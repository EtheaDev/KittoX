/********************************************************************************
  TasKitto - Shift activity/phase dates forward (SQL Server)

  Why: the Activity Dashboard views (VW_KPI_MONTHLY, VW_ACTIVITY_BY_STATUS,
  VW_ACTIVITY_DAILY_RANGE) filter ACTIVITY.ACTIVITY_DATE relative to GETDATE()
  (current month, and +/-15 days). As wall-clock time advances past the seeded
  data, the dashboard windows become empty. Running this script pushes the demo
  data forward so the dashboard keeps showing meaningful numbers.

  What it shifts:
    - ACTIVITY.ACTIVITY_DATE       (drives every dashboard view)
    - PHASE.START_DATE / END_DATE  (kept coherent with the activities)

  What it leaves untouched:
    - Rows with a junk date < @MinValidDate (e.g. the Delphi zero-date
      1899-12-30 present on 4 ACTIVITY rows). Shifting garbage is pointless.
    - ACTIVITY.START_TIME / END_TIME are TIME columns (no date) - unaffected.

  Default behaviour = AUTO RE-CENTER: the script computes the shift so the
  DENSEST month (the one with the most activities) lands in the current month.
  This is the goal - it keeps the dashboard's busiest period always "now",
  regardless of how stale the data is, in a single pass.

  Set @AutoReCenter = 0 to instead push everything forward by a fixed
  @MonthsShift (e.g. 1) - handy for a simple monthly cadence.

  Safe to re-run. Wrapped in a transaction: switch COMMIT -> ROLLBACK at the
  bottom to preview the effect without persisting.
********************************************************************************/
USE Taskitto;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @MonthsShift  int  = 1;            -- fixed shift, used only when @AutoReCenter = 0
DECLARE @AutoReCenter bit  = 1;            -- 1 = align the DENSEST month to the current month (the goal)
DECLARE @MinValidDate date = '2000-01-01'; -- rows older than this are treated as junk and skipped

-- Auto mode: find the month holding the most activities, then shift so that
-- month lands in the current month. Ties broken toward the most recent month.
IF @AutoReCenter = 1
BEGIN
  DECLARE @DenseYear int, @DenseMonth int;
  SELECT TOP 1
         @DenseYear  = YEAR(ACTIVITY_DATE),
         @DenseMonth = MONTH(ACTIVITY_DATE)
  FROM ACTIVITY
  WHERE ACTIVITY_DATE >= @MinValidDate
  GROUP BY YEAR(ACTIVITY_DATE), MONTH(ACTIVITY_DATE)
  ORDER BY COUNT(*) DESC, YEAR(ACTIVITY_DATE) DESC, MONTH(ACTIVITY_DATE) DESC;

  SET @MonthsShift = (YEAR(GETDATE()) - @DenseYear) * 12 + (MONTH(GETDATE()) - @DenseMonth);
END

PRINT CONCAT('TasKitto: shifting dates forward by ', @MonthsShift, ' month(s)...');

IF @MonthsShift = 0
BEGIN
  PRINT 'Nothing to do (shift = 0).';
  RETURN;
END

BEGIN TRAN;

  UPDATE ACTIVITY
    SET ACTIVITY_DATE = DATEADD(MONTH, @MonthsShift, ACTIVITY_DATE)
  WHERE ACTIVITY_DATE >= @MinValidDate;

  UPDATE PHASE
    SET START_DATE = DATEADD(MONTH, @MonthsShift, START_DATE)
  WHERE START_DATE IS NOT NULL AND START_DATE >= @MinValidDate;

  UPDATE PHASE
    SET END_DATE = DATEADD(MONTH, @MonthsShift, END_DATE)
  WHERE END_DATE IS NOT NULL AND END_DATE >= @MinValidDate;

  -- Verification: how the dashboard sees the data after the shift.
  SELECT
    @MonthsShift AS months_shifted,
    (SELECT COUNT(*) FROM ACTIVITY
       WHERE ACTIVITY_DATE >= DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)
         AND ACTIVITY_DATE <  DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))
    ) AS activities_in_current_month,
    (SELECT COUNT(*) FROM ACTIVITY
       WHERE ACTIVITY_DATE >= DATEADD(DAY, -15, CAST(GETDATE() AS date))
         AND ACTIVITY_DATE <= DATEADD(DAY,  15, CAST(GETDATE() AS date))
    ) AS activities_in_daily_range,
    (SELECT MAX(ACTIVITY_DATE) FROM ACTIVITY) AS new_max_activity_date;

COMMIT;     -- <-- change to ROLLBACK to preview without saving
GO
