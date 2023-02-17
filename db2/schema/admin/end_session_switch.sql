-- Procedure ADMIN.END_SESSION_SWITCH finalises session partition switching.
ALTER MODULE admin
ADD PROCEDURE end_session_switch()
  AUTONOMOUS
BEGIN
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_session_count BIGINT;

  -- Retrieve UTC timestamp and session partition control information.
  SET (v_utc, v_partition_id, v_is_switching) =
    (
      SELECT CURRENT_TIMESTAMP - CURRENT_TIMEZONE, active_partition_id, is_switching FROM sesctl
      WITH RS USE AND KEEP UPDATE LOCKS
    );

  -- Exit with error if switch is not started.
  IF NOT v_is_switching THEN
    SIGNAL SQLSTATE '72021' SET MESSAGE_TEXT = 'Switch is not started';
  END IF;

  -- Count all rows in the active partition (ignoring logically deleted sessions).
  SET v_session_count = 
    (
      SELECT COUNT_BIG(*) FROM sessio WHERE partition_id = v_partition_id AND deleted_ts IS NULL WITH CS
    );

  -- Exit with error if active partition is not empty.
  IF v_session_count > 0 THEN
    SIGNAL SQLSTATE '72022' SET MESSAGE_TEXT = 'Active partition is not empty';
  END IF;

  -- Update session control table to switch the active partition and disable switching.
  UPDATE sesctl
  SET
    active_partition_id = CASE active_partition_id WHEN 'A' THEN 'B' ELSE 'A' END,
    is_switching = FALSE,
    switch_start_ts = NULL;
END@
