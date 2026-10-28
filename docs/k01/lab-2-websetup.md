---
tags:
  - Bash
  - Linux
---

# 2. websetup.sh nagu tootmises

Deploy-skript, mis katkeb poole pealt ilma rea numbrita, teisel käivitusel kirjutab üle juba korras seadistuse või töötab Ubuntus, aga jätab Rockys lehe tulemüüri ja SELinuxi taha, on tootmises ohtlikum kui käsitsi töö. Apache'i paigaldus on sulle rutiin. Siin teed sellest skripti, mida julgeksid käivitada võõras tootmisserveris: see näitab enne, mida teeks, peatub vea juures koos rea numbriga, logib journald-isse ja teine käivitus ei muuda midagi.

**Kui teed seda tööl iga päev:** sinu `websetup.sh` täidab juba selle lehe etappide nõuded (`-n`, `-v`, ERR-trap rea numbriga, `logger -t websetup`, peatatud teenuse käivitamine) ja teine käivitus web01-s ütleb "muudatusi pole". Kui see on sul juba korras, mine otse etappi [„Sama skript Rocky's“](#sama-skript-rockys).

## Tee üks kord käsitsi

Käsitsi läbitud rada on skripti spetsifikatsioon.

Kirjutad käsud üles, sest skript peab tegema täpselt sama, ja hiljem võrdled neid skripti logiga. Märkmed näitavad ka, mis sammud olid sinu jaoks nii iseenesestmõistetavad, et sa neid ei märganud, näiteks `unzip`-i paigaldamine.

1. Pane malli URL control node'il muutujasse: `export TEMPLATE_URL=<tahvlilt>` (ka `~/.bashrc`-sse).
2. Paigalda web01-s `apache2`, `wget` ja `unzip`.
3. Laadi mall `/tmp`-sse, paki lahti ja kopeeri malli kausta **sisu** `/var/www/html/` alla.
4. Kirjuta tehtud käsud `k01-bash/NOTES.md`-sse pealkirja "Veebileht käsitsi" alla.
5. Kontrolli control node'ilt: `curl -sI http://web01 | head -1`

> Apache'i vaikeleht tähendab, et kopeerisid kausta `/var/www/html/<mall>/`, mitte selle sisu.

<!-- EKRAANIPILT: brauser (VPN-iga) aadressil http://<web01 IP>, näha on Tooplate'i mall (mitte Apache "It works" vaikeleht), aadressiriba nähtav. Tee pärast käsitsi paigaldust.
<figure markdown="span">
  ![Brauseris avatud veebimall web01 aadressil](assets/k01_veebimall.png)
  <figcaption>Joonis L1.4. Käsitsi paigaldatud mall web01-s.</figcaption>
</figure>
-->

`200 OK` control node'ilt tõestab rohkem kui `curl localhost` web01-s: see läbis võrgu ja võimaliku tulemüüri.

✅ **Edasi saad minna, kui** `curl -sI http://web01` annab `200 OK` ja brauser näitab malli.

## Peatu vea juures ja ütle, kus

Skripti esimesed read otsustavad, kas viga jääb märkamata. Ilma `set -e`-ta jätkab Bash pärast ebaõnnestunud `wget`-i ja kopeerib veebijuurde tühja kausta. Ilma ERR-trap'ita lõpeb skript küll, aga sa ei tea, millisel real.

Öine deploy, mis lõpeb koodiga 1 ilma ühegi reata, tähendab hommikul pool tundi logide uurimist. Üks rida `viga real 87 (kood 4): wget …` lühendab selle minutiks. Loo `k01-bash/websetup.sh`, mis teeb sama mis sina käsitsi, nende nõuetega:

- shebang ja `set -eEuo pipefail` (`-E`: ERR-trap kehtib ka funktsioonides)
- `trap … ERR` kirjutab stderr-i rea numbri (`$LINENO`), käsu (`$BASH_COMMAND`) ja koodi ning lõpetab sama koodiga
- ajutine kaust `mktemp -d`-ga, koristus `trap … EXIT`-iga
- töö funktsioonides (`install_pkgs`, `deploy_site` …), faili lõpus `main "$@"`; malli URL esimesest argumendist
- skriptis pole `sudo`-t: see käivitatakse tervikuna root'ina

```bash
on_err() { local rc=$?; …; exit "$rc"; }
trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR
```

Proovi vigase URL-iga: `wget` ebaõnnestub funktsiooni sees ja skript peab ütlema, millisel real.

```bash
scp k01-bash/websetup.sh web01:/tmp/
ssh web01 sudo bash /tmp/websetup.sh https://example.invalid/x.zip; echo "kood $?"
ssh web01 'ls -d /tmp/tmp.*'
```

Kood 4 on `wget`-i oma (võrguviga) ja jõudis sinuni muutmata, sest `on_err` lõpetab sama koodiga. Kui skripti kutsub teine skript, ütleb kood põhjuse tüübi ka siis, kui keegi stderr-i ei loe. Tühi `ls` tõestab, et EXIT-trap koristas ka vea korral. Ilma selleta koguneks `/tmp`-sse iga ebaõnnestunud käivituse järel üks mall.

✅ **Edasi saad minna, kui** stderr-is on rida `viga real N (kood 4): wget …`, kood pole 0 ja `ls` ei leia ühtki `/tmp/tmp.*` kausta.

## Teine käivitus ei muuda midagi

Idempotentne skript kontrollib enne iga muutust, kas seda on vaja, ja ütleb lõpus, mitu muudatust tegi.

Ilma selleta on iga kordus väike katkestus: Apache'i restart katkestab ühendused, paketiindeksi uuendus koormab mirror'it ja kopeerimine muudab failide aega, mis tühjendab vahemälud. Idempotentset skripti võid käivitada kas või iga tunni järel, et drift'i parandada.

- pakett: paigalda ainult puuduvad (`dpkg-query -W`, Rocky's `rpm -q`)
- teenus: `systemctl is-enabled` ja `is-active` enne `enable` ja `start`; restart'i pole, kui midagi ei muutunud
- mall: kopeeri ainult siis, kui mõni malli fail puudub või erineb (`cmp -s`)
- viimane rida on `web01: apache2, mall <nimi> (muudatusi pole)` või `(N muudatust)`

```bash
scp k01-bash/websetup.sh web01:/tmp/
ssh web01 systemctl show apache2 -p ActiveEnterTimestamp
ssh web01 sudo bash /tmp/websetup.sh "$TEMPLATE_URL"
ssh web01 sudo bash /tmp/websetup.sh "$TEMPLATE_URL"
ssh web01 systemctl show apache2 -p ActiveEnterTimestamp
```

Muuda siis web01-s käsitsi üht malli CSS-faili ja käivita uuesti: skript peab selle tagasi võtma ja ütlema "1 muudatust".

Kaks tulemust kokku tõestavad idempotentsust kahest suunast. Sama käivitusaeg näitab, et korrektset süsteemi ei puudutatud. "1 muudatust" näitab, et skript märkab drift'i ja parandab ainult selle. Kui käivitusaeg oleks muutunud, teeb mõni samm restart'i tingimusteta.

✅ **Edasi saad minna, kui** teine käivitus ütleb "muudatusi pole" ja Apache'i käivitusaeg jäi samaks.

## Lisa `-n` ja `-v`

Enne võõrasse serverisse minekut tahad näha, mida skript teeks. Dry-run on sinu plaan, mida saad kolleegile näidata või muudatustaotlusse kopeerida, enne kui midagi muutub. Lisa võtmed `getopts`-iga:

- `-n` dry-run: iga muutev käsk käib läbi ühe funktsiooni, mis `-n` korral ainult trükib `[dry-run] <kirjeldus>: <käsk>`
- `-v` verbose: iga muudatus ka stderr-i
- tundmatu võti: kasutusjuhend stderr-i, kood 2
- pärast `shift $((OPTIND - 1))` on URL jälle `$1`; kui seda pole, `$TEMPLATE_URL`, siis vaikemall (AWS kodutöös käivitub skript user-datana ilma argumentideta)
- dry-run töötab ka ilma root'ita

```bash
change() { local what="$1"; shift; …; }   # change "käivitan $SVC" systemctl start "$SVC"
```

Kustuta web01-s `index.html` ja vaata, mida skript teeks, enne kui ta seda teeb.

```bash
scp k01-bash/websetup.sh web01:/tmp/ && ssh web01 sudo rm /var/www/html/index.html
ssh web01 bash /tmp/websetup.sh -n "$TEMPLATE_URL"
ssh web01 ls /var/www/html/index.html
ssh web01 sudo bash /tmp/websetup.sh -v "$TEMPLATE_URL"
ssh web01 bash /tmp/websetup.sh -x; echo "kood $?"
```

Dry-run näitas ühte rida ja ainult seda, mis puudu oli. See tõestab, et dry-run kasutab samu kontrolle kui jooks ilma `-n`-ita, mitte eraldi nimekirja. Kui dry-run oleks näidanud ka paketi paigaldust, oleks kontroll ja muudatus omavahel lahku läinud. Kood 2 tundmatu võtme korral on Unixi kokkulepe "vale kasutus", mis erineb koodist 1 "töö ebaõnnestus".

✅ **Edasi saad minna, kui** dry-run näitab ainult malli kopeerimist, `index.html` puudub pärast seda endiselt, `-v` taastab selle ja `-x` annab koodi 2.

## Logi journald-isse

Kui skript töötab öösel üle SSH, on terminali väljund kadunud. Iga muudatus ja viga peab jõudma journald-isse.

`logger` kirjutab `/dev/log` socket'isse, mida systemd-l kuulab journald. `-t` saab väljaks `SYSLOG_IDENTIFIER` ja `-p user.err` väljaks `PRIORITY=3`, nii et `journalctl -t` ja `-p` filtreerivad indeksist, mitte teksti järgi. journald piirab teenuse kohta logimise kiirust (`RateLimitIntervalSec=30s`, `RateLimitBurst=10000`): tsüklis iga faili kohta logiv skript võib sellest üle minna ja read kaovad vaikselt.

- `logger -t websetup` iga tehtud muudatuse ja lõpurea kohta
- `on_err` logib prioriteediga `user.err`
- dry-run ei logi muudatusi, mida ei tehtud

```bash
scp k01-bash/websetup.sh web01:/tmp/
ssh web01 sudo bash /tmp/websetup.sh https://example.invalid/x.zip
ssh web01 sudo journalctl -t websetup -n 20 --no-pager
ssh web01 sudo journalctl -t websetup -p err --no-pager
```

`-p err` filter näitab ainult vigu. Monitooringu või logisüsteemi häire saab otsida täpselt sama tingimusega, ilma et peaks su skripti tekstivormi teadma. Kui viga on olemas tavalises vaates, aga mitte `-p err` all, logis `on_err` vale prioriteediga.

✅ **Edasi saad minna, kui** journal'is on tehtud muudatused ja vigase URL-i rida prioriteediga err.

## Peatatud teenus: kas skript märkab

Seni muutsid faile. Drift on sageli ka teenus, mille keegi peatas veaotsingu ajal ja unustas käivitada. Kontrolli, kas sinu skript näeb seda ja teeb ainult selle ühe asja.

1. Peata web01-s Apache ja vaata, mida skript teeks.

    ```bash
    ssh web01 sudo systemctl stop apache2
    ssh web01 bash /tmp/websetup.sh -n "$TEMPLATE_URL"
    ```

2. Käivita ilma `-n`-ita ja vaata journal'ist, mis kirja läks.

    ```bash
    ssh web01 sudo bash /tmp/websetup.sh "$TEMPLATE_URL"
    ssh web01 sudo journalctl -t websetup -n 3 --no-pager
    curl -sI http://web01 | head -1
    ```

Dry-run näitab ainult teenuse käivitamist ja jooks ilma `-n`-ita ütleb "1 muudatust". See tõestab, et `enabled` ja `active` on skriptis kaks eri kontrolli. Kui skript oleks öelnud "muudatusi pole", kontrollib see ainult, kas teenus käivitub boodil, ja jätaks peatatud Apache'i peatatuks kuni järgmise reboot'ini.

✅ **Edasi saad minna, kui** dry-run näitab ühte rida `käivitan apache2`, jooks ilma `-n`-ita ütleb "1 muudatust" ja `curl` annab `200 OK`.

## Sama skript Rocky's

mc01 on Rocky 9 ja selle snapshot `algus` on alles, nii et katseta seal julgelt. Enne stacki paigaldust viid mc01 tagasi puhtaks. Esimene käivitus ebaõnnestub `apt-get`-i peal.

Rocky's on lisaks paketihaldurile teine teenuse nimi, firewalld ja SELinux `enforcing`-režiimis. Need on täpselt need kohad, kus Ubuntu jaoks kirjutatud skript "töötab", kuid leht ei avane.

- distro `/etc/os-release` `ID` järgi: `ubuntu|debian` → `apt-get`, `apache2`; `rocky|rhel|almalinux` → `dnf`, `httpd`; muu → viga, kood 1
- alguses `cloud-init status --wait`; apt-ile `-o DPkg::Lock::Timeout=120` ja `DEBIAN_FRONTEND=noninteractive`
- firewalld: ainult siis, kui see töötab, ja `--query-service=http` enne `--add-service`
- SELinux: `restorecon -Rnv` ütleb, kas kontekst vajab parandust; paranda ainult siis

```bash
scp k01-bash/websetup.sh mc01:/tmp/ && scp k01-bash/websetup.sh web01:/tmp/
ssh mc01 sudo bash /tmp/websetup.sh "$TEMPLATE_URL"
ssh mc01 sudo bash /tmp/websetup.sh "$TEMPLATE_URL"
curl -sI http://mc01 | head -1
ssh web01 sudo bash /tmp/websetup.sh "$TEMPLATE_URL"
```

> mc01-s töötab `curl localhost`, aga control node'ilt mitte: vaata `ssh mc01 sudo firewall-cmd --list-services`.

Viimane rida on sama tähtis kui Rocky jooks: muudatus, mis lisas Rocky toe, ei tohi muuta Ubuntu käitumist. "Muudatusi pole" web01-s tõestab, et uued harud ei tööta vales distros. Rocky teine jooks tõestab, et ka tulemüür ja SELinux kontrollivad enne muutmist.

✅ **Edasi saad minna, kui** `curl -sI http://mc01` annab `200 OK` ning teine käivitus mc01-s ja web01-s ütleb "muudatusi pole".

## ShellCheck ja commit

ShellCheck leiab vead, mida testid ei leia, sest need avalduvad ainult erilise sisendiga: tühik failinimes, tühi muutuja, glob, mis ei leia midagi. `-S warning` on automaatse hindaja tase, nii et puhas tulemus siin tähendab puhast tulemust ka seal.

```bash
shellcheck -S warning k01-bash/websetup.sh
bash autograde/check.sh k01 parameters
chmod +x k01-bash/websetup.sh
git add k01-bash/websetup.sh k01-bash/NOTES.md
git commit -m "websetup.sh: dry-run, ERR-trap, journald, Ubuntu ja Rocky" && git push
```

Kirjuta üks ShellChecki kood, mille parandasid, ja selle oht ühe lausega `NOTES.md`-sse. Kui ShellCheck vaikis kohe, vaata `shellcheck -S style`.

`parameters` on automaatse hindaja kontroll, mida saad kohapeal käivitada. See ei käivita sinu skripti, vaid vaatab, kas selles on argument, distro tuvastus ja funktsioonid. Läbimine ei tõesta, et skript töötab; seda tõestasid eelmised etapid.

✅ **Edasi saad minna, kui** ShellCheck on vaikne ja `parameters` annab `OK`.

📎 **Selle mooduli tõend:** commit `websetup.sh: …`; `NOTES.md`-s käsitsi käsud, kahe käivituse väljund web01-st ja mc01-st, peatatud Apache'i test, `journalctl -t websetup` väljavõte ja SC-kood.

## Miks see nii töötab

**Bashi strict mode.** `pipefail` annab torule parempoolseima nullist erineva koodi, nii et `journalctl | grep -q` võib anda 141 (SIGPIPE), kui `grep` lõpetab varem. `-E` annab ERR-trap'i edasi funktsioonidesse, käsuasendustesse ja alamshellidesse. `errexit` ei kehti tingimuste sees ega vaikimisi käsuasenduses (`shopt -s inherit_errexit`, Bash 4.4+). Ükski neist ei kaitse kõigi vigade eest (vt lisaülesannet [7. `set -e` lõksud](lisa.md#7-set-e-loksud)).

**ERR-trap ja `-E`.** `-E` puudumist on raske märgata. Skript lõpetab vea korral ikka töö, aga kui viga tekib funktsiooni sees, ERR-trap ei käivitu. Siis pole stderr-is ega journal'is rea numbrit ega käsku. Öösel ebaõnnestunud deploy'st jääb alles ainult väljumiskood.

**Dry-run.** Dry-run on usaldusväärne ainult siis, kui iga muutev käsk läheb läbi ühe funktsiooni, laboris `change`. Kui kirjutad kuskile otse `cp`, ilma `change`-ita, näitab dry-run vähem muudatusi, kui käivitus ilma `-n`-ita teeks. Sama põhimõte on Ansible'i `--check`-režiimis: seal arvutab iga moodul ise, mida see muudaks.

**Distributsiooni tuvastamine.** `ID` on faili `/etc/os-release` standardväli ja see on olemas kõigil kursusel kasutatavatel distributsioonidel. Kontroll `yum --help` vastab ainult küsimusele, kas käsk `yum` on olemas. Rocky 9-l on `yum` viide `dnf`-ile, CentOS 7-l oli see veel eraldi programm. Seepärast tuvastatakse distributsioon OS-i enda andmete, mitte mõne käsu olemasolu järgi: sama käsunimi võib eri versioonides tähendada eri tööriista.

**Idempotentsus.** Laboris kontrollid seda skripti lõpurea ja Apache'i `ActiveEnterTimestamp`-i järgi. `install` ja `cp` ilma `-p`-ta muudavad faili `mtime`'i ka siis, kui sisu on sama; see tühjendab HTTP vahemälud (`Last-Modified`, ETag) ja paneb rsync'i ning varunduse faili uuesti kopeerima. Seepärast `cmp -s` enne kopeerimist.

Kui jõudsid kiiremini: [Lisaülesanded → 7. set -e lõksud](lisa.md#7-set-e-loksud), proovid läbi kohad, kus `set -e` viga ei peata, ja otsustad, kus vajab sinu skript selget kontrolli.
