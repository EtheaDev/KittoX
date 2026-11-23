---
title: HelloKitto
areas: basics
---

# HelloKitto

HelloKitto is the small demo application of the KittoX framework. It keeps track of a handful of
girls, of the dolls that belong to them, and of the parties the girls are invited to. It is meant
to be read while clicking: every screen named here is one entry of the menu on the left.

## The menu

| Folder | What is inside |
|---|---|
| **Girls** | The girls: a list to browse them and a form to add one. |
| **Dolls** | The dolls, as a list grouped by their mom, as a catalog of cards, and a form to add one. |
| **Parties** | The parties, with their invitations, and the same parties on a calendar. |
| **Lookup tables** | Hair types, the short list the other screens choose a colour from. |
| **User** | Change your password, or close the session. |

## Signing in

The application asks for a user name and a password. The demo is shipped with a couple of users;
which ones depends on the database you installed it with. If the password is refused, see
[Your account](your-account) for how it is changed - and note that an empty password is never
accepted, by design.

## Where to start

If this is your first time, open **Girls** and then **Dolls**: those two screens show everything
the rest of the application repeats - a search panel, a toolbar, a form that opens over the list.
[Lists and forms](lists-and-forms) explains those once and for all.
