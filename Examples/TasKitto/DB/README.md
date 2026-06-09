# TasKitto — Database scripts

SQL scripts to create and populate the TasKitto demo database on the three
supported engines, plus a helper to keep the **Activity Dashboard** showing
fresh data over time.

## Setup

Run, in order, against a database/schema named `taskitto` (lowercase on
PostgreSQL/Firebird):

| Engine | Scripts (in order) |
|--------|--------------------|
| **SQL Server** | `Taskitto_SQLServer_DDL.sql` → `Taskitto_SQLServer_DDL_Views.sql` → `Taskitto_SQLServer_Data.sql` |
| **PostgreSQL** | `KittoX_PostgreSQL_CreateDB.sql` → `TasKitto_PostgreSQL_DDL.sql` → `TasKitto_PostgreSQL_Data.sql` |
| **Firebird** | `TasKitto_Firebird_DDL.sql` → `TasKitto_Firebird_Data.sql` |

(On SQL Server the DDL is split because the views must be created in a
separate batch from the tables, per T-SQL batch rules.)

## Refreshing demo dates (`*_ShiftDates.sql`)

The Activity Dashboard views (`VW_KPI_MONTHLY`, `VW_ACTIVITY_BY_STATUS`,
`VW_ACTIVITY_DAILY_RANGE`) filter `ACTIVITY.ACTIVITY_DATE` relative to the
**current date** (current month, and ±15 days). As wall-clock time advances
past the seeded data, those windows go empty and the dashboard shows nothing.

The shift scripts push the demo data forward so the dashboard keeps showing
meaningful numbers:

- `Taskitto_SQLServer_ShiftDates.sql`
- `TasKitto_PostgreSQL_ShiftDates.sql`
- `TasKitto_Firebird_ShiftDates.sql`

**Default = auto re-center**: each script finds the month holding the most
activities and shifts everything so that month lands on the *current* month —
the dashboard's busiest period is always "now". They shift
`ACTIVITY.ACTIVITY_DATE` and `PHASE.START_DATE` / `END_DATE`, skip junk dates
(`< 2000-01-01`, e.g. the Delphi zero-date `1899-12-30`), and leave the
`START_TIME` / `END_TIME` columns untouched. Safe to re-run any time: each run
recomputes the shift it needs. To push by a fixed number of months instead,
set the in-script flag (`@AutoReCenter = 0` / `v_auto_recenter := FALSE` /
`V_AUTO = 0`) and the `*MonthsShift` value.

### How to run them

- **SQL Server** — run as-is in SSMS / `sqlcmd` (the `GO` batch separators are
  honoured there). If you send it through a driver that executes a single
  batch (no `GO`), strip the two `GO` lines and keep `USE Taskitto;` in the
  same batch so the `DECLARE`d variables stay in scope.
- **PostgreSQL** — run as-is in `psql` / any client; it is a single `DO $$ … $$`
  block (one auto-committed transaction).
- **Firebird** — run as-is in `isql` (it relies on the `SET TERM ^` directive
  and `EXECUTE BLOCK`).

> **Note — running via an MCP / generic SQL client:** the Firebird
> `EXECUTE BLOCK` form may be rejected by clients with a SQL safety filter
> (e.g. the `mcp-firebird` server flags it as an unsafe statement). In that
> case run the equivalent plain statements instead: first compute the shift
> with the `SELECT FIRST 1 … GROUP BY … ORDER BY COUNT(*) DESC` query at the
> top of the block, then issue the three `UPDATE … DATEADD(MONTH, <shift>, …)`
> statements with that integer. The result is identical to the block.
