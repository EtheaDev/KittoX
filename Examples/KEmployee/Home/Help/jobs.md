---
title: Jobs
areas: tables
---

# Jobs

The jobs an employee can hold. A job is not only a title: it carries the salary range it is paid
within, and that range is **per country**, because the same job is not paid the same everywhere.

## What a job is made of

| Field | |
|---|---|
| **Job code** | The code, up to five characters. |
| **Job grade** | The grade. Part of the key together with the code and the country: the same code at two grades is two jobs. |
| **Job country** | One of the [countries](countries). Part of the key. |
| **Job title** | The name of the job. Required. |
| **Min salary**, **Max salary** | The range this job is paid within, in the currency of its country. Required. |
| **Job requirement** | What the job asks for, as long a text as you need. |
| **Language req** | The language it requires. |

## Why the key is made of three fields

A job is the same job only when code, grade **and** country are the same. That is what lets the
same title exist at two grades, and in two countries with two different salary ranges, without
the records getting in each other's way.

## Before deleting one

A job someone holds cannot be deleted: look at the [employees](employees) first.
