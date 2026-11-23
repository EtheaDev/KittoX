---
title: KEmployee
areas: basics
---

# KEmployee

KEmployee is a demo application of the KittoX framework built on the **employee** database that
ships with Firebird - the one with departments, jobs, projects and a sales history. It is a
company seen from its personnel office: who works where, on what, for how much, and who buys from
it.

## The menu

| Folder | What is inside |
|---|---|
| **Tables** | The lists the rest of the application chooses from: [countries](countries), [jobs](jobs), [departments](departments). |
| **Business** | The day to day: [customers](customers) with their orders, [employees](employees) with their salary history, and [projects](projects). |
| **Maintenance** | **Close session**, which ends your session. |

## Where to start

Open **Employees**: it is the screen with the most in it, and it shows in one place what every
other screen does separately - a search panel, a form, and a tab underneath with the records that
belong to the one you are looking at. [Lists and forms](lists-and-forms) explains those once.

## A word about the data

It is demo data: salaries, orders and dates are the ones Firebird ships for teaching, not a real
company. Nothing you change here reaches anything but your own copy of the database.
