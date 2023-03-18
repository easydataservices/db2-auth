-- Procedure CONTROL.AUX_UPSEPA is an auxiliary (private) routine to update (move) the session partition. The update fails if
-- a lock cannot be acquired within 1 second.
ALTER MODULE control
ADD PROCEDURE aux_upsepa(p_session_internal_id BIGINT, p_new_partition_id CHAR(1))
BEGIN
  UPDATE sessio
  SET
    partition_id = p_new_partition_id
  WHERE
    session_internal_id = p_session_internal_id
  WAIT 1;
END@
