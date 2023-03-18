-- Procedure CONTROL.CHANGE_SESSION_ID changes the session id
ALTER MODULE control
ADD PROCEDURE change_session_id(p_session_id VARCHAR(60), p_new_session_id VARCHAR(60))
  AUTONOMOUS
BEGIN
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_session_internal_id BIGINT;

  DECLARE CONTINUE HANDLER FOR SQLSTATE '23505', SQLSTATE '23513'
  BEGIN
    SIGNAL SQLSTATE '72004' SET MESSAGE_TEXT = 'Session identifier already in use';
  END;

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

  -- Update session.
  -- Called procedures fail if locks cannot be acquired within 1 second. This avoids possible deadlock contention with
  -- other processes.
  IF v_is_switching THEN
    -- Move session to old partition.
    CALL aux_upsepa(v_session_internal_id, v_partition_id);

   -- Update session identifier. Fails if another session is using the identifier in the old partition.
    CALL aux_upseid(v_session_internal_id, v_partition_id, p_new_session_id);

   -- Move session to new partition. Fails if another session is using the identifier in the new partition.
    CALL aux_upsepa(v_session_internal_id, common.new_partition_id(TRUE, v_partition_id));    
  ELSE
   -- Update session identifier. Fails if another session is using the identifier in the current partition.
    CALL aux_upseid(v_session_internal_id, v_partition_id, p_new_session_id);
  END IF;

  -- Fail if the transaction has taken more than 5 seconds.
  IF CURRENT_TIMESTAMP - CURRENT_TIMEZONE > v_utc + 5 SECONDS THEN
    SIGNAL SQLSTATE '72009' SET MESSAGE_TEXT = 'Timeout';
  END IF;
END@
