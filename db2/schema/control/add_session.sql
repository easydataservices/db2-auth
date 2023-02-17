-- Procedure CONTROL.ADD_SESSION adds a new session.
ALTER MODULE control
ADD PROCEDURE add_session(p_session_id VARCHAR(60), p_session_config session_config)
  AUTONOMOUS
BEGIN
  DECLARE c_empty_json CHAR(2) CONSTANT '{}';
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_num_attribute_partitions SMALLINT;
  DECLARE v_session_internal_id BIGINT;
  DECLARE v_attribute_partition_num SMALLINT;

  -- Retrieve UTC timestamp and session partition control information.
  SET (v_utc, v_partition_id, v_is_switching, v_num_attribute_partitions) =
    (
      SELECT CURRENT_TIMESTAMP - CURRENT_TIMEZONE, active_partition_id, is_switching, num_attribute_partitions FROM sesctl
      WITH CS
    );

  -- Check that the session does not exist in the active partition, and block concurrent processes from creating it there.
  SET v_session_internal_id = 
    (
      SELECT session_internal_id FROM sessio WHERE session_id = p_session_id AND partition_id = v_partition_id
      WITH RR USE AND KEEP EXCLUSIVE LOCKS
    );

  -- If partitions are switching and the session was not found previously then check that the session does not exist in the 
  -- other partition, and block concurrent processes from creating it there.
  IF v_is_switching AND v_session_internal_id IS NULL THEN 
    SET v_session_internal_id = 
      (
        SELECT session_internal_id FROM sessio WHERE session_id = p_session_id AND partition_id != v_partition_id
        WITH RR USE AND KEEP EXCLUSIVE LOCKS
      );
  END IF;

  -- Exit with error if the session already exists.
  IF v_session_internal_id IS NOT NULL THEN
    SIGNAL SQLSTATE '72001' SET MESSAGE_TEXT = 'Session already exists';
  END IF;

  -- Add new session.
  SET p_session_config.change_ts = MIN(COALESCE(p_session_config.change_ts, v_utc), v_utc);
  SET v_session_internal_id = NEXT VALUE FOR session_internal_id;
  SET v_attribute_partition_num = MOD(NEXT VALUE FOR attribute_partition_num, v_num_attribute_partitions);
  INSERT INTO sessio
  (
    session_internal_id,
    partition_id,
    attribute_partition_num,
    created_ts,
    session_id
  )
  VALUES
    (
      v_session_internal_id,
      common.new_partition_id(v_is_switching, v_partition_id),
      v_attribute_partition_num,
      p_session_config.change_ts,
      p_session_id
    );

  -- Update session configuration.
  CALL aux_chsecf(p_session_id, p_session_config);

  -- Fail if the transaction has taken more than 5 seconds.
  IF CURRENT_TIMESTAMP - CURRENT_TIMEZONE > v_utc + 5 SECONDS THEN
    SIGNAL SQLSTATE '72009' SET MESSAGE_TEXT = 'Timeout';
  END IF;
END@
