---
title: Lists and forms
areas: basics
---

# Lists and forms

Almost every screen of HelloKitto is a **list**, and almost everything you do starts there. What
this page describes is the same on all of them.

## The search panel

Above the rows there is a panel that narrows what the list shows. It is made of the filters that
screen offers: a box to type into, a row of buttons to pick one value, a drop-down that completes
what you type. Filters add up - choosing a hair colour **and** typing a name leaves the rows that
match both.

Emptying a filter puts back the rows it was hiding; there is nothing to confirm.

## The toolbar

| Button | |
|---|---|
| **New** | Opens an empty form to add a record. |
| **Edit** | Opens the selected record in a form you can change. |
| **View** | Opens the selected record read-only. |
| **Delete** | Removes the selected record, after asking. |
| **Refresh** | Reads the rows again from the database. |

A record that other records depend on cannot be deleted: the application says which ones hold it
back rather than failing with a message from the database.

## Sorting and paging

Clicking the heading of a column sorts by it; clicking it again reverses the order. Long lists are
read a page at a time, with the page buttons at the bottom.

## The form

A form opens over the list. Fields marked as required will not let you save while they are empty,
and the application checks what it must before writing: it tells you what is wrong instead of
saving something it would have to undo.

**Save** writes and closes, **Cancel** closes without writing. Some forms carry arrows to move to
the record before or after without closing the form.

## Taking a list away with you

Where a screen offers it, the toolbar has **Download in CSV** and **Download in Excel**: both save
what the list is showing - filters included - not the whole table.
