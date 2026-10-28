---
tags:
  - Ansible
  - Proxmox
  - Molecule
---

# 2. kohtumine, lisaülesanded

| Ülesanne | Tase | Tulemus |
|---|---|---|
| [1. Käsitsi muudatus ja fetch](#1-kasitsi-muudatus-ja-fetch) | lihtne | käsitsi muudatus on control node'is diff'ina näha |
| [2. Play muutujad, list ja sõnastik](#2-play-muutujad-list-ja-sonastik) | lihtne | list, sõnastik ja fakt `debug`-i väljundis |
| [3. Rolli parameeter ja sammhaaval käivitus](#3-rolli-parameeter-ja-sammhaaval-kaivitus) | lihtne | rolli parameeter muudab heap'i, `site.yml` taastatud |
| [4. Vaulti diff Gitis](#4-vaulti-diff-gitis) | lihtne | `vault.yml` muudatus on `git log -p`-s loetav |
| [5. YAML-viga ja -vvv](#5-yaml-viga-ja-vvv) | lihtne | taandeviga leitud, `-vvv`-st `ssh` käsk näidatud |
| [6. Faktide vahemälu ja ajakulu](#6-faktide-vahemalu-ja-ajakulu) | lihtne | faktide vahemälu sees, ajad README-s |
| [7. Rolli sisend argument_specs'iga](#7-rolli-sisend-argument_specsiga) | keskmine | vale sisend peatab Tomcati rolli enne paigaldust |
| [8. Galaxy roll RabbitMQ jaoks](#8-galaxy-roll-rabbitmq-jaoks) | keskmine | RabbitMQ tuleb Galaxy rolliga, võrdlus README-s |
| [9. Drift'i öine kontroll](#9-drifti-oine-kontroll) | keskmine | öine timer teatab drift'i Labori seisu |
| [10. Vana playbook kaasaegseks](#10-vana-playbook-kaasaegseks) | keskmine | vanast playbook'ist kahe distro idempotentne roll |
| [11. web01 Rockyle](#11-web01-rockyle) | keskmine | sama Nginxi roll töötab Ubuntul ja Rockyl |
| [12. Lühike sert ja uuendamine](#12-luhike-sert-ja-uuendamine) | raske | sert uueneb enne aegumist ilma katkestuseta |
| [13. Pull-mudel: ansible-pull](#13-pull-mudel-ansible-pull) | raske | mc01 seadistab end ise, saladusteta |
| [14. Molecule: rolli test omaette masinas](#14-molecule-rolli-test-omaette-masinas) | raske | `molecule test` läbib Rocky ja Ubuntu platvormi |
| [15. Andmebaasi parooli rotatsioon](#15-andmebaasi-parooli-rotatsioon-ilma-autentimisveata) | raske | DB parool vahetatud ilma ühegi `Access denied`-ita |
| [16. SSH hardening](#16-ssh-hardening-ilma-end-valja-lukustamata) | raske | sshd hardening tehtud, Ansible'i ühendus ei katkenud |
| [17. SELinux praktikas](#17-selinux-praktikas-oma-veebijuur-ja-port) | raske | vhost pordil 8090, SELinux jääb `Enforcing`-uks |
| [18. Ansible teenusena: Semaphore](#18-ansible-teenusena-semaphore) | raske | öine `--check` käib Semaphore'i ajakavas |
| [19. Sündmuspõhine koristus](#19-sundmuspohine-koristus-ketas-ule-90-ja-inimese-kinnitus) | raske | ketta häire, kinnitus, siis koristus |
| [Lisaprojekt: andmebaasi varukoopia ja taastamine](#lisaprojekt-andmebaasi-varukoopia-ja-taastamine) | raske | dump ja kontrollitud taastamine, vea korral eelmine seis tagasi |
| [20. vorgukogu Ansible'iga](#20-vorgukogu-ansibleiga-ad-hoc-ja-playbook) | keskmine | ruuterite kogumine Ansible'iga, sama väljund |
| [21. Cisco IOS XE ainult lugemiseks](#21-cisco-ios-xe-ainult-lugemiseks) | lihtne | IOS XE `show` Ansible'i ja Netmikoga |

Failid ja README laused lähevad kausta `k02-ansible/` ja läbivad ansible-linti, keskmised ja rasked ülesanded on GitHubi issue „`K2 edasijõudnu`" linnukesed (label `edasijõudnu`).

## Lihtsad ülesanded

### 1. Käsitsi muudatus ja fetch

**Tase:** lihtne · **Eeldus:** [Andmebaas ühe playbook'iga](lab-2-andmebaas.md)

Andmebaasi lehel kirjutas Ansible käsitsi muudetud konfifaili üle ja jättis varukoopia. Enne ülekirjutamist tahad näha, mida kolleeg käsitsi muutis, ja seda kõigilt hostidelt korraga.

- Too `ansible.builtin.fetch`-iga db01-st `/etc/my.cnf.d/60-labseis.cnf` kausta `scratch/fetch/`.
- Võrdle seda `diff`-iga sisuga, mida roll `mariadb` sinna kirjutab.
- Too sama käsuga `/etc/motd` kõigist viiest hostist.

**Kontroll:**

```bash
ansible db01 -m ansible.builtin.fetch -a 'src=/etc/my.cnf.d/60-labseis.cnf dest=scratch/fetch/'
find scratch/fetch -type f
find scratch/fetch -name motd | wc -l
```

**Valmis, kui:**

- fail on kaustas `scratch/fetch/db01/etc/my.cnf.d/`;
- `diff -u` oodatud sisu ja toodud faili vahel ei väljasta midagi või näitab käsitsi muudatust `-`/`+` ridadena;
- `find scratch/fetch -name motd | wc -l` annab `5`.

??? success "Lahendus"
    Roll `mariadb` kirjutab faili `copy` `content`-iga, nii et oodatud sisu saab kokku panna rolli tekstist ja hosti aadressist. `fetch` ilma `flat`-ita lisab tee ette hosti nime, seepärast võib sama käsku anda `all`-ile.

    ```bash
    ansible db01 -m ansible.builtin.fetch -a 'src=/etc/my.cnf.d/60-labseis.cnf dest=scratch/fetch/'
    ip=$(ansible-inventory --host db01 | jq -r .ansible_host)
    printf '# Ansible (labori-seis)\n[mysqld]\nbind-address = %s\n' "$ip" > scratch/fetch/oodatud.cnf
    diff -u scratch/fetch/oodatud.cnf scratch/fetch/db01/etc/my.cnf.d/60-labseis.cnf && echo "drift'i pole"
    ansible all -m ansible.builtin.fetch -a 'src=/etc/motd dest=scratch/fetch/' -o
    find scratch/fetch -name motd | wc -l
    ```

    Sama tulemus ilma failita: `ansible-playbook site.yml --limit db01 --check --diff` näitab rolli ja hosti vahet otse.

    Kontroll: `diff` väljastab `drift'i pole`, kui käsitsi muudatust pole (muidu `-`/`+` read), ja `find … | wc -l` annab `5`.

    **Miks nii.** `fetch` toob faili vastupidises suunas, sihtmasinast control node'i. Fail läheb kausta `scratch/fetch/<host>/<tee>`: iga host saab oma kausta, nii et sama fail viiest hostist ei kirjuta üksteist üle.

### 2. Play muutujad, list ja sõnastik

**Tase:** lihtne · **Eeldus:** [Rollid ja muutujad](lab-3-rollid.md)

Labori lehtedel kasutasid muutujaid peamiselt skalaaridena. Mallides ja tsüklites on muutujad sageli listid ja sõnastikud ning faktid on üks suur sõnastik.

- Lisa `scratch/prio.yml` play'le `vars:` alla `labseis_ports: [80, 8080, 11211, 5672, 3306]` ja `labseis_db: {host: db01, port: 3306}`.
- Lisa `vars_files: [extra.yml]`, kus failis `scratch/extra.yml` on `labseis_env: klass`.
- Väljasta `debug`-iga `labseis_ports[1]`, `labseis_db.host`, `labseis_db['port']` ja `labseis_env`.
- Väljasta samamoodi `ansible_facts['memory_mb']['real']['free']`.

**Kontroll:**

```bash
ansible-playbook scratch/prio.yml | grep -E '"msg"|free'
```

**Valmis, kui:**

- `msg` on `8080 db01 3306 klass`;
- teine rida näitab vaba mälu megabaitides;
- PLAY RECAP annab `failed=0`.

??? success "Lahendus"
    `vars_files` tee on suhteline playbook'i kausta suhtes, nii et `extra.yml` leitakse `scratch/`-ist. Faktide jaoks peab `gather_facts` olema sees. Punktiga kuju `labseis_db.host` on lühem, nurksulgudega kuju töötab ka siis, kui võti langeb kokku Pythoni sõnastiku meetodiga (`items`, `keys`, `values`) või sisaldab sidekriipsu.

    ```yaml
    - name: Listi, sõnastiku ja faktide ligipääs
      hosts: app01
      vars:
        labseis_ports: [80, 8080, 11211, 5672, 3306]
        labseis_db: {host: db01, port: 3306}
      vars_files: [extra.yml]
      tasks:
        - name: List, sõnastik kahel kujul ja vars_files
          ansible.builtin.debug:
            msg: "{{ labseis_ports[1] }} {{ labseis_db.host }} {{ labseis_db['port'] }} {{ labseis_env }}"

        - name: Vaba mälu (MB)
          ansible.builtin.debug:
            var: ansible_facts['memory_mb']['real']['free']
    ```

    Kontroll: `ansible-playbook scratch/prio.yml | grep -E '"msg"|free'` väljastab `"msg": "8080 db01 3306 klass"` ja rea `ansible_facts['memory_mb']['real']['free']` arvuga.

### 3. Rolli parameeter ja sammhaaval käivitus

**Tase:** lihtne · **Eeldus:** [Kogu stack](lab-4-stack.md)

Sama rolli kasutatakse sageli mitmes projektis eri väärtustega. Rolli parameeter annab väärtuse ühele rolli kasutusele, muutmata rolli ega inventory't.

- Muuda `site.yml`-is rakenduse play ajutiselt kujule `roles: [{role: tomcat, vars: {tomcat_heap: 640m}}]`.
- Käivita app01 peal `--check --diff` ja vaata unit-faili `-Xmx` rida: kumb võidab, rolli parameeter või `host_vars`?
- Pane `site.yml`-i tagasi `roles: [tomcat]`.
- Läbi web01 ülesanded `--step`-iga.

**Kontroll:**

```bash
ansible-playbook site.yml --limit app01 --check --diff | grep -E '^[-+].*Xmx'
git diff --quiet site.yml && echo tagasi
ansible-playbook site.yml --step --limit web01
```

**Valmis, kui:**

- `grep` väljastab unit-faili vana ja uue `-Xmx` rea;
- `git diff --quiet` järel tuleb `tagasi`;
- `--step` küsis iga web01 ülesande eel `(N)o/(y)es/(c)ontinue` ja play lõppes `failed=0`-ga.

??? success "Lahendus"
    Rolli `vars` on Ansible'i prioriteedis „role params" tasemel, `host_vars` on sellest madalamal ja ainult `set_fact`, `include_vars` ning `-e` on kõrgemal. Check'is muutub ainult unit-fail, sest `-Xmx` on ainult seal.

    ```yaml
    - name: Rakendus
      hosts: app
      roles:
        - role: tomcat
          vars:
            tomcat_heap: 640m
    ```

    ```bash
    ansible-playbook site.yml --limit app01 --check --diff | grep -E '^[-+].*Xmx'
    git checkout site.yml && git diff --quiet site.yml && echo tagasi
    ansible-playbook site.yml --step --limit web01
    ```

    Kontroll: `grep` väljastab kaks rida, `-…-Xmx512m"` ja `+…-Xmx640m"`, ning `git diff --quiet` järel tuleb `tagasi`.

    **Miks nii.** Rolli parameetri prioriteet on kõrgem kui `host_vars`-il, nii et teine projekt saab kasutada sama rolli teiste väärtustega rolli koodi muutmata. `--step` sobib võõra playbook'i esimeseks läbimiseks: näed iga ülesande nime enne, kui see midagi teeb.

### 4. Vaulti diff Gitis

**Tase:** lihtne · **Eeldus:** [Kontroll enne muudatust](lab-5-kontroll.md) · **Esita:** `.gitattributes` (repo juures)

Krüpteeritud faili muudatust ei saa PR-i ülevaatusel lugeda: diff näitab ainult heksaridu. Git oskab faili enne võrdlemist dekrüpteerida, kui annad talle selleks käsu. Dekrüpteeritud diff näitab paroole, nii et ekraani jagades seda ei kasutata.

- Seo `.gitattributes`-is `k02-ansible/group_vars/all/vault.yml` diff-draiveriga `ansible-vault`.
- Seadista draiveri `textconv` käsk `git config`-iga oma masinas.
- Commit'i `.gitattributes`.

**Kontroll:**

```bash
cd ~/labori-seis
git log -p -1 -- k02-ansible/group_vars/all/vault.yml | grep -E '^[-+]vault_'
git log -p -1 --no-textconv -- k02-ansible/group_vars/all/vault.yml | grep -cE '^[-+][0-9a-f]{80}$'
git log --oneline -1 -- .gitattributes
```

**Valmis, kui:**

- esimene `grep` väljastab `+vault_…` read nimede ja väärtustega;
- teine `grep` (ilma `textconv`-ita) annab nullist suurema arvu;
- `git log` näitab `.gitattributes`-i commit'i.

Vihje: Git käivitab `textconv` käsu repo juurest, mitte kaustast `k02-ansible/`.

??? success "Lahendus"
    Git käivitab `textconv` käsu repo juurkaustas ja annab faili ajutise failina. Seal pole `k02-ansible/ansible.cfg`-d, nii et paroolifail peab tulema keskkonnamuutujast `ANSIBLE_VAULT_PASSWORD_FILE`, mida `.bashrc` juba ekspordib. Käsud käivita repo juurest.

    ```bash
    cd ~/labori-seis
    echo 'k02-ansible/group_vars/all/vault.yml diff=ansible-vault' >> .gitattributes
    git config diff.ansible-vault.textconv 'ansible-vault view'
    git add .gitattributes && git commit -m 'K2 lisa: vault.yml diff loetavaks'
    git log -p -1 -- k02-ansible/group_vars/all/vault.yml | grep -E '^[-+]vault_'
    git log -p -1 --no-textconv -- k02-ansible/group_vars/all/vault.yml | grep -cE '^[-+][0-9a-f]{80}$'
    ```

    Kontroll: esimene `grep` väljastab `+vault_…` read nimede ja väärtustega, teine (ilma `textconv`-ita) loendab ainult heksaridu. Kui esimene `grep` ei väljasta midagi, puudub `ANSIBLE_VAULT_PASSWORD_FILE` sinu shellis.

    **Miks nii.** `.gitattributes` läheb Giti, `git config` jääb sinu masinasse. Kellel paroolifaili või `textconv` seadet pole, see näeb edasi heksaridu.

### 5. YAML-viga ja -vvv

**Tase:** lihtne · **Eeldus:** [Andmebaas ühe playbook'iga](lab-2-andmebaas.md)

YAML-viga on Ansible'is sage ja veateade osutab tihti valele reale. Tekitad vea meelega, loed teadet ja leiad `-vvv` väljundist käsu, millega Ansible hostiga ühendub.

- Nihuta `db.yml`-is ühe ülesande mooduli rida kaks tühikut vasakule, käivita `--syntax-check` ja vaata, kas teate reanumber on vea real. Paranda.
- Võrdle `-v`, `-vvv` ja `-vvvv` väljundit.
- Salvesta allolev playbook `scratch/ping.yml`-ina ja märgi iga rea juurde kommentaarina, kas see on list, map või skalaar.
- Lisa kolmas ülesanne, mis väljastab `kernel.stdout`-i (`ansible.builtin.debug`, `var:`).
- Mis muutub PLAY RECAP-is, kui eemaldad `changed_when: false`?

```yaml
---
- name: Kontroll
  hosts: rocky
  gather_facts: false
  tasks:
    - name: Ühendus
      ansible.builtin.ping:
    - name: Mis kernel
      ansible.builtin.command: uname -r
      register: kernel
      changed_when: false
```

**Kontroll:**

```bash
ansible-playbook db.yml --syntax-check
ansible-playbook scratch/ping.yml | grep -A2 'Kerneli versioon'
ansible-playbook scratch/ping.yml -vvv 2>&1 | grep -E 'ESTABLISH SSH CONNECTION|SSH: EXEC ssh' | head -2
```

**Valmis, kui:**

- vigase taandega andis `--syntax-check` veateate reanumbriga, parandatud failiga viga pole;
- igal `scratch/ping.yml` real on kommentaar;
- kolmas ülesanne väljastab kerneli versiooni;
- `-vvv` väljundist näitad rida `ESTABLISH SSH CONNECTION FOR USER: kasutaja` ja koostatud `ssh` käsku.

??? success "Lahendus"
    `ansible.builtin.ping:` ilma väärtuseta on map'i võti väärtusega `null`, mitte skalaar. Ilma `changed_when: false`-ita on `command` alati `changed`, sest Ansible ei tea, kas käsk midagi muutis.

    ```yaml
    ---
    - name: Kontroll                         # list (playbook) → element: map (play); väärtus skalaar
      hosts: rocky                           # skalaar
      gather_facts: false                    # skalaar (bool)
      tasks:                                 # list
        - name: Ühendus                      # list element: map (ülesanne)
          ansible.builtin.ping:              # map'i võti, väärtus null
        - name: Mis kernel                   # map
          ansible.builtin.command: uname -r  # skalaar (free-form argument)
          register: kernel                   # skalaar
          changed_when: false                # skalaar (bool)
        - name: Kerneli versioon             # map
          ansible.builtin.debug:             # map
            var: kernel.stdout               # skalaar
    ```

    ```bash
    ansible-playbook scratch/ping.yml | grep -A2 'Kerneli versioon'
    ansible-playbook scratch/ping.yml -vvv 2>&1 | grep -E 'ESTABLISH SSH CONNECTION|SSH: EXEC ssh' | head -2
    ```

    Kontroll: esimene käsk näitab `kernel.stdout: 5.14.0-…` (Rocky 9), teine `ESTABLISH SSH CONNECTION FOR USER: kasutaja` ja `SSH: EXEC ssh … -o User="kasutaja"` rea. Ilma `changed_when`-ita annab PLAY RECAP `changed=1` kummalgi Rocky hostil.

    **Miks nii.** Taandevea teade on "Syntax Error while loading YAML" või "conflicting action statements" koos reanumbriga. Viga on tavaliselt sellel real või vahetult enne, sest parser avastab vea seal, kus struktuur enam ei klapi. `-v` näitab mooduli tulemust, `-vvv` SSH käske ja `-vvvv` ühenduse detaile. Ühendusvea (vale kasutaja, vale võti, sudo puudub) leiad just `-vvv` `ssh` käsust. Playbook on list, mille element (play) on map, ja selle `tasks` on jälle list mapidest. Mooduli JSON-väljund on sama andmestruktuur teise kirjapildiga.

### 6. Faktide vahemälu ja ajakulu

**Tase:** lihtne · **Eeldus:** [Kogu stack](lab-4-stack.md) · **Esita:** `ansible.cfg`

Viie hostiga on faktide kogumine märkamatu, viiesaja hostiga muudab see iga käivituse aeglaseks. Faktid kogutakse vaikimisi iga play alguses.

- Lülita `ansible.cfg`-s sisse ülesannete aja callback (`callbacks_enabled = ansible.posix.profile_tasks`) ja mõõda `site.yml` teise käivituse aeg.
- Lisa faktide vahemälu (`gathering = smart`, `fact_caching = jsonfile`, `fact_caching_connection = scratch/facts`, `fact_caching_timeout = 3600`) ja mõõda uuesti.
- Proovi ühel play'l `gather_subset: [min, network]`.
- Kirjuta README-sse kolme käivituse ajad, viis kõige aeglasemat ülesannet ja üks juhtum, kus vahemälu annab vale vastuse.

**Kontroll:**

```bash
time ansible-playbook site.yml > /dev/null
time ansible-playbook site.yml | tail -25
ls scratch/facts | wc -l
```

**Valmis, kui:**

- `ls scratch/facts | wc -l` annab `5`;
- vahemäluga käivitus on ilma vahemäluta käivitusest kiirem;
- `profile_tasks` väljastab lõpus ülesanded kestuse järjekorras;
- README-s on ajad, viis ülesannet ja vale vastuse juhtum.

??? success "Lahendus"
    `site.yml`-i viis rollide play'd koguvad vaikimisi (`gathering = implicit`) igaüks faktid uuesti. `smart` koos vahemäluga jätab need vahele, kui hosti faktid on vahemälus. Esimese play `ansible.builtin.setup` on ülesanne, mitte `gather_facts`, ja käivitub alati: see värskendab vahemälu iga `site.yml`-i alguses.

    ```ini
    [defaults]
    callbacks_enabled = ansible.posix.profile_tasks
    gathering = smart
    fact_caching = jsonfile
    fact_caching_connection = scratch/facts
    fact_caching_timeout = 3600
    ```

    ```bash
    time ansible-playbook site.yml > /dev/null                 # 1: ilma vahemäluta (callback sees)
    time ansible-playbook site.yml > /dev/null                 # 2: vahemäluga, esimene täidab
    time ansible-playbook site.yml | tail -25                  # 3: vahemäluga; profile_tasks väljastab aeglaseimad
    ls scratch/facts | wc -l
    ```

    Vale vastus: `verify.yml` loeb `ansible_local.deploy.version` vahemälust. Kui `deploy.yml` vahetas versiooni ja vahemälu on vana, võrdleb verify vana versiooni. Lahendus on `--flush-cache` või `setup` ülesanne pärast deploy'd.

    Kontroll: `ls scratch/facts | wc -l` annab `5`, kolmas käivitus on teisest kiirem ja `profile_tasks` väljastab lõpus ülesanded kestuse järjekorras.

## Keskmised ülesanded

### 7. Rolli sisend argument_specs'iga

**Tase:** keskmine · **Eeldus:** [Deploy ja rolling](lab-6-deploy.md) · **Esita:** `roles/tomcat/meta/argument_specs.yml`

Rolli `tomcat` sisendi kontroll on praegu käsitsi kirjutatud `assert` ja iga uus muutuja vajab uut rida. Ansible kontrollib rolli sisendit ise, kui rollil on fail `meta/argument_specs.yml`: seal on iga muutuja tüüp, `required`, lubatud väärtused ja kirjeldus, ja kontroll käib enne rolli esimest ülesannet.

- `tomcat_heap` on `required` string mustriga `^[0-9]+[mg]$`.
- `tomcat_port`, `tomcat_health_retries` ja `tomcat_health_delay` on täisarvud.
- Vale sisend (`-e tomcat_heap=palju`, `-e tomcat_port=http`) peatab play enne ühtki paigaldusülesannet arusaadava veaga.
- `ansible-lint` on puhas, vajadusel on `meta/main.yml` minimaalse sisuga.
- README-s on lause: mida `argument_specs` teeb paremini kui `assert` ja mida mitte.

**Kontroll:**

```bash
ansible-playbook site.yml --limit app01 -e tomcat_port=http 2>&1 | grep -E 'TASK \[tomcat|fatal'
ansible-playbook site.yml --limit app01 -e tomcat_heap=palju 2>&1 | grep -E 'TASK \[tomcat|fatal'
ansible-playbook site.yml --limit app01 | grep changed=
ansible-doc -t role -r roles tomcat | head -20
```

**Valmis, kui:**

- mõlemad vale sisendiga käivitused peatuvad `fatal` reaga enne ühtki Tomcati paigaldusülesannet;
- õige sisendiga annab teine käivitus `changed=0`;
- `ansible-doc -t role` näitab nelja muutujat koos kirjeldusega;
- lint on puhas ja README lause on olemas.

??? success "Lahendus"
    `argument_specs` kontrollib tüüpi, `required`-it ja `choices`-it, aga mustrit (regulaaravaldist) mitte. Seepärast jääb `tomcat_heap` kuju kontroll `assert`-iks rolli esimese ülesandena. Ansible lisab rolli algusesse ülesande "Validating arguments against arg spec main", mis on alati `ok` ega riku `changed=0`-i. `deploy.yml` kasutab `tasks_from: deploy`, mida `main` spec ei kata.

    ```yaml
    # roles/tomcat/meta/argument_specs.yml
    ---
    argument_specs:
      main:
        short_description: Tomcat 10.1, systemd unit ja Labori seisu WAR
        options:
          tomcat_heap:
            type: str
            required: true
            description: Java -Xmx, nt 512m või 1g. Kuju kontrollib assert rolli alguses.
          tomcat_port:
            type: int
            description: HTTP port, kuhu Nginxi upstream ühendub.
          tomcat_health_retries:
            type: int
            description: Mitu korda deploy /version vastust ootab.
          tomcat_health_delay:
            type: int
            description: Paus sekundites kahe katse vahel.
    ```

    ```yaml
    # roles/tomcat/tasks/main.yml, esimene ülesanne
    - name: Rolli sisend, tomcat_heap kuju
      ansible.builtin.assert:
        that: tomcat_heap is match('^[0-9]+[mg]$')
        fail_msg: "tomcat_heap={{ tomcat_heap }}: oodatud nt 512m või 1g"
        quiet: true
    ```

    ```bash
    ansible-playbook site.yml --limit app01 -e tomcat_port=http 2>&1 | grep -E 'TASK \[tomcat|unable to convert'
    ansible-playbook site.yml --limit app01 -e tomcat_heap=palju 2>&1 | grep -E 'fatal|oodatud'
    ansible-playbook site.yml --limit app01 | grep changed=
    ansible-doc -t role -r roles tomcat | head -20
    ```

    Kontroll: `tomcat_port=http` peatub ülesandes `tomcat : Validating arguments against arg spec main` teatega "unable to convert to int", `tomcat_heap=palju` peatub `assert`-is enne ühtki paigaldusülesannet, õige sisendiga annab teine käivitus `changed=0`.

### 8. Galaxy roll RabbitMQ jaoks

**Tase:** keskmine · **Eeldus:** [Kontroll enne muudatust](lab-5-kontroll.md) · **Esita:** `requirements.yml`, `site.yml`

Iga meeskond otsustab, kas kirjutada roll ise või võtta valmis roll ja selle hooldus kellegi teise käest. Siin võrdled oma rolli `rabbitmq` Galaxy rolliga `geerlingguy.rabbitmq`.

- Lisa `geerlingguy.rabbitmq` `requirements.yml`-i `roles:` alla lukustatud versiooniga.
- Loe enne läbi rolli `defaults/main.yml` ja `tasks/`.
- Asenda `site.yml`-is oma rolli paigaldusosa Galaxy rolliga.
- Kirjuta README-sse, mis muutujad tuli üle kirjutada, mis on teisiti kui sinu rollis, kumba eelistad ja miks.

**Kontroll:**

```bash
ansible-galaxy install -r requirements.yml
ansible-playbook site.yml --limit queue && ansible-playbook site.yml --limit queue | grep changed=
ssh rmq01 'apt-cache policy rabbitmq-server | head -4'
ansible-playbook verify.yml | tail -6
```

**Valmis, kui:**

- teine `--limit queue` käivitus annab `changed=0`;
- `apt-cache policy` näitab installitud versiooni ja selle allikat;
- `verify.yml` annab `failed=0`;
- README-s on võrdlus.

??? success "Lahendus"
    `geerlingguy.rabbitmq` paigaldab RabbitMQ ja Erlangi RabbitMQ enda apt-repost ja lukustab versiooni `rabbitmq_version` muutujaga. Kasutajaid, vhost'e ega pluginaid see ei halda. Need jäävad sinu rolli `community.rabbitmq` ülesanneteks. Roll kirjutab `sources.list.d`-sse uue repo, nii et Ubuntu paketi asemel tuleb upstream'i pakett ja selle versioon sõltub nüüd rolli vaikeväärtusest, mitte distrost.

    ```yaml
    # requirements.yml, lisaks collections: plokile
    roles:
      - name: geerlingguy.rabbitmq
        version: "<kinnita git tag, mille läbi lugesid>"
    ```

    ```yaml
    # site.yml
    - name: Järjekord
      hosts: queue
      roles:
        - role: geerlingguy.rabbitmq
        - role: rabbitmq   # plugin, kasutaja, guest, API kontroll; apt-ülesanne on nüüd ok
    ```

    ```bash
    ansible-galaxy install -r requirements.yml
    ansible-playbook site.yml --limit queue && ansible-playbook site.yml --limit queue | grep changed=
    ssh rmq01 'apt-cache policy rabbitmq-server | head -4'
    ansible-playbook verify.yml | tail -6
    ```

    Kontroll: teine `--limit queue` käivitus annab `changed=0`, `apt-cache policy` näitab installitud versiooni allikaks RabbitMQ repot ja verify on `failed=0`. Kontrollimata: kas rolli vaikimisi repo toetab Ubuntu 24.04 koodnime ja kas olemasolev Ubuntu pakett vahetub upstream'i oma vastu ilma `rabbitmq_version` muutujata. Mõlemad on README võrdluse sisu.

### 9. Drift'i öine kontroll

**Tase:** keskmine · **Eeldus:** [Kontroll enne muudatust](lab-5-kontroll.md)

Drift'i katses jäi käsitsi muudatus märkamata, kuni restart selle välja tõi. Öine kontroll leiab sellise muudatuse enne restarti.

- Control node'i systemd timer käivitab kord ööpäevas skripti `scratch/drift.sh`, mis käivitab `site.yml`-i `--check`-iga.
- Skript loeb PLAY RECAP-ist iga hosti `changed` väärtuse, kirjutab tulemuse journald-isse (`logger -t labseis-drift`) ja saadab Labori seisu `../scripts/labseis-report.sh lab-02 drift OK` või `FAIL` koos hostide nimedega.
- Skript ei muuda hoste ega pane väljundisse saladusi.
- Tee mc01-s käsitsi muudatus, käivita `labseis-drift.service` käsitsi ja vaata Labori seisu.
- README-s on lause, miks kontroll käivitub `--check`-iga, mitte ilma selleta.

**Kontroll:**

```bash
systemctl --user start labseis-drift.service; journalctl -t labseis-drift -n 1 --no-pager
systemctl --user list-timers labseis-drift.timer --no-pager
shellcheck -S warning scratch/drift.sh && echo puhas
```

**Valmis, kui:**

- puhtal stackil on Labori seisus `drift OK`;
- käsitsi muudatuse järel on Labori seisus `drift FAIL mc01`;
- `journalctl -t labseis-drift` näitab mõlemat käivitust;
- `list-timers` näitab järgmist käivitust ja `shellcheck` väljastab `puhas`.

??? success "Lahendus"
    `--check` lõpeb koodiga 0 ka siis, kui muudatusi leiti, seepärast tuleb drift PLAY RECAP-ist. Host, mis on `unreachable` või `failed`, ei ole „driftita": see on eraldi `FAIL`. Käivitus ilma `--check`-ita parandaks drift'i öösel ilma muudatuse kirjeta ja taaskäivitaks teenused, `--check` ainult teatab. Timer'il pole `.bashrc`-d, nii et `PATH`, Vaulti paroolifail ja token antakse unit'is.

    ```bash
    #!/usr/bin/env bash
    # Öine drift'i kontroll: site.yml --check, tulemus journald-isse ja Labori seisu. Ei muuda hoste.
    set -euo pipefail
    cd "$(dirname "$0")/.."
    report="$(git rev-parse --show-toplevel)/scripts/labseis-report.sh"
    out=$(mktemp)
    trap 'rm -f "$out"' EXIT

    rc=0
    ansible-playbook site.yml --check > "$out" 2>&1 || rc=$?
    recap=$(sed -n '/^PLAY RECAP/,$p' "$out")
    drift=$(awk '$2 == ":" && / changed=[1-9]/ {print $1}' <<< "$recap" | paste -sd, -)
    broken=$(awk '$2 == ":" && / (unreachable|failed)=[1-9]/ {print $1}' <<< "$recap" | paste -sd, -)

    if [[ -n "$broken" ]]; then status=FAIL msg="kontroll ei jõudnud lõpuni: $broken"
    elif [[ $rc -ne 0 ]]; then status=FAIL msg="ansible-playbook kood $rc, RECAP-i pole"
    elif [[ -n "$drift" ]]; then status=FAIL msg="$drift"
    else status=OK msg="drift'i pole"
    fi

    logger -t labseis-drift "$status $msg"
    if [[ -n "${LABSEIS_TOKEN:-}" ]]; then
        bash "$report" lab-02 drift "$status" "$msg" > /dev/null || logger -t labseis-drift "saatmine ebaõnnestus"
    fi
    echo "drift $status $msg"
    [[ "$status" == OK ]]
    ```

    ```ini
    # ~/.config/systemd/user/labseis-drift.service
    [Service]
    Type=oneshot
    WorkingDirectory=%h/labori-seis/k02-ansible
    Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
    Environment=ANSIBLE_VAULT_PASSWORD_FILE=%h/.config/is1/vault_pass
    EnvironmentFile=-%h/labori-seis/k01-bash/secrets.env
    ExecStart=%h/labori-seis/k02-ansible/scratch/drift.sh
    TimeoutStartSec=900

    # ~/.config/systemd/user/labseis-drift.timer
    [Timer]
    OnCalendar=*-*-* 03:15
    RandomizedDelaySec=15min
    Persistent=true

    [Install]
    WantedBy=timers.target
    ```

    ```bash
    systemctl --user daemon-reload && systemctl --user enable --now labseis-drift.timer
    systemctl --user start labseis-drift.service; journalctl -t labseis-drift -n 1 --no-pager
    ssh mc01 "sudo sed -i 's/^OPTIONS=.*/OPTIONS=\"-l 127.0.0.1\"/' /etc/sysconfig/memcached"
    systemctl --user start labseis-drift.service; journalctl -t labseis-drift -n 1 --no-pager
    shellcheck -S warning scratch/drift.sh && echo puhas
    ```

    Kontroll: esimene `journalctl` näitab `OK drift'i pole`, teine `FAIL mc01`, `shellcheck` väljastab `puhas`. Teenus jääb drift'i korral olekusse `failed` nagu `labseis-check`, nii et `systemctl --user --failed` näitab seda ka ilma Labori seisuta. Paranda lõpuks `ansible-playbook site.yml --limit cache`-iga.

### 10. Vana playbook kaasaegseks

**Tase:** keskmine · **Eeldus:** [Rollid ja muutujad](lab-3-rollid.md) · **Esita:** `roles/tomcat_vana/`

Paljudes organisatsioonides on kood kirjutatud aastaid tagasi ja töötab ainult masinatel, mida enam pole. Samu tüüpvigu leiad internetist ja AI vastustest. Koolitajalt saad vanema Tomcati playbook'i CentOS 6/7 ajastust.

- Leia vähemalt viis viga, mis takistavad playbook'i töötamist Ubuntu 24.04-l ja Rocky 9-l või on turvarisk.
- Paranda vead ja tee playbook'ist roll `roles/tomcat_vana`.
- Käivita roll Ubuntu 24.04 ja Rocky 9 peal kaks korda.
- Kirjuta README-sse viis parandust koos põhjustega.

**Kontroll:**

```bash
ansible-playbook -i '<ubuntu IP>,<rocky IP>,' scratch/vana.yml | grep changed=
ansible all -i '<ubuntu IP>,<rocky IP>,' -m ansible.builtin.uri -a 'url=http://localhost:8080/ status_code=200,404'
ansible-lint roles/tomcat_vana
```

**Valmis, kui:**

- teine käivitus annab mõlemal hostil `changed=0`;
- `uri` on mõlemal hostil `ok`;
- `ansible-lint` on puhas;
- README-s on viis parandust põhjustega.

Vihje: otsi stringivõrdlusi, distro nimega tingimusi, init-süsteemi, failiõigusi ja URL-e.

??? success "Lahendus"
    Iga parandus asendab eelduse („host on CentOS", „init on SysV") faktiga või distro muutujaga. Distro erinevused lähevad `vars/Debian.yml` ja `vars/RedHat.yml` faili, ülesanded jäävad samaks. Tomcat 8.5 → 10.1 tähendab ka `javax.*` → `jakarta.*`: vana WAR 10.1-l ei käivitu, see on rakenduse, mitte Ansible'i töö.

    | Vana | Uus | Miks |
    |---|---|---|
    | `when: ansible_distribution_version > '6'` | `when: ansible_facts['distribution_major_version'] is version('8', '>=')` | stringina on `'10' > '8'` väär |
    | `when: ansible_distribution == 'CentOS'` | `include_vars: "{{ ansible_facts['os_family'] }}.yml"` | Rocky, Alma ja RHEL on `RedHat` perekond |
    | `/etc/init.d/tomcat` + `service` | `template` → `/etc/systemd/system/tomcat.service`, `systemd_service` `daemon_reload: true` | SysV skripti systemd ainult emuleerib, `Restart=` ja cgroup'i pole |
    | unit-fail `mode: a+x` | `mode: "0644"` | systemd hoiatab "marked executable"; unit pole programm |
    | `shell: /bin/nologin` | `/usr/sbin/nologin` | Ubuntul `/bin/nologin` puudub (`/usr/sbin/nologin` on mõlemal) |
    | `get_url: url=http://user:parool@…` | `url_username`, `url_password` Vaultist, `no_log: true` | URL koos parooliga läheb `-v` väljundisse ja `ansible.log`-i |
    | `shell: cp -r …` | `unarchive` `creates:`-iga või `copy` `remote_src: true` | `shell` on alati `changed` ja kirjutab igal käivitusel üle |
    | JDK 8, Tomcat 8.5 | OpenJDK 21, Tomcat 10.1 | 8.5 toetus on lõppenud |

    ```yaml
    # roles/tomcat_vana/vars/Debian.yml
    tomcat_java_package: openjdk-21-jre-headless
    tomcat_java_home: /usr/lib/jvm/java-21-openjdk-amd64
    # roles/tomcat_vana/vars/RedHat.yml
    tomcat_java_package: java-21-openjdk-headless
    tomcat_java_home: /usr/lib/jvm/jre-21-openjdk
    ```

    ```bash
    ansible-playbook -i '<ubuntu IP>,<rocky IP>,' scratch/vana.yml && ansible-playbook -i '<ubuntu IP>,<rocky IP>,' scratch/vana.yml | grep changed=
    ansible all -i '<ubuntu IP>,<rocky IP>,' -m ansible.builtin.uri -a 'url=http://localhost:8080/ status_code=200,404'
    ansible-lint roles/tomcat_vana
    ```

    Kontroll: teine käivitus annab mõlemal hostil `changed=0`, `uri` on mõlemal `ok` ja lint on puhas. Rocky `JAVA_HOME`-i kinnita hostis käsuga `readlink -f "$(command -v java)"`. Kontrollimata: koolitaja vana playbook pole selle repo osa, tabel katab tüüpvead, mida sellistes playbook'ides leidub.

### 11. web01 Rockyle

**Tase:** keskmine · **Eeldus:** [Kogu stack](lab-4-stack.md) · **Esita:** `roles/nginx/`

Organisatsioon vahetab distributsiooni ja sama Nginxi roll peab töötama mõlemal. web01-l pole andmeid, mida `site.yml` uuesti ei looks.

- Tee snapshot ja vaheta web01 Rocky malli vastu (või kasuta lisa-VM-i).
- `inventory.ini` jääb muutmata (automaatne hindaja kontrollib seda): koopias `scratch/inventory-rocky.ini` on `web` grupi `rocky:children` all.
- Eemalda rollist Ubuntu `assert` ja vii distro erinevused `vars/RedHat.yml`-i ja `vars/Debian.yml`-i.
- Rockyl läheb sait kausta `conf.d/`, firewalld-is on lahti pordid 80 ja 443 ning SELinuxi boolean `httpd_can_network_connect` on sees (`ansible.posix.seboolean`).
- Pärast snapshot'i taastamist töötab sama roll edasi Ubuntul.

**Kontroll:**

```bash
ansible-playbook -i scratch/inventory-rocky.ini site.yml --limit web01
curl -s http://web01/health; echo
ssh web01 'sudo ausearch -m avc -ts recent 2>&1 | tail -2; sudo getsebool httpd_can_network_connect'
ansible-playbook site.yml --limit web01 | grep changed=     # pärast snapshot'i tagasi Ubuntul
```

**Valmis, kui:**

- Rocky web01-l annab `curl http://web01/health` `UP`;
- `getsebool` annab `on` ja `ausearch` `<no matches>`;
- Ubuntu web01 teine käivitus annab `changed=0`.

Vihje: 502 Rockyl on tavaliselt SELinuxi keeld, `ausearch -m avc -ts recent` näitab seda.

??? success "Lahendus"
    Kolm erinevust: saidi faili koht (`conf.d/` ilma sümlingita), SELinux (Nginx `httpd_t` ei tohi vaikimisi pordile 8080 ühenduda) ja Rocky `nginx.conf`-i oma `server` plokk. Kui see on märgitud `default_server`, annab täis-`nginx -t` (handler `Test nginx`) vea "duplicate default server". `validate` seda ei näe, sest kontrollib saidi faili eraldi. Ubuntu renderdus ei muutu, nii et Ubuntul jääb `changed=0`. Tulemüür tuleb rollist `common` grupimuutujast.

    ```yaml
    # roles/nginx/vars/Debian.yml
    nginx_site_file: /etc/nginx/sites-available/labori-seis
    nginx_site_link: /etc/nginx/sites-enabled/labori-seis
    # roles/nginx/vars/RedHat.yml
    nginx_site_file: /etc/nginx/conf.d/labori-seis.conf
    nginx_site_link: ""
    # group_vars/web.yml
    labseis_fw_ports: {http: 80/tcp, https: 443/tcp}
    ```

    ```yaml
    # roles/nginx/tasks/main.yml: assert ja apt asenduvad nendega
    - name: OS-i muutujad
      ansible.builtin.include_vars:
        file: "{{ ansible_facts['os_family'] }}.yml"

    - name: Nginx
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Distro server-plokk pole default_server (Rocky)
      ansible.builtin.replace:
        path: /etc/nginx/nginx.conf
        regexp: '^(\s*listen\s+\S*80)\s+default_server;'
        replace: '\1;'
      when: ansible_facts['os_family'] == "RedHat"
      notify: [Test nginx, Reload nginx]

    - name: Nginx tohib upstream'i ühenduda (SELinux)
      ansible.posix.seboolean:
        name: httpd_can_network_connect
        state: true
        persistent: true
      when: ansible_facts['selinux']['status'] | default('disabled') == 'enabled'

    # "Saidi seadistus": dest: "{{ nginx_site_file }}"
    # "Sait sisse" ja "Vaikesait välja": when: nginx_site_link | length > 0, src/dest muutujatest
    ```

    ```bash
    ansible-playbook -i scratch/inventory-rocky.ini site.yml --limit web01
    curl -s http://web01/health; echo
    ssh web01 'sudo ausearch -m avc -ts recent 2>&1 | tail -2; sudo getsebool httpd_can_network_connect'
    ansible-playbook site.yml --limit web01 | grep changed=     # pärast snapshot'i tagasi Ubuntul
    ```

    Kontroll: Rocky web01-l on `/health` `{"status":"UP",…}`, `getsebool` annab `on` ja `ausearch` `<no matches>`. Pärast snapshot'i taastamist annab Ubuntu web01 teine käivitus `changed=0`. Lisa `module_defaults` `ansible.builtin.dnf: {lock_timeout: 120}` ka play'le "Veebiserver", sest `package` ei anna `lock_timeout`-i edasi. Kontrollimata: Rocky 9 `nginx.conf`-i täpne `listen` rida ja `/etc/ssl/labori-seis` SELinuxi kontekst (siin polnud Rocky VM-i); `ausearch` näitab mõlemat.

## Rasked ülesanded

### 12. Lühike sert ja uuendamine

**Tase:** raske · **Eeldus:** [Tsüklid, mallid ja TLS](lab-7-tsuklid-tls.md) · **Esita:** `renew-cert.yml`

`verify.yml` kontrollib serdi aegumist, aga keegi peab serdi ka õigel ajal uuendama, ilma et kasutaja katkestust näeks. Kirjuta `renew-cert.yml`, mis uuendab web-hostide serdi, kui see aegub vähem kui `renew_before_days` (vaikimisi `30`) päeva pärast.

- Otsus tehakse serdi järgi, mida port 443 näitab, mitte control node'i faili järgi.
- Web-hoste võib olla mitu: korraga uueneb üks ja ebaõnnestunud host peatab ülejäänud.
- Katkestust ei tohi olla: avatud ühendused jäävad avatuks.
- CA võti ei lahku control node'ist ja serveri võti ei muutu.
- Playbook kontrollib lõpus ise, et port 443 näitab uut serti.

**Kontroll:**

```bash
# algseis: web01-l kahepäevane sert, verify.yml ebaõnnestub
rm ~/.config/is1/pki/web01.crt
ansible-playbook site.yml --limit web --tags tls -e nginx_cert_not_after=+2d
# teises terminalis kogu katse ajal
while sleep 1; do curl -s -o /dev/null -w '%{http_code}\n' --cacert ~/.config/is1/pki/ca.crt https://web01/health; done
# uuendus, kaks korda
ansible-playbook renew-cert.yml && ansible-playbook renew-cert.yml | grep changed=
ansible-playbook verify.yml | tail -6
ansible-playbook site.yml | grep changed=
```

**Valmis, kui:**

- kahepäevane sert asendub ühe käivitusega 90-päevasega ja teine käivitus annab `changed=0`;
- teise terminali väljundis pole ühtki mitte-200 rida;
- `verify.yml` on roheline ja `site.yml` annab `changed=0`;
- README-s on lause, miks uuendus käib kuu enne aegumist, mitte aegumise päeval.

??? tip "Lahenduse suund"
    **Põhiidee:** loe kehtivus pordist, otsusta tingimusega, allkirjasta uuesti sama CSR-iga ja tee reload.

    **Mehhanism ja moodulid:** `community.crypto.get_certificate` (`delegate_to: localhost`, `ca_cert`) annab serdi, mida klient näeb. `x509_certificate_info` `valid_at: {piisav: "+30d"}` annab tõeväärtuse. `x509_certificate` `provider: ownca` vajab `force: true`-d, sest moodul ei vaata aegumist (`ignore_timestamps`). Hosti läheb ainult `.crt` ja handlerid `Test nginx` → `Reload nginx` on play'l endal. `serial: 1` ja `max_fail_percentage: 0` piiravad korraga muutuvaid hoste. Reload'i ajal loeb Nginxi master serdi uuesti, uued worker'id võtavad uued ühendused ja vanad lõpetavad avatud ühendused vana serdiga.

    **Kontroll:** sama `get_certificate` + `valid_at` pärast `flush_handlers`-it ja `assert`. Seejärel `renew-cert.yml` teist korda (`changed=0`), `verify.yml` ja `site.yml` (`changed=0`: rolli `x509_certificate` ilma `force`-ita 90-päevast serti ei lühenda).

    **Tüüpilised lõksud:** `force: true` ilma tingimuseta (iga käivitus teeb uue serdi ja reload'i), `restarted` `reloaded`-i asemel (teises terminalis `000`), otsus control node'i faili järgi (kui eelmine katse katkes pärast allkirjastamist, on fail uus ja host vana).

### 13. Pull-mudel: ansible-pull

**Tase:** raske · **Eeldus:** [Rollid ja muutujad](lab-3-rollid.md) · **Esita:** `pull/cache.yml`

Control node ei näe alati kõiki hoste (eri võrgud, sülearvutid, ajutised masinad) ja host peab end ise seadistama. `ansible-pull` kloonib repo sihtmasinas ja käivitab playbook'i seal. Pane mc01 iga 15 minuti järel käivitama rolli `memcached` repost (haru `k02-ansible`) systemd timer'iga `labseis-pull`.

- mc01 ei saa ühtki saladust: Vaulti parool ega dekrüpteeritud `vault.yml` ei jõua mc01-le.
- mc01 loeb repot ainult lugemisõigusega võtmega.
- mc01 Ansible tuleb Rocky AppStream'ist ja on vanem kui control node'i 2.21: roll peab töötama mõlemaga.
- Push (`site.yml` control node'ist) ja pull ei tohi samal ajal sama faili kirjutada.
- Viiekümne hosti timer'id ei tohi kloonida sama sekundi peal.

**Kontroll:**

```bash
ssh mc01 'sudo systemctl start labseis-pull.service; sudo journalctl -u labseis-pull -n 5 --no-pager'
ssh mc01 "sudo sed -i 's/^OPTIONS=.*/OPTIONS=\"-l 127.0.0.1\"/' /etc/sysconfig/memcached"
# timer'i järgmise käivituse järel
ssh mc01 'grep ^OPTIONS /etc/sysconfig/memcached; sudo journalctl -u labseis-pull -n 5 --no-pager'
ssh mc01 'systemctl show labseis-pull.service -p Environment'
```

**Valmis, kui:**

- käsitsi muudatus kaob timer'i järgmisel käivitusel ilma control node'ita;
- `journalctl -u labseis-pull` näitab selle käivituse `changed=1`;
- mc01-s pole Vaulti paroolifaili ega `ANSIBLE_VAULT_PASSWORD_FILE` muutujat;
- README-s on kirjas, mida mc01 nüüd vajab, mida push-mudelis polnud, ja miks `--only-if-changed` siia ei sobi.

??? tip "Lahenduse suund"
    **Põhiidee:** pull-playbook on eraldi kaustas, kus pole `group_vars/`-i, ja roll tuleb repo `roles/` kaustast.

    **Mehhanism:** Ansible laeb `group_vars/` playbook'i ja inventory kaustast. Kui `pull-cache.yml` on `k02-ansible/` juures, loetakse ka `group_vars/all/vault.yml` ja dekrüpteerimine ebaõnnestub ilma paroolita. Playbook kausta `k02-ansible/pull/` ja unit'is `Environment=ANSIBLE_ROLES_PATH=<checkout>/k02-ansible/roles`. `ansible-pull --url … --checkout k02-ansible --directory /var/lib/labseis-pull --private-key … --accept-host-key -i localhost, k02-ansible/pull/cache.yml`. Play: `hosts: localhost`, `connection: local`, `roles: [memcached]`.

    **Tööriistad:** `dnf install ansible-core git-core` (AppStream annab 2.14 seeria), `community.crypto.openssh_keypair` mc01-s ja avalik võti GitHubi Deploy keys alla ilma kirjutusõiguseta, `flock /run/labseis-ansible.lock` unit'i `ExecStart`-is (push võtab sama luku), timer'is `OnUnitActiveSec=15min` ja `RandomizedDelaySec`. Rolli `memcached` ülesanded on ainult `ansible.builtin` moodulid, nii et kollektsioone mc01-le vaja pole.

    **Kontroll:** `ssh mc01 'sudo systemctl start labseis-pull.service; sudo journalctl -u labseis-pull -n 5'` → `changed=0`; käsitsi muudatus → `/health` `"cache":"DOWN"` → järgmine käivitus → `grep ^OPTIONS` näitab mc01 IP-d.

    **Tüüpilised lõksud:** `--only-if-changed` (playbook käivitub ainult uue commit'i peale ja käsitsi muudatus jääb alles), kirjutusõigusega deploy-võti, unit ilma `ANSIBLE_ROLES_PATH`-ita ("the role 'memcached' was not found").

### 14. Molecule: rolli test omaette masinas

**Tase:** raske · **Eeldus:** [Kontroll enne muudatust](lab-5-kontroll.md) · **Esita:** `roles/memcached/molecule/default/`

`verify.yml` testib kogu stacki labori hostides. Kui muudad ühte rolli ja tahad teada, kas see töötab mõlemal distributsioonil, ilma et puudutaksid labori stacki, vajad rolli jaoks eraldi masinat. [Molecule](https://ansible.readthedocs.io/projects/molecule/) loob selle, käivitab rolli, kontrollib ja kustutab masina.

- Paigalda `pipx inject ansible-core molecule` ja tee rollile `memcached` stsenaarium `molecule/default/` (`molecule.yml`, `converge.yml`, `verify.yml`).
- Samas stsenaariumis on kaks platvormi, Rocky 9 ja Ubuntu 24.04: `vars/RedHat.yml` ja `vars/Debian.yml` peavad mõlemad olema õiged.
- Teenus käivitub systemd kaudu, mitte konteineri `CMD`-na.
- Verify kontrollib, et Memcached kuulab masina IP-l ja seadistusrida on distro õiges failis, mitte ainult et teenus on `running`.
- Masin on Dockeri konteiner (pärast 3. kohtumist) või Proxmoxi lisa-VM delegeeritud draiveriga.

**Kontroll:**

```bash
cd roles/memcached
molecule test; echo "kood $?"
```

**Valmis, kui:**

- `molecule test` lõpeb koodiga `0`;
- converge, idempotence ja verify samm läbivad mõlemal platvormil;
- README-s on kirjas, millise rolli varjatud sõltuvuse Molecule välja tõi.

??? tip "Lahenduse suund"
    **Põhiidee:** konteiner, mille PID 1 on systemd, ja verify, mis loeb distrospetsiifilist faili.

    **Tööriistad:** `molecule-plugins[docker]` ja `community.docker` control node'is. Platvormid image'itest, kus systemd ja Python on olemas (näiteks `geerlingguy/docker-rockylinux9-ansible`, `geerlingguy/docker-ubuntu2404-ansible`), `command: ""`, `privileged: true`, `cgroupns_mode: host`, volume `/sys/fs/cgroup:/sys/fs/cgroup:rw`. Tavalises `rockylinux:9` image'is ebaõnnestub `service` "System has not been booted with systemd" veaga.

    **Varjatud sõltuvus:** värskes Ubuntu konteineris on apt vahemälu tühi. Laboris teeb `update_cache` roll `common`, rollis `memcached` seda pole. `converge.yml` vajab `pre_tasks`-is `apt update_cache`-i või roll oma ülesannet.

    **Kontroll:** verify: `service_facts` (`running`, `enabled`), `wait_for` `ansible_facts['default_ipv4']['address']`:11211, `grep -c -- '-l <IP>'` distro failis `failed_when` tingimusega. `molecule test --destroy never` ja `molecule login -h <platvorm>` silumiseks.

    **Tüüpilised lõksud:** privilegeeritud konteiner jagatud hostil on turvarisk (CI runner'il sobib), cgroup v1/v2 erinevus host-OS-is, idempotence ebaõnnestub `command`-iga ilma `changed_when`-ita.

    **Miks nii.** Molecule teeb sama tsükli, mida sa käsitsi tegid: loo masin, käivita roll (converge), käivita teist korda ja nõua `changed=0` (idempotence), kontrolli (verify), kustuta masin. `molecule.yml` kirjeldab masina ja draiveri, `converge.yml` on play, mis kasutab rolli, ja `verify.yml` kasutab sama `assert`-mustrit nagu sinu verify.

### 15. Andmebaasi parooli rotatsioon ilma autentimisveata

**Tase:** raske · **Eeldus:** [Deploy ja rolling](lab-6-deploy.md) · **Esita:** `rotate-db-user.yml`

Rakenduse andmebaasi parool on lekkinud (vana `ansible.log` jagati piletis) ja tuleb vahetada. Kui muudad lihtsalt `vault_db_password`-i ja käivitad `site.yml`-i, vahetab db01 parooli enne, kui app01 env-fail ja Tomcat uuenevad, ja rakenduse uued ühendused ebaõnnestuvad `Access denied`-iga. Hikari pool hoiab vanu ühendusi elus, nii et viga tuleb välja alles siis, kui pool avab uue ühenduse.

- Rotatsiooni ajal ei tohi rakendusel olla ühtki autentimisviga.
- MariaDB-s kehtib kasutajal korraga üks parool.
- Vana parool ei tohi lõpus kuskil kehtida.
- Iga samm on eraldi käivitatav ja kuni viimase sammuni saab selle rollback'iga tagasi võtta.
- Vana kasutaja eemaldatakse alles siis, kui sellel pole ühtki ühendust.

**Kontroll:**

```bash
ssh app01 'sudo journalctl -u tomcat --since "<algus>" | grep -c "Access denied"'
ssh db01 "sudo mysql -e 'SELECT user,host FROM mysql.user'"
ansible-playbook verify.yml | tail -6
ansible-playbook site.yml | grep changed=
```

**Valmis, kui:**

- `grep -c 'Access denied'` app01-s annab `0`;
- `mysql.user`-is pole vana kasutajat ja vana parooliga sisselogimine annab `ERROR 1045`;
- `verify.yml` on roheline ja teine `site.yml` käivitus annab `changed=0`;
- README-s on faaside tabel ja lause, mis muutuks kahe app-hostiga.

??? tip "Lahenduse suund"
    **Põhiidee:** vaheta kasutajat, mitte parooli. Kaks rakenduse kasutajat (`labseis` ja `labseis_b`) vahelduvad iga rotatsiooniga, nii et igal hetkel kehtib see paar, mida app01 kasutab.

    **Faasid:** (1) `rotate-db-user.yml -e rotate_new_user=labseis_b` loob uue kasutaja `vault_db_password_next` paroolist samade õigustega (`ansible.mariadb.mariadb_user`, `no_log: true`); (2) `group_vars/all/main.yml`-is `labseis_db_user` ja `labseis_db_password` uutele väärtustele, `site.yml --limit db,app` → env-fail muutub → handler `Restart tomcat`; (3) `rotate-db-user.yml -e rotate_drop_user=labseis` kontrollib `information_schema.PROCESSLIST`-ist ühenduste arvu (`mariadb_query`, `positional_args`), `/health`-i läbi web01 ja eemaldab siis vana kasutaja. Faasi 3 `assert` keeldub eemaldamast kasutajat, kes on veel `labseis_db_user`.

    **Rollback:** kuni faasini 3 on mõlemad kasutajad kehtivad, `git revert` faasi 2 commit'ile ja `site.yml --limit app` viib rakenduse vana kasutaja juurde.

    **Kontroll:** Valmis-tingimuste käsud. Ühe app-hostiga on Tomcati restart ainus katkestus ja see on HTTP poolel, mitte andmebaasi poolel. Kahe app-hostiga ja `serial: 1`-ga pole ka seda.

    **Tüüpilised lõksud:** play tasemel `when` (play ei toeta `when`-i, kasuta `block`-i), vana kasutaja eemaldamine enne, kui Hikari pool on vanad ühendused sulgenud, Vaulti parooli `rekey` saladuste endi vahetamise asemel (vanad commit'id jäävad vana parooliga loetavaks).

### 16. SSH hardening ilma end välja lukustamata

**Tase:** raske · **Eeldus:** [Rollid ja muutujad](lab-3-rollid.md) · **Esita:** `roles/common/`

Auditi leid: kõigis viies hostis on `sshd` vaikeseadetega, paroolisisselogimine on lubatud ja `kasutaja` saab agenti edasi saata. Paranda see rollis `common`. Risk on teel sinna: vigane `sshd_config` või vale `AllowGroups` lukustab välja ka Ansible'i ja alles jääb Proxmoxi konsool.

- Igal hostil kehtib `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `AllowAgentForwarding no` ja `AllowGroups` ainult grupiga, kuhu kuuluvad `kasutaja` ja `labops`.
- cloud-init kirjutab oma faili `/etc/ssh/sshd_config.d/` alla ja sinu seade peab sellest hoolimata kehtima.
- Vigane fail ei jõua kettale ja sshd't ei laeta vigase täiskonfiga.
- Muudatus läheb kõigepealt ühele hostile ja järgmine host saab selle alles siis, kui uus SSH ühendus eelmisega töötab.
- Ansible'i ühendus ei katke üheski hostis.

**Kontroll:**

```bash
ansible all -m ansible.builtin.command -a 'sshd -T' | grep -E '^(passwordauthentication|permitrootlogin|allowagentforwarding|allowgroups)'
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password kasutaja@db01
ansible all -m ansible.builtin.ping -o
ansible-playbook site.yml | grep changed=
```

**Valmis, kui:**

- `sshd -T` näitab igal hostil oodatud väärtusi;
- paroolisisselogimine annab `Permission denied (publickey)`;
- meelega tehtud trükiviga peatub `failed to validate` veaga ja `ping` töötab edasi;
- teine `site.yml` jooks on `changed=0`;
- README-s on lause, miks `ProxyJump` asendab agent forwarding'u.

??? tip "Lahenduse suund"
    **Põhiidee:** oma drop-in, mis sorteerub enne cloud-init'i faili, grupp enne `AllowGroups`-i ja eraldi play `serial: 1`-ga.

    **Mehhanism:** sshd loeb `Include /etc/ssh/sshd_config.d/*.conf` faili alguses ja iga võtme puhul kehtib **esimene** leitud väärtus. `50-cloud-init.conf` (Ubuntul võib seal olla `PasswordAuthentication yes`) võidab kõike, mis tuleb hiljem, seega on sinu fail `10-labseis.conf`. `validate: /usr/sbin/sshd -t -f %s` kontrollib fragmendi süntaksit enne paigaldamist, handler `Test sshd` (`sshd -t`) kontrollib täiskonfi enne `Reload sshd`-i. Teenuse nimi on Ubuntul `ssh`, Rockyl `sshd`: see läheb `vars/`-i.

    **Grupp:** loo `sshusers`, lisa `kasutaja`, valve1 ja valve2 (`append: true`) **enne** konfifaili. Vaata enne `id kasutaja` mõlemal distrol: cloud-init'i grupid erinevad ja oletus on siin lukustuse põhjus.

    **Rolling:** SSH osa eraldi play'sse (`hosts: all`, `serial: 1`, `max_fail_percentage: 0`), pärast `flush_handlers`-it `meta: reset_connection` ja `wait_for_connection`: Ansible avab uue ühenduse uue seadistusega.

    **Kontroll:** Valmis-tingimuste käsud. `sshd -T` näitab kehtivat seadistust, mitte faili sisu.

    **Tüüpilised lõksud:** fail `60-…` või `99-…` (cloud-init'i väärtus jääb kehtima ja `sshd -T` näitab `yes`), `AllowUsers kasutaja` (valvekasutajad kaovad), Ubuntu 24.04 `ssh.socket`: pordi või `ListenAddress`-i muutus vajab socket'i ümberseadistust, aga selles ülesandes porti ei muudeta.

### 17. SELinux praktikas: oma veebijuur ja port

**Tase:** raske · **Eeldus:** [Kontroll enne muudatust](lab-5-kontroll.md) (SELinuxi `failed_when` poliitika) · **Esita:** `selinux-www.yml`

Rocky hostides on SELinux `Enforcing` ja rolli `common` poliitika peatab play, kui keegi selle välja lülitab. mc01 peab nüüd serveerima sama veebimalli teise vhost'ina pordil `8090` kaustast `/srv/labseis-www` (tootmises eraldi ketas). Mõlemad annavad vaikimisi AVC keelu: fail on vale tüübiga ja port pole `httpd`-le lubatud.

- Kõik on eraldi playbook'is `selinux-www.yml`, `web.yml` jääb samaks.
- SELinux jääb `Enforcing`-uks: `setenforce 0`, `semanage permissive` ja `chcon` pole lubatud.
- Kontekst peab üle elama `restorecon -RF /srv/labseis-www` ja täieliku relabel'i.
- `web.yml` teine jooks jääb mõlemal hostil `changed=0`-ks ja pordi 80 leht ei muutu.
- Port `8090` saab `http_port_t` sildi; booleanid, mis lubavad `httpd`-l kõiki porte (`nis_enabled` jms), jäävad välja.

**Kontroll:**

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://mc01/ http://mc01:8090/
ssh mc01 'sudo matchpathcon -V /srv/labseis-www/index.html; getenforce; sudo ausearch -m avc -ts recent'
ansible-playbook selinux-www.yml | grep changed=; ansible-playbook web.yml | grep changed=
```

**Valmis, kui:**

- mõlemad URL-id annavad control node'ist `200`;
- `matchpathcon -V` ütleb `verified` ja `getenforce` on `Enforcing`;
- `ausearch` ei näita uusi `httpd_t` keelde;
- teine `selinux-www.yml` ja `web.yml` jooks on `changed=0`;
- README-s on lause, miks `chcon` ei sobi.

??? tip "Lahenduse suund"
    **Põhiidee:** püsiv reegel poliitikasse (`semanage`), siis failisüsteem reegli järgi (`restorecon`), alles siis sisu ja teenus.

    **Moodulid:** `community.general.sefcontext` (`target: '/srv/labseis-www(/.*)?'`, `setype: httpd_sys_content_t`), seejärel `restorecon -Rv /srv/labseis-www` `command`-iga ja `changed_when: "'Relabeled' in <register>.stdout"`; `community.general.seport` (`ports: 8090`, `proto: tcp`, `setype: http_port_t`); Rocky paketid `policycoreutils-python-utils` ja `python3-policycoreutils`. `Listen 8090` läheb lisafaili `conf.d/` alla. Fragmenti üksi `httpd -t` ei kontrolli, seepärast on handler `httpd -t` enne reload'i. Tulemüür: `ansible.posix.firewalld` `port: 8090/tcp`.

    **Mehhanism:** `chcon` muudab ainult faili xattr'it. `restorecon` ja relabel võtavad tüübi poliitika reeglist ja panevad `chcon`-i muudatuse tagasi `var_t`-ks. `ausearch -m avc` näitab `scontext=…httpd_t` ja `tcontext=…default_t` (fail) või `name_bind` (port).

    **Kontroll:** Valmis-tingimuste käsud. `semanage fcontext -l -C` ja `semanage port -l -C` näitavad ainult sinu lisatud kohalikke reegleid.

    **Tüüpilised lõksud:** sisu kopeeritakse enne `sefcontext`-i ja `restorecon` jääb vahele, `seport` puuduva Pythoni teegiga ("policycoreutils … not found"), `Listen 8090` `lineinfile`-iga paketi `httpd.conf`-i, mille paketiuuendus `.rpmnew`-ga mööda läheb. Kontrollimata: kas `8090` on kursuse Rocky 9 poliitikas juba mõne teise tüübiga määratud (`semanage port -l | grep -w 8090`); siis teeb `seport` `modify`-i.

### 18. Ansible teenusena: Semaphore

**Tase:** raske · **Eeldus:** [Kontroll enne muudatust](lab-5-kontroll.md); Docker control node'is nagu lehel [Tsüklid, mallid ja TLS](lab-7-tsuklid-tls.md)

Meeskonnas ei käivitata playbook'e kellegi sülearvutist: pole ajakava, auditilogi ega õiguste piiri ja kaks inimest võivad sama asja korraga käivitada. Pane control node'i Dockerisse [Semaphore UI](https://semaphoreui.com/install/docker/2_16) ja vii sinna kaks job template'it: öine `site.yml --check` ja `deploy.yml` versiooniga sisendist.

- Semaphore loeb repot ainult lugemisõigusega deploy-võtmega; SSH võti ja Vaulti parool on Semaphore'i Key Store'is, mitte konteineri keskkonnas ega repos.
- `SEMAPHORE_ACCESS_KEY_ENCRYPTION` ja admini parool on failis väljaspool repot (`0600`); kui see kaob, ei saa Key Store'i avada.
- UI kuulab ainult `127.0.0.1:3000` ja sinna jõuab SSH tunneliga.
- Teine kasutaja rolliga Task Runner saab template'i käivitada, aga mitte muuta.
- Sama template'i kaks käivitust ei tööta korraga.
- Öine check on ajastatud Semaphore'is, mitte cron'is.

**Kontroll:**

```bash
git grep -nE 'SEMAPHORE_|vault_pass'; echo "kood $?"
docker inspect semaphore --format '{{json .Config.Env}}' | grep -ci vault
curl -s -o /dev/null -w '%{http_code}\n' http://<control node'i IP>:3000/     # teisest masinast
```

**Valmis, kui:**

- task log näitab `site.yml --check` jooksu viiel hostil `changed=0 failed=0` ja ajakava on Semaphore'is;
- Task Runner kasutaja ei näe template'i muutmise nuppu;
- `git grep` ei leia saladusi ja `docker inspect` ei näita keskkonnas Vaulti parooli;
- teisest masinast port 3000 ei vasta;
- README-s on võrdlus: mida annab Semaphore, mida AWX ja mis on kummagi hind.

??? tip "Lahenduse suund"
    **Põhiidee:** Semaphore on job template'id inventory, võtmete ja repo ümber. Ansible töötab Semaphore'i konteineris, mitte sinu shellis, nii et kõik, mis seal on `.bashrc`-st või `~/.config/is1/`-st, tuleb anda eraldi.

    **Tööriistad:** `community.docker.docker_container` (image `semaphoreui/semaphore:v2.16.x` lukustatud tag'iga, `SEMAPHORE_DB_DIALECT=sqlite`, volume'id `/var/lib/semaphore`, `/etc/semaphore`, `env_file` väljaspool repot, `published_ports: ["127.0.0.1:3000:3000"]`). Semaphore'is: Key Store (SSH võti `kasutaja`-le, Vaulti parool tüübina "Login with password"), Repository (GitHubi deploy-võti), Inventory (fail repost `k02-ansible/inventory.ini`), Task Template (playbook `k02-ansible/site.yml`, lisaargument `--check`, Vault võti), Schedule.

    **Mehhanism:** konteiner jõuab VM-ideni hosti marsruudi kaudu (VPN control node'is). Kollektsioonid installib Semaphore enne jooksu `requirements.yml`-ist, kui see on oodatud kohas, muidu ebaõnnestub esimene moodul nime peal. Template'i paralleelkäivituse seade jäta välja ja kontrolli kahe järjestikuse käivitusega.

    **Kontroll:** Valmis-tingimuste käsud, task log'i RECAP-i rida ja `curl -s -o /dev/null -w '%{http_code}' http://<control node'i IP>:3000/` teisest masinast ei vasta.

    **Tüüpilised lõksud:** `ansible.cfg` asukoht (template käivitub repo juurest, `k02-ansible/ansible.cfg` jääb lugemata, kui töökaust on vale), `:latest` image (uuendus muudab andmebaasi skeemi), admini parool `docker run -e`-ga shelli ajaloos. Kontrollimata: Semaphore'i versioonis kehtiv kollektsioonide `requirements.yml` tee ja paralleelkäivituse seade nimi.

### 19. Sündmuspõhine koristus: ketas üle 90% ja inimese kinnitus

**Tase:** raske · **Eeldus:** [Deploy ja rolling](lab-6-deploy.md) · **Esita:** `rulebooks/disk.yml`, `disk-report.yml`, `disk-cleanup.yml`, teavituse playbook

app01 ketas täitub Tomcati logidest ja `logs.yml`-i pakkidest, valvur koristab seda öösel käsitsi. Tee control node'is [ansible-rulebook](https://docs.ansible.com/projects/rulebook/en/latest/), mis võtab ketta häire vastu, küsib kinnitust ja käivitab alles siis koristus-playbook'i. Häireid saadab iga 5 minuti järel sinu `disk-report.yml` (tootmises Alertmanager).

- Häire üksi ei muuda hostis midagi: see kirjutab kinnitustaotluse journald-isse (`logger -t labseis-eda`), kümme sama hosti häiret pooles tunnis annavad ühe taotluse.
- Koristus käivitub ainult siis, kui sama hosti kohta tuleb 30 minuti jooksul kinnitus, ja logisse jääb, kes kinnitas.
- Webhook kuulab ainult `127.0.0.1` ja nõuab token'it; token ja Vaulti parool on failis väljaspool repot (`0600`).
- Webhook'i sisend on võõras: kinnitus hostile `all` või `app*` ei käivita midagi.
- Koristus kustutab ainult journald'i üle piiri, üle 7 päeva vanad Tomcati logid, vanad `logs.yml` pakid ja paketihalduri vahemälu; WAR-id jäävad rollback'i jaoks. Kui ketas jääb üle piiri, lõpeb play veaga.
- Teine koristus järjest annab `changed=0`.

**Kontroll:**

```bash
eda() { curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "Authorization: Bearer $EDA_TOKEN" \
  -H 'Content-Type: application/json' -d "$1" http://127.0.0.1:5000/disk; }
eda '{"kind":"disk","host":"app01","mount":"/","pct":93}'
journalctl -t labseis-eda -n 3 --no-pager
eda '{"kind":"approve","host":"app01","by":"<nimi>"}'
EDA_TOKEN=vale eda '{"kind":"disk","host":"app01","mount":"/","pct":93}'
ansible-lint rulebooks/disk.yml disk-report.yml disk-cleanup.yml
```

**Valmis, kui:**

- häire annab `journalctl -t labseis-eda` reale `OOTAB host=app01` ja 10 päeva vanune testfail `/opt/tomcat/logs/` all on alles;
- kümme häiret järjest annavad ühe `OOTAB` rea;
- kinnitus annab rea `KINNITAS by=<nimi>`, vana testfail kaob, tänane jääb;
- vale token'iga päring saab koodi `401` ja ansible-lint on puhas;
- README-s on lause, mis muutuks, kui kinnitus oleks AWX-i workflow approval samm.

??? tip "Lahenduse suund"
    **Põhiidee:** kinnitus on teine sündmus. Ilma AWX-ita pole rulebook'il approval sammu, seega saadab inimene kinnituse samale webhook'ile ja reegel ootab mõlemat sündmust.

    **Rulebook:** allikas `eda.builtin.webhook` (`host: 127.0.0.1`, `port: 5000`, `token`), token `--env-vars`-iga. Esimene reegel: `condition: event.payload.kind == "disk" and event.payload.pct >= 90`, `throttle` `once_within: 30 minutes` ja `group_by_attributes` hosti kaupa, tegevus `run_playbook` teavituse playbook'ile. Teine reegel: `condition: all:` kahe nimega sündmusega (`events.alert << …`, `events.ok << … and event.payload.host == events.alert.payload.host`) ja `timeout: 30 minutes`. Ruleset'is `match_multiple_rules: true`, sest sama häire peab jõudma mõlemasse reeglisse, ja `default_events_ttl`, et kinnitamata häire ei jääks mällu.

    **Playbook:** sündmus on muutujas `ansible_eda.events`. Esimene play `localhost`-il teeb `assert`-i (host on `groups['all']`-is üks nimi, mount on tee, kinnitaja olemas), kirjutab auditirea ja lisab hosti `add_host`-iga; teine play koristab `find` + `file state: absent`-iga ja lõpetab `df` kontrolli ning `fail`-iga, kui piir jäi ületatuks. `ansible.cfg`-s on `become = True`, nii et `localhost` play'd vajavad `become: false`.

    **Käivitus:** `pipx install ansible-rulebook`, `pipx inject` sama ansible-core'i versiooniga ja `ansible-runner`, Java 17+. systemd kasutaja-unit töökaustaga `k02-ansible/` ja `EnvironmentFile`-iga: timer'il ja teenusel pole sinu shelli keskkonda, Vaulti parool on vaja ka siis, kui koristus Vaulti muutujaid ei kasuta, sest krüpteeritud `group_vars` fail laaditakse ikka.

    **Kontroll:** Valmis-tingimuste käsud. Eskalatsiooni proovid `fallocate`-iga `/var/tmp/` all: kinnitus annab `fail`-i ja fail jääb alles.

    **Tüüpilised lõksud:** häire läheb ainult esimesse reeglisse (`match_multiple_rules` puudub), host webhook'ist otse `hosts:` mustriks, token `disk-report.yml` väljundis (`no_log` saatmise ülesandel), koristus, mis kustutab `/opt/labori-seis` WAR-id ja võtab rollback'i võimaluse. Paralleelkäivituse ja õiguste teema on ülesandes [18. Semaphore](#18-ansible-teenusena-semaphore). Kontrollimata: allika nimi sõltub ansible-rulebook'i versioonist (vanemas `ansible.eda.webhook` koos kollektsiooniga `ansible.eda`).

### Lisaprojekt: andmebaasi varukoopia ja taastamine

**Tase:** raske · **Eeldus:** [Andmebaas ühe playbook'iga](lab-2-andmebaas.md), kõige parem pärast lehte [Deploy ja rolling](lab-6-deploy.md); stack roheline ja snapshot `k02-stack` olemas · **Esita:** `backup-db.yml`, `restore-db.yml`

Ansible ei taasta kustutatud andmeid. `backup-db.yml` teeb db01-st varukoopia töötava rakenduse kõrval ja toob selle control node'i kausta `scratch/backup/`, `restore-db.yml` taastab selle teadliku katkestusega ja paneb vea korral eelmise seisu tagasi.

- Nimi on `labseis-<kuupäev>-<kellaaeg>.sql.gz` faktist `ansible_facts['date_time']`, db01 kaust `/var/backups/labori-seis` (`0700`).
- Dump tuleb `ansible.mariadb.mariadb_db` `state: dump`-iga (`login_unix_socket` rolli `vars/RedHat.yml`-ist); tabeleid ei lukustata ja rakendus kirjutab dump'i ajal edasi.
- `fetch` (`flat: true`, `validate_checksum: true`) toob koopia control node'i ja pakk on terve (`gzip -t`).
- db01-st kustutatakse üle 7 päeva vanad koopiad ainult varukoopia kaustas ja alles pärast seda, kui uus koopia on control node'is kontrollitud.
- Taastamise fail tuleb `-e backup_file=…`-ga ja `assert` kontrollib, et see on olemas.
- Taastamine küsib kinnitust, kui `-e confirm=yes` puudub, ja ilma TTY-ta ei jätku see ilma `confirm=yes`-ita.
- Import'i ajal rakendus ei kirjuta. Enne import'i tehakse dump praegusest seisust, ebaõnnestunud import'i järel imporditakse see tagasi ja rakendus käivitatakse ikka.
- Lõpus kontrollib playbook ridade arvu (`mariadb_query`, `assert`) ja `/version` vastust.

**Kontroll:**

```bash
systemctl --user stop labseis-check.timer     # katse ajaks; lõpus start
# teises terminalis: while sleep 1; do curl -s -o /dev/null -w '%{http_code}\n' http://web01/health; done | grep -v '^200$'
ansible-playbook backup-db.yml && ls -l scratch/backup/
before=$(ssh db01 "sudo mysql -N -e 'SELECT COUNT(*) FROM labseis.result'")
ssh db01 "sudo mysql -e 'DELETE FROM labseis.result'"
ansible-playbook restore-db.yml -e backup_file="$(ls -t scratch/backup/labseis-*.sql.gz | head -1)" -e confirm=yes
[ "$before" = "$(ssh db01 "sudo mysql -N -e 'SELECT COUNT(*) FROM labseis.result'")" ] && echo taastatud
ansible-playbook verify.yml | tail -6
```

**Valmis, kui:**

- varukoopia ajal ei väljasta teine terminal ühtki rida;
- pärast `DELETE`-i ja taastamist väljastab kontroll `taastatud`;
- db01-s on `pre-restore-*.sql.gz`;
- `verify.yml` on roheline ja mõlemad playbook'id läbivad ansible-linti.

Vihje: `DELETE FROM student` ei sobi katseks, `result.student_id` võõrvõti keelab selle (`ERROR 1451`).

??? tip "Lahenduse suund"
    **Põhiidee:** dump ühe tehingu snapshot'ina, koristus alles pärast kontrollitud koopiat, taastamine kolmes play's (app seisma → db → app käima).

    **Mehhanism:** `mariadb_db` `state: dump` käivitab hostis `mysqldump`-i. `single_transaction: true` teeb InnoDB tabelitest järjepideva snapshot'i ühes tehingus ilma `LOCK TABLES`-ita. Vaikimisi `false` lukustab tabelid lugemiseks ja Labori seisu `POST /api/results` ootab luku taga. `.gz` lõpuga `target` pakib väljundi. Dump'i fail sisaldab `DROP TABLE`/`CREATE TABLE`-i, seepärast peab Tomcat import'i ajal seisma.

    **Kui import ebaõnnestub:** kaitse-dump enne import'i, import `block`-is, `rescue` impordib kaitse-dump'i ja salvestab vea `set_fact`-iga. Viga antakse viimases play's pärast Tomcati käivitamist. Kui kõik ühe play hostid ebaõnnestuvad, peatub kogu playbook ja järgmine play (Tomcat käima) jääks käivitamata.

    **Kinnitus:** `pause` ilma TTY-ta hoiatab "Not waiting for response to prompt as stdin is not interactive" ja jätkab. Tegelik kaitse on `assert` muutujale `confirm`.

    **Kontroll:** Kontroll-ploki käsud. Gigabaitide puhul `fetch` asemel `ansible.posix.synchronize` (rsync) või otse objektihoidlasse.

    **Tüüpilised lõksud:** koristus enne `fetch`-i, taastamine töötava Tomcatiga, unustatud `result` read, mis tulid pärast dump'i (taastamise RPO = dump'ide intervall).

    **Miks nii.** Varukoopia, mida pole taastatud, on oletus. `fetch` toob faili läbi Ansible'i SSH ühenduse ja sobib megabaitidele. `single_transaction` kaitseb ainult InnoDB tabeleid: MyISAM tabelid ja DDL dump'i ajal rikuvad snapshot'i järjepidevuse. Taastamise katkestus on teadlik ja planeeritud: tootmises käib see change'i aknas ja Nginxi `nginx_drain_hosts` muutuja või hoolduslehega.

## Võrguinsenerile

Ülesanded jätkavad 1. kohtumise tööriistaga `vorgukogu` ([1. kohtumise lisaülesanne 21](../k01/lisa.md#21-vorgukogupy-show-kaskude-valjund-kahelt-ruuterilt)): sama kogumine, nüüd Ansible'iga. Koolitaja on loonud `rtr01` ja `rtr02` (Ubuntu 24.04 + FRR 10.x, kasutaja `kasutaja` grupis `frrvty`, sinu võti), kaustas `vorgukogu/` on 1. kohtumise `known_hosts`. Failid lähevad kausta `vorgukogu/ansible/`, mitte `k02-ansible/`-isse: automaatne hindaja kontrollib `k02-ansible/inventory.ini`-d ja ruuterid sinna ei kuulu.

### 20. vorgukogu Ansible'iga: ad-hoc ja playbook

**Tase:** keskmine · **Eeldus:** 1. kohtumise lisaülesanne 21, `ansible-core` control node'is, [Kontroll enne muudatust](lab-5-kontroll.md) · **Esita:** `vorgukogu/ansible/hosts.yml`, `ansible.cfg`, `kogu.yml`

Kolleeg küsib, miks kirjutasid Pythoni skripti, kui Ansible on juba olemas. Tee sama kogumine Ansible'iga ja võrdle tulemust failide kaupa: kui väljund on sama, valid tööriista töö järgi, mitte harjumuse järgi. Ruuteris ei muutu midagi.

- `hosts.yml`: grupp `routers`, `ansible_host` IP-na, `ansible_user: kasutaja`, võti `~/.ssh/id_ed25519_labseis`; `ansible.cfg` kasutab sama `../known_hosts` faili ja hostivõtme kontrolli.
- Ad-hoc: `show version` mõlemalt ruuterilt ilma playbook'ita.
- `kogu.yml`: `show version`, `show interface brief` ja `show running-config` `ansible.builtin.command`-iga (`vtysh -c '…'`), `changed_when: false`.
- `running-config` peab olema selle ruuteri terviklik konf (`hostname <ruuter>`, viimane rida `end`), muidu on host `failed` ja tema faile ei kirjutata.
- Väljund läheb control node'i `../out-ansible/<ruuter>/<käsk>.txt`, sama failinime ja saladuste maskiga nagu `vorgukogu.py`-l, `running-config` alates reast `frr version`.
- Teine jooks muutmata ruuteritega annab `changed=0`.

**Kontroll:**

```bash
cd ~/labori-seis/vorgukogu/ansible
ansible routers -m ansible.builtin.command -a "vtysh -c 'show version'"
ansible-playbook kogu.yml && ansible-playbook kogu.yml | grep -E 'rtr0[12] '
diff -rw ../out ../out-ansible && echo "sama väljund"
grep -rnE '(password|key-string|md5) +[^* ]' ../out-ansible/; echo "kood $?"
printf 'routers:\n  hosts:\n    rtr09: {ansible_host: 192.0.2.1}\n' > /tmp/proov.yml
ansible-playbook -i hosts.yml -i /tmp/proov.yml kogu.yml | tail -4; echo "kood ${PIPESTATUS[0]}"
```

**Valmis, kui:**

- ad-hoc annab mõlemalt ruuterilt `FRRouting 10.`;
- teine jooks näitab mõlemal `changed=0`;
- `diff -rw` väljastab `sama väljund` (1. kohtumise `out/` on enne värskelt kogutud);
- saladuste `grep` annab koodi `1`;
- proovis on `rtr09` `unreachable=1`, rtr01 ja rtr02 `failed=0` ja `ansible-playbook`-i kood on `4`.

??? success "Lahendus"
    Ruuter on Ansible'ile tavaline Linuxi host: `command` töötab ruuteris ja `register` toob väljundi control node'i. Faili kirjutamine on `delegate_to: localhost`, sest fail on control node'is; `fetch` sobiks siis, kui ruuteris oleks juba valmis fail. `changed_when: false` märgib `show` käsud lugemiseks, muidu oleks iga jooks `changed`. Asendusmuster on muutujas: Jinja stringiliteraalis muutuks `'\1'` juhtmärgiks. Ansible'i kood 4 tähendab kättesaamatut hosti, 2 ebaõnnestunud ülesannet: sama jaotus mis `vorgukogu.py` koodil 2.

    ```yaml
    # Ruuterid Ansible'ile: sama vorgukogu/inventory.yaml info Ansible'i kujul.
    # FRR on Linuxi host: tavaline SSH ja moodul töötab ruuteris Pythoniga.
    all:
      children:
        routers:
          hosts:
            rtr01: {ansible_host: 10.10.7.21}
            rtr02: {ansible_host: 10.10.7.22}
          vars:
            ansible_user: kasutaja
            ansible_ssh_private_key_file: ~/.ssh/id_ed25519_labseis
            ansible_python_interpreter: /usr/bin/python3
    ```

    ```ini
    [defaults]
    inventory = hosts.yml
    # hostivõtmed sama failist mis vorgukogu.py-l (ssh-keyscan + sõrmejälje kontroll)
    host_key_checking = True
    timeout = 10

    [ssh_connection]
    ssh_args = -o UserKnownHostsFile=../known_hosts -o ControlMaster=auto -o ControlPersist=60s
    ```

    ```yaml
    ---
    # Sama töö mis vorgukogu.py-l: show-käskude väljund control node'i out-ansible/<host>/<käsk>.txt.
    # Käivitus kaustast vorgukogu/ansible: ansible-playbook kogu.yml
    - name: Ruuterite show-käskude kogumine
      hosts: routers
      gather_facts: false
      vars:
        vork_out: "{{ playbook_dir }}/../out-ansible"
        vork_commands:
          - show version
          - show interface brief
          - show running-config
        # samad saladuse read mis vorgukogu.py SECRET_PATTERNS-is: käsk jääb, väärtus asendatakse
        vork_secret_regex: '^(\s*(?:(?:enable )?password|key-string|ip ospf authentication-key|ip ospf message-digest-key \d+ md5|neighbor \S+ password))\s+\S.*$'
        # asendusmuster muutujas: Jinja stringiliteraalis muutuks '\1' juhtmärgiks
        vork_secret_mask: '\1 ***'
      tasks:
        - name: Show-käsud vtysh'iga
          ansible.builtin.command: vtysh -c '{{ item }}'
          loop: "{{ vork_commands }}"
          register: vork_show
          changed_when: false   # ainult lugemine: ruuteris ei muutu midagi
          check_mode: false     # --check-is samuti: muidu poleks millega faile võrrelda

        - name: Running-config on selle ruuteri terviklik konf
          ansible.builtin.assert:
            that:
              - ("hostname " ~ inventory_hostname) in vork_running.stdout_lines
              - vork_running.stdout_lines[-1] == "end"
            fail_msg: "{{ inventory_hostname }}: väljund pole selle ruuteri FRR-i konf"
            quiet: true
          vars:
            vork_running: "{{ vork_show.results | selectattr('item', 'eq', 'show running-config') | first }}"

        - name: Kaust control node'is
          ansible.builtin.file:
            path: "{{ vork_out }}/{{ inventory_hostname }}"
            state: directory
            mode: "0750"
          delegate_to: localhost

        - name: Väljund control node'i, saladused maskeeritud
          ansible.builtin.copy:
            content: "{{ vork_text | regex_replace(vork_secret_regex, vork_secret_mask, multiline=True) }}\n"
            dest: "{{ vork_out }}/{{ inventory_hostname }}/{{ item.item | replace(' ', '-') }}.txt"
            mode: "0640"
          loop: "{{ vork_show.results }}"
          loop_control:
            label: "{{ item.item }}"
          vars:
            # running-config alates "frr version" nagu vorgukogu.py-l: päis "Building configuration..." välja
            vork_text: "{{ ('frr version' ~ item.stdout.split('frr version', 1)[1]) if item.item == 'show running-config' else item.stdout }}"
          delegate_to: localhost
    ```

    Kontroll: Kontroll-ploki käsud; `ansible-playbook kogu.yml --check --diff` näitab, mis failides muutuks (`check_mode: false` laseb `show` käsud ka check'is käivitada). Täislahendus: `labori-seis/deploy/lisa-lahendused/k02/vork-ansible/`. Kontrollimata: siin polnud ansible-core'i ega ruuterit; YAML parsib ja maski regex on Pythonis läbi proovitud. Kui `diff -rw` näitab erinevust ainult viimase tühja rea kohta, on see Netmiko ja `command` väljundi lõpu erinevus, mitte konfi erinevus.

    **Miks nii.** Netmiko skript on sinu kood: sa otsustad, mida teha veaga, kuidas väljundit parsida ja millal ühendus suletakse. Ansible annab sama töö jaoks inventory, paralleelsuse (`forks`), korduvkäivituse, `--check`-i ja `PLAY RECAP`-i, aga tema loogika on moodulites, mitte sinu tsüklis. Väike erijuhtum (seadmepõhine parsimine, API ja CLI segamini) on lihtsam Pythonis, kümnete seadmete ühesugune muudatus on lihtsam Ansible'iga. Paljudes võrgutiimides elavad mõlemad: Ansible käivitab, keerulisem osa on Pythoni moodul või filter. FRR on siin Linuxi host, mitte Cisco või Juniperi seade: rtr01-l on Python, Ansible kopeerib mooduli SSH-ga ruuterisse ja `vtysh` käivitab käsu. Ansible'i FRR-i kollektsioon `frr.frr` on aegunud (toetus lõppes 2025. aasta detsembris, ansible-core 2.17-st uuemaga seda ei toetata), seepärast seda ei kasutata.

### 21. Cisco IOS XE ainult lugemiseks

**Tase:** lihtne · **Eeldus:** [20. vorgukogu Ansible'iga](#20-vorgukogu-ansibleiga-ad-hoc-ja-playbook) · **Esita:** `vorgukogu/ansible/devnet-hosts.yml`, `vorgukogu/ansible/devnet.yml`, `vorgukogu/devnet.yaml`, `NOTES.md`

Cisco DevNeti always-on IOS XE sandbox on tasuta ja avalik, aga jagatud: sellega töötavad samal ajal teised, kasutajanimi ja parool vahetuvad ning seade on vahel tundide kaupa maas. Seepärast käivitad ainult `show` käske, mitte ühtegi konfimuudatust. Kui sandbox ei vasta, jäta ülesanne vahele.

- Host on `devnetsandboxiosxe.cisco.com`, port 22; kasutaja ja parool on [DevNet Sandboxi](https://developer.cisco.com/site/sandbox/) lehel "IOS XE on Cat8kv AlwaysOn" (või sarnase nimega always-on IOS XE) ja lähevad keskkonda `DEVNET_USER`, `DEVNET_PASSWORD`.
- `devnet-hosts.yml`: `ansible_connection: ansible.netcommon.network_cli`, `ansible_network_os: cisco.ios.ios`, kasutaja ja parool keskkonnast.
- `devnet.yml` käivitab `cisco.ios.ios_command` `show version` ja `cisco.ios.ios_facts` `gather_subset: min`.
- Sama Netmikoga: `vorgukogu/devnet.yaml` `device_type: cisco_ios`, käsud `show version` ja `show ip interface brief`; `vorgukogu.py` jääb muutmata.
- `NOTES.md`-s on lause: mis vahe on `vorgukogu.py` jaoks `cisco_ios` ja `linux` draiveril.

**Kontroll:**

```bash
ansible-galaxy collection install cisco.ios ansible.netcommon
pipx inject ansible-core ansible-pylibssh
export DEVNET_USER=<sandboxi lehelt> DEVNET_PASSWORD=<sandboxi lehelt>
cd ~/labori-seis/vorgukogu/ansible
ansible-playbook -i devnet-hosts.yml devnet.yml
cd .. && ssh-keyscan devnetsandboxiosxe.cisco.com 2>/dev/null > devnet_known_hosts
VORK_USER=$DEVNET_USER VORK_PASSWORD=$DEVNET_PASSWORD VORK_KNOWN_HOSTS=devnet_known_hosts \
  python vorgukogu.py --inventory devnet.yaml --out out-devnet; ls out-devnet/*
```

**Valmis, kui:**

- `debug` väljastab seadme hostinime ja IOS XE versiooni;
- `out-devnet/sandbox-iosxe/` all on kaks faili;
- `NOTES.md`-s on draiverite lause.

Vihje: `network_cli` vajab kas `ansible-pylibssh`-i või `paramiko`-t.

??? success "Lahendus"
    `network_cli` puhul ei kopeeri Ansible seadmesse midagi: `ios_command` töötab control node'il, saadab käsu püsiva SSH sessiooni kaudu ja parsib vastuse. `ios_facts` loeb `show version` ja teiste käskude väljundist struktureeritud faktid (`ansible_net_version`, `ansible_net_hostname`). Netmikos teeb sama `cisco_ios` draiver: tunneb ära prompti `#`/`>`, lülitab paging'u välja (`terminal length 0`) ja käsk läheb otse, ilma `vtysh`-ita. Hostivõtme kontroll on Ansible'i inventory's ainult selle avaliku hosti jaoks välja lülitatud, sest sandbox paigaldatakse uuesti ja võti muutub; Netmiko pool kasutab `ssh-keyscan`-i faili, mis kehtib kuni järgmise paigalduseni.

    ```yaml
    # DevNeti always-on IOS XE: jagatud ja mitte alati üleval. Ainult show-käsud, ei mingit konfi.
    all:
      children:
        devnet:
          hosts:
            sandbox-iosxe:
              ansible_host: devnetsandboxiosxe.cisco.com
          vars:
            ansible_connection: ansible.netcommon.network_cli
            ansible_network_os: cisco.ios.ios
            ansible_user: "{{ lookup('ansible.builtin.env', 'DEVNET_USER') }}"
            ansible_password: "{{ lookup('ansible.builtin.env', 'DEVNET_PASSWORD') }}"
            ansible_command_timeout: 30
            # avalik sandbox, hostivõti muutub uuel paigaldusel; ainult selle hosti jaoks
            ansible_host_key_checking: false
    ```

    ```yaml
    ---
    # Päris Cisco IOS XE (DevNeti always-on sandbox), ainult lugemine.
    # Eeldus: ansible-galaxy collection install cisco.ios ansible.netcommon ja pipx inject ansible-core ansible-pylibssh.
    # Kasutaja ja parool on sandboxi lehel: export DEVNET_USER=... DEVNET_PASSWORD=...
    # Käivitus: ansible-playbook -i devnet-hosts.yml devnet.yml
    - name: IOS XE versioon ja faktid
      hosts: devnet
      gather_facts: false
      tasks:
        - name: Show version
          cisco.ios.ios_command:
            commands: [show version]
          register: devnet_version

        - name: Faktid (minimal)
          cisco.ios.ios_facts:
            gather_subset: [min]

        - name: Tulemus
          ansible.builtin.debug:
            msg: "{{ ansible_net_hostname }} {{ ansible_net_version }}; {{ devnet_version.stdout_lines[0][0] }}"
    ```

    ```yaml
    # vorgukogu.py päris Cisco IOS XE vastu (DevNeti always-on sandbox): ainult show-käsud.
    # Käivitus: VORK_USER=... VORK_PASSWORD=... VORK_KNOWN_HOSTS=devnet_known_hosts \
    #   python vorgukogu.py --inventory devnet.yaml --out out-devnet
    defaults:
      device_type: cisco_ios   # Netmiko draiver: käsk läheb otse, ilma vtysh'ita
      timeout: 20
    commands:
      - show version
      - show ip interface brief
    devices:
      - name: sandbox-iosxe
        host: devnetsandboxiosxe.cisco.com
    ```

    Kontrollimata: sandboxi hostinimi, kasutaja ja kättesaadavus kursuse päeval; `ansible_net_*` faktide nimed on `cisco.ios` dokumentatsiooni järgi. Kui `ios_facts` annab `Authentication failed`, on parool sandboxi lehel vahetunud.

    **Miks nii.** Cisco, Juniperi või Arista seadmel Pythonit pole ja seal käib kõik [teistmoodi](https://docs.ansible.com/projects/ansible/latest/network/getting_started/network_differences.html): moodul töötab control node'il, ühendus on `ansible_connection: ansible.netcommon.network_cli` (CLI üle SSH), `netconf` (XML RPC üle SSH) või `httpapi` (seadme REST API) ja platvormi ütleb `ansible_network_os` (nt `cisco.ios.ios`). Enable-režiim on `become: true` koos `become_method: enable`, mitte `sudo`. Ühendus on püsiv: üks SSH sessioon seadmega elab kogu play aja ja moodulid saadavad käske selle kaudu, mitte iga ülesande jaoks uue sisselogimisega. Varukoopia (`*_config` `backup: true`) kirjutatakse control node'i playbook'i kõrvale kausta `backup/`, mitte seadmesse.

## Arutelu

Vasta `k02-ansible/README.md`-s, igale küsimusele saab vastata oma stacki peal katsega.

1. **Algseis.** `ping` moodul ei kasuta ICMP-d. Mida see kontrollib ja mida tähendab, kui `ssh db01` töötab, aga `ansible db01 -m ping` annab `/usr/bin/python3: not found`?
2. **Andmebaas ühe playbook'iga.** Miks on "kas tabel on olemas" parem tingimus kui "kas baas loodi just praegu"? Mis juhtuks, kui `seed.sql` katkeks esimesel käivitusel poole peal?
3. **Kontroll enne muudatust.** Öine `--check` leiab drift'i. Mis juhtub, kui sama öö jooksul teeb pipeline deploy? Kuidas eristad drift'i ja pooleli jäänud deploy'd?
4. **Deploy ja rolling.** `serial: 1` ja `max_fail_percentage: 0` kahekümne hostiga: kui kaua kestab deploy, kui iga host võtab minuti? Mis on `serial: [1, 5, "50%"]` mõte?
5. **Esitamine.** Paroolifail on `~/.config/is1/`-s ja `.bashrc` ekspordib `ANSIBLE_VAULT_PASSWORD_FILE`-i. Kuidas saab pipeline sama parooli, ilma et see oleks repos?

## Kodutöö

Kodutöö viib sama koodi teise keskkonda: kui rollid on inventory allikast sõltumatud, töötab `site.yml` AWS-is sama hästi kui Proxmoxis ja muutub ainult see, kust hostide nimekiri tuleb.

| Issue | Mis | Juhend |
|---|---|---|
| `K2.K` | Sama `site.yml` viiel AWS-i EC2-l dünaamilise inventory'ga (`amazon.aws.aws_ec2`) | [`kodutood/k02-aws.md`](../kodutood/k02-aws.md) |
| `K2.M` | Monitooring: kontroll kõigil hostidel systemd timer'ina | [`kodutood/monitooring.md`](../kodutood/monitooring.md) → 2. kohtumine |
