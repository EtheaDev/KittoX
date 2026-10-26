/*-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------*/

-- Oracle 19c/21c script: create the HELLOKITTO schema/user for the HelloKitto example.
--
-- Run this FIRST, connected as a privileged user (SYSTEM or SYS) to the PLUGGABLE
-- DATABASE (PDB) that will host the example, e.g. Oracle XE 21c -> xepdb1:
--
--   sqlplus system/<pwd>@localhost:1521/xepdb1  @HelloKitto_Oracle_CreateUser.sql
--
-- IMPORTANT (multitenant): the user must be a LOCAL user of the PDB. Do NOT run it
-- while connected to the CDB root (CDB$ROOT), or Oracle requires a C## prefix.
-- Check with:  SELECT SYS_CONTEXT('USERENV','CON_NAME') FROM DUAL;  -> must be XEPDB1.
--
-- The password below (12345) matches the FireDAC_Oracle / ODAC_Oracle connection in
-- Home\Metadata\Config.yaml. Change it here AND in Config.yaml if you want another.
--
-- After this script, connect AS HELLOKITTO and run, in order:
--   HelloKitto_Oracle_DDL.sql      (tables + constraints)
--   HelloKitto_Oracle_Data.sql     (demo data)

CREATE USER HELLOKITTO IDENTIFIED BY "12345"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION   TO HELLOKITTO;
GRANT CREATE TABLE     TO HELLOKITTO;
GRANT CREATE VIEW      TO HELLOKITTO;
GRANT CREATE SEQUENCE  TO HELLOKITTO;
GRANT CREATE PROCEDURE TO HELLOKITTO;
