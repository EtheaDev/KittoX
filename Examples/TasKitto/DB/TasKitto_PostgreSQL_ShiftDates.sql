/********************************************************************************
  TasKitto - Shift activity/phase dates forward (PostgreSQL)

  Pushes the demo data forward so the Activity Dashboard views
  (vw_kpi_monthly, vw_activity_by_status, vw_activity_daily_range), which filter
  activity_date around CURRENT_DATE, keep returning meaningful numbers.

  Shifts taskitto.activity.activity_date and taskitto.phase.start_date/end_date.
  Skips junk dates < v_min_valid (e.g. the Delphi zero-date 1899-12-30).
  start_time / end_time are TIME columns and are left untouched.

  Default = AUTO RE-CENTER: computes the shift so the DENSEST month (the one
  with the most activities) lands in the current month - keeping the dashboard's
  busiest period always "now". Set v_auto_recenter := FALSE to push everything
  forward by a fixed v_months instead. Wrapped in a DO block; the whole block is
  one transaction (it rolls back automatically if it raises).
********************************************************************************/
DO $$
DECLARE
  v_months       int     := 1;             -- fixed shift, used only when v_auto_recenter = FALSE
  v_auto_recenter boolean := TRUE;          -- TRUE = align the DENSEST month to the current month (the goal)
  v_min_valid    date    := DATE '2000-01-01';
  v_in_month     int;
  v_new_max      date;
BEGIN
  -- Auto mode: find the month with the most activities, then shift so that
  -- month lands in the current month. Ties broken toward the most recent month.
  IF v_auto_recenter THEN
    SELECT (EXTRACT(YEAR FROM CURRENT_DATE)::int - yr) * 12
         + (EXTRACT(MONTH FROM CURRENT_DATE)::int - mo)
      INTO v_months
      FROM (
        SELECT EXTRACT(YEAR  FROM activity_date)::int AS yr,
               EXTRACT(MONTH FROM activity_date)::int AS mo,
               COUNT(*) AS n
          FROM taskitto.activity
         WHERE activity_date >= v_min_valid
         GROUP BY 1, 2
         ORDER BY n DESC, yr DESC, mo DESC
         LIMIT 1
      ) d;
  END IF;

  RAISE NOTICE 'TasKitto: shifting dates forward by % month(s)...', v_months;

  IF v_months = 0 THEN
    RAISE NOTICE 'Nothing to do (shift = 0).';
    RETURN;
  END IF;

  UPDATE taskitto.activity
     SET activity_date = activity_date + (v_months * INTERVAL '1 month')
   WHERE activity_date >= v_min_valid;

  UPDATE taskitto.phase
     SET start_date = start_date + (v_months * INTERVAL '1 month')
   WHERE start_date IS NOT NULL AND start_date >= v_min_valid;

  UPDATE taskitto.phase
     SET end_date = end_date + (v_months * INTERVAL '1 month')
   WHERE end_date IS NOT NULL AND end_date >= v_min_valid;

  SELECT COUNT(*) INTO v_in_month
    FROM taskitto.activity
   WHERE activity_date >= DATE_TRUNC('month', CURRENT_DATE)
     AND activity_date <  DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month';

  SELECT MAX(activity_date) INTO v_new_max FROM taskitto.activity;

  RAISE NOTICE 'Done. Activities now in current month: %, new max date: %', v_in_month, v_new_max;
END $$;
