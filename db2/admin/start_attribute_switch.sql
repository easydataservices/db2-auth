-- Procedure ADMIN.START_ATTRIBUTE_SWITCH initiates attribute partition switching.
ALTER MODULE admin
ADD PROCEDURE start_attribute_switch()
  AUTONOMOUS
BEGIN ATOMIC
  UPDATE sesctl
  SET
    attribute_is_switching = TRUE,
    attribute_switch_start_ts = CURRENT_TIMESTAMP - CURRENT_TIMEZONE
  WHERE
    NOT attribute_is_switching;
END@
