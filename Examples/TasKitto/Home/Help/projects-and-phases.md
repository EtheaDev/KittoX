---
title: Projects and phases
areas: customers
---

# Projects and phases

A **project** belongs to a customer and is divided into **phases**. An activity is recorded
against a phase, never directly against a project - which is what makes the hours of a project
the sum of the hours of its phases, with nothing left over.

## What a project is made of

| Field | |
|---|---|
| **Project Name** | Required. |
| **Customer** | The [customer](customers) it is for. Required. |
| **Status** | Where the project stands. |

## What a phase is made of

| Field | |
|---|---|
| **Phase Name** | Required. |
| **Project** | The project it belongs to. Required. |
| **Start Date**, **End Date** | When it runs. |
| **Status** | Where it stands. |

The phases of a project are in a tab under its form, and are saved with it.

## Before deleting

A project with phases, or a phase with activities recorded against it, cannot be deleted: the
hours would be left pointing at nothing. Move or delete those first.
