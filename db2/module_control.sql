-- Module CONTROL contains routines for use by the session manager.
CREATE OR REPLACE MODULE control;

ALTER MODULE control
PUBLISH TYPE session_config AS ROW
(
  change_ts TIMESTAMP(0),
  auth_name VARCHAR(60),
  max_idle_minutes SMALLINT,
  properties_json VARCHAR(2000)
);

-- Add new session.
ALTER MODULE control
PUBLISH PROCEDURE add_session(p_session_id VARCHAR(60), p_session_config session_config);

-- Mark session authenticated.
ALTER MODULE control
PUBLISH PROCEDURE change_session_config(p_session_id VARCHAR(60), p_session_config session_config);

-- Mark session deleted.
ALTER MODULE control
PUBLISH PROCEDURE remove_session(p_session_id VARCHAR(60));

-- Change the session id.
ALTER MODULE control
PUBLISH PROCEDURE change_session_id(p_session_id VARCHAR(60), p_new_session_id VARCHAR(60));
