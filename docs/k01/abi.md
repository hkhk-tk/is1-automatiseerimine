---
tags:
  - veaotsing
---

# Abi: veaotsing

Paranda alles siis, kui "Kontrolli" veeru käsk näitas sama, mida tabel ootab; muidu on põhjus mujal.

| Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
|---|---|---|---|
| **1. Keskkond** | | | |
| `cloud-init status: error` | `sudo cloud-init status --long`, `/var/log/cloud-init-output.log` | Cloud-Init vahekaardil vale IP või gateway | cloud-init ei saa võrku üles, kõik järgmised moodulid (paketid, võtmed) ebaõnnestuvad ahelas |
| `Could not get lock /var/lib/dpkg/lock-frontend` | `cloud-init status`, `systemctl list-jobs` | cloud-init või `apt-daily` uuendab; skriptid ootavad `cloud-init status --wait` ja `-o DPkg::Lock::Timeout=120` | dpkg lubab korraga ainult ühe paigaldaja; värske VM uuendab esimesel boodil ise |
| `ssh: Permission denied (publickey)` | `ssh -v <host>`, Cloud-Init vahekaardi võti | võti pole hostis: Regenerate Image + reboot | cloud-init loeb võtme ainult boodil; muudatus vahekaardil ei jõua töötavasse VM-i |
| `ssh -T git@github.com` → `Permission denied (publickey)` | GitHub → Settings → SSH keys | avalik võti pole GitHubis: `gh ssh-key add ~/.ssh/id_ed25519.pub -t control-node` | GitHub tunneb ära ainult võtmed, mis on sinu kontole lisatud |
| uut võtit tehes kadus `~/.ssh` sisu | `ls -la ~/.ssh` | kaust tühjendati; uus võti saab oma failinime (`-f`), `known_hosts` ja `config` jäävad | `ssh-keygen` kirjutab vaikimisi `id_ed25519` üle, kui vastad küsimusele "y" |
| `getent hosts db01` ei vasta | `grep labori-seis /etc/hosts` | `etc-hosts.sh` jäi käivitamata või `hosts`-is on CRLF | `getent` loeb `/etc/hosts`-i; `\r` rea lõpus teeb nimest `db01\r`, mida keegi ei küsi |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` | `ssh-keygen -F <host>` | VM loodi uuesti (rollback seda ei põhjusta): `ssh-keygen -R <host>` ja `ssh-keygen -R <IP>` | uus VM genereerib uue hostivõtme, `known_hosts` mäletab vana |
| pärast rollback'i `ssh mc01` ootab ja annab `Connection timed out` | Proxmoxis VM-i olek | VM on `stopped`: vajuta **Start** | ilma RAM-ita snapshot salvestab ainult ketta, rollback jätab VM-i peatatuks |
| `dig: command not found` | `command -v dig` | `sudo apt-get install bind9-dnsutils` | `dig` on eraldi paketis, `getent` on osa glibc-st |
| **2. websetup.sh** | | | |
| brauseris Apache'i vaikeleht | `ls /var/www/html` | kopeeriti malli kaust, mitte selle sisu | `cp -r mall /var/www/html/` loob alamkausta; `index.html` jääb Apache'i oma |
| `Permission denied` skripti käivitamisel | `ls -l k01-bash/*.sh` | käivitusõigus puudub: `chmod +x`, Gitis `git add --chmod=+x` | Git salvestab käivitusbiti eraldi; VS Code'is loodud fail on vaikimisi `644` |
| `$'\r': command not found` | `file websetup.sh` | Windowsi reavahetused: VS Code all paremal `CRLF` → `LF` | Bash loeb `\r`-i käsu osaks, iga rida lõpeb nähtamatu märgiga |
| ERR-trap ei teata funktsiooni sees olevast veast | `head -15 websetup.sh` | `set -E` puudub: ERR-trap ei kehti funktsioonides | Bash ei päri ERR-trap'i funktsioonidesse, kui `-E` (errtrace) pole sees |
| automaatne hindaja `strict` FAIL, kuigi `set` rida on olemas | `grep -n '^set' k01-bash/*.sh` | kontroll otsib kuju `set -e…`: kirjuta `set -eEuo pipefail`, mitte `set -Eeuo` | automaatne hindaja kontrollib teksti mustriga, mitte Bashi tähendust |
| teine käivitus ütleb ikka "N muudatust" | `bash /tmp/websetup.sh -n -v` | mõni samm muudab tingimusteta (`cp`, `restart`, `--add-service` ilma kontrollita) | idempotentsus tuleb kontrollist enne muutust; käsk ise ei tea, kas töö on juba tehtud |
| `-n` dry-run muutis siiski midagi | `grep -n apt-get websetup.sh` (ja `dnf`, `cp`, `systemctl`) | mõni muutev käsk ei käi läbi `change` funktsiooni | dry-run töötab ainult seal, kus `change` otsustab; otse kirjutatud käsk käivitub alati |
| peatatud Apache'iga ütleb skript "muudatusi pole" | `grep -n 'is-active' websetup.sh` | teenuse samm kontrollib ainult `is-enabled` | `enabled` tähendab "käivitub boodil", mitte "töötab praegu"; need on kaks eri olekut |
| `journalctl -t websetup` on tühi | `logger -t websetup proov`, siis uuesti | `logger` puudub skriptist või tag on teine | `journalctl -t` otsib täpset tag'i (`SYSLOG_IDENTIFIER`); teise nimega read on teises kohas |
| db01/mc01-s töötab `curl localhost`, control node'ilt mitte | `ssh mc01 sudo firewall-cmd --list-services` | firewalld blokeerib; ava `http` ainult siis, kui firewalld töötab | Rocky pilvepildis on firewalld sees ja lubab vaikimisi ainult `ssh`-d; `localhost`-i liiklus ei läbi tulemüüri |
| Rocky annab 403 Forbidden | `ssh mc01 ls -Z /var/www/html` | SELinuxi kontekst vale (`mv` /tmp-st): `restorecon -R /var/www/html` | `mv` säilitab faili vana konteksti (`user_tmp_t`), httpd tohib lugeda ainult `httpd_sys_content_t`; `restorecon` paneb failidele kausta SELinuxi vaikekonteksti tagasi |
| `sudo: a terminal is required` (`scp` töötab) | `ssh web01 sudo -n true` | `kasutaja` vajab paroolita sudo-t, cloud-init teeb selle | ilma TTY-ta ei saa sudo parooli küsida ja lõpetab kohe |
| **3. Mitu hosti** | | | |
| `ssh-copy-id`: `Permission denied` | `ssh -i ~/.ssh/id_ed25519 <host> true` | olemasolev võti ei tööta; parooliga pilvepildis ei saa | `ssh-copy-id` peab ise kõigepealt sisse saama; pilvepildis on paroolimeetod keelatud |
| tsükkel küsib parooli või jääb rippuma | `ssh -G <host>`: `batchmode`, `identityfile` | `~/.ssh/config` ühine plokk puudub või `Host` nimi ei klapi | ilma `BatchMode`-ita langeb ssh paroolile tagasi ja ootab klaviatuuri, mida skriptis pole |
| `sysinfo.sh` ketta väärtus tühi või vale | `ssh web01 df --output=pcent /` | `df`-ilt küsiti seadet (`/dev/sda1`), mitte haakepunkti `/` | seadme nimi erineb VM-ide vahel, haakepunkt `/` on alati sama |
| seadistati ainult esimene host | `grep -n 'while' webdeploy.sh` | `while read` + `ssh` neelab stdin-i: `ssh -n` või `mapfile` | ssh saadab oma stdin-i kaugkäsule; tsükli ülejäänud read lähevad esimesele hostile |
| paralleelse jooksu kokkuvõttes on kõik OK, kuigi üks host ebaõnnestus | `cat logs/<host>.log` | taustatöö kood jäi salvestamata (pelk `wait` kaotab koodid) | `wait` ilma argumendita tagastab 0; iga taustatöö kood tuleb küsida eraldi |
| `-f hosts` ütleb, et faili pole | `ls k01-bash/hosts` | tee on `k01-bash` kausta suhtes või kasuta absoluutset teed | skript teeb alguses `cd "$(dirname "$0")"`, suhteline tee arvutatakse sealt |
| teine jooks ei oota ega lõpeta lukuga | `ls -l k01-bash/logs/.webdeploy.lock` | `flock` ilma `-n`-ita ootab; või lukk ei ole kogu skripti peal (`exec 9>`) | `flock käsk` lukustab ainult selle ühe käsu ajaks, `exec 9>` hoiab fd lahti kogu skripti eluaja |
| pärast `kill -9` ütleb teine jooks kohe ikka "juba jookseb" | `lsof k01-bash/logs/.webdeploy.lock` (või `fuser -v …`, mis vajab paketti psmisc) | taustal töötavad veel tapetud skripti `scp`/`ssh` protsessid | lapsprotsessid pärivad failideskriptori 9; lukk vabaneb, kui viimane neist lõpeb |
| `logs/` ilmub `git status`-esse | `git check-ignore -v k01-bash/logs/x` | `.gitignore`-is puudub `k01-bash/logs/` | Git jälgib kõike, mida `.gitignore` ei välista |
| **4. Viis teenust** | | | |
| `git status` näitab `secrets.env`-i | `git check-ignore -v k01-bash/secrets.env` | rida puudub või fail lisati varem: `git rm --cached k01-bash/secrets.env` | `.gitignore` mõjub ainult jälgimata failidele; kord lisatud faili jälgib Git edasi |
| `deploy-all.sh` ütleb `secrets.env: DB_PASSWORD puudub` | `grep -c = secrets.env` | fail on tühi või võtme nimi on vale | `${VAR:?}` lõpetab skripti, kui muutuja on tühi; nii ei jõua tühi parool hostini |
| `deploy-all.sh`: `hosts: sama IP mitmel real` | `sort -k2 hosts \| uniq -D -f1` | kaks nime ühe IP-ga (kopeeritud rida) | `validate_hosts` keeldub enne esimest ssh-d, sest muidu läheks kahe teenuse skript samasse VM-i |
| health check (`wait_healthy`) ootab alati täis aja, ka töötava teenusega | `ssh <host> '<PROBE käsk>'; echo $?` | kontroll käivitub control node'il või vale port; `PROBE` peab töötama sihthostis | `127.0.0.1` tähendab seda masinat, kus käsk töötab; control node'il seda teenust pole |
| health check lõpetab kohe, ootamata | `bash -x deploy-all.sh mc01` | `until` tingimus on vale või `GATE_TIMEOUT` on 0 | `until` lõpetab esimese koodi 0 peale; kui tingimus annab alati 0, ei oodata kunagi |
| `check.sh`: `UNKNOWN: jq puudub` | `command -v jq` | `sudo apt-get install jq` control node'il | ilma JSON-i lugemiseta ei saa kontroll otsustada, seepärast UNKNOWN, mitte CRITICAL |
| `check.sh` näitab `health-db` OK, kuigi db on maas | `curl -s -w '%{http_code}' http://web01/health` | `curl -f` 503 korral kaotab JSON-i keha või `grep` leiab vale võtme | `-f`-iga jätab curl HTTP vea korral vastuse keha näitamata; just 503 kehas on vastus. `--fail-with-body` annab samuti veakoodi, aga näitab keha |
| `check.sh` kood on alati 0 | viimased read `check.sh`-is | väljumiskood ei sõltu tulemustest; `set -e` ei aita siin | skripti kood on viimase käsu kood, tavaliselt `echo`; taset tuleb lugeda ja `exit`-iga anda |
| tulemused ei jõua Labori seisu | `bash ../scripts/labseis-report.sh lab-01 test OK proov` | `LABSEIS_TOKEN` puudub või vale, `LABSEIS_URL` vale | `result` ei katkesta saatmise vea peale, nii et ekraanil näeb kõik korras välja |
| `curl -v`: `Connected` on olemas, siis `SSL certificate problem: unable to get local issuer certificate` | `curl -sv "$url/" 2>&1 \| grep issuer` | väljaandja on proksi või sisemine CA, mida control node ei usalda | `curl` kontrollib ahelat süsteemi CA-failiga; proksi sertifikaati seal pole |
| `curl -v`: `certificate has expired` | `curl -sv "$url/" 2>&1 \| grep 'expire date'` | serveri sertifikaat on aegunud või control node'i kell on vale (`timedatectl`) | aegumist võrreldakse sinu masina kellaga, mitte serveri omaga |
| **5. Kolm viga** | | | |
| `502 Bad Gateway` | `ssh app01 sudo journalctl -u tomcat -n 50 --no-pager` | Tomcat ei vasta: õigused või unit | Nginx töötab ja vastab ise, aga ei saa taga olevalt teenuselt vastust |
| `nginx` paigaldus: `bind() to 0.0.0.0:80 failed` | `ssh web01 sudo ss -tlnp` | web01-s töötab `websetup.sh`-i paigaldatud apache2 | apache2 hoiab `0.0.0.0:80`, nginx-i `bind()` saab `EADDRINUSE` |
| `/health` → `db: DOWN` | `ss -tlnp` db01-s, `SELECT user,host FROM mysql.user` | MariaDB ei kuula võrgus või kasutaja tohib tulla ainult db01-st | hosti sees tehtud kontroll läheb läbi, sest seal on nii aadress kui kasutaja `localhost` |
| `/health` → `cache: DOWN` | `ss -tlnp` mc01-s, `/etc/sysconfig/memcached` | memcached kuulab `127.0.0.1` peal või firewalld blokeerib 11211 | paketi vaikeseadistus on turvaline: teenus on kättesaadav ainult samas masinas |
| `/health` → `queue: DOWN` | `ssh rmq01 sudo rabbitmqctl list_users` | `labseis` puudub või parool erineb: `./deploy-all.sh rmq01 app01` | rakendus loeb parooli oma keskkonnafailist; kui see ja RabbitMQ erinevad, keeldub RabbitMQ |
| `X-Cache` jääb `MISS`-iks | `ssh app01 sudo grep MEMCACHED /etc/labori-seis/env` | rakendus ei jõua mc01-ni | rakendus läheb vahemälu vea korral otse andmebaasi ja ei teata sellest kasutajale |
| pärast db01 rollback'i ja `./deploy-all.sh db01` on `db` jälle DOWN | `git log --oneline -3 -- services/mariadb.sh` | parandus tehti masinas või jäi commit'imata | rollback kustutab kõik, mis polnud skriptis; skript paigaldab ainult seda, mis failis on |
| **6. Sama töö Ansible'iga** | | | |
| `pip install`: `externally-managed-environment` | `pipx --version` | Ubuntu 24.04 süsteemi Python (PEP 668); paigalda `pipx install 'ansible-core==2.21.*'` | distro kaitseb oma Pythoni pakette, et pip ei kirjutaks üle apt-i omi |
| `ansible: command not found` pärast pipx-i | `echo $PATH`, `ls ~/.local/bin` | `~/.local/bin` pole PATH-is: `pipx ensurepath && exec bash` | pipx paneb käsud `~/.local/bin` alla; shell loeb PATH-i ainult käivitudes |
| `config file = None` või `/etc/ansible/ansible.cfg` | `pwd`, `ls -ld .` | vale kaust või kaust kõigile kirjutatav: `cd ~/labori-seis/k02-ansible`, `chmod o-w .` | Ansible otsib `ansible.cfg`-i praegusest kaustast ja keeldub kõigile kirjutatavast |
| `Could not match supplied host pattern` / `provided hosts list is empty` | `ansible-inventory --graph` | `ansible.cfg` jäi lugemata või grupi nimes on trükiviga | ilma konfifailita ei tea Ansible, kus `inventory.ini` on, ja inventory on tühi |
| `ansible-inventory --graph` näitab hoste `queue`, `app`, `web`, ping annab neile `UNREACHABLE` | `grep -n '^\[' inventory.ini` | `:children` puudub: `[ubuntu]` all olevaid ridu loetakse hostinimedeks | tavalise grupi all on iga rida host; ainult `:children` ütleb, et read on grupid |
| `UNREACHABLE`, `Permission denied (publickey)` | `ssh kasutaja@<IP> true`, `ansible db01 -m ansible.builtin.ping -vvv \| grep -i 'user\|identity'` | `remote_user` puudub või vale; `ansible_host` on IP, seega `~/.ssh/config` `Host db01` plokk ei rakendu | ssh valib `Host` ploki aadressi järgi, millega ühendutakse; IP ei klapi nimega |
| `UNREACHABLE`, `Host key verification failed` | `ssh-keygen -F <IP>` | `known_hosts`-is on host nime järgi, Ansible ühendub IP-ga: `ssh -o StrictHostKeyChecking=accept-new kasutaja@<IP> true` | `known_hosts` hoiab võtit selle aadressi all, millega ühendusid; IP on uus aadress |
| ad-hoc käsk lõpeb koodiga 4 | väljundis `UNREACHABLE` | vähemalt üks host ei vastanud SSH-le | Ansible eristab koodidega: 2 = ülesanne ebaõnnestus, 4 = hostini ei jõutud |
| `/usr/bin/python3: not found` | `ansible db01 -m ansible.builtin.raw -a 'command -v python3'` | sihtmasinas pole Pythonit; SSH ise töötab | moodulid on Pythoni programmid; ainult `raw` töötab ilma Pythonita |
| `Failed to lock apt` / `This command has to be run with superuser privileges` | käsureal `-b` | ad-hoc ilma `become`'ita; playbook'is `become: true` | `become` on täna konfifailist väljas, nii et moodul töötab kasutajana `kasutaja` |
| `command` on alati `CHANGED` | `ansible-doc ansible.builtin.command` | ootuspärane: `command` ei tea, mida käsk muudab; playbook'is `changed_when` | moodul ei näe käsu sisse, seega eeldab, et käsk muutis midagi |
| `--check`: `Source /opt/labseis-mall/… not found` | kas see on hosti esimene jooks | check-režiim ei paki malli lahti; käivita üks kord ilma `--check`-ita, siis `--check` | check-režiim ei muuda midagi, seega järgmine ülesanne ei leia faile, mida eelmine oleks loonud |
| teine jooks annab `changed=1` | `ansible-playbook web.yml -v --diff` | mõni ülesanne muudab tingimusteta: `command` ilma päringuta, `apt` ilma `cache_valid_time`-ita | ilma `cache_valid_time`-ita uuendab `apt` indeksit igal jooksul ja raporteerib selle muutusena |
| mc01-s töötab `curl localhost`, control node'ilt mitte | `ansible mc01 -b -m ansible.builtin.command -a 'firewall-cmd --list-services'` | tulemüüri ülesanne jäi vahele: `service_facts` puudub või `when` on vale | `when` tingimus loeb fakti, mida pole, ja ülesanne jääb vaikselt vahele (`skipping`) |
| `unarchive`: `Failed to find handler` | `ansible webhosts -m ansible.builtin.command -a 'command -v unzip'` | `unzip` pole paigaldatud või paigaldus on pärast `unarchive`-i | `unarchive` kasutab sihtmasina `unzip`-i; ülesanded käivituvad failis olevas järjekorras |
| ansible-lint: `fqcn`, `name[casing]`, `no-changed-when`, `risky-file-permissions` | `ansible-lint web.yml` reegli nimi | moodul täisnimega, nimi suure tähega, `command`-il `changed_when`, failidel `mode` | lint kontrollib, et playbook on loetav ja ennustatav ka teise inimese jaoks |
| `git status` näitab `k02-ansible/ansible.log` | `git check-ignore -v k02-ansible/ansible.log` | `.gitignore`-is puudub rida `k02-ansible/ansible.log` | `log_path` kirjutab iga jooksu faili; Git näeb seda uue failina |
| **7. Operatsioon** | | | |
| `systemctl --user`: `Failed to connect to bus` | `echo $XDG_RUNTIME_DIR` | oled `sudo -i` või `su` all; logi sisse ssh-ga | kasutaja systemd elab sisselogimise seansis; `su` ei loo uut seanssi |
| timer ei käivitu, kui sa pole sisse logitud | `loginctl show-user "$USER" -p Linger` | `sudo loginctl enable-linger "$USER"` | ilma linger'ita peatab systemd kasutaja teenused viimase seansi lõpus |
| teenus `failed`, journal'is `No such file or directory` | `systemctl --user cat labseis-check.service` | `ExecStart` või `WorkingDirectory` tee on vale (`%h` = kodukaust) | systemd ei kasuta shelli: `~` ei laiene, tee peab olema täielik või `%h`-ga |
| teenus `failed`, journal'is `UNKNOWN: fail 'hosts' puudub` | `ls -l ~/labori-seis/k01-bash/hosts` | `hosts` on ümber nimetatud või kustutatud | `check.sh` loeb IP-d `hosts`-ist oma kaustas; kood 3 tähendab "ei saa kontrollida", mitte "stack on maas" |
| `journalctl --user -u labseis-check` on tühi | `systemctl --user list-timers` | timer pole `enable`-tud või `daemon-reload` jäi tegemata | systemd loeb unit-failid uuesti ainult `daemon-reload`-i peale |
| redeploy ei muutnud `/version`-it | `grep WAR_URL secrets.env` | `secrets.env` kirjutab käsurea `WAR_URL`-i üle | `. ./secrets.env` omistab muutujad uuesti, käsurealt tulnud väärtus kaob |
| vigase `WAR_URL`-iga lõpeb `deploy-all.sh app01` kohe veaga, `/version` on endine | `ssh app01 sudo journalctl -u tomcat --since -10min --no-pager \| tail -3` | ootuspärane: allalaadimine ebaõnnestus ja Tomcati ei restarditud | `tomcat.sh` laeb WAR-i ajutisse faili ja puudutab `webapps/`-i alles pärast õnnestunud `curl -f`-i |
| `WAR_URL` ei mõju ka vigase URL-iga | `ls -l ../target/labori-seis.war; ssh app01 ls -l /tmp/labori-seis.war` | kohalik WAR on olemas: `ssh app01 sudo rm /tmp/labori-seis.war` | `deploy-all.sh` kopeerib `target/`-i WAR-i app01 `/tmp`-sse ja `tomcat.sh` eelistab seda URL-ile |
| pärast rollback'i ei saa `ssh mc01` automaatika võtmega sisse | `ssh -G mc01`: `identityfile` | snapshot on vanem kui võti: `ssh-copy-id -i ~/.ssh/id_ed25519_labseis.pub mc01` | rollback viib tagasi ka `authorized_keys`-i, mis oli snapshot'i ajal |
| **8. Git meeskonnas** | | | |
| `gh pr create`: `could not find any commits between` | `git log --oneline k01-bash..k01-runbook` | commit tegemata või push'imata: `git push -u origin k01-runbook` | PR võrdleb GitHubis olevaid harusid; kohalik commit pole seal olemas |
| `gh pr review --approve`: `Can not approve your own pull request` | `gh pr view --json author` | ootuspärane: oma PR-ile jäta kommentaar (`--comment`) | GitHub lubab kinnitada ainult kellelgi teisel peale autori |
| `closes #N` ei sulgenud issue'd pärast merge'i | `gh pr view --json baseRefName` | PR läks `k01-bash`-i; issue sulgub esitamise PR-iga, kui töö jõuab `main`-i | GitHub töötleb sulgemissõnu ainult vaikeharule tehtud merge'i puhul |
| `git merge`: `Already up to date`, konflikti ei tulnud | `git diff k01-bash k01-timeout-aeglane -- k01-bash/check.sh` | `sed` ei leidnud `timeout 3 bash` rida, commit oli tühi või jäi tegemata | sinu `port()` timeout erineb starteri omast; muuda `sed`-is väärtus enda omaks |
| `git commit` pärast konflikti: `Committing is not possible because you have unmerged files` | `git status --short` (`UU`) | fail on parandatud, aga `git add` tegemata | Git peab konflikti lahendatuks alles siis, kui fail on uuesti staging'us |
| konflikti lahendus läks sassi | `git status` | `git merge --abort` viib seisu enne merge'i | merge'i ajal hoiab Git mõlemat algversiooni alles, kuni commit on tehtud |
| `git merge --ff-only`: `Not possible to fast-forward` | `git log --oneline --graph k01-bash k01-runbook-kood3 -5` | rebase jäi tegemata või `k01-bash` liikus pärast rebase'i | fast-forward on võimalik ainult siis, kui sinu haru algab `k01-bash`-i viimasest commit'ist |
| `git push` pärast rebase'i: `rejected (non-fast-forward)` | `git status -sb` | haru oli juba üleval: `git push --force-with-lease origin <sinu haru>`, mitte kunagi `main` ega `k01-bash` | rebase andis commit'idele uued hash'id ja GitHubi haru tipp pole enam sinu haru ajaloos |
| `k01-bisect: töökaustas on commit'imata muudatusi` | `git status --short --untracked-files=no` | pane töö kõrvale: `git stash push -m "…"` | skript teeb uue haru ja ei tohi sinu poolikut tööd kaasa võtta |
| `k01-bisect: ei leia 'tr -d …'` | `grep -n '^ip_of' k01-bash/check.sh` | `ip_of` on sinu `check.sh`-is ümber kirjutatud | kolleegi commit'id eeldavad starteri `ip_of` rida; küsi koolitajalt |
| bisect leidis esimese kolleegi commit'i, kuigi see ainult lisab kommentaari | `git switch k01-bash && (cd k01-bash && ./check.sh); echo $?` | "hea" seis polnud roheline: `git bisect reset`, paranda stack, alusta uuesti | kui `k01-bash` ise annab koodi ≠ 0, on iga test "halb" ja bisect jõuab vahemiku algusesse |
| `git bisect run`: `bisect run failed: exit code … is < 0 or >= 128` | `echo $?` pärast käsitsi `./check.sh` | test katkes signaaliga või puudub käivitusõigus | koodid 128+ tähendavad bisect'i jaoks "test ise ei tööta" ja see peatub |
| `git stash pop`: `CONFLICT` | `git status --short` | `NOTES.md` muutus vahepeal ka commit'is: lahenda nagu konflikt, siis `git stash drop` | stash on samuti merge; konflikti korral jääb kirje alles, kuni ise kustutad |
| `git show HEAD~1:k01-bash/prod.env` näitab tokenit ka pärast `git rm --cached` | `git log --oneline -- k01-bash/prod.env` | ootuspärane: fail on vanas commit'is | `rm --cached` muudab järgmist commit'i, mitte varasemaid |
| `git log -S` annab commit'i parooli väärtusega | `git show --stat <hash>` | parool on olnud repos: vaheta see ([lisaülesanne 18](lisa.md#18-parooli-vahetus-skriptiga)) | ajalugu on GitHubis nähtav kõigile, kes repot näevad, ka pärast faili eemaldamist |
| **9. Esitamine** | | | |
| tag pole GitHubis | `git ls-remote --tags origin` | tavaline `git push` tag'e ei lükka: `git push origin k01` | tag on eraldi viide; `git push` saadab vaikimisi ainult harud |
| parandus pärast esitust | `git log --oneline -1 k01` | tag on vana commit'i peal: `git tag -f k01 && git push -f origin k01` | tag ei liigu commit'iga kaasa, see osutab alati ühele commit'ile |
| `k01 shellcheck`: "k01-bash/ all pole skripte" | `ls k01-bash/*.sh` | skript ei lõpe `.sh`-ga või on vales kaustas | automaatne hindaja otsib faile mustriga `k01-bash/*.sh` |
| kohapeal `OK`, värskes kloonis `FAIL` | `git status --short --ignored k01-bash` | fail on jälgimata, ignoreeritud või push'imata | sinu töökaustas on faile, mida GitHubis pole; automaatne hindaja näeb ainult repot |
