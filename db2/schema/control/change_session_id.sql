-- Procedure CONTROL.CHANGE_SESSION_ID changes the session id
ALTER MODULE control
ADD PROCEDURE change_session_id(p_session_id VARCHAR(60), p_new_session_id VARCHAR(60))
  AUTONOMOUS
BEGIN
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_session_internal_id BIGINT;
  DECLARE v_is_already_used BOOLEAN;

  -- Retrieve UTC timestamp and session partition control information.
  SET (v_utc, v_partition_id, v_is_switching) =
    (SELECT CURRENT_TIMESTAMP - CURRENT_TIMEZONE, active_partition_id, is_switching FROM sesctl WITH CS);

  -- Validate inputs.
  IF p_new_session_id = ''  THEN
    SIGNAL SQLSTATE '72014' SET MESSAGE_TEXT = 'New SESSION_ID cannot be empty';    
  END IF;

  -- Look up the session in the active partition, and block concurrent processes from accessing it.
  SET v_session_internal_id =
    (
      SELECT
        session_internal_id
      FROM
        sessio 
      WHERE
        session_id = p_session_id AND partition_id = v_partition_id AND deleted_ts IS NULL
      WITH RR USE AND KEEP EXCLUSIVE LOCKS
    );

  -- If partitions are switching and the session was not found previously then look up the session in the other partition,
  -- and block concurrent processes from accessing it.
  IF v_is_switching AND v_session_internal_id IS NULL THEN 
    SET v_session_internal_id = 
      (
        SELECT
          session_internal_id
        FROM
          sessio 
        WHERE
          session_id = p_session_id AND partition_id != v_partition_id AND deleted_ts IS NULL
        WITH RR USE AND KEEP EXCLUSIVE LOCKS
      );
  END IF;

  -- Exit with error if the session does not exist.
  IF v_session_internal_id IS NULL THEN
    SIGNAL SQLSTATE '72002' SET MESSAGE_TEXT = 'Session does not exist';
  END IF;

  -- Look up the new session in the active partition, and block concurrent processes from creating it.
  SET v_is_already_used =
    (
      SELECT
        TRUE
      FROM
        sessio 
      WHERE
        session_id = p_new_session_id AND partition_id = v_partition_id AND deleted_ts IS NULL
      WITH RR USE AND KEEP EXCLUSIVE LOCKS
    );

  -- If partitions are switching and the new session was not found previously then look up the new session in the other
  -- partition, and block concurrent processes from creating it.
  IF v_is_switching AND v_is_already_used IS NULL THEN 
    SET v_is_already_used = 
      (
        SELECT
          TRUE
        FROM
          sessio 
        WHERE
          session_id = p_new_session_id AND partition_id != v_partition_id AND deleted_ts IS NULL
        WITH RR USE AND KEEP EXCLUSIVE LOCKS
      );
  END IF;

  -- Exit with error if the new session already exists.
  IF v_is_already_used IS TRUE THEN
    SIGNAL SQLSTATE '72001' SET MESSAGE_TEXT = 'Session already exists';
  END IF;

  -- Update session.
  IF v_is_switching THEN
    UPDATE sessio
    SET
      partition_id = common.new_partition_id(TRUE, v_partition_id),
      session_id = p_new_session_id
    WHERE
      session_internal_id = v_session_internal_id;
  ELSE
    UPDATE sessio
    SET
      session_id = p_new_session_id
    WHERE
      session_internal_id = v_session_internal_id AND partition_id = v_partition_id;
  END IF;

  -- Fail if the transaction has taken more than 5 seconds.
  IF CURRENT_TIMESTAMP - CURRENT_TIMEZONE > v_utc + 5 SECONDS THEN
    SIGNAL SQLSTATE '72009' SET MESSAGE_TEXT = 'Timeout';
  END IF;
END@
