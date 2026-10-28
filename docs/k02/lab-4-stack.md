---
tags:
  - Ansible
  - rollid
  - Tomcat
  - Nginx
---

# 4. Kogu stack

Iga teenus on eraldi võttes korras, aga kasutaja saab 502: Nginx viitab vanale aadressile, Tomcat taaskäivitus enne, kui uus seadistus kohale jõudis, või RabbitMQ polnud veel valmis, kui rakendus ühendus. Andmebaas ja vahemälu on rollides, aga sõnumijärjekorda, rakendust ja veebiserverit veel pole. Nüüd lisad RabbitMQ, Tomcati ja Nginxi rollid koos mallide ja handleritega; mida iga roll tegema peab, näed failidest `k01-bash/services/rabbitmq.sh`, `tomcat.sh` ja `nginx.sh`. Iga roll on omaette lihtne, raskus on ühendustes: Tomcat vajab teiste hostide aadresse, Nginx vajab Tomcati aadressi ja iga taaskäivitus peab juhtuma õigel hetkel.

Lõpuks vastab `/health` läbi web01, teine jooks on viiel hostil `changed=0` ja stackist on snapshot.

**Kui teed seda tööl iga päev:** kirjutad RabbitMQ, Tomcati ja Nginxi rollid mallide ja handleritega nõuete loetelu järgi, `curl -s http://web01/health` annab `{"status":"UP",…}` ja teine `site.yml` jooks on viiel hostil `changed=0`. Kui see on sul juba korras, mine otse etappi [„Handler käivitub ainult muudatuse korral“](#handler-kaivitub-ainult-muudatuse-korral).

Päring tuleb web01 Nginxisse, läheb app01 Tomcatisse ja Tomcat küsib andmeid db01-st, vahemälu mc01-st ja saadab sõnumeid rmq01-le. Iga nool on port, mis peab olema avatud, ja aadress, mis peab mallis õige olema. Seepärast kontrollid iga rolli järel teenust sealt, kust seda kasutatakse (näiteks MariaDB porti app01-st, mitte db01-st).

<figure markdown="span">
  ![Labori seisu viis VM-i: web01 Nginx, app01 Tomcat, db01 MariaDB, mc01 Memcached, rmq01 RabbitMQ](assets/k02_stack.svg)
  <figcaption>Joonis L2.4. Labori seis: viis teenust, pordid ja distrod.</figcaption>
</figure>

## RabbitMQ: ootamine enne kasutajat

Kirjutad RabbitMQ rolli. Uus asi on ootamine: roll peab enne kasutaja loomist ootama, kuni RabbitMQ päringuid vastu võtab.

Ilma ootamata töötab roll sinu masinas, sest teenus käis juba eelmisest katsest. Värskel VM-il, OpenTofu järel või pipeline'is ebaõnnestub see vahelduvalt, sõltuvalt sellest, kui kiiresti Erlangi node oma andmebaasi laadis.

Kirjuta roll `rabbitmq` ja play `hosts: queue`:

- rolli esimene ülesanne `ansible.builtin.assert`, et host on Ubuntu (`os_family == "Debian"`), arusaadava `fail_msg`-iga
- pakett `rabbitmq-server`, teenus käib ja käivitub bootil
- enne kasutajat `rabbitmqctl await_startup --timeout 60` (`changed_when: false`): systemd jaoks on teenus "started" enne, kui Erlangi node vastab
- kasutaja [`community.rabbitmq.rabbitmq_user`](https://docs.ansible.com/projects/ansible/latest/collections/community/rabbitmq/rabbitmq_user_module.html): `labseis_mq_user`, `labseis_mq_password`, `update_password: always`, õigused vhost'il `/`, `no_log: true`; kasutaja `guest` kustutatud
- `requirements.yml`-i `community.rabbitmq` (`">=1.7.0,<2.0.0"`)

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml --limit queue
ansible-playbook site.yml --limit queue | tail -3
ssh rmq01 sudo rabbitmqctl list_users
```

`labseis` ilma `guest`-ita tähendab, et rakendusel on oma kasutaja ja vaikekasutaja tuntud parooliga on kadunud. `changed=0` teisel jooksul koos `update_password: always`-ga näitab, et moodul võrdleb parooli ja muudab seda ainult siis, kui Vaultis on teine väärtus. `assert` rolli alguses on lühim dokumentatsioon: see ütleb kohe, et roll on kirjutatud Ubuntule.

✅ **Edasi saad minna, kui** `list_users` näitab `labseis` ja mitte `guest` ning teine `--limit queue` jooks on `changed=0`.

## Tomcat: paigaldus ja keskkonnamall

Kirjutad Tomcati paigalduse. See on stacki kõige keerulisem roll, sest Tomcat ei tule paketina: arhiiv tuleb alla laadida, kontrollida ja lahti pakkida ning õigused tuleb panna ise. Lisaks kirjutad kaks malli: rakenduse keskkonnafaili ja systemd unit'i.

Roll `tomcat` jaguneb kaheks failiks: `tasks/install.yml` käivitub harva, `tasks/deploy.yml` iga versiooniga. `tasks/main.yml` impordib mõlemad `ansible.builtin.import_tasks`-iga. Siin kirjutad `install.yml`-i:

- assert Ubuntu, `openjdk-21-jre-headless`, süsteemikasutaja `tomcat` (`/usr/sbin/nologin`, kodu `/opt/tomcat`, kodukausta ei looda)
- Tomcat `tomcat_version` arhiiv `get_url`-iga koos `checksum: "sha512:<url>.sha512"`, lahti `unarchive`-iga (`remote_src`, `--strip-components=1`, `creates:`) kausta `/opt/tomcat-<versioon>`, sümlink `/opt/tomcat`; programm kuulub root'ile, kasutajale `tomcat` ainult `conf`, `logs`, `temp`, `webapps`, `work`
- näidisrakendused ära; vaike-`ROOT` ainult siis, kui `webapps/ROOT/tomcat.svg` on olemas (`stat` + `register`)
- mall `templates/env.j2` → `/etc/labori-seis/env` (`0640 root:tomcat`, `no_log: true`): `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `MEMCACHED_HOST`, `RABBITMQ_HOST`, `RABBITMQ_USER`, `RABBITMQ_PASSWORD`, `TEACHER_TOKEN`; hostid IP-ga (`hostvars[groups['db'][0]]['ansible_host']`)
- mall `templates/tomcat.service.j2` → `/etc/systemd/system/tomcat.service` (`User=tomcat`, `EnvironmentFile=`, `-Xmx{{ tomcat_heap }}`); kõik muudatused teavitavad handlerit `Restart tomcat` (`ansible.builtin.systemd_service`, `daemon_reload: true`)

```bash
ansible-playbook site.yml --limit app --check --diff | grep -E 'Xmx|changed'
ansible-playbook site.yml --limit app
ssh app01 'sudo ls -l /etc/labori-seis/env; systemctl cat tomcat | grep Xmx'
```

> Kui unit-failis on `-Xmx384m`, ei jõudnud `host_vars/app01.yml` kohale: vaata `ansible-inventory --host app01`.

`-rw-r----- root tomcat` tähendab, et Tomcat saab paroole lugeda, aga mitte muuta, ja teised kasutajad ei näe neid üldse. `-Xmx512m` unit-failis on README prioriteedi tabeli tõend: `host_vars` võitis rolli vaikeväärtuse. Mall seob muutujad ja hostid üheks failiks, nii et uue andmebaasi IP jaoks muudad ainult inventory't ja käivitad sama rolli.

✅ **Edasi saad minna, kui** env-fail on `-rw-r----- root tomcat`, unit-failis on `-Xmx512m` ja `systemctl is-active tomcat` app01-s on `active`.

## Tomcat: deploy eraldi failis

Paned rakenduse ise Tomcatisse. Versioon on muutuja ja iga versioon on serveris oma failina. Deploy on eraldi failis, sest pipeline kutsub hiljem ainult seda osa ja paigaldust iga versiooniga kordama ei pea.

Kui uus versioon kirjutab vana faili üle, pole tagasiminekuks enam midagi. Kui deploy ja paigaldus on ühes failis, taaskäivitab iga uus versioon ka asju, mis polnud muutunud.

Rakenduse versioon on GitHubi Release'i tag. Lisa `group_vars/all/main.yml`-i:

```yaml
labseis_war_url: "https://github.com/hkhk-tk/labori-seis-war/releases/download/{{ labseis_version }}/labori-seis.war"
```

Kirjuta `tasks/deploy.yml`:

- kaust `/opt/labori-seis`; WAR `get_url`-iga faili `labori-seis-{{ labseis_version }}.war`: iga versioon on oma failina, vana jääb alles
- `ROOT.war` tuleb sellest failist `copy` + `remote_src: true` (`tomcat:tomcat`, `0640`) ja teavitab handlerit
- `ansible.builtin.meta: flush_handlers`, siis `ansible.builtin.uri` `http://localhost:8080/version` koos `until`, `retries`, `delay`
- kõigil deploy ülesannetel `tags: [deploy]`

```bash
ansible-playbook site.yml --limit app
curl -s http://app01:8080/version; echo
ansible-playbook site.yml --limit app | tail -3
```

`/version` vastus tähendab, et Tomcat käivitus, pakkis `ROOT.war`-i lahti ja rakendus vastab. Ilma `flush_handlers`-ita enne kontrolli küsiks `uri` vana rakenduse käest, saaks vastuse ja läbiks, ja taaskäivitus juhtuks alles pärast kontrolli. `changed=0` teisel jooksul tähendab, et kindla failinimega `get_url` ei laadinud faili uuesti alla.

✅ **Edasi saad minna, kui** `/version` vastab ja teine `--limit app` jooks on `changed=0`.

## Nginx: mall tsükliga ja kaks handlerit

Kirjutad viimase rolli. Nginxi mall käib tsükliga üle app-grupi, nii et uus app-host jõuab upstream'i ilma malli muutmata. Handlereid on kaks ja nende järjekord kaitseb vigase seadistuse eest: kõigepealt test, siis reload.

Reload'il kontrollib Nginxi master seadistuse ise ja jätab vigase korral vana tööle, aga vigane fail jääb kettale ja järgmine restart või reboot jätab saidi maha. Handler `Test nginx` peatab play enne reload'i, kuid ka siis on vigane fail juba kettal; selle sulged `validate`-iga tsüklite ja mallide juures.

Kirjuta roll `nginx` ja play `hosts: web`:

- mall `templates/labori-seis.conf.j2` → `/etc/nginx/sites-available/labori-seis`: upstream'i read tsükliga üle `groups['app']`, aadress `hostvars[h]['ansible_host']`, port `nginx_app_port` (`defaults`); sait `sites-enabled`-is linkina, vaikesait eemaldatud
- handlerid failis selles järjekorras: `Test nginx` (`nginx -t`, `changed_when: false`), siis `Reload nginx`; iga muudatus teavitab mõlemat
- `meta: flush_handlers`, siis `uri` `http://localhost/health` `until`-iga

```bash
ansible-playbook site.yml --limit web
curl -s http://web01/health; echo
ssh web01 'sudo nginx -T 2>/dev/null | grep -A3 "upstream labori_seis"'
```

`{"status":"UP",…}` tähendab, et Nginx jõudis Tomcatini ja Tomcat kõigi kolme taustateenuseni. Kui mõni neist oleks `DOWN`, ütleks JSON, milline. `nginx -T` loeb seadistuse failidest kettal, mitte töötavast protsessist: muudatus jõuab teenusesse alles pärast reload'i.

✅ **Edasi saad minna, kui** `/health` annab `{"status":"UP",…}` ja upstream'is on app01 IP pordiga 8080.

## Teenus maas: mida näevad /health ja Ansible

Peatad rmq01-s RabbitMQ ja vaatad sama riket kahest kohast: kasutaja poolt `/health`-ist ja Ansible'i poolt. Siis lased playbook'il teenuse üles tõsta.

Intsidendis on esimene küsimus, kas viga on seisus (teenus maas, fail vale) või koodis. Kui seisu viga parandab sama playbook, mis selle lõi, on parandus kiire ja korratav ega vaja käsitsi `systemctl`-i.

1. Peata teenus ja vaata, mida kasutaja näeb.

    ```bash
    ssh rmq01 sudo systemctl stop rabbitmq-server
    curl -s http://web01/health; echo
    ```

2. Käivita ainult järjekorra play ja vaata, mis muutus.

    ```bash
    ansible-playbook site.yml --limit queue | grep -E 'changed:|RUNNING HANDLER|changed='
    sleep 5; curl -s http://web01/health; echo
    ```

3. Kirjuta README-sse, milline ülesanne oli `changed`, miks handler ei käivitunud ja mida tähendaks `changed=0`, kui teenus oleks ikka maas.

`/health` näitas `"queue":"DOWN"`, aga ülejäänud teenused jäid `UP`-ks. Rakendus eristab sõltuvusi ja see aitab kohe õigele hostile minna. Ansible muutis ainult ülesannet `RabbitMQ käib`, sest soovitud seis on `started` ja teenus polnud käimas. Handler ei käivitunud, sest seadistus ei muutunud. Kui `changed=0` ja teenus oleks ikka maas, ebaõnnestub teenus kohe pärast käivitust ja vastus on `journalctl -u rabbitmq-server`-is, mitte Ansible'is.

✅ **Edasi saad minna, kui** peatatud teenusega näitab `/health` `"queue":"DOWN"`, jooksus on `changed` ainult teenuse ülesanne, `/health` on uuesti `UP` ja README-s on kolm vastust.

## Osaline käivitus: tag'id ja --limit

Käivitad ainult osa playbook'ist: ainult deploy, ainult kasutajad, ainult üks host. Enne kui midagi käivitad, vaatad, mis käivituks.

Kogu stacki jooks kasutajate uuendamiseks võtab minuteid ja puudutab teenuseid, mida sa muuta ei tahtnud. Kitsas käivitus on kiirem ja selle mõju on väiksem, aga ainult siis, kui tead, mida see vahele jätab.

1. Vaata, mis käivituks, ilma hostidega ühendumata.

    ```bash
    ansible-playbook site.yml --list-tags
    ansible-playbook site.yml --tags deploy --list-tasks
    ```

2. Käivita osad eraldi.

    ```bash
    ansible-playbook site.yml --tags deploy
    ansible-playbook site.yml --tags users --limit rocky
    ansible-playbook site.yml --skip-tags deploy --limit app01
    ansible-playbook site.yml --start-at-task 'Restart tomcat' --limit app01
    ```

3. Kirjuta README-sse käsk, mis uuendab ainult valvekasutajaid ühel hostil, ja miks viimane käsk ütles, et sellist ülesannet pole.

`--list-tasks` näitab plaani ilma ühendumata ja see on kõige odavam kontroll enne kitsast jooksu. `--tags deploy` käivitas ka faktide kogumise, sest faktid on igal play'l ja deploy vajab neid. `--start-at-task` ei leidnud handlerit, sest handler pole ülesanne: see käivitub ainult teavituse peale. Tag'id ja `--limit` koos annavad kaks telge: mida teha ja kus.

✅ **Edasi saad minna, kui** `--tags deploy` käivitub ainult deploy ülesanded ja faktide kogumise ning annab `changed=0` ja README-s on kaks vastust.

## Handler käivitub ainult muudatuse korral

Tõestad, et handler käivitub ainult siis, kui teavitav ülesanne muutis midagi, ja ainult üks kord, isegi kui teavitusi oli mitu. Siis teed stackist snapshot'i, kuhu saad tagasi minna.

Pipeline käivitab playbook'i iga merge'iga. Restart igal jooksul tähendaks Tomcati 30–60-sekundilist katkestust iga kord ja `changed` ridu, mille seast tegelikku muudatust enam ei leia.

1. Lisa `env.j2`-sse üks kommentaaririda ja käivita kogu stack.

    ```bash
    ansible-playbook site.yml | grep -E 'RUNNING HANDLER|changed='
    ansible-playbook site.yml | tee scratch/run-handler.txt | tail -7
    ```

2. Kui teisel jooksul on mõni ülesanne `changed`, leia see `-v`-ga ja paranda. Tüüpilised põhjused: `command` ilma `changed_when`-ita, `get_url` ilma kindla failinimeta, eraldi restart, kustutamine, mis kustutab ka sinu rakenduse.
3. Kaks muudatust korraga: lisa `env.j2`-sse teine kommentaaririda ja anna käsureal teine mälu. Mõlemad mallid muutuvad, Tomcati käivitusaeg muutub üks kord.

    ```bash
    ssh app01 systemctl show tomcat -p ActiveEnterTimestamp
    ansible-playbook site.yml --limit app01 -e tomcat_heap=500m | grep -cF 'RUNNING HANDLER [tomcat : Restart tomcat]'
    ssh app01 systemctl show tomcat -p ActiveEnterTimestamp
    ansible-playbook site.yml --limit app01 > /dev/null; ansible-playbook site.yml | tail -7
    ```

4. Kui kõik viis on `changed=0`, tee Proxmoxis igal VM-il snapshot `k02-stack` (**Include RAM** maha).

Handleri rida ainult app01 kohta tõestab, et teised hostid ei saanud tarbetut restarti. Kahe muudatusega jooksus loendas `grep -c` handlerit üks kord, kuigi kaks ülesannet teavitasid: Ansible kogub teavitused kokku ja käivitab iga handleri kord. Viimane käsk ilma `-e`-ta pani `512m` tagasi ja see on õige: `-e` kehtis ainult ühe jooksu. Snapshot tehakse alles `changed=0` seisus, sest ainult siis on see seis, mida kood kirjeldab.

✅ **Edasi saad minna, kui** esimesel jooksul on `RUNNING HANDLER [tomcat : Restart tomcat]` ainult app01 kohta, kahe muudatusega jooks loendab handlerit `1` korra ja käivitusaeg muutus, teine jooks annab viiel hostil `changed=0` ja igal VM-il on snapshot `k02-stack`.

## Commit

Commit'id kolm uut rolli.

```bash
cd ~/labori-seis
git add -A k02-ansible
git commit -m "K2.4 rabbitmq, tomcat, nginx: mallid ja handlerid (closes #N)" && git push
```

Tühi `git status` tähendab, et snapshot ja Git näitavad sama seisu. Kui deploy, TLS-i või intsidendi harjutuses läheb midagi segamini, saad mõlemad koos tagasi keerata.

✅ **Edasi saad minna, kui** `git status --short` on tühi.

📎 **Selle mooduli tõend:** commit `K2.4`; `/health` → `UP`; `scratch/run-handler.txt` handleri reaga (ei lähe Giti); snapshot `k02-stack`; README-s RabbitMQ rikke kolm vastust ja osalise käivituse käsk.

## Miks see nii töötab

**`get_url` ja `unarchive`.** `get_url` koos `checksum`-iga laadib faili ainult siis, kui seda pole või kontrollsumma ei klapi. `unarchive` koos `creates:`-iga pakib arhiivi lahti ainult siis, kui `creates`-is nimetatud faili veel pole.

**Handlerid.** Handlerid lahendavad küsimuse, millal teenus taaskäivitada. Bashis kirjutasid `if muutus; then systemctl restart; fi` iga faili juurde eraldi ja mitu muudatust tähendas mitut taaskäivitust. Handler koondab kõik teavitused ja käivitub üks kord, vaikimisi play iga osa (`pre_tasks`, `roles` ja `tasks`, `post_tasks`) lõpus.

**`flush_handlers` ja järjekord.** `flush_handlers` käivitab teavitatud handlerid kohe, kui järgmine samm vajab juba uut seadistust: kontroll, kasutaja loomine, deploy. Handlerid käivituvad selles järjekorras, nagu nad on failis kirjas, mitte teavituste järjekorras. Seepärast käivitub `Test nginx` alati enne `Reload nginx`-i.

**Kollektsioonid.** Kollektsioonid paigaldatakse vaikimisi kausta `~/.ansible/collections/ansible_collections/<nimeruum>/<nimi>/` (seade `COLLECTIONS_PATH`). Seal näed iga mooduli Pythoni lähtekoodi.

**Mooduli sõltuvused.** Moodul käivitub sihtmasinas, seega peavad ka selle Pythoni sõltuvused (PyMySQL, `python3-firewall`) olema sihtmasinas, mitte control node'is. Erand on inventory plugin'id ja `delegate_to: localhost` ülesanded, mis käivituvad control node'is.

**Rolli parameeter ja `--step`.** Mõlemad on ajutised tööriistad. Rolli parameeter `site.yml`-is peidab väärtuse kohta, kust keegi seda ei otsi, ja `--step` ei sobi automaatikasse. Need on uurimiseks, püsiv väärtus kuulub ikka `host_vars`-i või `group_vars`-i.

**Reload ja restart.** Tomcati unit'il `ExecReload`-i pole, nii et handler teeb restart'i. Pärast unit-faili muutmist on vaja `daemon-reload`-i: `systemd_service` koos `daemon_reload: true`-ga teeb selle enne `state` muutmist samas ülesandes, nii et eraldi handlerit pole vaja.

**Kellele Tomcati failid kuuluvad.** Programm (`bin/`, `lib/`) kuulub root'ile ja kasutajale `tomcat` kuuluvad ainult `conf`, `logs`, `temp`, `webapps` ja `work`. `unarchive` paneb failidele arhiivi omaniku, kui `owner`/`group` puudub, seepärast on õigused rollis eraldi ülesandena.

**Tühi grupp mallis.** Kui grupp `app` on tühi, renderdub upstream ilma ühegi `server` reata ja Nginx keeldub sellist seadistust laadimast. Test enne reload'i peatab play ja vana seadistus jääb tööle.

Kui jõudsid kiiremini: [Lisaülesanded → 3. Rolli parameeter ja sammhaaval käivitus](lisa.md#3-rolli-parameeter-ja-sammhaaval-kaivitus), annad Tomcati rollile väärtuse play's ja läbid `site.yml`-i `--step`-iga ülesande kaupa.
