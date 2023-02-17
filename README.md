# _About the AUTH Service_

# Synopsis
The AUTH Service provides an off-the-peg solution for passing session authentication details to Db2 applications, and optionally for saving and retrieving session attributes. The design supports high workload environments and 24x7 availability.

Check the [AUTH Service Project Blog](https://github.com/easydataservices/db2-auth/wiki/Project-Blog) for latest news.

# Design features
The author has seen designs for session management within the database that have proved highly problematic in the real world. The AUTH Service includes several features to avoid potential pitfalls:

* Availability: The service is designed for 24x7 operation.
* Atomicity: Session attributes can be saved and retrieved in a single operation. This ensures consistency between related attributes when persisted.
* Locking: The service is carefully coded to avoid deadlocks and to minimise lock contention (generally to avoid lock waits completely); also to ensure that any unavoidable lock waits are momentary.
* Housekeeping: The service is designed for full housekeeping without affecting availability.
* LOB performance: The service uses table partitioning to minimise both likelihood and severity of contention for buddy space during concurrent LOB updates.

# Project status
Code is currently in active development, and not yet completed.

# Further documentation

| Document | Primary audience | Description |
| -------- | ---------------- | ----------- |
| [INSTALL](docs/INSTALL.md) | all | Installation instructions |
| [DESIGN_SESSIONS](docs/DESIGN_SESSIONS.md) | developers | Session management design notes |
| [DESIGN_ATTRIBUTES](docs/DESIGN_ATTRIBUTES.md) | developers | Session attribute management design notes |
| [ERROR_CODES](docs/ERROR_CODES.md) | all | AUTH Service user-defined SQLSTATE error codes |
