# Testi E-mail

Nel [menu amministratore](/administrator_menu), alla voce Gestione Email è possibile gestire i testi delle mail automatiche inviate da [Sport Club Manager](/start).

### Finestra elenco con filtro di ricerca

Dall'elenco è possibile vedere la lista delle mail automatiche.

Sul pannello di ricerca è possibile indicare i "filtri" di ricerca:

- Ricerca libera: (Ricerca su Id account, cognome, nome e email)

Sulla toolbar è possibile effettuare le operazioni di:

- ![](./images/edit_record.png) Modifica di un [testo della mail](/emailtemplates_emailtemplate) automatica
- ![](./images/refresh.png) Aggiornamento elenco (refresh)
- ![](./images/help.png) Guida in linea

Inoltre sono disponibili le operazioni speciali di:
- ![](./images/excel_document.png) [Esportazione in excel](/excel_export) elenco dei testi mail di [Sport Club Manager](/start)

![Elenco](./images/elencotestimail.jpg)

### Elenco delle e-mail automatiche
| Codice | Evento scatenante |
|---|---|
| REGISTERMAILMESSAGE | Utente si [registra](/new_user) nel gestionale |
| RESETMAILMESSAGE | Utente richiede [nuova password](/reset_password) |
| SETPASSWORDMAILMESSAGE | Utente [modifica la password](/change_password) |
| NOTIFICAVISITAMEDICAMAILMESSAGE | Amministratore [notifica la prenotazione](/appointment_notification) di una visita medica all'utente |
| RICHIESTAISCRIZIONEMAILMESSAGE | Utente richiede [l'iscrizione al corso](/user_subscribechild_subscription) |
| RIFIUTAISCRIZIONEMAILMESSAGE | Amministratore [rifiuta l'iscrizione](/reject_subscription) |
| APPROVAISCRIZIONEMAILMESSAGE | Amministratore [approva l'iscrizione](/approve_subscription) |
| RICHIESTAPAGAMENTOMAILMESSAGE | Utente [inserisce il pagamento](/user_payments_form) effettuato |
| RIFIUTOPAGAMENTOMAILMESSAGE | Amministratore [rifiuta pagamento](/reject_payment) dichiarato dall'utente |
| CONFERMAPAGAMENTOMAILMESSAGE | Amministratore [conferma pagamento](/approve_payment) |
| RICEVUTADISPONIBILEMAILMESSAGE | Amministratore [genera i documenti](/deductions_generate_documents) per le detrazioni fiscali |
