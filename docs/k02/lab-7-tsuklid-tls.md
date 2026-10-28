---
tags:
  - Ansible
  - Jinja2
  - TLS
---

# 7. Tsüklid, mallid ja TLS

Stack töötab, aga tulemüüri reeglid on laiali, täis ketas lõhub poole stacki, vigane Nginxi fail jääb kettale, sert aegub märkamatult, kasutaja õigused kaovad ja logid tuleb intsidendi ajal käsitsi kokku korjata. Nüüd tulevad loendid muutujatest, eelkontroll peatab kõik hostid enne esimest muudatust, mall kontrollib end ise enne paigaldamist ja web01 saab HTTPS-i labori oma CA serdiga. Pärast iga etappi peab teine `site.yml` jooks olema endiselt `changed=0`, sest ümberkorraldus, mis masinaid muudab, on peidetud muudatus.

Lõpuks kogud logid kõigilt hostidelt ühe käsuga ja käivitad Ansible'iga esimese konteineri.

**Kui teed seda tööl iga päev:** tulemüüri pordid tulevad sul grupi muutujast, mallidel on `validate:` ja `site.yml`-i alguses on eelkontroll `any_errors_fatal`-iga; teine `site.yml` jooks on `changed=0`. Kui see on sul juba korras, mine otse etappi [„Oma CA ja HTTPS web01-l“](#oma-ca-ja-https-web01-l).

## Loendid muutujast: paketid ja tulemüüri pordid

Lisad rollile `common` admini tööriistad ja viid tulemüüri pordid MariaDB ja Memcached'i rollist grupi muutujasse, mida `common` läbib tsükliga. Näed kolme kuju: list ühe mooduli parameetrina, `loop` üle sõnastiku `dict2items`-iga ja `loop_control: label`, mis hoiab väljundi loetavana.

Kui port on kirjas kahe rolli sees, peab uue teenuse lisaja teadma, kuhu vaadata, ja tulemüüri tegelik poliitika on mitmes failis laiali. Kui pordid on grupi muutujas, näitab üks `ansible-inventory --host` käsk, mis peab hostis avatud olema.

1. Muuda rolle. Nõuded:
    - `roles/common/defaults/main.yml`: `common_packages: [jq, lsof, rsync, tar, unzip]` ja üks `ansible.builtin.package` ülesanne kogu listiga, ilma `loop`-ita
    - `group_vars/db.yml`: `labseis_fw_ports: {mariadb: 3306/tcp}`, `group_vars/cache.yml`: `labseis_fw_ports: {memcached: 11211/tcp}`
    - rollis `common` üks `ansible.posix.firewalld` ülesanne, `loop: "{{ labseis_fw_ports | default({}) | dict2items }}"`, `label` teenuse nime ja pordiga, ainult kui `labseis_firewalld` on tõene
    - MariaDB ja Memcached'i rollist kustuta `service_facts` ja `firewalld` ülesanded; valvekasutajate tsüklil on `label: "{{ item.name }}"`
2. Käivita ja vaata hostidest.

    ```bash
    ansible-inventory --host db01 | grep -A2 fw_ports
    ansible-playbook site.yml --limit rocky | grep -E 'item=|changed='
    ssh db01 sudo firewall-cmd --list-ports; ssh mc01 sudo firewall-cmd --list-ports
    ansible-playbook site.yml | tail -7
    ```

3. Lisa ajutiselt `group_vars/rocky.yml`-i `labseis_fw_ports: {ssh: 22/tcp}` ja vaata uuesti `--host db01`. Taasta fail `git checkout`-iga.
4. Kirjuta README-sse, miks `ssh` rida `db01` muutujatest puudus ja kuidas sa ühise ja grupi osa kokku paneksid.

> `curl` jäi listist välja meelega: Rocky minimal'is on pakett `curl-minimal` ja `curl` läheb sellega konflikti.

`item=mariadb 3306/tcp` väljundis on `label`-i töö: ilma selleta väljastaks Ansible iga rea juurde kogu sõnastiku. Pordid jäid hostides samaks ja teine jooks andis `changed=0`. See tõestab, et ümberkorraldus muutis koodi, mitte masinaid. Pakettide list on üks apt või dnf tehing ja üks `changed` rida, tsükkel oleks viis tehingut. `ssh` kadus, sest `db` on `rocky` lapsgrupp ja võidab, ning Ansible asendab sõnastiku tervikuna, mitte ei liida. Ühise osa jaoks on eraldi muutuja ja `combine` filter.

✅ **Edasi saad minna, kui** tsükli read näitavad ainult teenuse nime ja porti, db01-s on `3306/tcp` ja mc01-s `11211/tcp`, teine jooks on viiel hostil `changed=0` ja README-s on sõnastiku vastus.

## Eelkontroll: üks host peatab kõik

Lisad `site.yml`-i algusesse play, mis kontrollib igal hostil vaba kettaruumi enne, kui ükski roll midagi muudab. Kui ühel hostil on ruumi liiga vähe, ei lähe edasi ükski host: selleks on play'l `any_errors_fatal: true`. Vaba ruumi loed faktist `ansible_facts['mounts']`, mis on list sõnastikest, ja õige rea leiad `selectattr`-iga.

Täis ketas on tavaline öise jooksu põhjus: pakett jääb pooleldi lahti ja MariaDB ei käivitu. `max_fail_percentage` peatab alles järgmise batch'i, aga sama batch'i teised hostid jõuavad muudatuse ära teha. Eelkontroll peatab kõik enne esimest muudatust.

1. Muuda `site.yml`-i. Nõuded:
    - esimene play "Eelkontroll kõigil hostidel", `hosts: all`, `any_errors_fatal: true`; `wait_for_connection` ja `setup` tõstad siia rolli `common` play'st (`pre_tasks`)
    - `ansible.builtin.assert`: `/` rea `size_available` jagatud 1048576-ga on vähemalt `labseis_min_free_mb` (`group_vars/all/main.yml`, `1024`), `fail_msg` nimetab hosti
    - rolli `common` play saab `gather_facts: false`, sest faktid on samast jooksust juba olemas
2. Vaata, mis kujul fakt on, täida mc01 ketas peaaegu täis ja käivita.

    ```bash
    ansible mc01 -m ansible.builtin.setup -a 'filter=ansible_mounts' | grep -E '"mount"|size_available'
    ssh mc01 'sudo fallocate -l $(( $(df --output=avail -m / | tail -1) - 500 ))M /var/tmp/taide'
    ansible-playbook site.yml | grep -E 'fatal|NO MORE|ok='
    ssh mc01 sudo rm /var/tmp/taide && ansible-playbook site.yml | tail -7
    ```

3. Kirjuta README-sse, mis oli teiste nelja hosti olek ja mis oleks juhtunud ilma `any_errors_fatal`-ita.

mc01 ebaõnnestus assert'is ja ülejäänud neli läbisid selle, aga ükski ei jõudnud rolli `common`-ini: väljundis on `NO MORE HOSTS LEFT` ja nende RECAP-is pole ühtki muudatust. Ilma `any_errors_fatal`-ita oleks neli hosti jätkanud ja Tomcat oleks saanud uue seadistuse andmebaasi järel, mis ei käivitunud. `size_available` on baitides ja `| first | default(0)` kaitseb juhuks, kui `/` rida puudub, nagu mõnes konteineris.

✅ **Edasi saad minna, kui** täis kettaga ebaõnnestub mc01 eelkontrollis, teised hostid ei jõua ühegi rollini, pärast `rm`-i on jooks viiel hostil roheline ja README-s on kaks vastust.

## Nginxi mall: filtrid, tingimus ja validate

Teed Nginxi malli paindlikumaks ja paned selle end ise kontrollima. `default([])` lubab grupil puududa, `join` paneb nimede listi ühele reale, `{% if %}` lülitab HTTPS-ploki muutujaga ja tsükli sees märgib `down` hoolduses oleva hosti. `validate:` kontrollib renderdatud faili enne, kui see jõuab `sites-available`-isse.

Kogu stacki ehitades kaitses sind handler `Test nginx`, aga siis oli vigane fail juba kettal. Järgmine reboot või kolleegi `systemctl restart nginx` jätab saidi maha ja keegi ei seosta seda eilse jooksuga. `validate` jätab vigase faili üldse paigaldamata.

Failimoodulite valik sõltub sellest, kellele fail kuulub.

| Moodul | Sobib, kui | Laboris | Oht |
|---|---|---|---|
| `lineinfile` | üks rida paketi failis | Memcached'i `-l` / `OPTIONS` | regexp leiab mitu rida või mitte ühtki ja lisab uue |
| `blockinfile` | mitu rida jagatud failis | `/etc/hosts` plokk | kustutatud marker tähendab teist plokki |
| `template` | kogu fail on sinu | Nginxi sait, `env`, unit | käsitsi muudatus kaob järgmisel jooksul |

*Tabel L2.1. Kolm viisi faili muuta.*

1. Muuda rolli `nginx`. Nõuded:
    - `defaults/main.yml`: `nginx_tls: false` (järgmises etapis lülitad sisse), `nginx_tls_dir: /etc/ssl/labori-seis`, `nginx_drain_hosts: []`
    - upstream'i tsükkel üle `groups['app'] | default([])`, rea lõpus ` down`, kui host on `nginx_drain_hosts`-is
    - `server_name` listist `[inventory_hostname, ansible_host]` `join(' ')`-iga; `{% if nginx_tls | bool %}` ploki sees `listen 443 ssl`, `ssl_certificate`, `ssl_certificate_key` ja `ssl_protocols TLSv1.2 TLSv1.3`
    - `copy` skript `/usr/local/sbin/nginx-validate-site` (`0755`) ja mallile `validate: /usr/local/sbin/nginx-validate-site %s`
2. Saidi fail üksi pole terve `nginx.conf` ja `nginx -t -c` keelduks sellest. Skript pakib faili ajutise `http`-ploki sisse:

    ```sh
    #!/bin/sh
    conf=$(mktemp /tmp/nginx-validate.XXXXXX)
    trap 'rm -f "$conf"' EXIT
    printf 'events {}\nhttp {\n include /etc/nginx/mime.types;\n include %s;\n}\n' "$1" > "$conf"
    nginx -t -q -c "$conf"
    ```

3. Käivita kaks korda: esimene paigaldab skripti ja uue malli, teine peab olema `changed=0`.

    ```bash
    ansible-playbook site.yml --limit web > /dev/null; ansible-playbook site.yml --limit web | tail -3
    ```

4. Kustuta mallis upstream'i `server` rea lõpust `;`, käivita ja vaata, mis hostis alles jäi.

    ```bash
    ansible-playbook site.yml --limit web | grep -E 'failed to validate|fatal'
    ssh web01 'sudo nginx -T 2>/dev/null | grep -A2 "upstream labori_seis"'; curl -s http://web01/health; echo
    git checkout roles/nginx/templates/labori-seis.conf.j2
    ```

5. Vaata hooldusrežiimi ainult plaanina.

    ```bash
    ansible-playbook site.yml --limit web --check --diff -e '{"nginx_drain_hosts": ["app01"]}' | grep -E '^[-+] +server'
    ```

Vigane mall ebaõnnestus ülesandes `Saidi seadistus` ja `nginx -T` näitas vana upstream'i: fail kettal ja töötav seadistus jäid puutumata ning `/health` vastas edasi. Handlerit ei teavitatud, sest ülesanne ei muutunud. Hooldusrežiimi diff näitas üht rida: `down` märgiga host ei saa päringuid, aga jääb upstream'i. Ühe app-hostiga tähendaks see 502-t kõigile, seepärast jäi see plaaniks. Kui `nginx_tls` on `false`, renderdub mall nagu enne TLS-i ja teine jooks on `changed=0`.

✅ **Edasi saad minna, kui** puuduva `;`-ga ebaõnnestub jooks `failed to validate` veaga, `/health` vastab samal ajal ja upstream on endine, diff näitab ` down` rida ja pärast `git checkout`-i on teine jooks `changed=0`.

## Oma CA ja HTTPS web01-l

Ansible teeb control node'is labori CA ja web01 serdi `community.crypto` moodulitega ja viib web01-le ainult serveri serdi ja võtme. Krüptoülesanded käivituvad `delegate_to: localhost`-iga ja ilma sudo'ta (`become: false`). CA ülesannetel on lisaks `run_once: true`, sest CA on üks kogu labori kohta, ka siis, kui web-hoste on mitu.

Iseallkirjastatud serdiga lõpeb see `curl -k` ja `validate_certs: false`-ga igas playbook'is. Oma CA puhul antakse kliendile (`--cacert`, `ca_path`, `ca_cert`) üks fail ja kontroll jääb sisse.

1. Control node'is: `pipx inject ansible-core cryptography`, `requirements.yml`-i `community.crypto` (`">=3.0.0,<4.0.0"`) ja paigaldus.
2. Kirjuta `roles/nginx/tasks/tls.yml`. Nõuded:
    - `group_vars/all/main.yml`: `labseis_pki_dir: "{{ lookup('ansible.builtin.env', 'HOME') }}/.config/is1/pki"`, rolli vaikeväärtus `nginx_pki_dir: "{{ labseis_pki_dir }}"`
    - kaust `0700`, CA võti `openssl_privatekey`, CA taotlus `openssl_csr` (`basic_constraints: ["CA:TRUE"]`, `key_usage: [keyCertSign, cRLSign]`, mõlemad critical), CA sert `x509_certificate` `provider: selfsigned`; kõigil `delegate_to: localhost`, `become: false`, `run_once: true`
    - serveri võti, taotlus (`subject_alt_name`: `DNS:<host>` ja `IP:<ansible_host>`, `extended_key_usage: [serverAuth]`) ja sert `provider: ownca`, `ownca_not_after: "+90d"`; `delegate_to: localhost`, `become: false`, ilma `run_once`-ita
    - `copy` kausta `nginx_tls_dir` (sert `0644`, võti `0600`, `loop` + `label`), teavitab mõlemat handlerit
    - `tasks/main.yml`: `import_tasks: tls.yml` enne malli, `when: nginx_tls | bool`, `tags: [tls]`; `nginx_tls: true`
3. Käivita ja kontrolli kliendi poolt.

    ```bash
    ansible-playbook site.yml --limit web | grep -E 'localhost|RUNNING HANDLER|changed='
    ls -l ~/.config/is1/pki/
    curl -s https://web01/health; echo "kood $?"
    curl -s --cacert ~/.config/is1/pki/ca.crt https://web01/health; echo
    openssl s_client -connect web01:443 -servername web01 </dev/null 2>/dev/null | openssl x509 -noout -issuer -enddate -ext subjectAltName
    ```

> CA võti `ca.key` ei lähe Giti ega sihtmasinasse.

Read kujul `web01 -> localhost` tähendavad, et ülesanne käivitus control node'is web01 muutujatega, nagu rolling deploy health check käivitus web01-s app01 muutujatega. Kood `60` ilma `--cacert`-ita on õige: süsteem ei tunne sinu CA-d ja keeldub. `--cacert`-iga vastab `/health`, issuer on "Labori seis CA" ja SAN-is on nii nimi kui IP. Teine jooks on `changed=0`, sest moodulid võrdlevad olemasolevaid faile ega loo neid uuesti. Tootmises tehakse serveri võti tavaliselt hostis ja liigub ainult taotlus. Siin hoiab ühe masina mudel koodi lühikese.

✅ **Edasi saad minna, kui** `curl --cacert` annab `{"status":"UP",…}`, ilma selleta kood `60`, `pki/` kaustas on `ca.key` õigustega `-rw-------` ja teine `site.yml` jooks on viiel hostil `changed=0`.

## import_tasks või include_tasks

`tls.yml` tuli `import_tasks`-iga. Siin paned samasse kohta ajutiselt `include_tasks`-i ja vaatad kahte erinevust: kas `--list-tasks` näeb sisemisi ülesandeid ja kas `--tags tls` need käivitab. Mõlemad on igapäevased käsud, kui tahad ainult serti uuendada.

Vale valik ei anna viga. `--tags tls` lõpeb roheliselt, sert jääb uuendamata ja sa saad sellest teada alles siis, kui see aegub.

1. Vaata praegust plaani ja kitsast jooksu.

    ```bash
    ansible-playbook site.yml --limit web --list-tasks | grep -E 'CA |Serveri|TAGS: \[tls'
    ansible-playbook site.yml --limit web --tags tls | grep -E 'TASK|changed='
    ansible-playbook site.yml --limit web --skip-tags tls --list-tasks | grep -c Serveri
    ```

2. Muuda `import_tasks` ajutiselt `include_tasks`-iks ja korda kahte esimest käsku.
3. Lisa include'ile `apply: {tags: [tls]}`, korda teist käsku ja taasta fail: `git checkout roles/nginx/tasks/main.yml`.
4. Kirjuta README-sse tabel ridadega `import` ja `include` ning veergudega: kas `--list-tasks` näitab sisemisi ülesandeid, kas `--tags tls` need käivitab, millal `when` hinnatakse.

`import_tasks` on staatiline: Ansible loeb faili sisse playbook'i laadimisel, ülesanded on plaanis nähtavad ja `tags` ning `when` kopeeritakse igale ülesandele. `include_tasks` on dünaamiline: fail loetakse jooksu ajal, `--list-tasks` näeb ainult include rida ja tag kehtib ainult sellele reale, nii et sisemised ülesanded jäid vahele. `when` hinnatakse include'il üks kord, import'il iga ülesande eel. Include on vajalik siis, kui failinimi tuleb muutujast või kui faili tahad tsüklis korrata. Muul juhul vali import.

✅ **Edasi saad minna, kui** import'iga käivitub `--tags tls` serdi ülesanded, include'iga ilma `apply`-ta mitte, `--skip-tags tls` loendab `0` ja README tabelis on kaks rida.

## Serdi aegumine: failed_when, mitte ignore_errors

Kontrollid, kui kaua sert kehtib. Kõigepealt kirjutad kontrolli valesti `ignore_errors`-iga ja vaatad, mida pipeline sellest näeks. Siis kirjutad sama õigesti ja lisad `verify.yml`-i kontrolli, mis küsib serti pordist 443 nii, nagu klient seda näeb.

Aegunud sert on planeeritav katkestus, mis ikka üllatab. `ignore_errors` teeb asja hullemaks: viga väljastatakse punaselt, aga väljumiskood on `0` ja pipeline on roheline.

1. Tee `scratch/sert.yml` (`hosts: web`): `command: openssl x509 -checkend 34560000 -noout -in /etc/ssl/labori-seis/web01.crt` (400 päeva), `changed_when: false`, `ignore_errors: true`.

    ```bash
    ansible-playbook scratch/sert.yml | grep -E 'ignoring|ignored='; echo "kood ${PIPESTATUS[0]}"
    ```

2. Asenda `ignore_errors` `register`-i ja `failed_when`-iga, mis on tõene ainult siis, kui väljundis pole `Certificate will` (käsk ise ei töötanud). Lisa järgmine ülesanne `assert`, mis nõuab `will not expire` ja ütleb `fail_msg`-is, mitme päeva peale kontroll tehti. Käivita ja vaata koodi.
3. Lisa `verify.yml`-i play `hosts: web`. Nõuded:
    - `community.crypto.get_certificate` (`host` IP-ga, `port: 443`, `server_name`, `ca_cert` CA failiga), `delegate_to: localhost`, `become: false`
    - `community.crypto.x509_certificate_info` `content: "{{ <register>.cert }}"`, `valid_at: {piisav: "+{{ labseis_cert_min_days }}d"}` (`group_vars/all`, `30`)
    - `uri` `https://<IP>/health` `ca_path`-iga control node'ist
    - `assert`: sert pole aegunud, `valid_at['piisav']` on tõene ja SAN-is on `DNS:<host>`

    ```bash
    ansible-playbook verify.yml | tail -6
    ansible-playbook verify.yml -e labseis_cert_min_days=120 | grep -E 'failed:|msg'
    ```

`ignore_errors` andis RECAP-is `ignored=1` ja koodi `0`: pipeline oleks selle läbi lasknud. `failed_when` eraldab kaks asja, mida `openssl` annab sama koodiga `1`: "sert aegub" on vastus, "faili pole" on viga. `assert` muudab vastuse arusaadavaks veaks ja kood on `2`. Verify ebaõnnestus 120 päevaga, sest sert kehtib 90 päeva. Kontroll küsis serti võrgust, nii et see leiab ka juhu, kus fail on uuendatud, aga Nginx pole seda veel laadinud.

✅ **Edasi saad minna, kui** `ignore_errors`-iga on kood `0` ja `ignored=1`, `failed_when` ja `assert`-iga kood `2`, verify on roheline ja `-e labseis_cert_min_days=120` nurjab selle aegumise kuupäevaga sõnumis.

## RabbitMQ API: until ja kasutaja õigused

Lülitad RabbitMQ-s sisse management plugin'i ja kontrollid HTTP API kaudu, et rakenduse kasutaja on olemas ja näeb oma vhost'i. Plugin vajab käivitumiseks paar sekundit. `until`, `retries` ja `delay` ootavad nii kaua, kui vaja, aga mitte lõputult.

`rabbitmqctl list_users` ütleb, et kasutaja on olemas, aga mitte seda, kas tal on õigused. Kui õigused kaovad, näed seda alles siis, kui rakendus proovib sõnumit saata. API kontroll leiab selle varem ja samamoodi, nagu rakendus ühendub: rakenduse kasutaja ja parooliga.

1. Muuda rolli `rabbitmq` ja `verify.yml`-i. Nõuded:
    - `community.rabbitmq.rabbitmq_plugin` (`names: rabbitmq_management`, `state: enabled`) enne kasutajat; rakenduse kasutajale `tags: management`
    - rolli lõpus `uri` `http://localhost:15672/api/whoami` (kasutaja ja parool `labseis_mq_*` muutujatest, `force_basic_auth: true`, `no_log: true`, `check_mode: false`), `until` staatus `200`, `retries` ja `delay` rolli `defaults`-ist (`20`, `3`)
    - `verify.yml` play `hosts: queue`: `uri` `http://<IP>:15672/api/vhosts` control node'ist (`delegate_to: localhost`, `become: false`, `no_log: true`) ja `assert`, et nimede seas on `/`
2. Käivita, võta kasutajalt õigused ja vaata, kes märkab.

    ```bash
    ansible-playbook site.yml --limit queue | grep -E 'RETRYING|API|changed='
    ssh rmq01 sudo rabbitmqctl clear_permissions -p / labseis
    curl -s http://web01/health; echo; ansible-playbook verify.yml 2>&1 | grep -E 'failed:|msg'
    ansible-playbook site.yml --limit queue | grep -E 'changed:|changed='
    ansible-playbook verify.yml | tail -6
    ```

3. Kirjuta README-sse, mitu `RETRYING` rida oli esimesel jooksul, mida näitas `/health` õiguste kadumise ajal ja miks `tags: management` on laboris sobiv, aga tootmises mitte.

`RETRYING` read on `until` töö: iga rida on üks ootamine `delay` sekundit ja nende arv ütleb, kui kaua API käivitus. Ilma `until`-ita oleks esimene jooks värskel VM-il juhuslikult ebaõnnestunud. Õiguste kadumise järel ebaõnnestus verify vhost'i kontrollis ja `site.yml` taastas õigused ühe `changed` reaga, sest õigused on rolli soovitud seisus kirjas. `management` tag lubab rakenduse kasutajal API-d lugeda. Tootmises oleks selleks eraldi monitooringu kasutaja, et rakenduse parool ei peaks kontrollini jõudma.

✅ **Edasi saad minna, kui** esimesel jooksul ootab `until` API-t, õigusteta kasutajaga ebaõnnestub verify vhost'i kontrollis, `site.yml` taastab õigused ja verify on uuesti roheline.

## Logid kokku: fetch, archive ja unarchive

Kirjutad `logs.yml`-i, mis kogub viimase kahe tunni teenuselogid igalt hostilt, pakib need hostis ja toob control node'i. Intsidendiülesandes kasutad seda esimese sammuna: logid ühes kohas enne, kui keegi midagi taaskäivitab.

Journal'i vanad read kaovad rotatsiooniga, rollback kustutab VM-i seisu ja iga taaskäivitus lükkab vana vea ekraanilt välja. Viiest hostist logide käsitsi kogumine võtab kümme minutit, mida intsidendi ajal pole.

1. Kirjuta `k02-ansible/logs.yml`. Nõuded:
    - play muutuja `logs_units: {db: mariadb, cache: memcached, queue: rabbitmq-server, app: tomcat, web: nginx}`; hosti teenused `dict2items | selectattr('key', 'in', group_names) | map(attribute='value') | list`
    - `journalctl -u <teenus> --since {{ logs_since }}` tsükliga (`changed_when: false`, `check_mode: false`), väljund `copy`-ga faili `/var/tmp/labseis-logs/<teenus>.log` (`0600`, `label`)
    - `community.general.archive` kogu kaustast (`requirements.yml`-i `community.general`), `fetch` `flat: true` kausta `scratch/logs/`
    - control node'is kaust `run_once: true`-ga ja `unarchive` hosti kausta; mõlemal `delegate_to: localhost`, `become: false`
2. Käivita ja otsi vigu kõigi hostide logidest korraga.

    ```bash
    ansible-galaxy collection install -r requirements.yml && ansible-lint logs.yml
    ansible-playbook logs.yml | grep -E 'item=|changed='
    find scratch/logs -name '*.log' | sort
    grep -ril error scratch/logs --include='*.log'
    ```

Iga host kogus ainult oma teenuse logi, sest `selectattr` jättis alles ainult need grupid, kuhu host kuulub. `flat: true` paneb faili otse kausta ja hosti nimi on failinimes. Ilma selleta teeks `fetch` iga hosti jaoks kogu tee `<host>/var/tmp/…`. Kausta pakkimine annab alati `tar.gz`-i: üksik fail oleks paljas `.gz`, mida `unarchive` ei ava. Vanemates juhendites näed `local_action:` kuju. See on sama mis `delegate_to: localhost`, aga lint märgib selle aegunuks. See playbook muudab igal jooksul faile `/var/tmp/` all ja see on õige: tegemist on tööriistaga, mitte soovitud seisuga, ja `site.yml`-i see ei kuulu.

✅ **Edasi saad minna, kui** `scratch/logs/` all on viis pakki ja viis hosti kausta, igas ainult selle hosti teenuse logi, ja `ansible-lint logs.yml` on puhas.

## Sama teenus konteineris Ansible'iga

Ansible ei seadista ainult VM-e. `community.docker.docker_container` käivitab control node'i Dockeris Memcached'i testkonteineri sama mõttega nagu teised moodulid: soovitud seis on konteiner selle nime, image'i ja pordiga, mitte käsk `docker run`.

3. kohtumisel ehitad stacki konteineritesse ja kirjutad sama asja Compose'is. Kui tead, et ka konteiner on soovitud seis, näed, miks käsitsi `docker run` skriptis on sama mis `command` ilma `changed_when`-ita: see ei tea, kas konteiner on juba olemas.

1. Control node'is peab Docker töötama ilma sudo'ta (3. kohtumise leht [Konteinerid käsitsi](../k03/lab-1-kasitsi.md), sammud 2–4). Siis `pipx inject ansible-core docker` ja `requirements.yml`-i `community.docker`.
2. Kirjuta `k02-ansible/memcached-docker.yml`. Nõuded:
    - `hosts: localhost`, `gather_facts: false`, `become: false`
    - konteiner `labseis-mc-test`, image `memcached:1.6-alpine`, port `127.0.0.1:11212:11211`, olek muutujast `mc_test_state` (vaikimisi `started`)
    - `wait_for` pordile ja `bash` käsk, mis saadab `version` ja ebaõnnestub `failed_when`-iga, kui vastus ei alga `VERSION`-iga; mõlemad ainult `started` olekus
3. Käivita, kustuta konteiner käsitsi, käivita uuesti ja koristus.

    ```bash
    ansible-playbook memcached-docker.yml && ansible-playbook memcached-docker.yml | tail -2
    docker ps --filter name=labseis-mc-test --format '{{.Image}} {{.Ports}}'
    docker rm -f labseis-mc-test && ansible-playbook memcached-docker.yml | tail -2
    ansible-playbook memcached-docker.yml -e mc_test_state=absent | tail -2
    ```

Teine jooks oli `changed=0`: moodul küsis Dockerilt konteineri seisu ja nägi, et see vastab soovitule. Käsitsi kustutatud konteiner tuli järgmise jooksuga tagasi, täpselt nagu peatatud teenus kogu stacki ehitades. Port seoti ainult `127.0.0.1`-ga, nii et testkonteiner pole võrgust kättesaadav. `absent` olek on sama soovitud seis vastupidi ja koristab konteineri ühe käsuga.

✅ **Edasi saad minna, kui** teine jooks on `changed=0`, `docker ps` näitab `memcached:1.6-alpine 127.0.0.1:11212->11211/tcp`, kustutatud konteiner tuleb jooksuga tagasi ja `absent` eemaldab selle.

## Commit

Commit'id loendid, eelkontrolli, malli, TLS-i, API kontrolli, logide ja konteineri playbook'i.

```bash
cd ~/labori-seis
git add -A k02-ansible
git commit -m "K2.7 loendid, eelkontroll, mall, TLS, API, logid (closes #N)" && git push
bash autograde/check.sh k02 lint && bash autograde/check.sh k02 syntax
git ls-files k02-ansible | grep -E '\.key$|\.crt$|pki/|scratch/' || echo puhas
```

`OK` mõlemas kontrollis tähendab, et uued playbook'id ja kollektsioonid paigalduvad ka automaatses hindajas, kus pole sinu kohalikku seadistust. `puhas` tähendab, et CA ja serdid on ainult `~/.config/is1/pki/`-s ja logid ainult `scratch/`-is.

✅ **Edasi saad minna, kui** `lint` ja `syntax` annavad `OK`, viimane käsk ütleb `puhas` ja `ansible-playbook verify.yml` on roheline.

📎 **Selle mooduli tõend:** commit `K2.7`; README-s sõnastiku vastus, eelkontrolli kaks vastust, import/include tabel, RabbitMQ kolm vastust; `verify.yml` roheline HTTPS-i ja API kontrolliga; `scratch/logs/` (ei lähe Giti).

## Miks see nii töötab

**`loop` ja `with_*`.** `loop` asendas vanemad `with_items`, `with_dict` ja teised `with_*` kujud. `with_dict: "{{ x }}"` on sama mis `loop: "{{ x | dict2items }}"`, kus iga element on sõnastik `{key, value}`.

**List parameetrina.** Kui moodul võtab listi (`package`, `apt`, `dnf`, `user` gruppide jaoks), anna list parameetrina, mitte tsüklina. Üks tehing on kiirem ja paketihaldur lahendab sõltuvused korraga.

**`loop_control`.** `loop_control` toetab peale `label`-i ka võtmeid `index_var` ja `loop_var`. Viimast on vaja, kui tsüklis kaasatud fail kasutab ise muutujat `item`.

**Sõnastike liitmine.** Sõnastikud ei liitu üle prioriteeditasemete: kõrgem tase asendab kogu väärtuse. Konfiguratsioonifaili seade `hash_behaviour = merge` muudaks seda kogu projektis ja on aegunud. Seepärast liidetakse sõnastikud ühes kohas filtriga `combine`.

**CA sert.** `x509_certificate` `provider: selfsigned` ei lisa laiendeid ise: `basicConstraints CA:TRUE` ja `keyUsage keyCertSign` tulevad CSR-ist, mille tegi `openssl_csr`. Kui need puuduvad, teeb moodul vaikselt tavalise serdi ja `ownca` allkirjastatud serdid ei valideeru.

**Serveri sert ja SAN.** Kui `subject_alt_name` puudub, paneb `openssl_csr` CN-i ise SAN-i (`use_common_name_for_san`, vaikimisi tõene). Kui annad SAN-i ise, pead sinna kirjutama ka nime ja IP-ga ühendumiseks eraldi `IP:` kirje.

**Võtme tüüp.** `openssl_privatekey` teeb vaikimisi RSA 4096 võtme. `type: ECC` ja `curve: secp256r1` annavad väiksema võtme ja kiirema käepigistuse ning kursuse Nginx ja curl toetavad seda; vanemad kliendid ja osa manussüsteeme toetavad ainult RSA-d.

**Serdi uuendamine.** `x509_certificate` ei uuenda serti ise, kui aegumine läheneb (community.crypto 2.0-st alates on `ignore_timestamps` vaikimisi tõene). Moodul kontrollib ainult, kas sert vastab taotlusele ja CA-le. Seepärast on aegumise kontroll `verify.yml`-is. Idempotentne moodul hoiab ainult seda seisu, mida selle parameetrid kirjeldavad: aeg ei ole parameeter, kui sa aja kontrolli ise ei lisa.

**ACME ja sisemine CA.** Tootmises teeb sama töö ACME (`community.crypto.acme_certificate`) või sisemine CA, näiteks HashiCorp Vaulti PKI.

Kui jõudsid kiiremini: [Lisaülesanded → 12. Lühike sert ja uuendamine](lisa.md#12-luhike-sert-ja-uuendamine), teed 2-päevase serdi ja playbook'i, mis uuendab selle enne aegumist ilma katkestuseta.
