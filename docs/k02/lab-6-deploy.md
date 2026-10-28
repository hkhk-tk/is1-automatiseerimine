---
tags:
  - Ansible
  - deploy
  - rolling update
---

# 6. Deploy ja rolling

Uus versioon ei käivitu kell 2 öösel ja kasutaja näeb 502-t, kuni keegi vana WAR-i käsitsi üles leiab; igakuine patch'imine teeb reboot'i kõigile hostidele korraga. Paigaldus juhtub korra, deploy kümneid kordi kuus: pipeline käivitab `deploy.yml`-i iga uue versiooniga ja iga kord võib juhtuda, et uus versioon ei käivitu. Nüüd teed deploy, mis läheb vea korral ise eelmisele versioonile tagasi, jätab töötava versiooni hosti custom fact'i ja vahetab hoste ükshaaval, kusjuures health check peatab rollout'i, kui rakendus pärast deploy'd ei vasta.

Lõpuks on sama rolling-muster ka `web.yml`-il, kus on kaks hosti ja näed, et teine jääb puutumata, ja `patch.yml`-il, mis paikab OS-i lainetena ja teeb reboot'i ainult seal, kus vaja.

**Kui teed seda tööl iga päev:** `deploy.yml` kasutab `block`/`rescue`/`always`-i, `rescue` lõpeb `fail`-iga, play'l on `serial: 1` ja `max_fail_percentage: 0` ning health check käib `delegate_to`-ga web01-st; `ansible-playbook deploy.yml -e labseis_version=v9.9.9` lõpeb `failed=1` ja `/health` jääb `200`-ks. Kui see on sul juba korras, mine otse etappi [„Paigad ja reboot lainetena“](#paigad-ja-reboot-lainetena).

> ⚠️ Enne alustamist peab `ansible-playbook verify.yml` olema roheline. Kui stack läheb segamini: rollback kõigil viiel snapshot'ile `k02-stack`, siis `ansible-playbook site.yml`. Rollback kaotab ka pärast snapshot'i lisatud andmebaasi read, laboris on andmestik `seed.sql`-ist taastatav. Ilma rohelise verify'ta ei tea sa, kas rike tuli sinu deploy'st või oli juba enne olemas.

## block, rescue, always: deploy, mis läheb tagasi

Kirjutad Tomcati deploy ümber kolmeks osaks. `block` teeb vahetuse ja kontrollib tulemust. `rescue` käivitub ainult siis, kui block ebaõnnestus, ja paneb eelmise versiooni tagasi. `always` käivitub mõlemal juhul ja kirjutab üles, mis versioon nüüd töötab.

Ilma rollback'ita tähendab ebaõnnestunud deploy, et keegi peab öösel käsitsi vana WAR-i otsima ja Tomcati taaskäivitama. Ilma `always`-ita ei tea järgmine deploy, mis versioon oli viimati töötav, ja rollback ei saa toimida.

Muuda `roles/tomcat/tasks/deploy.yml`-i. Nõuded:

- enne blokki: kaust `/etc/ansible/facts.d` ja `set_fact` `tomcat_previous_version` custom fact'ist `ansible_facts['ansible_local']['deploy']['version']`, vaikimisi tühi (`default({})`, `default('')`)
- `block`: WAR alla, `ROOT.war` vahetus, `flush_handlers`, `/version` kontroll (`retries` ja `delay` rolli vaikeväärtustest `tomcat_health_retries: 30`, `tomcat_health_delay: 4`), lõpus `set_fact` `tomcat_live_version`
- `rescue`: eelmise versiooni WAR tagasi `ROOT.war`-iks (teavitab handlerit), `flush_handlers`, `/version` vastab, `tomcat_live_version` = eelmine, viimasena `ansible.builtin.fail` sõnumiga, mis versioon ebaõnnestus, millises ülesandes (`ansible_failed_task.name`) ja mis nüüd töötab
- `always`: `/etc/ansible/facts.d/deploy.fact` JSON-ina `{"version": "<töötav versioon>"}`, `0644`
- blokil on nimi ja `tags: [deploy]`; lugevatel ülesannetel `check_mode: false` nagu `verify.yml`-is ja rollides

```bash
ansible-playbook site.yml --tags deploy
ssh app01 cat /etc/ansible/facts.d/deploy.fact
ansible app01 -m ansible.builtin.setup -a 'filter=ansible_local'
ansible-playbook site.yml | tail -7
```

> `rescue` lõpeb `fail`-iga meelega. Ilma selleta on host `rescued=1 failed=0`, PLAY RECAP on roheline ja pipeline arvab, et uus versioon on väljas.

`deploy.fact` on hosti mälu: järgmine deploy loeb sealt, kuhu tagasi minna. `setup` näitab seda faktina, nii et seda saab kasutada iga playbook, ka `verify.yml`. `changed=0` kogu stackil tähendab, et `always` kirjutab sama sisu ja ei muuda faili, kui versioon ei muutunud. Kui fail muutuks igal jooksul, oleks idempotentsus kadunud ja `run2.txt` ei läheks automaatsest hindajast läbi.

✅ **Edasi saad minna, kui** `deploy.fact` näitab `{"version": "v1.1.0"}`, `setup` näitab seda `ansible_local` → `deploy` all ja kogu `site.yml` annab ikka `changed=0`.

## Katkine versioon: kaks rikke liiki

Proovid kahte rikke liiki ja vaatad samal ajal, mida kasutaja näeb. Esimesel juhul faili pole üldse ja vahetust ei toimu. Teisel juhul fail tuleb, Tomcat taaskäivitub ja rakendus ei käivitu. Mõlemal juhul peab kasutaja lõpuks nägema töötavat lehte.

Need kaks on kõige sagedasemad deploy-rikked: vale tag pipeline'is ja katkine build. Esimene ei tohiks kasutajale üldse nähtav olla, teine on nähtav ainult taaskäivituse aja.

1. Teises terminalis loe kogu katse ajal, mida kasutaja näeb.

    ```bash
    while sleep 1; do printf '%s %s\n' "$(date +%T)" "$(curl -s -o /dev/null -w '%{http_code}' http://web01/health)"; done | tee scratch/katkestus.txt
    ```

2. Olematu versioon: WAR-i ei saa alla laadida.

    ```bash
    ansible-playbook deploy.yml -e labseis_version=v9.9.9 | grep -E 'rescue|RUNNING HANDLER|fatal|msg|rescued='
    ```

3. Katkine WAR: fail tuleb, rakendus ei käivitu. Lühenda ootamist, et rescue tuleks kiiremini.

    ```bash
    echo katki > /tmp/katki.war
    ansible-playbook deploy.yml -e labseis_version=v0.0.0-katki -e labseis_war_local=/tmp/katki.war -e tomcat_health_retries=8
    ssh app01 cat /etc/ansible/facts.d/deploy.fact
    ```

4. Koristus: `ssh app01 sudo rm /opt/labori-seis/labori-seis-v0.0.0-katki.war`, siis `ansible-playbook deploy.yml` (`changed=0`). Peata teine terminal.
5. Kirjuta README-sse kummagi juhtumi kohta: millised ülesanded käivitusid `rescue`-s, kas Tomcat taaskäivitus, mitu sekundit oli `scratch/katkestus.txt`-is mitte-200 ja mis on `deploy.fact`-is.

Olematu versiooni korral ebaõnnestus juba allalaadimine ja `ROOT.war` jäi puutumata. Rescue kopeeris sama faili tagasi, see oli `ok` ja handler ei käivitunud, nii et kasutaja ei näinud katkestust. Katkise WAR-i korral oli katkestus kaks korda: kord uue versiooni proovimisel ja kord rollback'i ajal. Sekundid `katkestus.txt`-is on selle hind. `deploy.fact` jäi mõlemal juhul `v1.1.0`-ks, sest `always` kirjutab töötava, mitte proovitud versiooni.

✅ **Edasi saad minna, kui** mõlemad jooksud lõpevad app01-l `failed=1` sinu `fail` sõnumiga, olematu versiooni korral Tomcat ei taaskäivitu, katkise WAR-i korral tuleb tagasi `v1.1.0` ja `deploy.fact` on mõlemal juhul `v1.1.0`.

## Deploy ilma mäluta: kui deploy.fact kaob

Kustutad app01-st `deploy.fact`-i ja proovid sama katkist WAR-i uuesti. Nüüd ei tea rescue, kuhu tagasi minna. Sama olukord tekib siis, kui OpenTofu loob app01 uuesti ja hostis pole ühtki fact'i.

Rollback, mis sõltub hosti enda mälust, kaob koos hostiga. Kui sa seda piiri ei tea, usaldad rescue'd ka seal, kus see midagi teha ei saa.

1. Kustuta fact ja proovi katkist versiooni. Teine terminal võib jälle lugeda `/health`-i.

    ```bash
    ssh app01 sudo rm /etc/ansible/facts.d/deploy.fact
    ansible-playbook deploy.yml -e labseis_version=v0.0.0-katki -e labseis_war_local=/tmp/katki.war -e tomcat_health_retries=8 | grep -E 'msg|failed='
    curl -s -o /dev/null -w '%{http_code}\n' http://web01/health
    ssh app01 cat /etc/ansible/facts.d/deploy.fact
    ```

2. Taasta Gitis olev versioon ja koristus.

    ```bash
    ansible-playbook deploy.yml | tail -4
    ssh app01 'sudo rm /opt/labori-seis/labori-seis-v0.0.0-katki.war; cat /etc/ansible/facts.d/deploy.fact'
    curl -s -o /dev/null -w '%{http_code}\n' http://web01/health
    ```

3. Kirjuta README-sse: mis oli `fail` sõnumis, mis koodi andis `/health` enne taastamist ja kus peaks "viimane töötav versioon" elama, et see üle elaks hosti uuesti loomise.

Sõnum ütles, et töötab "mitte midagi", ja `/health` ei andnud 200: rollback ei olnud võimalik ja kasutaja nägi viga kuni taastamiseni. Tomcat ilma töötava rakenduseta annab 404, taaskäivituse ajal annab Nginx 502. `deploy.fact`-is oli tühi versioon, sest `always` kirjutas ausalt, mis töötab. Taastamine töötas, sest Gitis olev versioon on alati teada ja selle WAR oli serveris alles.

✅ **Edasi saad minna, kui** ilma fact'ita ebaõnnestub deploy sõnumiga "eelmist versiooni pole", `/health` annab enne taastamist mitte-200 koodi, pärast taastamist `200` ja `deploy.fact` on jälle `v1.1.0`.

## Rolling deploy ja health check

Kirjutad `deploy.yml`-i ümber nii, et hostid vahetuvad ükshaaval ja iga hosti järel kontrollitakse, kas see töötab kasutaja poolt. Esimene ebaõnnestunud host peatab kõik ülejäänud. Laboris on üks app-host, aga sama kood töötab kahekümnega.

`serial: 1` piirab vale versiooni mõju ühe hostiga, aga maksab ajaga: kui Tomcati restart koos health check'iga võtab 60–90 sekundit, kestab deploy kahekümnel hostil 20–30 minutit ja kogu selle aja töötavad kaks versiooni kõrvuti. `serial: [1, "25%"]` hoiab canary eelise ja lühendab ülejäänud osa.

- play `hosts: app`, `serial: 1`, `max_fail_percentage: 0`, deploy tuleb `ansible.builtin.import_role`-iga (`name: tomcat`, `tasks_from: deploy`)
- iga hosti järel `ansible.builtin.wait_for` web01-st selle hosti porti 8080: `delegate_to: "{{ groups['web'][0] }}"`, aadress `hostvars[inventory_hostname]['ansible_host']`
- siis `ansible.builtin.uri` `http://localhost/health` samuti web01-st, `until` ja `retries`-iga
- mõlemal kontrollil (`wait_for` ja `uri`) `tags: [deploy]`

```bash
ansible-playbook deploy.yml --syntax-check && ansible-lint deploy.yml
ansible-playbook deploy.yml --list-hosts
ansible-playbook deploy.yml -e labseis_version=<uus tag tahvlilt> | grep -E 'PLAY|TASK|changed='
curl -s http://app01:8080/version; echo
ansible-playbook deploy.yml | tail -4
```

> Delegeeritud ülesandes on `ansible_host` ühenduse muutuja ja viitab web01-le. `{{ ansible_host }}`-iga kontrolliks health check web01 enda porti ja läbiks alati.

`app01 -> web01` väljundis tähendab, et ülesanne käivitus web01-s, aga app01 muutujatega. Just nii kontrollib health check app01-t sealt, kust Nginx seda kasutab. Viimane jooks pani `v1.1.0` tagasi, sest Gitis olev versioon on source of truth: `-e` kehtis ainult ühe jooksu. GitHub Actionsi pipeline annab `-e labseis_version`-i iga kord ise ja muudab Gitis olevat versiooni alles siis, kui see on läbi läinud.

✅ **Edasi saad minna, kui** uus versioon jõuab app01-le ja `/version` näitab seda, health check'id käivituvad `app01 -> web01` kujul ja viimane jooks (Gitis olev versioon) paneb `v1.1.0` tagasi.

## Rolling kahel hostil: web.yml

`webhosts` grupis on kaks hosti ja siin näed rolling'u mõju: esimese hosti ebaõnnestumine jätab teise vanale seisule. Pärast rollback'i `enne-stack`-ile pole veebimalli seal enam, esimene jooks paneb selle uuesti.

Rolling ilma health check'ita vahetab kõik hostid ja teatab edust ka siis, kui ükski neist väljast ei vasta. Health check control node'ist leiab ka selle, mida host ise ei näe: tulemüüri, kuulamisaadressi ja marsruudi.

1. Lisa `web.yml`-i play'le `serial: 1` ja `max_fail_percentage: 0`, firewalld päringule `check_mode: false` ja `post_tasks` lõppu health check control node'ist: `uri` `http://{{ hostvars[inventory_hostname]['ansible_host'] }}/`, `delegate_to: localhost`, `become: false`, `until`/`retries`.

    ```bash
    ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL"
    ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL" | tail -4
    ```

2. Lõhu rmq01 väljastpoolt: port 80 on kinni kõigile peale loopback'i. rmq01 sees vastab leht edasi.

    ```bash
    ssh rmq01 'sudo iptables -I INPUT ! -i lo -p tcp --dport 80 -j REJECT'
    ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL_2" | grep -E 'PLAY|fatal|ok=|NO MORE'
    for h in rmq01 mc01; do curl -s -m 3 "http://$h/" | grep -m1 -i '<title>'; done
    ```

3. Ava port ja käivita uuesti: nüüd saavad mõlemad uue malli.

    ```bash
    ssh rmq01 'sudo iptables -D INPUT ! -i lo -p tcp --dport 80 -j REJECT'
    ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL_2" | tail -4
    ```

4. Kirjuta README-sse: miks rmq01 `localhost` kontroll läbis ja health check control node'ist mitte, mis seisus oli mc01 rikke ajal ja mida teeks `any_errors_fatal: true` teisiti.

rmq01 sai uue malli, aga kasutaja ei näinud seda, ja health check märkas seda. mc01 jäi vana malli peale ja teenindas edasi: see on rolling'u kasu. Ilma `serial`-ita oleks mõlemad hostid saanud uue malli korraga ja play oleks ebaõnnestunud alles siis, kui muudatus oli juba kõikjal tehtud. Pärast pordi avamist jõudis sama jooks lõpuni, sest kood oli kogu aeg õige: viga oli võrgus.

✅ **Edasi saad minna, kui** rikke ajal ebaõnnestub rmq01 health check'is, mc01-ni ei jõuta ja see näitab endiselt vana malli pealkirja, ning pärast pordi avamist on mõlemal uus mall.

## verify.yml teab versiooni

Lisad `verify.yml`-i kontrolli, mis võrdleb hostis töötavat versiooni Gitis olevaga. Nii märkab verify ka seda, kui keegi on käsitsi teise versiooni peale pannud või deploy jäi pooleli.

Kahe eri versiooniga hostid on kõige raskemini leitav viga: mõni kasutaja näeb uut käitumist, mõni vana, ja ükski monitooringu kontroll ei ole punane.

Lisa `verify.yml` rakenduse play `assert`-i tingimus: `ansible_facts['ansible_local']['deploy']['version']` võrdub `labseis_version`-iga.

```bash
ansible-playbook verify.yml | tail -6
ansible-playbook deploy.yml -e labseis_version=<uus tag tahvlilt> > /dev/null
ansible-playbook verify.yml | grep -E 'failed:|msg'
ansible-playbook deploy.yml > /dev/null && ansible-playbook verify.yml | tail -6
```

Verify ebaõnnestus, kuigi kõik teenused töötasid ja `/health` oli `UP`. See on õige: töötav süsteem, mis ei vasta Gitile, on drift ja järgmine `site.yml` muudaks seda vaikselt.

✅ **Edasi saad minna, kui** verify ebaõnnestub, kui töötab teine versioon kui Gitis, ja on roheline, kui versioonid klapivad.

## Paigad ja reboot lainetena

Turvauuendus tuleb kõigile viiele hostile ja osa neist vajab pärast kerneli, glibc või systemd uuendust reboot'i. Sama `serial` ja health check, mis vahetasid rakenduse versiooni, vahetavad nüüd OS-i pakette. Kirjutad `patch.yml`-i, mis uuendab hostid ükshaaval, teeb reboot'i ainult seal, kus OS seda nõuab, ja peatub, kui stack pärast hosti tagasitulekut kasutaja poolt ei vasta.

Kui reboot'id käivad korraga või ilma kontrollita, on andmebaas ja rakendus samal ajal maas ja järgmise hosti reboot algab enne, kui eelmise teenus on tagasi. Kui reboot käib igal jooksul, on iga kuu patch'imine tarbetu katkestus.

> ⚠️ Paketiuuendust ei saa Ansible'iga tagasi võtta. Tee enne Proxmoxis kõigil viiel snapshot `k02-enne-paigad` (**Include RAM** maha). Tootmises on selle koht hosti varukoopia või snapshot change'i plaanis.

Nõuded `k02-ansible/patch.yml`-ile:

- esimene play kontrollib enne ühtki muudatust, et `/health` control node'ist on `UP` (`delegate_to: localhost`, `become: false`, `run_once: true`); kui ei ole, ei alga ükski laine
- teine play `hosts: db:cache:queue:app:web`, `serial: 1`, `max_fail_percentage: 0`: taustateenused enne, web01 viimasena
- MariaDB ja RabbitMQ versioon ei muutu patch'imise lainega: Rockyl `dnf` `exclude: ["mariadb*"]`, Ubuntul `ansible.builtin.dpkg_selections` `rabbitmq-server` olekus `hold`
- uuendus: Rockyl `dnf` `name: "*"`, `state: latest`, Ubuntul `apt` `upgrade: dist` koos `update_cache`-iga; mõlemal `lock_timeout`
- reboot'i vajadus: Rockyl `dnf needs-restarting -r` (pakett `dnf-utils`; kood 1 tähendab "vaja", 0 "pole vaja", muu kood on viga), Ubuntul faili `/var/run/reboot-required` olemasolu; lugevatel ülesannetel `changed_when: false` ja `check_mode: false`
- `ansible.builtin.reboot` ainult vajadusel; iga hosti järel `/health` control node'ist `until`-iga, kuni JSON-is on `"status": "UP"`

Lint annab `dnf` ülesandele leiu `package-latest`. Siin on uusim versioon ülesande eesmärk: lisa üks `# noqa: package-latest` koos põhjendusega (automaatne hindaja lubab kokku kuni kolm).

1. Vaata plaani ilma muudatuseta.

    ```bash
    ansible-playbook patch.yml --syntax-check && ansible-lint patch.yml
    ansible-playbook patch.yml --list-hosts
    ssh db01 rpm -q mariadb-server
    ansible-playbook patch.yml --check | grep -E 'changed:|Reboot|changed='
    ```

2. Teises terminalis loe `/health`-i nagu katkise versiooni katses (`scratch/katkestus.txt`), siis käivita kaks korda.

    ```bash
    ansible-playbook patch.yml | tee scratch/patch-1.txt | grep -E 'PLAY \[|Reboot|changed='
    ansible-playbook patch.yml | tail -7
    ssh rmq01 apt-mark showhold; ssh db01 rpm -q mariadb-server
    ansible-playbook verify.yml | tail -6
    ```

3. Kirjuta README-sse tabel: host, kas pakette uuendati, kas oli reboot ja miks, mitu sekundit oli `/health` mitte-200 selle hosti laine ajal.

> Kui `apt` ootab minuteid lukku, töötab hostis `unattended-upgrades`. `lock_timeout` ootab, aga lõplik lahendus on otsus, kumb paikab: Ansible või hosti enda timer.

`--list-hosts` näitab lainete järjekorda: Ansible võtab mustri grupid järjekorras ja `serial: 1` teeb igast hostist oma laine. Reboot käivitus ainult seal, kus uuenes midagi, mis seda nõuab, ja teine jooks ei uuendanud ega taaskäivitanud midagi: `changed=0` ja reboot on `skipping`. db01 laine ajal näitas `/health` hetkeks `DOWN`, aga järgmine host ootas, kuni rakendus andmebaasi uuesti leidis. web01 on stacki ainus sisenemispunkt: selle reboot on planeeritud katkestus, mida `serial` ei väldi, ja selle hind on `katkestus.txt`-is.

✅ **Edasi saad minna, kui** `--list-hosts` näitab järjekorda db01, mc01, rmq01, app01, web01, esimene jooks lõpeb viiel hostil `failed=0` ja reboot käivitus ainult seal, kus vaja, teine jooks annab `changed=0`, `apt-mark showhold` näitab `rabbitmq-server`, MariaDB versioon on sama mis enne, `verify.yml` on roheline ja README-s on tabel.

## Commit

Commit'id deploy, rolling'u, verify ja patch'imise laine muudatused. Viimane kontroll käivitab automaatse hindaja syntax-check'i, mis kontrollib ka `deploy.yml`-i, sest pipeline käivitab seda faili otse.

```bash
cd ~/labori-seis
git add -A k02-ansible
git commit -m "K2.6 deploy rollback'iga, rolling deploy.yml, web.yml ja patch.yml (closes #N)" && git push
```

`OK` syntax-check'is tähendab, et `import_role` tee ja `tasks_from` nimi on õiged. Need on ainsad vead, mida `site.yml`-i jooks ei leia, sest `site.yml` ei kasuta `deploy.yml`-i.

✅ **Edasi saad minna, kui** `bash autograde/check.sh k02 syntax` repo juurest annab `OK` (see kontrollib ka `deploy.yml`-i).

📎 **Selle mooduli tõend:** commit `K2.6`; README-s kahe rikke tabel katkestuse sekunditega, fact'ita deploy kolm vastust, rolling'u kolm vastust, patch'imise laine tabel (uuendus, reboot, katkestus hosti kaupa); `deploy.fact` app01-s; `patch.yml` teine jooks `changed=0`.

## Miks see nii töötab

**`rescue` ja handlerid.** Ploki `rescue` osas on kättesaadavad muutujad `ansible_failed_task` ja `ansible_failed_result`. Ploki sees teavitatud handlerid käivituvad `flush_handlers`-i kohas. Kui kontroll ebaõnnestub pärast seda, on taaskäivitus juba tehtud ja `rescue` teavitab handlerit uuesti.

**Rolling ühe ja kahe hostiga.** Ühe rakendushostiga ei ole deploy katkestuseta: kasutaja näeb taaskäivituse ajal viga `502`. Kahe rakendushostiga eemaldaks rolling deploy iga hosti enne vahetust Nginxi upstream'ist (`down` mallis, `pre_tasks` `delegate_to` web-hostile) ja lisaks selle tagasi alles pärast health check'i. Ilma selleta saadab Nginx päringuid ka taaskäivituvale hostile ja märgib selle maha alles passiivse kontrolliga (`max_fails=1`, `fail_timeout=10s` vaikimisi), nii et osa kasutajaid saab vea.

**Versioon väljaspool hosti.** Hosti custom fact kaob koos hostiga, seepärast hoitakse tootmises viimast töötavat versiooni väljaspool hosti: pipeline'i viimases õnnestunud käivituses, Gitis või artefaktihoidlas. Hosti fact jääb siis ainult kohalikuks kontrolliks, mida `verify.yml` võrdleb oodatud versiooniga.

**`serial` listina.** `serial` võib olla ka list, näiteks `[1, 5, "50%"]`: esimene batch on üks canary host, siis viis, siis 50% play hostidest batch'i kohta ja listi viimane väärtus kordub, kuni hostid saavad otsa. Protsent arvutatakse play hostide koguarvust ja ümardatakse alla, kuid vähemalt üheks hostiks.

**Vigade piir.** `any_errors_fatal` peatab kõik hostid kohe pärast ülesannet, kus mõni ebaõnnestus. `max_fail_percentage` hinnatakse iga batch'i lõpus ja piir peab olema ületatud, mitte saavutatud: `serial: 4` korral peatab kahe hosti ebaõnnestumine play alles siis, kui väärtus on 49, mitte 50.

Kui jõudsid kiiremini: [Lisaülesanded → Lisaprojekt: andmebaasi varukoopia ja taastamine](lisa.md#lisaprojekt-andmebaasi-varukoopia-ja-taastamine), teed enne deploy'd db01-st varukoopia ja tõestad taastamisega, et see töötab.
