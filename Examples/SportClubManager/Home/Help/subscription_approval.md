# Approvazione Iscrizione


#### Parametrizzazione Causale:
![](./images/causapprovazioneiscrizione.jpg)


#### Parametrizzazione righe:
Indicare i conti da movimentare in dare e in Avere.
![](./images/causapprovazioneiscrizioneconti.jpg)

## Scrittura automatica di “Approvazione iscrizione – apertura credito”

Quando l’operatore amministrativo procede all’approvazione di una iscrizione ad un corso, il sistema utilizza questa causale automatica per l’apertura del credito verso il socio.

Viene creata una riga Avere con l’importo totale dell’iscrizione con il conto contabile definito in Avere nei Conti Automatici.

Vengono create più righe Dare con il conto definito in dare per ogni rata prevista dalla quota iscrizione per cui viene approvata l’iscrizione al socio, con il riferimento partita composto da Codice Fiscale dell’iscritto + data scadenza della rata iscrizione.

#### Movimento

| Campo | Contenuto |
|---|---|
| ID | GUID |
| DX | Descrizione della causale contabile |
| ESERCID | Esercizio calcolato dalla data iscrizione |
| NR_MOV | Numero movimento dall’esercizio |
| UTENTE_INSERIMENTOID | Utente che ha effettuato l’approvazione dell’iscrizione |
| DATA_REG | Data iscrizione |
| TIPO_MOV | TIPO_REG della causale automatica |
| CAUSALEID | ID Causale contabile |
| IMPORTO | Importo totale dell’iscrizione |

#### Righe

| Campo | Contenuto Righe Dare | Contenuto Riga Avere |
|---|---|---|
| ID | GUID | GUID |
| MOVIMENTOID | ID Movimento | ID Movimento |
| NR_RIGA | Numero riga sequenziale | Numero riga sequenziale |
| UTENTE_INSERIMENTOID | Utente che ha effettuato l’approvazione dell’iscrizione | Utente che ha effettuato l’approvazione dell’iscrizione |
| CONTOID | Conto automatico Dare | Conto Automatico Avere |
| SEGNO | Dare | Avere |
| DX | Descrizione rata iscrizione | Descrizione rata iscrizione |
| DATASCADENZA | Data scadenza rata iscrizione | Data iscrizione |
| PARTITA | Codice fiscale + data scadenza rata iscrizione |  |
| IMPORTO | Importo rata iscrizione | Importo iscrizione |
| NOMINATIVOID | ID  Nominativo iscritto |  |
