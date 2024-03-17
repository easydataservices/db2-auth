-- Module ATTRIBUTES contains routines for saving and retrieving session attributes.
CREATE OR REPLACE MODULE attributes;

ALTER MODULE attributes
PUBLISH TYPE session_attribute AS ROW
(
  attribute_name VARCHAR(240),
  object BLOB(2M)
);

ALTER MODULE attributes
PUBLISH TYPE session_attribute_array AS session_attribute ARRAY[];

-- Save session attributes.
ALTER MODULE attributes
PUBLISH PROCEDURE save_attributes
(
  p_session_id VARCHAR(60),
  p_session_attributes session_attribute_array
);

-- Retrieve session attributes for the specified session identifier (P_SESSION_ID). The specified P_SINCE_GENERATION_ID value
-- determines which attributes are returned. When 0, all attribute objects are returned (i.e. full load); when greater than 0,
-- only attributes with a generation later than P_SINCE_GENERATION_ID are returned (i.e. delta load). Deleted attributes are
-- returned with a NULL object.
ALTER MODULE attributes
PUBLISH PROCEDURE get_attributes
(
  p_session_id VARCHAR(60),
  p_since_generation_id INTEGER,
  OUT p_session_attributes session_attribute_array
);
