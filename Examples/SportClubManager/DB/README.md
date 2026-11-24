# Sport Club Manager — Database

The application runs on **MS SQL Server** through FireDAC, on a database named
**`KITTOXSCM`**. The connection is in `Home\Metadata\Config.yaml`:

```yaml
Databases:
  Main: FD
    Connection:
      DriverID: MSSQL
      Server: 127.0.0.1, 1435
      Database: KITTOXSCM
      User_Name: SA
```

## Setup

Create the database, then run the two scripts in order against it — neither
carries a `USE`, so they act on whatever database you select:

| Script | What it does |
|---|---|
| `SCM_SQLServer_DDL.sql` | 123 tables, 25 views, 11 functions, 123 primary keys, 605 defaults |
| `SCM_SQLServer_Data.sql` | ~12,400 rows of demo data |

```
sqlcmd -S localhost -d master -Q "CREATE DATABASE KITTOXSCM"
sqlcmd -S localhost -d KITTOXSCM -i SCM_SQLServer_DDL.sql
sqlcmd -S localhost -d KITTOXSCM -i SCM_SQLServer_Data.sql
```

The schema declares **two** foreign keys and no secondary indexes: in this
application referential integrity lives in the metadata and in the business
rules, not in the schema. The data script switches those two constraints off
while it loads and checks them again at the end, so the order of the tables
does not matter.

## Signing in

Every account has the same password, **`demo1234`**, and `Config.yaml` also
enables the **passepartout** (`PassepartoutPassword: password`), which lets you
in as any existing user.

| User name | Who | What opens |
|---|---|---|
| `ADMIN` | administrator | `ADMIN_Home`, the full management interface |
| `SEGRETERIA` | office account, not an administrator | `ADMIN_Home` with fewer rights |
| `SYSDBA` | system administrator, what `Auth/.Defaults` pre-fills | `ADMIN_Home` |
| `BLDDRD68B12C523H` | a parent: three children, 22 subscriptions | `USER_Home`, the member's own interface |

The two profiles are what `APPUSER.PROFILEID` says: `ADMIN` loads `ADMIN_Home`,
designed for a desktop browser; `USER` loads `USER_Home`, designed for the
parent's telephone. **A member's user name is their tax code** — that is how the
application expects a member to sign in — so the 24 member accounts are named
after the tax codes in `NOMINATIVI`, and any of them gets you into the user
interface.

## What the demo data is, and is not

The archive this example started from was a **real sports club's**: names,
addresses, tax codes, e-mail addresses, medical certificate dates, payments and
accounts of actual people. None of that is here. `SCM_SQLServer_Anonymize.sql`
is the script that took it out, and it is kept in the repository so that the
result can be checked and reproduced:

- **89 people** got a synthetic surname, first name, address, telephone,
  e-mail (all at `example.com`) and IBAN. A family shares its surname, its
  address and its landline, because in the archive it did.
- **The tax codes are rebuilt, not blanked**: the application validates their
  format and their check character, and derives birth date, gender and
  birthplace from the code itself, so only the six name letters and the check
  character are recomputed. The date and place of birth carry over from the
  original — they identify nobody once the name is gone. The script's own
  verification confirms every code is valid and matches the name it belongs to.
- **The club** is now "A.S.D. ETHEA" in Milano, with a demo VAT number; the
  other clubs, the sponsors, the suppliers, the customers, the banks, the
  clinics and the sports facilities became "… Demo N".
- **Photographs and logos** are gone, the **mail queue** is empty, the free-text
  notes are cleared, and the identity-document numbers are synthetic.
- What stays real is the **shape** of the data: 12,400 rows, 83 people in the
  registry, 37 subscriptions with their fees and instalments, a full
  double-entry accounting year, the national list of Italian municipalities.
  Two subscriptions point at people who were never in the registry and seven
  rows were entered by users who no longer exist: both oddities came with the
  original archive, and they are left as they were — an application meets
  data like this in the field.

The one thing the anonymisation deliberately leaves alone is the name of a
**town**: municipalities, provinces and regions keep their real names, since
they are a national list and a birthplace says nothing about a person whose
name is invented.

## Rebuilding the demo data

If the demo database is ever rebuilt from a club's archive:

```
sqlcmd -S localhost -d <copy of the archive> -i SCM_SQLServer_Anonymize.sql
```

It refuses to run on a database named `SCM_MILLENNIUM` and on one it has
already anonymised, prints what it changed, verifies the result, and drops its
own mapping tables at the end — the map is the only thing that could undo the
anonymisation, so it must not survive. Then regenerate `SCM_SQLServer_Data.sql`
from the anonymised copy.
