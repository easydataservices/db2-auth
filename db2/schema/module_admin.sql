-- Module ADMIN contains housekeeping routines.
CREATE OR REPLACE MODULE admin;

-- Initiate session partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE start_session_switch();

-- Finalise session partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE end_session_switch();

-- Initiate attribute partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE start_attribute_switch();

-- Finalise attribute partition switching.
ALTER MODULE admin
PUBLISH PROCEDURE end_attribute_switch();
