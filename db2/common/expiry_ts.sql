-- Function COMMON.EXPIRY_TS returns the expiry timestamp calculated from the inputs.
ALTER MODULE common
ADD FUNCTION expiry_ts
(
  p_max_idle_minutes SMALLINT,
  p_last_accessed_ts TIMESTAMP(0),
  p_last_authenticated_ts TIMESTAMP(0)
) RETURNS TIMESTAMP(0)
BEGIN
  DECLARE v_max_idle_minutes SMALLINT;
  DECLARE v_max_authentication_minutes SMALLINT;
  DECLARE v_authentication_expiry_ts TIMESTAMP(0);
  DECLARE v_idle_expiry_ts TIMESTAMP(0);

  SET (v_max_idle_minutes, v_max_authentication_minutes) =
    (SELECT max_idle_minutes, max_authentication_minutes FROM sesctl WITH CS);
  SET v_authentication_expiry_ts = p_last_authenticated_ts + v_max_authentication_minutes MINUTES;
  SET v_idle_expiry_ts = p_last_accessed_ts + COALESCE(p_max_idle_minutes, v_max_idle_minutes) MINUTES;
  RETURN
    CASE
      WHEN v_idle_expiry_ts IS NULL THEN v_authentication_expiry_ts
      WHEN v_authentication_expiry_ts IS NULL THEN v_idle_expiry_ts
      ELSE MIN(v_authentication_expiry_ts, v_idle_expiry_ts)
    END;
END@
