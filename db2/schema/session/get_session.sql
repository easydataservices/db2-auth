-- Procedure SESSION.GET_SESSION retrieves session details. 
ALTER MODULE session
ADD PROCEDURE get_session
(
  p_session_id VARCHAR(60),
  OUT p_session_info session_info
)
  AUTONOMOUS
BEGIN
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_max_idle_minutes SMALLINT;
  DECLARE v_max_authentication_minutes SMALLINT;

  -- Retrieve UTC timestamp and session partition control information.
  SET (v_utc, v_partition_id, v_is_switching, v_max_idle_minutes, v_max_authentication_minutes) =
    (
      SELECT 
        CURRENT_TIMESTAMP - CURRENT_TIMEZONE, active_partition_id, is_switching, max_idle_minutes, max_authentication_minutes
      FROM
        sesctl
      WITH CS
    );

  -- Look up session in the active partition, and block concurrent processes from accessing it there.
  SET p_session_info =
    (
      SELECT 
        created_ts,
        last_accessed_ts,
        last_authenticated_ts,
        COALESCE(max_idle_minutes, v_max_idle_minutes),
        v_max_authentication_minutes,
        expiry_ts,
        auth_name,
        properties_json,
        CASE WHEN auth_name IS NULL THEN FALSE ELSE TRUE END AS is_authenticated,
        CASE WHEN expiry_ts < v_utc THEN FALSE ELSE TRUE END AS is_expired,
        attribute_generation_id
      FROM 
        sessio
      WHERE
        session_id = p_session_id AND partition_id = v_partition_id AND deleted_ts IS NULL
      WITH RR USE AND KEEP EXCLUSIVE LOCKS
    );

  -- If partitions are switching...
  IF v_is_switching THEN 
    -- If the session was not found in the old partition then look up the session in the new partition, and block concurrent
    -- processes from accessing it there.
    IF p_session_info.created_ts IS NULL THEN
      SET p_session_info =
        (
          SELECT 
            created_ts,
            last_accessed_ts,
            last_authenticated_ts,
            COALESCE(max_idle_minutes, v_max_idle_minutes),
            v_max_authentication_minutes,
            expiry_ts,
            auth_name,
            properties_json,
            CASE WHEN auth_name IS NULL THEN FALSE ELSE TRUE END AS is_authenticated,
            CASE WHEN expiry_ts < v_utc THEN FALSE ELSE TRUE END AS is_expired,
            attribute_generation_id
          FROM 
            sessio
          WHERE
            session_id = p_session_id AND partition_id != v_partition_id AND deleted_ts IS NULL
          WITH RR USE AND KEEP EXCLUSIVE LOCKS
        );
    -- Otherwise move the session to the new partition.
    ELSE
      UPDATE sessio
      SET
        partition_id = common.new_partition_id(TRUE, v_partition_id)
      WHERE
        session_id = p_session_id AND partition_id = v_partition_id;
    END IF;
  END IF;

  -- Early out if session not found.
  IF p_session_info.created_ts IS NULL THEN
    RETURN;
  END IF;

  -- If the session is not expired then update the last accessed time.
  IF p_session_info.expiry_ts < v_utc  THEN
    IF v_is_switching THEN
      UPDATE sessio
      SET
        last_accessed_ts = v_utc
      WHERE
        session_id = p_session_id;
    ELSE
      UPDATE sessio
      SET
        last_accessed_ts = v_utc
      WHERE
        session_id = p_session_id AND partition_id = v_partition_id;
    END IF;
  END IF;
END@
