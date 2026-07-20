/********************************************************************************
  TasKitto - Shift activity/phase dates forward (Oracle 19c)

  Why: the Activity Dashboard views (VW_KPI_MONTHLY, VW_ACTIVITY_BY_STATUS,
  VW_ACTIVITY_DAILY_RANGE) filter ACTIVITY.ACTIVITY_DATE relative to SYSDATE
  (current month, and +/-15 days). As wall-clock time advances past the seeded
  data, the dashboard windows become empty. Running this script pushes the demo
  data forward so the dashboard keeps showing meaningful numbers.

  What it shifts:
    - ACTIVITY.ACTIVITY_DATE       (drives every dashboard view)
    - PHASE.START_DATE / END_DATE  (kept coherent with the activities)

  What it leaves untouched:
    - Rows with a junk date < v_min_valid (e.g. the Delphi zero-date
      1899-12-30 present on a few ACTIVITY rows). Shifting garbage is pointless.
    - ACTIVITY.START_TIME / END_TIME hold only the time-of-day (stored in a DATE)
      and are not shifted.

  Default behaviour = AUTO RE-CENTER: the script computes the shift so the
  DENSEST month (the one with the most activities) lands in the current month.
  This keeps the dashboard's busiest period always "now", regardless of how
  stale the data is, in a single pass.

  Set v_auto_recenter := FALSE to instead push everything forward by a fixed
  v_months_shift (e.g. 1) - handy for a simple monthly cadence.

  Safe to re-run. It COMMITs at the end: change COMMIT -> ROLLBACK to preview
  the effect without persisting.

  How to run:
    - SQL*Plus / SQLcl: run as-is (the trailing "/" executes the PL/SQL block;
      SET SERVEROUTPUT ON shows the messages).
    - Generic SQL client / MCP that rejects anonymous PL/SQL: set the shift
      yourself and issue the three UPDATEs directly. To find the shift, run:
        SELECT ROUND(MONTHS_BETWEEN(TRUNC(SYSDATE,'MM'), m)) AS months_shift
        FROM (SELECT TRUNC(ACTIVITY_DATE,'MM') m
              FROM ACTIVITY WHERE ACTIVITY_DATE >= DATE '2000-01-01'
              GROUP BY TRUNC(ACTIVITY_DATE,'MM')
              ORDER BY COUNT(*) DESC, TRUNC(ACTIVITY_DATE,'MM') DESC)
        WHERE ROWNUM = 1;
      then UPDATE ... SET col = ADD_MONTHS(col, <months_shift>) on the columns
      below (skipping dates < 2000-01-01), and COMMIT.
********************************************************************************/

SET SERVEROUTPUT ON

DECLARE
  v_auto_recenter BOOLEAN     := TRUE;             -- TRUE = align the DENSEST month to the current month (the goal)
  v_months_shift  PLS_INTEGER := 1;                -- fixed shift, used only when v_auto_recenter = FALSE
  v_min_valid     DATE        := DATE '2000-01-01';-- rows older than this are treated as junk and skipped
  v_cur_month     DATE        := TRUNC(SYSDATE, 'MM');
  v_dense_month   DATE;
  v_cnt_month     PLS_INTEGER;
  v_cnt_range     PLS_INTEGER;
  v_max_date      DATE;
BEGIN
  -- Auto mode: find the month holding the most activities, then shift so that
  -- month lands in the current month. Ties broken toward the most recent month.
  IF v_auto_recenter THEN
    SELECT m INTO v_dense_month FROM (
      SELECT TRUNC(ACTIVITY_DATE, 'MM') AS m
      FROM ACTIVITY
      WHERE ACTIVITY_DATE >= v_min_valid
      GROUP BY TRUNC(ACTIVITY_DATE, 'MM')
      ORDER BY COUNT(*) DESC, TRUNC(ACTIVITY_DATE, 'MM') DESC
    ) WHERE ROWNUM = 1;

    v_months_shift := ROUND(MONTHS_BETWEEN(v_cur_month, v_dense_month));
  END IF;

  DBMS_OUTPUT.PUT_LINE('TasKitto: shifting dates forward by ' || v_months_shift || ' month(s)...');

  IF v_months_shift = 0 THEN
    DBMS_OUTPUT.PUT_LINE('Nothing to do (shift = 0).');
    RETURN;
  END IF;

  UPDATE ACTIVITY
    SET ACTIVITY_DATE = ADD_MONTHS(ACTIVITY_DATE, v_months_shift)
  WHERE ACTIVITY_DATE >= v_min_valid;

  UPDATE PHASE
    SET START_DATE = ADD_MONTHS(START_DATE, v_months_shift)
  WHERE START_DATE IS NOT NULL AND START_DATE >= v_min_valid;

  UPDATE PHASE
    SET END_DATE = ADD_MONTHS(END_DATE, v_months_shift)
  WHERE END_DATE IS NOT NULL AND END_DATE >= v_min_valid;

  -- Verification: how the dashboard sees the data after the shift.
  SELECT COUNT(*) INTO v_cnt_month FROM ACTIVITY
    WHERE ACTIVITY_DATE >= TRUNC(SYSDATE, 'MM')
      AND ACTIVITY_DATE <  ADD_MONTHS(TRUNC(SYSDATE, 'MM'), 1);

  SELECT COUNT(*) INTO v_cnt_range FROM ACTIVITY
    WHERE ACTIVITY_DATE >= TRUNC(SYSDATE) - 15
      AND ACTIVITY_DATE <= TRUNC(SYSDATE) + 15;

  SELECT MAX(ACTIVITY_DATE) INTO v_max_date FROM ACTIVITY;

  DBMS_OUTPUT.PUT_LINE('Activities in current month  : ' || v_cnt_month);
  DBMS_OUTPUT.PUT_LINE('Activities in +/-15 day range: ' || v_cnt_range);
  DBMS_OUTPUT.PUT_LINE('New max ACTIVITY_DATE         : ' || TO_CHAR(v_max_date, 'YYYY-MM-DD'));

  COMMIT;   -- <-- change to ROLLBACK to preview without saving
END;
/
