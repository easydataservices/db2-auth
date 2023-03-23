-- Procedure ATTRIBUTES.GET_ATTRIBUTES retrieves session attributes for the specified session identifier (P_SESSION_ID).
-- Attribute names and generation are always returned.
-- The value of P_SINCE_GENERATION_ID determines whether the attribute object is returned, or NULL:
-- 1. When NULL, no attribute objects are returned (return all attribute names).
-- 2. When 0, all attribute objects are returned (full load).
-- 3. When greater then 0, only objects for attributes with a generation greater than P_SINCE_GENERATION_ID are
--    returned (delta load).
ALTER MODULE attributes
ADD PROCEDURE get_attributes
(
  p_session_id VARCHAR(60),
  p_since_generation_id INTEGER,
  OUT p_session_attributes session_attribute_array
)
  AUTONOMOUS
BEGIN
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_attribute_partition_id CHAR(1);
  DECLARE v_attribute_is_switching BOOLEAN;
  DECLARE v_session_internal_id BIGINT;
  DECLARE v_session_deleted_ts TIMESTAMP(0);
  DECLARE v_attribute_partition_num SMALLINT;
  DECLARE v_session_attribute session_attribute;
  DECLARE v_index INTEGER DEFAULT 1;

  -- Exit with error if inputs are unexpectedly null.
  IF p_session_id IS NULL THEN
    SIGNAL SQLSTATE '72003' SET MESSAGE_TEXT = 'Unsupported NULL input';
  END IF;

  -- Retrieve session and attribute partition control information.
  SET (v_partition_id, v_is_switching, v_attribute_partition_id, v_attribute_is_switching) =
    (
      SELECT
        active_partition_id,
        is_switching,
        attribute_active_partition_id,
        attribute_is_switching 
      FROM 
        sesctl
      WITH CS
    );

  -- Look up session information in the active partition, and block concurrent processes from updating it there.
  SET (v_session_internal_id, v_attribute_partition_num, v_session_deleted_ts) = 
    (
      SELECT
        session_internal_id, attribute_partition_num, deleted_ts
      FROM
        sessio
      WHERE
        session_id = p_session_id AND partition_id = v_partition_id
      WITH RR USE AND KEEP UPDATE LOCKS
    );

  -- If partitions are switching and the session was not found in the old partition then check the new, and block
  -- concurrent processes from updating it there.
  IF v_is_switching THEN 
    IF v_session_internal_id IS NULL THEN
      SET (v_session_internal_id, v_attribute_partition_num, v_session_deleted_ts) =
        (
          SELECT
            session_internal_id, attribute_partition_num, deleted_ts
          FROM
            sessio
          WHERE
            session_id = p_session_id AND partition_id != v_partition_id
          WITH RR USE AND KEEP UPDATE LOCKS
        );
    END IF;
  END IF;

  -- Exit with error if the session does not exist.
  IF v_session_internal_id IS NULL THEN
    SIGNAL SQLSTATE '72002' SET MESSAGE_TEXT = 'Session does not exist';
  END IF;

  -- Iterate through session attributes in the active partition to populate array.
  FOR r AS
    SELECT 
      attribute_name,
      CASE WHEN generation_id > p_since_generation_id THEN object END AS object
    FROM
      sesatt
    WHERE
      session_internal_id = v_session_internal_id AND
      attribute_partition_num = v_attribute_partition_num AND
      partition_id = v_attribute_partition_id AND
      v_session_deleted_ts IS NULL
    WITH CS
  DO
    SET v_session_attribute.attribute_name = r.attribute_name;
    SET v_session_attribute.object = r.object;
    SET p_session_attributes[v_index] = v_session_attribute;
    SET v_index = v_index + 1;
  END FOR;

  -- If the attribute partitions are switching then also iterate through session attributes in the new partition to 
  -- populate array.
  IF v_attribute_is_switching THEN
    FOR r AS
      SELECT 
        attribute_name,
        CASE WHEN generation_id > p_since_generation_id THEN object END AS object
      FROM
        sesatt
      WHERE
        session_internal_id = v_session_internal_id AND
        attribute_partition_num = v_attribute_partition_num AND
        partition_id != v_attribute_partition_id AND
        v_session_deleted_ts IS NULL
      WITH CS
    DO
      SET v_session_attribute.attribute_name = r.attribute_name;
      SET v_session_attribute.object = r.object;
      SET p_session_attributes[v_index] = v_session_attribute;
      SET v_index = v_index + 1;
    END FOR;
  END IF;
END@
