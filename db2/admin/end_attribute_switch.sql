-- Procedure ADMIN.END_ATTRIBUTE_SWITCH finalises attribute partition switching.
ALTER MODULE admin
ADD PROCEDURE end_attribute_switch()
  AUTONOMOUS
BEGIN
  DECLARE v_utc TIMESTAMP(0);
  DECLARE v_attribute_partition_id CHAR(1);
  DECLARE v_session_partition_id CHAR(1);
  DECLARE v_attribute_is_switching BOOLEAN;
  DECLARE v_session_is_switching BOOLEAN;
  DECLARE v_attribute_count BIGINT;

  -- Retrieve UTC timestamp and session partition control information.
  SET (v_utc, v_session_partition_id, v_session_is_switching, v_attribute_partition_id, v_attribute_is_switching) =
    (
      SELECT
        CURRENT_TIMESTAMP - CURRENT_TIMEZONE,
        active_partition_id,
        is_switching,
        attribute_active_partition_id,
        attribute_is_switching
      FROM
        sesctl
      WITH RS USE AND KEEP UPDATE LOCKS
    );

  -- Exit with error if switch is not started.
  IF NOT v_attribute_is_switching THEN
    SIGNAL SQLSTATE '72021' SET MESSAGE_TEXT = 'Switch is not started';
  END IF;

  -- Count all rows in the active partition (ignoring logically deleted attributes).
  SET v_attribute_count =
    (
      SELECT
        COUNT_BIG(*)
      FROM
        sesatt AS a
          LEFT OUTER JOIN
        (
          SELECT * FROM sessio WHERE partition_id = common.new_partition_id(v_session_is_switching, v_session_partition_id)
        ) AS s
          ON
            s.session_internal_id = a.session_internal_id AND
            s.deleted_ts IS NOT NULL
      WHERE
        a.partition_id = v_attribute_partition_id AND s.session_internal_id IS NOT NULL
      WITH CS
    );

  -- Exit with error if active partition is not empty.
  IF v_attribute_count > 0 THEN
    SIGNAL SQLSTATE '72022' SET MESSAGE_TEXT = 'Active partition is not empty';
  END IF;

  -- Update session control table to switch the active partition and disable switching.
  UPDATE sesctl
  SET
    attribute_active_partition_id = CASE attribute_active_partition_id WHEN 'A' THEN 'B' ELSE 'A' END,
    attribute_is_switching = FALSE,
    attribute_switch_start_ts = NULL;
END@
