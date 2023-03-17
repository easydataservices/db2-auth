# _AUTH Service installation instructions_

# Overview

## About
This document describes how to build an AUTH Service environment.

The AUTH Service consists of just 2 components:
1. Db2 schema
2. Java JAR file

## Prerequisites
The following prerequsites are not covered by this document:
1. Db2 for LUW version 11.5 (or later)
2. Apache Ant for building the JAR file

# Db2 schema creation

## Database
You will need a Db2 database connection to create the schema. If you have not created a database already, use the ``CREATE DATABASE`` command. For example, at its simplest:
``db2 create database MYDB``

> Note: You must be logged in with a user that has either SYSADM or SYSCTRL authorities to execute the ``CREATE DATABASE`` command. For example, you could use the Db2 instance owner.

Then connect to the database, e.g.:

``db2 connect to MYDB``

## Default schema
The default schema for the AUTH Service is ``AUTH``. If you want to use a different schema, edit the schema and path values in file ``set_env.sql`` before proceeding.

## Sequence of commands
Change to the ``db2`` directory, and execute the following commands in sequence to create the database objects and code modules:

```
# From db2 directory
db2 -stvf set_env.sql
db2 -stvf schema/storage.sql
db2 -stvf schema/module_common.sql
db2 -stvf schema/module_control.sql
db2 -stvf schema/module_session.sql
db2 -stvf schema/module_attributes.sql
db2 -stvf schema/module_admin.sql
db2 -td@ -f schema/common/new_partition_id.sql
db2 -td@ -f schema/common/expiry_ts.sql
db2 -td@ -f schema/common/check_json.sql
db2 -td@ -f schema/control/aux_chsecf.sql
db2 -td@ -f schema/control/add_session.sql
db2 -td@ -f schema/control/change_session_config.sql
db2 -td@ -f schema/control/change_session_id.sql
db2 -td@ -f schema/control/remove_session.sql
db2 -td@ -f schema/session/get_session.sql
db2 -td@ -f schema/attributes/get_attributes.sql
db2 -td@ -f schema/attributes/save_attributes.sql
db2 -td@ -f schema/admin/start_session_switch.sql
db2 -td@ -f schema/admin/end_session_switch.sql
db2 -td@ -f schema/admin/start_attribute_switch.sql
db2 -td@ -f schema/admin/end_attribute_switch.sql
```

## Uninstallation Sequence of commands

> Note: Only execute this section if you want to uninstall without dropping the database.

Change to the ``db2`` directory, and execute the following commands in sequence to create the database objects and code modules:

```
# From db2 directory
db2 -stvf set_env.sql
db2 drop module SESSION
db2 drop module CONTROL
db2 drop module ATTRIBUTES
db2 drop module COMMON
db2 drop module ADMIN
db2 drop sequence SESSION_INTERNAL_ID
db2 drop sequence ATTRIBUTE_PARTITION_NUM
db2 drop tablespace TS_SESSIO_DAT, TS_SESSIO_IDX, TS_SESSIO_LOB, TEMPSPACE_32K
db2 drop bufferpool BP_32K
db2 drop view SESSIO
db2 drop view SESATT
```

# Java

## Build the code
You can build the code using ``ant``. Change to the ``java`` directory first.

```
# From the java directory
ant -f build-db2-auth.xml
```

Expected output should end with a message that includes the words ``BUILD SUCCESSFUL``.
