# KittoX su Linux: ambiente di test (WSL)

Gli eseguibili Linux si compilano su Windows con `dcclinux64` e si eseguono in un
Ubuntu che gira dentro Windows (WSL 2). Non servono l'IDE, il suo SDK Manager né
PAServer: gli script copiano da Ubuntu le librerie che il linker usa e passano
tutto al compilatore da riga di comando.

## Una volta sola

1. **WSL** (PowerShell come amministratore), poi **riavviare Windows**:
   ```
   wsl --install --no-distribution
   ```
2. **Ubuntu e i pacchetti** (PowerShell normale, dalla cartella del repository):
   ```
   powershell -ExecutionPolicy Bypass -File Tools\Linux\Install-KittoXLinux.ps1
   ```
   Installa Ubuntu 24.04 senza domande, crea l'utente `kittox`, installa compilatore
   C, ICU, i client di PostgreSQL, Firebird e SQL Server (ODBC 18), estrae PAServer
   in `/opt` e imposta la rete *mirrored*: dentro Linux `127.0.0.1` è questo PC, quindi
   i test raggiungono gli stessi database con lo stesso `TestDatabases.yaml`.
3. **SDK** (le librerie di sistema per il linker):
   ```
   powershell -ExecutionPolicy Bypass -File Tools\Linux\Import-LinuxSdk.ps1
   ```
   Le mette in `%LOCALAPPDATA%\KittoX\LinuxSDK\Ubuntu-24.04` (oppure dove indica la
   variabile `KX_LINUX_SDK`). Va rifatto solo se si installano in Ubuntu nuovi
   pacchetti di sviluppo.
4. **Firebird con EMPLOYEE** (solo per KEmployee, e solo se un Firebird con quel
   database non risponde già su `127.0.0.1:3050`):
   ```
   wsl -d Ubuntu-24.04 -- bash -c "tr -d '\r' < /mnt/d/ETHEA/KittoX/Tools/Linux/setup_firebird_employee.sh | sudo bash -s"
   ```
   Firebird 3 in Ubuntu, database creato dallo script d'esempio del pacchetto, alias
   `EMPLOYEE`, SYSDBA/masterkey come nella `Config.yaml` di KEmployee.
5. **Le tre demo come servizi** (HelloKitto, TasKitto, KEmployee):
   ```
   Tools\Linux\deploy_examples_linux.cmd
   ```
   Compila, copia in `~/kittox` e installa i servizi `kittox-hellokitto`,
   `kittox-taskitto`, `kittox-kemployee` (porte 3621, 3622, 3623).

## Ogni volta

```
Test\run_tests_linux.cmd            compila per Linux64 ed esegue i test in Ubuntu
Test\run_tests_linux.cmd Debug nobuild   esegue l'ultima build senza ricompilare
Test\build_linux.cmd                solo compilazione
```

## Un'applicazione su Linux

Lo stesso `.dpr` standalone di Windows (quello con `Kitto.Vcl.Start`): fuori da
Windows parte senza interfaccia, come servizio o da terminale, e si ferma con
SIGTERM/SIGINT (`systemctl stop`, Ctrl+C). Nella `UseKitto.pas` le unit solo
Windows (ADO, driver DBExpress, `Kitto.Tool.ADO`, `Kitto.Tool.DebenuQuickPDF`) vanno
racchiuse in `{$IFDEF MSWINDOWS}`, come in HelloKitto.

```
Tools\Linux\build_app_linux.cmd Examples\HelloKitto\Projects\HelloKitto.dpr
Tools\Linux\deploy_app_linux.cmd Examples\HelloKitto\Projects\HelloKitto.dpr
wsl -d Ubuntu-24.04 -- ~/kittox/App/HelloKitto/Home/HelloKitto
```

Il deploy copia nel file system di Linux, con lo stesso layout di IIS che
`Kitto.Config` riconosce da sé:

```
~/kittox/Home/                     System Home (risorse del framework)
~/kittox/App/HelloKitto/Home/      Home dell'applicazione + eseguibile
```

Poi si apre `http://localhost:3621/hellokittox/` dal browser di Windows.

Come servizio systemd (unit `kittox-hellokitto`, log nel journal):

```
wsl -d Ubuntu-24.04 -- bash -c "tr -d '\r' < /mnt/d/ETHEA/KittoX/Tools/Linux/install_service.sh | sudo bash -s -- HelloKitto"
wsl -d Ubuntu-24.04 -- journalctl -u kittox-hellokitto -f
```

Con la rete mirrored la porta è condivisa con Windows: un servizio abilitato in
WSL occupa la porta anche per la versione Windows della stessa applicazione.
`systemctl disable --now kittox-hellokitto` lo spegne.

## Comandi utili

| Cosa | Comando |
|---|---|
| Aprire una shell Ubuntu | `wsl -d Ubuntu-24.04` |
| Spegnere WSL (libera memoria) | `wsl --shutdown` |
| I file di Windows da Linux | `/mnt/c/...`, `/mnt/d/...` |
| I file di Linux da Windows | `\\wsl.localhost\Ubuntu-24.04\home\kittox` |

## Da sapere

- I test girano direttamente da `D:\` (`/mnt/d/...`). Quel file system **non distingue
  maiuscole e minuscole**, come Windows; un server Linux vero invece sì. I problemi di
  maiuscole nei nomi dei file YAML si vedono solo copiando l'applicazione dentro Linux
  (per esempio in `/home/kittox`), che è quello che fa `deploy_app_linux.cmd`.
- Da Git Bash, prima di `wsl.exe --cd /mnt/...`: `export MSYS_NO_PATHCONV=1`.
- **Dal browser di Windows usare `127.0.0.1`, non `localhost`.** `localhost` va prima
  su `::1`; il server ascolta solo in IPv4 e con la rete mirrored la connessione IPv6
  resta appesa invece di essere rifiutata, e ogni richiesta paga il ritardo.
- **WSL si spegne da solo** pochi secondi dopo la chiusura dell'ultimo `wsl.exe`, e
  con lui i servizi. Per tenerlo acceso: una finestra con `wsl -d Ubuntu-24.04`
  aperta, oppure in `%USERPROFILE%\.wslconfig`
  ```
  [general]
  instanceIdleTimeout=-1
  [wsl2]
  vmIdleTimeout=-1
  ```
  seguito da `wsl --shutdown`. I servizi abilitati ripartono a ogni avvio di Ubuntu.
- `smoke_test.py <url> <utente> <password>` verifica un'applicazione avviata: home,
  risorse, login e ogni view (con `VIEWDIR=<Home>\Metadata\Views` tutte quelle del
  progetto, non solo quelle del primo menu).
- PAServer serve solo per fare debug dall'IDE: si avvia con `/opt/PAServer-37.0/paserver`.
