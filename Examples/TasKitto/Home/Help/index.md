---
title: TasKitto
areas: basics
---

# TasKitto

TasKitto is the demo application of the KittoX framework that records **what people spend their
time on**: an activity, done by an employee, on a phase of a project, for a customer. Everything
else in it - the charts, the calendar, the dashboard, the report - is that same activity seen
from a different angle.

## The menu

| Folder | What is inside |
|---|---|
| **Tables** | [Employees](employees), operator roles and activity types: the short lists the rest of the application chooses from. |
| **Customers** | [Customers](customers), their [projects](projects-and-phases), and the [customer map](customer-map). |
| **Activities** | Recording them: the [wizard](new-activity), the [input list](activity-input), [activities by type](activities-by-type), the [report](activity-report), the [calendar](activity-calendar). |
| **Statistics** | The [dashboard](dashboard) and the two pie charts, plus the bar chart. |
| **Maintenance** | [Users, roles and permissions](users-and-permissions), the password, and the way out. |

## The shape of the data

Read it once and the whole application makes sense:

> A **customer** has **projects**. A project is divided into **phases**. An **activity** is work
> done by an **employee**, in a **role**, on a phase, on a day, of some **type**, for a number of
> hours.

That is why an activity asks for a phase and not for a project: the project comes with the phase.

## Where to start

[New Activity Wizard](new-activity) if you are here to record work; [Activity
Dashboard](dashboard) if you are here to see how it is going. [Lists and forms](lists-and-forms)
explains the gestures that work everywhere.
