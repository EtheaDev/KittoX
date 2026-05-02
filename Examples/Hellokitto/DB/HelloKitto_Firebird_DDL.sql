/********************* TABLES **********************/

-- ACCEPTED uses the native BOOLEAN type introduced in Firebird 3.0.
-- The PostgreSQL DDL uses the same `boolean` type; the SQL Server DDL uses `BIT`.
-- The %DB.TRUE% / %DB.FALSE% macros expand to the literal that matches each
-- dialect (TRUE/FALSE on Firebird and PostgreSQL, 1/0 on SQL Server) — see
-- TEFDBEngineType.GetBoolTrueLiteral in EF.DB.pas — so application SQL stays
-- portable.
-- Apps that must run against Firebird 2.5 or earlier need to substitute SMALLINT
-- here and override the boolean macros via descendant TEFDBEngineType.
CREATE TABLE DOLL
(
  DOLL_ID      varchar(32)   NOT NULL,
  DOLL_NAME    varchar(40)   NOT NULL,
  DATE_BOUGHT  date,
  HAIR_ID      varchar(32),
  DRESS_SIZE   varchar(4),
  MOM_ID       varchar(32)   NOT NULL,
  ASPECT       varchar(1024),
  PICTURE      blob sub_type 0,
  PICTURE_FILE varchar(200),
  CONSTRAINT PK_DOLL PRIMARY KEY (DOLL_ID)
);

CREATE TABLE GIRL
(
  GIRL_ID    varchar(32) NOT NULL,
  GIRL_NAME  varchar(40) NOT NULL,
  AGE        integer,
  HAIR_ID    varchar(32) NOT NULL,
  PHONE      varchar(16),
  CONSTRAINT PK_GIRL PRIMARY KEY (GIRL_ID)
);

CREATE TABLE HAIR
(
  HAIR_ID    varchar(32) NOT NULL,
  HAIR_COLOR varchar(80) NOT NULL,
  CONSTRAINT PK_HAIR PRIMARY KEY (HAIR_ID)
);

CREATE TABLE INVITATION
(
  INVITATION_ID varchar(32) NOT NULL,
  PARTY_ID      varchar(32) NOT NULL,
  INVITEE_ID    varchar(32) NOT NULL,
  ACCEPTED      boolean,
  CONSTRAINT PK_INVITATION PRIMARY KEY (INVITATION_ID)
);

-- HelloKitto stores password hashes as 32-character MD5 hex digests
-- (Auth: DB with IsClearPassword: False and no IsBCrypted flag).
-- Keep PASSWORD_HASH wide enough (60+ chars) only if you switch to bcrypt.
CREATE TABLE KITTO_USERS
(
  USER_NAME            varchar(32)  NOT NULL,
  PASSWORD_HASH        varchar(32),
  EMAIL_ADDRESS        varchar(100),
  MUST_CHANGE_PASSWORD boolean DEFAULT FALSE NOT NULL,
  IS_ACTIVE            boolean DEFAULT TRUE  NOT NULL,
  CONSTRAINT PK_KITTO_USERS PRIMARY KEY (USER_NAME)
);

CREATE TABLE PARTY
(
  PARTY_ID    varchar(32)   NOT NULL,
  PARTY_NAME  varchar(40)   NOT NULL,
  PARTY_DATE  date          NOT NULL,
  PARTY_TIME  time          NOT NULL,
  ADDRESS     varchar(256)  NOT NULL,
  CONSTRAINT PK_PARTY PRIMARY KEY (PARTY_ID)
);

/******************** FOREIGN KEYS *******************/

ALTER TABLE DOLL ADD CONSTRAINT DT_DOLL_MOM
  FOREIGN KEY (MOM_ID) REFERENCES GIRL (GIRL_ID);

ALTER TABLE DOLL ADD CONSTRAINT FK_DOLL_HAIR
  FOREIGN KEY (HAIR_ID) REFERENCES HAIR (HAIR_ID)
  ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE GIRL ADD CONSTRAINT FK_GIRL_HAIR
  FOREIGN KEY (HAIR_ID) REFERENCES HAIR (HAIR_ID)
  ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE INVITATION ADD CONSTRAINT DT_INVITATION_PARTY
  FOREIGN KEY (PARTY_ID) REFERENCES PARTY (PARTY_ID)
  ON UPDATE NO ACTION ON DELETE NO ACTION;

ALTER TABLE INVITATION ADD CONSTRAINT FK_INVITATION_GIRL
  FOREIGN KEY (INVITEE_ID) REFERENCES GIRL (GIRL_ID);
