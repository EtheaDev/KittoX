# Chiusura bilancio


#### Parametrizzazione Causale:
![](./images/causchiusurabil.jpg)


#### Parametrizzazione righe:
Indicare il conto da usare come contropartita sia in Dare che Avere una per lo stato patrimoniale che deve essere nel passivo del Bilancio e uno per il Conto Economico che deve essere nei costi:
![](./images/causchiusurabilconti.jpg)

## Scrittura automatica di “Chiusura bilancio”

Dal bilancio è possibile eseguire le scritture automatiche di apertura e chiusura del bilancio di un esercizio contabile.

Viene inserito un movimento per ogni sottoconto contabile dello stato patrimoniale (Sezione=Passivo/Attivo) e del conto economico (Sezione=Costi/Ricavi) con saldo diverso da zero.

Per ogni movimento, se il sottoconto ha i riferimenti al Cliente o Fornitore o Socio viene creata una riga con il Saldo Dare e/o Avere per ogni controparte con segno inverso, e come contropartita avrà una riga Dare e/o Avere con l’importo totale dei saldi contabili con il conto contabile definito in Dare e/o Avere nei Conti Automatici a seconda che il sottoconto è nello stato patrimoniale o nel conto economico prende il conto nel Passivo o nei Costi, se il sottoconto non ha i riferimenti al Cliente o Fornitore o Socio viene creata una riga con il Saldo Dare o Avere del sottoconto e una riga Dare o Avere con il conto contabile definito in Dare o Avere nei Conti Automatici a seconda che il sottoconto è nello stato patrimoniale o nel conto economico prende il conto nel Passivo o nei Costi.


#### Movimento

| Campo | Contenuto |
|---|---|
| ID | GUID |
| DX | Descrizione della causale contabile |
| ESERCID | Esercizio di chiusura |
| NR_MOV | Numero movimento dall’esercizio |
| UTENTE_INSERIMENTOID | Utente che ha effettuato l’apertura/chiusura bilancio |
| DATA_REG | Data fine esercizio |
| TIPO_MOV | TIPO_REG della causale automatica |
| CAUSALEID | ID Causale contabile |
| IMPORTO | Totale Saldo Dare + Totale Saldo Avere |


#### Righe

| Campo | Contenuto Righe Dare | Contenuto Riga Avere |
|---|---|---|
| ID | GUID | GUID |
| MOVIMENTOID | ID Movimento | ID Movimento |
| NR_RIGA | Numero riga sequenziale | Numero riga sequenziale |
| UTENTE_INSERIMENTOID | Utente che ha effettuato l’apertura/chiusura bilancio | Utente che ha effettuato l’apertura/chiusura bilancio |
| CONTOID | Conto con saldo in Avere o contropartita saldo Dare conto automatico definito in Dare | Conto con saldo in Dare o contropartita saldo Avere conto automatico definito in Avere |
| SEGNO | Dare | Avere |
| DX | Descrizione conto | Descrizione conto |
| DATASCADENZA | Data fine esercizio | Data fine esercizio |
| IMPORTO | Saldo del conto in Avere o Totale del saldo Dare | Saldo del conto in Dare o Totale del saldo Avere |
| NOMINATIVOID | ID  Nominativo se il conto ha riferimento Socio | ID  Nominativo se il conto ha riferimento Socio |
| CLIENTEID | ID  Cliente se il conto ha riferimento Cliente | ID  Cliente se il conto ha riferimento Cliente |
| FORNITOREID | ID  Fornitore se il conto ha riferimento Fornitore | ID  Fornitore se il conto ha riferimento Fornitore |
