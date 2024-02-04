-- Module ADMIN contains housekeeping routines.
CREATE OR REPLACE MODULE admin;

-- Initiate session partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE start_session_switch();

-- Move sessions to the new partition
ALTER MODULE admin
PUBLISH PROCEDURE move_sessions();

-- Return count of sessions that have mot been moved to the new partition
ALTER MODULE admin
PUBLISH FUNCTION unmoved_sessions_count() RETURNS BIGINT;

-- Finalise session partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE end_session_switch();

-- Initiate attribute partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE start_attribute_switch();

-- Move attributes to the new partition
ALTER MODULE admin
PUBLISH PROCEDURE move_attributes();

-- Return count of attributes that have mot been moved to the new partition
ALTER MODULE admin
PUBLISH FUNCTION unmoved_attributes_count() RETURNS BIGINT;

-- Finalise attribute partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE end_attribute_switch();
