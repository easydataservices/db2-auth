-- Procedure CONTROL.REMOVE_SESSION marks a session deleted.
ALTER MODULE control
ADD PROCEDURE remove_session(p_session_id VARCHAR(60))
  AUTONOMOUS
BEGIN
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_session_internal_id BIGINT;

  -- Retrieve UTC timestamp and session partition control information.
  SET (v_utc, v_partition_id, v_is_switching) =
    (SELECT CURRENT_TIMESTAMP - CURRENT_TIMEZONE, active_partition_id, is_switching FROM sesctl WITH CS);

  -- Look up session in the active partition, and block concurrent processes from accessing it there.
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

  -- If the session was not found and partitions are switching then look up the session in the new partition, and block
  -- concurrent processes from accessing it there.
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

  -- Mark the session deleted.
  IF v_is_switching THEN
    UPDATE sessio
    SET
      deleted_ts = v_utc
    WHERE
      session_internal_id = v_session_internal_id;
  ELSE
    UPDATE sessio
    SET
      deleted_ts = v_utc
    WHERE
      session_internal_id = v_session_internal_id AND partition_id = v_partition_id;
  END IF;

  -- Fail if the transaction has taken more than 5 seconds.
  IF CURRENT_TIMESTAMP - CURRENT_TIMEZONE > v_utc + 5 SECONDS THEN
    SIGNAL SQLSTATE '72009' SET MESSAGE_TEXT = 'Timeout';
  END IF;
END@
