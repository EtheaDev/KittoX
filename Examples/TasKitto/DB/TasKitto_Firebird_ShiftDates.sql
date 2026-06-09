/********************************************************************************
  TasKitto - Shift activity/phase dates forward (Firebird)

  Pushes the demo data forward so the Activity Dashboard views
  (VW_KPI_MONTHLY, VW_ACTIVITY_BY_STATUS, VW_ACTIVITY_DAILY_RANGE), which filter
  ACTIVITY_DATE around CURRENT_DATE, keep returning meaningful numbers.

  Shifts ACTIVITY.ACTIVITY_DATE and PHASE.START_DATE/END_DATE.
  Skips junk dates < V_MINVALID (e.g. the Delphi zero-date 1899-12-30).
  START_TIME / END_TIME are TIME columns and are left untouched.

  Default = AUTO RE-CENTER: computes the shift so the DENSEST month (the one
  with the most activities) lands in the current month - keeping the dashboard's
  busiest period always "now". Set V_AUTO = 0 to push everything forward by a
  fixed V_MONTHS instead. Requires Firebird 2.1+ (DATEADD / EXECUTE BLOCK).
  Run with isql; commit when prompted (or run inside a single transaction).
********************************************************************************/
SET TERM ^ ;

EXECUTE BLOCK
RETURNS (MONTHS_SHIFTED INTEGER, ACTIVITIES_IN_CURRENT_MONTH INTEGER, NEW_MAX_ACTIVITY_DATE DATE)
AS
  DECLARE VARIABLE V_MONTHS   INTEGER;
  DECLARE VARIABLE V_AUTO     SMALLINT;
  DECLARE VARIABLE V_MINVALID DATE;
BEGIN
  V_MONTHS   = 1;              /* fixed shift, used only when V_AUTO = 0          */
  V_AUTO     = 1;              /* 1 = align the DENSEST month to current month    */
  V_MINVALID = DATE '2000-01-01';

  /* Auto mode: find the month with the most activities, then shift so that      */
  /* month lands in the current month. Ties broken toward the most recent month. */
  IF (V_AUTO = 1) THEN
    SELECT FIRST 1
           (EXTRACT(YEAR  FROM CURRENT_DATE) - EXTRACT(YEAR  FROM ACTIVITY_DATE)) * 12
         + (EXTRACT(MONTH FROM CURRENT_DATE) - EXTRACT(MONTH FROM ACTIVITY_DATE))
      FROM ACTIVITY
     WHERE ACTIVITY_DATE >= :V_MINVALID
     GROUP BY EXTRACT(YEAR FROM ACTIVITY_DATE), EXTRACT(MONTH FROM ACTIVITY_DATE)
     ORDER BY COUNT(*) DESC,
              EXTRACT(YEAR  FROM ACTIVITY_DATE) DESC,
              EXTRACT(MONTH FROM ACTIVITY_DATE) DESC
      INTO :V_MONTHS;

  IF (V_MONTHS <> 0) THEN
  BEGIN
    UPDATE ACTIVITY
       SET ACTIVITY_DATE = DATEADD(MONTH, :V_MONTHS, ACTIVITY_DATE)
     WHERE ACTIVITY_DATE >= :V_MINVALID;

    UPDATE PHASE
       SET START_DATE = DATEADD(MONTH, :V_MONTHS, START_DATE)
     WHERE START_DATE IS NOT NULL AND START_DATE >= :V_MINVALID;

    UPDATE PHASE
       SET END_DATE = DATEADD(MONTH, :V_MONTHS, END_DATE)
     WHERE END_DATE IS NOT NULL AND END_DATE >= :V_MINVALID;
  END

  MONTHS_SHIFTED = V_MONTHS;

  SELECT COUNT(*)
    FROM ACTIVITY
   WHERE EXTRACT(YEAR  FROM ACTIVITY_DATE) = EXTRACT(YEAR  FROM CURRENT_DATE)
     AND EXTRACT(MONTH FROM ACTIVITY_DATE) = EXTRACT(MONTH FROM CURRENT_DATE)
    INTO :ACTIVITIES_IN_CURRENT_MONTH;

  SELECT MAX(ACTIVITY_DATE) FROM ACTIVITY INTO :NEW_MAX_ACTIVITY_DATE;

  SUSPEND;
END^

SET TERM ; ^
