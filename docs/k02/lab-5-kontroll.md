---
tags:
  - Ansible
  - ansible-lint
  - testimine
---

# 5. Kontroll enne muudatust

Kolleeg parandas mc01-s faili käsitsi, `/health` on roheline ja viga tuleb välja nädal hiljem reboot'il. Samamoodi jõuab tootmisse plaan, mis check'is valetab, ja võõras roll, mida keegi ei lugenud. Stack töötab ja teine jooks on `changed=0`, aga enne kui kood läheb teise masinasse või pipeline'i, pead teadma, et sellele saab loota. Nüüd lukustad kollektsioonide versioonid, teed lint'i puhtaks, paned `--check`-i tõtt rääkima, lased `failed_when`-il poliitikarikkumise peatada ja kirjutad `verify.yml`-i, mis kontrollib stacki sealt, kust seda kasutatakse: app01-st andmebaasi, vahemälu ja RabbitMQ porte, web01-st `/health`-i. Kontrollid on järjestatud odavamast kallimani: lint ja syntax-check ei puuduta ühtki hosti, `--check` küsib hostidelt, aga ei muuda midagi, ja `verify.yml` kontrollib töötavat stacki.

Lõpuks on lint puhas ja `verify.yml` roheline: samade kontrollidega otsid hiljem intsidenti ja samas järjekorras käivitab neid GitHub Actionsi pipeline.

**Kui teed seda tööl iga päev:** `ansible-lint` annab `0 failure(s), 0 warning(s)` ja `ansible-playbook site.yml --check` viiel hostil `changed=0 failed=0` ilma ühegi lugeva ülesande `skipping`-uta. Kui see on sul juba korras, mine otse etappi [„Rolli test: assert sisendile ja verify.yml“](#rolli-test-assert-sisendile-ja-verifyyml).

## Kollektsioonid versioonidega ja võõras roll

Vaatad üle, mis versioonid sul tegelikult paigaldatud on, ja loed läbi ühe populaarse avaliku rolli. Rolli kasutusele ei võta: harjutad võõra koodi lugemist enne, kui see sinu serveritesse jõuab.

Võõras roll töötab root'ina kõigis hostides, kuhu sa selle paned. Kui sa pole seda lugenud, ei tea sa, mida see paigaldab, milliseid porte avab ja mis juhtub, kui autor järgmises versioonis vaikeväärtust muudab.

1. Vaata, et `requirements.yml`-is on kolm kollektsiooni versioonivahemikuga (`ansible.mariadb`, `community.rabbitmq`, `ansible.posix`) ja et paigaldatud versioonid jäävad vahemikku.

    ```bash
    cat requirements.yml
    ansible-galaxy collection list | grep -E 'mariadb|rabbitmq|posix'
    ```

2. Laadi üks avalik roll proovikausta ja loe see läbi, enne kui sellist kunagi kasutad.

    ```bash
    ansible-galaxy role install geerlingguy.memcached -p scratch/roles
    sed -n '1,25p' scratch/roles/geerlingguy.memcached/tasks/main.yml
    cat scratch/roles/geerlingguy.memcached/defaults/main.yml
    ansible-lint scratch/roles/geerlingguy.memcached | tail -5
    ```

    <!-- EKRAANIPILT: galaxy.ansible.com, rolli geerlingguy.memcached leht; näha nimi, toetatud platvormid (Debian/Ubuntu, EL), viimane versioon ja allalaadimiste arv. Tee enne install-käsku.
    <figure markdown="span">
      ![Ansible Galaxy leht rolliga geerlingguy.memcached](assets/k02_galaxy_memcached.png)
      <figcaption>Joonis L2.5. Galaxy rolli leht: platvormid ja versioon enne paigaldamist.</figcaption>
    </figure>
    -->

3. Kirjuta README-sse: milline sinu rolli muutuja vastab tema `memcached_listen_ip`-le, mida teeb tema roll, mida sinu oma ei tee, ja mitu lint-leidu populaarsel rollil on.

> Galaxy ei vasta? `git clone --depth 1 https://github.com/geerlingguy/ansible-role-memcached scratch/roles/geerlingguy.memcached`.

Võõras roll on üles ehitatud samamoodi nagu sinu oma: `defaults`, `vars` distro kaupa, `tasks`, `handlers`. Lint-leiud populaarses rollis ei tähenda, et roll on halb. Need näitavad, et lint'i reeglid muutuvad ajas ja iga projekt otsustab ise, milliseid ta järgib. Sinu projekti otsustab automaatne hindaja: kõik reeglid.

✅ **Edasi saad minna, kui** kolm kollektsiooni on vahemikus, roll on `scratch/roles` all (Gitist väljas) ja README-s on kolm vastust.

## ansible-lint puhtaks

Lint leiab vormivead ja osa mõttevigu enne, kui ükski host neid näeb. Automaatne hindaja lint'ib kogu kausta, sh eelmise korra `web.yml`-i, ja ignoreerib sinu `.ansible-lint` faili. Lubatud on kuni kolm `# noqa`-t, igaühel põhjendus.

Lint-leid, mis jääb parandamata, harjutab meeskonna leide ignoreerima. Siis jääb märkamata ka see leid, mis tähendab viga, näiteks `no-changed-when` ülesandel, mis muudab midagi igal jooksul.

1. Käivita lint ja paranda leiud ükshaaval ([reeglid](https://docs.ansible.com/projects/lint/rules/)): `fqcn`, `name[casing]`, `name[template]`, `no-changed-when`, `no-handler`, `var-naming[no-role-prefix]`, `risky-file-permissions`, `yaml[truthy]`.

    ```bash
    ansible-lint
    bash ../autograde/check.sh k02 lint
    bash ../autograde/check.sh k02 syntax
    ```

2. Pärast parandusi käivita stack kaks korda: lint-parandus ei tohi masinates midagi muuta.

Puhas lint tähendab, et kood on ühtlane ja ilmsed lõksud on suletud. See ei tähenda, et kood teeb õiget asja: selle ütleb teine jooks ja `verify.yml`. `changed=0` pärast parandusi tõestab, et parandused muutsid ainult vormi. Kui mõni host oleks `changed`, muutis mõni parandus ka käitumist, tavaliselt failiõigusi `risky-file-permissions` reegli järel.

✅ **Edasi saad minna, kui** `ansible-lint` ütleb `0 failure(s), 0 warning(s)`, mõlemad automaatse hindaja kontrollid annavad `OK` ja teine `site.yml` jooks on `changed=0`.

## --check, mis räägib tõtt

Seadistatud stackil peab `--check` andma `changed=0` ja ühtki viga. Kui see ebaõnnestub või jätab midagi vahele, ei saa sa check'i peale muudatust usaldada. Siin leiad ülesanded, mis check'is valetavad, ja parandad need.

Check, mis ebaõnnestub ka siis, kui kõik on korras, õpetab inimesi check'i mitte käivitama. Check, mis jätab kontrolli vahele, ütleb "kõik korras" ka siis, kui pole.

1. Käivita check kogu stackil ja märgi üles iga ülesanne, mis ebaõnnestub või on `skipping`, kuigi see ainult loeb (päring, ootamine, `uri` kontroll).

    ```bash
    ansible-playbook site.yml --check 2>&1 | tee scratch/check1.txt | grep -E 'fatal|skipping|changed='
    ```

2. Igale sellisele ülesandele lisa `check_mode: false`. Muutvale ülesandele (pakett, fail, teenus, import) mitte kunagi.
3. Käivita uuesti ja võrdle.

    ```bash
    ansible-playbook site.yml --check | tail -7
    grep -rn -B4 'check_mode: false' roles | grep -E 'name:'
    ```

4. Kirjuta README-sse iga ülesanne, millele `check_mode: false` lisasid, ja üks lause, mis oleks valesti läinud ilma selleta.

`check_mode: false` tähendab "käivitu ka check'i ajal". Lugeva ülesande jaoks on see ohutu, sest see ei muuda midagi. Muutva ülesande jaoks oleks see ohtlik, sest check ei oleks enam dry-run. `changed=0 failed=0` check'is tähendab nüüd, et kood ja masinad on samas seisus.

✅ **Edasi saad minna, kui** `--check` annab viiel hostil `changed=0 failed=0` ja `check_mode: false` on ainult lugevatel ülesannetel.

## Drift: käsitsi muudatus, mida keegi ei märganud

Muudad mc01-s Memcached'i konfifaili käsitsi, aga teenust ei taaskäivita. Teenus töötab edasi vana seadistusega ja `/health` on roheline. Siis leiad muudatuse `--check`-iga ja vaatad, kuidas seda skriptis tuvastada.

Selline drift on nähtamatu kuni järgmise restardi või reboot'ini. Siis kuulab Memcached ainult loopback'il, app01 ei jõua sinna ja keegi ei seosta seda nädal tagasi tehtud käsitsi muudatusega.

1. Tee käsitsi muudatus ja vaata, et teenus vastab ikka.

    ```bash
    ssh mc01 "sudo sed -i 's/^OPTIONS=.*/OPTIONS=\"-l 127.0.0.1\"/' /etc/sysconfig/memcached"
    curl -s http://web01/health; echo
    ```

2. Leia muudatus check'iga ja vaata käsu väljumiskoodi.

    ```bash
    ansible-playbook site.yml --check --diff --limit cache | grep -E '^[-+]OPTIONS|changed='; echo "kood ${PIPESTATUS[0]}"
    ansible-playbook site.yml --check --limit cache | grep -qE 'changed=[1-9]' && echo DRIFT
    ```

3. Paranda playbook'iga ja vaata, et handler käivitus.

    ```bash
    ansible-playbook site.yml --limit cache | grep -E 'RUNNING HANDLER|changed='
    ```

4. Kirjuta README-sse, miks check'i kood oli `0`, kuigi muudatus leiti, ja kuidas sa sama kontrolli öösel automaatselt käivitaksid.

Diff näitas täpselt, mis muutus ja kus, enne kui midagi parandati. Kood `0` tähendab, et check lõpetas vigadeta, mitte et muudatusi polnud: `changed` ei ole Ansible'i jaoks viga. Seepärast tuvastab skript drift'i PLAY RECAP-ist, mitte väljumiskoodist. Parandus käivitas handleri, sest fail muutus: nii jõudis õige seadistus ka teenusesse, enne kui keegi seda märkas.

✅ **Edasi saad minna, kui** diff näitab `-OPTIONS="-l 127.0.0.1"` ja `+` rida mc01 IP-ga, kood on `0`, teine käsk ütleb `DRIFT`, parandus käivitab `Restart memcached` handlerit ja README-s on kaks vastust.

## Muudatuse plaan: --check --diff

Plaanitud muudatus: app01 saab rohkem mälu ja RabbitMQ parool vahetub. Vaatad mõlemat enne, kui ükski teenus taaskäivitub. See on tavaline muudatuse töövoog: plaan, ülevaatus, käivitus, kontroll.

Parooli vahetus peab jõudma ühe jooksuga nii RabbitMQ-sse kui ka rakenduse env-faili.

1. Muuda `host_vars/app01.yml`-is `tomcat_heap` väärtuseks `576m` ja Vaultis `vault_mq_password`.

    ```bash
    ansible-vault edit group_vars/all/vault.yml
    ansible-playbook site.yml --check --diff --limit app01,rmq01
    ```

2. Leia diff'ist unit-faili rida `-Xmx`. Vaata, mida check näitab env-faili ja RabbitMQ kasutaja kohta.
3. Käivita ilma `--check`-ita ja vaata, kus midagi muutus.

    ```bash
    ansible-playbook site.yml | grep -E 'changed:|RUNNING HANDLER|changed='
    curl -s http://web01/health; echo
    ```

4. Kirjuta README-sse, mida check näitas ja mida peitis, ja miks see on õige.

> `git diff group_vars/all/vault.yml` näitab ainult krüpteeritud ridu. Loetava diff'i annab lisaülesanne [4. Vaulti diff Gitis](lisa.md#4-vaulti-diff-gitis).

Check näitas mälu muudatust täpselt ja peitis paroolid, sest `no_log: true` peidab ka diff'i. See on õige: diff jõuab logisse ja pipeline'i väljundisse, kus paroolil pole kohta. Käivitus muutis kahte hosti ja `/health` jäi `UP`-ks. See tõestab, et parool jõudis korraga RabbitMQ-sse ja rakenduse env-faili. Kui `/health` näitaks `"queue":"DOWN"`, oleks parool jõudnud ainult ühte kohta.

✅ **Edasi saad minna, kui** check näitab `-Xmx512m` → `-Xmx576m`, env-faili ja kasutaja kohta ainult peidetud tulemust, päris jooks muudab ainult app01-t ja rmq01-t ning `/health` on `UP`.

## failed_when: kontroll, mis peatab

`failed_when` ütleb, mis on viga. Seda saab kasutada poliitikana: kui keegi on Rocky hostis SELinuxi välja lülitanud, peab play peatuma, mitte vaikselt edasi minema. Sa ei paranda siin SELinuxi automaatselt, vaid peatad töö ja annad inimesele märku.

Automaatne `setenforce 1` peidaks probleemi, mille tõttu SELinux välja lülitati: AVC keelud tuleksid tagasi ja teenus seiskuks järgmisel jooksul.

1. Lisa rolli `common` ülesanne, mis käivitab `getenforce` ainult Rocky hostidel. Nõuded: `register` rolli eesliitega, `changed_when: false`, `check_mode: false` ja `failed_when` tõene, kui väljund pole `Enforcing`.
2. Lülita mc01-s SELinux ajutiselt permissive'iks ja käivita.

    ```bash
    ssh mc01 sudo setenforce 0
    ansible-playbook site.yml --limit rocky | grep -E 'fatal|SELinux|failed='
    ssh mc01 sudo setenforce 1
    ansible-playbook site.yml --limit rocky | tail -4
    ```

3. Kirjuta README-sse, mille poolest erineb `failed_when` `ignore_errors`-ist ja miks `cloud-init status --wait` ülesandel on `failed_when: … not in [0, 2]`.

mc01 ebaõnnestus ja db01 jõudis lõpuni: viga peatab ainult selle hosti, kus poliitikat rikuti. `failed_when` defineerib, mis on viga, `ignore_errors` aga ütleb, et viga ei loe. Need on vastupidised tööriistad. Esimest kasutad kontrolliks, teist peaaegu mitte kunagi.

✅ **Edasi saad minna, kui** permissive mc01 ebaõnnestub SELinuxi ülesandes, db01 jõuab samal jooksul lõpuni ja pärast `setenforce 1` on jooks roheline.

## Rolli test: assert sisendile ja verify.yml

Lisad rolli algusesse sisendi kontrolli ja kirjutad eraldi playbook'i, mis ainult kontrollib. `assert` kaitseb rolli halva sisendi eest enne, kui midagi muutub. `verify.yml` kontrollib tulemust nii, nagu seda näeb rakendus või kasutaja.

Roll, mis võtab vastu lühikese parooli, loob nõrga kasutaja ja keegi ei saa sellest teada. Stack, mida kontrollitakse ainult teenuse enda hostis, võib olla igas hostis "korras" ja kasutaja jaoks ikka katki.

1. Lisa rolli `mariadb` esimeste ülesannete hulka `ansible.builtin.assert`: `labseis_db_name` vastab mustrile `^[a-z][a-z0-9_]*$` ja `labseis_db_password` on vähemalt 12 märki, `quiet: true`, arusaadav `fail_msg`. Proovi lühikese parooliga.

    ```bash
    ansible-playbook site.yml --limit db -e vault_db_password=lyhike | grep -E 'fatal|msg|changed='
    ```

2. Kirjuta `k02-ansible/verify.yml`, mis ainult kontrollib:
    - igal hostil on custom fact `labseis` ja selle `roll` on hosti `group_names`-is
    - app-hostilt vastavad db, cache ja queue grupi esimese hosti pordid 3306, 11211, 5672 (`ansible.builtin.wait_for`, `timeout: 5`)
    - app-hostis on `tomcat.service` `running` ja `enabled` (`service_facts`) ning `/etc/labori-seis/env` on `0640 root:tomcat` (`stat` + `assert`)
    - web-hostist annab `http://localhost/health` 200 ja JSON-is on `db`, `cache`, `queue` kõik `UP` (`uri` `status_code: [200, 503]`, siis `assert`)
3. Käivita, peata üks teenus, vaata, kus verify ebaõnnestub, ja paranda playbook'iga.

    ```bash
    ansible-playbook verify.yml && ansible-lint verify.yml
    ssh mc01 sudo systemctl stop memcached
    ansible-playbook verify.yml | grep -E 'failed:|fatal|Memcached'
    ansible-playbook site.yml --limit cache && ansible-playbook verify.yml | tail -6
    ```

Lühike parool peatas play `assert`-is ja `changed=0` näitab, et ühtki muudatust ei tehtud. Just see on sisendi kontrolli mõte: viga enne muutust, mitte poole peal. Peatatud Memcached nurjas verify Memcached'i pordi juures app01-st, mitte mc01-s endas. Nii näed rikke koha ja selle mõju korraga. `status_code: [200, 503]` laseb `uri`-l vastuse vastu võtta ka siis, kui rakendus ütleb "osaliselt maas", ja `assert` ütleb siis, milline teenus.

✅ **Edasi saad minna, kui** lühike parool peatab play `assert`-is enne ühtki muudatust, peatatud memcached nurjab verify Memcached'i pordi juures ja pärast `site.yml --limit cache` on verify roheline.

## Commit

Commit'id lint-parandused, `check_mode` read, poliitikakontrolli ja `verify.yml`-i. Viimane kontroll käivitab automaatse hindaja lint'i repo juurest, samamoodi nagu pipeline seda teeb.

```bash
cd ~/labori-seis
git add -A k02-ansible
git commit -m "K2.5 lint, check_mode, failed_when, verify.yml (closes #N)" && git push
```

`OK` repo juurest tähendab, et lint töötab ilma sinu kohaliku seadistuseta.

✅ **Edasi saad minna, kui** `bash autograde/check.sh k02 lint` repo juurest annab `OK`.

📎 **Selle mooduli tõend:** commit `K2.5`; README-s Galaxy rolli võrdlus, `check_mode: false` ülesannete loetelu, drift'i kaks vastust, check-diff'i tähelepanek ja `failed_when` vastused; roheline `verify.yml`.

## Miks see nii töötab

**Check-režiimi tugi.** Mooduli dokumentatsiooni osa „Attributes" ütleb, kas moodul toetab check-režiimi: `full`, `partial` või `none`.

**AI ja vananenud kuju.** AI kirjutab playbook'i kiiresti, aga sageli vananenud kujul: `community.mysql`, `yes`, `ansible_distribution == "CentOS"`, taaskäivitus eraldi ülesandena. Lint leiab vormivead, teine käivitus loogikavead.

**Drift'i allikad.** Ansible'i hallatud hostis tekib drift käsitsi parandustest, pakettide uuendustest (`.rpmnew`/`.dpkg-dist` uue vaikekonfiga) ja teistest tööriistadest, mis kirjutavad samu faile: cloud-init, NetworkManager, `unattended-upgrades`. Viimased kaks ei ilmu `git log`-i ega muudatuste registrisse.

**`--check --diff` drift'i leidjana.** `--check --diff` on lihtsaim viis drift'i leida: see näitab, mida Ansible muudaks, kui praegu käivituks.

**Öine check.** Tootmises käivitatakse check sageli öösel ja tulemus saadetakse monitooringusse: punane, kui mõnel hostil on `changed` üle nulli. Nii leitakse drift enne, kui see teenuse taaskäivitusel esile tuleb.

**`fetch` drift'i uurimisel.** `--check --diff` ütleb, et fail erineb, `fetch` toob faili, et saaksid otsustada, kas käsitsi muudatus oli parandus, mis tuleb koodi tõsta, või viga, mis tuleb üle kirjutada. Sama mustriga kogud intsidendi ajal kõigilt hostidelt konfiguratsioonifailid kokku ja võrdled neid `diff`-iga.

**Vault ja `git diff`.** `ansible-vault edit` krüpteerib kogu faili uue soolaga uuesti, nii et `git diff` näitab kogu krüpteeritud sisu muutununa ka siis, kui muutsid ühte väärtust. Giti `textconv` mehhanism dekrüpteerib faili enne võrdlemist ja töötab iga binaarse või kodeeritud failiga. Vaulti puhul on see kasulik ka intsidendis: näed, millal ja millises commit'is parool muutus, ilma et peaksid vanu versioone käsitsi välja võtma ja dekrüpteerima.

**Molecule ja pipeline.** Molecule'i väärtus tuleb pipeline'is. Kui iga rolli muudatus käivitab automaatselt testi kahel distributsioonil, leitakse distributsioonipõhine viga enne merge'i ja labori stack ei ole enam ainus testkeskkond.

**Vastus või viga.** Kõik nullist erinevad väljumiskoodid pole vead. `firewall-cmd --query-service` annab koodi 1, kui teenust pole lubatud: see on vastus „ei". `failed_when` ja `changed_when` ütlevad Ansible'ile, mida tulemus tähendab, `ignore_errors` aga ainult peidab vea.

Kui jõudsid kiiremini: [Lisaülesanded → 9. Drift'i öine kontroll](lisa.md#9-drifti-oine-kontroll), teed timer'i, mis käivitab öösel `--check`-i ja saadab drift'i hostid Labori seisu. SELinuxi poliitikast edasi: [17. SELinux praktikas](lisa.md#17-selinux-praktikas-oma-veebijuur-ja-port) lahendab AVC keelud ilma SELinuxit välja lülitamata, [18. Semaphore](lisa.md#18-ansible-teenusena-semaphore) viib öise check'i meeskonna ajakavasse.
