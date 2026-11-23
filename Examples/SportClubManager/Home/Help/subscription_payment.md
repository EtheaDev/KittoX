# Pagamento iscrizione


#### Parametrizzazione Causale:
![](./images/causincassoiscrizione.jpg)


#### Parametrizzazione righe:
Per ogni tipologia di pagamento/Banca è necessario indicare il conto contabile da utilizzare.
![](./images/causincassoiscrizioneconti.jpg)

### Scrittura automatica di “Incasso iscrizioni”

Al Pagamento dell’iscrizione vengono effettuate più scritture contabili automatiche di incasso iscrizioni, una per ogni rata che viene pagata.

Viene inserito un movimento per ogni rata pagata. In caso di pagamento parziale, la partita rimarrà aperta per l’importo ancora da pagare.

Per ogni movimento, viene creata una riga in Dare con l’importo totale del bonifico con il conto contabile definito in Dare nei Conti Automatici, in base al tipo di pagamento e alla banca.

Viene creata una riga Avere con il conto definito in Avere (Quote iscrizioni da incassare) con il riferimento partita composto da Codice Fiscale dell’iscritto + data scadenza della rata iscrizione, in modo da chiudere il credito.


#### Movimento

| Campo | Contenuto |
|---|---|
| ID | GUID |
| DX | Descrizione della causale contabile |
| ESERCID | Esercizio calcolato dalla data pagamento |
| NR_MOV | Numero movimento dall’esercizio |
| UTENTE_INSERIMENTOID | Utente che ha effettuato l’inserimento del pagamento |
| DATA_REG | Data pagamento |
| TIPO_MOV | TIPO_REG della causale automatica |
| CAUSALEID | ID Causale contabile |
| MOD_PAGAMENTOID | ID Modalità di pagamento |
| BANCAID | ID Banca su cui è stato effettuato il pagamento |
| IMPORTO | Importo totale dell’iscrizione |

#### Righe

| Campo | Contenuto Righe Dare | Contenuto Riga Avere |
|---|---|---|
| ID | GUID | GUID |
| MOVIMENTOID | ID Movimento | ID Movimento |
| NR_RIGA | Numero riga sequenziale | Numero riga sequenziale |
| UTENTE_INSERIMENTOID | Utente che ha effettuato l’inserimento del pagamento | Utente che ha effettuato l’inserimento del pagamento |
| CONTOID | Conto automatico Dare a seconda della modalità di pagamento/ banca | Conto Automatico Avere |
| SEGNO | Dare | Avere |
| DX | Descrizione rata iscrizione pagata | Descrizione rata iscrizione pagata |
| DATASCADENZA | Data pagamento | Data pagamento |
| PARTITA |  | Codice fiscale + data scadenza rata iscrizione pagata |
| IMPORTO | Importo pagamento rata | Importo pagamento rata |
| NOMINATIVOID | ID  Nominativo della rata iscrizione pagata | ID  Nominativo della rata iscrizione pagata |
| BANCAID | ID Banca su cui è stato effettuato il pagamento | ID Banca su cui è stato effettuato il pagamento |
