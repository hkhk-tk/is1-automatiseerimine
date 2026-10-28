---
tags:
  - Bash
  - Ansible
  - Git
  - Proxmox
---

# 1. kohtumine, lisaülesanded

| Ülesanne | Tase | Tulemus |
|---|---|---|
| [1. Giti tagasivõtmine](#1-giti-tagasivotmine) | lihtne | iga tagasivõtmise tase proovitud |
| [2. RabbitMQ käsitsi ja sudo logi](#2-rabbitmq-kasitsi-ja-sudo-logi) | lihtne | tead, kuhu käsureal antud parool jõuab |
| [3. X-Cache rikketest](#3-x-cache-rikketest) | lihtne | tead, mida `/health` ja `X-Cache` näevad |
| [4. Taaskäivituse test](#4-taaskaivituse-test) | lihtne | `/etc/hosts` plokk elab reboot'i üle |
| [5. Hostifaili valideerimine](#5-hostifaili-valideerimine) | lihtne | `webdeploy.sh` keeldub vigasest hostifailist |
| [6. AI ülevaatus](#6-ai-ulevaatus) | lihtne | üks AI soovitus võetud, üks põhjendatult jäetud |
| [7. set -e lõksud](#7-set-e-loksud) | keskmine | tead, kus `set -e` viga ei peata |
| [8. Ansible sihtmasina poolelt](#8-ansible-sihtmasina-poolelt) | keskmine | tead, mida Ansible sihtmasinas teeb |
| [9. Üks host korraga ja vigade piir](#9-uks-host-korraga-ja-vigade-piir) | keskmine | esimene vigane host peatab play |
| [10. `dismantle.sh <teenus>`](#10-dismantlesh-teenus) | keskmine | teenus eemaldatud, andmed alles |
| [12. Health check app01-st](#12-health-check-app01-st) | keskmine | taustateenuseid kontrollitakse app01-st |
| [13. Teine mall ja vanad failid](#13-teine-mall-ja-vanad-failid) | keskmine | malli vahetus ja rollback sümlingiga |
| [14. Teata ainult oleku muutusest](#14-teata-ainult-oleku-muutusest) | keskmine | journal'is ainult oleku muutused |
| [15. Saladuste kontroll pre-commit hook'iga](#15-saladuste-kontroll-pre-commit-hookiga) | keskmine | saladusega commit katkestatakse |
| [16. Tarnija repo: fork ja upstream](#16-tarnija-repo-fork-ja-upstream) | keskmine | fork sünkroonis, parandus tagasi pakutud |
| [17. deploy-all.sh lainetena](#17-deploy-allsh-lainetena) | raske | paralleelne deploy, osalise rikke kokkuvõte |
| [18. Parooli vahetus skriptiga](#18-parooli-vahetus-skriptiga) | raske | parool vahetatud, rikke korral taastatud |
| [19. WordPress automaatselt](#19-wordpress-automaatselt) | raske | idempotentne WordPress, parool logidest väljas |
| [20. Heakskiidetud tegevuste kataloog](#20-heakskiidetud-tegevuste-kataloog) | raske | käivitub ainult commit'itud tegevus, audit journal'is |
| [21. vorgukogu.py](#21-vorgukogupy-show-kaskude-valjund-kahelt-ruuterilt) | keskmine | kahe ruuteri show-väljund failides, saladused maskitud |

Iga ülesanne on eraldi issue (label `edasijõudnu`), failid lähevad kausta `k01-bash/`, otsuste põhjendused ja teadlikult tegemata jäetud asjad `k01-bash/NOTES.md`-sse ning iga uus `k01-bash/*.sh` läbib automaatse hindaja ShellChecki, `set -e` ja käivitusõiguse kontrolli.

## Lihtsad ülesanded

### 1. Giti tagasivõtmine

**Tase:** lihtne · **Eeldus:** [websetup.sh nagu tootmises](lab-2-websetup.md)

Git ei paku üht universaalset "undo" nuppu, sest viga võib olla eri kohas. Muutus võib olla ainult töökaustas, staging'is, sinu kohalikus commit'is või juba GitHubi push'itud ajaloos. Mida kaugemale muudatus on jõudnud, seda ettevaatlikum peab tagasivõtmine olema: jagatud ajalugu ei tohi lihtsalt ümber kirjutada.

1. Algseis: `git status` on puhas ja kõik on push'itud.
2. Töökaust: lisa `websetup.sh`-i lõppu `echo proov`, vaata `git diff` ja võta muudatus tagasi.
3. Staging: lisa sama rida ja `git add`, võrdle `git diff` ja `git diff --cached`, võta muudatus tagasi nii staging'ust kui töökaustast.
4. Push'itud commit: eemalda `unzip`-ilt `-o`, commit'i ja push'i. Võta tagasi nii, et teiste kloonid ja tag'id jäävad kehtima.
5. Kohalik commit: `echo "# proov" >> k01-bash/NOTES.md && git commit -am "kohalik proov"`, siis eemalda see commit ajaloost.

**Kontroll:**

```bash
git status --short
git log --oneline -4
git diff origin/k01-bash
```

**Valmis, kui:**

- `git status --short` on tühi
- `git log --oneline -4` näitab vigast commit'i ja selle `Revert "…"` commit'i
- commit'i `kohalik proov` ajaloos pole
- `git diff origin/k01-bash` on tühi

Vihje: kui `reset --hard` viis liiga palju, näitab `git reflog` hash'i ja `git reset --hard <hash>` toob selle tagasi.

??? success "Lahendus"
    Käsu valib see, kui kaugele muudatus jõudis. Kuni see on ainult sinu masinas, võid ajalugu ümber kirjutada; pärast push'i parandab ainult uus commit, sest teiste kloonid ja tag'id osutavad vanale hash'ile.

    ```bash
    git restore k01-bash/websetup.sh                       # 1: töökaust
    git restore --staged k01-bash/websetup.sh              # 2: staging → töökaust
    git restore k01-bash/websetup.sh                       #    töökaust → HEAD
    git revert HEAD --no-edit && git push                  # 3: push'itud
    git reset --hard HEAD~1                                # 4: ainult kohalik
    git reflog -5                                          # kui reset viis liiga palju,
    git reset --hard <hash>                                # hash reflog'i väljundist
    ```

    Kontroll: `git status --short` on tühi, `git log --oneline -3` näitab `Revert "…"` commit'i ja `git diff origin/k01-bash` on tühi.

    **Miks nii.** Push'itud ajalugu on ka teiste oma, seepärast `revert`. `reset --hard` kustutab commit'id ja salvestamata muudatused, seega kasuta seda ainult push'imata töö peal. Kolmanda taseme `git log` näitab nüüd kahte commit'i: viga ja selle tagasivõtmist. Kui `git reset --hard` kustutas kogemata midagi vajalikku, näitab `git reflog` viimaseid HEAD-i asukohti ja commit'i saab sealt tagasi tuua. Neli taset on samad, mis loengu joonisel 1.5.

### 2. RabbitMQ käsitsi ja sudo logi

**Tase:** lihtne · **Eeldus:** [Üks käsk, mitu hosti](lab-3-mitu-hosti.md) · **Esita:** `k01-bash/NOTES.md`

`deploy-all.sh` saadab paroolid hosti standardsisendi kaudu. Käsitsi sisestad parooli `rabbitmqctl add_user` käsureale. See on tahtlikult halb näide: `sudo` logi näitab kogu käsku koos parooliga.

1. Algseis: rmq01-l on snapshot `enne-stack` ja `deploy-all.sh` pole seal veel käinud. Kõik rmq01 muudatused pärast snapshot'i kaovad.
2. Paigalda RabbitMQ käsitsi ja loo kasutaja parooliga käsureal ([`rabbitmqctl`](https://www.rabbitmq.com/docs/man/rabbitmqctl.8)):

    ```bash
    ssh rmq01
    sudo apt-get update -qq && sudo apt-get install -y -qq rabbitmq-server
    sudo rabbitmqctl add_user labseis proov123
    sudo rabbitmqctl set_permissions -p / labseis ".*" ".*" ".*"
    ```

3. Leia sudo logist rida, kus parool on näha, ja kontrolli, et port 5672 kuulab.
4. Kirjuta `NOTES.md`-sse kolm asja, mida `services/rabbitmq.sh` teeb teisiti kui sina.
5. Proxmoxis **rmq01 → Snapshots → `enne-stack` → Rollback**, siis Start.

**Kontroll:**

```bash
ssh rmq01 'sudo journalctl -t sudo -n 5 --no-pager; sudo ss -tlnp | grep 5672'
# pärast rollback'i:
ssh rmq01 'systemctl is-active rabbitmq-server; sudo journalctl -t sudo --no-pager | grep -c proov123'
```

**Valmis, kui:**

- enne rollback'i on sudo logis rida `COMMAND=…rabbitmqctl add_user labseis proov123` ja port 5672 kuulab
- pärast rollback'i on teenus `inactive` ja `grep -c` annab `0`
- `NOTES.md`-s on kolm erinevust `services/rabbitmq.sh`-iga

??? success "Lahendus"
    Erinevused on kolmes kohas: kuidas parool hostini jõuab, kas teine käivitus töötab ja kas `rabbitmqctl` ootab Erlangi node'i. Parool läheb `deploy-all.sh`-is `ssh … "sudo bash -s"` standardsisendisse, nii et sudo logib ainult `bash -s`.

    ```bash
    grep -nE 'await_startup|list_users|change_password|add_user|delete_user' k01-bash/services/rabbitmq.sh
    grep -n 'bash -s' k01-bash/deploy-all.sh
    ```

    `NOTES.md`-sse: (1) parool tuleb keskkonnamuutujast, mille `remote_run` saadab stdin-i kaudu, mitte sudo käsureale; (2) `add_user` ainult siis, kui kasutajat pole, muidu `change_password`, nii et teine käivitus ei ebaõnnestu ja uus parool jõuab RabbitMQ-sse; (3) `rabbitmqctl await_startup` enne kasutajahaldust ja `guest` kustutatakse. `rabbitmqctl` saab parooli siiski argumendina, seega on see rmq01-s käsu kestuse ajal `ps`-is näha.

    Kontroll: samm 4 annab `inactive` ja `0`. Kontrollimata: labori VM-ides.

    **Miks nii.** Ubuntu 24.04 vaikeseadistuses logib sudo kogu käsurea, seega on parool logis. Pärast rollback'i kaob laborimasinast nii kasutaja kui ka logikirje, kuid tootmises ei kao lekkinud parool kuskile: see tuleb välja vahetada. Tulemusest järeldad kaks asja. Esiteks ei piisa sellest, et parool on failis `chmod 600`: oluline on ka tee, mida mööda see protsessini jõuab. Teiseks saadetakse sudo logi tootmises sageli ka keskse logiserverisse, nii et parool jääks alles ka siis, kui puhastaksid kohaliku journal'i.

### 3. X-Cache rikketest

**Tase:** lihtne · **Eeldus:** [Kolm viga](lab-5-kolm-viga.md)

Memcached mc01-s seiskub, web01 vastab edasi. Monitooring näeb ainult seda, mida tema kontroll küsib, ja `/health` ning `X-Cache` päis küsivad eri asju.

1. Algseis: stack töötab, `check.sh` annab koodi 0. Kaob ainult vahemälu sisu.
2. Peata mc01-s memcached.
3. Tee web01-le kaks järjestikust päringut ja vaata `X-Cache` päist, siis küsi `/health` HTTP koodi.
4. Ennusta, mida `check.sh` ütleb, ja käivita see.
5. Taasta `./deploy-all.sh mc01`-ga.

**Kontroll:**

```bash
. ./secrets.env
ssh mc01 sudo systemctl stop memcached
for i in 1 2; do curl -s -o /dev/null -D - "http://web01/?token=$TEACHER_TOKEN" | grep -i x-cache; done
curl -s -o /dev/null -w '%{http_code}\n' http://web01/health
./check.sh; echo "kood $?"
./deploy-all.sh mc01 && ./check.sh > /dev/null; echo "kood $?"
```

**Valmis, kui:**

- mõlema päringu `X-Cache` väärtus ja `/health` HTTP kood on teada ning oskad öelda, miks need erinevad
- rikke ajal on teada `check.sh` kood ja read, mis rikke näitasid
- pärast `./deploy-all.sh mc01` annab `check.sh` koodi 0

??? success "Lahendus"
    Mõlemal korral tuleb `MISS`, aga `/health` annab ikka 200: selles laborirakenduses pole vahemälu kohustuslik sõltuvus.

    `check.sh` näeb sama riket kolmest kohast: port, `/health` väli `cache` ja `X-Cache`. Kõik kolm on tasemel WARN, sest kasutaja saab teenust edasi, seega on kood 1, mitte 2.

    ```bash
    ssh mc01 sudo systemctl stop memcached
    ./check.sh | grep -E '^(memcached|health-cache|cache) '; echo "kood ${PIPESTATUS[0]}"
    ./deploy-all.sh mc01 > /dev/null && ./check.sh > /dev/null; echo "kood $?"
    ```

    Kontroll: kolm rida tasemega `WARN` (`mc01:11211 ei vasta`, `cache DOWN`, `X-Cache: MISS`) ja `kood 1`; pärast `deploy-all.sh mc01`-i `kood 0`. Kontrollimata: labori VM-ides.

    **Miks nii.** `/health` vastab küsimusele, kas rakendus suudab Memcachediga ühenduda. `X-Cache` vastab teisele küsimusele: kas kasutajapäring kasutas vahemälu. Teenus võib olla võrgus kättesaadav, kuid rakendus võib cache'ist mööda minna või seda üldse mitte kasutada. Seepärast ei piisa ainult pordi või `/health` kontrollist. Tulemus ütleb, et rakendus on ehitatud vahemälu kaotust taluma: leht töötab, ainult aeglasemalt, ja iga päring läheb andmebaasi. Väikese koormusega laboris ei märka seda keegi. Suure koormusega süsteemis võib sama olukord andmebaasi üle koormata ja siis lakkab kogu teenus töötamast, kuigi `/health` näitas alguses, et kõik on korras. Kas see on õige, arutad Arutelu 3. küsimuses.

### 4. Taaskäivituse test

**Tase:** lihtne · **Eeldus:** [Keskkond](lab-1-keskkond.md) · **Esita:** `k01-bash/NOTES.md`

Laboris VM-e tavaliselt ei taaskäivitata, nii et `/etc/hosts` plokk on seni üle elanud ainult deploy'sid. Esimene plaaniline reboot pärast kerneli uuendust näitab, kas seadistus jääb alles.

1. Algseis: stack töötab ja kõik parandused on skriptis. Käsitsi tehtud muudatus, mida skript ei korda, võib kaduda.
2. Taaskäivita app01 ja web01.
3. Kontrolli, kas app01 leiab nime db01 ja web01 `/health` vastab.
4. Leia, kumb mehhanism plokki hoiab: drop-in `/etc/cloud/cloud.cfg.d/99-labori-seis.cfg` või mall `/etc/cloud/templates/hosts.debian.tmpl`, ja mida ütleb user-data.
5. Kirjuta tulemus `NOTES.md`-sse.

**Kontroll:**

```bash
ssh app01 sudo reboot; ssh web01 sudo reboot
sleep 60; ssh app01 getent hosts db01; curl -s http://web01/health
ssh app01 'sudo cloud-init query userdata | grep etc_hosts'
```

**Valmis, kui:**

- `getent hosts db01` annab pärast reboot'i db01 IP
- `/health` vastab
- `NOTES.md`-s on kirjas, kas plokk jäi alles ja kumb mehhanism sinu VM-is töötas

Vihje: kui midagi kadus, taastab `./deploy-all.sh app01 web01` seisu.

??? success "Lahendus"
    Kumb mehhanism töötab, otsustab user-data. Proxmoxi genereeritud user-data's on `manage_etc_hosts: true` ja user-data on tugevam kui `cloud.cfg.d` drop-in: cloud-init renderdab `/etc/hosts`-i igal boodil mallist ja plokk tuleb `hosts.debian.tmpl`-ist. Kui user-data's seda võtit pole, kehtib drop-in `manage_etc_hosts: false` ja cloud-init ei puutu faili.

    ```bash
    ssh app01 'sudo cloud-init query userdata | grep manage_etc_hosts'
    ssh app01 'grep -c "labori-seis BEGIN" /etc/hosts /etc/cloud/templates/hosts.debian.tmpl'
    ssh app01 'sudo grep -i "etc/hosts" /var/log/cloud-init.log | tail -3'
    ```

    Kontroll: `getent hosts db01` annab pärast reboot'i db01 IP, `grep -c` annab mõlemas failis `1` ja `/health` vastab. Kui user-data's on `true`, on mehhanism mall, muidu drop-in. Kontrollimata: labori VM-ides.

    **Miks nii.** Kui plokk oleks ainult `/etc/hosts`-is ja user-data's on `manage_etc_hosts: true`, töötaks kõik kuni esimese taaskäivituseni ja pärast seda ei leiaks app01 nime db01, kuigi repos pole midagi muutunud. Seepärast kirjutab `etc-hosts.sh` ploki ka malli.

### 5. Hostifaili valideerimine

**Tase:** lihtne · **Eeldus:** [Üks käsk, mitu hosti](lab-3-mitu-hosti.md) · **Esita:** `k01-bash/webdeploy.sh`

Vigase hostifaili tõttu võib deploy jõuda valesse masinasse. `deploy-all.sh` kontrollib faili funktsiooniga `validate_hosts`, `webdeploy.sh` ei kontrolli.

1. `webdeploy.sh` kontrollib hostifaili enne lukku ja enne esimest `scp`-d sama reegliga nagu `validate_hosts`.
2. Keeldub tühjast failist, reast, kus pole täpselt kaks välja, ning korduvast IP-st või nimest.
3. Teade nimetab faili ja põhjuse, kood on 1.

**Kontroll:**

```bash
: > /tmp/tyhi; ./webdeploy.sh -f /tmp/tyhi; echo $?
printf 'web01 10.10.1.11\nmc01 10.10.1.11\n' > /tmp/topelt; ./webdeploy.sh -f /tmp/topelt; echo $?
./webdeploy.sh; echo $?
```

**Valmis, kui:**

- tühja failiga ütleb teade põhjuse ja kood on 1
- topelt-IP-ga ütleb teade põhjuse, kood on 1 ja ühtki `→ host` rida pole
- korrektse `hosts` failiga töötab `webdeploy.sh` nagu enne

??? success "Lahendus"
    Kontroll käib enne lukku ja enne tsüklit. `|| true` on vajalik: tühja faili korral annab `grep` koodi 1 ja `pipefail` koos `set -e`-ga lõpetaks skripti ilma teateta.

    ```bash
    # webdeploy.sh, kohe pärast rida, mis kontrollib "$HOSTS_FILE" olemasolu
    validate_hosts() {
        local clean dup
        clean=$(tr -d '\r' < "$HOSTS_FILE" | grep -Ev '^[[:space:]]*(#|$)' || true)
        [[ -n "$clean" ]] || { echo "$HOSTS_FILE: ühtki hosti pole" >&2; exit 1; }
        awk 'NF != 2 { exit 1 }' <<< "$clean" || { echo "$HOSTS_FILE: iga rida peab olema 'nimi IP'" >&2; exit 1; }
        dup=$(awk '{print $2}' <<< "$clean" | sort | uniq -d)
        [[ -z "$dup" ]] || { echo "$HOSTS_FILE: sama IP mitmel real: $dup" >&2; exit 1; }
        dup=$(awk '{print $1}' <<< "$clean" | sort | uniq -d)
        [[ -z "$dup" ]] || { echo "$HOSTS_FILE: sama nimi mitmel real: $dup" >&2; exit 1; }
    }
    validate_hosts
    ```

    Kontroll: `: > /tmp/tyhi; ./webdeploy.sh -f /tmp/tyhi; echo $?` annab `ühtki hosti pole` ja `1`; `printf 'web01 10.10.1.11\nmc01 10.10.1.11\n' > /tmp/topelt; ./webdeploy.sh -f /tmp/topelt` annab `sama IP mitmel real` ja ühtki `→ host` rida pole. Kontrollitud kohalike hostifailidega.

    **Miks nii.** Kontroll peab olema enne esimest muudatust: kui see on tsükli sees, on osa hoste juba seadistatud, kui vigane rida ette tuleb.

### 6. AI ülevaatus

**Tase:** lihtne · **Eeldus:** [Üks käsk, mitu hosti](lab-3-mitu-hosti.md) · **Esita:** `k01-bash/NOTES.md`

AI võib märgata stiili- ja töökindlusprobleeme, kuid ta ei näe sinu VM-e, kursuse piiranguid ega automaatset hindajat. AI soovitus on mustand, mis läbib samad kontrollid nagu sinu enda kood.

1. Anna `websetup.sh` või `webdeploy.sh` AI-tööriistale palvega vaadata see üle Bashi heade tavade ja tootmiskindluse järgi. AI-le ei lähe `secrets.env` ega ükski parool.
2. Vali üks soovitus, mille võtad, ja üks, mille jätad. Kirjuta mõlema tehniline põhjus `NOTES.md`-sse.
3. Tee valitud muudatus ja käivita skript teist korda.

**Kontroll:**

```bash
shellcheck -S warning k01-bash/websetup.sh
scp k01-bash/websetup.sh web01:/tmp/ && ssh web01 sudo bash /tmp/websetup.sh
```

**Valmis, kui:**

- ShellCheck ei anna hoiatusi
- teine käivitus lõpeb `(muudatusi pole)`
- `NOTES.md`-s on kaks soovitust koos põhjusega

??? success "Lahendus"
    Näide: võta soovitus anda `wget`-ile ajapiir, sest hangunud allalaadimine hoiab `webdeploy.sh`-i lukku ja ühe paralleelse töö koha kinni. Jäta soovitus asendada `site_differs` + `cp` lihtsa `cp -r`-iga: iga käivitus muudaks siis faile ja "muudatusi pole" kaoks.

    ```bash
    sed -i 's/wget -q "\$URL"/wget -q --timeout=30 --tries=2 "$URL"/' k01-bash/websetup.sh
    shellcheck -S warning k01-bash/websetup.sh
    scp k01-bash/websetup.sh web01:/tmp/ && ssh web01 sudo bash /tmp/websetup.sh
    ```

    Kontroll: ShellCheck vaikib ja viimane rida lõpeb `(muudatusi pole)`. Kontrollimata: web01-s; `sed`-i asendus ja ShellCheck on kontrollitud.

    **Miks nii.** Hinda üht soovitust tehnilise põhjendusega: kas see teeb sinu skripti selles laboris paremaks või ainult teistsuguseks. Kui "muudatusi pole" kadus, tegi soovitus skripti halvemaks, isegi kui kood näeb puhtam välja. Teine tüüpiline näide on lõppu "igaks juhuks" lisatud `systemctl restart`, mis samuti rikub idempotentsuse.

## Keskmised ülesanded

### 7. set -e lõksud

**Tase:** keskmine · **Eeldus:** [websetup.sh nagu tootmises](lab-2-websetup.md) · **Esita:** `k01-bash/set-e-test.sh`, `k01-bash/NOTES.md`

Igas sinu skriptis on `set -euo pipefail`. Mõni ebaõnnestunud käsk ei peata ometi skripti ja deploy jätkab vigase seisuga.

1. Ennusta iga tabeli rea kohta enne käivitamist, kas skript peatub.
2. `set-e-test.sh` käivitab iga juhtumi eraldi, nii et üks peatus ei katkesta teisi, ja väljastab iga juhtumi kohta `PEATUS (kood N)` või `JÄTKAS`.
3. Viimase rea juhtum on deterministlik: see annab `pipefail`-iga sama tulemuse igal käivitusel.
4. Kirjuta `NOTES.md`-sse iga ootamatu tulemusega rea parandus.

| Kood | Kas `set -euo pipefail` peatab? |
|---|---|
| `systemctl enabled httpd` | ? |
| `rm -rf "$TMPDIR"/*`, kui `TMPDIR` on seadmata | ? |
| `if [ $NUM -gt 100 ]`, kui `NUM` on tühi | ? |
| `if deploy_site; then …` | ? |
| `local x=$(false)` | ? |
| `n=0; (( n++ ))` | ? |
| `journalctl … | grep -q x` | ? |

*Tabel L1.4. `set -e` piirid.*

**Kontroll:**

```bash
bash k01-bash/set-e-test.sh
shellcheck -S warning k01-bash/set-e-test.sh
```

**Valmis, kui:**

- iga tabeli rea kohta on üks `PEATUS` või `JÄTKAS` rida
- toru juhtum annab igal käivitusel sama koodi
- ShellCheck ei anna hoiatusi
- `NOTES.md`-s on iga ootamatu rea parandus

??? success "Lahendus"
    | Kood | Kas `set -euo pipefail` peatab? |
    |---|---|
    | `systemctl enabled httpd` | jah: `enabled` on tahtlik trükiviga (õige on `enable`), tundmatu alamkäsu peale annab `systemctl` koodi ≠ 0 |
    | `rm -rf "$TMPDIR"/*`, kui `TMPDIR` on seadmata | jah, `-u` tõttu, enne `rm`-i |
    | `if [ $NUM -gt 100 ]`, kui `NUM` on tühi | ei: `if` tingimuses viga ei peata, `[` annab koodi 2 ja haru jääb vahele |
    | `if deploy_site; then …` | ei: tingimuse kontekstis ei kehti `set -e` ka funktsiooni kehas |
    | `local x=$(false)` | ei: `local` tagastab 0 (ShellCheck SC2155) |
    | `n=0; (( n++ ))` | jah, ootamatult: `(( 0 ))` tagastab 1 |
    | `journalctl … | grep -q x` | mõnikord: `grep -q` lõpetab esimese vaste järel, `journalctl` saab SIGPIPE (kood 141) |

    Iga juhtum käivitub eraldi `bash -c`-s, nii et üks peatus ei katkesta teisi. Viimane rida näitab SIGPIPE-d deterministlikult: `yes` kirjutab lõputult ja `head` sulgeb toru.

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    cases=(
        'systemctl enabled httpd'
        'unset TMPDIR; rm -rf "$TMPDIR"/*'
        'NUM=""; if [ $NUM -gt 100 ]; then echo suur; fi'
        'f() { false; echo "f jätkas"; }; if f; then :; fi'
        'g() { local x=$(false); }; g'
        'n=0; (( n++ ))'
        'yes | head -1 > /dev/null'
    )
    for c in "${cases[@]}"; do
        if out=$(bash -c "set -euo pipefail; $c; echo jätkas" 2>&1); then rc=0; else rc=$?; fi
        if [[ "$out" == *jätkas ]]; then r=JÄTKAS; else r="PEATUS (kood $rc)"; fi
        printf '%-18s %s\n' "$r" "$c"
    done
    ```

    Parandused: `(( ++n ))` või `n=$((n + 1))`; `local x; x=$(…)`; `[[ $NUM =~ ^[0-9]+$ ]] || { echo "NUM pole arv" >&2; exit 1; }`. `if deploy_site` puhul ei aita `set -e` funktsiooni sees ega `||` väljaspool: funktsioon peab kriitilised käsud ise kontrollima (`wget … || return 1`) või käivituma ilma tingimuseta.

    Kontroll: `PEATUS` ridadel 1, 2, 6 ja 7 (viimasel kood 141), `JÄTKAS` ridadel 3, 4 ja 5.

    **Miks nii.** `set -e` jätab mulje, et iga ebaõnnestunud käsk peatab skripti. Tegelikult sõltub tulemus käsu asukohast: `if` tingimuses, funktsioonis, käsuasenduses ja aritmeetilises avaldises võivad reeglid olla teised. Tabelis olevad näited on ohtlikud just seepärast, et nad võivad töötada testis, kuid jätta deploy ajal vea märkamata.

    `journalctl … | grep -q x` rida ebaõnnestub ainult mõnikord: kas `journalctl` jõuab enne `grep`-i lõppu veel kirjutada, sõltub väljundi pikkusest ja ajastusest. Seepärast kasutab test `yes | head -1`, kus SIGPIPE tuleb alati.

    Kõik need juhtumid järgivad sama reeglit: `set -e` reageerib väljumiskoodile selles kohas, kus Bash seda koodi ootab, mitte sellele, kas käsk sinu mõttes õnnestus.

    Praktiline järeldus: kus käsu tulemus on otsus (`if`, `||`, `&&`), kontrolli koodi ise ja kirjuta vea korral selge teade. Kus käsk peab lihtsalt õnnestuma, jäta see `set -e` hooleks. `if deploy_site` rida on kõige ohtlikum, sest kogu funktsiooni sisu käivitub siis ilma `set -e`-ta.

### 8. Ansible sihtmasina poolelt

**Tase:** keskmine · **Eeldus:** [Sama töö Ansible'iga](lab-6-ansible.md)

Playbook töötab sinu masinas, aga kolleegi masinas mitte, või on käivitus oodatust mitu korda aeglasem. Põhjus on tavaliselt näha SSH-ühenduse sees või selles, millise `ansible.cfg`-i Ansible leidis.

1. Leia `-vvv` väljundist, millise SSH käsu, kasutaja ja võtmega Ansible db01-ga ühendub.
2. Lülita pipelining välja, jäta sihtmasinasse ajutised failid alles ja vaata, mis seal on. Korista need lõpus.
3. Mõõda `ansible all -m ansible.builtin.ping` aega pipelining'uga ja ilma.
4. Leia, millise konfiguratsioonifaili Ansible valib `ANSIBLE_CONFIG`-iga, projekti kaustas ja kõigile kirjutatavas kaustas.
5. Vaata, millised seaded erinevad vaikimisi väärtusest.

**Kontroll:**

```bash
cd ~/labori-seis/k02-ansible
ansible db01 -m ansible.builtin.ping -vvv 2>&1 | grep -E 'ESTABLISH|SSH: EXEC' | head -3
ANSIBLE_PIPELINING=False ANSIBLE_KEEP_REMOTE_FILES=1 ansible db01 -m ansible.builtin.ping
ssh db01 'ls ~/.ansible/tmp/*/'
ssh db01 'rm -rf ~/.ansible/tmp/ansible-tmp-*'
time ansible all -m ansible.builtin.ping; time ANSIBLE_PIPELINING=False ansible all -m ansible.builtin.ping
ANSIBLE_CONFIG=/etc/ansible/ansible.cfg ansible --version | grep 'config file'
ansible --version | grep 'config file'
chmod o+w . && ansible --version 2>&1 | grep -iE 'config file|world writable'; chmod o-w .
ansible-config dump --only-changed
```

**Valmis, kui:**

- ühenduse kasutaja ja võti on `-vvv` väljundist leitud
- ilma pipelining'uta on db01-s `~/.ansible/tmp/` all mooduli fail ja lõpus on see koristatud
- kahe `time` tulemuse vahe on teada
- kõigile kirjutatavas kaustas tuleb hoiatus ja `config file` ei ole sinu projekti fail

??? success "Lahendus"
    Ilma pipelining'uta teeb Ansible igas hostis mitu SSH-käsku: ajutine kaust, mooduli fail, `chmod`, käivitus ja koristus. Pipelining'uga läheb moodul ühe SSH-käsuga `python3` standardsisendisse. Ühenduse kasutaja ja võti on `ESTABLISH SSH CONNECTION FOR USER: kasutaja` real ja `SSH: EXEC` real (`-o 'IdentityFile=…'`, kui võti on seadistuses).

    ```bash
    ansible db01 -m ansible.builtin.ping -vvv 2>&1 | grep -c 'SSH: EXEC'
    ANSIBLE_PIPELINING=False ansible db01 -m ansible.builtin.ping -vvv 2>&1 | grep -c 'SSH: EXEC'
    ANSIBLE_PIPELINING=False ANSIBLE_KEEP_REMOTE_FILES=1 ansible db01 -m ansible.builtin.ping > /dev/null
    ssh db01 'ls ~/.ansible/tmp/*/; rm -rf ~/.ansible/tmp/ansible-tmp-*'
    ```

    Kontroll: esimene arv on väiksem kui teine, `ls` näitab `AnsiballZ_ping.py`. Kõigile kirjutatavas kaustas tuleb hoiatus `Ansible is being run in a world writable directory … ignoring it as an ansible.cfg source` ja `config file` ei ole enam sinu projekti fail. Kontrollimata: Ansible'it selle lahenduse kirjutamise keskkonnas ei käivitatud, `SSH: EXEC` ridade arv sõltub versioonist.

    **Miks nii.** Ilma pipelining'uta kopeerib Ansible iga mooduli faili `AnsiballZ_ping.py` sihtmasinasse ja käivitab selle, pipelining'uga saadab Ansible sama koodi Pythoni standardsisendisse. Muster on sama, mida `deploy-all.sh` teeb `bash -s`-iga. Ajavahe ühe `ping`-iga on väike, aga playbook'is on kümneid ülesandeid ja iga ülesanne on üks moodul igas hostis. Kui käivitus on aeglane, vaata esmalt, kas pipelining on sees, ja alles siis `forks`-i. Pipelining vajab, et sudo ei nõuaks `requiretty`-t; Ubuntu 24.04 ja Rocky 9 pilvemallides seda vaikimisi ei nõuta, vanemates RHEL-i paigaldustes võib see sees olla.

    Ansible ei liida konfiguratsioonifaile kokku, vaid kasutab esimest leitud faili. Kui keegi ütleb „minul töötab", on esimene küsimus, millist faili tema masin kasutas. Keskkonnamuutuja `ANSIBLE_CONFIG` on eelistatud kaustas oleva faili ees. Kõigile kirjutatavas kaustas jätab Ansible faili kasutamata ja hoiatab selle eest: keegi teine võiks sinna kirjutada oma `ansible.cfg`-i, mis käivitab tema koodi sinu õigustes. `dump --only-changed` näitab ainult neid seadeid, mis erinevad vaikimisi väärtusest. Selle väljundit on mõistlik veaotsingul kolleegile saata: see näitab ühe ekraaniga, mille poolest seadistus vaikimisi seisust erineb. Saladusi see tavaliselt ei sisalda, aga vaata väljund enne saatmist üle.

### 9. Üks host korraga ja vigade piir

**Tase:** keskmine · **Eeldus:** [Sama töö Ansible'iga](lab-6-ansible.md) · **Esita:** `k01-bash/NOTES.md`

Kui viga on playbook'is või sihtmasinas, ebaõnnestub käivitus vaikimisi kõigis hostides korraga. Tootmises tahad, et esimene vigane host peataks ülejäänud.

1. Algseis: `web.yml` teine käivitus annab `changed=0`. rmq01 malli kaust kustutatakse ja `unzip` viiakse ajutiselt teise nime alla.
2. Tee `web.yml`-ist koopia `/tmp/serial-web.yml` (repost väljas) ja lisa play'le `serial: 1` ja `max_fail_percentage: 0`. Käivita see kaustast `k02-ansible`, siis kehtib sinu `ansible.cfg`.
3. Lõhu rmq01, käivita koopia ja vaata, kas mc01-ni jõuti. Siis taasta `unzip` ja käivita `web.yml`.
4. Kirjuta `NOTES.md`-sse, mis järjekorras hostid läbiti, miks mc01 jäi puutumata ja kuidas sama teeks `webdeploy.sh`.

**Kontroll:**

```bash
ssh rmq01 'sudo rm -rf /opt/labseis-mall && sudo mv /usr/bin/unzip /usr/bin/unzip.x'
ansible-playbook /tmp/serial-web.yml -e web_template_url="$TEMPLATE_URL"
ssh rmq01 sudo mv /usr/bin/unzip.x /usr/bin/unzip
ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL"
```

**Valmis, kui:**

- koopia väljund lõpeb reaga `NO MORE HOSTS LEFT`
- PLAY RECAP-is on rmq01 `failed=1` ja mc01 rida puudub
- pärast taastamist lõpeb `web.yml` ilma `failed`-ita
- `NOTES.md`-s on kolm vastust

??? success "Lahendus"
    `serial: 1` jagab play üheliikmelisteks partiideks inventory järjekorras (webhosts: rmq01, siis mc01) ja `max_fail_percentage: 0` lõpetab play esimese ebaõnnestunud partii järel. `apt` ütleb rmq01-l `ok`, sest pakett `unzip` on paigaldatud, ja viga tuleb alles `unarchive`-is, mis ei leia `unzip`-i.

    ```yaml
    - name: Veebileht webhosts grupile
      hosts: webhosts
      become: true
      serial: 1
      max_fail_percentage: 0
    ```

    `webdeploy.sh`-is vastab sellele `-j 1` ja tsükli katkestus esimese nullist erineva `<host>.rc` järel; praegu käib skript kõik hostid läbi ja annab vea alles kokkuvõttes.

    Kontroll: `ansible-playbook /tmp/serial-web.yml -e web_template_url="$TEMPLATE_URL"` lõpeb reaga `NO MORE HOSTS LEFT`, PLAY RECAP-is on rmq01 `failed=1` ja mc01 rida puudub. Kontrollimata: Ansible'it selle lahenduse kirjutamise keskkonnas ei käivitatud.

    **Miks nii.** Ilma `serial`-ita käivitab Ansible iga ülesande kõigis hostides paralleelselt (`forks` piires), nii et vigane muudatus jõuab kõikjale enne, kui keegi seda näeb. Üheliikmeline partii on aeglasem, aga kahju jääb ühe hosti piiresse.

### 10. `dismantle.sh <teenus>`

**Tase:** keskmine · **Eeldus:** [Viis teenust](lab-4-viis-teenust.md) · **Esita:** `k01-bash/dismantle.sh`, `k01-bash/NOTES.md`

Paigaldusskript kirjutatakse peaaegu alati, eemaldusskript harva. Kui teenus tuleb hostilt ära viia, jäävad käsitsi eemaldamisel maha paketid, konfid ja avatud tulemüüri pordid.

1. `dismantle.sh <teenus>`: stop, disable, purge, konfiguratsioonifailid eemaldatud, firewalld port suletud, Ubuntus ja Rockys.
2. Teine käivitus lõpeb ilma veata ja ütleb, et polnud midagi eemaldada.
3. Andmeid ei kustutata ilma teadliku otsuseta: andmekaust jääb alles, kui seda eraldi ei küsita.
4. Proovi ainult laboris, kus teenuse andmed on tühjad või skriptiga taastatavad. Taastamine: `./deploy-all.sh <host>`.
5. Kirjuta `NOTES.md`-sse, mida peaks `dismantle.sh mariadb` tegema andmetega (`/var/lib/mysql`) ja miks ei tohi see neid vaikimisi kustutada.

**Kontroll:**

```bash
shellcheck -S warning k01-bash/dismantle.sh
scp k01-bash/dismantle.sh mc01:/tmp/
ssh mc01 sudo bash /tmp/dismantle.sh memcached; ssh mc01 sudo bash /tmp/dismantle.sh memcached
./check.sh > /dev/null; echo "kood $?"
./deploy-all.sh mc01 > /dev/null && ./check.sh > /dev/null; echo "kood $?"
```

**Valmis, kui:**

- ShellCheck ei anna hoiatusi
- esimene käivitus teatab eemaldamisest, teine ütleb, et teenust polnud, mõlemad koodiga 0
- `check.sh` annab koodi 1, pärast `./deploy-all.sh mc01` koodi 0
- `NOTES.md`-s on vastus andmete küsimusele

??? success "Lahendus"
    Iga samm kontrollib enne muutmist, seega teine käivitus ei ebaõnnestu ja ütleb "polnud paigaldatud". Rockys jätab `dnf remove` muudetud konfi alles nimega `.rpmsave`, Ubuntus võtab `purge` konfid ise. Andmekaust kustub ainult `FORCE=1`-ga: andmete kustutamine on eraldi otsus, mida ei tohi teha teenuse eemaldamise kõrvalmõjuna, ja snapshot'ita hostis pole seda tagasi võtta.

    ```bash
    #!/usr/bin/env bash
    # Kasutus: sudo bash dismantle.sh <web|mariadb|memcached|rabbitmq|tomcat|nginx>
    #          sudo FORCE=1 bash dismantle.sh mariadb   (kustutab ka /var/lib/mysql)
    set -euo pipefail
    what="${1:?mida eemaldada: web|mariadb|memcached|rabbitmq|tomcat|nginx}"
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
        ubuntu|debian) family=deb ;;
        rocky|rhel|centos|almalinux) family=rpm ;;
        *) echo "Tundmatu distro: $ID" >&2; exit 1 ;;
    esac

    installed() {
        if [[ $family == deb ]]; then
            dpkg-query -W -f='${Status}' "$1" 2> /dev/null | grep -q 'install ok installed'
        else
            rpm -q "$1" > /dev/null 2>&1
        fi
    }
    purge() {   # ainult paigaldatud paketid
        local p present=()
        for p in "$@"; do installed "$p" && present+=("$p"); done
        (( ${#present[@]} )) || return 0
        if [[ $family == deb ]]; then
            DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 purge -y -qq "${present[@]}" > /dev/null
            apt-get -o DPkg::Lock::Timeout=120 autoremove -y -qq > /dev/null
        else
            dnf remove -y -q "${present[@]}" > /dev/null
        fi
        removed=1
    }
    stop() {    # unit puudub → midagi peatada pole
        if systemctl list-unit-files "$1.service" --no-legend 2> /dev/null | grep -q .; then
            systemctl disable --now "$1" > /dev/null 2>&1
        fi
    }

    port="" removed=0
    case "$what" in
        web)
            if [[ $family == deb ]]; then svc=apache2; else svc=httpd; fi
            stop "$svc"; purge "$svc"; port=http
            if [[ -n "$(ls -A /var/www/html 2> /dev/null)" ]]; then rm -rf /var/www/html/*; removed=1; fi ;;
        mariadb)
            stop mariadb; purge mariadb-server; port=3306/tcp
            rm -f /etc/mysql/mariadb.conf.d/60-labseis.cnf /etc/my.cnf.d/60-labseis.cnf
            if [[ "${FORCE:-0}" == 1 && -d /var/lib/mysql ]]; then rm -rf /var/lib/mysql; removed=1; fi ;;
        memcached)
            stop memcached; purge memcached; port=11211/tcp
            rm -f /etc/sysconfig/memcached.rpmsave ;;
        rabbitmq) stop rabbitmq-server; purge rabbitmq-server ;;
        tomcat)
            stop tomcat
            if [[ -e /etc/systemd/system/tomcat.service || -d /opt/tomcat ]]; then
                rm -f /etc/systemd/system/tomcat.service; systemctl daemon-reload
                rm -rf /opt/tomcat /opt/tomcat-* /etc/labori-seis; removed=1
            fi ;;
        nginx)
            stop nginx; purge nginx nginx-common
            rm -f /etc/nginx/sites-available/labori-seis /etc/nginx/sites-enabled/labori-seis ;;
        *) echo "Tundmatu: $what" >&2; exit 1 ;;
    esac

    if [[ -n "$port" ]] && command -v firewall-cmd > /dev/null && systemctl is-active --quiet firewalld; then
        if [[ "$port" == http ]]; then fw=service=http; else fw="port=$port"; fi
        if firewall-cmd -q --permanent "--query-$fw"; then
            firewall-cmd -q --permanent "--remove-$fw"; firewall-cmd -q --reload; removed=1
        fi
    fi
    if (( removed )); then echo "$(hostname -s): $what eemaldatud"; else echo "$(hostname -s): $what polnud paigaldatud"; fi
    ```

    Kontroll: `scp dismantle.sh mc01:/tmp/ && ssh mc01 sudo bash /tmp/dismantle.sh memcached` ütleb `eemaldatud`, teine kord `polnud paigaldatud`; `./check.sh` annab koodi 1, pärast `./deploy-all.sh mc01` koodi 0. Kontrollimata: skripti on kontrollitud ShellChecki ja `bash -n`-iga, mitte labori VM-ides.

### 12. Health check app01-st

**Tase:** keskmine · **Eeldus:** [Kolm viga](lab-5-kolm-viga.md) · **Esita:** `k01-bash/deploy-all.sh`, `k01-bash/NOTES.md`

Kolme vea otsingul läbis health check mc01 juures, kuigi app01 ei saanud ühendust. Kontroll käis mc01-s endas, mitte sealt, kust teenust kasutatakse.

1. `deploy-all.sh` kontrollib db01, mc01 ja rmq01 porti app01 poolt, näiteks nii:

    ```bash
    ssh app01 'timeout 2 bash -c "</dev/tcp/mc01/11211"'
    ```

2. Viga ütleb, millist hosti kontrolliti ja millisest hostist; ajapiir tuleb `GATE_TIMEOUT`-ist.
3. Test: mc01 snapshot'ile `enne-stack`, starteri `memcache.sh` ajutiselt tagasi, siis `./deploy-all.sh mc01`.
4. Taasta oma `memcache.sh` (`git restore k01-bash/services/memcache.sh`) ja käivita `./deploy-all.sh mc01`.
5. Kirjuta `NOTES.md`-sse selle lähenemise puudus.

**Kontroll:**

```bash
GATE_TIMEOUT=15 ./deploy-all.sh mc01; echo "kood $?"
git restore k01-bash/services/memcache.sh && ./deploy-all.sh mc01
```

**Valmis, kui:**

- starteri `memcache.sh`-iga ebaõnnestub health check juba deploy ajal, teates on app01 ja kood on 1
- pärast `git restore` ütleb sama käsk `--- mc01 terve`
- `NOTES.md`-s on puudus kirjas

??? success "Lahendus"
    `PROBE` käivitub sihthostis, seega ei piisa käsu muutmisest: muuta tuleb ka hosti, kuhu `wait_healthy` SSH-ga läheb. Sihtmärk on IP failist `hosts`, mitte nimi, sest app01 `/etc/hosts`-i kirjutatakse alles app01 deploy'l ja esimesel täisdeploy'l pole seal veel mc01 nime.

    ```bash
    declare -A PROBE_FROM=([db01]=app01 [mc01]=app01 [rmq01]=app01)
    declare -A PORT=([db01]=3306 [mc01]=11211 [rmq01]=5672)
    probe() {
        local host="$1"
        if [[ -n "${PROBE_FROM[$host]:-}" ]]; then
            printf 'timeout 2 bash -c "</dev/tcp/%s/%s"' "$(ip_of "$host")" "${PORT[$host]}"
        else
            printf '%s' "${PROBE[$host]}"
        fi
    }

    wait_healthy() {
        local host="$1" from ip cmd deadline
        from="${PROBE_FROM[$host]:-$host}"
        ip=$(ip_of "$from")
        cmd=$(probe "$host")
        deadline=$((SECONDS + GATE_TIMEOUT))
        until ssh -n "${SSH_OPTS[@]}" "$SSH_USER@$ip" "$cmd" 2> /dev/null; do
            if (( SECONDS >= deadline )); then
                echo "VÄRAV: $host ei vastanud $from-st $GATE_TIMEOUT s jooksul ($cmd)" >&2
                return 1
            fi
            sleep 3
        done
        echo "--- $host terve"
    }
    ```

    Puudus: tulemus ei erista "mc01 on maas" ja "app01 on maas või nende vahel on võrguprobleem", ja täiesti tühjas keskkonnas peab app01 VM olema enne taustateenuseid SSH-ga kättesaadav.

    Kontroll: starteri `memcache.sh`-iga annab `GATE_TIMEOUT=15 ./deploy-all.sh mc01` rea `VÄRAV: mc01 ei vastanud app01-st 15 s jooksul` ja koodi 1; pärast `git restore` ütleb sama käsk `--- mc01 terve`. Kontrollimata: labori VM-ides; ShellCheck ja `probe` väljund on kontrollitud.

### 13. Teine mall ja vanad failid

**Tase:** keskmine · **Eeldus:** [Sama töö Ansible'iga](lab-6-ansible.md) · **Esita:** `k02-ansible/web.yml`

`copy` lisab ja uuendab faile, aga ei kustuta neid, mida uues versioonis pole. Iga veebisaidi uuendusega jääb veebijuurde vanu faile ja rollback eelmisele mallile pole puhas.

1. Algseis: `web.yml` teine käivitus annab `changed=0`. rmq01 ja mc01 veebijuure sisu võib kaduda.
2. Käivita `web.yml` teise Tooplate'i malliga (`-e web_template_url=<teine ZIP-i URL>`) ja vaata rmq01-s, millised failid jäid `/var/www/html` alla esimesest mallist.
3. Iga mall läheb oma kausta `/var/www/<mall>` ja veebijuur on sümlink aktiivsele kaustale (`ansible.builtin.file`, `state: link`).
4. Rollback eelmisele mallile on üks käivitus eelmise URL-iga.
5. Teine käivitus annab `changed=0`.

**Kontroll:**

```bash
ansible-playbook web.yml -e web_template_url=<teine ZIP-i URL>
ssh rmq01 'readlink /var/www/html; ls /var/www/html/'
ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL"
ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL"
```

**Valmis, kui:**

- `readlink /var/www/html` näitab uue malli kausta ja `ls` ainult selle faile
- esimese malli URL viib lingi tagasi ühe käivitusega
- järgmine käivitus annab `changed=0`

??? success "Lahendus"
    Need neli ülesannet asendavad ülesande "Malli sisu veebijuurde". `file: state: link` ei tee olemasolevast kaustast sümlinki, seega viiakse vana `/var/www/html` üks kord kõrvale. `stat` ei järgi vaikimisi linki: sümlingi puhul on `isdir` väär ja kõrvaletõstmine jääb vahele. Rollback on sama playbook eelmise URL-iga: kaust on olemas, `copy` annab `ok` ja muutub ainult link.

    ```yaml
    - name: Mall oma kausta
      ansible.builtin.copy:
        src: "{{ web_unpack_dir }}/{{ web_template }}/"
        dest: "/var/www/{{ web_template }}/"
        remote_src: true
        owner: root
        group: root
        mode: "u=rwX,g=rX,o=rX"

    - name: Veebijuure praegune kuju
      ansible.builtin.stat:
        path: "{{ web_docroot }}"
      register: web_root

    - name: Vana veebijuur kõrvale (üks kord, kaustalt sümlingile)
      ansible.builtin.command:
        cmd: "mv {{ web_docroot }} {{ web_docroot }}.enne-symlinki"
        creates: "{{ web_docroot }}.enne-symlinki"
      when: web_root.stat.isdir | default(false)

    - name: Veebijuur osutab aktiivsele mallile
      ansible.builtin.file:
        src: "/var/www/{{ web_template }}"
        dest: "{{ web_docroot }}"
        state: link
        owner: root
        group: root
    ```

    Kontroll: pärast teise malliga käivitust näitab `ssh rmq01 readlink /var/www/html` uue malli kausta ja `ls /var/www/html/` ainult selle faile; `-e web_template_url="$TEMPLATE_URL"` viib lingi tagasi ja järgmine käivitus annab `changed=0`. Kontrollimata: YAML parsib, `ansible-lint`-i ja labori VM-e selle lahenduse kirjutamise keskkonnas polnud.

### 14. Teata ainult oleku muutusest

**Tase:** keskmine · **Eeldus:** [Operatsioon](lab-7-operatsioon.md) · **Esita:** `k01-bash/check-notify.sh`

Timer kirjutab iga viie minuti järel sama `WARNING`-u ja inimene lakkab seda lugemast. Teade peab tulema ainult siis, kui olek muutub.

1. Algseis: timer töötab ja `check.sh` annab koodi 0.
2. `check-notify.sh` käivitab `check.sh`-i ja hoiab väljumiskoodi failis `logs/check.state`.
3. Kui kood erineb eelmisest, kirjutab skript journal'isse üks rida `logger -t labseis-alert -p user.warning`-iga: vana ja uus olek ning `check.sh` viimane rida.
4. Kui kood on sama, ei kirjuta skript midagi. Skripti enda kood on sama mis `check.sh`-il.
5. Pane timer'i `ExecStart` ajutiselt `check-notify.sh` peale ja peata mc01-s memcached. Lõpus `ExecStart` tagasi `check.sh`-ile, `systemctl --user daemon-reload` ja `./deploy-all.sh mc01`.

**Kontroll:**

```bash
ssh mc01 sudo systemctl stop memcached
systemctl --user status labseis-check.service      # mõne timer'i käivituse järel
./deploy-all.sh mc01
journalctl -t labseis-alert --since -1h --no-pager
```

**Valmis, kui:**

- `journalctl -t labseis-alert` näitab pärast mitut timer'i käivitust ainult kahte rida: `OK → WARNING` ja pärast `./deploy-all.sh mc01` `WARNING → OK`
- rikke ajal näitab `systemctl --user status labseis-check.service` `status=1`
- ShellCheck ei anna `check-notify.sh`-ile hoiatusi

??? success "Lahendus"
    Olek kirjutatakse alles pärast teadet: kui `logger` ebaõnnestub, proovib järgmine käivitus uuesti. Puuduv või vigane olekufail tähendab "eelmine oli OK", nii et esimene käivitus tervel stackil ei tekita teadet.

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    cd "$(dirname "$0")"
    STATE=logs/check.state
    NAMES=(OK WARNING CRITICAL UNKNOWN)
    mkdir -p logs

    rc=0
    out=$(./check.sh 2>&1) || rc=$?
    prev=$(cat "$STATE" 2> /dev/null || echo 0)
    [[ "$prev" =~ ^[0-9]+$ ]] || prev=0

    if [[ "$rc" != "$prev" ]]; then
        logger -t labseis-alert -p user.warning -- \
            "${NAMES[$prev]:-kood $prev} → ${NAMES[$rc]:-kood $rc}: $(tail -n 1 <<< "$out")"
    fi
    printf '%s\n' "$rc" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    exit "$rc"
    ```

    Timer: `systemctl --user edit --full labseis-check.service`, `ExecStart=%h/labori-seis/k01-bash/check-notify.sh`, siis `systemctl --user daemon-reload`.

    Kontroll: `journalctl -t labseis-alert --since -1h --no-pager` näitab kahte rida `OK → WARNING: WARNING: 3 hoiatust` ja `WARNING → OK: OK: kõik kihid töötavad`, `systemctl --user status labseis-check.service` näitab rikke ajal `status=1`. Oleku loogika on kontrollitud võlts-`check.sh`-iga; journald'i ja timer'iga kontrollimata.

### 15. Saladuste kontroll pre-commit hook'iga

**Tase:** keskmine · **Eeldus:** [Git meeskonnas](lab-8-git-meeskonnas.md) · **Esita:** `k01-bash/hooks/pre-commit`, `k01-bash/NOTES.md`

Saladuse proovis nägid, et `git rm --cached` ei puhasta ajalugu. Odavam on peatada saladus enne, kui see üldse commit'i jõuab: pre-commit hook'i nullist erinev väljumiskood katkestab commit'i enne, kui commit-objekt luuakse.

1. `k01-bash/hooks/pre-commit` (Bash, `set -euo pipefail`, ShellCheck ei anna hoiatusi) loeb ainult staging'ut: `git diff --cached -U0` lisatud read (`^+`).
2. Keeldub, kui lisatud real on `PASSWORD=`, `TOKEN=` või `SECRET=` tegeliku väärtusega. Muutuja viide (`=$…`, `="$…`) pole saladus.
3. Keeldub, kui staging'us on fail `*.env`. `*.example` failid on lubatud.
4. Ütleb faili nime ja põhjuse ning lõpeb koodiga 1.
5. Hook on sisse lülitatud repo seadena (`core.hooksPath`). Proovid teed ajutisel harul.
6. Kirjuta `NOTES.md`-sse, miks hook'ist üksi ei piisa.

**Kontroll:**

```bash
chmod +x k01-bash/hooks/pre-commit && git config core.hooksPath k01-bash/hooks
git switch -c hook-proov
printf 'DB_PASSWORD=Sup3r\n' > prod.env && git add prod.env && git commit -m proov; echo "kood $?"
git restore --staged prod.env && rm prod.env
echo '# proov' >> k01-bash/NOTES.md && git commit -qam "NOTES proov"; echo "kood $?"
```

**Valmis, kui:**

- `prod.env` commit keeldub, teade nimetab faili ja kood on 1
- `NOTES.md` commit läheb läbi
- `LABSEIS_TOKEN=` tühja väärtusega ja `export DB_PASSWORD="$DB_PASSWORD"` lähevad läbi
- `NOTES.md`-s on kirjas, miks hook'ist üksi ei piisa

??? success "Lahendus"
    Failinimi tuleb diff'i päisest `+++ b/<fail>`, mis algab samuti `+`-iga, seega kontrollitakse seda enne lisatud ridu. Väärtust ei väljastata: hook'i väljund võib jõuda CI logisse. `%q` jms on `printf`-i vorming, mitte saladus (`deploy-all.sh`-is on rida `export DB_PASSWORD=%q`).

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0

    while IFS= read -r -d '' f; do
        case "$f" in
            *.example) ;;
            *.env) echo "pre-commit: $f: .env fail ei lähe Giti" >&2; fail=1 ;;
        esac
    done < <(git diff --cached --name-only -z --diff-filter=ACMR)

    file=""
    while IFS= read -r line; do
        case "$line" in
            '+++ b/'*) file=${line#+++ b/} ;;
            '+++ '*) file="" ;;
            +*)
                [[ "$file" == *.example ]] && continue
                if [[ "$line" =~ (PASSWORD|TOKEN|SECRET)=([^[:space:]]+) ]]; then
                    case "${BASH_REMATCH[2]}" in
                        \$* | \"\$* | \'\$* | %*) ;;
                        *) echo "pre-commit: $file: lisatud real on ${BASH_REMATCH[1]}= väärtusega" >&2; fail=1 ;;
                    esac
                fi ;;
        esac
    done < <(git diff --cached -U0 --no-color --diff-filter=ACMR)

    (( fail == 0 )) || echo "pre-commit: commit katkestatud (eemalda: git restore --staged <fail>)" >&2
    exit "$fail"
    ```

    Kontroll: `printf 'DB_PASSWORD=Sup3r\n' > prod.env && git add prod.env && git commit -m proov` annab kaks rida `prod.env` kohta ja koodi 1; `LABSEIS_TOKEN=` tühja väärtusega, `export DB_PASSWORD="$DB_PASSWORD"` ja `NOTES.md` lähevad läbi. Kontrollitud ajutises Giti repos.

    Hook'ist üksi ei piisa, sest `git commit --no-verify` läheb sellest mööda ja `core.hooksPath` pole värskes kloonis vaikimisi seatud. Sama kontroll peab olema ka serveri poolel (CI või push'i kontroll).

### 16. Tarnija repo: fork ja upstream

**Tase:** keskmine · **Eeldus:** [Git meeskonnas](lab-8-git-meeskonnas.md) · **Esita:** `k01-bash/NOTES.md`

Monitooringu plugin, Ansible'i roll või tarnija skript, mida meeskond kasutab, vajab sinu parandust, aga algsesse repos pole sul kirjutusõigust. Kui fork jääb maha, puuduvad teil kas tarnija turvaparandused või sinu enda omad. Siin on `tarnija.git` algne repo ja `fork.git` sinu fork serveris, mõlemad kohalikud bare-repod.

1. Loo tarnija repo ühe commit'iga ja tee sellest fork (Giti `user.name` ja `user.email` on seatud, kõik on kaustas `/tmp/k01-fork`):

    ```bash
    mkdir -p /tmp/k01-fork && cd /tmp/k01-fork
    git init -q --bare -b main tarnija.git && git clone -q tarnija.git tarnija-dev
    printf '#!/usr/bin/env bash\nset -euo pipefail\ndf -P / | awk '\''NR == 2 {print $5}'\''\n' > tarnija-dev/check_disk.sh
    (cd tarnija-dev && git add check_disk.sh && git commit -qm "check_disk.sh: kasutus protsentides" && git push -q origin main)
    git clone -q --bare tarnija.git fork.git && git clone -q fork.git fork-too
    ```

2. Kaustas `fork-too`: remote `upstream` osutab `tarnija.git`-ile, `origin` jääb fork'iks.
3. Parandus harul `lavi`: `check_disk.sh` võtab lävendi argumendina (vaikimisi 90) ja annab ületamisel koodi 1. Haru on fork'is.
4. Tarnija liigub vahepeal edasi: `tarnija-dev`-is üks uus commit (näiteks `README.md`) ja push.
5. Sünkroniseeri: fork'i `main` võrdub `upstream/main`-iga ainult fast-forward'iga, `lavi` on `upstream/main`-i peal ja fork'is uuendatud ilma `--force`-ita.
6. Paku parandus tagasi: `git request-pull` väljund `NOTES.md`-sse koos vastusega, miks fork'i `main`-ile ei tehta oma commit'e.

**Kontroll:**

```bash
cd /tmp/k01-fork/fork-too
git rev-parse main upstream/main origin/main
git merge-base --is-ancestor upstream/main lavi; echo $?
git log --oneline upstream/main..lavi
./check_disk.sh 1; echo $?
```

**Valmis, kui:**

- `git rev-parse` annab kolm korda sama hash'i
- `git merge-base --is-ancestor` annab koodi 0
- `git log --oneline upstream/main..lavi` näitab ainult sinu commit'i
- `./check_disk.sh 1` annab hoiatuse ja koodi 1
- `NOTES.md`-s on `request-pull` väljund ja vastus

??? success "Lahendus"
    Fork'i `main` on ainult tarnija koopia: sinu töö elab harul. Siis on `main`-i sünkroonimine alati fast-forward ja konflikt saab tekkida ainult sinu harul, kus see on sinu lahendada. Rebase'i järel vajab juba üles lükatud haru `--force-with-lease`-i, sest see on ainult sinu haru.

    ```bash
    cd /tmp/k01-fork/fork-too
    git remote add upstream /tmp/k01-fork/tarnija.git && git remote -v
    git switch -c lavi
    cat > check_disk.sh <<'EOF'
    #!/usr/bin/env bash
    set -euo pipefail
    max=${1:-90}
    use=$(df -P / | awk 'NR == 2 {sub("%", "", $5); print $5}')
    echo "${use}%"
    (( use < max )) || { echo "WARNING: / üle ${max}%" >&2; exit 1; }
    EOF
    git commit -qam "check_disk.sh: lävend argumendina, kood 1" && git push -q -u origin lavi
    (cd ../tarnija-dev && echo '# check_disk' > README.md && git add README.md && git commit -qm "README" && git push -q)
    git fetch upstream
    git switch main && git merge --ff-only upstream/main && git push origin main
    git switch lavi && git rebase upstream/main && git push --force-with-lease origin lavi
    git request-pull upstream/main /tmp/k01-fork/fork.git lavi
    ```

    Kontroll: kolm `rev-parse`-i on võrdsed, `merge-base --is-ancestor` annab `0`, `upstream/main..lavi` näitab üht commit'i ja `./check_disk.sh 1; echo $?` annab hoiatuse ning `1`. Kontrollitud ajutises kaustas Git 2.43-ga.

    **Miks nii.** GitHubis teeb fork'i `gh repo fork <omanik>/<repo> --clone` ja PR läheb `gh pr create --repo <omanik>/<repo>`-ga, `request-pull` asemel on PR fork'i harust tarnija `main`-i. Kohalikud bare-repod näitavad sama mehhanismi ilma, et vajaksid kellegi teise GitHubi repot.

## Rasked ülesanded

### 17. deploy-all.sh lainetena

**Tase:** raske · **Eeldus:** [Viis teenust](lab-4-viis-teenust.md) · **Esita:** `k01-bash/deploy-waves.sh`, `k01-bash/NOTES.md`

Järjestikune `deploy-all.sh` on turvaline, aga aeglane. `deploy-waves.sh` paigaldab sõltumatud hostid paralleelselt ja peab otsustama, mis juhtub, kui üks host ebaõnnestub keset lainet, kui host hangub ja kui keegi käivitab deploy teist korda.

1. Tuleta lained sõltuvustest (mis peab töötama enne app01, mis enne web01) ja kirjuta põhjendus `NOTES.md`-sse.
2. Iga host on eraldi `./deploy-all.sh <host>` koos selle health check'iga, väljund `logs/<host>.log`, iga taustatöö kood eraldi.
3. Kui laines ebaõnnestub üks host, lõpetavad sama laine teised hostid oma töö (apt-i ei katkestata poole pealt), järgmist lainet ei alustata ja kokkuvõte näitab iga hosti kohta `OK`, `VIGA` või `VAHELE`.
4. Ühel hostil on ajapiir keskkonnamuutujast `HOST_TIMEOUT` (sekundites): hangunud SSH või apt-i lukk ei hoia deploy'd lõputult kinni.
5. Teine samaaegne käivitus keeldub kohe.

**Kontroll:**

```bash
time ./deploy-all.sh > /dev/null; time ./deploy-waves.sh
sed -i 's/^rmq01 .*/rmq01 <vaba IP>/' hosts; ./deploy-waves.sh; echo "kood $?"; git restore hosts
HOST_TIMEOUT=5 ./deploy-waves.sh; echo "kood $?"
./deploy-waves.sh > /dev/null & sleep 1; ./deploy-waves.sh; echo "kood $?"; wait
```

**Valmis, kui:**

- `deploy-waves.sh` on mõõdetavalt kiirem kui `deploy-all.sh`
- vale rmq01 IP-ga on rmq01 `VIGA`, sama laine teised hostid `OK`, hilisemate lainete hostid `VAHELE` ja kood 1
- `HOST_TIMEOUT=5`-ga lõpeb skript ajapiiri teatega
- teine samaaegne käivitus keeldub koodiga 1

??? tip "Lahenduse suund"
    **Lained:** db01, mc01 ja rmq01 ei sõltu üksteisest; app01 vajab kõiki kolme (`tomcat.sh` ootab `/version`-it, mis vajab andmebaasi ja järjekorda); web01 on viimane, sest Nginx kontrollib käivitudes app01 nime. Laine kestus on selle aeglaseima hosti kestus, nii et võit tuleb ainult esimesest lainest.

    **Mehhanism:** iga host `&`-ga taustale, PID assotsiatiivsesse massiivi (`pid[$host]=$!`), siis iga PID-i kohta eraldi `wait "$pid" || rc=$?`. Pelk `wait` annab 0 ka siis, kui mõni taustatöö ebaõnnestus. Ajapiir: `timeout --kill-after=10 "$HOST_TIMEOUT" ./deploy-all.sh "$host"`, kood 124 tähendab ajapiiri. Lukk: `exec 9> logs/.deploy.lock; flock -n 9`. Taustaprotsessid pärivad fd 9, nii et kui `deploy-waves.sh` tapetakse, hoiavad veel töötavad `deploy-all.sh`-id lukku kuni oma lõpuni. Nii see peabki olema.

    **Kontroll:** vale IP-ga test peab näitama, et sama laine teised hostid lõpetasid (`--- db01 terve` nende logis) ja app01 logi ei uuenenud.

    **Tüüpiline lõks:** `set -e` + `wait "$pid"` ilma `|| …`-ita lõpetab skripti esimese ebaõnnestunud hosti juures. Siis jäävad teiste hostide tulemused lugemata ja kokkuvõte puudub. Teine lõks: `local -A` massiiv funktsioonis, mis käivitub alamshellis (`$( … )` või toru), kaotab väärtused.

### 18. Parooli vahetus skriptiga

**Tase:** raske · **Eeldus:** [Operatsioon](lab-7-operatsioon.md) · **Esita:** `k01-bash/rotate-db-password.sh`, `k01-bash/NOTES.md`

RabbitMQ harjutuses ([lisaülesanne 2](#2-rabbitmq-kasitsi-ja-sudo-logi)) nägid, et lekkinud parool tuleb välja vahetada. `DB_PASSWORD` on kahes kohas, db01 MariaDB kasutajal ja app01 Tomcati keskkonnas, ja nende vahetamise vahel on aken, kus need erinevad. Rike võib tulla keset vahetust.

1. Algseis: `/health` on kõigil kihtidel `UP`. Vana parool lakkab töötamast, vahepeal võib `db` olla `DOWN`. Taastamine: `secrets.env` varukoopiast, siis `./deploy-all.sh db01 app01`.
2. `k01-bash/rotate-db-password.sh` genereerib uue parooli ise; parool ei jõua ühegi protsessi käsureale (`ps`, sudo logi) ega ekraanile.
3. `secrets.env` uueneb aatomiliselt ja eelmine versioon jääb varukoopiaks kohta, mida Git ei näe (`git status` jääb puhtaks).
4. db01 ja app01 deploy'takse järjekorras, mille põhjendad `NOTES.md`-s; kaks samaaegset käivitust pole võimalikud.
5. Kui mõni samm ebaõnnestub, taastab skript eelmise parooli igas hostis, mida ta jõudis puudutada, ja lõpeb nullist erineva koodiga; eraldi kood juhuks, kui ka rollback ebaõnnestus.
6. Lõpus kontrollib skript `/health`-ist, et `db` on `UP`.

**Kontroll:**

```bash
./rotate-db-password.sh; echo "kood $?"
ssh db01 'sudo journalctl -t sudo --since -15min --no-pager' | grep -cFf <(sed -n 's/^DB_PASSWORD=//p' secrets.env)
ssh -t db01 mysql -h db01 -u labseis -p        # vana parooliga
git status --short
sed -i 's/^app01 .*/app01 <vaba IP>/' hosts; ./rotate-db-password.sh; echo "kood $?"; git restore hosts
```

**Valmis, kui:**

- esimene käivitus annab koodi 0, `/health` näitab `"db":"UP"` ja `git status` on puhas
- sudo logis on uue parooli vasteid `0`
- vana parool annab `Access denied`
- vale app01 IP-ga lõpeb skript nullist erineva koodiga, `secrets.env` on jälle eelmise parooliga ja `/health` näitab `"db":"UP"`
- `NOTES.md`-s on kirjas, mitu sekundit oli `db` `DOWN`, mis kood rikketestis tuli ja miks

??? tip "Lahenduse suund"
    **Järjekord:** db01 (`ALTER USER`) enne app01-t (uus `/etc/labori-seis/env` ja Tomcati restart). `ALTER USER` ei katkesta olemasolevaid ühendusi, seega töötab Tomcati pool edasi ja aken puudutab ainult uusi ühendusi. Vastupidises järjekorras käivituks Tomcat uue parooliga vastu vana parooli ja oleks kohe `DOWN`. Akent ei saa sellise skeemiga nulli viia; selleks oleks vaja kahte kehtivat kasutajat või parooli korraga.

    **Mehhanism:** `openssl rand -hex 24` (ainult `[0-9a-f]`: `mariadb.sh` paneb parooli SQL-i `'…'` sisse); uus fail `mktemp secrets.env.XXXXXX` samas kaustas ja `mv` (sama failisüsteem, aatomiline); parool `awk`-ile keskkonnast (`NEWPW="$new" awk '… ENVIRON["NEWPW"] …'`), mitte argumendina; varukoopia `mktemp`-iga kausta `~/.local/state/labseis/`; lukk `flock`-iga samas kaustas. Host lisatakse rollback'i nimekirja **enne** tema deploy'd, sest poolik deploy võis parooli juba muuta.

    **Kontroll:** rikketestis jõuab db01 uue paroolini, app01 SSH ebaõnnestub ja rollback viib db01 tagasi. app01 rollback ebaõnnestub samal põhjusel. Skript ei saa teada, kas app01 jõudis midagi muuta, nii et aus tulemus on "rollback osaliselt ebaõnnestus", mitte 0.

    **Tüüpiline lõks:** `sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$new/"` paneb parooli `sed`-i käsureale; `secrets.env.bak` repo kaustas pole `.gitignore`-is ja läheb `git add .`-iga GitHubi; `tr -dc … < /dev/urandom | head -c 32` annab `pipefail`-iga koodi 141.

    **Miks vana parooliga kontroll.** `Access denied` vana parooliga näitab, et parool vahetus ka MariaDB kasutajal, mitte ainult `secrets.env`-is.

### 19. WordPress automaatselt

**Tase:** raske · **Eeldus:** [Viis teenust](lab-4-viis-teenust.md) · **Esita:** `k01-bash/wordpress.sh`, `k01-bash/NOTES.md`

Internetist leitud paigaldusskript on tavaliselt kirjutatud ühe OS-i versiooni ja ühe eduka käivituse jaoks. Sinu `wordpress.sh` peab taluma kolme asja, mida selline skript ei talu: teist käivitust, katkenud allalaadimist ja parooli, mis ei tohi jõuda logidesse.

1. Algseis: rmq01-st on värske snapshot (Ubuntu, port 80 on seal vaba). Parool on control node'is failis `~/.config/is1/wp-db-password` (`openssl rand -hex 16`, `chmod 600`). Taastamine: rollback sellele snapshot'ile, siis `./deploy-all.sh rmq01`.
2. `wordpress.sh` paigaldab Apache'i, PHP 8.3, MariaDB samasse masinasse ja WordPressi `/srv/www/wordpress`. Parool tuleb standardsisendist ja seda pole rmq01 sudo logis ega ühegi protsessi käsureal.
3. Teine käivitus ütleb "muudatusi pole", ei laadi Apache'it uuesti ja `wp-config.php` jääb baidi pealt samaks.
4. Katkenud või vigane arhiiv ei jäta `/srv/www/wordpress`-i poolikuks: skript ebaõnnestub ja järgmine käivitus õige URL-iga lõpetab paigalduse.
5. `wp-config.php` soolad genereeritakse üks kord; kui soolade päring ebaõnnestub, ei jää poolikut `wp-config.php`-d.
6. Võta üks internetist leitud Ubuntu 20.04 WordPressi skript ja kirjuta `NOTES.md`-sse, mis selles 24.04-l ei tööta ja miks.

**Kontroll:**

```bash
PW=~/.config/is1/wp-db-password; scp k01-bash/wordpress.sh rmq01:/tmp/
ssh rmq01 'sudo WP_URL=http://web01/health bash /tmp/wordpress.sh' < "$PW"; echo "kood $?"
ssh rmq01 'ls -d /srv/www/wordpress'
for i in 1 2; do ssh rmq01 'sudo bash /tmp/wordpress.sh && sudo md5sum /srv/www/wordpress/wp-config.php' < "$PW"; done
ssh rmq01 'sudo journalctl -t sudo --since -30min --no-pager' | grep -cFf "$PW"
```

**Valmis, kui:**

- vigase URL-iga on kood ≠ 0 ja `/srv/www/wordpress` puudub
- kahe järgmise käivituse `md5sum` on sama ja teine ütleb "muudatusi pole"
- sudo logis on parooli vasteid `0`
- `http://rmq01/` avab WordPressi paigaldusvormi
- `NOTES.md`-s on 20.04 skripti vead

??? tip "Lahenduse suund"
    **Parool:** `IFS= read -r WP_DB_PASSWORD` standardsisendist. `sudo WP_DB_PASSWORD=… bash …` paneb parooli sudo logi `ENV=` välja ja `ps`-i, `sed "s/password_here/$pw/"` paneb selle `sed`-i käsureale. `wp-config.php`-sse läheb see `awk`-iga keskkonnast (`ENVIRON`), MariaDB-sse heredoc'iga standardsisendi kaudu.

    **Aatomilisus:** kõik ehitatakse ajutises kaustas samas failisüsteemis (`mktemp -d /srv/www/.wp-stage.XXXXXX`) ja tõstetakse paika `mv`-ga. `tar -tzf` kontrollib arhiivi enne lahtipakkimist. Kui kaust on olemas, aga `wp-settings.php` puudub, siis skript peatub ega kustuta midagi. Soolade vastust kontrollitakse (`grep "define('AUTH_KEY'"`) enne, kui `wp-config.php` paika läheb.

    **Idempotentsus:** paketid `dpkg-query`-ga, vhost kirjutatakse ajutisse faili ja võrreldakse `cmp -s`-iga, `a2query -s`/`-m` enne `a2ensite`/`a2enmod`, `systemctl reload apache2` ainult muudatuse korral. Muudatuste loendur annab "muudatusi pole".

    **20.04 → 24.04:** tüüpilised leiud on PHP 7.4 versiooniga paketinimed ja teed (`php7.4-…`, `/etc/php/7.4/`), interaktiivne `mysql_secure_installation`, `wp-config.php` kirjutamine igal käivitusel (uued soolad logivad kõik kasutajad välja) ja `wget … | tar` ilma veakontrollita.

    **Tüüpiline lõks:** `tar -xzf` otse `/srv/www`-sse. Katkenud arhiiv jätab `wp-settings.php`-ga pooliku kausta ja järgmine käivitus peab paigaldust valmis.

### 20. Heakskiidetud tegevuste kataloog

**Tase:** raske · **Eeldus:** [Operatsioon](lab-7-operatsioon.md) · **Esita:** `k01-bash/run-action.sh`, `k01-bash/actions/`, `k01-bash/NOTES.md`

Öösel võib tegevuse käivitada inimene, timer või alarm. Kõik kolm peavad käivitama ainult sama üle vaadatud koodi ja jätma sama jälje.

1. Kataloog `k01-bash/actions/catalog`, rida tegevuse kohta: nimi, skript kaustas `actions/`, lubatud hostid (komadega või `*`), kinnitus (`jah`/`ei`). Tegevused: lugev `disk-usage` (kõik hostid, kinnituseta) ja muutev `journal-vacuum` (`journalctl --vacuum-size=200M`; db01, app01, web01; kinnitusega).
2. `run-action.sh <tegevus> <host>` keeldub tegevusest, mida kataloogis pole, ja hostist, mis pole tegevusele lubatud (kood 2).
3. Käivitub ainult commit'itud kood: kui `actions/` kaustas on commit'imata või jälgimata faile, keeldub skript (kood 3). Hosti läheb täpselt see sisu, mida kontrolliti.
4. Kinnitust vajav tegevus käivitub ainult siis, kui terminalis on inimene, kes kirjutab hosti nime. Ilma terminalita (timer, alarm) keeldub skript koodiga 4.
5. Iga katse, ka keeldutud ja katkenud, annab journal'isse ühe `run-action` rea: kes, kas oli terminal, tegevus, host, commit, kood ja põhjus. Tegevuse väljund läheb `logs/action-<tegevus>-<host>.log`-i.
6. Ühel tegevusel on ajapiir keskkonnamuutujast `ACTION_TIMEOUT`; ebaõnnestumine või ajapiir annab koodi 1.

**Kontroll:**

```bash
./run-action.sh disk-usage db01; echo "kood $?"
./run-action.sh rm-rf db01; echo "kood $?"
./run-action.sh journal-vacuum mc01; echo "kood $?"
echo '# muudatus' >> actions/disk-usage.sh; ./run-action.sh disk-usage db01; echo "kood $?"; git restore actions/disk-usage.sh
./run-action.sh journal-vacuum db01 < /dev/null; echo "kood $?"
./run-action.sh journal-vacuum db01; echo "kood $?"
journalctl -t run-action --since -15min --no-pager
```

**Valmis, kui:**

- koodid on järjest 0, 2, 2, 3, 4 ning hosti nime kirjutamise järel 0
- journal'is on kuus `run-action` rida ja igaühes on `commit=` ning `kood=`
- `NOTES.md`-s on kirjas, kuidas sama kataloogi kasutaks timer või alarm ja kus nende jaoks kinnitus küsitakse

Vihje: `journal-vacuum` kustutab db01-s journald arhiivid üle 200 MB.

??? tip "Lahenduse suund"
    **Mehhanism:** heakskiidetud tähendab commit'itud. `git status --porcelain -- actions/` peab olema tühi ja auditisse läheb `git rev-parse --short HEAD`. Kataloog ja tegevuse skript loetakse `git show HEAD:<tee>`-ga, mitte töökaustast, ja skript läheb hosti `ssh … 'bash -s'` standardsisendisse. Nii ei saa faili muuta kontrolli ja käivituse vahel ning sihtmasinasse faili ei jää. Hosti lubatavus: `[[ ",$allowed," == *",$host,"* ]]`. Kinnitus: `[[ -t 0 ]]` ja `read -rp`.

    **Audit:** üks `logger -t run-action -p auth.notice` rida `EXIT`-trap'is, mitte skripti lõpus. Muidu jäävad keeldumised ja katkenud käivitused auditist välja, kuigi just neid auditis vaja on.

    **Kontroll:** võlts-ssh-ga (`SSH=<tee>` keskkonnamuutuja) saad kõik koodid läbi proovida ilma hostita; journal'i read peavad tekkima ka koodidega 2–4.

    **Tüüpiline lõks:** skript kontrollib `git status`-t, aga käivitab siis faili töökaustast. Teine lõks: kinnituse `read` loeb sama standardsisendit, mida keegi suunas (`< /dev/null`, toru), ja „kinnitus“ tuleb failist. Täislahendus: `labori-seis/deploy/lisa-lahendused/k01/T-tegevuste-kataloog/`.

## Võrguinsenerile

Võrguinseneri ülesanded on üks väike tööriist `vorgukogu`, mis kasvab iga kohtumisega: täna Python ja Netmiko, järgmisel korral sama töö Ansible'iga, siis konteiner, soovitud seis mallist ja diff ruuteri vastu, testid ja CI, öine Jenkinsi töö varunduse repo'sse ja lõpuks Kubernetese CronJob. Kood on repo juurkaustas `vorgukogu/`, mitte `k01-bash/`-is: automaatne hindaja seda kausta ei kontrolli ja iga päev lisab samasse kausta ühe faili või kausta.

### 21. vorgukogu.py: show-käskude väljund kahelt ruuterilt

**Tase:** keskmine · **Eeldus:** [Üks käsk, mitu hosti](lab-3-mitu-hosti.md) · **Esita:** `vorgukogu/` (`vorgukogu.py`, `inventory.yaml`, `requirements.txt`, `known_hosts`)

Enne hooldusakent on vaja iga ruuteri versiooni, liideste olekut ja running-config'i. Koolitaja loodud `rtr01` (`<IS1_NET>.21`) ja `rtr02` (`<IS1_NET>.22`) on Ubuntu 24.04 ja [FRRouting (FRR)](https://docs.frrouting.org/) 10.x.

1. Algseis: `ssh kasutaja@<IS1_NET>.21` töötab võtmega `~/.ssh/id_ed25519_labseis`; venv, `requirements.txt` ja `.gitignore` (`.venv/`, `out/`, `*.env`):

    ```bash
    sudo apt-get install -y python3-venv
    mkdir -p ~/labori-seis/vorgukogu && cd ~/labori-seis/vorgukogu
    python3 -m venv .venv && . .venv/bin/activate
    pip install 'netmiko==4.7.*' 'pyyaml==6.0.*'
    pip freeze | grep -iE '^(netmiko|paramiko|pyyaml)=='
    ```

2. `known_hosts` sõrmejäljed on võrreldud ruuteri omadega (Proxmoxi konsoolis `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`).
3. `inventory.yaml`: seadmed IP-ga ja `device_type: linux`, käsud `show version`, `show interface brief`, `show running-config`. Kasutaja ja võti tulevad keskkonnast (`VORK_USER`, `VORK_KEY_FILE` või `VORK_PASSWORD`).
4. Väljund läheb faili `out/<seade>/<käsk>.txt`, running-config alates reast `frr version`. Paroolide, `key-string`-i (ka `key chain lab`) ning OSPF-i ja BGP võtmete väärtused on `***`, käsk jääb.
5. Hostivõtit kontrollitakse `known_hosts`-i vastu, ajapiir on 10 s. Seade, mis ei vasta või annab poolikut väljundit (pole `hostname <seade>` või viimane rida pole `end`), saab `FAIL`, tema vanad failid jäävad alles ja teised kogutakse ikka.
6. Lõppkood: 0 kõik korras, 2 mõni seade ebaõnnestus, 1 seadistuse viga (inventory, keskkonnamuutuja või `known_hosts` puudu).

**Kontroll:**

```bash
ssh-keyscan -t ed25519 <IS1_NET>.21 <IS1_NET>.22 2>/dev/null > known_hosts
ssh-keygen -lf known_hosts
export VORK_USER=kasutaja VORK_KEY_FILE=~/.ssh/id_ed25519_labseis
python vorgukogu.py; echo "kood $?"
find out -type f | sort
grep -rnE '(password|key-string|md5) +[^* ]' out/; echo "kood $?"
cp -r out out.enne
ssh kasutaja@<IS1_NET>.21 "sudo vtysh -c 'configure terminal' -c 'interface lo' -c 'description proov'"
python vorgukogu.py --only rtr01 && diff -r out.enne out
sed 's/^devices:/&\n  - {name: rtr09, host: 192.0.2.1}/' inventory.yaml > proov.yaml
time python vorgukogu.py --inventory proov.yaml; echo "kood $?"
ssh kasutaja@<IS1_NET>.21 "sudo vtysh -c 'configure terminal' -c 'interface lo' -c 'no description'"
rm -r proov.yaml out.enne
```

**Valmis, kui:**

- esimene jooks: `OK` mõlemale, kood `0`, `out/` all 6 faili
- saladuste `grep` annab koodi `1`
- `diff -r` näitab ainult rida `>  description proov` failis `rtr01/show-running-config.txt`
- `proov.yaml`-iga: `FAIL rtr09`, kood `2`, teiste failid uuendatud, aeg alla 30 s
- rtr01 `lo` kirjeldus on lõpus eemaldatud

??? success "Lahendus"
    Skript on jagatud väikesteks funktsioonideks, et 5. kohtumisel saaks neid ilma ruuterita testida: `mask_secrets` ja `check_running_config` on puhtad funktsioonid, `ConnectHandler` antakse `main`-ile argumendina. `except Exception` seadme tsüklis on teadlik: Netmiko ja Paramiko tõstavad ajapiiri, autentimise ja hostivõtme vea eri klassidena ning ükski neist ei tohi teisi seadmeid peatada. Failid kirjutatakse kõrvale ja nimetatakse ümber, nii et katkestus ei jäta poolikut faili. `ssh_strict=True` koos `alt_key_file`-iga lükkab tagasi hosti, mille võtit failis pole.

    ```yaml
    # vorgukogu inventory: ainult aadressid ja seadme tüüp.
    # Kasutaja, võti ja parool tulevad keskkonnast (VORK_USER, VORK_KEY_FILE / VORK_PASSWORD).
    # IP-d: <IS1_NET>.21 ja .22 (koolitaja tahvlilt); näites IS1_NET=10.10.7.
    defaults:
      device_type: linux   # FRR Ubuntu peal: Netmiko Linuxi draiver + vtysh
      port: 22
      timeout: 10          # sekundit TCP ühenduse loomiseks
    commands:
      - show version
      - show interface brief
      - show running-config
    devices:
      - name: rtr01
        host: 10.10.7.21
      - name: rtr02
        host: 10.10.7.22
    ```

    ```python
    #!/usr/bin/env python3
    """vorgukogu: kogub ruuteritelt show-käskude väljundi failidesse out/<host>/<käsk>.txt.

    Kasutus (kaustast vorgukogu/, venv aktiivne):
        export VORK_USER=kasutaja VORK_KEY_FILE=~/.ssh/id_ed25519_labseis
        python vorgukogu.py                     # kõik inventory.yaml seadmed
        python vorgukogu.py --only rtr01        # üks seade

    Väljumiskood: 0 kõik seadmed korras, 2 vähemalt üks seade ebaõnnestus (teised on kogutud),
    1 seadistuse viga (inventory või keskkonnamuutujad puudu).
    """

    from __future__ import annotations

    import argparse
    import os
    import re
    import sys
    from pathlib import Path

    import yaml
    from netmiko import ConnectHandler

    # FRR-il pole Netmiko draiverit: ühendume Linuxi hostina (device_type "linux")
    # ja käivitame FRR-i CLI vtysh'i ühe käsuga. Päris Cisco seadmel (cisco_ios) läheb käsk otse.
    VTYSH_DEVICE_TYPES = {"linux"}

    # Read, mille väärtus ei lähe faili: käsk jääb alles, väärtus asendatakse.
    # Nii näitab diff, et saladus muutus, aga mitte saladust ennast.
    SECRET_PATTERNS = [
        re.compile(r"^(\s*(?:enable\s+)?password)\s+\S.*$", re.MULTILINE),
        re.compile(r"^(\s*key-string)\s+\S.*$", re.MULTILINE),
        re.compile(r"^(\s*ip ospf authentication-key)\s+\S.*$", re.MULTILINE),
        re.compile(r"^(\s*ip ospf message-digest-key\s+\d+\s+md5)\s+\S.*$", re.MULTILINE),
        re.compile(r"^(\s*neighbor\s+\S+\s+password)\s+\S.*$", re.MULTILINE),
        re.compile(r"^(\s*(?:enable\s+)?secret)\s+\S.*$", re.MULTILINE),
        re.compile(r"^(\s*username\s+\S+\s+(?:secret|password))\s+\S.*$", re.MULTILINE),
    ]
    MASK = "***"


    class ConfigError(Exception):
        """Inventory või keskkonnamuutujad on puudu või vigased."""


    def mask_secrets(text: str) -> str:
        """Asendab saladuste väärtused MASK-iga, käsk jääb alles."""
        for pattern in SECRET_PATTERNS:
            text = pattern.sub(rf"\1 {MASK}", text)
        return text


    def command_for(device_type: str, command: str) -> str:
        """FRR-i Linuxi hostil läheb show-käsk vtysh'i kaudu, mujal otse."""
        if device_type in VTYSH_DEVICE_TYPES:
            return f"vtysh -c '{command}'"
        return command


    def filename_for(command: str) -> str:
        """'show running-config' -> 'show-running-config.txt'."""
        return re.sub(r"[^a-z0-9]+", "-", command.lower()).strip("-") + ".txt"


    def strip_header(running_config: str) -> str:
        """FRR-i päis 'Building configuration...' välja: alates reast 'frr version'."""
        lines = running_config.splitlines()
        for i, line in enumerate(lines):
            if line.startswith("frr version"):
                return "\n".join(lines[i:]) + "\n"
        return running_config.strip() + "\n"


    def check_running_config(text: str, hostname: str) -> None:
        """Tühi, katkenud või võõra seadme väljund ei tohi head varukoopiat üle kirjutada."""
        lines = [line.rstrip() for line in text.strip().splitlines()]
        if f"hostname {hostname}" not in lines:
            raise ValueError(f"väljundis pole rida 'hostname {hostname}'")
        if not lines or lines[-1] != "end":
            raise ValueError("viimane rida pole 'end' (väljund on poolik)")


    def load_inventory(path: Path) -> tuple[list[dict], list[str]]:
        """Loeb seadmed ja käsud. Paroole ega võtmeid inventory's pole."""
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except (OSError, yaml.YAMLError) as e:
            raise ConfigError(f"{path}: {e}") from e
        defaults = data.get("defaults", {})
        commands = data.get("commands") or []
        devices = []
        for item in data.get("devices") or []:
            if "name" not in item or "host" not in item:
                raise ConfigError(f"{path}: igal seadmel peab olema name ja host ({item})")
            devices.append({**defaults, **item})
        if not devices or not commands:
            raise ConfigError(f"{path}: devices ja commands ei tohi olla tühjad")
        return devices, commands


    def credentials(env: dict) -> dict:
        """Kasutaja ja võti või parool tulevad keskkonnast, mitte failist, mis läheb Giti."""
        user = env.get("VORK_USER")
        key_file = env.get("VORK_KEY_FILE")
        password = env.get("VORK_PASSWORD")
        if not user or not (key_file or password):
            raise ConfigError("sea VORK_USER ja VORK_KEY_FILE (või VORK_PASSWORD)")
        creds = {"username": user}
        if key_file:
            creds.update(use_keys=True, key_file=os.path.expanduser(key_file), allow_agent=False)
        if password:
            creds["password"] = password
        return creds


    def connect_params(device: dict, creds: dict, known_hosts: Path) -> dict:
        """Netmiko ConnectHandler'i argumendid ühe seadme jaoks."""
        return {
            "device_type": device.get("device_type", "linux"),
            "host": device["host"],
            "port": int(device.get("port", 22)),
            **creds,
            # vaikimisi võtab Netmiko vastu iga hostivõtme; siin ainult known_hosts failis olevad
            "ssh_strict": True,
            "alt_host_keys": True,
            "alt_key_file": str(known_hosts),
            "conn_timeout": int(device.get("timeout", 10)),
            "auth_timeout": 10,
            "banner_timeout": 15,
        }


    def collect_device(device: dict, commands: list[str], params: dict, connect=ConnectHandler) -> dict:
        """Käivitab käsud ühel seadmel ja tagastab {käsk: väljund}. Viga tõstetakse üles."""
        outputs = {}
        with connect(**params) as conn:
            for command in commands:
                raw = conn.send_command(command_for(params["device_type"], command), read_timeout=30)
                if command == "show running-config":
                    raw = strip_header(raw)
                    if params["device_type"] in VTYSH_DEVICE_TYPES:
                        check_running_config(raw, device["name"])
                outputs[command] = mask_secrets(raw.rstrip() + "\n")
        return outputs


    def write_atomic(path: Path, text: str) -> None:
        """Uus fail kirjutatakse kõrvale ja nimetatakse ümber: pooleli faili ei teki."""
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(text, encoding="utf-8")
        tmp.replace(path)


    def main(argv: list[str] | None = None, env: dict | None = None, connect=ConnectHandler) -> int:
        parser = argparse.ArgumentParser(description="Kogub ruuteritelt show-käskude väljundi.")
        parser.add_argument("--inventory", type=Path, default=Path("inventory.yaml"))
        parser.add_argument("--out", type=Path, default=Path("out"))
        parser.add_argument("--only", action="append", help="ainult see seade (võib korrata)")
        args = parser.parse_args(argv)
        env = dict(os.environ) if env is None else env

        try:
            devices, commands = load_inventory(args.inventory)
            creds = credentials(env)
        except ConfigError as e:
            print(f"VIGA: {e}", file=sys.stderr)
            return 1
        known_hosts = Path(env.get("VORK_KNOWN_HOSTS", args.inventory.parent / "known_hosts"))
        if not known_hosts.is_file():
            print(f"VIGA: {known_hosts} puudub (ssh-keyscan + sõrmejälje kontroll)", file=sys.stderr)
            return 1
        if args.only:
            devices = [d for d in devices if d["name"] in args.only]

        failed = []
        for device in devices:
            name = device["name"]
            try:
                outputs = collect_device(device, commands, connect_params(device, creds, known_hosts), connect)
            except Exception as e:  # üks maas seade ei peata teisi
                reason = str(e).splitlines()[0] if str(e) else ""
                print(f"FAIL {name}: {type(e).__name__}: {reason}", file=sys.stderr)
                failed.append(name)
                continue
            for command, text in outputs.items():
                write_atomic(args.out / name / filename_for(command), text)
            print(f"OK   {name}: {len(outputs)} faili")

        if failed:
            print(f"ebaõnnestus: {', '.join(failed)}", file=sys.stderr)
            return 2
        return 0


    if __name__ == "__main__":
        sys.exit(main())
    ```

    Kontroll: nõuete all olevad käsud. `FAIL rtr09: NetmikoTimeoutException` tuleb `conn_timeout`-i järel (10 s). Kui rtr01 annab `FAIL … not found in known_hosts`, on `known_hosts`-is teine aadress kui `inventory.yaml`-is; kui `vtysh` vastab `Permission denied`, pole `kasutaja` grupis `frrvty`. Täislahendus: `labori-seis/deploy/lisa-lahendused/k01/vork-vorgukogu/`. Kontrollimata: Netmiko 4.7 ja FRR-i vastu (siin polnud PyPI-t ega ruuterit); kontrollitud võlts-`ConnectHandler`-iga 5. kohtumise testides (FRR 10 väljundi kujul, maas seade, poolik väljund, puuduv seadistus).

    **Miks nii.** Python on võrguautomaatikas levinuim keel, sest seadmete jaoks on valmis teegid ja sama skript töötab Linuxis, macOS-is ja konteineris. Sõltuvused lähevad projekti oma venv'i, mitte süsteemi Pythonisse: Ubuntu 24.04 keelab süsteemi `pip install`-i (PEP 668) ja iga projekt saab oma versioonid. [Paramiko](https://www.paramiko.org/) on SSH protokolli teostus Pythonis: ühendus, autentimine, hostivõtme kontroll ja kanal. [Netmiko](https://github.com/ktbyers/netmiko) (4.7, Python ≥ 3.9) on Paramiko peal teek, mis tunneb seadmete CLI eripärasid: prompti äratundmine, paging'u väljalülitus, enable- ja konfirežiim. `ConnectHandler(device_type="cisco_ios", …)` annab ühenduse ja `send_command("show version")` tagastab väljundi stringina, kui prompt on tagasi. Platvorme on üle saja (`cisco_ios`, `cisco_nxos`, `juniper_junos`, `arista_eos` jne). **FRR-ile Netmiko draiverit pole.** FRR on Linuxi programm, seepärast ühendub skript ruuteriga kui Linuxi hostiga (`device_type="linux"`) ja käivitab `vtysh -c "show …"`. Cisco seadmel läheks sama käsk otse, ilma `vtysh`-ita; muu kood jääb samaks.

    FRR-i CLI `vtysh` on Cisco IOS-i sarnane (`show running-config`, `configure terminal`, `write memory`), salvestatud konf on `/etc/frr/frr.conf`. Kasutaja `kasutaja` on grupis `frrvty`, seega töötab `vtysh` ilma `sudo`-ta.

    Võrguinsener kasutab seda siis, kui sama `show` käsk on vaja saada kahesajalt seadmelt, väljund peab olema failis võrdlemiseks või muudatus tuleb teha kõigil ühtemoodi. Käsitsi on see SecureCRT-i sessioonid ja kopeerimine, Expect-skriptiga on see habras prompti ootamine. Netmiko kirjutab selle osa sinu eest.

    Maskitavad read on `password`, `enable password`, `key-string`, `ip ospf authentication-key`, `ip ospf message-digest-key … md5` ja `neighbor … password`; lahenduse `SECRET_PATTERNS` katab lisaks `secret`-i ja `username … secret`. Nii näitab diff, et saladus muutus, aga mitte saladust ennast. Netmiko võtab vaikimisi vastu iga hostivõtme, seepärast `known_hosts` ja `ssh_strict=True`; fail ei ole saladus ja läheb Giti. Inventory's on IP, mitte nimi: 3. kohtumise konteiner ja 7. kohtumise pod ei näe control node'i `/etc/hosts`-i. Väljundfailid on seadmete konf: need ei lähe selle repo Giti, 6. kohtumisel viiakse need eraldi privaatsesse repo'sse. Ajapiir 10 s on vajalik, sest TCP vaikimisi ootab maas seadet umbes kaks minutit.

## Arutelu

Käske pole vaja. Vasta `NOTES.md`-s paari lausega või arutle järgmise kohtumise alguses.

1. **websetup.sh.** Sinu idempotentsuse kontroll võrdleb malli faile. Mida see ei märka? Millal oleks parem võrrelda kogu kausta (`rsync --dry-run --delete`) ja mis on selle oht?
2. **Mitu hosti.** Kas `webdeploy.sh` peaks 200 hostiga peatuma esimese 10 vea järel? Kuidas teeks seda `xargs -P` või Ansible'i `max_fail_percentage`?
3. **Kolm viga.** Memcached on maas, aga leht töötab ja `/health` annab 200. Millal võiks vahemälu kadumine olla kasutajale sama halb kui andmebaasi kadumine?
4. **Sama töö Ansible'iga.** `web.yml` ei oota `cloud-init status --wait`-i ega võta lukku nagu `flock`. Millal see värskelt kloonitud VM-il ebaõnnestub, millise mooduliga lisaksid ootamise ja kas lukk on Ansible'i ülesanne või käivitaja (timer, pipeline) oma?
5. **Git meeskonnas.** Sinu `check.sh` annab koodi 1, kui vahemälu on maas, ja koodi 2, kui andmebaas on maas. Kas see sobib `git bisect run` testiks, kui otsid commit'i, mis murdis ainult andmebaasiühenduse? Millist testi kasutaksid selle asemel?

## Kodutöö

*Sobib pärast lehte [Operatsioon](lab-7-operatsioon.md).*

Kodutöö viib sama `websetup.sh`-i pilve ja `check.sh` mõtte monitooringusse. AWS-is käivitub `websetup.sh` user-data skriptina ilma argumentideta, seepärast oli vaikemall vajalik. Pilves pole snapshot'i, mis kõik tagasi viiks: koristus on sinu töö ja iga unustatud ressurss maksab.

| Issue | Mis | Juhend |
|---|---|---|
| `K1.K` | AWS: konto ohutus, EC2 `websetup.sh`-iga user-datana, koristus | [`kodutood/k01-aws.md`](../kodutood/k01-aws.md) |
| `K1.M` | Monitooring: `golden-signals.sh`, cron iga 5 min, tulemus Labori seisu | [`kodutood/monitooring.md`](../kodutood/monitooring.md) → 1. kohtumine |
