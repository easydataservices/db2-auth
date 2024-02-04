-- Module ADMIN contains housekeeping routines.
CREATE OR REPLACE MODULE admin;

-- Initiate session partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE start_session_switch();

-- Move sessions to the new partition
ALTER MODULE admin
PUBLISH PROCEDURE move_sessions();

-- Finalise session partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE end_session_switch();

-- Initiate attribute partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE start_attribute_switch();

-- Move attributes to the new partition
ALTER MODULE admin
PUBLISH PROCEDURE move_attributes();

-- Finalise attribute partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE end_attribute_switch();
