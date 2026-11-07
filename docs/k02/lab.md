---
tags:
  - Ansible
  - Praktikum
---

# Praktikum: Labori seis rollidega

1. kohtumisel kirjutasid playbook'e, kus kõik oli ühes failis: masin, väärtused ja failide sisu. Täna saad viie teenusega playbook'i `labseis.yml`, parandad selle vead ja võtad sellest sammhaaval kõik välja: masinad inventory'sse, väärtused muutujatesse, tekstid mallidesse, paroolid Vaulti ja lõpuks iga teenuse rolli.

**Edenemine:** laboritahvel <http://is126.kaaren.lab.hkhk.lan> (VPN-iga).

Küsimused: [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions). Kirjuta käsk ja kogu veateade tekstina. Enne saatmist eemalda paroolid ja tokenid.

??? abstract "Õpiväljundid"

    1. Leiad playbook'i vea sammudega sümptom, hüpotees, tõend, parandus ja korduskontroll.
    2. Asendad playbook'is masinanimed inventory gruppidega ja väärtused muutujatega ning valid muutujale taseme.
    3. Tõstad konfiguratsiooniteksti malli ja paroolid Vaulti.
    4. Koondad ühe teenuse ülesanded, malli, handler'i ja vaikeväärtused rolliks.
    5. Tõestad iga sammu järel `--check --diff`, korduva käivituse ja `/health`-iga, et süsteem töötab samamoodi.


## Osa 1 · Algne playbook

### 1.1 Haru ja failid

Alates 2. kohtumisest teed iga kohtumise töö eraldi harus ja ühendad selle päeva lõpus pull request'iga harusse `main`. Käsk `git pull` toob repositooriumi uued failid, ka `labseis.yml`-i.

```bash
cd ~/kursus
git switch main
git pull
git switch -c k02-ansible
cd k02-ansible
cp ../k01/ansible.cfg ../k01/inventory.ini .
ls
```

??? success "Oodatav tulemus"

    Kaustas on `ansible.cfg`, `inventory.ini`, `labseis.yml` ja `requirements.yml`. Kõik selle kohtumise käsud käivitad kaustas `~/kursus/k02-ansible`.

??? warning "Kui `labseis.yml` puudub"

    Laadi mõlemad failid starterist (käivita kaustas `~/kursus/k02-ansible`):

    ```bash
    curl -fsSLO https://raw.githubusercontent.com/hkhk-tk/is1-starter/main/k02-ansible/labseis.yml
    curl -fsSLO https://raw.githubusercontent.com/hkhk-tk/is1-starter/main/k02-ansible/requirements.yml
    ```

### 1.2 Kogud

Andmebaasi ja RabbitMQ kasutajate moodulid ei ole `ansible-core`'is, vaid eraldi **kogudes** (collections). Fail `requirements.yml` loetleb vajalikud kogud koos versioonidega, et kõigil oleks sama komplekt.

```bash
cat requirements.yml
ansible-galaxy collection install -r requirements.yml
ansible-doc community.mysql.mysql_user | head -20
```

??? success "Oodatav tulemus"

    Kolm kogu on paigaldatud kausta `~/.ansible/collections`. `ansible-doc` näitab mooduli kirjeldust ja parameetreid.

??? warning "Kui moodulit ei leita"

    Viga `couldn't resolve module/action 'community.mysql.mysql_db'` tähendab, et kogu pole paigaldatud või paigaldati teise kasutajana. Käivita kogude paigaldus uuesti ilma `sudo`-ta ja kontrolli:

    ```bash
    ansible-galaxy collection list | grep -E "community.mysql|community.rabbitmq|ansible.posix"
    ```

### 1.3 Mis juhtub, kui avad Labori seisu

Brauser ei pöördu otse rakenduse poole. Päringu võtab vastu Nginx web01-s ja edastab selle app01-le, kus Tomcatis töötab rakendus. Kasutaja pöördub ainult Nginxi pordi 80 poole ja rakendusserverit saab vahetada, ilma et kasutaja aadress muutuks. Rakendus hoiab andmeid MariaDB-s (db01), sageli küsitud vastuseid Memcachedis (mc01) ja saadab sõnumeid RabbitMQ kaudu (rmq01).

<figure markdown="span">
  ![Labori topoloogia: control haldab SSH kaudu viit masinat; brauser → web01 Nginx → app01 Tomcat → db01 MariaDB, mc01 Memcached, rmq01 RabbitMQ](assets/k02_topoloogia.svg){ width="860" }
  <figcaption>Joonis 2.1. Labori topoloogia: rakenduse liiklus (lilla) ja Ansible'i haldusühendused (oranž) (Talvik, 2026).</figcaption>
</figure>

Kirjuta tabelisse oma masinate IP-aadressid. Need on Proxmoxis masina lehel **Summary → IPs**. Sama tabeli järgi täidad 3. osas `inventory.ini`.

??? note "Tabel 1.1. Masinad, rollid ja aadressid"

    | Masin | Proxmoxi nimi | Distributsioon | Grupid | Port | Roll | IP-aadress |
    |---|---|---|---|---|---|---|
    | control | `Automatiseerimine-IS126-<Perenimi>-Control` | Ubuntu 24.04 | – | – | Ansible ja Git | |
    | web01 | `…-Web01` | Ubuntu 24.04 | `web`, `ubuntu` | 80 | `nginx` | |
    | app01 | `…-App01` | Ubuntu 24.04 | `app`, `ubuntu` | 8080 | `tomcat` | |
    | rmq01 | `…-Rmq01` | Ubuntu 24.04 | `queue`, `ubuntu` | 5672 | `rabbitmq` | |
    | mc01 | `…-Mc01` | AlmaLinux 9 | `cache`, `alma` | 11211 | `memcached` | |
    | db01 | `…-Db01` | AlmaLinux 9 | `db`, `alma` | 3306 | `mariadb` | |

    Kõik viis masinat on rollis `common`. AlmaLinuxi masinates töötab tulemüür `firewalld`, seepärast avatakse seal teenuse port.

Aadress `/health` näitab rakenduse ja iga sõltuvuse olekut eraldi. Kui üks sõltuvus ei tööta, vastab rakendus ikka, aga vastav väli on `DOWN`. Siis on päring jõudnud Nginxi kaudu rakenduseni ja viga on rakenduse ja selle sõltuvuse vahel.

### 1.4 Esimene käivitus

**Küsimus enne käsku:** kas Labori seis töötab pärast esimest käivitust?

```bash
ansible-playbook labseis.yml
ssh web01 curl -s localhost/health
```

??? success "Oodatav tulemus"

    Playbook lõpeb ilma vigadeta, kõigis masinates on `failed=0`. Rakendus vastab, aga üks osa ei tööta: `{"status":"UP","db":"UP","queue":"UP","cache":"DOWN"}`. Esimene käivitus võtab umbes 5–8 minutit.

??? warning "Kui app01 ülesanne „Rakendus vastab“ ebaõnnestub"

    Rakendus ei käivitunud. Vaata logi: `ssh app01 sudo journalctl -u tomcat10 -n 40 --no-pager`. Kui seal on `ACCESS_REFUSED`, on RabbitMQ kasutajal teine parool kui rakenduse seadetes.

### 1.5 Mida failis näed

Loe `labseis.yml` läbi ja leia kuus asja, mis täna failist välja lähevad: masinanimed, korduvad väärtused, paroolid, konfiguratsioonifailide tekst, teenuste taaskäivitused ja distributsioonist sõltuvad erinevused.

??? tip "Kust need leiad"

    ```bash
    grep -n "hosts:" labseis.yml
    grep -n -E "512m|app01:8080|labseis$|name: labseis" labseis.yml
    grep -n "2026" labseis.yml
    grep -n "content: |" labseis.yml
    grep -n -E "restart|notify" labseis.yml
    grep -n "when:" labseis.yml
    ```

    Masinanimed on iga play päises. Väärtus `labseis` on andmebaasi nimes, kasutajas ja rakenduse seadetes. Paroole on kolmes kohas. Konfiguratsioonitekste on viis. `when` jagab MariaDB paigalduse kaheks.

??? question "Sinu töö"

    Milline väärtus on sinu serverites praegu kirjutatud otse konfiguratsioonifaili või skripti sisse? Mitmest kohast peaksid seda muutma?

## Osa 2 · Leia ja paranda vead

Iga viga leiad samade sammudega: **Sümptom** (mida näed), **Hüpotees** (mis võib olla põhjus), **Tõend** (käsk, mis hüpoteesi kinnitab või lükkab ümber), **Paranda** ja **Kontrolli**. Kirjuta iga vea hüpotees enne tõendi otsimist oma K2 issue kommentaariks.

### 2.1 Viga 1: vahemälu ei vasta

**Sümptom:** `/health` näitab `"cache":"DOWN"`. Rakendus app01-s ei saa ühendust Memcachedi serveriga mc01-s.

**Hüpotees:** kirjuta issue'sse, mis võib ühenduse takistada. Mõtle kolmele kohale: kas teenus töötab, kas see kuulab võrgus ja kas midagi on teel ees.

??? tip "Tõend"

    Kontrolli kõiki kolme kohta:

    ```bash
    ssh mc01 systemctl is-active memcached
    ssh mc01 sudo ss -tlnp | grep 11211
    ssh mc01 sudo firewall-cmd --list-ports
    ssh app01 "timeout 3 bash -c '</dev/tcp/mc01/11211' && echo avatud || echo suletud"
    ```

    Teenus töötab ja kuulab aadressil `0.0.0.0:11211`, aga tulemüüris on avatud port `11221/tcp` ja app01-st on port suletud.

??? example "Paranda"

    Ülesandes `Tulemüür lubab vahemälu pordi` on pordi number vale. Paranda see:

    ```yaml
          port: 11211/tcp
    ```

    Vale port jääb tulemüüris avatuks. Sulge see üks kord ad-hoc käsuga:

    ```bash
    ansible mc01 -b -m ansible.posix.firewalld -a "port=11221/tcp permanent=true immediate=true state=disabled"
    ```

**Kontrolli:**

```bash
ansible-playbook labseis.yml
ssh web01 curl -s localhost/health
```

??? success "Oodatav tulemus"

    `{"status":"UP","db":"UP","queue":"UP","cache":"UP"}`. Rakendus loob vahemäluühenduse uuesti, vajadusel oota minut.

### 2.2 Viga 2: teine käivitus muudab masinaid

**Sümptom:** midagi ei ole muutunud, aga playbook teatab muudatustest.

**Küsimus enne käsku:** mitu ülesannet on teisel käivitusel `changed`?

```bash
ansible-playbook labseis.yml
```

??? success "Oodatav tulemus"

    Kõigis viies masinas on `changed=1` või rohkem. Väljundis on `changed` kahes ülesandes: `Masinad tunnevad üksteist nime järgi` (iga masina kohta) ja app01-s `Tomcat taaskäivitatakse, et seaded rakenduksid`.

**Hüpotees:** kirjuta issue'sse, miks need kaks ülesannet muudavad masinat igal käivitusel.

??? tip "Tõend"

    ```bash
    ssh app01 grep -c db01 /etc/hosts
    ansible-playbook labseis.yml
    ssh app01 grep -c db01 /etc/hosts
    ssh app01 systemctl show tomcat10 -p ActiveEnterTimestamp
    ```

    Iga käivitus lisab faili `/etc/hosts` viis rida juurde ja Tomcat on käivitatud mõni minut tagasi. `shell` ja `command` käivitavad käsu iga kord, sest need moodulid ei tea soovitud olekut. Tomcati taaskäivitus katkestab rakenduse ka siis, kui seaded ei muutunud.

??? example "Paranda: `/etc/hosts`"

    Moodul [`ansible.builtin.blockinfile`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/blockinfile_module.html) haldab failis ühte märgistatud plokki ja kirjutab selle ainult siis, kui sisu erineb. Asenda esimese play ülesanne:

    ```yaml
        - name: Masinad tunnevad üksteist nime järgi
          ansible.builtin.blockinfile:
            path: /etc/hosts
            marker: "# {mark} labori-seis"
            block: |
              {% for h in groups['all'] | sort %}
              {{ hostvars[h].ansible_default_ipv4.address }} {{ h }}
              {% endfor %}
    ```

    Filter `sort` hoiab järjekorra samana. Varasemad käivitused jätsid faili palju ridu. Eemalda need üks kord ad-hoc käsuga, enne kui playbook'i uuesti käivitad:

    ```bash
    ansible all -b -m ansible.builtin.lineinfile -a "path=/etc/hosts regexp='^\S+ (web01|app01|rmq01|mc01|db01)$' state=absent"
    ```

Failis on handler'id juba olemas: MariaDB, Memcachedi ja Nginxi seadete ülesanded teavitavad neid võtmega `notify` ja handler käivitub play lõpus ainult siis, kui fail muutus. Tomcati play's handler'it pole, taaskäivitus on tavaline ülesanne ja käivitub iga kord. Paranduses saavad Tomcati kaks seadete ülesannet sama mustri.

**Küsimus enne käsku:** play viimane ülesanne kontrollib, et rakendus vastab. Kas see kontroll peab toimuma enne või pärast Tomcati taaskäivitust? Mis juhtub, kui handler käivitub alles play lõpus?

??? example "Paranda: Tomcati taaskäivitus"

    Tomcat tuleb taaskäivitada ainult siis, kui seadete fail muutus. Selleks on **handler**: ülesanne, mis käivitub play lõpus ainult siis, kui mõni ülesanne teatas sellest võtmega `notify` ja tegi muudatuse. Kustuta ülesanne `Tomcat taaskäivitatakse, et seaded rakenduksid`. Lisa kahele seadete ülesandele (`Rakenduse seaded on failis` ja `Tomcat loeb rakenduse seaded ja kasutab Java 21`) rida:

    ```yaml
          notify: Restart tomcat
    ```

    Lisa play lõppu (samale taandele kui `tasks:`) handler ja enne ülesannet `Rakendus vastab` rida, mis käivitab ootel handler'id kohe:

    ```yaml
      handlers:
        - name: Restart tomcat
          ansible.builtin.systemd_service:
            name: tomcat10
            state: restarted
            daemon_reload: true
    ```

    ```yaml
        - name: Muudatused rakenduvad enne kontrolli
          ansible.builtin.meta: flush_handlers
    ```

    `daemon_reload: true` loeb muutunud teenusefaili enne taaskäivitust.

**Kontrolli:** käivita playbook kaks korda.

```bash
ansible-playbook labseis.yml
ansible-playbook labseis.yml
ssh app01 grep -c db01 /etc/hosts
```

??? success "Oodatav tulemus"

    Teisel käivitusel on kõigis viies masinas `changed=0`. Failis `/etc/hosts` on db01 üks kord.

```bash
(cd ~/kursus && git add k02-ansible && git commit -m "k02: labseis.yml vead parandatud" && git push -u origin k02-ansible)
```

Sulgudes olevad käsud käivituvad alamkestas, nii et töökaust jääb `~/kursus/k02-ansible`. Kõik järgmised käsud käivitad samas kaustas.


## Osa 3 · Masinanimedest gruppideks

**Probleem:** iga play päises on masina nimi (`hosts: db01`). Kui andmebaas kolib teise masinasse või neid on kaks, tuleb muuta playbook'i. Lisaks võtab `/etc/hosts` plokk IP-aadressid faktidest, mis on olemas ainult käivituses osalevatel masinatel.

**Eesmärk:** inventory ütleb, milline masin millist tööd teeb. Playbook kasutab gruppe ja ülesanded jäävad samaks.

### 3.1 Inventory gruppideks

1. kohtumisel olid grupid distributsiooni järgi. Nüüd lisandub grupp iga teenuse kohta ja distributsioonigrupid koostatakse teenusegruppidest. Järelliide `:children` tähendab, et grupi liikmed on teised grupid. Muutuja `ansible_host` on masina IP-aadress.

Asenda faili `inventory.ini` sisu ja pane `<web01-IP>` jt asemele oma masinate aadressid (Proxmox, Summary → IPs või `~/.ssh/config`). Fail `inventory.ini`:

```ini
[web]
web01 ansible_host=<web01-IP>

[app]
app01 ansible_host=<app01-IP>

[queue]
rmq01 ansible_host=<rmq01-IP>

[cache]
mc01 ansible_host=<mc01-IP>

[db]
db01 ansible_host=<db01-IP>

[ubuntu:children]
web
app
queue

[alma:children]
cache
db

[all:vars]
ansible_user=kasutaja
```

**Küsimus enne käsku:** millised masinad on grupis `ubuntu` ja millistes gruppides on app01?

```bash
ansible-inventory --graph
ansible app01,mc01 -m ansible.builtin.debug -a var=group_names
```

??? success "Oodatav tulemus"

    Grupi `ubuntu` all on grupid `web`, `app` ja `queue`. app01: `["app", "ubuntu"]`, mc01: `["alma", "cache"]`. Just nende gruppide `group_vars` failidest saab masin 4. osas oma muutujad.

<figure markdown="span">
  ![Inventory: grupid teenuse ja distributsiooni järgi](assets/k02_inventory.svg){ width="720" }
  <figcaption>Joonis 2.2. Iga masin on teenuse grupis ja distributsiooni grupis (Talvik, 2026).</figcaption>
</figure>

### 3.2 Play'd gruppidele

Esimene muudatus nähtavalt. Andmebaasi play päises asendub masin grupiga, ülesanded jäävad samaks:

```yaml
# enne
- name: Andmebaas
  hosts: db01

# pärast
- name: Andmebaas
  hosts: db
```

Tee sama ülejäänud nelja teenuse play'ga: `mc01` → `cache`, `rmq01` → `queue`, `app01` → `app`, `web01` → `web`. Esimene play jääb `hosts: all`.

### 3.3 IP-aadress inventory'st

`/etc/hosts` plokk võtab aadressid faktidest (`ansible_default_ipv4`). Fakte kogub Ansible ainult masinatest, mis käivituses osalevad, nii et `--limit mc01` korral teiste masinate aadresse pole. Asenda esimese play ploki rida:

```yaml
          {{ hostvars[h].ansible_host }} {{ h }}
```

**Kontroll.** **Peab säilima:** kõik. Aadressid on samad, ainult allikas muutus.

```bash
ansible-playbook labseis.yml --check --diff
ansible-playbook labseis.yml --limit mc01
```

??? success "Oodatav tulemus"

    `--check --diff` ei näita ühtki muudatust, kõigis masinates `changed=0`. `--limit mc01` töötab nüüd, sest IP-aadressid on inventory's.

??? warning "Kui näed `'dict object' has no attribute 'ansible_default_ipv4'`"

    Rida kasutab veel fakte. Kontrolli, et ploki reas on `hostvars[h].ansible_host`.

```text
k02-ansible/
├── ansible.cfg
├── inventory.ini          grupid ja ansible_host
├── labseis.yml            hosts: grupid
└── requirements.yml
```

```bash
(cd ~/kursus && git add k02-ansible && git commit -m "k02: inventory grupid" && git push)
```

## Osa 4 · Väärtused muutujatesse

**Probleem:** rakendusserveri mälu tuleb tõsta. Leia `labseis.yml`-ist koht, kus seda muuta: `grep -n Xmx labseis.yml`. Väärtus on konfiguratsioonifaili teksti sees. Samamoodi on `labseis` kirjas viies kohas ja `app01:8080` Nginxi tekstis.

**Eesmärk:** väärtus on ühes kohas, kus on selge, kelle seadistus see on. Väärtuse muutmiseks ei pea ülesandeid puutuma.

### 4.1 Üks väärtus nähtavalt

Muutujate failid on kaustades `group_vars` ja `host_vars` inventory kõrval:

```bash
mkdir -p group_vars/all host_vars
```

Väärtus `512m` on rakendusserverite seadistus, seega läheb see grupi `app` muutujate faili. Fail `group_vars/app.yml`:

```yaml
tomcat_heap: 512m
```

`labseis.yml`-is asendub väärtus muutuja nimega:

```text
# enne
          Environment=CATALINA_OPTS=-Xmx512m
# pärast
          Environment=CATALINA_OPTS=-Xmx{{ tomcat_heap }}
```

```bash
ansible-playbook labseis.yml --check --diff --limit app01
```

??? success "Oodatav tulemus"

    `changed=0`: muutuja väärtus on sama, mis oli tekstis.

Nüüd sama nõue uuesti: muuda mälu **ilma ülesandeid muutmata**. Kirjuta failis `group_vars/app.yml` ajutiselt `640m`. Mõtle enne läbi, mida näitavad käsud:

```bash
ansible-playbook labseis.yml --check --diff --limit app01
ansible app01 -m ansible.builtin.debug -a var=tomcat_heap -e tomcat_heap=1g
```

??? success "Oodatav tulemus"

    `--diff` näitab rida `-Xmx512m` → `-Xmx640m` ja et Tomcat taaskäivitataks. Masinas midagi ei muutunud. Teine käsk näitab `1g`: käsurea `-e` on tugevam kui grupimuutuja. Pane väärtus tagasi `512m`-ks.

??? warning "Kui muutuja puudub ka app01-s"

    Kontrolli `ansible-inventory --graph` ja `ls group_vars`: app01 peab olema grupis `app` ja fail peab olema `group_vars/app.yml`. Kui käivitus annab vea `We were unable to read either as JSON nor YAML` ja väärtuses on `{{`, puuduvad väärtuse ümber jutumärgid.

### 4.2 Kelle seadistus see on

Iga väärtuse puhul otsusta, kelle seadistus see on. Sellest sõltub fail.

??? note "Tabel 2.1. Väärtused ja nende koht"

    | Väärtus | Fail | Põhjus |
    |---|---|---|
    | andmebaasi nimi, kasutaja, järjekorra kasutaja (`labseis`) | `group_vars/all/main.yml` | vajavad db01, rmq01 ja app01 |
    | Tomcati mälu (`512m`) | `group_vars/app.yml` | rakendusserverite seadistus |
    | Nginxi ülesvooluserver (`app01:8080`) | `host_vars/web01.yml` | selle veebiserveri seadistus |

    `group_vars/all/` on kaust, et 6. osas saaks loetava `main.yml` kõrvale krüpteeritud `vault.yml`.

Loo failid ja asenda `labseis.yml`-is väärtused muutujatega. Rakenduse seadetes asenduvad masinanimed gruppidega: `groups['db'][0]` on grupi `db` esimene masin, nii et andmebaasi kolimisel muudetakse ainult inventory't.

??? example "Failid `group_vars/all/main.yml` ja `host_vars/web01.yml`"

    ```yaml
    labseis_db_name: labseis
    labseis_db_user: labseis
    labseis_mq_user: labseis
    ```

    ```yaml
    nginx_upstream: app01:8080
    ```

??? example "Read, mis `labseis.yml`-is muutuvad"

    ```text
    hosts: db (andmebaas)    name: "{{ labseis_db_name }}"           (kaks korda)
                             name: "{{ labseis_db_user }}"
                             priv: "{{ labseis_db_name }}.*:ALL"
    hosts: queue             user: "{{ labseis_mq_user }}"
    hosts: app (env-fail)    DB_HOST={{ groups['db'][0] }}
                             DB_NAME={{ labseis_db_name }}
                             DB_USER={{ labseis_db_user }}
                             MEMCACHED_HOST={{ groups['cache'][0] }}
                             RABBITMQ_HOST={{ groups['queue'][0] }}
                             RABBITMQ_USER={{ labseis_mq_user }}
    hosts: web               server {{ nginx_upstream }};
    ```

**Kontroll.** **Peab säilima:** kõik, väärtused on samad.

```bash
ansible-playbook labseis.yml --check --diff
```

??? success "Oodatav tulemus"

    Kõigis masinates `changed=0`. Kui mõnes on `changed`, näitab `--diff`, millise väärtuse tekst erineb.

```text
k02-ansible/
├── ansible.cfg
├── inventory.ini
├── labseis.yml
├── requirements.yml
├── group_vars/
│   ├── all/main.yml
│   └── app.yml
└── host_vars/web01.yml
```

```bash
(cd ~/kursus && git add k02-ansible && git commit -m "k02: väärtused muutujatesse" && git push)
```

??? question "Sinu töö"

    Milliseid väärtusi hoiaksid teie serverites grupi kaupa ja milliseid ühe masina kaupa?

## Osa 5 · Konfiguratsioonitekst mallidesse

**Probleem:** konfiguratsioonifailide tekst on ülesannete sees (`content: |`). Faili on raske lugeda, sest YAML-i ja Nginxi süntaks on segamini, ja sama teksti ei saa teises play's kasutada.

**Eesmärk:** tekst on eraldi failis, mallis. Ülesanne viitab mallile. Teenuse seadistus ei muutu, muutub ainult see, kus teksti hoitakse.

### 5.1 Üks mall nähtavalt: Nginx

Moodul `template` töötleb faili enne kopeerimist Jinja2-ga: `{{ muutuja }}` asendatakse väärtusega. Mallid on kaustas `templates/` playbook'i kõrval, laiendiga `.j2`. Rida `{{ ansible_managed }}` lisab faili algusesse märkuse, et faili haldab Ansible.

```bash
mkdir -p templates
```

Tekst tõstetakse ülesandest malli. Fail `templates/labori-seis-nginx.conf.j2`:

```nginx
# {{ ansible_managed }}
upstream labori_seis {
    server {{ nginx_upstream }};
}
server {
    listen 80 default_server;
    server_name _;
    location / {
        proxy_pass http://labori_seis;
        proxy_set_header Host $host;
    }
}
```

Ülesandes asendub `copy` koos tekstiga `template`-ga:

```yaml
    # enne
    - name: Labori seisu sait on seadistatud
      ansible.builtin.copy:
        dest: /etc/nginx/sites-available/labori-seis
        content: |
          upstream labori_seis {
          ...
        mode: "0644"
      notify: Reload nginx

    # pärast
    - name: Labori seisu sait on seadistatud
      ansible.builtin.template:
        src: labori-seis-nginx.conf.j2
        dest: /etc/nginx/sites-available/labori-seis
        mode: "0644"
      notify: Reload nginx
```

**Kontroll.** **Peab säilima:** Nginxi seadistus. **Teadlik muudatus:** uus esimene rida `# Ansible managed`.

```bash
ansible-playbook labseis.yml --check --diff --limit web01
ansible-playbook labseis.yml --limit web01
ssh web01 head -4 /etc/nginx/sites-available/labori-seis
ssh web01 curl -s localhost/health
```

??? success "Oodatav tulemus"

    `--diff` näitab ainult rida `+# Ansible managed`. Käivitusel on mall `changed` ja väljundis `RUNNING HANDLER [Reload nginx]`. Failis on rida `server app01:8080;`: muutuja `nginx_upstream` väärtus failist `host_vars/web01.yml`. `/health` vastab nagu enne.

### 5.2 Memcached: täienda põhja

Tõsta Memcachedi seadete tekst ülesandest `Memcached kuulab kõigil liidestel` faili `templates/memcached.j2`. Lisa malli esimeseks reaks `# {{ ansible_managed }}` nagu Nginxi mallis. Ülesanne jääb samaks, ainult `copy` ja `content` asenduvad. Täienda põhja:

```yaml
    - name: Memcached kuulab kõigil liidestel
      ansible.builtin.template:
        # lisa siia src ja loodud malli nimi
        dest: /etc/sysconfig/memcached
        mode: "0644"
      notify: Restart memcached
```

```bash
ansible-playbook labseis.yml --syntax-check
ansible-playbook labseis.yml --check --diff --limit mc01
```

**Kontrolli:** kas Memcachedi seadetes muutub mõni väärtus või ainult see, kus teksti hoitakse?

??? example "Fail `templates/memcached.j2` ja `src`"

    ```bash
    # {{ ansible_managed }}
    PORT="11211"
    USER="memcached"
    MAXCONN="1024"
    CACHESIZE="64"
    OPTIONS="-l 0.0.0.0"
    ```

    Ülesandes: `src: memcached.j2`. `--diff` näitab ainult rida `+# Ansible managed`.

### 5.3 Tomcat: eesmärgi järgi

Tõsta Tomcati teenuse lisaseadete tekst (ülesanne `Tomcat loeb rakenduse seaded ja kasutab Java 21`) faili `templates/labori-seis-tomcat.conf.j2` ja muuda ülesanne seda kasutama. Säilita seadete väärtused (ka `{{ tomcat_heap }}`), sihtfail, õigused ja `notify: Restart tomcat`. Rakenduse seadete faili `env` jäta 6. osasse, sest selles on paroolid.

??? tip "Vihje"

    Vaata, kuidas muutus Nginxi ülesandes `copy` + `content` kujuks `template` + `src`. Mallis jääb `{{ tomcat_heap }}` alles: mall töötleb muutujat samamoodi nagu `content`.

```bash
ansible-playbook labseis.yml --check --diff
ansible-playbook labseis.yml
ansible-playbook labseis.yml
```

??? success "Oodatav tulemus"

    `--diff` näitab Memcachedi ja Tomcati failis ainult rida `# Ansible managed`. Handler'id taaskäivitavad Memcachedi ja Tomcati. Teisel käivitusel `changed=0`.

??? example "Fail `templates/labori-seis-tomcat.conf.j2`"

    ```ini
    # {{ ansible_managed }}
    [Service]
    EnvironmentFile=/etc/labori-seis/env
    Environment=JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    Environment=CATALINA_OPTS=-Xmx{{ tomcat_heap }}
    ```

    Ülesandes: `src: labori-seis-tomcat.conf.j2`.

```text
k02-ansible/
├── ansible.cfg, inventory.ini, labseis.yml, requirements.yml
├── group_vars/            all/main.yml, app.yml
├── host_vars/web01.yml
└── templates/             labori-seis-nginx.conf.j2, memcached.j2, labori-seis-tomcat.conf.j2
```

```bash
(cd ~/kursus && git add k02-ansible && git commit -m "k02: konfiguratsioonitekstid mallidesse" && git push)
```

## Osa 6 · Paroolid Vaulti

**Probleem:** `grep -n 2026 labseis.yml` näitab kolme parooli. Fail on Gitis ja paroole näeb igaüks, kellel on repositooriumile ligipääs.

**Eesmärk:** paroolid on repositooriumis Vaultiga krüpteeritud failis, nende avamise parool on väljaspool repositooriumi. Parooli väärtus jääb samaks, muutub ainult hoidmise viis. Parooli vahetus on eraldi töö (kodutöö).

### 6.1 Vault

**Ansible Vault** krüpteerib faile või üksikuid väärtusi. Vaulti parool on failis väljaspool repositooriumi ja `ansible.cfg` ütleb, kust see võtta.

```bash
mkdir -p ~/.config/is1
read -rsp "Vaulti parool: " p && printf '%s\n' "$p" > ~/.config/is1/vault_pass && unset p
chmod 600 ~/.config/is1/vault_pass
```

Ava `ansible.cfg` ja lisa olemasolevasse sektsiooni `[defaults]` rida `vault_password_file`. Teist sektsiooni `[defaults]` ei looda:

```ini
[defaults]
inventory = inventory.ini
vault_password_file = ~/.config/is1/vault_pass
```

```bash
ansible-vault create group_vars/all/vault.yml
```

Redaktoris kirjuta samad väärtused, mis on praegu `labseis.yml`-is, siis masinate olek ei muutu:

```yaml
vault_db_password: "Labseis2026"
vault_rabbitmq_password: "Jarjekord2026"
vault_teacher_token: "opetaja-token-2026"
```

Lisa faili `group_vars/all/main.yml` viited. Loetavas failis on näha, millised saladused on olemas, väärtused on ainult krüpteeritud failis:

```yaml
labseis_db_password: "{{ vault_db_password }}"
labseis_mq_password: "{{ vault_rabbitmq_password }}"
labseis_teacher_token: "{{ vault_teacher_token }}"
```

```bash
head -1 group_vars/all/vault.yml
ansible db01 -m ansible.builtin.debug -a "msg={{ labseis_db_password | length }}"
```

??? success "Oodatav tulemus"

    Esimene rida on `$ANSIBLE_VAULT;1.1;AES256`. `debug` näitab parooli pikkust (`11`), mitte parooli ennast: Ansible avas faili, aga saladust pole vaja terminali kuvada.

??? warning "Kui Vaulti faili ei saa avada"

    `Attempting to decrypt but no vault secrets found`: parooli faili pole või `ansible.cfg`-s puudub rida `vault_password_file`. `Decryption failed`: failis `~/.config/is1/vault_pass` on teine parool kui see, millega `vault.yml` loodi.

<figure markdown="span">
  ![Vault: saladus vault.yml-is, nimi main.yml-is, kasutus mallis](assets/k02_vault_vahekiht.svg){ width="720" }
  <figcaption>Joonis 2.3. Väärtus on krüpteeritud failis, nimi loetavas failis ja kasutus mallis (Talvik, 2026).</figcaption>
</figure>

### 6.2 Paroolid playbook'ist välja

Paroolid on kolmes kohas. Andmebaasi play's kaob osa `vars:` ja kasutaja ülesandes on `password: "{{ labseis_db_password }}"`. RabbitMQ kasutaja ülesandes on `password: "{{ labseis_mq_password }}"`. Rakenduse seadete fail `env` tuleb mallist. Paroolidega ülesanded saavad `no_log: true`: Vault kaitseb faili, aga käivituse väljundit kaitseb `no_log`.

??? example "Fail `templates/env.j2` ja muutuvad ülesanded"

    ```bash
    # {{ ansible_managed }}
    DB_HOST={{ groups['db'][0] }}
    DB_NAME={{ labseis_db_name }}
    DB_USER={{ labseis_db_user }}
    DB_PASSWORD={{ labseis_db_password }}
    MEMCACHED_HOST={{ groups['cache'][0] }}
    RABBITMQ_HOST={{ groups['queue'][0] }}
    RABBITMQ_USER={{ labseis_mq_user }}
    RABBITMQ_PASSWORD={{ labseis_mq_password }}
    TEACHER_TOKEN={{ labseis_teacher_token }}
    ```

    ```yaml
        - name: Rakenduse seaded on failis
          ansible.builtin.template:
            src: env.j2
            dest: /etc/labori-seis/env
            owner: root
            group: tomcat
            mode: "0640"
          notify: Restart tomcat
          no_log: true
    ```

**Kontroll.** **Peab säilima:** paroolid, rakendus. **Teadlik muudatus:** `env` failis rida `# Ansible managed`.

```bash
grep -c 2026 labseis.yml
ansible-playbook labseis.yml
ansible-playbook labseis.yml
ssh web01 curl -s localhost/health
```

??? success "Oodatav tulemus"

    `grep` annab `0`. Esimesel käivitusel muutub `env` fail ja Tomcat taaskäivitatakse, teisel `changed=0`. `/health` vastab `{"status":"UP","db":"UP","queue":"UP","cache":"UP"}`.

```text
k02-ansible/
├── ansible.cfg            vault_password_file
├── inventory.ini, labseis.yml, requirements.yml
├── group_vars/all/        main.yml (viited), vault.yml (krüpteeritud)
├── group_vars/app.yml, host_vars/web01.yml
└── templates/             labori-seis-nginx.conf.j2, memcached.j2, labori-seis-tomcat.conf.j2, env.j2
```

```bash
(cd ~/kursus && git add k02-ansible && git commit -m "k02: paroolid Vaulti" && git push)
```

## Osa 7 · Teenused rollideks

**Probleem:** `labseis.yml` on korras, aga ühe teenuse osad on ikka mitmes kohas: ülesanded ja handler failis, mall kaustas `templates/`, vaikeväärtusi pole. Teise projekti jaoks ei saa Nginxi seadistust kaasa võtta.

**Eesmärk:** iga teenuse ülesanded, handler'id, mallid ja vaikeväärtused on ühes kaustas, **rollis**. `site.yml` ütleb ainult, milline roll millises grupis käivitub. Kuna tekst on juba mallides ja väärtused muutujates, tõstad ainult olemasolevaid osi ja masinates ei tohi midagi muutuda.

### 7.1 Esimene roll nähtavalt: `nginx`

??? note "Tabel 2.2. Nginxi play osad ja rolli failid"

    | `labseis.yml`-is | Rollis |
    |---|---|
    | `tasks:` all olevad ülesanded | `roles/nginx/tasks/main.yml` |
    | `handlers:` all olev handler | `roles/nginx/handlers/main.yml` |
    | `templates/labori-seis-nginx.conf.j2` | `roles/nginx/templates/labori-seis.conf.j2` |
    | vaikeväärtus (praegu puudub) | `roles/nginx/defaults/main.yml` |
    | play päis `hosts: web`, `become: true` | `site.yml` |

Kaustad võib luua käsitsi või käsuga `ansible-galaxy role init --init-path roles nginx`, mis loob kõik standardsed kaustad (ka `files`, `meta`, `tests`, `vars`). Siin loome ainult vajalikud:

```bash
mkdir -p roles/nginx/tasks roles/nginx/handlers roles/nginx/templates roles/nginx/defaults
mv templates/labori-seis-nginx.conf.j2 roles/nginx/templates/labori-seis.conf.j2
```

Ülesanded tõstetakse `tasks:` alt faili `roles/nginx/tasks/main.yml`. Taane muutub: play's olid ülesanded neli tühikut sees, rollis algab `- name:` rea algusest. Malli nimi ülesandes muutub `labori-seis.conf.j2`-ks. Paketi ülesandesse lisandub `cache_valid_time: 3600`: paketiloendit ei uuendata uuesti, kui see on alla tunni vana. Serveris see midagi ei muuda. Fail `roles/nginx/tasks/main.yml`:

```yaml
- name: Nginx on paigaldatud
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true
    cache_valid_time: 3600

- name: Labori seisu sait on seadistatud
  ansible.builtin.template:
    src: labori-seis.conf.j2
    dest: /etc/nginx/sites-available/labori-seis
    mode: "0644"
  notify: Reload nginx

- name: Labori seisu sait on sisse lülitatud
  ansible.builtin.file:
    src: /etc/nginx/sites-available/labori-seis
    dest: /etc/nginx/sites-enabled/labori-seis
    state: link
  notify: Reload nginx

- name: Vaikesait on välja lülitatud
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify: Reload nginx

- name: Nginx töötab ja käivitub koos masinaga
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

Fail `roles/nginx/handlers/main.yml`:

```yaml
- name: Reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
```

Roll pakub vaikeväärtuse, projekt kirjutab selle üle failis `host_vars/web01.yml`. Fail `roles/nginx/defaults/main.yml`:

```yaml
nginx_upstream: app01:8080
```

Fail `site.yml` (play päis tuleb `labseis.yml`-ist):

```yaml
- name: Veebiserver
  hosts: web
  become: true
  roles:
    - nginx
```

Kustuta `labseis.yml`-ist play `Veebiserver`.

**Kontroll.** **Peab säilima:** kõik. Ülesanded, mall ja väärtused on samad, muutus ainult nende asukoht.

```bash
ansible-playbook site.yml --check --diff
ansible-playbook labseis.yml --check --diff
```

??? success "Oodatav tulemus"

    Mõlemas `changed=0` ja `--diff` ei näita midagi. `site.yml` haldab nüüd web01, `labseis.yml` ülejäänud masinaid.

```text
k02-ansible/
├── labseis.yml            andmebaas, vahemälu, järjekord, rakendus, /etc/hosts
├── site.yml               veebiserver
├── roles/nginx/
│   ├── defaults/main.yml
│   ├── handlers/main.yml
│   ├── tasks/main.yml
│   └── templates/labori-seis.conf.j2
├── templates/             memcached.j2, labori-seis-tomcat.conf.j2, env.j2
├── group_vars/, host_vars/, inventory.ini, ansible.cfg, requirements.yml
```

### 7.2 Roll `common`

`common` käib kõigis masinates. `blockinfile` haldab ainult markerite vahel olevat plokki, mitte kogu faili `/etc/hosts`: süsteemi enda read jäävad alles. Sama marker `# {mark} labori-seis` seob rolli ülesande plokiga, mille `labseis.yml` lõi. Ploki tekst läheb malli.

??? example "Failid `roles/common/templates/hosts.j2` ja `roles/common/tasks/main.yml`"

    ```jinja
    {% for h in groups['all'] | sort %}
    {{ hostvars[h].ansible_host }} {{ h }}
    {% endfor %}
    ```

    ```yaml
    - name: Masinad tunnevad üksteist nime järgi
      ansible.builtin.blockinfile:
        path: /etc/hosts
        marker: "# {mark} labori-seis"
        block: "{{ lookup('ansible.builtin.template', 'hosts.j2') }}"
    ```

??? example "Lisa `site.yml`-i algusesse"

    ```yaml
    - name: Kõik masinad
      hosts: all
      become: true
      roles:
        - common
    ```

Kustuta `labseis.yml`-ist esimene play. Kontroll: `ansible-playbook site.yml --check --diff` annab `changed=0`.

**Teadlik muudatus rolli kaudu:** igas masinas on sisselogimisel teade, web01-s oma tekst. Lisa rolli vaikeväärtus ja ülesanne ning faili `host_vars/web01.yml` masina oma väärtus.

??? example "Teade sisselogimisel"

    `roles/common/defaults/main.yml`:

    ```yaml
    common_motd: "Seda masinat haldab Ansible (Labori seis)."
    ```

    Lisa `roles/common/tasks/main.yml` lõppu:

    ```yaml
    - name: Teade sisselogimisel
      ansible.builtin.copy:
        dest: /etc/motd
        content: "{{ common_motd }}\n"
        mode: "0644"
    ```

    Lisa `host_vars/web01.yml`-i:

    ```yaml
    common_motd: "web01: veebiserver. Muudatused ainult Ansible'iga."
    ```

**Küsimus enne käsku:** mis on `/etc/motd` failis web01-s ja mis app01-s?

```bash
ansible-playbook site.yml --check --diff
ansible-playbook site.yml
ssh web01 cat /etc/motd
ssh app01 cat /etc/motd
```

??? success "Oodatav tulemus"

    `--diff` näitab ainult `/etc/motd` muudatusi. web01-s on masina oma tekst, teistes rolli vaikeväärtus: masina muutuja on tugevam kui rolli vaikeväärtus.

### 7.3 Rollid `memcached`, `mariadb` ja `rabbitmq`

Iga teenuse puhul on sama järjekord. Memcachedi näitel:

1. Loo rolli kaustad ja tõsta mall: `mkdir -p roles/memcached/{tasks,handlers,templates,defaults}` ja `mv templates/memcached.j2 roles/memcached/templates/`.
2. Tõsta ülesanded ja handler'id play'st rolli ja lisa vaikeväärtused. Ära muuda selles sammus seadete väärtusi. Tee seda 7.1 Nginxi rolli järgi ise, allpool olevad failid on kontrolliks.
3. Lisa `site.yml`-i play, mis annab grupile rolli (`hosts: cache`, `roles: [memcached]`).
4. Kontrolli süntaksit: `ansible-playbook site.yml --syntax-check`.
5. Rakenda ainult selles masinas: `ansible-playbook site.yml --limit mc01 --check --diff`, siis ilma `--check`-ita, ja `ssh web01 curl -s localhost/health`.
6. Kustuta vana play `labseis.yml`-ist ja käivita `site.yml --limit mc01` uuesti: `changed=0`.

MariaDB (`db01`, grupp `db`) ja RabbitMQ (`rmq01`, grupp `queue`) puhul asenda masina ja grupi nimi. Rollid erinevad selle poolest, kuidas teenust seadistatakse.

**Memcached** seadistatakse failiga, seepärast on mall ja handler. Rollis tulevad port ja mälu vaikeväärtustest, nii et kodutöös saab mälu masina kaupa muuta.

??? example "Roll `memcached`"

    ```bash
    mkdir -p roles/memcached/tasks roles/memcached/handlers roles/memcached/templates roles/memcached/defaults
    mv templates/memcached.j2 roles/memcached/templates/
    ```

    `roles/memcached/defaults/main.yml`:

    ```yaml
    memcached_port: 11211
    memcached_mem_mb: 64
    # AlmaLinuxi seadete fail (mall on selle vormingus)
    memcached_conf: /etc/sysconfig/memcached
    ```

    `roles/memcached/templates/memcached.j2` (literaalid asenduvad vaikeväärtustega, tulemus on sama):

    ```bash
    # {{ ansible_managed }}
    PORT="{{ memcached_port }}"
    USER="memcached"
    MAXCONN="1024"
    CACHESIZE="{{ memcached_mem_mb }}"
    OPTIONS="-l 0.0.0.0"
    ```

    `roles/memcached/tasks/main.yml`:

    ```yaml
    - name: Memcached on paigaldatud
      ansible.builtin.package:
        name: memcached
        state: present

    - name: Memcached kuulab kõigil liidestel
      ansible.builtin.template:
        src: memcached.j2
        dest: "{{ memcached_conf }}"
        mode: "0644"
      notify: Restart memcached

    - name: Memcached töötab ja käivitub koos masinaga
      ansible.builtin.service:
        name: memcached
        state: started
        enabled: true

    - name: Tulemüür lubab vahemälu pordi
      ansible.posix.firewalld:
        port: "{{ memcached_port }}/tcp"
        permanent: true
        immediate: true
        state: enabled
      when: ansible_facts['os_family'] == "RedHat"
    ```

    `roles/memcached/handlers/main.yml`:

    ```yaml
    - name: Restart memcached
      ansible.builtin.service:
        name: memcached
        state: restarted
    ```

    `site.yml`-i play `Vahemälu`: `hosts: cache`, `become: true`, `roles: [memcached]`.

**MariaDB:** `labseis.yml`-is on paigaldus kaks korda (Ubuntu ja AlmaLinux) ja konfiguratsioonifail kahes kohas. Rollis on erinevad väärtused vaikeväärtustes. Need on AlmaLinuxi omad, Ubuntus kirjutaksid need üle failis `group_vars/ubuntu.yml`. Skeemi laadimine on handler, mida teavitab andmebaasi loomine: tabelid laaditakse ainult uude andmebaasi, mitte igal käivitusel.

??? example "Roll `mariadb`"

    ```bash
    mkdir -p roles/mariadb/tasks roles/mariadb/handlers roles/mariadb/templates roles/mariadb/defaults
    ```

    `roles/mariadb/defaults/main.yml`:

    ```yaml
    mariadb_port: 3306

    # AlmaLinuxi väärtused. Teises distributsioonis kirjuta need üle grupimuutujatega.
    mariadb_paketid:
      - mariadb-server
      - python3-PyMySQL
    mariadb_conf_dir: /etc/my.cnf.d
    mariadb_socket: /var/lib/mysql/mysql.sock
    ```

    `roles/mariadb/templates/60-labseis.cnf.j2`:

    ```ini
    # {{ ansible_managed }}
    [mysqld]
    bind-address = 0.0.0.0
    port = {{ mariadb_port }}
    ```

    `roles/mariadb/handlers/main.yml`:

    ```yaml
    - name: Restart mariadb
      ansible.builtin.service:
        name: mariadb
        state: restarted

    - name: Load schema
      community.mysql.mysql_db:
        name: "{{ labseis_db_name }}"
        state: import
        target: "/root/{{ item }}"
        login_unix_socket: "{{ mariadb_socket }}"
      loop:
        - schema.sql
        - seed.sql
    ```

    `roles/mariadb/tasks/main.yml`:

    ```yaml
    - name: MariaDB ja Pythoni teek on paigaldatud
      ansible.builtin.package:
        name: "{{ mariadb_paketid }}"
        state: present

    - name: MariaDB kuulab kõigil liidestel
      ansible.builtin.template:
        src: 60-labseis.cnf.j2
        dest: "{{ mariadb_conf_dir }}/60-labseis.cnf"
        mode: "0644"
      notify: Restart mariadb

    - name: MariaDB töötab ja käivitub koos masinaga
      ansible.builtin.service:
        name: mariadb
        state: started
        enabled: true

    - name: Tulemüür lubab andmebaasi pordi
      ansible.posix.firewalld:
        port: "{{ mariadb_port }}/tcp"
        permanent: true
        immediate: true
        state: enabled
      when: ansible_facts['os_family'] == "RedHat"

    - name: Muudatused rakenduvad enne andmebaasi seadistamist
      ansible.builtin.meta: flush_handlers

    - name: Andmebaas on olemas
      community.mysql.mysql_db:
        name: "{{ labseis_db_name }}"
        encoding: utf8mb4
        state: present
        login_unix_socket: "{{ mariadb_socket }}"
      notify: Load schema

    - name: Rakenduse kasutaja on olemas
      community.mysql.mysql_user:
        name: "{{ labseis_db_user }}"
        host: "%"
        password: "{{ labseis_db_password }}"
        priv: "{{ labseis_db_name }}.*:ALL"
        state: present
        login_unix_socket: "{{ mariadb_socket }}"
      no_log: true

    - name: Skeem ja algandmed on kopeeritud
      ansible.builtin.copy:
        src: "{{ playbook_dir }}/../db/{{ item }}"
        dest: "/root/{{ item }}"
        mode: "0600"
      loop:
        - schema.sql
        - seed.sql
    ```

    `site.yml`-i play `Andmebaas`: `hosts: db`, `become: true`, `roles: [mariadb]`.

**RabbitMQ** kasutaja luuakse mooduliga, mitte konfiguratsioonifailiga, sest RabbitMQ hoiab kasutajaid oma andmebaasis. Seepärast pole mall ega handler vaja.

??? example "Roll `rabbitmq`"

    ```bash
    mkdir -p roles/rabbitmq/tasks roles/rabbitmq/defaults
    ```

    `roles/rabbitmq/defaults/main.yml`:

    ```yaml
    rabbitmq_vhost: /
    ```

    `roles/rabbitmq/tasks/main.yml`:

    ```yaml
    - name: RabbitMQ on paigaldatud
      ansible.builtin.apt:
        name: rabbitmq-server
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: RabbitMQ töötab ja käivitub koos masinaga
      ansible.builtin.service:
        name: rabbitmq-server
        state: started
        enabled: true

    - name: Rakenduse kasutaja on olemas
      community.rabbitmq.rabbitmq_user:
        user: "{{ labseis_mq_user }}"
        password: "{{ labseis_mq_password }}"
        update_password: on_create
        vhost: "{{ rabbitmq_vhost }}"
        configure_priv: ".*"
        read_priv: ".*"
        write_priv: ".*"
        state: present
      no_log: true

    - name: Vaikekasutajat guest ei ole
      community.rabbitmq.rabbitmq_user:
        user: guest
        state: absent
    ```

    `site.yml`-i play `Sõnumijärjekord`: `hosts: queue`, `become: true`, `roles: [rabbitmq]`.

Play'de järjekord `site.yml`-is: `Kõik masinad`, `Andmebaas`, `Vahemälu`, `Sõnumijärjekord`, siis `Veebiserver`. 7.4 lisab rakendusserveri veebiserveri ette, sest rakendus ühendub käivitumisel kõigi kolmega.

**Kontroll.** **Peab säilima:** teenused ja `/health`. **Teadlik muudatus:** MariaDB konfiguratsioonifailis rida `# Ansible managed` ja MariaDB taaskäivitus.

```bash
ansible-playbook site.yml --check --diff
ansible-playbook site.yml
ansible-playbook site.yml
ssh web01 curl -s localhost/health
```

??? success "Oodatav tulemus"

    `--diff` näitab ainult MariaDB konfiguratsioonifaili uut esimest rida. Käivitusel taaskäivitatakse MariaDB, tabeleid uuesti ei laadita. Teisel käivitusel `changed=0` ja `/health` vastab kõigil väljadel `UP`.

??? warning "Kui handler ei käivitu või andmebaas ei vasta"

    `The requested handler 'Restart mariadb' was not found`: handler'i nimi peab olema täpselt sama mis `notify:` real. `A MySQL module is required`: db01-s puudub `python3-PyMySQL`. `"db":"DOWN"`: kontrolli `ssh db01 sudo ss -tln | grep 3306` (peab olema `0.0.0.0:3306`) ja `ssh db01 sudo firewall-cmd --list-ports`.

**Küsimus enne käsku:** RabbitMQ kasutaja ülesandes on `update_password: on_create`. Kui muudad hiljem Vaultis RabbitMQ parooli, kas olemasoleva kasutaja parool muutub?

??? success "Vastus"

    Ei: `on_create` määrab parooli ainult kasutaja loomisel. Siis on rakenduse seadetes uus parool ja RabbitMQ-s vana ning `/health` näitab `"queue":"DOWN"`. Paroolivahetuseks on `update_password: always`, mis muudab parooli, kui see erineb.

### 7.4 Roll `tomcat` ja lõppkontroll

Tomcati rollis on kolm eri asja: seadistus (kaks malli, mis teavitavad sama handler'it), rakenduse fail (WAR) ja kontroll, et rakendus vastab. `flush_handlers` käivitab taaskäivituse enne kontrolli, nii et kontroll näeb juba uute seadetega rakendust. `check_mode: false` laseb kontrollpäringu teha ka `--check` käivitusel, sest päring ainult loeb. Eelvaates näitab see praegu töötava rakenduse olekut, mitte veel rakendamata seadete tulemust.

??? example "Roll `tomcat`"

    ```bash
    mkdir -p roles/tomcat/tasks roles/tomcat/handlers roles/tomcat/templates roles/tomcat/defaults
    mv templates/env.j2 roles/tomcat/templates/
    mv templates/labori-seis-tomcat.conf.j2 roles/tomcat/templates/labori-seis.conf.j2
    ```

    `roles/tomcat/defaults/main.yml`:

    ```yaml
    tomcat_heap: 256m
    tomcat_webapps: /var/lib/tomcat10/webapps
    # WAR kursuse starteri release'ist. Kui tomcat_war_url on tühi, kopeeritakse fail tomcat_war_src control node'ist.
    tomcat_war_url: https://github.com/hkhk-tk/is1-starter/releases/download/v1.1.0/labori-seis.war
    tomcat_war_src: "{{ playbook_dir }}/../labori-seis.war"
    ```

    `roles/tomcat/handlers/main.yml`:

    ```yaml
    - name: Restart tomcat
      ansible.builtin.systemd_service:
        name: tomcat10
        state: restarted
        daemon_reload: true
    ```

    `roles/tomcat/tasks/main.yml`:

    ```yaml
    - name: Java 21 ja Tomcat 10 on paigaldatud
      ansible.builtin.apt:
        name:
          - openjdk-21-jre-headless
          - tomcat10
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: Rakenduse seadete kaust on olemas
      ansible.builtin.file:
        path: /etc/labori-seis
        state: directory
        owner: root
        group: tomcat
        mode: "0750"

    - name: Rakenduse seaded (paroolid) on failis
      ansible.builtin.template:
        src: env.j2
        dest: /etc/labori-seis/env
        owner: root
        group: tomcat
        mode: "0640"
      notify: Restart tomcat
      no_log: true

    - name: Tomcati teenuse lisaseadete kaust on olemas
      ansible.builtin.file:
        path: /etc/systemd/system/tomcat10.service.d
        state: directory
        mode: "0755"

    - name: Tomcat loeb rakenduse seaded ja kasutab Java 21
      ansible.builtin.template:
        src: labori-seis.conf.j2
        dest: /etc/systemd/system/tomcat10.service.d/labori-seis.conf
        mode: "0644"
      notify: Restart tomcat

    - name: Kas juurkontekstis on Tomcati näidisleht?
      ansible.builtin.stat:
        path: "{{ tomcat_webapps }}/ROOT/index.html"
      register: tomcat_naidis

    - name: Näidislehe kaust on eemaldatud
      ansible.builtin.file:
        path: "{{ tomcat_webapps }}/ROOT"
        state: absent
      when: tomcat_naidis.stat.exists

    - name: Rakendus (WAR) on alla laaditud
      ansible.builtin.get_url:
        url: "{{ tomcat_war_url }}"
        dest: "{{ tomcat_webapps }}/ROOT.war"
        owner: tomcat
        group: tomcat
        mode: "0644"
      when: tomcat_war_url | length > 0

    - name: Rakendus (WAR) on kopeeritud control node'ist
      ansible.builtin.copy:
        src: "{{ tomcat_war_src }}"
        dest: "{{ tomcat_webapps }}/ROOT.war"
        owner: tomcat
        group: tomcat
        mode: "0644"
      when: tomcat_war_url | length == 0

    - name: Tomcat töötab ja käivitub koos masinaga
      ansible.builtin.service:
        name: tomcat10
        state: started
        enabled: true

    - name: Muudatused rakenduvad enne kontrolli
      ansible.builtin.meta: flush_handlers

    - name: Rakendus vastab app01-s
      ansible.builtin.uri:
        url: http://localhost:8080/health/live
        status_code: 200
      register: tomcat_live
      check_mode: false
      until: tomcat_live.status == 200
      retries: 40
      delay: 5
    ```

Kui `labseis.yml`-is pole enam ühtki play'd, kustuta see ja kaust `templates`. Lõpliku `site.yml` viimane play kontrollib, et rakendus ja iga sõltuvus töötavad. HTTP kood `200` üksi ei piisa: 1. osas vastas rakendus koodiga `200`, aga vahemälu oli `DOWN`. `/health` tagastab JSON-i ja `uri` annab selle väljale `json`.

Lõplik `site.yml`:

```yaml
- name: Kõik masinad
  hosts: all
  become: true
  roles:
    - common

- name: Andmebaas
  hosts: db
  become: true
  roles:
    - mariadb

- name: Vahemälu
  hosts: cache
  become: true
  roles:
    - memcached

- name: Sõnumijärjekord
  hosts: queue
  become: true
  roles:
    - rabbitmq

- name: Rakendusserver
  hosts: app
  become: true
  roles:
    - tomcat

- name: Veebiserver
  hosts: web
  become: true
  roles:
    - nginx

- name: Labori seis vastab
  hosts: web
  gather_facts: false
  tasks:
    - name: Rakendus ja selle sõltuvused töötavad web01 kaudu
      ansible.builtin.uri:
        url: http://localhost/health
        status_code: 200
        return_content: true
      register: health
      check_mode: false
      until:
        - health.status | default(-1) == 200
        - (health.json | default({})).get('db', '') == 'UP'
        - (health.json | default({})).get('queue', '') == 'UP'
        - (health.json | default({})).get('cache', '') == 'UP'
      retries: 30
      delay: 5
```

```bash
git rm labseis.yml
ls templates      # peab olema tühi; kui mõni mall on alles, on selle roll pooleli
rmdir templates
ansible-playbook site.yml --check --diff
ansible-playbook site.yml
```

??? success "Oodatav tulemus"

    **Teadlik muudatus:** `env` failis ja teenuse lisaseadetes ei muutu midagi (mallid olid juba 5.–6. osas), seega `changed=0`. Viimane ülesanne `Rakendus ja selle sõltuvused töötavad web01 kaudu` on `ok`. Ava brauseris `http://<web01-IP>/`: avaneb Labori seisu leht.

??? warning "Kui `Rakendus vastab app01-s` ebaõnnestub 40 korduse järel"

    Rakendus ei käivitunud: `ssh app01 sudo journalctl -u tomcat10 -n 50 --no-pager`. `ACCESS_REFUSED` viitab RabbitMQ paroolile, `Communications link failure` andmebaasile.

??? warning "Kui web01 annab `502 Bad Gateway`"

    Nginx töötab, aga ei saa rakendusserverilt vastust: `ssh app01 curl -s localhost:8080/health/live` ja `grep nginx_upstream host_vars/web01.yml`.

```bash
(cd ~/kursus && git add -A k02-ansible && git commit -m "k02: rollid, labseis.yml kustutatud" && git push)
```

## Osa 8 · Tõestus

### 8.1 Kuidas väljundit lugeda

Ansible'i väljund on tõend. Iga ülesande järel on iga masina tulemus:

??? note "Tabel 2.3. Ülesande tulemused väljundis"

    | Väljundis | Tähendus |
    |---|---|
    | `ok: [db01]` | moodul kontrollis olekut, muudatust polnud vaja |
    | `changed: [web01]` | moodul muutis masinat |
    | `skipping: [web01]` | tingimus `when` ei olnud tõene |
    | `RUNNING HANDLER [nginx : Reload nginx]` | handler käivitus, sest mõni ülesanne teavitas ja muutis |
    | `fatal: [app01]: FAILED!` | ülesanne ebaõnnestus, selle masina ülejäänud ülesanded jäävad tegemata |
    | `PLAY RECAP` | iga masina kokkuvõte; `changed=0` tähendab, et ükski ülesanne ei muutnud masinat. `--check` käivitusel tähendab `changed`, et ülesanne muudaks masinat, masin ise jääb samaks |

### 8.2 Triiv

**Triiv** (drift) on olukord, kus masina tegelik seadistus erineb repositooriumis kirjeldatust. Tekita see meelega ja vaata, kuidas Ansible selle leiab:

```bash
ssh web01 "echo 'käsitsi muudetud' | sudo tee /etc/motd"
ansible-playbook site.yml --check --diff --limit web01
ssh web01 cat /etc/motd
ansible-playbook site.yml --limit web01
ssh web01 cat /etc/motd
ansible-playbook site.yml --limit web01
```

??? success "Oodatav tulemus"

    `--check --diff` näitab muudatust `-käsitsi muudetud`, aga fail jääb samaks: eelvaade ei muuda midagi. Käivitus taastab teksti failist `host_vars/web01.yml` ja järgmine käivitus annab `changed=0`. Ansible ei mäleta varasemaid käivitusi, vaid võrdleb iga kord kirjeldatud ja tegelikku olekut.

### 8.3 Muudatus masinate kaupa

Võtmesõna `serial` töötleb play masinaid partiide kaupa ja määrab ainult partii suuruse. Kui tahad, et esimese vea järel ülejäänud partiid ei käivituks, lisa ka `any_errors_fatal: true`. Juba tehtud muudatusi see tagasi ei võta. Lisa `site.yml`-i esimesse play'sse `hosts:` rea järele:

```yaml
  serial: 2
  any_errors_fatal: true
```

**Küsimus enne käsku:** mitu korda on väljundis rida `PLAY [Kõik masinad]`?

```bash
ansible-playbook site.yml
```

??? success "Oodatav tulemus"

    Kolm korda: kaks masinat, kaks masinat ja üks masin.

### 8.4 `ansible-lint` ja korduv käivitus

[`ansible-lint`](https://docs.ansible.com/projects/lint/) kontrollib häid tavasid: moodulid on täisnimega, failidel on `mode`, `command` ülesandel on `changed_when`. Automaatne hindaja kasutab sama versiooni.

```bash
sudo apt install -y pipx
pipx install "ansible-lint==26.9.*"
pipx ensurepath && source ~/.bashrc
ansible-lint
ansible-playbook site.yml | tee run2.txt
```

??? success "Oodatav tulemus"

    `ansible-lint` lõpeb reaga `Passed: 0 failure(s), 0 warning(s)`. `run2.txt` PLAY RECAP-is on kõigil viiel masinal `changed=0` ja `failed=0`: projekt on korduvkäivitatav. Et süsteem töötab, tõendab viimane ülesanne, mis on `ok` ainult siis, kui `db`, `queue` ja `cache` on `UP`.

??? warning "Kui teisel käivitusel on `changed`"

    Vaata väljundist, milline ülesanne muutis. `shell` ja `command` asemel kasuta moodulit, mis kontrollib olekut. Mallis hoia järjekord samana (`sort`) ja ära kasuta väärtusi, mis muutuvad igal käivitusel.

### 8.5 Projekt tervikuna

```text
k02-ansible/
├── ansible.cfg               inventory, roll, Vaulti parooli fail
├── inventory.ini             masinad, grupid, IP-aadressid
├── requirements.yml          kogud ja nende versioonid
├── site.yml                  milline roll millises grupis, järjekord
├── run2.txt                  korduva käivituse tõend
├── group_vars/
│   ├── all/main.yml          ühised väärtused ja viited saladustele
│   ├── all/vault.yml         krüpteeritud paroolid
│   └── app.yml               rakendusserverite väärtused
├── host_vars/web01.yml       ühe masina väärtused
└── roles/
    ├── common/               /etc/hosts plokk, teade sisselogimisel
    ├── mariadb/              andmebaas, kasutaja, skeem
    ├── memcached/            vahemälu
    ├── rabbitmq/             järjekord ja kasutaja
    ├── tomcat/               rakendus ja selle seaded
    └── nginx/                veebiserver
```

??? question "Teine laborikeskkond"

    Samad viis teenust tuleb paigaldada teise õppija masinatesse, millel on teised IP-aadressid. Hostinimed, distributsioonid ja kasutaja on samad. Milliseid faile pead muutma ja millised peavad jääma samaks?

    Nende eeldustega muutub ainult `inventory.ini` (IP-aadressid) ja vajadusel Vaulti parool. Rollid, `site.yml` ja muutujad jäävad samaks. Just see ongi eraldamise kasu.

??? note "Kontrollnimekiri"

    - [ ] `labseis.yml` on kustutatud, `site.yml` paigaldab kogu Labori seisu
    - [ ] kuus rolli: `common`, `mariadb`, `memcached`, `rabbitmq`, `tomcat`, `nginx`
    - [ ] `group_vars/all/vault.yml` algab reaga `$ANSIBLE_VAULT`, Vaulti parool ei ole Gitis
    - [ ] `ansible-lint` ja `run2.txt` on puhtad

## Töö esitamine

Töö jõuab harusse `main` pull request'iga ja esitatakse tag'iga `k02`.

```bash
(cd ~/kursus && git add -A k02-ansible && git commit -m "k02: serial, run2.txt" && git push)
```

Tee GitHubis pull request harust `k02-ansible` harusse `main` (**Compare & pull request**), vaata muudatused üle ja ühenda (**Merge pull request**). Seejärel:

```bash
cd ~/kursus
git switch main
git pull
git tag k02
git push origin k02
```

Tulemuse näed Classroom 50-s.

??? warning "K2 tulemus on 0, kuigi töö on tehtud"

    Tag `k02` osutab siis harus `main` olevatele algfailidele, sest pull request jäi tegemata või haru `k02-ansible` ei jõudnud GitHubi. Kontrolli GitHubis, kas haru `k02-ansible` on olemas. Kui ei ole, saada see: `git push -u origin k02-ansible`. Tee pull request ja ühenda see, seejärel tõsta tag uuele kohale:

    ```bash
    cd ~/kursus
    git switch main
    git pull
    git tag -f k02
    git push -f origin k02
    ```

## Rikkeotsing

Sama meetod nagu loengus: **sümptom → hüpotees → tõend → parandus → korduskontroll**. Kõige parem paaristööna: paariline käivitab „Tekita rike“ käsu, kui sa ei vaata, ja sina leiad põhjuse. Siis vahetage. Üksi tehes ära vaata käsku, käivita see ja alusta sümptomist. Iga rikke lõpus peab `ssh web01 curl -s localhost/health` näitama kõigil väljadel `UP` ja `ansible-playbook site.yml` andma `changed=0`.

??? example "R1 · Vahemälu ei vasta"

    Tekita rike: `ssh mc01 sudo systemctl stop memcached`

    **Sümptom:** `/health` näitab `"cache":"DOWN"`, teised väljad `UP`.

    ??? tip "Vihje"
        Milline nool topoloogial on katki? Kas teenus töötab: `ssh mc01 systemctl is-active memcached`.

    ??? success "Lahendus"
        Memcached ei tööta. Roll ütleb `state: started`, seega parandab käivitus: `ansible-playbook site.yml --limit mc01` annab `changed=1`. Teisel käivitusel `changed=0`. Küsimus: miks parandas playbook rikke, kuigi sa koodi ei muutnud?

??? example "R2 · Leht annab 502"

    Tekita rike: `ssh web01 "sudo sed -i 's/app01:8080/app01:8081/' /etc/nginx/sites-available/labori-seis && sudo systemctl reload nginx"`

    **Sümptom:** `ssh web01 curl -s -o /dev/null -w '%{http_code}' localhost/health` annab `502`.

    ??? tip "Vihje"
        Rakendus app01-s töötab? Kui jah, siis on viga web01 ja app01 vahel. `--check --diff` näitab, mis serveris erineb koodist.

    ??? success "Lahendus"
        Keegi muutis serveris faili käsitsi: see on triiv. `ansible-playbook site.yml --limit web01 --check --diff` näitab `-server app01:8081;` ja `+server app01:8080;`. Käivitus taastab faili ja handler laeb Nginxi uuesti. Eelvaates on ka `failed=1`: viimane play kontrollib rakendust, mis praegu annab 502.

??? example "R3 · Andmebaas puudub pärast taaskäivitust"

    Tekita rike: `ssh db01 sudo systemctl disable --now mariadb`

    **Sümptom:** `/health` näitab `"db":"DOWN"`.

    ??? tip "Vihje"
        `ssh db01 systemctl is-active mariadb` ja `systemctl is-enabled mariadb`. Mida tähendab `disabled` järgmisel masina käivitusel?

    ??? success "Lahendus"
        MariaDB on peatatud ja automaatne käivitus välja lülitatud. Rollis on `state: started` ja `enabled: true`, käivitus parandab mõlemad. Ilma `enabled: true`-ta oleks teenus pärast masina taaskäivitust jälle maas.

??? example "R4 · Grupimuutuja ei mõju"

    Tekita rike: `mkdir -p roles/tomcat/vars && echo 'tomcat_heap: 128m' > roles/tomcat/vars/main.yml`

    **Sümptom:** `ansible-playbook site.yml --limit app01 --check --diff` tahab muuta `-Xmx512m` → `-Xmx128m`, kuigi `group_vars/app.yml` ütleb `512m`.

    ??? tip "Vihje"
        Kust veel võib `tomcat_heap` tulla? `grep -rn tomcat_heap .`

    ??? success "Lahendus"
        Rolli `vars` on tugevam kui `group_vars`. Kustuta `roles/tomcat/vars` ja eelvaade on jälle tühi. Vaikeväärtus kuulub kausta `defaults`.

??? example "R5 · Handler'it ei leita"

    Tekita rike: `sed -i 's/notify: Reload nginx/notify: reload nginx/' roles/nginx/tasks/main.yml && sed -i '1a # rike' roles/nginx/templates/labori-seis.conf.j2`

    **Sümptom:** `ansible-playbook site.yml --limit web01` lõpeb veaga.

    ??? success "Lahendus"
        Veateade: `The requested handler 'reload nginx' was not found`. Nimi `notify` real ja handler'i nimi peavad olema täpselt samad, ka suurtäht. Paranda `notify: Reload nginx` ja kustuta mallist rida `# rike`.

??? example "R6 · Vault ei avane"

    Tekita rike: `mv ~/.config/is1/vault_pass ~/.config/is1/vault_pass.bak`

    **Sümptom:** iga käivitus lõpeb kohe veaga.

    ??? success "Lahendus"
        `ERROR! The vault password file /home/kasutaja/.config/is1/vault_pass was not found`. `ansible.cfg` viitab failile, mida pole. Taasta: `mv ~/.config/is1/vault_pass.bak ~/.config/is1/vault_pass`. Kui kolleeg kloonib repositooriumi, saab ta sama vea: Vaulti parool tuleb anda turvalise kanali kaudu, mitte Gitis.

??? example "R7 · Mall ei koostu"

    Tekita rike: `sed -i 's/{{ nginx_upstream }}/{{ nginx_upstreams }}/' roles/nginx/templates/labori-seis.conf.j2`

    **Sümptom:** `ansible-playbook site.yml --limit web01` annab `FAILED`.

    ??? success "Lahendus"
        `'nginx_upstreams' is undefined`: mallis on muutuja nimes kirjaviga. Kas Nginx töötab edasi? Jah, mall koostatakse control node'is ja vigast faili serverisse ei saadeta. Paranda nimi.

## Lisaülesanded

Kogenud õppijatele. Iga ülesanne on samas projektis ja lõpeb kontrolliga. Pärast katset taasta projekt nii, et `run2.txt` jääb puhtaks.

??? example "1 · Eeltingimused: vale väärtus peatab rolli enne muudatusi"

    Kui keegi kirjutab `tomcat_heap: palju`, käivitub Tomcat vigase seadistusega alles pärast taaskäivitust. Rolli alguses olev kontroll peatab käivituse enne, kui midagi muutub. Lisa faili `roles/tomcat/tasks/main.yml` algusesse:

    ```yaml
    - name: Mälu väärtus on õiges vormis
      ansible.builtin.assert:
        that:
          - tomcat_heap is match('^[0-9]+[mg]$')
        fail_msg: "tomcat_heap peab olema kujul 512m või 1g, praegu: {{ tomcat_heap }}"
        quiet: true
    ```

    ```bash
    ansible-playbook site.yml --limit app01 -e tomcat_heap=palju
    ansible-playbook site.yml --limit app01
    ```

    Esimene käivitus lõpeb `failed=1` ja `changed=0` ning teatega `tomcat_heap peab olema kujul 512m või 1g, praegu: palju`. Teine annab `changed=0`.

    Rolli sisendit saab kirjeldada ka failis `roles/tomcat/meta/argument_specs.yml` ([Role argument validation](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html#role-argument-validation)). See kontrollib, et muutuja on olemas ja õiget tüüpi, aga mitte väärtuse vormi: `-e '{"tomcat_heap": [512]}'` teisendab loendi tekstiks ja kontrollist läheb läbi. Miks on `assert` siin vajalik ka siis, kui `argument_specs` on olemas?

??? example "2 · Kui midagi läheb valesti: `block` ja `rescue`"

    Vea korral ütleb viimane play ainult, et `/health` ei vastanud. Põhjus on tavaliselt app01 Tomcati logis. Asenda `site.yml`-i viimase play ülesanne nii, et vea korral loeb Ansible rakendusserveri logi. `block` ja `rescue` töötavad nagu `try` ja `catch`, `delegate_to` käivitab ülesande teises masinas:

    ```yaml
      tasks:
        - name: Kontroll, vea korral rakendusserveri logi
          block:
            - name: Rakendus ja selle sõltuvused töötavad web01 kaudu
              ansible.builtin.uri:
                url: http://localhost/health
                return_content: true
              register: health
              check_mode: false
              until: health.status == 200
              retries: "{{ health_retries | default(30) }}"
              delay: 5
              failed_when: health.status != 200 or 'DOWN' in (health.content | default(''))
          rescue:
            - name: Tomcati logi app01-st
              ansible.builtin.command: journalctl -u tomcat10 -n 20 --no-pager
              delegate_to: "{{ groups['app'][0] }}"
              become: true
              register: tomcat_logi
              changed_when: false

            - name: Logi viimased read
              ansible.builtin.debug:
                var: tomcat_logi.stdout_lines

            - name: Labori seis ei vasta
              ansible.builtin.fail:
                msg: "Labori seis ei vasta web01 kaudu. Põhjus on tõenäoliselt ülal Tomcati logis."
    ```

    Proovi: `ssh app01 sudo systemctl stop tomcat10`, siis `ansible-playbook site.yml --limit web01 -e health_retries=2`. Kokkuvõttes on `failed=1` ja `rescued=1`. Taasta Tomcat playbook'iga: `ansible-playbook site.yml --limit app01`.

??? example "3 · Kaks keskkonda: test ja prod"

    Töökohas paigaldatakse sama projekt mitmesse keskkonda. Rollid ja `site.yml` on samad, erinevad masinad ja mõned väärtused. Dokumentatsiooni soovitus ([Sample Ansible setup](https://docs.ansible.com/projects/ansible/latest/tips_tricks/sample_setup.html)) on hoida igal keskkonnal oma inventory ja selle kõrval oma `group_vars`. Selles katses on mõlemas keskkonnas samad masinad, prod-is on rakendusel rohkem mälu.

    ```bash
    mkdir -p inventories/test/group_vars inventories/prod/group_vars
    cp inventory.ini inventories/test/hosts.ini
    cp inventory.ini inventories/prod/hosts.ini
    echo 'tomcat_heap: 768m' > inventories/prod/group_vars/app.yml
    ansible-playbook -i inventories/prod/hosts.ini site.yml --limit app01 --check --diff
    ```

    **Küsimus enne käsku:** kas `--diff` näitab `-Xmx768m`? Tegelikult annab käsk `changed=0`: projekti kõrval olev `group_vars/app.yml` (`512m`) on tugevam kui inventory kõrval olev. Tõsta grupi `app` väärtus testi inventory juurde ja proovi uuesti:

    ```bash
    mv group_vars/app.yml inventories/test/group_vars/app.yml
    ansible-playbook -i inventories/prod/hosts.ini site.yml --limit app01 --check --diff
    ansible-playbook -i inventories/test/hosts.ini site.yml --limit app01 --check --diff
    ansible-playbook site.yml --limit app01 --check --diff
    ```

    Prod näitab `-Xmx512m` → `+Xmx768m`, test `changed=0`. Viimane käsk kasutab `ansible.cfg`-s olevat `inventory.ini`-d ja näitab `+Xmx256m`: grupimuutujat pole enam ja kehtib rolli vaikeväärtus. Mida peaks `ansible.cfg`-s muutma, et vaikimisi oleks test ja prod-i jaoks tuleks `-i` alati kirjutada? Kuidas hoiaksid prod-i paroole eraldi Vaulti parooliga (`--vault-id prod@prompt`, [Managing vault passwords](https://docs.ansible.com/projects/ansible/latest/vault_guide/vault_managing_passwords.html))?

    Taasta katse lõpus projekt, sest automaatne hindaja ootab faile vanas kohas: `mv inventories/test/group_vars/app.yml group_vars/app.yml && rm -r inventories`, siis `ansible-playbook site.yml --limit app01 --check --diff` annab `changed=0`.

??? example "4 · Paroolid keskserverist: HashiCorp Vault ja OpenBao"

    Ansible Vault hoiab paroole krüpteeritult repositooriumis. Töökohas on saladused sageli keskses serveris, kust Ansible need käivituse ajal küsib: Gitis pole ka krüpteeritud väärtust, ligipääsu saab tühistada ja iga päring jääb serveri logisse. Levinuim selline server on HashiCorp Vault (alates 2023 BSL-litsentsiga). [OpenBao](https://openbao.org/) on selle avatud lähtekoodiga haru (sarnaselt OpenTofuga 4. kohtumisel) sama API-ga, nii et kogu [`community.hashi_vault`](https://docs.ansible.com/projects/ansible/latest/collections/community/hashi_vault/index.html) töötab mõlemaga.

    Käivita OpenBao control node'is arendusrežiimis. See hoiab andmeid mälus ja kasutab teadaolevat juurtokenit, seega sobib ainult katseks:

    ```bash
    cd /tmp
    curl -fsSLO https://github.com/openbao/openbao/releases/download/v2.7.1/openbao_2.7.1_linux_amd64.deb
    sudo apt install -y ./openbao_2.7.1_linux_amd64.deb python3-hvac
    nohup bao server -dev -dev-root-token-id=proov -dev-listen-address=127.0.0.1:8200 > /tmp/bao.log 2>&1 &
    export BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=proov VAULT_TOKEN=proov
    bao kv put secret/labseis db_password=Labseis2026
    cd ~/kursus/k02-ansible
    ansible-galaxy collection install community.hashi_vault:==6.2.0
    ```

    Asenda failis `group_vars/all/main.yml` andmebaasi parooli viide lookup'iga. Lookup käivitub control node'is iga kord, kui muutujat kasutatakse:

    ```yaml
    labseis_db_password: "{{ lookup('community.hashi_vault.vault_kv2_get', 'labseis', engine_mount_point='secret', url='http://127.0.0.1:8200').secret.db_password }}"
    ```

    ```bash
    ansible db01 -m ansible.builtin.debug -a "msg={{ labseis_db_password | length }}"
    ansible-playbook site.yml --limit db01,app01 --check --diff
    ```

    Pikkus on `11` ja kontroll annab `changed=0`: parool on sama, ainult allikas muutus. Mis juhtub, kui teed `unset VAULT_TOKEN` või peatad serveri (`pkill -f "bao server"`)? Võrdle Ansible Vaultiga: mis on Gitis, kes saab parooli lugeda ja kuidas tühistad ligipääsu? Katse lõpus taasta failis `main.yml` rida `labseis_db_password: "{{ vault_db_password }}"`.

