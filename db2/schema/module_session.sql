-- Module SESSION contains routines for retrieving session details.
CREATE OR REPLACE MODULE session;

ALTER MODULE session
PUBLISH TYPE session_info AS ROW
( 
  created_ts TIMESTAMP(0),
  last_accessed_ts TIMESTAMP(0),
  last_authenticated_ts TIMESTAMP(0),
  max_idle_minutes SMALLINT,
  max_authentication_minutes SMALLINT,
  expiry_ts TIMESTAMP(0),
  auth_name VARCHAR(60),
  properties_json VARCHAR(2000),
  is_authenticated BOOLEAN,
  is_expired BOOLEAN,
  attribute_generation_id INTEGER
);

-- Retrieve session informaation
ALTER MODULE session
PUBLISH PROCEDURE get_session
(
  p_session_id VARCHAR(60),
  OUT p_session_info session_info
);
