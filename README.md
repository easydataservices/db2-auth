# _About the AUTH Service_

<img src="docs/auth_service_overview.png" title="AUTH Service overview" width="70%"/>

# Synopsis
The AUTH Service is an off-the-peg solution that enables session details to be persisted by and retreived from a Db2 for LUW database. Optionally, session attributes can also be persisted and retrieved. The design supports high workload environments and 24x7 availability.

Check the [AUTH Service Project Blog](https://github.com/easydataservices/db2-auth/wiki/Project-Blog) for latest news.

# Design features
The author has seen designs for session management within the database that have proved highly problematic in the real world. The AUTH Service includes several features to avoid potential pitfalls:

* Availability: The service is designed for 24x7 operation.
* Atomicity: Session attributes can be saved and retrieved in a single operation. This ensures consistency between related attributes when persisted.
* Locking: The service is carefully coded to avoid deadlocks and to minimise lock contention (generally to avoid lock waits completely); also to ensure that any unavoidable lock waits are momentary.
* Housekeeping: The service is designed for full housekeeping without affecting availability.
* LOB performance: The service uses table partitioning to minimise both likelihood and severity of contention for buddy space during concurrent LOB updates.

# Project status
In development, no release to date. See blog for minor updates.

# Further documentation

| Document | Primary audience | Description |
| -------- | ---------------- | ----------- |
| [INSTALL](docs/INSTALL.md) | all | Installation instructions |
| [DESIGN_SESSIONS](docs/DESIGN_SESSIONS.md) | developers | Session management design notes |
| [DESIGN_ATTRIBUTES](docs/DESIGN_ATTRIBUTES.md) | developers | Session attribute management design notes |
| [ERROR_CODES](docs/ERROR_CODES.md) | all | AUTH Service user-defined SQLSTATE error codes |
