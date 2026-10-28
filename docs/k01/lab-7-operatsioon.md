---
tags:
  - Bash
  - systemd
  - Proxmox
---

# 7. Operatsioon

Paljud intsidendid tekivad pärast paigaldust: teenus seiskub öösel ja keegi ei märka, uus release ei tööta, logid täidavad ketta või host ei tule pärast reboot'i üles. Lõpuks käivitub kontroll ise, rike tuleb välja ilma sinuta, rakendus saab uue versiooni, katki host taastub skriptiga ja logid püsivad mahu piires. Timer leiab rikke, aga ei teavita kedagi: tulemus jääb journal'isse ja Labori seisu, teavituseks (e-kiri, chat, valvetelefon) on vaja eraldi kanalit.

**Kui teed seda tööl iga päev:** `systemctl --user list-timers labseis-check.timer` näitab järgmist käivitust, journal'is on `OK: kõik kihid töötavad` ja `WAR_URL=<uus WAR-i URL> ./deploy-all.sh app01` muudab `/version`-it (selles skriptis on käsurida tugevam kui `secrets.env`). Kui see on sul juba korras, mine otse etappi [„Vigane release ja rollback ilma snapshot'ita“](#vigane-release-ja-rollback-ilma-snapshotita).

## check.sh systemd timeriga

Cron'i asemel systemd timer: väljund läheb journal'isse, viimane tulemus on `systemctl status`-es ja järgmine käivitus `list-timers`-is. Kirjuta kaks unit-faili kausta `k01-bash/systemd/` ja paigalda koopiad `~/.config/systemd/user/` alla:

- `labseis-check.service`: `Type=oneshot`, `WorkingDirectory` ja `ExecStart` on sinu `k01-bash` ja `check.sh` (`%h` = kodukaust)
- `labseis-check.timer`: `OnCalendar=*:0/5`, `[Install]` all `WantedBy=timers.target`
- `sudo loginctl enable-linger "$USER"`: timer käivitub ka siis, kui sa pole sisse logitud
- iga nullist erinev `check.sh` kood (1, 2 ja ka 3) jätab oneshot-teenuse olekusse `failed`, nii näeb riket ka `systemctl --user --failed`

```bash
systemd-analyze calendar '*:0/5'
systemctl --user daemon-reload
systemctl --user enable --now labseis-check.timer
systemctl --user list-timers labseis-check.timer
systemctl --user start labseis-check.service
journalctl --user -u labseis-check -n 20 --no-pager
```

> `Failed to connect to bus` tähendab, et oled `sudo -i` või `su` all: `systemctl --user` vajab sisselogimisseanssi (ssh).

`systemd-analyze calendar` näitab, millal avaldis järgmisel korral käivitub, enne kui selle kuskile paned. See hoiab ära klassikalise vea, kus kontroll käivitub kord tunnis, mitte iga viie minuti järel. Journal'i `OK`-rida tõestab, et teenus leidis õige kausta ja `secrets.env`-i.

✅ **Edasi saad minna, kui** `list-timers` näitab järgmist käivitust ja journal'is on `OK: kõik kihid töötavad`.

## Tekita rike ja vaata, kes märkab

Kontroll, mida pole kunagi punaseks nähtud, võib olla katki ja öelda alati `OK`.

1. Peata memcached: `ssh mc01 sudo systemctl stop memcached`
2. Oota järgmist timeri käivitust (kuni 5 min) või käivita teenus kohe.

    ```bash
    systemctl --user start labseis-check.service
    journalctl --user -u labseis-check -n 15 --no-pager
    systemctl --user status labseis-check.service --no-pager | head -5
    ```

3. Vaata Labori seisu koondtabelit: mis on punane, mis roheline.
4. Kirjuta `NOTES.md`-sse, miks on kood 1, mitte 2, ja mida kasutaja sel ajal märkab.
5. Taasta skriptiga, mitte `systemctl start`-iga: `./deploy-all.sh mc01`

Taastad skriptiga, sest `systemctl start` parandaks sümptomi, aga ei kontrolliks, et kõik muu mc01-s on soovitud seisus. `deploy-all.sh mc01` teeb mõlemat ja health check ütleb, millal see on valmis. Järgmise jooksu `OK` on tõend, et kontroll näeb ka taastumist, mitte ainult riket.

✅ **Edasi saad minna, kui** journal'is on `WARNING` ja kood 1, Labori seisus on vahemälu punane ja pärast `deploy-all.sh mc01` tuleb järgmisel käivitusel `OK`.

## Kui kontroll ise ei saa töötada

Kood 3 tähendab "ma ei tea": stack võib olla korras, aga kontroll ei saa seda öelda. Icinga ja Nagios näitavad UNKNOWN-i eraldi olekuna ja teavitusreeglid käsitlevad seda eraldi.

1. Nimeta hostifail ajutiselt ümber ja käivita kontroll.

    ```bash
    mv hosts hosts.bak
    systemctl --user start labseis-check.service
    journalctl --user -u labseis-check -n 3 --no-pager
    ```

2. Vaata teenuse olekut ja pane fail tagasi.

    ```bash
    systemctl --user status labseis-check.service --no-pager | grep -E 'Active|status='
    mv hosts.bak hosts
    systemctl --user start labseis-check.service
    ```

Journal'is on `UNKNOWN: fail 'hosts' puudub` ja olekus `status=3`. Teenus on `failed` nagu rikke ajal, aga kood ütleb põhjuse. Kui sinu `check.sh` oleks andnud koodi 2, oleks monitooring näidanud "stack on maas", kuigi ükski teenus polnud seiskunud. Viimane käivitus tõestab, et pärast faili tagasipanekut on kõik jälle `OK`.

✅ **Edasi saad minna, kui** journal'is on `UNKNOWN` ja `status=3`, pärast faili tagasipanekut `OK` ning `NOTES.md`-s on üks lause, miks UNKNOWN ei ole CRITICAL.

## Uuenda app01 ja mõõda katkestust

Rakenduse uus versioon on uus WAR. Uuendad ainult app01 ja health check ütleb, millal see on valmis. Ühe app-hostiga on see uuendus, mille ajal võib olla lühike katkestus, mitte rolling deploy.

Mõõdad kahte asja: kas uus versioon jõudis kohale ja kui kaua kasutaja vigu nägi.

1. Vaata praegust versiooni ja proovi käsurea `WAR_URL`-i (uue WAR-i URL on tahvlil).

    ```bash
    curl -s http://web01/version; echo
    WAR_URL=<uus WAR-i URL> ./deploy-all.sh app01
    curl -s http://web01/version; echo
    ```

2. Kui versioon ei muutunud, kirjutas `secrets.env` sinu `WAR_URL`-i üle. Paranda `deploy-all.sh`: käsurea väärtus peab olema tugevam kui fail.
3. Käivita teises terminalis katkestuse mõõtja ja tee redeploy uuesti.

    ```bash
    while sleep 1; do echo "$(date +%T) $(curl -s -o /dev/null -w '%{http_code}' http://web01/health)"; done
    ```

4. Kirjuta `NOTES.md`-sse, mitu sekundit web01 vastas 502-ga ja mida oleks vaja, et kasutaja katkestust ei näeks.

Skript laeb `secrets.env`-i alles siis, kui käsurea `WAR_URL` on juba keskkonnas, nii et fail kirjutab selle üle. Paranduse järel kehtib selles skriptis reegel: käsurida on tugevam kui fail ja fail on tugevam kui vaikeväärtus. Kui see on vastupidi, ei saa sa kunagi ühekordselt midagi üle kirjutada ilma faili muutmata. 502-de arv mõõtjas on sinu katkestuse aeg. Ühe app-hostiga ei saa see olla null, ja just seda numbrit vajad, kui kirjutad hooldusakna teadet.

✅ **Edasi saad minna, kui** `/version` näitab uut versiooni, väljundis on "app01 terve" ja katkestuse pikkus on `NOTES.md`-s.

## Vigane release ja rollback ilma snapshot'ita

Tootmises ei tehta igast release'ist VM-i snapshot'it: rollback käib sama teed kui deploy, eelmise artefaktiga. Proovid kahte vigast release'i. Mõlemal korral ebaõnnestub `deploy-all.sh app01`, aga ainult ühel korral jääb kasutaja teenuseta. Kumb ja miks, selgub `tomcat.sh`-i sammude järjekorrast.

Nõuded:

- enne alustamist on `NOTES.md`-s praegune `/version` ja URL, millega see paigaldati: see on sinu rollback'i siht
- eelmise etapi katkestuse mõõtja töötab teises terminalis kogu etapi vältel
- vigane release 1 on URL, mida pole; vigane release 2 on URL, mis vastab 200-ga, aga ei ole WAR
- iga katse järel on kirjas `deploy-all.sh`-i kood, `/version`, `check.sh`-i kood ja mõõtja vigaste vastuste arv
- taastad ainult `deploy-all.sh`-iga ja eelmise versiooni URL-iga, mitte Proxmoxist

```bash
WAR_URL=http://web01/puudub.war ./deploy-all.sh app01; echo "kood $?"
curl -s http://web01/version; echo; ./check.sh > /dev/null; echo "check $?"
WAR_URL=http://web01/health ./deploy-all.sh app01; echo "kood $?"
curl -s http://web01/version; echo; ./check.sh > /dev/null; echo "check $?"
```

> Kui `target/labori-seis.war` on repos või `/tmp/labori-seis.war` app01-s, kasutab `tomcat.sh` seda ja `WAR_URL` ei mõju.

Rollback'i URL valid enne riket, mitte selle ajal: kui seda pole kirjas, ei tea keegi kell kolm öösel, milline WAR oli viimane töötav. `NOTES.md`-sse kirjuta ka, milline kontroll `tomcat.sh`-is enne `install`-i oleks teise vigase release'i peatanud ja miks see ei asenda health check'i.

✅ **Edasi saad minna, kui** esimese katse järel on `/version` muutumata ja mõõtjas pole ühtki vigast vastust, teise järel annab `check.sh` koodi 2, pärast rollback'i näitab `/version` sama versiooni, mille enne kirja panid, `check.sh` annab koodi 0 ja `NOTES.md`-s on mõlema katse katkestuse pikkus ning WAR-i kontroll.

## Taasta host snapshot'ist

Test skriptidele: host läheb tagasi tühjaks ja üks käsk toob selle samasse seisu. Timer salvestab rikke ja taastumise aja.

> ⚠️ Rollback kustutab app01-st kõik, mis tehti pärast snapshot'i `enne-stack`.

1. Proxmoxis **app01 → Snapshots → `enne-stack` → Rollback**, siis **Start**.
2. Oota, kuni host vastab, ja vaata stacki seisu.

    ```bash
    until ssh app01 true; do sleep 3; done
    ./check.sh; echo "kood $?"
    ```

3. Taasta app01 skriptiga: `./deploy-all.sh app01`
4. Vaata journal'ist, millal timer rikke ja taastumise nägi: `journalctl --user -u labseis-check --since -30min --no-pager | grep -E 'OK:|WARNING:|CRITICAL:'`

Journal'is on nüüd rikke ja taastumise ajajoon ilma, et oleksid ise midagi üles kirjutanud. Aeg esimese `CRITICAL`-i ja esimese `OK` vahel on selles mõõtmises tuvastamisest taastumiseni kulunud aeg. Sinna sisaldub `deploy-all.sh app01` kestus ja timer'i intervall, sest taastumist näeb alles järgmine käivitus kuni viis minutit hiljem. Kui `deploy-all.sh` oleks ebaõnnestunud, oleks see tähendanud, et skript eeldab midagi, mis oli app01-s ainult varasemast käsitsi tööst.

✅ **Edasi saad minna, kui** `check.sh` andis pärast rollback'i koodi 2, pärast `deploy-all.sh app01` koodi 0 ja journal'is on `CRITICAL` → `OK` üleminek.

## Logid ei täida ketast

Täis `/var` on tüüpiline öine intsident: journal ja rakenduse logid kasvavad kuude kaupa, kuni MariaDB ei saa kirjutada või Tomcat ei paki WAR-i lahti. Vaikeseaded erinevad distroti ja Tomcat kirjutab iga päeva kohta uue logifaili (`catalina.<kuupäev>.log`, `localhost_access_log.<kuupäev>.txt`), aga vanu ei kustuta. Tootmispiirang: muudatus läheb kõigisse viide hosti ja Tomcatit ei taaskäivitata, sest iga restart on sinu mõõdetud katkestus.

1. Vaata praegust seisu. Kirjuta `NOTES.md`-sse, millises hostis on journal püsiv ja millises ainult `/run`-is.

    ```bash
    for h in web01 app01 rmq01 mc01 db01; do
        ssh -n "$h" 'echo "== $(hostname)"; ls -d /var/log/journal 2> /dev/null || echo "püsiv kaust puudub"; sudo journalctl --disk-usage; sudo journalctl --list-boots --no-pager | wc -l'
    done
    ssh app01 'sudo ls -l /opt/tomcat/logs/ | tail -5'
    ```

2. Kirjuta `k01-bash/hostlogs.sh <host>…` ja selle failid kausta `k01-bash/hostlogs/`. Nõuded:
    - kõigis hostides journald drop-in `/etc/systemd/journald.conf.d/50-labseis.conf`: püsiv salvestus, journal'i kogumaht kuni 200 MB, vähemalt 500 MB vaba ruumi failisüsteemis
    - `systemd-journald` taaskäivitub ainult siis, kui drop-in muutus
    - app01-s kustuvad `/opt/tomcat/logs/` failid, mis on vanemad kui 14 päeva, kord päevas, ilma Tomcati taaskäivituseta; mehhanismi valid ise (logrotate, `systemd-tmpfiles`, Tomcati `logging.properties`) ja põhjendad valikut `NOTES.md`-s kahe lausega
    - teine käivitus ütleb igas hostis "muudatusi pole"; ShellCheck vaikib

3. Käivita ja tõesta. Vana logifail on võltsitud: `touch -d` paneb faili ajaks 20 päeva tagasi.

    ```bash
    pid=$(ssh app01 systemctl show -p MainPID --value tomcat)
    ./hostlogs.sh web01 app01 rmq01 mc01 db01 && ./hostlogs.sh web01 app01 rmq01 mc01 db01 | tail -2
    ssh app01 'sudo -u tomcat touch -d "20 days ago" /opt/tomcat/logs/catalina.2000-01-01.log'
    ssh app01 '<sinu puhastuse käsk käsitsi, nt sudo systemd-tmpfiles --clean või sudo logrotate -f /etc/logrotate.d/<fail>>'
    ssh app01 'ls /opt/tomcat/logs/ | grep -c 2000-01-01; systemctl show -p MainPID --value tomcat'; echo "enne: $pid"
    ssh mc01 sudo systemctl reboot; sleep 30; until ssh mc01 true; do sleep 3; done
    ssh mc01 'sudo journalctl --list-boots --no-pager | wc -l; sudo journalctl -b -1 -n 1 --no-pager'
    ```

> Kui võltsitud fail jääb alles, kuigi reegel ütleb 14 päeva: `touch -d` muudab mtime'i ja atime'i, aga ctime on praegune. Vaata oma tööriista manuaalist, millist aega see vanuse arvutamisel kasutab (`man tmpfiles.d`, väli *Age*).

`systemd-journald` taaskäivitus ei katkesta teenuseid: unit'ide stdout'i ühendused hoiab systemd alles ja journald võtab need tagasi. Tomcati `logging.properties`-i `maxDays` oleks kõige otsesem lahendus, aga see rakendub alles Tomcati restardil. mc01 reboot tõestab, et journal elab boot'ide üle; selle ajal annab timer vahemälu kohta `WARNING`-u, mis on oodatud.

✅ **Edasi saad minna, kui** teine `hostlogs.sh` ütleb igas hostis "muudatusi pole", võltsitud `2000-01-01` fail on kadunud (`grep -c` annab `0`), Tomcati `MainPID` on sama mis enne, mc01 `--list-boots` annab vähemalt 2 ja `journalctl -b -1` näitab eelmise boot'i rida.

## Commit

Unit-failid lähevad repo kausta `systemd/`, mitte ainult `~/.config/systemd/user/` alla. Repos on need versioonitud ja järgmisel control node'il paigaldad need ühe `cp`-ga.

```bash
shellcheck -S warning ./*.sh
git add systemd/ deploy-all.sh hostlogs.sh hostlogs/ NOTES.md
git commit -m "systemd: check.sh timer; deploy-all.sh: käsurea WAR_URL; hostlogs.sh" && git push
```

✅ **Edasi saad minna, kui** `git ls-files systemd/` näitab mõlemat unit-faili.

📎 **Selle mooduli tõend:** commit `systemd: check.sh timer …`; `NOTES.md`-s journal'i read rikke ja taastumisega, UNKNOWN-test, redeploy katkestuse pikkus, kahe vigase release'i tulemus koos rollback'iga, vastus koodi 1 küsimusele, journal'i seis enne ja pärast `hostlogs.sh`-i ning logide puhastuse valiku põhjendus.

## Miks see nii töötab

**systemd timer ja cron.** Timer'i `AccuracySec` on vaikimisi 1 min: systemd koondab äratusi ja `*:0/5` võib käivituda kuni minut hiljem. Kui sada hosti käivitavad sama kontrolli samal sekundil, hajutab koormust `RandomizedDelaySec`. `Persistent=true` käivitab vahele jäänud käivituse pärast boot'i, cron'il selleks eraldi anacron. Oneshot-teenust ei käivitata uuesti, kui eelmine käivitus alles töötab, cron'i töö aga käivitub paralleelselt teisega. Cron'i väljund läheb `MAILTO`-sse ja pilvemallides, kus MTA-d pole, kaotsi.

**Kasutaja timer ja linger.** Kasutaja timer (`systemctl --user`) töötab sinu kasutaja systemd-eksemplaris. Ilma `loginctl enable-linger`-ita peatab systemd selle eksemplari, kui sinu viimane seanss lõpeb, ja timer ei käivitu enam.

**Rolling deploy.** Rolling deploy vajab vähemalt kahte rakendushosti, Nginxi `upstream`-plokki mõlemaga ja sammu, mis eemaldab hosti enne uuendust liiklusest. Ühe rakendushostiga ei ole uuesti paigaldamine järkjärguline ja kasutaja näeb katkestust.

**journald maht.** Ilma seadeta kasutab journald kuni 10% failisüsteemist (ülempiir 4 GB) ja jätab vabaks 15%. `Storage=auto` kirjutab kettale ainult siis, kui `/var/log/journal` on olemas, muidu `/run/log/journal`-isse, mis kaob reboot'il. `SystemMaxUse` ja `SystemKeepFree` kehtivad koos ja rangem võidab: täis ketta korral kustutab journald vanimad arhiivifailid, aktiivset faili mitte. Rakenduse logid on eraldi küsimus, sest journald neid ei näe.

Kui jõudsid kiiremini: [Lisaülesanded → 14. Teata ainult oleku muutusest](lisa.md#14-teata-ainult-oleku-muutusest), kirjutad timerile wrapper-skripti, mis teatab ainult siis, kui stacki olek muutub.
