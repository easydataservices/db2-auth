# _AUTH Service design for Session Attribute Management_

> Note: Table names described below are mostly aliases. Actual table names and their related objects (indexes and constraints) use a short 6 letter abbreviation. You can refer to a table by its abbreviated name or by its alias.

# Schema
Schema AUTH contains tables used for core session management (described in [DESIGN_SESSIONS](DESIGN_SESSIONS.md)).

Session attribute management extends the schema to allow one or more session attributes to be persisted for any active session.

## Table SESSION_ATTRIBUTE
Table SESSION_ATTRIBUTE (short name SESATT) stores session attributes. The attributes are stored as binary large objects (binary LOBs aka BLOBs).

To maximise availability, the table is in fact a UNION ALL view, implementing view partitioning as described above (see table SESSIO). The view references two view partitions, physical tables SESSION_ATTRIBUTE_A (short name SESATA) and SESSION_ATTRIBUTE_B (short name SESATB). The value of column PARTITION_ID determines which view partition a row is stored in; rows with value ``A`` are stored in table SESSION_ATTRIBUTE_A, and rows with value ``B`` are stored in table SESSION_ATTRIBUTE_B.

In addition to view partitioning, the SESSION_ATTRIBUTE physical design employs standard Db2 table partitioning in tables SESSION_ATTRIBUTE_A and SESSION_ATTRIBUTE_B as a second tier of partitioning. The reason for this second tier is not availability but performance. Both tables must have the same number of table partitions (matching the value of column NUM_ATTRIBUTE_PARTITIONS in table SESSION_CONTROL). The default implementation is defined with 20 partitions each. The partitioning key is column ATTRIBUTE_PARTITION_NUM.

# Design considerations

## Session storage and partition switching
There are two modes of operation, depending of the value of column ATTRIBUTE_IS_SWITCHING in table SESSION_CONTROL:

* During normal operation (when ATTRIBUTE_IS_SWITCHING is ``false``), the value (``A`` or ``B``) of column ATTRIBUTE_ACTIVE_PARTITION_ID designates which of the two view partitions is the active partition. All active session information will be held in that view partition. The other partition will either be empty or will contain only logically deleted session attribute data.

    > Note: There are no accesses to the inactive partition during normal operation. This allows housekeeping activities on that partition without risk of contention, even in the busiest of systems.
* During partition switching (when ATTRIBUTE_IS_SWITCHING is ``true``), the value of column ATTRIBUTE_ACTIVE_PARTITION_ID designates the old active partition. After the switch is started, new session rows are written to the other partition (i.e. the new active partition) while a background process asynchronously moves other session rows from the old partition to the new. Once all rows have been moved, the values of the ATTRIBUTE_ACTIVE_PARTITION_ID and ATTRIBUTE_IS_SWITCHING columns are flipped, and normal operation resumes.

    > Note: Partition switching involves some additional overhead, with both view partitions accessed throughout the operation. It makes sense to schedule switches during less busy periods.

The same principles apply to session attributes.

## LOB performance
Db2 LOBs over the size that can be in-lined are stored separately from regular data. LOBs can be a serious performance bottleneck for several reasons. To mitigate this risk, the AUTH sevice uses a number of strategies:

* The largest available page size is used, to allow a large in-line LOB size of up to 32,000 bytes. In-line LOB performance has all the benefits of regular data.
* LOB data (unless in-lined) uses direct IO and is not cached in bufferpool memory. The AUTH service therefore uses a dedicated tablespace (TS_SESSIO_LOB) for LOBs, and enables filesystem caching for that tablespace.
* LOB storage uses a buddy space mechanism. Db2 maintains hints to show where free buddy space segments of a particular size are located. The hint mechanism is simple, and does not support concurrent inserts. LOB inserts that miss out on space located by a hint must perform a search for space that can be very lengthy, before the hint mechanism is reestablished. For this reason, the AUTH service uses Db2 table partitioning for session attribute storage. LOB partitions are allocated to new sessions on a round robin basis. Each partition has its own LBA object containing LOB space allocation information for that partition. The use of multiple table partitions:
    * Reduces the chance of concurrent inserts into the same LOB space, and in turn the chance of needing to perform a lengthy space search.
    * Reduces the average size and duration of a space search, if needed.
    * Reduces the impact of space searches on performance, because partitions not under similar duress will still have an established hint mechanism.

> Note: For high load systems it is recommended that you place tablespace TS_SESSIO_LOB in a storage group backed by fast storage (e.g. flash storage).

# Interface

## Overview
The following modules contain routines used for session attribute management:
* ATTRIBUTES: Routines for persisting and retrieving session attributes.
* ADMIN: Routines for housekeeping.

## Module ATTRIBUTES
Module ATTRIBUTES contains routines for saving and retrieving session attributes. The attributes are stored in table SESSION_ATTRIBUTE (described above).

Module routines use array type SESSION_ATTRIBUTE_ARRAY for passing attributes. The definition of this type is:

```
ALTER MODULE attributes
PUBLISH TYPE session_attribute AS ROW
(
  attribute_name VARCHAR(240),
  object BLOB(2M)
);

ALTER MODULE attributes
PUBLISH TYPE session_attribute_array AS session_attribute ARRAY[];
```

### Procedure SAVE_ATTRIBUTES
Procedure SAVE_ATTRIBUTES saves attributes for the specified session (P_SESSION_ID). The attributes (P_SESSION_ATTRIBUTES) are passed as an array.

> Notes:
> 1. Any attribute that was persisted previously but not passed to the current invocation of the procedure is left unchanged.
> 1. An input attribute with a NULL object is not persisted. If previously persisted, the attribute is deleted.
> 1. An input attribute with its object unchanged from when it was last persisted is left unchanged. This is more efficent than an unnecessary update. However, if the application framework tracks which session attributes have changed since last persisted, then not passing unchanged attributes as input is yet more efficient.

### Procedure GET_ATTRIBUTES
Procedure GET_ATTRIBUTES retrieves all attributes for the specified session (P_SESSION_ID). The attributes (P_SESSION_ATTRIBUTES) are returned in an array. There are 2 modes of operation, depending on P_SINCE_GENERATION_ID:
1. When P_SINCE_GENERATION_ID is NULL, the procedure returns all attribute names. Object data is not returned (returns NULL). This mode is used to retrieve a list of all current attribute names. To detect deletions, the caller can compare the attribute names returned with the list of attribute names already known to the HttpSession.
2. When P_SINCE_GENERATION_ID has a value, the procedure returns only attributes with a later GENERATION_ID. Object data is also returned. This can be used to retrieve a delta of attribute inserts and updates.

## Module ADMIN

## Procedure START_ATTRIBUTE_SWITCH
Procedure START_ATTRIBUTE_SWITCH initiates attribute partition switching.

## Procedure END_ATTRIBUTE_SWITCH
Procedure END_ATTRIBUTE_SWITCH finalises attribute partition switching.
