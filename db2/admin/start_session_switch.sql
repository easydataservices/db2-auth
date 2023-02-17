-- Procedure ADMIN.START_SESSION_SWITCH initiates session partition switching.
ALTER MODULE admin
ADD PROCEDURE start_session_switch()
  AUTONOMOUS
BEGIN ATOMIC
  UPDATE sesctl
  SET
    is_switching = TRUE,
    switch_start_ts = CURRENT_TIMESTAMP - CURRENT_TIMEZONE
  WHERE
    NOT is_switching;
END@
