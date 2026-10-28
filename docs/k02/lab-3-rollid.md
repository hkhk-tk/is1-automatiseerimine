---
tags:
  - Ansible
  - rollid
  - muutujad
---

# 3. Rollid ja muutujad

Teine meeskond kopeerib sinu playbook'i, Ubuntul see ei tööta ja kahe kuu pärast on kaks lahknevat koopiat; samal ajal on app01-l teine mälu kui failis ja keegi ei tea, kust see tuli. `db.yml` töötab ainult Rockyl ja iga uus teenus teeks faili pikemaks. Nüüd jagad koodi rollideks, millest igaüks teeb ühte asja, võtab sisendi muutujatest ja töötab mõlemal distrol, ning tõestad käskudega, milline väärtus võidab. Rollideks jagamine ei tohi masinates midagi muuta ja teine jooks näitab, kas muutis.

Lõpuks on stackis rollid `common`, `mariadb` ja `memcached`, valvekasutajad ja esimene custom fact.

**Kui teed seda tööl iga päev:** `site.yml` rollidega `common`, `mariadb` ja `memcached` annab teisel jooksul viiel hostil `changed=0` ja `ansible-inventory --host app01` näitab `tomcat_heap: 512m` failist `host_vars/app01.yml`; prioriteedi tabeli README-sse kirjutad ilma katseta. Kui see on sul juba korras, mine otse etappi [„Valvekasutajad, sudoers ja custom fact“](#valvekasutajad-sudoers-ja-custom-fact).

## Rollide kaustad ja site.yml

Lood kuue rolli kaustad, tõstad `db.yml`-i sisu rolli `mariadb` ja lisad rolli `common`, mis käivitub igal hostil. Playbook'ist saab `site.yml`: lühike fail, mis ütleb ainult, milline roll millisele grupile käib.

Ümberkorraldus, mis muudab masinates midagi, on peidetud muudatus. Kui see juhtub tootmises, taaskäivitub teenus ilma, et keegi oleks seda plaaninud, ja seda on raske hiljem seostada "ainult koodi korrastamisega".

1. Loo kuue rolli kaustastruktuur ja kustuta failid, mida vaja pole (`meta/` on Galaxy'sse avaldamiseks ja lint nõuaks selle täitmist).

    ```bash
    for r in common mariadb memcached rabbitmq tomcat nginx; do
        ansible-galaxy role init --init-path roles "$r"
    done
    rm -rf roles/*/tests roles/*/meta roles/*/README.md roles/*/vars/main.yml
    ```

2. Tõsta `db.yml`-i ülesanded `roles/mariadb/tasks/main.yml`-i ja nimeta playbook ümber: `git mv db.yml site.yml`. Play'sse jääb `hosts: db` ja `roles: [mariadb]`. Skeemi tee on nüüd `{{ playbook_dir }}/../db/…`, sest rollis otsiks `copy` faili rolli `files/` kaustast.
3. Lisa `site.yml`-i esimeseks play `hosts: all` rolliga `common`. Nõuded rollile:
    - `cloud-init status --wait` (`changed_when: false`, `failed_when` lubab koodid 0 ja 2)
    - `ansible.builtin.blockinfile` paneb kõik hostid (`groups['all']`, IP `hostvars[h]['ansible_host']`) faili `/etc/hosts` ja cloud-initi mallidesse `/etc/cloud/templates/hosts.*.tmpl`, nagu Bashi `etc-hosts.sh`
    - Ubuntul apt vahemälu (`cache_valid_time`), Rocky hostidel firewalld paigaldatud ja käimas, kui `labseis_firewalld` on tõene
    - `/etc/motd` (`copy`, `content: "Labori seis ({{ ansible_facts['distribution'] }}): hallatud Ansible'iga, käsitsi ära muuda\n"`, `0644`): eelmise korra ad-hoc muudatus jõuab nüüd Giti
4. Käivita kaks korda.

    ```bash
    ansible-playbook site.yml --syntax-check
    ansible-playbook site.yml
    ansible-playbook site.yml | tail -7
    ```

Esimesel jooksul muutis ainult `common`, sest see on uus. MariaDB osa jäi `ok`-ks, mis tõestab, et ülesannete tõstmine rolli ei muutnud nende tähendust. Kui MariaDB ülesanne oleks `changed`, oleks tõstmisel midagi muutunud: tavaliselt faili tee, mõni parameeter või ülesannete järjekord. Teine jooks `changed=0` viiel hostil on uus lähtepunkt, millega võrdled iga järgmist muudatust.

✅ **Edasi saad minna, kui** esimesel jooksul on `changed` ainult rolli `common` ülesanded, MariaDB osa on `ok` nagu `db.yml`-iga ja teine jooks annab viiel hostil `changed=0`.

## Hallatud plokk ja käsitsi rida

Kontrollid, kuidas `blockinfile` käitub, kui keegi muudab sama faili käsitsi. Lisad web01 `/etc/hosts`-i oma rea väljapoole plokki ja rikud ühe rea ploki sees.

Paljud failid on jagatud: osa haldab Ansible, osa keegi teine (pakett, cloud-init, kolleeg). Kui moodul kirjutaks kogu faili üle, kaoks teiste osa vaikselt. Kui ta ei parandaks oma osa, jääks vale nimi kehtima.

1. Tee web01-s kaks käsitsi muudatust ja vaata plaani.

    ```bash
    ssh web01 "echo '10.10.1.99 varu01' | sudo tee -a /etc/hosts"
    ssh web01 "sudo sed -i '/^# BEGIN labori-seis/,/^# END labori-seis/ s/ db01$/ db01-vana/' /etc/hosts"
    ansible-playbook site.yml --limit web01 --check --diff | grep -E '^[-+][0-9]'
    ```

2. Käivita playbook ja vaata faili.

    ```bash
    ansible-playbook site.yml --limit web01 | tail -3
    ssh web01 'grep -nE "varu01|labori-seis|db01" /etc/hosts'
    ssh web01 "sudo sed -i '/varu01/d' /etc/hosts"
    ```

3. Kirjuta README-sse, mille järgi `blockinfile` teab, mis on tema osa, ja mis juhtuks, kui keegi kustutaks markeri rea.

Diff näitas ainult `db01` rida, mitte `varu01` rida. Ansible võrdleb ainult markerite `# BEGIN labori-seis` ja `# END labori-seis` vahelist osa ja jätab ülejäänud faili rahule. Pärast jooksu oli `db01` jälle õige ja `varu01` alles. Kui marker kaob, ei leia moodul oma plokki ja lisab faili lõppu uue: siis on failis kaks plokki ja vana jääb parandamata. Sama näed juba praegu: Bashi `etc-hosts.sh` plokil on teine marker (`# labori-seis BEGIN`) ja see on failis Ansible'i ploki kõrval alles. Üleminekul skriptidelt Ansible'ile jääb sellist pärandit sageli maha ja selle koristamine on eraldi otsus.

✅ **Edasi saad minna, kui** `--check --diff` näitab ainult `db01-vana` → `db01` muudatust, pärast jooksu on `varu01` rida alles ja `db01` õige, koristuse järel on `varu01` kadunud ja README-s on kaks vastust.

## Muutujad oma tasemele

Nimed ja paroolid on praegu ülesannetes. Viid iga väärtuse sinna, kus see kehtib: kõigi ühine `group_vars/all`-i, OS-i erinevus OS-grupi faili, ühe hosti erand `host_vars`-i ja rolli enda mõistlik vaikeväärtus rolli `defaults/`-i. Distrode erinevad teed ja paketinimed lähevad rolli `vars/` faili.

Väärtus, mis on ülesandes, tuleb muuta igas kohas, kus seda kasutatakse. Kui unustad ühe koha, on rakendusel ja andmebaasil eri parool ja viga ilmub alles rakenduse logis.

- `group_vars/all/main.yml`: `labseis_db_name`, `labseis_db_user`, `labseis_mq_user`, `labseis_version: v1.1.0` ja saladuste vahekiht `labseis_db_password: "{{ vault_db_password }}"` (samamoodi `labseis_mq_password`, `labseis_teacher_token`); rollid kasutavad ainult `labseis_*` nimesid
- `group_vars/rocky.yml`: `labseis_firewalld: true`, `group_vars/ubuntu.yml`: `labseis_firewalld: false`, `host_vars/app01.yml`: `tomcat_heap: 512m`
- `roles/mariadb/defaults/main.yml`: `mariadb_bind_address` faktist `ansible_facts['default_ipv4']['address']`, `mariadb_app_host: "%"`, `mariadb_sql_dir`; `roles/tomcat/defaults/main.yml`: `tomcat_heap: 384m`
- `roles/mariadb/vars/Debian.yml` ja `RedHat.yml`: paketid, socket, konfifaili kaust; rolli esimene ülesanne `include_vars: "{{ ansible_facts['os_family'] }}.yml"`

```bash
ansible-inventory --host app01
ansible app01 -m ansible.builtin.debug -a var=tomcat_heap
ansible db01 -m ansible.builtin.debug -a 'msg={{ labseis_db_password | length }}'
ansible-playbook site.yml | tail -7
git add -A . && git commit -m "K2.3 muutujad oma tasemel"
```

> Ad-hoc `debug` näeb inventory muutujaid ja Vaulti, aga mitte rolli `defaults/`-i: rolli seal pole. `mariadb_bind_address` ad-hoc käsus on `VARIABLE IS NOT DEFINED!`.

Parooli pikkus tuli vahekihi kaudu Vaultist. See tähendab, et rollid ei tea, kust parool tuleb, ja hiljem saab Ansible Vaulti asendada HashiCorp Vaultiga ilma rolle muutmata. Ainus `changed` oli bind-aadress, sest vaikeväärtus on nüüd VM-i IP, mitte `0.0.0.0`. See muudatus on oodatud ja õige: MariaDB ei kuula enam kõigil liidestel. Iga teine `changed` oleks märk, et mõni väärtus muutus tõstmisel.

✅ **Edasi saad minna, kui** `tomcat_heap` on `512m`, parooli pikkus tuleb Vaultist läbi vahekihi (parooli ennast ära väljasta: see jõuaks ka `ansible.log`-i) ja `site.yml` annab `changed=0` peale bind-aadressi muudatuse, mis nüüd on VM-i IP.

## Muutujate prioriteet praktikas

Ära jäta prioriteeti uskumiseks. Paned sama muutuja mitmele tasemele ja vaatad, kumb võidab. Iga sammu järel küsid tulemust käsuga `ansible-inventory --host app01 | grep heap`.

Prioriteedi viga on intsidendis kõige kavalam: kõik failid näevad õiged välja, aga hostil kehtib teine väärtus. Ainus kiire tee põhjuseni on teada järjekorda ja osata seda käsuga kontrollida.

1. Lisa ajutiselt `group_vars/ubuntu.yml`-i `tomcat_heap: 448m` ja uude faili `group_vars/app.yml` `tomcat_heap: 480m`. Tulemus on ikka `512m`: host võidab grupi.
2. Kommenteeri `host_vars/app01.yml` rida välja. Tulemus on `480m`: lapsgrupp `app` võidab vanemgrupi `ubuntu`.
3. Kustuta `group_vars/app.yml`. Tulemus on `448m`. Taasta siis algseis.

    ```bash
    rm group_vars/app.yml
    git checkout group_vars/ubuntu.yml host_vars/app01.yml
    git status --short group_vars host_vars
    ```

4. Kõrgemad tasemed: loo `scratch/prio.yml` (play `hosts: app`, `gather_facts: false`, `vars: {tomcat_heap: 256m}`, üks `debug`) ja käivita see ilma ja koos `-e`-ga.

    ```bash
    ansible-playbook scratch/prio.yml
    ansible-playbook scratch/prio.yml -e tomcat_heap=768m
    ```

5. Kirjuta README-sse tabel: tase, väärtus, miks võitis (kuus rida rolli vaikeväärtusest `-e`-ni). Rolli vaikeväärtust `384m` näed Tomcati unit-failis, kui `host_vars` rida puudub.

Tabeli loogika on lihtne: mida lähemal käivitusele ja mida kitsamale hulgale väärtus kehtib, seda kõrgem ta on. Rolli vaikeväärtus on kõige nõrgem, sest see on ainult soovitus. `-e` on kõige tugevam, sest selle andis inimene või pipeline just selle jooksu jaoks. `-e`-d tasub kasutada ainult ühekordseks erandiks: muutuja, mis tuleb igal jooksul `-e`-ga, kuulub faili.

✅ **Edasi saad minna, kui** README tabelis on kuus taset õiges järjekorras, `scratch/prio.yml` näitab `256m` ja `-e`-ga `768m` ning `git status` ei näita `group_vars`-is ega `host_vars`-is muudatusi.

## Faktid, register ja tingimused

Kogud faktid kõigilt hostidelt, salvestad käsu tulemuse `register`-iga ja kirjutad tingimuse, mis vaatab kahte asja korraga. Need on kolm tööriista, millega rollid otsustavad, mida teha.

Tingimus, mis on vale, ei ebaõnnestu. See jääb lihtsalt vahele ja ülesanne, mida pidid tegema, jääb tegemata. Seepärast pead tingimust testima ka juhul, kui see peab vahele jääma.

1. Loo `scratch/facts.yml` (`hosts: all`), mis väljastab iga hosti kohta `distribution`, `memtotal_mb`, `memory_mb.real.free`, `processor[2]` ja `date_time.date`, ning ülesande `ansible.builtin.command: df -h /` (`register: disk`, `changed_when: false`) `stdout_lines` ja `rc`.
2. Lisa play'le `gather_facts: false`, käivita, loe viga ja eemalda rida.
3. Lisa ülesanne, mis käivitub ainult Rocky hostidel, kus on alla 2000 MB mälu. `when:` on list kahe tingimusega ja mälu läheb arvuks `| int`-iga.

    ```bash
    ansible-playbook scratch/facts.yml
    ansible-playbook scratch/facts.yml --limit db01 -v | grep -A3 'df -h'
    ```

4. Kirjuta README-sse, miks `ansible_facts['distribution'] == "CentOS"` jääb Rockyl vaikselt vahele ja mis on `'10' > '8'` väärtus ilma `| int`-ita.

Faktid kogub moodul `setup`, mis käivitub play alguses igas hostis ja loeb `/etc/os-release`-i, `/proc`-i, `/sys`-i ja võrguliideseid. Tulemus on mälus kuni jooksu lõpuni, kui faktide vahemälu pole seadistatud. `gather_facts: false` säästab hosti kohta sekundi-paar, aga siis on faktide sõnastik tühi. Kahe tingimusega list tähendab "ja": mõlemad peavad olema tõesed. Kui ülesanne jäi Ubuntul vahele ja Rockyl käivitus, töötab tingimus mõlemas suunas. Stringide võrdlus käib tähthaaval ja seepärast on `'10'` väiksem kui `'8'`.

✅ **Edasi saad minna, kui** näed viie hosti distrot, mälu ja ketast, `gather_facts: false` annab `'ansible_facts' is undefined` või puuduva atribuudi vea ja kahe tingimusega ülesanne on Ubuntul `skipping`.

## Memcached roll

Kirjutad teise teenuse rolli sama mustriga nagu MariaDB: pakett, konfifail, teenus. Uus on see, et konfifail on distrodel eri kohas ja eri kujul, ja et muudatus konfis peab teenuse taaskäivitama. Selle jaoks on handler.

Ilma handlerita kirjutab Ansible konfifaili ja teenus kuulab vana seadistusega edasi. Jooks on roheline, aga muudatus jõuab teenusesse alles järgmisel reboot'il, ja siis ei mäleta keegi, miks käitumine muutus.

Kirjuta roll `memcached` ja play `hosts: cache`:

- `defaults/main.yml`: `memcached_listen` faktist `ansible_facts['default_ipv4']['address']` ja `memcached_port: 11211` (nimed täpselt need)
- `vars/Debian.yml` ja `vars/RedHat.yml`: konfifail, regexp ja rida (Ubuntu `/etc/memcached.conf` rida `-l …`, Rocky `/etc/sysconfig/memcached` rida `OPTIONS="-l …"`); muuda `ansible.builtin.lineinfile`-iga
- konfifaili muutus teavitab handlerit `Restart memcached` (`handlers/main.yml`), teenus käib ja käivitub bootil
- firewalld avab pordi ainult siis, kui firewalld käib, nagu MariaDB rollis

```bash
ansible-playbook site.yml --limit cache
ansible-playbook site.yml --limit cache | tail -3
ssh mc01 'sudo ss -tlnp | grep 11211'
ssh app01 'timeout 3 bash -c "</dev/tcp/mc01/11211" && echo avatud'
```

Lisa samal ajal MariaDB rollile handler `Restart mariadb` ja `notify` konfifailile, siis kuulab MariaDB pärast muutust uue aadressi peal.

`ss` näitab, millist aadressi teenus kuulab, mitte seda, mis konfis on. Kui need erinevad, pole teenus pärast muudatust taaskäivitunud. `avatud` app01-st tõestab, et tulemüür ja kuulamisaadress on koos õiged. MariaDB uus aadress `ss` väljundis on vastus küsimusele, mis jäi `db.yml`-i juures lahtiseks: õige lahendus oli handler, mitte eraldi restart, mis taaskäivitaks teenust igal jooksul.

✅ **Edasi saad minna, kui** `ss` näitab mc01 IP-d (mitte `127.0.0.1`), app01-st tuleb `avatud`, teine `--limit cache` jooks on `changed=0` ja `ssh db01 'sudo ss -tlnp | grep 3306'` näitab db01 IP-d.

## Valvekasutajad, sudoers ja custom fact

Roll `common` saab kaks asja, mida igal hostil vaja: valvekasutajad, kes tohivad lugeda logisid, aga root'iks ei saa, ja custom fact, mis ütleb hosti rolli. Sudoers'i fail on koht, kus üks trükiviga võtab `sudo` kõigilt ära, ka Ansible'ilt. Seepärast proovid siin meelega vigast rida.

Ansible'i `become` käib sama `sudo` kaudu. Vigase faili järel ei saa ka playbook seda parandada ja alles jääb konsool või snapshot.

1. `roles/common/defaults/main.yml`:

    ```yaml
    common_ops_group: labops
    common_ops_users:
      - {name: valve1, comment: "Labori valve 1"}
      - {name: valve2, comment: "Labori valve 2"}
    ```

2. Ülesanded rollis `common`, kõik `tags: [users]`-iga:
    - `ansible.builtin.group` loob grupi, `ansible.builtin.user` tsükliga üle `common_ops_users` (`groups`, `append: true`, `shell: /bin/bash`)
    - `ansible.builtin.copy` faili `/etc/sudoers.d/50-labops` sisuga `%labops ALL=(root) NOPASSWD: /usr/bin/journalctl`, `mode: "0440"`, `validate: /usr/sbin/visudo -cf %s`
3. Custom fact: kaust `/etc/ansible/facts.d` (`0755`) ja fail `labseis.fact` (`0644`, mitte käivitatav) INI-kujul: jaotis `[host]`, read `roll=` (funktsionaalne grupp, `group_names` ilma `ubuntu`, `rocky`, `webhosts`-ita) ja `hallatud=ansible`.
4. Proovi `validate`-i: kirjuta sudoers'i ritta `NOPASWD`, käivita, loe viga ja paranda.

    ```bash
    ansible-playbook site.yml --tags users --limit db01
    ssh db01 'sudo -l -U valve1; sudo -n true && echo sudo töötab'
    ansible all -m ansible.builtin.setup -a 'filter=ansible_local' -o
    ```

`failed to validate` ja samas töötav `sudo` tõestavad, et `validate` kontrollis ajutist faili enne paigaldamist ja vigane fail ei jõudnudki `/etc/sudoers.d/` alla. `sudo -l` näitab, mida valve1 tohib: ainult `journalctl`, mitte shelli. Custom fact on fail `/etc/ansible/facts.d/*.fact`: `setup` loeb INI- või JSON-faili ja paneb sisu `ansible_local` alla, käivitatava faili ta käivitab ja parsib selle stdout'i JSON-ina. `verify.yml` kasutab seda hiljem, et kontrollida, kas host on see, mida inventory arvab.

✅ **Edasi saad minna, kui** vigane rida annab `failed to validate` ja `sudo` töötab edasi, `sudo -l` näitab valve1-le ainult `journalctl`-i, `setup` näitab igal hostil `ansible_local` → `labseis` → `host` → `roll` ja teine `site.yml` jooks on `changed=0`.

## Commit

Commit'id kolm rolli ja muutujate failid.

```bash
cd ~/labori-seis
git add -A k02-ansible
git commit -m "K2.3 rollid common, mariadb, memcached; muutujad (closes #N)" && git push
git ls-files k02-ansible | grep -E 'scratch|vault_pass' || echo puhas
```

`puhas` tähendab, et `scratch/prio.yml`, `scratch/facts.yml` ja paroolifail jäid sinu masinasse. Kui `grep` leiab midagi, eemalda see `git rm --cached`-iga ja kontrolli `.gitignore`-i.

✅ **Edasi saad minna, kui** viimane käsk ütleb `puhas`.

📎 **Selle mooduli tõend:** commit `K2.3`; README-s `blockinfile` markeri vastus, prioriteedi tabel kuue tasemega, `CentOS` ja `'10' > '8'` vastused.

## Miks see nii töötab

**Faktid ja `/etc/os-release`.** Faktid `os_family` ja `distribution` tuletab Ansible uuematel distributsioonidel peamiselt failist `/etc/os-release` (väljad `ID` ja `ID_LIKE`). Bashi skriptid tegid sama käsitsi (`. /etc/os-release; case "$ID"`). Vanemates õpetustes on tingimus `ansible_distribution == "CentOS"`, mis jääb Rockyl vahele ilma veateateta.

**Faktide kuju.** Faktid kirjutame kujul `ansible_facts['os_family']`, mitte `ansible_os_family`. Vana kuju töötab, sest Ansible lisab faktid ka eraldi muutujatena (seade `INJECT_FACTS_AS_VARS`). Uuemad ansible-core'i versioonid hoiatavad selle kuju eest ja seade vaikeväärtus on muutumas; täpse versiooni leiad Ansible'i porting guide'ist.

**Custom fact'i võtmed.** Custom fact'i INI-failis muudetakse võtmed väiketähtedeks. Kui kirjutaksid rolli `common` faili `labseis.fact` ploki `[host]` alla `Roll=app`, oleks tulemus `ansible_facts['ansible_local']['labseis']['host']['roll']`. Suurtähtedega võtit otsiv tingimus ei leia siis midagi. JSON-kujul fact (nagu `deploy.fact`) jätab võtmed muutmata.

**Kasutaja grupid.** `ansible.builtin.user` koos `groups:` ja `append: true`-ga lisab grupi olemasolevatele. Ilma `append`-ita eemaldatakse kasutajalt kõik muud lisagrupid.

**`validate` mehhanism.** Moodul kirjutab uue sisu kõigepealt ajutisse faili sihtkausta kõrval, asendab `validate` käsus `%s` selle teega ja käivitab käsu. Ainult koodi `0` korral teeb ta atomaarse `rename`-i sihtfailiks. Ilma `%s`-ita keeldub Ansible käsku käivitamast. Sama mehhanism töötab `copy`, `template`, `lineinfile` ja `blockinfile` moodulitel.

**`defaults` ja `vars`.** Rolli `defaults` ja `vars` erinevad prioriteedi poolest. `defaults` on kõige madalama prioriteediga ja mõeldud väärtustele, mida kasutaja võib üle kirjutada: mälu, port, kuulamisaadress. `vars` on palju kõrgema prioriteediga ja mõeldud väärtustele, mis sõltuvad distributsioonist ja mida kasutaja muutma ei peaks: paketinimed, socket'i tee, konfiguratsioonifaili kaust.

**Vale tase.** Kui paned paketinime `defaults`-i, võib keegi selle kogemata `group_vars`-is üle kirjutada. Kui paned mälu `vars`-i, ei saa seda enam `host_vars`-is muuta.

**`blockinfile` marker.** Vaikemarker on `# {mark} ANSIBLE MANAGED BLOCK`. Kui kaks ülesannet (või kaks rolli) kasutavad samas failis sama markerit, kirjutavad nad teineteise ploki igal jooksul üle ja kumbki pole kunagi `changed=0`. Seepärast on igal plokil oma `marker`.

**Cloud-init ja `/etc/hosts`.** Proxmoxi user-data sisaldab `manage_etc_hosts: true` ja cloud-init kirjutab faili `/etc/hosts` igal käivitusel mallist `/etc/cloud/templates/hosts.*.tmpl` uuesti. Seepärast paneb roll `common` ploki ka mallidesse. Nginx ja rakendus kasutavad sellegipoolest IP-aadresse, et nende töö ei sõltuks nimelahendusest.

**Nurksulud ja punkt.** Muutuja elemendi saad kätte indeksiga, võtme punktiga või nurksulgudes. Punkt-kuju ei tööta, kui võti on sama mis Pythoni meetodi nimi (`items`, `keys`) või sisaldab sidekriipsu, nurksulud töötavad iga võtmenimega. Seepärast kasutavad selle kursuse rollid nurksulge. Kirjapilt on veidi pikem, aga see ei murdu võtme nime tõttu ja on sama kujuga, mida näed `setup` väljundis.

**Ubuntu ja Rocky erinevused.** Rollidesse jõuavad need erinevused: Ubuntul käivitub teenus pärast paigaldust ise, Rockyl mitte; Memcached'i seadistus on Ubuntul `/etc/memcached.conf`, Rockyl `/etc/sysconfig/memcached`; MariaDB lisaseadistus on Ubuntul `/etc/mysql/mariadb.conf.d/`, Rockyl `/etc/my.cnf.d/`; PyMySQL-i pakett on Ubuntul `python3-pymysql`, Rockyl `python3-PyMySQL`; tulemüür ja MAC on Ubuntul ufw (väljas) ja AppArmor, Rockyl firewalld ja SELinux. Seepärast paneb roll teenuse alati selgelt käima ja võtab teed ning paketinimed `vars/` failist.

**Äsja kirjutatud fact.** Custom fact, mille play ise kirjutas, ilmub muutujatesse alles pärast uut faktide kogumist. Sama play's on vaja ülesannet `ansible.builtin.setup` parameetriga `filter: ansible_local`.

Kui jõudsid kiiremini: [Lisaülesanded → 2. Play muutujad, list ja sõnastik](lisa.md#2-play-muutujad-list-ja-sonastik), harjutad listi elemendi, sõnastiku võtme ja faktide poole pöördumist kolmel kirjaviisil. Sama rolli `common` sshd hardening ilma end välja lukustamata on [16. SSH hardening](lisa.md#16-ssh-hardening-ilma-end-valja-lukustamata).
