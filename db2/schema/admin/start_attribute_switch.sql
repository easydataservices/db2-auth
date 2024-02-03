-- Procedure ADMIN.START_ATTRIBUTE_SWITCH initiates attribute partition switching.
ALTER MODULE admin
ADD PROCEDURE start_attribute_switch()
  AUTONOMOUS
BEGIN ATOMIC
  DECLARE v_is_switching BOOLEAN;

  SET v_is_switching = (SELECT is_switching FROM sesctl WITH RS USE AND KEEP UPDATE LOCKS);
  IF v_is_switching THEN
    SIGNAL SQLSTATE '72023' SET MESSAGE_TEXT = 'Session and attribute switch cannot run in parallel';
  END IF;

  UPDATE sesctl
  SET
    attribute_is_switching = TRUE,
    attribute_switch_start_ts = CURRENT_TIMESTAMP - CURRENT_TIMEZONE
  WHERE
    NOT attribute_is_switching;
END@
