---
title: Departments
areas: tables
---

# Departments

The departments of the company. They are a **tree**: a department may have a parent department,
which is how a division contains its offices.

## What a department is made of

| Field | |
|---|---|
| **Dept no** | The code, three characters. It is the key, and it is what the other screens refer to. |
| **Department** | The name. Required. |
| **Budget** | The budget of the department. |
| **Location** | Where it is. |
| **Phone no** | The switchboard number. |
| **Head department** | The department this one belongs to, if any. Leave it empty for a department at the top. |
| **Manager** | The [employee](employees) who runs it. |

## Before deleting one

A department with employees in it, or with another department under it, cannot be deleted. Move
those first.
