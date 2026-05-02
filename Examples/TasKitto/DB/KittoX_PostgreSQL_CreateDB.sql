-- KittoX PostgreSQL — Server Setup
-- Run this script connected as a superuser or a role with CREATEROLE + CREATEDB.
-- NOTE: CREATE DATABASE cannot run inside a transaction block;
--       use psql or pgAdmin to execute this file.
--
-- Usage:
--   psql -U postgres -h localhost -f KittoX_PostgreSQL_CreateDB.sql

/******************** ROLES **********************/

CREATE ROLE kittox_admin WITH
  LOGIN
  PASSWORD 'kittox_admin_2026!'
  CREATEDB
  CREATEROLE;

-- Application roles (no CREATEDB / CREATEROLE — least privilege)
CREATE ROLE taskitto_app WITH
  LOGIN
  PASSWORD 'taskitto_app_2026!';

CREATE ROLE hellokitto_app WITH
  LOGIN
  PASSWORD 'hellokitto_app_2026!';

/******************** DATABASES ******************/

CREATE DATABASE taskitto
  WITH
    OWNER            = kittox_admin
    ENCODING         = 'UTF8'
    CONNECTION LIMIT = -1;

CREATE DATABASE hellokitto
  WITH
    OWNER            = kittox_admin
    ENCODING         = 'UTF8'
    CONNECTION LIMIT = -1;

/******************** NOTES **********************
After creating the databases, connect to each one
as kittox_admin and run the respective DDL scripts:

  \c taskitto
  \i TasKitto_PostgreSQL_DDL.sql

  \c hellokitto
  \i HelloKitto_PostgreSQL_DDL.sql

Schema privileges (search_path, GRANT USAGE, etc.)
are set inside each DDL script.
**************************************************/
