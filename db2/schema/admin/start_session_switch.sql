-- Procedure ADMIN.START_SESSION_SWITCH initiates session partition switching.
ALTER MODULE admin
ADD PROCEDURE start_session_switch()
  AUTONOMOUS
BEGIN ATOMIC
  DECLARE v_attribute_is_switching BOOLEAN;

  -- Check that an attribute switch is not started.
  SET v_attribute_is_switching = (SELECT attribute_is_switching FROM sesctl WITH RS USE AND KEEP UPDATE LOCKS);
  IF v_attribute_is_switching THEN
    SIGNAL SQLSTATE '72023' SET MESSAGE_TEXT = 'Session and attribute switch cannot run in parallel';
  END IF;

  -- Reset the move stop requested flag.
  UPDATE sesctl SET is_move_stop_requested = FALSE;

  -- Update the control table to start the session switch (if not already started).
  UPDATE sesctl
  SET
    is_switching = TRUE,
    switch_start_ts = CURRENT_TIMESTAMP - CURRENT_TIMEZONE
  WHERE
    NOT is_switching;
END@
