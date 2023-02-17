-- Module VALIDATE contains common auxiliary routines.
CREATE OR REPLACE MODULE common;

-- Return the target partition id.
ALTER MODULE common
PUBLISH FUNCTION new_partition_id(p_is_switching BOOLEAN, p_partition_id CHAR(1)) RETURNS CHAR(1);

-- Return the expiry timestamp calculated from the inputs.
ALTER MODULE common
PUBLISH FUNCTION expiry_ts
(
  p_max_idle_minutes SMALLINT,
  p_last_accessed_ts TIMESTAMP(0),
  p_last_authenticated_ts TIMESTAMP(0)
) RETURNS TIMESTAMP(0);

-- Validate JSON input.
ALTER MODULE common
PUBLISH PROCEDURE check_json(p_json VARCHAR(32000));
