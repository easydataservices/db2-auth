-- Procedure CONTROL.CHANGE_SESSION_CONFIG changes authentication and related properties of a session.
ALTER MODULE control
ADD PROCEDURE change_session_config(p_session_id VARCHAR(60), p_session_config session_config)
  AUTONOMOUS
BEGIN
  DECLARE v_utc TIMESTAMP(0);

  -- Retrieve UTC timestamp.
  SET v_utc = CURRENT_TIMESTAMP - CURRENT_TIMEZONE;

  -- Call delegate auxiliary procedure.
  CALL aux_chsecf(p_session_id, p_session_config);

  -- Fail if the transaction has taken more than 5 seconds.
  IF CURRENT_TIMESTAMP - CURRENT_TIMEZONE > v_utc + 5 SECONDS THEN
    SIGNAL SQLSTATE '72009' SET MESSAGE_TEXT = 'Timeout';
  END IF;  
END@
