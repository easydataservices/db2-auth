-- Storage
CREATE BUFFERPOOL bp_32k PAGESIZE 32 K;

-- Note: For LOB performamce it is recommended that you place tablespaces on fast storage and have plenty of
-- free memory for filesystem caching.
CREATE TABLESPACE ts_sessio_dat 
  PAGESIZE 32 K 
  BUFFERPOOL bp_32k;

CREATE SYSTEM TEMPORARY TABLESPACE tempspace_32k 
  PAGESIZE 32 K 
  BUFFERPOOL bp_32k;

CREATE TABLESPACE ts_sessio_idx;

CREATE TABLESPACE ts_sessio_lob 
  PAGESIZE 32 K 
  BUFFERPOOL bp_32k
  FILE SYSTEM CACHING;

-- Sequences
CREATE SEQUENCE session_internal_id AS BIGINT;

CREATE SEQUENCE attribute_partition_num AS SMALLINT
  START WITH 1
  CYCLE;

-- Session Control table
CREATE TABLE sesctl
(
  singleton_id SMALLINT NOT NULL DEFAULT 1,
  max_expired_minutes SMALLINT NOT NULL DEFAULT 1440,
  max_idle_minutes SMALLINT NOT NULL DEFAULT 10,
  max_authentication_minutes SMALLINT DEFAULT 1440,
  num_attribute_partitions SMALLINT NOT NULL DEFAULT 20,
  active_partition_id CHAR(1) NOT NULL DEFAULT 'A',
  is_switching BOOLEAN NOT NULL DEFAULT FALSE,
  switch_start_ts TIMESTAMP(0),
  attribute_active_partition_id CHAR(1) NOT NULL DEFAULT 'A',
  attribute_is_switching BOOLEAN NOT NULL DEFAULT FALSE,
  attribute_switch_start_ts TIMESTAMP(0),
  session_move_commit_limit SMALLINT NOT NULL DEFAULT 50,
  session_move_sleep_seconds SMALLINT NOT NULL DEFAULT 1,
  attribute_move_commit_limit SMALLINT NOT NULL DEFAULT 10,
  attribute_move_sleep_seconds SMALLINT NOT NULL DEFAULT 1,
  is_move_stop_requested BOOLEAN NOT NULL DEFAULT FALSE
)
  ORGANIZE BY ROW
  IN ts_sessio_dat INDEX IN ts_sessio_idx;

CREATE ALIAS session_control FOR sesctl;

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_pk PRIMARY KEY (singleton_id);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc01 CHECK (singleton_id = 1);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc02 CHECK (max_expired_minutes > 1);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc03 CHECK (max_idle_minutes BETWEEN 1 AND 1440);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc04 CHECK (max_authentication_minutes > max_idle_minutes);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc05 CHECK (num_attribute_partitions > 0);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc06 CHECK (active_partition_id IN ('A', 'B'));

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc07 CHECK ((is_switching AND switch_start_ts IS NOT NULL) OR (NOT is_switching AND switch_start_ts IS NULL));

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc08 CHECK (attribute_active_partition_id IN ('A', 'B'));

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc09 CHECK
(
  (attribute_is_switching AND attribute_switch_start_ts IS NOT NULL) OR 
  (NOT attribute_is_switching AND attribute_switch_start_ts IS NULL)
);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc10 CHECK (NOT is_switching OR NOT attribute_is_switching);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc11 CHECK (session_move_commit_limit > 0);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc12 CHECK (session_move_sleep_seconds >= 0);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc13 CHECK (attribute_move_commit_limit > 0);

ALTER TABLE sesctl
ADD CONSTRAINT sesctl_cc14 CHECK (attribute_move_sleep_seconds >= 0);

INSERT INTO sesctl(singleton_id) VALUES 1;

-- Session table A
CREATE TABLE sessia
(
  session_internal_id BIGINT NOT NULL,
  partition_id CHAR(1) NOT NULL,
  attribute_partition_num SMALLINT NOT NULL,
  created_ts TIMESTAMP(0) NOT NULL,
  attribute_generation_id INTEGER NOT NULL DEFAULT 0,
  last_accessed_ts TIMESTAMP(0) NOT NULL DEFAULT '0001-01-01-00.00.00',
  last_authenticated_ts TIMESTAMP(0),
  expiry_ts TIMESTAMP(0) NOT NULL DEFAULT '9999-12-31-24.00.00',
  deleted_ts TIMESTAMP(0),
  session_id VARCHAR(60) NOT NULL,
  max_idle_minutes SMALLINT,
  auth_name VARCHAR(60),
  properties_json VARCHAR(2048) NOT NULL DEFAULT '{}'
)
  ORGANIZE BY ROW
  IN ts_sessio_dat INDEX IN ts_sessio_idx;

CREATE ALIAS session_a FOR sessia;

ALTER TABLE sessia
  VOLATILE;

CREATE UNIQUE INDEX sessia_pk ON sessia (session_internal_id RANDOM)
  INCLUDE (partition_id);

CREATE UNIQUE INDEX sessia_uk1 ON sessia (session_id RANDOM)
  INCLUDE (partition_id);

CREATE INDEX sessia_ix01 ON sessia (auth_name)
  EXCLUDE NULL KEYS;

ALTER TABLE sessia
ADD CONSTRAINT sessia_pk PRIMARY KEY (session_internal_id);

ALTER TABLE sessia
ADD CONSTRAINT sessia_uk1 UNIQUE (session_id);

ALTER TABLE sessia
ADD CONSTRAINT sessia_cc01 CHECK (partition_id = 'A');

-- Session table B
CREATE TABLE sessib
(
  session_internal_id BIGINT NOT NULL,
  partition_id CHAR(1) NOT NULL,
  attribute_partition_num SMALLINT NOT NULL,
  created_ts TIMESTAMP(0) NOT NULL,
  attribute_generation_id INTEGER NOT NULL DEFAULT 0,
  last_accessed_ts TIMESTAMP(0) NOT NULL DEFAULT '0001-01-01-00.00.00',
  last_authenticated_ts TIMESTAMP(0),
  expiry_ts TIMESTAMP(0) NOT NULL DEFAULT '9999-12-31-24.00.00',
  deleted_ts TIMESTAMP(0),
  session_id VARCHAR(60) NOT NULL,
  max_idle_minutes SMALLINT,
  auth_name VARCHAR(60),
  properties_json VARCHAR(2048) NOT NULL DEFAULT '{}'
)
  ORGANIZE BY ROW
  IN ts_sessio_dat INDEX IN ts_sessio_idx;

CREATE ALIAS session_b FOR sessib;

ALTER TABLE sessib
  VOLATILE;

CREATE UNIQUE INDEX sessib_pk ON sessib (session_internal_id RANDOM)
  INCLUDE (partition_id);

CREATE UNIQUE INDEX sessib_uk1 ON sessib (session_id RANDOM)
  INCLUDE (partition_id);

CREATE INDEX sessib_ix01 ON sessib (auth_name)
  EXCLUDE NULL KEYS;

ALTER TABLE sessib
ADD CONSTRAINT sessib_pk PRIMARY KEY (session_internal_id);

ALTER TABLE sessib
ADD CONSTRAINT sessib_uk1 UNIQUE (session_id);

ALTER TABLE sessib
ADD CONSTRAINT sessib_cc01 CHECK (partition_id = 'B');

-- Session view
CREATE OR REPLACE VIEW sessio
(
  session_internal_id,
  partition_id,
  attribute_partition_num,
  created_ts,
  attribute_generation_id,
  last_accessed_ts,
  last_authenticated_ts,
  expiry_ts,
  deleted_ts,
  session_id,
  max_idle_minutes,
  auth_name,
  properties_json
) AS
SELECT
  session_internal_id,
  partition_id,
  attribute_partition_num,
  created_ts,
  attribute_generation_id,
  last_accessed_ts,
  last_authenticated_ts,
  expiry_ts,
  deleted_ts,
  session_id,
  max_idle_minutes,
  auth_name,
  properties_json
FROM
  sessia
UNION ALL
SELECT
  session_internal_id,
  partition_id,
  attribute_partition_num,
  created_ts,
  attribute_generation_id,
  last_accessed_ts,
  last_authenticated_ts,
  expiry_ts,
  deleted_ts,
  session_id,
  max_idle_minutes,
  auth_name,
  properties_json
FROM
  sessib
WITH ROW MOVEMENT;

CREATE ALIAS session FOR sessio;

-- Session Attribute table A
CREATE TABLE sesata
(
  session_internal_id BIGINT NOT NULL,
  attribute_name VARCHAR(240) NOT NULL,
  attribute_partition_num SMALLINT NOT NULL,
  partition_id CHAR(1) NOT NULL,
  generation_id INTEGER NOT NULL,
  object BLOB(2M) INLINE LENGTH 32000
)
  ORGANIZE BY ROW
  IN ts_sessio_dat INDEX IN ts_sessio_idx LONG IN ts_sessio_lob
  PARTITION BY (attribute_partition_num)
  (
    STARTING 0 ENDING 0,
    STARTING 1 ENDING 1,
    STARTING 2 ENDING 2,
    STARTING 3 ENDING 3,
    STARTING 4 ENDING 4,
    STARTING 5 ENDING 5,
    STARTING 6 ENDING 6,
    STARTING 7 ENDING 7,
    STARTING 8 ENDING 8,
    STARTING 9 ENDING 9,
    STARTING 10 ENDING 10,
    STARTING 11 ENDING 11,
    STARTING 12 ENDING 12,
    STARTING 13 ENDING 13,
    STARTING 14 ENDING 14,
    STARTING 15 ENDING 15,
    STARTING 16 ENDING 16,
    STARTING 17 ENDING 17,
    STARTING 18 ENDING 18,
    STARTING 19 ENDING 19
  );

CREATE ALIAS session_attribute_a FOR sesata;

ALTER TABLE sesata
VOLATILE;

CREATE UNIQUE INDEX sesata_pk ON sesata
(
  session_internal_id, attribute_name, attribute_partition_num
)
  PARTITIONED
  INCLUDE (partition_id)
  CLUSTER;

ALTER TABLE sesata
ADD CONSTRAINT sesata_pk PRIMARY KEY (session_internal_id, attribute_name, attribute_partition_num);

ALTER TABLE sesata
ADD CONSTRAINT sesata_cc01 CHECK (partition_id = 'A');

-- Session Attribute table B
CREATE TABLE sesatb
(
  session_internal_id BIGINT NOT NULL,
  attribute_name VARCHAR(240) NOT NULL,
  attribute_partition_num SMALLINT NOT NULL,
  partition_id CHAR(1) NOT NULL,
  generation_id INTEGER NOT NULL,
  object BLOB(2M) INLINE LENGTH 32000
)
  ORGANIZE BY ROW
  IN ts_sessio_dat INDEX IN ts_sessio_idx LONG IN ts_sessio_lob
  PARTITION BY (attribute_partition_num)
  (
    STARTING 0 ENDING 0,
    STARTING 1 ENDING 1,
    STARTING 2 ENDING 2,
    STARTING 3 ENDING 3,
    STARTING 4 ENDING 4,
    STARTING 5 ENDING 5,
    STARTING 6 ENDING 6,
    STARTING 7 ENDING 7,
    STARTING 8 ENDING 8,
    STARTING 9 ENDING 9,
    STARTING 10 ENDING 10,
    STARTING 11 ENDING 11,
    STARTING 12 ENDING 12,
    STARTING 13 ENDING 13,
    STARTING 14 ENDING 14,
    STARTING 15 ENDING 15,
    STARTING 16 ENDING 16,
    STARTING 17 ENDING 17,
    STARTING 18 ENDING 18,
    STARTING 19 ENDING 19
  );

CREATE ALIAS session_attribute_b FOR sesatb;

ALTER TABLE sesatb
VOLATILE;

CREATE UNIQUE INDEX sesatb_pk ON sesatb
(
  session_internal_id, attribute_name, attribute_partition_num
)
  PARTITIONED
  INCLUDE (partition_id)
  CLUSTER;

ALTER TABLE sesatb
ADD CONSTRAINT sesatb_pk PRIMARY KEY (session_internal_id, attribute_name, attribute_partition_num);

ALTER TABLE sesatb
ADD CONSTRAINT seatsb_cc01 CHECK (partition_id = 'B');

-- Session Attribute view
CREATE OR REPLACE VIEW sesatt
(
  session_internal_id,
  attribute_name,
  attribute_partition_num,
  partition_id,
  generation_id,
  object
) AS
SELECT
  session_internal_id,
  attribute_name,
  attribute_partition_num,
  partition_id,
  generation_id,
  object
FROM
  sesata
UNION ALL
SELECT
  session_internal_id,
  attribute_name,
  attribute_partition_num,
  partition_id,
  generation_id,
  object
FROM
  sesatb
WITH ROW MOVEMENT;

CREATE ALIAS session_attribute FOR sesatt;
