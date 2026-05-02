-- HelloKitto PostgreSQL DDL
-- Generated: 2026-04-27
--
-- IMPORTANT: Tables and columns are created WITHOUT quoted identifiers.
-- PostgreSQL folds unquoted identifiers to lowercase automatically.
-- KittoX also generates SQL with unquoted identifiers (uppercase from model YAML),
-- which PostgreSQL folds to lowercase consistently → no mismatch.
--
-- Boolean columns (kitto_users.is_active / .must_change_password,
-- invitation.accepted) use the native PostgreSQL boolean type. The login query
-- in Config.yaml and the framework default Auth.DB queries use the %DB.TRUE% /
-- %DB.FALSE% macros so they work cross-dialect.
--
-- Usage: psql -d <database> -f HelloKitto_PostgreSQL_DDL.sql

CREATE SCHEMA IF NOT EXISTS hellokitto;

/******************** TABLES **********************/

CREATE TABLE hellokitto.hair
(
  hair_id     varchar(32) NOT NULL,
  hair_color  varchar(80) NOT NULL,
  CONSTRAINT pk_hair PRIMARY KEY (hair_id)
);

CREATE TABLE hellokitto.girl
(
  girl_id     varchar(32) NOT NULL,
  girl_name   varchar(40) NOT NULL,
  age         integer,
  hair_id     varchar(32) NOT NULL,
  phone       varchar(16),
  CONSTRAINT pk_girl PRIMARY KEY (girl_id)
);

CREATE TABLE hellokitto.doll
(
  doll_id      varchar(32) NOT NULL,
  doll_name    varchar(40) NOT NULL,
  date_bought  date,
  hair_id      varchar(32),
  dress_size   varchar(4),
  mom_id       varchar(32) NOT NULL,
  aspect       varchar(1024),
  picture      bytea,
  picture_file varchar(200),
  CONSTRAINT pk_doll PRIMARY KEY (doll_id)
);

CREATE TABLE hellokitto.party
(
  party_id    varchar(32) NOT NULL,
  party_name  varchar(40) NOT NULL,
  party_date  date NOT NULL,
  party_time  time NOT NULL,
  address     varchar(256) NOT NULL,
  CONSTRAINT pk_party PRIMARY KEY (party_id)
);

CREATE TABLE hellokitto.invitation
(
  invitation_id varchar(32) NOT NULL,
  party_id      varchar(32) NOT NULL,
  invitee_id    varchar(32) NOT NULL,
  accepted      boolean,
  CONSTRAINT pk_invitation PRIMARY KEY (invitation_id)
);

CREATE TABLE hellokitto.kitto_users
(
  user_name             varchar(32) NOT NULL,
  password_hash         varchar(60),
  email_address         varchar(100),
  must_change_password  boolean NOT NULL DEFAULT FALSE,
  is_active             boolean NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_kitto_users PRIMARY KEY (user_name)
);

/********************* FOREIGN KEYS **********************/

ALTER TABLE hellokitto.doll ADD CONSTRAINT dt_doll_mom
  FOREIGN KEY (mom_id) REFERENCES hellokitto.girl (girl_id);

ALTER TABLE hellokitto.doll ADD CONSTRAINT fk_doll_hair
  FOREIGN KEY (hair_id) REFERENCES hellokitto.hair (hair_id);

ALTER TABLE hellokitto.girl ADD CONSTRAINT fk_girl_hair
  FOREIGN KEY (hair_id) REFERENCES hellokitto.hair (hair_id);

ALTER TABLE hellokitto.invitation ADD CONSTRAINT dt_invitation_party
  FOREIGN KEY (party_id) REFERENCES hellokitto.party (party_id);

ALTER TABLE hellokitto.invitation ADD CONSTRAINT fk_invitation_girl
  FOREIGN KEY (invitee_id) REFERENCES hellokitto.girl (girl_id);