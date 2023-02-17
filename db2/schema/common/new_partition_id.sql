-- Function COMMON.NEW_PARTITION_ID returns the target partition id.
ALTER MODULE common
ADD FUNCTION new_partition_id(p_is_switching BOOLEAN, p_partition_id CHAR(1)) RETURNS CHAR(1)
  CONTAINS SQL
  DETERMINISTIC
  NO EXTERNAL ACTION
BEGIN
  RETURN
    CASE
      WHEN p_is_switching THEN CASE p_partition_id WHEN 'A' THEN 'B' ELSE 'A' END
      ELSE p_partition_id
    END;      
END@
