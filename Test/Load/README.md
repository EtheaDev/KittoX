# Banco di prova sotto carico

Misura una applicazione KittoX sui due stack HTTP — **Indy** e **HTTP.sys** — e mette le due
colonne vicine. Serve a rispondere a una domanda sola: *cosa cambia a cambiare stack?*

| | |
|---|---|
| `KXLoadServer.dpr` | Serve HelloKitto, senza finestre, sullo stack che gli si dice. È l'host console del framework con lo stack preso da un argomento invece che dalla configurazione: così la stessa applicazione si misura su entrambi senza modificare un file fra una prova e l'altra |
| `KXLoadTest.dpr` | N thread che chiedono lo stesso indirizzo per S secondi, su connessioni tenute aperte. Ne escono richieste al secondo e la latenza ai percentili che contano |
| `run_load.ps1` | Fa girare tutto su entrambi gli stack, per ogni scenario e ogni livello di concorrenza, e stampa il confronto |
| `run_load_jwt.ps1` | Lo stesso banco puntato su TasKitto, per il percorso con login e JWT: si veda più sotto |

## Compilare

```
dcc64 -B -U"<Source>;<Source\EF>;<Source\ThirdParty>;...;<Examples\HelloKitto\Source>" ^
      -NU.\dcu KXLoadServer.dpr
dcc64 -B -NU.\dcu KXLoadTest.dpr
```

I percorsi sono quelli del `.dproj` di HelloKitto. Il server ha bisogno anche di
`Examples\HelloKitto\Source`, perché collega le stesse unit del `.dpr` dell'esempio — senza,
l'applicazione non si configura.

## Misurare

```powershell
& .\run_load.ps1
& .\run_load.ps1 -Seconds 20 -Concurrency 1,16,64 -Scenarios home,static
```

**Si lancia con l'operatore di chiamata, non con `powershell -File`.** Con `-File` l'array
`1,8,32,64` arriva come una stringa sola e PowerShell lo legge come il numero **183264**: la
prima volta è successo davvero, e il banco ha ubbidito lanciando centottantatremila thread. Ora
una concorrenza fuori da 1–1024 viene rifiutata, spiegando perché.

### Gli scenari

| | |
|---|---|
| `home` | La home dell'applicazione **con il cookie di sessione**: tutta la catena — sessione, instradamento, metadati, rendering |
| `static` | Un foglio di stile da `Resources`, con il cookie: il percorso corto, dove lo stack pesa di più |
| `cold` | La home **senza cookie**: ogni richiesta apre una sessione. Non è quello che fa un browser, ed è il punto — misura quanto costa una raffica di prime visite |

## Il percorso JWT: TasKitto

HelloKitto non ha login (`Auth: Null`), quindi il banco qui sopra non passa mai dalla verifica
di un token, dalla reidratazione della sessione, dal controllo degli accessi. Per quello c'è
`run_load_jwt.ps1`, che serve **TasKitto**.

Il server è lo stesso sorgente compilato con `-DTASKITTO`, che collega le unit di TasKitto al
posto di quelle di HelloKitto. Va compilato in una cartella a parte e portato qui con un altro
nome, perché i percorsi di `Home` sono relativi all'eseguibile:

```
dcc64 -B -DTASKITTO -U"<gli stessi percorsi, senza Examples\HelloKitto\Source>" ^
      -NU.\dcu_taskitto -E.\taskitto KXLoadServer.dpr
move taskitto\KXLoadServer.exe KXLoadServerTasKitto.exe
```

Serve il database di TasKitto raggiungibile (quello di `Config.yaml`).

```powershell
& .\run_load_jwt.ps1
& .\run_load_jwt.ps1 -Seconds 15 -Concurrency 2,8,32
```

| | |
|---|---|
| `data` | `kx/view/Customers/data` con il token: verifica, reidratazione, ACL e una query, tutto su **un solo** oggetto sessione da tutti i thread |
| `page` | `kx/view/Dashboard` con il token: lo stesso, passando dal rendering di una view |
| `reload` | Le due schede: un generatore legge `data` mentre un altro ricarica la home **con lo stesso token** |
| `reload-session` | Come sopra, ma la scheda che ricarica manda **solo il cookie di sessione** |

Con il JWT tutte le richieste con lo stesso token finiscono sullo stesso oggetto sessione, che è
ciò che si vuole scuotere. Lo script fa il login da sé e passa sessione e token al generatore
con `--cookie=`; le view vogliono anche `--header="X-KittoX: true"`, altrimenti il server le
prende per un indirizzo digitato a mano e rimanda alla home.

**Qui non conta la velocità, conta la colonna degli errori**, e in particolare che non ci sia
nessun 500. I 404 dei due scenari `reload` vanno letti così:

- `reload`: arrivare sulla home scollega l'utente e **revoca il token**, apposta. Da lì in poi
  le richieste `data` sono respinte, quasi tutte: è la risposta giusta.
- `reload-session`: la home scollega la sessione, ma senza token nella richiesta non c'è nulla
  da revocare. Ogni richiesta `data` ricollega la sessione dal proprio token, e le due parti si
  contendono lo stesso oggetto per tutta la corsa. La gran parte delle `data` riesce; qualcuna,
  presa fra lo scollegamento e il collegamento successivo, viene respinta dal cancello delle
  autorizzazioni. È una corsa vera fra richieste della stessa sessione, ma è un rifiuto, non un
  crollo.

## Come si leggono i numeri

**Generatore e server girano sulla stessa macchina** e si dividono il processore. I numeri
servono a confrontare uno stack con l'altro — che è il loro scopo — e **non** a dichiarare quante
richieste regge un server.

La colonna degli errori non è un dettaglio: è lì che questo banco ha trovato un access violation
dell'applicazione sotto richieste concorrenti della stessa sessione. Si veda
`KittoX_HttpSys.md` §7.3.

## Che cosa non misura

Niente POST, niente form, niente upload, nessuna query pesante: le quattro richieste che fa sono
quelle che tutte le applicazioni fanno. Chi vuole misurare la *propria* applicazione punti
`--url=` dove gli serve.
