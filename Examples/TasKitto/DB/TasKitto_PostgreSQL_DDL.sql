-- TasKitto PostgreSQL DDL
-- Generated: 2026-04-27
--
-- IMPORTANT: Tables and columns are created WITHOUT quoted identifiers.
-- PostgreSQL folds unquoted identifiers to lowercase automatically.
-- KittoX also generates SQL with unquoted identifiers (uppercase from model YAML),
-- which PostgreSQL folds to lowercase consistently → no mismatch.
--
-- Usage: psql -d <database> -f TasKitto_PostgreSQL_DDL.sql

CREATE SCHEMA IF NOT EXISTS taskitto;

/******************** TABLES **********************/

CREATE TABLE taskitto.kitto_users
(
  user_name varchar(32) NOT NULL,
  password_hash varchar(60),
  is_active boolean NOT NULL DEFAULT TRUE,
  first_name varchar(50),
  last_name varchar(50),
  email_address varchar(100) NOT NULL,
  must_change_password boolean NOT NULL DEFAULT FALSE,
  CONSTRAINT pk_kitto_users PRIMARY KEY (user_name)
);

-- Standard KittoX ACL tables, read by both AccessControl: DB (TKDBAccessController)
-- and AccessControl: JWT (TKJWTAccessController, snapshotted at login).
-- Schema is fixed by the default SQL queries in Source/Kitto.AccessControl.DB.pas;
-- override via AccessControl/ReadPermissionsCommandText / ReadRolesCommandText if needed.

CREATE TABLE taskitto.kitto_user_roles
(
  user_name varchar(50) NOT NULL,
  role_name varchar(50) NOT NULL,
  CONSTRAINT pk_kitto_user_roles PRIMARY KEY (user_name, role_name)
);

CREATE TABLE taskitto.kitto_permissions
(
  resource_uri_pattern varchar(200) NOT NULL,
  grantee_name varchar(50) NOT NULL,
  access_modes varchar(100) NOT NULL,
  grant_value varchar(50) NOT NULL,
  CONSTRAINT pk_kitto_permissions PRIMARY KEY (resource_uri_pattern, grantee_name, access_modes)
);

CREATE TABLE taskitto.customer
(
  customer_id varchar(32) NOT NULL,
  customer_name varchar(40) NOT NULL,
  address varchar(60),
  city varchar(60),
  phone varchar(20),
  email varchar(60),
  status varchar(10),
  CONSTRAINT pk_customer PRIMARY KEY (customer_id)
);

CREATE TABLE taskitto.employee
(
  employee_id varchar(32) NOT NULL,
  employee_name varchar(40) NOT NULL,
  employee_type varchar(20),
  CONSTRAINT pk_employee PRIMARY KEY (employee_id)
);

CREATE TABLE taskitto.operator_role
(
  role_id varchar(32) NOT NULL,
  role_name varchar(20) NOT NULL,
  fee double precision,
  CONSTRAINT pk_operator_role PRIMARY KEY (role_id)
);

CREATE TABLE taskitto.project
(
  project_id varchar(32) NOT NULL,
  project_name varchar(40) NOT NULL,
  customer_id varchar(32) NOT NULL,
  status varchar(12),
  CONSTRAINT pk_project PRIMARY KEY (project_id)
);

CREATE TABLE taskitto.phase
(
  phase_id varchar(32) NOT NULL,
  phase_name varchar(40) NOT NULL,
  project_id varchar(32) NOT NULL,
  start_date date,
  end_date date,
  status varchar(12),
  CONSTRAINT pk_phase PRIMARY KEY (phase_id)
);

CREATE TABLE taskitto.activity_type
(
  type_id varchar(32) NOT NULL,
  type_name varchar(20) NOT NULL,
  CONSTRAINT pk_activity_type PRIMARY KEY (type_id)
);

CREATE TABLE taskitto.activity
(
  activity_id varchar(32) NOT NULL,
  description varchar(80) NOT NULL,
  phase_id varchar(32) NOT NULL,
  employee_id varchar(32) NOT NULL,
  role_id varchar(32) NOT NULL,
  type_id varchar(32) NOT NULL,
  activity_date date NOT NULL,
  start_time time,
  end_time time,
  status varchar(12),
  CONSTRAINT pk_activity PRIMARY KEY (activity_id)
);

/********************* FOREIGN KEYS **********************/

ALTER TABLE taskitto.activity ADD CONSTRAINT dt_activity_phase
  FOREIGN KEY (phase_id) REFERENCES taskitto.phase (phase_id);

ALTER TABLE taskitto.activity ADD CONSTRAINT fk_activity_activity_type
  FOREIGN KEY (type_id) REFERENCES taskitto.activity_type (type_id);

ALTER TABLE taskitto.activity ADD CONSTRAINT fk_activity_employee
  FOREIGN KEY (employee_id) REFERENCES taskitto.employee (employee_id);

ALTER TABLE taskitto.activity ADD CONSTRAINT fk_activity_operator_role
  FOREIGN KEY (role_id) REFERENCES taskitto.operator_role (role_id);

ALTER TABLE taskitto.phase ADD CONSTRAINT dt_phase_project
  FOREIGN KEY (project_id) REFERENCES taskitto.project (project_id);

ALTER TABLE taskitto.project ADD CONSTRAINT dt_project_customer
  FOREIGN KEY (customer_id) REFERENCES taskitto.customer (customer_id);

/********************* VIEWS **********************/

-- Used by ACTIVITY_BY_TYPE model (no PhysicalName → view name must be activity_by_type)
CREATE VIEW taskitto.activity_by_type AS
SELECT
  CAST(AVG(EXTRACT(EPOCH FROM (a.end_time - a.start_time)) / 3600.0) AS DECIMAL(8,4)) AS duration,
  t.type_name
FROM taskitto.activity a
JOIN taskitto.activity_type t ON a.type_id = t.type_id
GROUP BY t.type_name;

-- Used by ACTIVITY_BY_STATUS model (PhysicalName: VW_ACTIVITY_BY_STATUS)
CREATE VIEW taskitto.vw_activity_by_status AS
SELECT
  a.status,
  COUNT(*) AS activity_count,
  COALESCE(SUM(EXTRACT(EPOCH FROM (a.end_time - a.start_time)) / 3600.0), 0) AS total_hours
FROM taskitto.activity a
WHERE a.activity_date >= DATE_TRUNC('month', CURRENT_DATE)
  AND a.activity_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
GROUP BY a.status;

-- Used by ACTIVITY_DAILY_RANGE model (PhysicalName: VW_ACTIVITY_DAILY_RANGE)
CREATE VIEW taskitto.vw_activity_daily_range AS
SELECT
  a.activity_date,
  COUNT(*) AS activity_count,
  COALESCE(SUM(EXTRACT(EPOCH FROM (a.end_time - a.start_time)) / 3600.0), 0) AS total_hours
FROM taskitto.activity a
WHERE a.activity_date >= CURRENT_DATE - INTERVAL '15 days'
  AND a.activity_date <= CURRENT_DATE + INTERVAL '15 days'
GROUP BY a.activity_date;

-- Used by KPI_MONTHLY model (PhysicalName: VW_KPI_MONTHLY)
CREATE VIEW taskitto.vw_kpi_monthly AS
SELECT
  (SELECT COUNT(*) FROM taskitto.activity
   WHERE activity_date >= DATE_TRUNC('month', CURRENT_DATE)
     AND activity_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
  ) AS activity_count,
  (SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0), 0)
   FROM taskitto.activity
   WHERE activity_date >= DATE_TRUNC('month', CURRENT_DATE)
     AND activity_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
  ) AS total_hours,
  (SELECT COUNT(*) FROM taskitto.project WHERE status = 'Open') AS active_projects,
  (SELECT COUNT(DISTINCT p.customer_id)
   FROM taskitto.activity a
   INNER JOIN taskitto.phase ph ON ph.phase_id = a.phase_id
   INNER JOIN taskitto.project p ON p.project_id = ph.project_id
   WHERE a.activity_date >= DATE_TRUNC('month', CURRENT_DATE)
     AND a.activity_date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'
  ) AS active_customers;
