-- Procedure CONTROL.AUX_CHSECF is an auxiliary (private) routine to change authentication and related properties
-- of a session.
ALTER MODULE control
ADD PROCEDURE aux_chsecf(p_session_id VARCHAR(60), p_session_config session_config)
BEGIN
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_partition_id CHAR(1);
  DECLARE v_is_switching BOOLEAN;
  DECLARE v_session_internal_id BIGINT;
  DECLARE v_auth_name VARCHAR(60);
  DECLARE v_last_accessed_ts TIMESTAMP(0);
  DECLARE v_last_authenticated_ts TIMESTAMP(0);
  DECLARE v_expiry_ts TIMESTAMP(0);

  -- Retrieve UTC timestamp and session partition control information.
  SET (v_utc, v_partition_id, v_is_switching) =
    (SELECT CURRENT_TIMESTAMP - CURRENT_TIMEZONE, active_partition_id, is_switching FROM sesctl WITH CS);

  -- Look up session in the active partition, and block concurrent processes from accessing it there.
  SET (v_session_internal_id, v_auth_name, v_last_accessed_ts, v_last_authenticated_ts) = 
    (
      SELECT
        session_internal_id, auth_name, last_accessed_ts, last_authenticated_ts
      FROM
        sessio
      WHERE
        session_id = p_session_id AND partition_id = v_partition_id AND deleted_ts IS NULL
      WITH RR USE AND KEEP EXCLUSIVE LOCKS
    );

  -- If the session was not found and partitions are switching then look up the session in the new partition, and block
  -- concurrent processes from accessing it there.
  IF v_is_switching AND v_session_internal_id IS NULL THEN 
    SET (v_session_internal_id, v_auth_name, v_last_accessed_ts, v_last_authenticated_ts) = 
      (
        SELECT
          session_internal_id, auth_name, last_accessed_ts, last_authenticated_ts
        FROM
          sessio
        WHERE
          session_id = p_session_id AND partition_id != v_partition_id AND deleted_ts IS NULL
        WITH RR USE AND KEEP EXCLUSIVE LOCKS
      );
  END IF;

  -- Exit with error if the session does not exist.
  IF v_session_internal_id IS NULL THEN
    SIGNAL SQLSTATE '72002' SET MESSAGE_TEXT = 'Session does not exist';
  END IF;

  -- Validate inputs.
  IF p_session_config.auth_name != v_auth_name  THEN
    SIGNAL SQLSTATE '72011' SET MESSAGE_TEXT = 'AUTH_NAME cannot be changed';    
  END IF;

  IF p_session_config.auth_name = '' THEN
    SIGNAL SQLSTATE '72012' SET MESSAGE_TEXT = 'AUTH_NAME cannot be empty';    
  END IF;

  IF NOT p_session_config.max_idle_minutes BETWEEN 1 AND 1440 THEN
    SIGNAL SQLSTATE '72013' SET MESSAGE_TEXT = 'MAX_IDLE_MINUTES out of range';
  END IF;

  CALL common.check_json(p_session_config.properties_json);

  -- Calculate derived values.
  SET p_session_config.change_ts = MIN(COALESCE(p_session_config.change_ts, v_utc), v_utc);
  SET v_last_accessed_ts = MAX(p_session_config.change_ts, v_last_accessed_ts);
  SET v_auth_name = COALESCE(v_auth_name, RTRIM(p_session_config.auth_name));
  IF v_auth_name IS NOT NULL THEN
    SET v_last_authenticated_ts = COALESCE(MAX(p_session_config.change_ts, v_last_authenticated_ts), v_utc);
  END IF;
  SET v_expiry_ts = common.expiry_ts(p_session_config.max_idle_minutes, v_last_accessed_ts, v_last_authenticated_ts);

  -- Update the session.
  IF v_is_switching THEN
    UPDATE sessio
    SET
      last_accessed_ts = v_last_accessed_ts,
      last_authenticated_ts = v_last_authenticated_ts,
      max_idle_minutes = p_session_config.max_idle_minutes,
      expiry_ts = v_expiry_ts,
      auth_name = v_auth_name,
      properties_json = COALESCE(TRIM(p_session_config.properties_json), properties_json)
    WHERE 
      session_internal_id = v_session_internal_id;
  ELSE
    UPDATE sessio
    SET
      last_accessed_ts = v_last_accessed_ts,
      last_authenticated_ts = v_last_authenticated_ts,
      max_idle_minutes = p_session_config.max_idle_minutes,
      expiry_ts = v_expiry_ts,
      auth_name = v_auth_name,
      properties_json = COALESCE(TRIM(p_session_config.properties_json), properties_json)
    WHERE
      session_internal_id = v_session_internal_id AND partition_id = v_partition_id;
  END IF;
END@
