---
tags:
  - veaotsing
  - Ansible
---

# Abi: veaotsing

Kui ühtki rida ei klapi, käivita sama käsk `-v`-ga ja loe esimest ebaõnnestunud ülesannet ning hosti.

Kõige sagedasem muster on see, et sümptom ja põhjus on eri kohas. Roll ebaõnnestub, aga viga on inventory's. Jooks on roheline, aga teenus pole muudatust saanud. Seepärast ära paranda esimest kohta, kus viga näed, vaid küsi, kust ebaõnnestunud väärtus tuli.

| Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
|---|---|---|---|
| **1. Algseis** | | | |
| `UNREACHABLE … Permission denied (publickey)` | `ssh kasutaja@<IP>`, `ansible db01 -m ping -vvv` | vale kasutaja või võti; `remote_user = kasutaja`; pärast rollback'i `algus`-ele on automatiseerimise võti läinud: kasuta `enne-stack` (laboris; rollback kaotab hilisemad muudatused) | Ansible kasutab süsteemi `ssh`-d ja `~/.ssh/config`-i; `-vvv` näitab täpset `ssh` käsurida koos `IdentityFile`-i ja `User`-iga |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` | `ssh-keygen -F <host>` | VM loodi uuesti: `ssh-keygen -R <host>` ja `ssh-keygen -R <IP>`; laboris `host_key_checking = False` | Ansible kasutab sama `known_hosts`-i mis `ssh`; `host_key_checking = False` lisab ssh-le `StrictHostKeyChecking=no` |
| `config file = None` või `/etc/ansible/ansible.cfg` | `pwd`, `ls -ld .` | vale kaust või kaust kõigile kirjutatav: `cd ~/labori-seis/k02-ansible`, `chmod o-w .` | Ansible otsib `ansible.cfg`-d praegusest kaustast ja ignoreerib seda, kui kausta saavad kõik kirjutada: keegi võiks sinna oma seaded panna |
| `ansible-config dump --only-changed` ei näita `DEFAULT_BECOME` | `grep -n become ansible.cfg` | `become = True` on vale jaotise all: peab olema `[privilege_escalation]` | INI-failis kuulub võti jaotisele; tundmatut võtit vales jaotises Ansible ei loe ega hoiata |
| `UNREACHABLE` ainult `-u root`-ga | `ansible all -m ping -u root` | mallist loodud VM-idesse root SSH-ga ei saa, see on õige | cloud-init keelab root'i SSH sisselogimise; root'iks saad `become`-iga |
| `Could not get lock /var/lib/dpkg/lock-frontend` | `ssh <host> cloud-init status` | cloud-init või unattended-upgrades töötab; `lock_timeout: 120` ja rollis `common` `cloud-init status --wait` | `apt` moodul ootab lukku `lock_timeout` sekundit (vaikimisi 60), `dnf` 30; cloud-init esimene boot hoiab lukku kauem |
| mc01 `UNREACHABLE … No route to host`, teised `pong` | Proxmoxis mc01 olek | VM on välja lülitatud või võrk maas | Ansible jätab `UNREACHABLE` hosti play ülejäänud ülesannetest välja ega peata teisi |
| käsk ripub ühe hosti juures kaua | `ansible-config dump \| grep TIMEOUT`, `-T 5` | host ei vasta ja pakett kaob vastuseta | `timeout` (vaikimisi 10 s) läheb ssh-le `ConnectTimeout`-ina; `DROP` reegli taga ootab iga fork selle aja ära |
| **2. Andmebaas ühe playbook'iga** | | | |
| `--check` ebaõnnestub: `Could not find the requested service mariadb` | kas pakett on paigaldatud | check tühjal masinal: paketti ei paigaldatud, see pole viga koodis | check ennustab iga ülesannet eraldi; teenuse ülesanne küsib masinalt ja teenust seal veel pole |
| `A MySQL module is required: … PyMySQL` | `ssh db01 rpm -q python3-PyMySQL` | PyMySQL puudub **sihtmasinas**: `python3-PyMySQL` (Rocky), `python3-pymysql` (Ubuntu) | moodul töötab sihtmasina Pythonis, mitte control node'is, ja vajab teeki seal |
| `Access denied for user 'root'@'localhost'` | `ssh db01 'sudo ss -xlp \| grep mysql'` | ühendus käib TCP kaudu: `login_unix_socket:` õige teega | MariaDB root autendib `unix_socket`-iga: ilma paroolita pääseb sisse ainult socket'i kaudu |
| `couldn't resolve module/action 'ansible.mariadb.mariadb_db'` | `ansible-galaxy collection list` | kollektsioon paigaldamata: `ansible-galaxy collection install -r requirements.yml` | ansible-core sisaldab ainult `ansible.builtin`-i; kõik muu tuleb kollektsioonidest |
| `Attempting to decrypt but no vault secrets found` | `echo $ANSIBLE_VAULT_PASSWORD_FILE` | Vaulti parool puudub: `export ANSIBLE_VAULT_PASSWORD_FILE=~/.config/is1/vault_pass` või `--ask-vault-pass` | Ansible laadib `group_vars/all/vault.yml`-i iga jooksuga ja vajab selleks parooli, ka siis, kui ükski ülesanne saladust ei kasuta |
| `vault password file … was not found` pipeline'is või kolleegil | `grep vault ansible.cfg` | `vault_password_file` on `ansible.cfg`-s: eemalda, kasuta keskkonnamuutujat | konfifail on Gitis, paroolifail mitte; tee, mis on sinu masinas õige, on mujal vale |
| import on igal jooksul `changed` | `ansible-playbook db.yml -v` | `state: import` impordib alati: tingimus `SHOW TABLES` päringu järgi | moodul ei tea, mis SQL-failis on, ega oska öelda, kas see on juba imporditud |
| import käivitub, kuigi tabel on olemas | `debug: var=<register>` | tingimus loeb vale välja: `query_result` on list päringute kaupa (`[0]`) | moodul võib käivitada mitu päringut ja tagastab iga tulemuse eraldi listina |
| app01 ei saa db01-ga ühendust (`/dev/tcp` timeout) | `ssh db01 sudo firewall-cmd --list-ports` | firewalld Rockyl: `ansible.posix.firewalld` port `3306/tcp` | Rocky 9 `public` tsoonis on vaikimisi ainult `ssh`, `cockpit`, `dhcpv6-client` |
| playbook ei taasta kustutatud ridu | `ssh db01 "sudo mysql -e 'SHOW TABLES' labseis"` | tingimus vaatab tabelit, mitte ridu: see on õige | Ansible hoiab struktuuri, mitte andmeid; andmete taastamine on varukoopia töö |
| ad-hoc import: `Access denied` | ad-hoc käsu parameetrid | `login_unix_socket` puudub ad-hoc käsust | ad-hoc käsk ei tea playbook'i parameetreid; iga parameeter tuleb anda `-a`-s |
| **3. Rollid ja muutujad** | | | |
| `Could not find or access 'schema.sql'` rollis | `grep -n src roles/mariadb/tasks/main.yml` | rollis otsib `copy` faili rolli `files/` kaustast: `{{ playbook_dir }}/../db/…` | suhteline `src` lahendatakse rolli sees rolli `files/` kausta suhtes |
| muutuja on rollis `undefined` | `ansible-inventory --host <host>`, `ls group_vars host_vars` | fail vales kohas või vale nimega (`group_vars/rocky.yml` peab klappima grupi nimega) | Ansible seob faili grupiga nime järgi ja ei hoiata faili kohta, mis ühelegi grupile ei vasta |
| ad-hoc `debug` ütleb rolli muutuja kohta `VARIABLE IS NOT DEFINED!` | rolli `defaults/main.yml` | ad-hoc ei laadi rolli: vaata playbook'i jooksus või `--check --diff`-is | rolli `defaults` laaditakse ainult siis, kui roll on play's |
| `host_vars` väärtus ei kehti | `ansible-inventory --host app01`, `grep -rn <muutuja> site.yml roles/` | play `vars:`, rolli parameeter või `-e` võidab `host_vars`-i | inventory muutujad on prioriteedis madalamal kui play ja käsurea omad |
| tingimus jääb vahele, kuigi peaks käivituma | `ansible <host> -m setup -a filter=ansible_distribution*` | `ansible_distribution` on `Rocky`, mitte `CentOS`; kasuta `os_family` | `distribution` on distro täpne nimi, `os_family` on pere (`RedHat`, `Debian`) |
| arvude võrdlus annab vale tulemuse | `debug: var=<fakt>` | fakt on string: `'10' > '8'` on väär, lisa `\| int` | stringe võrreldakse tähthaaval ja `'1'` on enne `'8'` |
| `'ansible_facts' is undefined` | play `gather_facts` | `gather_facts: false`: faktid jäid kogumata | faktid kogutakse play alguses ainult siis, kui see pole välja lülitatud |
| memcached kuulab `127.0.0.1` peal | `ansible-inventory --host mc01 \| grep memcached`, `ssh mc01 cat /etc/sysconfig/memcached` | `memcached_listen` tuleb kõrgemalt tasemelt või `lineinfile` regexp ei leia rida | kui regexp ei leia rida, lisab `lineinfile` uue rea lõppu ja vana jääb kehtima |
| `failed to validate` sudoers'i ülesandes | `visudo -cf` sama sisuga | süntaksiviga (`NOPASWD`): fail jäi paika panemata, `sudo` töötab edasi | `validate` kontrollib ajutist faili enne paigaldamist ja keeldub vigasest |
| `sudo: parse error in /etc/sudoers.d/…` | Proxmoxi konsool root'ina | fail kirjutati ilma `validate`-ita: kustuta fail konsoolist või tee rollback (laboris taastab hilisemad andmed `site.yml`) | Ansible'i `become` käib sama `sudo` kaudu, nii et playbook ei saa vigast faili parandada |
| `ansible_local` on tühi | `ssh <host> ls -l /etc/ansible/facts.d/` | kaust või fail puudub, JSON/INI on vigane või fail on käivitatav (`0755`) | käivitatava `.fact` faili käivitab `setup` skriptina ja ootab JSON-väljundit |
| `/etc/hosts`-is on kaks labori plokki | `ssh <host> grep -n labori-seis /etc/hosts` | Bashi `etc-hosts.sh` plokk ja Ansible'i plokk erinevate markeritega | `blockinfile` tunneb oma plokki ainult markeri järgi; teise markeriga plokk on tema jaoks võõras tekst |
| käsitsi rida ploki sees kaob, väljaspool jääb | `--check --diff --limit <host>` | see on õige käitumine | `blockinfile` haldab ainult markerite vahelist osa |
| **4. Kogu stack** | | | |
| `rabbitmq_user` ebaõnnestub värskel VM-il | `ssh rmq01 sudo rabbitmqctl status` | Erlangi node pole valmis: enne `rabbitmqctl await_startup` | systemd loeb teenuse käivitunuks, kui protsess töötab, mitte siis, kui node vastab |
| `unarchive` ebaõnnestub `Failed to find handler` | `ssh app01 which tar` | arhiiv katkine või URL vale; `get_url` `checksum` kontrollib enne lahtipakkimist | `unarchive` tunneb arhiivi tüübi sisu järgi; HTML-veateade `.tar.gz` nime all pole arhiiv |
| Tomcat ei käivitu, logis `Permission denied` | `ssh app01 sudo journalctl -u tomcat -n 50 --no-pager` | töökaustad ei kuulu kasutajale `tomcat` või unit'is vale `User=` | Tomcat kirjutab `logs`, `temp` ja `work` kausta käivitusel ega saa ilma nendeta alustada |
| unit-failis on `-Xmx384m` | `ansible-inventory --host app01` | `host_vars/app01.yml` puudub või vale nimega | ilma `host_vars`-ita jääb kehtima rolli vaikeväärtus |
| `/health` annab 502 | `ssh app01 'sudo journalctl -u tomcat -n 50'` | Tomcat käivitub 30–60 s või env-fail on vale (DB, MQ parool) | 502 kestab, kuni Tomcat rakendust käivitab; `uri` `until` peab ootama sama kaua (`retries` × `delay`) |
| `/health` → `"queue":"DOWN"` | `ssh rmq01 systemctl is-active rabbitmq-server` | RabbitMQ on peatatud või seiskunud | rakendus kontrollib iga sõltuvust eraldi ja annab selle seisu JSON-is |
| teenus peatati, `site.yml` muudab ainult teenuse ülesannet | jooksu `changed:` read | see on õige: soovitud seis on `started` | handler käivitub ainult seadistuse muutuse peale; teenuse käivitamine on tavaline ülesanne |
| `handler … was not found` | `grep -rn 'name:' roles/*/handlers/` | `notify` tekst ja handleri nimi ei klapi täpselt (ka suurtäht) | `notify` otsib handlerit nime järgi, tähthaaval |
| handler käivitub kaks korda ühes jooksus | `grep -n flush_handlers roles/tomcat/tasks/*.yml` | `flush_handlers` on kahe teavituse vahel | iga `flush_handlers` käivitab ootel handlerid kohe; ilma selleta kogunevad teavitused kokku |
| iga jooks `changed=1` Tomcati vaike-ROOT juures | `ssh app01 ls /opt/tomcat/webapps/ROOT` | kustutamine kustutab sinu rakenduse: tingimus `tomcat.svg` olemasolu järgi | Tomcat pakib `ROOT.war`-i lahti samasse kausta, mida vaike-ROOT kasutas |
| teine jooks pole `changed=0` | `ansible-playbook site.yml -v \| grep -B2 changed:` | `command` ilma `changed_when`-ita, `get_url` ilma kindla failinimeta, eraldi restart | `command` ei tea, mida käsk tegi, ja ütleb alati `changed` |
| `--start-at-task` ei leia ülesannet | `ansible-playbook site.yml --list-tasks` | handler pole ülesanne või nimi on teine | handlerid pole ülesannete nimekirjas; need käivituvad ainult teavituse peale |
| `ROOT.war` muutus, aga vana versioon vastab | `flush_handlers` asukoht | kontroll käivitus enne handlerit: `meta: flush_handlers` kontrolli ette | handlerid käivituvad vaikimisi play lõpus |
| **5. Kontroll enne muudatust** | | | |
| lint ebaõnnestub ainult automaatses hindajas | `bash autograde/check.sh k02 lint` | automaatne hindaja ignoreerib `.ansible-lint` faili ja lubab kuni kolm `# noqa`-t | automaatne hindaja kustutab koopiast sinu lint'i seadistuse, et kõik reeglid kehtiksid |
| `var-naming[no-role-prefix]` | lint'i rida | rolli `register`/`set_fact` ilma rolli eesliiteta (`tomcat_…`) | rollide muutujad on kõik samas nimeruumis; eesliide hoiab ära kokkupõrked |
| `--check` ebaõnnestub: `has no attribute 'query_result'` (või `rc`, `status`) | ülesanne, mille `register`-it kasutatakse | päring jäi check'is käivitamata: lugevale ülesandele `check_mode: false` | check-režiimis jätab `command` ja osa mooduleid ülesande vahele ja `register`-is pole tulemust |
| `--check` näitab `changed` ülesandes, mis ainult loeb | `ansible-playbook site.yml --check -v` | `command` ilma `changed_when: false`-ita | `command` eeldab muudatust, kui sa ei ütle teisiti |
| `--check` leiab muudatuse, aga kood on `0` | `echo ${PIPESTATUS[0]}` | see on õige; drift'i leiad PLAY RECAP-ist (`changed=[1-9]`) | `changed` pole Ansible'i jaoks viga; nullist erinev kood tuleb ainult `failed` või `unreachable` korral |
| käsitsi muudetud konf, teenus töötab edasi | `ssh <host> sudo ss -tlnp` | teenus pole uut faili lugenud | Ansible'i jooksus viib uue faili teenusesse handler; käsitsi muudatuse järel handlerit pole |
| `--diff` ei näita env-faili | ülesande `no_log` | `no_log: true` peidab ka diff'i, see on õige | diff jõuaks logisse ja pipeline'i väljundisse |
| SELinuxi ülesanne ebaõnnestub Rocky hostis | `ssh <host> getenforce` | keegi tegi `setenforce 0`: `sudo setenforce 1` ja uuri, miks | `failed_when` kontrollib poliitikat ja peatab hosti meelega |
| `assert` ebaõnnestub: parool alla 12 märgi | `ansible-vault view group_vars/all/vault.yml` | `vault_db_password` liiga lühike või `-e` andis teise väärtuse | `-e` võidab ka Vaulti väärtuse |
| `verify.yml` ebaõnnestub Memcached'i pordi juures | `ssh mc01 sudo ss -tlnp`, `systemctl is-active memcached` | teenus maas või kuulab loopback'il: `ansible-playbook site.yml --limit cache` | verify küsib app01-st, mitte mc01-st endast |
| `verify.yml`: `/health` JSON-is mõni `DOWN` | `curl -s http://web01/health` | vastav teenus või ühendus (1. kohtumise veaotsingu tabel) | rakendus küsib iga sõltuvust ise ja annab tulemuse edasi |
| **6. Deploy ja rolling** | | | |
| deploy on `rescued=1 failed=0`, aga uus versioon pole väljas | `rescue` viimane ülesanne | `rescue` ei lõpe `fail`-iga | edukas `rescue` loeb vea käsitletuks ja host jääb roheliseks |
| rescue ei pane eelmist versiooni tagasi | `ssh app01 cat /etc/ansible/facts.d/deploy.fact` | `tomcat_previous_version` tühi: fact puudub või loed vale võtit (`ansible_facts['ansible_local']['deploy']['version']`) | ilma fact'ita pole rescue'l teada, milline fail oli viimati töötav |
| deploy sõnum: "eelmist versiooni pole" | `ssh app01 ls /etc/ansible/facts.d/` | `deploy.fact` kustutati või host on uus | hosti mälu kaob koos hostiga; taasta Gitis oleva versiooniga `ansible-playbook deploy.yml` |
| `deploy.fact` muutub igal jooksul | `cat deploy.fact` kahe jooksu järel | faili sisu sõltub jooksust (aeg, eelmine versioon): jäta sinna ainult töötav versioon | `copy` võrdleb sisu ja iga erinev bait on `changed` |
| health check pärast deploy'd läbib, kuigi app01 ei vasta | `-v` väljund `wait_for` juures | `{{ ansible_host }}` delegeeritud ülesandes on web01: kasuta `hostvars[inventory_hostname]['ansible_host']` | `delegate_to` muudab ühenduse muutujad delegeeritud hosti omadeks |
| `delegate_to: localhost` küsib sudo parooli või ebaõnnestub `sudo` peal | ülesande `become` | `become: True` tuleb `ansible.cfg`-st: lisa delegeeritud ülesandele `become: false` | `become` kehtib ka delegeeritud ülesandele ja control node'is pole paroolita sudo't |
| `NO MORE HOSTS LEFT` pärast esimest hosti | PLAY RECAP | `max_fail_percentage: 0` töötas: esimene host ebaõnnestus, paranda see | iga ebaõnnestunud host ületab nulli ja play peatub enne järgmist batch'i |
| katkine versioon jääb kauaks ootele | `tomcat_health_retries`, `tomcat_health_delay` | vaikimisi 30 × 4 s; testis `-e tomcat_health_retries=8` | `until` kordab kuni `retries` täis, enne kui block ebaõnnestub |
| `web.yml` health check ebaõnnestub, `curl` rmq01-s töötab | `ssh rmq01 sudo iptables -S INPUT` | testi `REJECT` reegel on alles: `iptables -D …` | reegel lubab ainult loopback'i; `localhost` kontroll läbib, väline mitte |
| **7. Tsüklid, mallid ja TLS** | | | |
| tsüklis `'dict object' has no attribute 'key'` või `Invalid data passed to 'loop'` | `ansible -m ansible.builtin.debug -a var=labseis_fw_ports db01` | `dict2items` puudub või muutuja on juba list | `loop` vajab listi; sõnastik tuleb enne listiks teha, list mitte |
| `group_vars/rocky.yml`-i port puudub db01-s | `ansible-inventory --host db01` | lapsgrupi `db` sõnastik asendas `rocky` oma | sõnastikud ei liitu üle tasemete; kõrgem tase asendab kogu väärtuse, liitmiseks on `combine` |
| `No package curl available` või konflikt `curl-minimal`-iga | `ssh mc01 rpm -q curl-minimal` | `curl` lisati `common_packages`-isse | Rocky minimal'is on `curl-minimal`, mis annab sama käsu ja ei luba teist paketti kõrvale |
| eelkontroll ebaõnnestub kõigil hostidel, kuigi ruumi on | `ansible mc01 -m ansible.builtin.setup -a filter=ansible_mounts` | arvutus vales ühikus: `size_available` on baitides | MB saad jagades 1048576-ga; ilma jagamata on võrdlus vale suurusjärguga |
| `NO MORE HOSTS LEFT` kohe eelkontrolli järel | `fatal` rida väljundis | üks host ebaõnnestus ja `any_errors_fatal` peatas kõik, nii peabki | play peatab kõik hostid, kui ükski ebaõnnestub; paranda see host ja käivita uuesti |
| `Saidi seadistus` ebaõnnestub `failed to validate`, `nginx: [emerg] cannot load certificate` | `ssh web01 ls -l /etc/ssl/labori-seis/` | sert pole hostis enne malli: `import_tasks: tls.yml` peab olema enne malli | `validate` käivitab `nginx -t`-d, mis loeb ka kõik serdifailid, millele sait viitab |
| `failed to validate`, kuigi mall on õige | `ssh web01 sudo /usr/local/sbin/nginx-validate-site /etc/nginx/sites-available/labori-seis` | skript puudub, pole käivitatav või `%s` puudub `validate` reast | Ansible asendab `%s` ajutise faili teega; ilma selleta kontrollib skript vale faili või mitte midagi |
| `Can't detect any of the required Python libraries cryptography` | `pipx runpip ansible-core list \| grep -i cryptography` | teek puudub Ansible'i venv'is: `pipx inject ansible-core cryptography` | `delegate_to: localhost` töötab Ansible'i enda Pythonis, mitte süsteemi `python3`-s ega web01-s |
| `couldn't resolve module/action 'community.crypto…'` (või `community.general`, `community.docker`) | `ansible-galaxy collection list \| grep community` | `requirements.yml` uuendati, aga ei paigaldatud | kollektsioon on control node'i kaustas, mitte repos; iga uus rida vajab `ansible-galaxy collection install -r` |
| delegeeritud ülesanne küsib `sudo` parooli või `Missing sudo password` | ülesande `become` | `become: false` puudub `delegate_to: localhost` ülesandelt | `ansible.cfg` `become = True` kehtib ka control node'is käivituvale ülesandele |
| `curl: (60) SSL certificate problem: unable to get local issuer certificate` | `curl --cacert ~/.config/is1/pki/ca.crt …` | klient ei tunne labori CA-d | `uri` ja `get_certificate` vajavad sama: `ca_path` või `ca_cert` labori CA failiga |
| `curl: (60) … no alternative certificate subject name matches` | `openssl x509 -noout -ext subjectAltName -in ~/.config/is1/pki/web01.crt` | nimi või IP puudub SAN-ist | kui `subject_alt_name` on antud, ei lisa `openssl_csr` sinna CN-i ega IP-d ise |
| `--tags tls` lõpeb roheliselt, serdi ülesandeid ei käivitu | `grep -n _tasks roles/nginx/tasks/main.yml` | `include_tasks` ilma `apply: {tags: [tls]}`-ta | dünaamilise include'i tag kehtib ainult include'ile endale, mitte sisemistele ülesannetele |
| `ignore_errors` ülesanne punane, aga jooks ja pipeline roheline | PLAY RECAP `ignored=` | viga peideti, kood on `0` | `ignore_errors` ütleb, et viga ei loe; kontrolliks kasuta `failed_when` ja `assert` |
| RabbitMQ API: `FAILED - RETRYING` lõpuni, staatus `401` | `ssh rmq01 sudo rabbitmqctl list_users` | kasutajal pole `management` tag'i või parool ei klapi | API lubab ainult tag'iga kasutajaid; `rabbitmqctl` hostis ei vaja parooli ja ei näita seda viga |
| RabbitMQ API: `Connection refused` pordil 15672 | `ssh rmq01 sudo rabbitmq-plugins list -e` | plugin pole sisse lülitatud või käivitub veel | plugin avab pordi alles pärast käivitust; `until` ootab seda, kui `retries` on piisav |
| `logs.yml`: `unarchive` ütleb `Failed to find handler` | `file scratch/logs/*.tar.gz` | arhiiv tehti ühest failist ja on paljas `.gz` | `archive` kaustast annab alati `tar.gz`-i; üksik fail pakitakse ilma tar'ita |
| `memcached-docker.yml`: `Permission denied … docker.sock` | `id -nG \| grep docker`, `docker ps` | kasutaja pole grupis `docker` või uus grupp pole sessioonis | grupi liikmesus tuleb sisse alles uues sisselogimises |
| `memcached-docker.yml`: `No module named 'docker'` | `pipx runpip ansible-core list \| grep -i docker` | Dockeri Pythoni SDK puudub: `pipx inject ansible-core docker` | moodul räägib Dockeriga Pythoni teegi kaudu, mitte `docker` käsu kaudu |
| **8. Intsident** | | | |
| skript: `töökaustas on commit'imata muudatusi` | `git status --short` | commit või stash enne | skript peab teadma head seisu, kuhu tagasi minna |
| skript: `ei leia '…'` | moodulite 3–4 nõuded | sinu failis puudub nõutud nimi (`[app]`, `memcached_listen`, `Restart tomcat`, `tomcat_heap`) | skript muudab kindlaid ridu ja ei tee midagi, kui neid pole |
| skript: `haru enne-intsidenti on juba olemas` | `git log --oneline -3` | intsident on juba tehtud; uuesti: `git reset --hard enne-intsidenti && git branch -D enne-intsidenti` | haru on hea seisu märk ja skript ei kirjuta seda üle |
| kõik on segamini | `git log --oneline enne-intsidenti..` | `git reset --hard enne-intsidenti`, siis `ansible-playbook site.yml` | kood ja masinad lähevad koos tagasi; masinad järgnevad koodile |
| verify on roheline, aga mõni play jäi vahele | `ansible-playbook verify.yml \| grep 'no hosts matched'` | grupp on tühi või ümber nimetatud | tühi grupp pole Ansible'i jaoks viga; play jääb vaikselt vahele |
| verify esimene play küsib sudo parooli | play `become` | `become: false` puudub `localhost` play'st | `ansible.cfg` `become = True` kehtib ka control node'is käivituvale play'le |
| **9. Esitamine** | | | |
| `idempotent` FAIL: PLAY RECAP-is pole 5 hosti | `grep -c ok= run2.txt` | `run2.txt` tehti `--limit`-iga või esimesest jooksust | automaatne hindaja loeb RECAP-i ridu ja ootab igalt hostilt ühte |
| `vault` FAIL: avatekstis saladus | automaatse hindaja teates fail ja rida | parool `vault.yml`-i, viide `{{ vault_… }}` | automaatne hindaja otsib võtmeid `password`/`token`, mille väärtus pole muutuja |
| `inventory` FAIL: `muutujad ainult group_vars/all-is` | `ls host_vars group_vars` | puudub `host_vars/<host>.yml` või `group_vars/<grupp>.yml` | kontroll ootab, et vähemalt üks väärtus on grupi või hosti tasemel |
| `syntax` FAIL ainult `deploy.yml`-is | `ansible-playbook deploy.yml --syntax-check` | `import_role` tee või `tasks_from` nimi vale | `site.yml` ei kasuta `deploy.yml`-i, nii et see viga tuleb välja ainult otse kontrollides |
| kloonist check: `Could not find or access` | `git status` algses kaustas | fail on sinu kaustas, aga mitte Gitis | tavaliselt `scratch/`-is või `.gitignore`-i all olev fail, millele playbook viitab |
| kloonist check: `no vault secrets found` | `echo $ANSIBLE_VAULT_PASSWORD_FILE` | uues shellis pole muutujat | muutuja tuleb `~/.bashrc`-st; mitteinteraktiivne shell (cron, CI runner) seda ei loe |
| tag ei käivita automaatset hindajat | `git ls-remote --tags origin` | tag push'imata: `git push origin k02` | automaatne hindaja käivitub tag'i push'i sündmusest; haru push seda ei tekita |

*Tabel L2.3. Veaotsing moodulite kaupa.*
