-- Oracle 19c DDL script for the HelloKitto example.
--
-- Dialect notes (see TEFOracleDBEngineType in Source/EF/EF.DB.pas):
--   * Boolean columns use NUMBER(1) with 0/1 (Oracle pre-23c has no native
--     BOOLEAN). The %DB.TRUE% / %DB.FALSE% macros expand to 1 / 0 on Oracle, so
--     application SQL (e.g. the login query) stays portable.
--   * Firebird/SQL Server 'time' has no Oracle equivalent: PARTY_TIME is a DATE
--     (KittoX stores the time-of-day in a DATE, per ExpandDateTimeFrom).
--   * Firebird 'blob sub_type 0' / SQL Server IMAGE -> BLOB.
--   * varchar -> VARCHAR2; integer -> NUMBER(10).
--   * Identifiers are unquoted (Oracle folds them to upper case, matching the
--     metadata). Recommended DB character set: AL32UTF8.
--
-- Primary keys are string ids (no auto-increment), so no sequences/identity are
-- needed. Run this as the schema owner, then run HelloKitto_Oracle_Data.sql.

/********************* TABLES **********************/

CREATE TABLE DOLL
(
  DOLL_ID      VARCHAR2(32)   NOT NULL,
  DOLL_NAME    VARCHAR2(40)   NOT NULL,
  DATE_BOUGHT  DATE,
  HAIR_ID      VARCHAR2(32),
  DRESS_SIZE   VARCHAR2(4),
  MOM_ID       VARCHAR2(32)   NOT NULL,
  ASPECT       VARCHAR2(1024),
  PICTURE      BLOB,
  PICTURE_FILE VARCHAR2(200),
  CONSTRAINT PK_DOLL PRIMARY KEY (DOLL_ID)
);

CREATE TABLE GIRL
(
  GIRL_ID    VARCHAR2(32) NOT NULL,
  GIRL_NAME  VARCHAR2(40) NOT NULL,
  AGE        NUMBER(10),
  HAIR_ID    VARCHAR2(32) NOT NULL,
  PHONE      VARCHAR2(16),
  CONSTRAINT PK_GIRL PRIMARY KEY (GIRL_ID)
);

CREATE TABLE HAIR
(
  HAIR_ID    VARCHAR2(32) NOT NULL,
  HAIR_COLOR VARCHAR2(80) NOT NULL,
  CONSTRAINT PK_HAIR PRIMARY KEY (HAIR_ID)
);

CREATE TABLE INVITATION
(
  INVITATION_ID VARCHAR2(32) NOT NULL,
  PARTY_ID      VARCHAR2(32) NOT NULL,
  INVITEE_ID    VARCHAR2(32) NOT NULL,
  ACCEPTED      NUMBER(1)    CHECK (ACCEPTED IN (0, 1)),
  CONSTRAINT PK_INVITATION PRIMARY KEY (INVITATION_ID)
);

-- HelloKitto stores password hashes as 32-character MD5 hex digests
-- (Auth: DB with IsClearPassword: False). Widen PASSWORD_HASH to 60+ only if
-- you switch to bcrypt.
CREATE TABLE KITTO_USERS
(
  USER_NAME            VARCHAR2(32) NOT NULL,
  PASSWORD_HASH        VARCHAR2(60),
  EMAIL_ADDRESS        VARCHAR2(100),
  MUST_CHANGE_PASSWORD NUMBER(1) DEFAULT 0 NOT NULL CHECK (MUST_CHANGE_PASSWORD IN (0, 1)),
  IS_ACTIVE            NUMBER(1) DEFAULT 1 NOT NULL CHECK (IS_ACTIVE IN (0, 1)),
  CONSTRAINT PK_KITTO_USERS PRIMARY KEY (USER_NAME)
);

CREATE TABLE PARTY
(
  PARTY_ID    VARCHAR2(32)  NOT NULL,
  PARTY_NAME  VARCHAR2(40)  NOT NULL,
  PARTY_DATE  DATE          NOT NULL,
  PARTY_TIME  DATE          NOT NULL,
  ADDRESS     VARCHAR2(256) NOT NULL,
  CONSTRAINT PK_PARTY PRIMARY KEY (PARTY_ID)
);

/******************** FOREIGN KEYS *******************/

ALTER TABLE DOLL ADD CONSTRAINT DT_DOLL_MOM
  FOREIGN KEY (MOM_ID) REFERENCES GIRL (GIRL_ID);

ALTER TABLE DOLL ADD CONSTRAINT FK_DOLL_HAIR
  FOREIGN KEY (HAIR_ID) REFERENCES HAIR (HAIR_ID);

ALTER TABLE GIRL ADD CONSTRAINT FK_GIRL_HAIR
  FOREIGN KEY (HAIR_ID) REFERENCES HAIR (HAIR_ID);

ALTER TABLE INVITATION ADD CONSTRAINT DT_INVITATION_PARTY
  FOREIGN KEY (PARTY_ID) REFERENCES PARTY (PARTY_ID);

ALTER TABLE INVITATION ADD CONSTRAINT FK_INVITATION_GIRL
  FOREIGN KEY (INVITEE_ID) REFERENCES GIRL (GIRL_ID);
