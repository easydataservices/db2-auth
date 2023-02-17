# _AUTH Service error codes_

AUTH Service routines use a standard set of user-defined error codes, summarised in the table below.

## SQLSTATE error codes
| SQLSTATE | Message | Explanation |
| -------- | ------- | ----------- |
| 72001    | Session already exists | A session should only be persisted when it is created. |
| 72002    | Session does not exist | Unknown session. This is most likely to indicate a program error. |
| 72003    | Unsupported NULL input | One or more input parameters contain unsupported NULLs. This indicates a program error. |
| 72009    | Timeout | Execution did not complete within the maximum allowed time (5 seconds). |
| 72011    | AUTH_NAME cannot be changed | Once set, the user name cannot be changed. |
| 72012    | AUTH_NAME cannot be empty | The user name can be NULL but cannot be blank. |
| 72013    | MAX_IDLE_MINUTES out of range | Value must be between 1 AND 1440, or NULL. |
| 72014    | New SESSION_ID cannot be empty | The session identifier canmot be NULL and cannot be blank. |
| 72021    | Switch is not started | Attempt to end a non-existent switch operation. |
| 72022    | Active partition is not empty | To end a switch operation, the old active partition can contain no sessions (except logically deleted sessions). |
| 72099   | General error | JDBC method catch-all, used for any error rethrown as an SQLException. |
