-- Procedure COMMON.CHECK_JSON is a private routine to validate JSON input.
ALTER MODULE common
ADD PROCEDURE check_json(p_json VARCHAR(32000))
BEGIN
  DECLARE v_json_object VARCHAR(32020);

  IF p_json IS NOT NULL THEN
    SET v_json_object =
      JSON_OBJECT
      (
        KEY 'properties'
        VALUE p_json
        FORMAT JSON WITH UNIQUE KEYS
        RETURNING VARCHAR(32020)
      );
  END IF;
END@
