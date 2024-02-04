-- Procedure ADMIN.MOVE_SESSIONS moves sessions to the new partition.
ALTER MODULE admin
ADD PROCEDURE move_sessions()
BEGIN
  DECLARE v_partition_id CHAR(1);
  DECLARE v_new_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_session_move_commit_limit SMALLINT;
  DECLARE v_session_move_sleep_seconds SMALLINT;
  DECLARE v_is_move_stop_requested BOOLEAN;
  DECLARE v_commit_count SMALLINT DEFAULT 0;

  DECLARE PROCEDURE get_control_info
  BEGIN
    SET (v_partition_id, v_session_move_commit_limit, v_session_move_sleep_seconds, v_is_move_stop_requested) =
      (
        SELECT
          active_partition_id, session_move_commit_limit, session_move_sleep_seconds, is_move_stop_requested
        FROM
          sesctl
        WITH RS
      );
    IF v_partition_id = v_new_partition_id THEN
      SIGNAL SQLSTATE '72091' SET MESSAGE_TEXT = 'Partition switch completed unexpectedly';
    END IF;
  END;

  -- Retrieve static control information.
  SET (v_partition_id, v_is_switching) =
    (SELECT active_partition_id, is_switching FROM sesctl WITH CS);

  -- Exit with error if switch is not started.
  IF NOT v_is_switching THEN
    SIGNAL SQLSTATE '72021' SET MESSAGE_TEXT = 'Switch is not started';
  END IF;

  -- Reset the move stop requested flag.
  UPDATE sesctl SET is_move_stop_requested = FALSE;

  -- Derive the new partition identifier, and get dynamic control information.
  SET v_new_partition_id = common.new_partition_id(TRUE, v_partition_id);
  CALL get_control_info;

  -- Move sessions (except deleted ones) from the active partition to the new partition...
  FOR r AS c1 CURSOR WITH HOLD FOR
    SELECT session_internal_id FROM sessio WHERE partition_id = v_partition_id AND deleted_ts IS NULL WITH CS
  DO
    -- Move session row to the new partition.
    UPDATE sessio
    SET
      partition_id = v_new_partition_id
    WHERE
      session_internal_id = r.session_internal_id AND
      partition_id = v_partition_id
    SKIP LOCKED;

    -- Check commit limit and perform commit control processing.
    SET v_commit_count = v_commit_count + 1;
    IF v_commit_count >= v_session_move_commit_limit THEN
      COMMIT;
      SET v_commit_count = 0;
      IF v_session_move_sleep_seconds > 0 THEN
        CALL dbms_lock.sleep(v_session_move_sleep_seconds);
      END IF;
      CALL get_control_info;
      IF v_is_move_stop_requested THEN
        RETURN 1;
      END IF;      
    END IF;
  END FOR;
END@
