---
title: Lists and forms
areas: basics
---

# Lists and forms

Every screen of KEmployee is a **list**, and the same handful of gestures works on all of them.

## The search panel

Above the rows, a panel narrows what the list shows: **Search Employees**, **Search Customers**,
**Search Projects**, **Search Departments**, **Search Jobs**, each with the filters that screen
offers. Filters add up, and emptying one puts back the rows it was hiding.

## The toolbar

**New**, **Edit**, **View**, **Delete**, **Refresh** - add a record, change it, read it without
the risk of changing it, remove it after a confirmation, read the rows again.

A record other records depend on cannot be deleted: a department with employees, a job someone
holds, a country a job belongs to. The application says what is holding it rather than letting the
database refuse with a message nobody can read.

## Sorting, paging, exporting

Click a column heading to sort by it, click again to reverse. Long lists are read a page at a
time. Where a screen offers it, the toolbar carries **Download in CSV**, **Download in Excel** or
**Download in TXT**, and what comes out is what the list is showing - filters included.

## Tabs under a form

Some records own others: an employee owns a salary history, a customer owns orders. Those appear
in a **tab under the form** of the record they belong to, with a toolbar of their own, and they
are saved together with it.
