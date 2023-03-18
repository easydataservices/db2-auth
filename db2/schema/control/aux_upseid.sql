-- Procedure CONTROL.AUX_UPSEID is an auxiliary (private) routine to update a session identifier. The update fails if
-- a lock cannot be acquired within 1 second.
ALTER MODULE control
ADD PROCEDURE aux_upseid(p_session_internal_id BIGINT, p_partition_id CHAR(1), p_new_session_id VARCHAR(60))
BEGIN
  UPDATE sessio
  SET
    session_id = p_new_session_id
  WHERE
    session_internal_id = p_session_internal_id AND partition_id = p_partition_id
  WAIT 1;
END@
