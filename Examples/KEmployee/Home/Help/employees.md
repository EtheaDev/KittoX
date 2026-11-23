---
title: Employees
areas: business
---

# Employees

The people of the company: what they are paid, when they were hired, which department they belong
to and what job they hold.

## What an employee is made of

| Field | |
|---|---|
| **First name**, **Last name** | Required. The full name shown by other screens is built from them. |
| **Phone ext** | The internal extension, four characters. |
| **Hire date** | The day the employee was hired. Required. |
| **Salary** | The current salary. Required - and see the salary history below, which is where its changes are kept. |
| **Department** | One of the [departments](departments). Required. |
| **Job** | One of the [jobs](jobs). Required. |

A job carries a minimum and a maximum salary for the country it belongs to, so a salary and a job
that disagree are a thing worth checking before saving.

## Salary history

Open an employee and the tab underneath holds the **changes to that salary**, one row each:

| Field | |
|---|---|
| **Change date** | When the change was applied. Part of the key: two changes to the same employee on the same date by the same person are the same row. |
| **Updater id** | Who applied it. |
| **Old salary**, **New salary**, **Percent change** | What it was, what it became, by how much. |

The history is saved together with the employee it belongs to.

## Exporting

The toolbar offers **Download in TXT** besides the usual buttons: it takes away the employees the
list is showing, filters included.
