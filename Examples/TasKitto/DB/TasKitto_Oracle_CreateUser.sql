-- Oracle 19c/21c script: create the TASKITTO schema/user for the TasKitto example.
--
-- Run this FIRST, connected as a privileged user (SYSTEM or SYS) to the PLUGGABLE
-- DATABASE (PDB) that will host the example, e.g. Oracle XE 21c -> xepdb1:
--
--   sqlplus system/<pwd>@localhost:1521/xepdb1  @TasKitto_Oracle_CreateUser.sql
--
-- IMPORTANT (multitenant): the user must be a LOCAL user of the PDB. Do NOT run it
-- while connected to the CDB root (CDB$ROOT), or Oracle requires a C## prefix.
-- Check with:  SELECT SYS_CONTEXT('USERENV','CON_NAME') FROM DUAL;  -> must be XEPDB1.
--
-- The password below (12345) matches the FireDAC_Oracle / ODAC_Oracle connection in
-- Home\Metadata\Config.yaml. Change it here AND in Config.yaml if you want another.
--
-- After this script, connect AS TASKITTO and run, in order:
--   TasKitto_Oracle_DDL.sql        (tables + foreign keys + dashboard views)
--   TasKitto_Oracle_Data.sql       (demo data)
--   TasKitto_Oracle_ShiftDates.sql (re-centre the demo dates around today)

CREATE USER TASKITTO IDENTIFIED BY "12345"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION   TO TASKITTO;
GRANT CREATE TABLE     TO TASKITTO;
GRANT CREATE VIEW      TO TASKITTO;
GRANT CREATE SEQUENCE  TO TASKITTO;
GRANT CREATE PROCEDURE TO TASKITTO;
