# FAQ di Sport Club Manager
Elenco delle domande più frequenti.

### Q. Posso utilizzare il prodotto con Android o iOS?
A. Si, la versione per SmartPhone funziona sia con Android che con iOS, perché “gira” nel browser dello smartphone.

### Q. Posso inserire le anagrafiche già in mio possesso (es. cambiando software)?
A. Si, offriamo assistenza per il servizio di migrazione dati al nostro gestionale. A questo scopo forniamo un foglio Excel con la struttura dei dati di cui il sistema ha bisogno.

### Q. Posso fornire l'app a tutti i genitori/soci?
A. Si, S.C.M. è pensato proprio per essere utilizzato da tutti i genitori/soci della tua ASD. Ognuno di loro avrà il proprio account personale sul quale potrà operare con il [menu “utente/socio”](/user_application). La registrazione del genitore è a cura dell'utente, inserendo il proprio codice fiscale: se le anagrafiche sono state migrate l'utente verrà agganciato automaticamente ai suoi dati anagrafici e al suo nucleo famigliare.

### Q. Come posso utilizzare la app come amministratore e genitore?
A. Ogni utente/genitore viene "riconosciuto" con il proprio codice fiscale ed opera con il [menu “utente/socio”](/user_application). Gli "amministratori" invece vengono registrati con un identificativo personale (es. COGNOME.NOME) ed operano nel [menu “amministratore”](/administrator_menu).

### Q. Come posso controllare le scadenze delle visite mediche?
A. Lo stato delle visite mediche è consultabile nella gestione anagrafica, sia nell'elenco dei [nominativi](/admin_people) che nell'area dedicata alle [visite mediche](/admin_medicalvisits).

### Q. Chi prenota le visite mediche?
A. Ѐ l'amministratore che prenota la visita e avvisa l'utente/genitore via e-mail nell'area dedicata alle [visite mediche](/admin_medicalvisits). Lato utente, invece, il genitore può inserire una visita in [appuntamento visita](/user_medicalvisits) come promemoria o caricare tutti i dati della visita insieme al certificato in [certificato medico](/user_medicalcertificate).

### Q. Chi inserisce l'esito di una visita medica e il relativo certificato?
A. Sia l'amministratore che l'utente/genitore possono caricare il certificato e dichiarare l'esito della visita medica.

### Q. Come posso differenziare le condizioni di iscrizione ai vari corsi?
A. Si, S.C.M. prevede la possibilità di configurare l’iscrizione ai vari corsi/squadre della tua A.S.D. L’iscrizione verrà fatta direttamente dal genitore, così non dovrai più inserire alcun dato manualmente.

### Q. Da utente/socio posso iscrivermi a un corso in autonomia?
A. Si e i passaggi per l'iscrizione sono gli stessi effettuati dai genitori.

### Q. Che cos'è lo sconto fratelli?
A. Lo sconto fratelli per l'iscrizione di più figli (richiesto da parte del utente/genitore o concesso direttamente dal amministratore in fase di [approvazione dell'iscrizione](/admin_subscriptions_subscription)) può essere stabilito sia in importo fisso che in percentuale nella [campagna di iscrizione](/admin_subscriptioncampaigns), l'importo dello sconto rimane comunque modificabile da parte del amministratore in fase di approvazione.

### Q. Che cos'è lo sconto rata unica?
A. Lo sconto rata unica (se previsto nella [quota iscrizione](/admin_subscriptionfees_subscriptionfee) del corso) applica lo sconto stabilito nel caso in cui l'utente/genitore effettui un pagamento unico che copra tutte le rate del corso, l'importo dello sconto rimane comunque modificabile da parte del amministratore in fase di [approvazione dell'iscrizione](/admin_subscriptions_subscription).

### Q. Da amministratore come convalido le richieste di iscrizione?
A. Nell'area dedicata alle [iscrizioni](/admin_subscriptions), dopo aver selezionato l'iscrizione desiderata, fare clic sul pulsante "Approva iscrizione".

### Q. Come gestire gli sconti/abbuoni/voucher in fase di approvazione di una iscrizione?
A. Lo sconto/abbuono/voucher si può specificare nelle [rate di iscrizione](/admin_subscriptions_subscriptioninstalment) al corso.

### Q. Come creo la nuova stagione?
A. Nel [menu "amministratore"](/administrator_menu), alla voce Parametri - Parametri gestionali è possibile gestire le [stagioni](/admin_seasons_season) sportive, inoltre il pulsante "[Duplica campagne](/duplicate_campaigns)" genera tutte le campagne dell'ultima stagione in quella nuova, aggiornando le date di scadenza delle quote e i limiti di età degli iscritti.

### Q. Come personalizzare il testo di una mail automatica?
A. Alla voce Gestione Email nel [menu "amministratore"](/administrator_menu) è possibile gestire i [testi email](/emailtemplates) delle mail automatiche. Ad es. se si vuole modificare la mail di [approvazione iscrizione](/approve_subscription) (APPROVAISCRIZIONEMAILMESSAGE), potete indicare anche la quota della prima rata da pagare per evitare incomprensioni con chi deve pagare, in questo modo:

> La tua iscrizione a **{SubscriptionFee}** é stata approvata per un importo totale di € **{SubscriptionTotal}**.
> Dovrai provvedere al pagamento della prima rata di € **{RataIscrizione:1:TotalAmount}** entro il **{RataIscrizione:1:DueDate}**, seguendo queste istruzioni:
> **#IstruzioniIscrizione#**
> Se hai ricevuto per sbaglio questa mail o le informazioni non ti sembrano corrette, contattaci scrivendo a: **%Config:SportsClubEmail%**
> Cordiali saluti.
> Lo staff di **%Config:SportsClubName%**

Il programma farà le seguenti sostituzioni:

> **{SubscriptionFee}** -> nome del corso.
> **{SubscriptionTotal}** -> l'importo totale dovuto (comprensivo di sconti).
> **{RataIscrizione:1:Amount}** -> l'importo della prima rata.
> **{RataIscrizione:1:DueDate}** -> scadenza della prima rata.
> **#IstruzioniIscrizione#** -> istruzioni presenti nella campagna iscrizioni (dove potrai indicare le modalità con cui pagare, dove e quando, ecc...).

Abbiamo a vostra disposizione una [lista dei campi variabili](/emailtemplates_emailtemplate) che potrete utilizzare a seconda del tipo di mail.

### Q. Come correggo e rinvio una mail automatica?
A. Nel [menu "amministratore"](/administrator_menu), alla voce **Gestione Email**, è possibile gestire la [Coda Email](/emailqueue) per la modifica dei messaggi. Una volta apportate le modifiche desiderate nella [maschera di modifica](/emailqueue_emailqueue), la **Data Ora di Trasmissione** deve essere rimossa per effettuare il rinvio della mail.
