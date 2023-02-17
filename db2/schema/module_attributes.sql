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

ALTER MODULE attributes
PUBLISH PROCEDURE save_attributes
(
  p_session_id VARCHAR(60),
  p_session_attributes session_attribute_array
);

ALTER MODULE attributes
PUBLISH PROCEDURE get_attributes
(
  p_session_id VARCHAR(60),
  p_since_generation_id INTEGER,
  OUT p_session_attributes session_attribute_array
);
