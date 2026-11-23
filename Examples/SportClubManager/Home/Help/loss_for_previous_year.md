# Perdita d’esercizio precedente


#### Parametrizzazione Causale:
![](./images/causperditaprec.jpg)


#### Parametrizzazione righe:
Indicare i conti da usare in Dare e Avere per la scrittura:
![](./images/causperditaprecconti.jpg)

## Scrittura automatica di “Perdita d’esercizio precedente”

Dal bilancio è possibile eseguire le scritture automatiche di apertura e chiusura del bilancio di un esercizio contabile.

Viene inserito un movimento con la perdita dell’esercizio chiuso se i costi dell’esercizio sono maggiori dei ricavi.

Viene creato un movimento contabile con l’importo della perdita d’esercizio e una riga Dare e una Avere come parametrizzata nella causale automatica.




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
| IMPORTO | Importo perdita d’esercizio |


#### Righe

| Campo | Contenuto Righe Dare | Contenuto Riga Avere |
|---|---|---|
| ID | GUID | GUID |
| MOVIMENTOID | ID Movimento | ID Movimento |
| NR_RIGA | Numero riga sequenziale | Numero riga sequenziale |
| UTENTE_INSERIMENTOID | Utente che ha effettuato l’apertura/chiusura bilancio | Utente che ha effettuato l’apertura/chiusura bilancio |
| CONTOID | Conto automatico definito in Dare | Conto automatico definito in Avere |
| SEGNO | Dare | Avere |
| DX | Descrizione conto | Descrizione conto |
| DATASCADENZA | Data inizio esercizio | Data inizio esercizio |
| IMPORTO | Importo perdita d’esercizio | Importo perdita d’esercizio |
