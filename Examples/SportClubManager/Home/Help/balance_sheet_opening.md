# Apertura bilancio


#### Parametrizzazione Causale:
![](./images/causaperturabil.jpg)


#### Parametrizzazione righe:
Indicare il conto da usare come contropartita sia in Dare che Avere:
![](./images/causaperturabilconti.jpg)

## Scrittura automatica di “Apertura bilancio”

Dal bilancio è possibile eseguire le scritture automatiche di apertura e chiusura del bilancio di un esercizio contabile.

Viene inserito un movimento per ogni sottoconto contabile dello stato patrimoniale (Sezione=Passivo/Attivo) con saldo diverso da zero.

Per ogni movimento, se il sottoconto ha i riferimenti al Cliente o Fornitore o Socio viene creata una riga con il Saldo Dare e/o Avere per ogni controparte come era aperta nell’esercizio chiuso, e come contropartita avrà una riga Dare e/o Avere con l’importo totale dei saldi contabili con il conto contabile definito in Dare e/o Avere nei Conti Automatici, se il sottoconto non ha i riferimenti al Cliente o Fornitore o Socio viene creata una riga con il Saldo Dare o Avere del sottoconto e una riga Dare o Avere con il conto contabile definito in Dare o Avere nei Conti Automatici.


#### Movimento

| Campo | Contenuto |
|---|---|
| ID | GUID |
| DX | Descrizione della causale contabile |
| ESERCID | Esercizio successivo a quello di chiusura |
| NR_MOV | Numero movimento dall’esercizio |
| UTENTE_INSERIMENTOID | Utente che ha effettuato l’apertura/chiusura bilancio |
| DATA_REG | Data inizio esercizio |
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
| CONTOID | Conto con saldo in Dare o contropartita saldo Avere conto automatico definito in Dare | Conto con saldo in Avere o contropartita saldo Dare conto automatico definito in Avere |
| SEGNO | Dare | Avere |
| DX | Descrizione conto | Descrizione conto |
| DATASCADENZA | Data inizio esercizio | Data inizio esercizio |
| IMPORTO | Saldo del conto in Dare o Totale del saldo Avere | Saldo del conto in Avere o Totale del saldo Dare |
| NOMINATIVOID | ID  Nominativo se il conto ha riferimento Socio | ID  Nominativo se il conto ha riferimento Socio |
| CLIENTEID | ID  Cliente se il conto ha riferimento Cliente | ID  Cliente se il conto ha riferimento Cliente |
| FORNITOREID | ID  Fornitore se il conto ha riferimento Fornitore | ID  Fornitore se il conto ha riferimento Fornitore |
