-- Procedure ATTRIBUTES.SAVE_ATTRIBUTES saves session attributes.
ALTER MODULE attributes
ADD PROCEDURE save_attributes
(
  p_session_id VARCHAR(60),
  p_session_attributes session_attribute_array
)
  AUTONOMOUS
BEGIN
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_attribute_partition_id CHAR(1);
  DECLARE v_attribute_is_switching BOOLEAN;
  DECLARE v_session_internal_id BIGINT;
  DECLARE v_attribute_partition_num SMALLINT;
  DECLARE v_attribute_generation_id SMALLINT;
  DECLARE v_is_matched_object BOOLEAN;
  DECLARE v_is_changed BOOLEAN DEFAULT FALSE;

  -- Exit with error if inputs are unexpectedly null.
  IF p_session_id IS NULL THEN
    SIGNAL SQLSTATE '72003' SET MESSAGE_TEXT = 'Unsupported NULL input';
  END IF;

  -- Retrieve UTC timestamp and session and attribute partition control information.
  SET (v_utc, v_partition_id, v_is_switching, v_attribute_partition_id, v_attribute_is_switching) =
    (
      SELECT
        CURRENT_TIMESTAMP - CURRENT_TIMEZONE,
        active_partition_id,
        is_switching,
        attribute_active_partition_id,
        attribute_is_switching 
      FROM 
        sesctl
      WITH CS
    );

  -- Look up session information in the active partition, and block concurrent processes from updating it there.
  SET (v_session_internal_id, v_attribute_partition_num, v_attribute_generation_id) = 
    (
      SELECT
        session_internal_id, attribute_partition_num, attribute_generation_id
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
      SET (v_session_internal_id, v_attribute_partition_num, v_attribute_generation_id) =
        (
          SELECT
            session_internal_id, attribute_partition_num, attribute_generation_id
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

 -- Update session attributes.
  FOR r AS
    SELECT 
      attribute_name, object
    FROM
      UNNEST(p_session_attributes) AS a      
  DO
    -- Exit with error if inputs are unexpectedly null.
    IF r.attribute_name IS NULL THEN
      SIGNAL SQLSTATE '72003' SET MESSAGE_TEXT = 'Unsupported NULL input';
    END IF;

    -- Delete the attribute if the input object is NULL.
    IF r.object IS NULL THEN
      BEGIN
        DECLARE EXIT HANDLER FOR NOT FOUND
        BEGIN
          -- Skip to end of block without setting changed flag (if no rows deleted).
        END;
        IF v_attribute_is_switching THEN
          DELETE FROM sesatt
          WHERE
            session_internal_id = v_session_internal_id AND 
            attribute_name = r.attribute_name AND
            attribute_partition_num = v_attribute_partition_num;
        ELSE
          DELETE FROM sesatt
          WHERE
            session_internal_id = v_session_internal_id AND 
            attribute_name = r.attribute_name AND
            attribute_partition_num = v_attribute_partition_num AND
            partition_id = v_attribute_partition_id;
        END IF;
        SET v_is_changed = TRUE;
      END;
    -- Otherwise...
    ELSE
      -- Look up existing attribute in the active partition.
      SET v_is_matched_object =
        (
          SELECT
            CASE WHEN object = r.object THEN TRUE ELSE FALSE END
          FROM
            sesatt
          WHERE
            session_internal_id = v_session_internal_id AND 
            attribute_name = r.attribute_name AND
            attribute_partition_num = v_attribute_partition_num AND
            partition_id = v_attribute_partition_id
          WITH CS
        );
  
      -- If attribute partitions are switching and the object was not found in the old partition then check the new.
      IF v_is_matched_object IS NULL AND v_attribute_is_switching THEN
        SET v_is_matched_object =
          (
            SELECT
              CASE WHEN object = r.object THEN TRUE ELSE FALSE END
            FROM
              sesatt
            WHERE
              session_internal_id = v_session_internal_id AND 
              attribute_name = r.attribute_name AND
              attribute_partition_num = v_attribute_partition_num AND
              partition_id != v_attribute_partition_id
            WITH CS
          );
      END IF;

      -- If the attribute does not exist then insert it.
      IF v_is_matched_object IS NULL THEN
        INSERT INTO sesatt(session_internal_id, attribute_name, attribute_partition_num, partition_id, generation_id, object)
        VALUES
          (
            v_session_internal_id, 
            r.attribute_name,
            v_attribute_partition_num,
            common.new_partition_id(v_attribute_is_switching, v_attribute_partition_id),
            v_attribute_generation_id + 1,
            r.object
          );
        SET v_is_changed = TRUE;
      -- If the attribute has changed then update it.
      ELSEIF NOT v_is_matched_object THEN
        IF v_attribute_is_switching THEN
          UPDATE sesatt
          SET
            partition_id = common.new_partition_id(TRUE, v_attribute_partition_id),
            generation_id = v_attribute_generation_id + 1,
            object = r.object
          WHERE
            session_internal_id = v_session_internal_id AND 
            attribute_name = r.attribute_name AND
            attribute_partition_num = v_attribute_partition_num;
        ELSE
          UPDATE sesatt
          SET
            generation_id = v_attribute_generation_id + 1,
            object = r.object
          WHERE
            session_internal_id = v_session_internal_id AND 
            attribute_name = r.attribute_name AND
            attribute_partition_num = v_attribute_partition_num AND
            partition_id = v_attribute_partition_id;
        END IF;        
        SET v_is_changed = TRUE;
      END IF;
    END IF;
  END FOR;

  -- If any attribute changes have been made then update session.
  IF v_is_changed THEN
    IF v_is_switching THEN 
      UPDATE sessio
      SET
        attribute_generation_id = v_attribute_generation_id + 1
      WHERE
        session_id = p_session_id;
    ELSE
      UPDATE sessio
      SET
        attribute_generation_id = v_attribute_generation_id + 1
      WHERE
        session_id = p_session_id AND partition_id = v_partition_id;
    END IF;    
  END IF;
  
  -- Fail if the transaction has taken more than 5 seconds.
  IF CURRENT_TIMESTAMP - CURRENT_TIMEZONE > v_utc + 5 SECONDS THEN
    SIGNAL SQLSTATE '72009' SET MESSAGE_TEXT = 'Timeout';
  END IF;
END@
