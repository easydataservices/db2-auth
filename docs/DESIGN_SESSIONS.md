# _AUTH Service design for Session Management_

> Note: Table names described below are mostly aliases. Actual table names and their related objects (indexes and constraints) use a short 6 letter abbreviation. You can refer to a table by its abbreviated name or by its alias.

> Note: AUTH is the default schema name for the service, but you may use a different name.

# Schema
Schema AUTH contains two tables used for core session management, SESSION and SESSION_CONTROL. Session details are stored in SESSION, while SESSION_CONTROL contains control information for managing sessions.

> See also: [DESIGN_ATTRIBUTES](DESIGN_ATTRIBUTES.md)

## Table SESSION
Table SESSION (short name SESSIO) contains details of sessions and their state. To maximise availability, the table is in fact a UNION ALL view to implement a form of partitioning. Here we term this "view partitioning" to distinguish it from standard DB2 table partitioning.

The view references two view partitions, physical tables SESSION_A (short name SESSIA) and SESSION_B (short name SESSIB). The value of column PARTITION_ID determines which view partition a row is stored in; rows with value ``A`` are stored in table SESSION_A, and rows with value ``B`` are stored in table SESSION_B.

Whether rows are inserted with a PARTITION_ID value of ``A`` or ``B`` is controlled by table SESSION_CONTROL (short name SESCTL).

## Table SESSION_CONTROL
Table SESSION_CONTROL contains control data. Values in this table determine how quickly sessions expire, and which partition of table SESSION contains session data.

# Design considerations

## Session storage and partition switching
There are two modes of operation, depending of the value of column IS_SWITCHING:

* During normal operation (when IS_SWITCHING is ``false``), the value (``A`` or ``B``) of column ACTIVE_PARTITION_ID designates which of the two view partitions is the active partition. All active session information will be held in that partition. The other partition will either be empty or will contain only logically deleted session data.

    > Note: There are no accesses to the inactive partition during normal operation. This allows housekeeping activities on that partition without risk of contention, even in the busiest of systems.
    
* During partition switching (when IS_SWITCHING is ``true``), the value of column ACTIVE_PARTITION_ID designates the old active partition. After the switch is started, new session rows are written to the other partition (i.e. the new active partition) while a background process asynchronously moves other session rows from the old partition to the new. Once all rows have been moved, the values of the ACTION_PARTITION_ID and IS_SWITCHING columns are flipped, and normal operation resumes.

    > Note: Partition switching involves some additional overhead, with both view partitions accessed throughout the operation. It makes sense to schedule switches during less busy periods.

## Locking strategy
The AUTH service is designed carefully to minimise lock contention:
* All accesses to session and attribute data start by locking the session row in table SESSION.
* This single lock* is a very lightweight solution. It acts to prevent conflicting updates to the session data by any concurrent process.
* Because the session lock acts as gatekeeper to all data for that session, there is no need to lock attribute rows.

    _* During partition switching the row lock may be placed in both partitions._

Generally, the only serialisation of lock requests (lock waits) occurs if multiple processes access data for the same session concurrently. The locking strategy avoids any possibility of deadlocks. Locks are retained for minimal duration, so even in the rare case of concurrent access requests lock waits should not be noticeable to users.

In only one case can locks for one session affect another - when adding a new session. Due to next key locking, Db2 will place a read lock on the next key, which belongs to another session. Again, this lock will be momentary and is unlikely to be noticeable in the event of a concurrent access to that other session. Moreover, the probability of this type of contention reduces as the number of existing sessions in table SESSION grows. Due to the very brief duration that locks are held it is unlikely to be necessary, but a strategy for reducing the probability still further would be to retain logically deleted session rows.

# Interface

## Overview
The following modules contain routines used for session management:
* CONTROL: Routines for adding, updating and removing sessions.
* SESSION: Routines for retrieving sessions.
* ADMIN: Routines for housekeeping.

## Module CONTROL

Module CONTROL contains routines for managing sessions.

The module uses custom type SESSION_CONFIG:

```
TYPE session_config AS ROW
(
  change_ts TIMESTAMP(0),
  auth_name VARCHAR(60),
  max_idle_minutes SMALLINT,
  properties_json VARCHAR(2000)
)
```

The SESSION_CONFIG fields can be used to specify the following:
* CHANGE_TS - an earlier time that the session configuration changes were effected. This supports deferral of updates from the session cache to the store. If not specified then the current time is used.
* AUTH_NAME - the authenticated user name. This can be NULL for sessions that are not yet authenticated, but once set the value cannot be changed.
* MAX_IDLE_MINUTES - override of the default maximum inactive interval (in minutes) between requests, before the session will be invalidated. The value must be between 1 and 1440. If NULL then the default used is 10 minutes.
* PROPERTIES_JSON - additional session configuration properties in JSON format. For example, it might be useful to store the server affinity or the authentication given (password, one-time token etc.).

### Procedure ADD_SESSION
Procedure ADD_SESSION adds a new session (P_SESSION_ID) with the specified configuration (P_SESSION_CONFIG of type SESSION_CONFIG).

The procedure blocks other processes from creating the same session row concurrently. During normal operation the block operates only on the active partition; but when partition switching has been started the block operates on both partitions.

### Procedure CHANGE_SESSION_CONFIG
Procedure CHANGE_SESSION_CONFIG changes the configuration (P_SESSION_CONFIG of type SESSION_CONFIG) of an existing session (P_SESSION_ID).

Calling the procedure with a non-NULL P_SESSION_CONFIG.AUTH_NAME indicates that the session has been authenticated or re-authenticated. If the session has expired it will be reactivated.

The procedure blocks other processes from accessing the same session row concurrently. During normal operation the block operates only on the active partition; when partition switching has been started the block operates on both partitions.

### Procedure REMOVE_SESSION
Procedure REMOVE_SESSION marks a session (P_SESSION_ID) deleted. The deletion is a logical deletion; column IS_DELETED is set ``true`` but the row is not removed.

The procedure blocks other processes from accessing the same session row concurrently. During normal operation the block operates only on the active partition; when partition switching has been started the block operates on both partitions.

### Procedure CHANGE_SESSION_ID
Procedure CHANGE_SESSION_ID changes the current session identifier (P_SESSION_ID) to the specified new identifier (P_NEW_SESSION_ID). This supports protection against session fixation attacks.

The procedure blocks other processes from accessing the same session row concurrently. During normal operation the block operates only on the active partition; when partition switching has been started the block operates on both partitions.

## Module SESSION

Module SESSION contains routines for retrieving an existing session.

The module uses custom type SESSION_INFO:

```
TYPE session_info AS ROW
( 
  created_ts TIMESTAMP(0),
  last_accessed_ts TIMESTAMP(0),
  last_authenticated_ts TIMESTAMP(0),
  max_idle_minutes SMALLINT,
  max_authentication_minutes SMALLINT,
  expiry_ts TIMESTAMP(0),
  auth_name VARCHAR(60),
  properties_json VARCHAR(2000),
  is_authenticated BOOLEAN,
  is_expired BOOLEAN,
  attribute_generation_id INTEGER
)
```

The SESSION_INFO fields return the following information:
* CREATED_TS - when the session was created.
* LAST_ACCESSED_TS - when the session was last accessed by a request.
* LAST_AUTHENTICATED_TS - when the session was last authenticated.
* MAX_IDLE_MINUTES - maximum inactive interval (in minutes) between requests, before this session will be invalidated.
* MAX_AUTHENTICATION_MINUTES - maximum time (in minutes) before this session will be invalidated.
* EXPIRY_TS - when the session will expiry if no interventions occur.
* AUTH_NAME - authenticated user name; NULL for sessions that are not yet authenticated.
* PROPERTIES_JSON - additional session configuration properties, in JSON format.
* IS_AUTHENTICATED - TRUE if the session is authenticated, otherwise FALSE.
* IS_EXPIRED - TRUE if the session is expired, otherwise FALSE.
* ATTRIBUTE_GENERATION_ID - 0 if there are no session attributes. Increases by 1 every time session attributes are added, changed or removed. Can be used by cache to determine whether attribute have changed and which attributes need to be reloaded.

## Procedure GET_SESSION
Procedure GET_SESSION retrieves session details (P_SESSION_INFO of type SESSION_INFO) for the specified session (P_SESSION_ID).

If the session exists and has not expired then the LAST_ACCESSED_TS is updated.

The procedure blocks other processes from accessing the same session row concurrently. During normal operation the block operates only on the active partition; when partition switching has been started the block operates on both partitions..

## Module ADMIN

## Procedure START_SESSION_SWITCH
Procedure START_SESSION_SWITCH initiates session partition switching.

## Procedure START_SESSION_SWITCH
Procedure END_SESSION_SWITCH finalises session partition switching.
