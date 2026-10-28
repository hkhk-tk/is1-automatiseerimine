---
tags:
  - Ansible
  - Bash
---

# 6. Sama töö Ansible'iga

Iga uus host ja iga uus skript tähendab, et hostide nimekiri, paralleelsus, dry-run, kokkuvõte ja vigade käsitlus tuleb Bashis uuesti kirjutada, ja seda koodi hooldad ainult sina. Nüüd paned sama veebimalli rmq01-le ja mc01-le Ansible'iga ning vaatad, mida tööriist sinu eest teeb ja mida mitte.

Lõpuks on kaustas `k02-ansible/` konfifail, inventory ja playbook `web.yml`. Teine käivitus annab `changed=0`. web01 jääb välja, sest seal hoiab porti 80 stacki Nginx.

**Kui teed seda tööl iga päev:** `k02-ansible/`-s on `ansible.cfg`, inventory ja `web.yml` selle lehe nõuete järgi, `ansible-lint web.yml` vaikib ja teine jooks annab rmq01-l ja mc01-l `changed=0`. Kui see on sul juba korras, mine otse etappi [„Lõhu ja vaata, mida Ansible märkab“](#lohu-ja-vaata-mida-ansible-markab).

## Pane Ansible control node'ile

Automaatne hindaja kasutab lukustatud versiooni. Sama versioon läheb ka sinule, omaette venv'i, nii et süsteemi Python jääb puutumata.

Versioonide erinevus muudab tulemust: uuem ansible-lint lisab reegleid ja vanem ansible-core ei tunne mõnd mooduli parameetrit. Kui sinu masinas on teine versioon kui CI-s, saad roheliseks lokaalselt ja punaseks automaatses hindajas, ilma et koodis midagi muutuks.

1. Paigalda pipx, Ansible ja ansible-lint.

    ```bash
    sudo apt-get install -y -o DPkg::Lock::Timeout=120 pipx python3-venv
    pipx install 'ansible-core==2.21.*'
    pipx inject --include-apps ansible-core 'ansible-lint==26.9.*'
    pipx ensurepath && exec bash
    ```

2. Vaata versiooni ja seda, milline `ansible` käivitub.

    ```bash
    ansible --version | head -3
    command -v ansible ansible-lint
    ```

Kui `command -v` näitab `/usr/bin/ansible`, on masinas ka apt-i versioon ja PATH-i järjekord otsustab, kumb töötab.

✅ **Edasi saad minna, kui** `ansible --version` näitab `core 2.21` ja mõlemad tööriistad on `~/.local/bin/` all.

## Konfifail ja inventory

Ansible võtab esimese leitud konfifaili järjekorras `ANSIBLE_CONFIG`, `./ansible.cfg`, `~/.ansible.cfg`, `/etc/ansible/ansible.cfg` ega liida neid kokku. Projekti kaustas olev fail on seega repos ja kehtib igaühele, kes käivitab sealt. Loo `~/labori-seis/k02-ansible/ansible.cfg`:

- `[defaults]`: `inventory = inventory.ini`, `remote_user = kasutaja`, `interpreter_python = auto_silent`, `log_path = ansible.log`
- `[ssh_connection]`: `pipelining = True`
- `become` jäta täna konfifailist välja: annad selle käsureal `-b`-ga või play'is
- repo juure `.gitignore`-i rida `k02-ansible/ansible.log`

Inventory on rohkem kui hostide nimekiri. Grupid lubavad sama hosti kirjeldada mitmest vaatest: mis teenust see pakub ja mis OS-il see töötab. Kirjuta samasse kausta `inventory.ini` oma `k01-bash/hosts` failist:

- funktsionaalsed grupid `[db]`, `[cache]`, `[queue]`, `[app]`, `[web]`, igas üks host kujul `db01 ansible_host=<IP>`
- OS-grupid `[ubuntu:children]` (queue, app, web) ja `[rocky:children]` (db, cache): nende all on grupid, mitte hostid
- grupp `[webhosts]` hostidega rmq01 ja mc01, ilma IP-ta: host on juba olemas, grupp lisab talle ainult uue nime

```bash
cd ~/labori-seis/k02-ansible
ansible --version | grep 'config file'
ansible-inventory --graph
ansible-inventory --host mc01
```

> `config file = None` tähendab, et oled vales kaustas või on kaust kõigile kirjutatav (`ls -ld .`). Siis ignoreerib Ansible faili turvalisuse pärast.

`--graph` näitab puud, mille Ansible su failist ehitas. mc01 kahe grupi all tähendab, et grupid ei välista üksteist: playbook, mis sihib `cache`, ja playbook, mis sihib `webhosts`, jõuavad mõlemad samasse hosti. `--host mc01` näitab muutujaid, mis sellel hostil lõpuks on. Seda käsku vajad igas veaotsingus, kus "vale väärtus jõudis hostini".

✅ **Edasi saad minna, kui** `config file` näitab sinu `k02-ansible/ansible.cfg`-i, puus on `@ubuntu`, `@rocky` ja `@webhosts` ning mc01 on nii `@cache` kui `@webhosts` all.

## Ad-hoc: vaata, enne kui muudad

Ad-hoc käsk käivitab ühe mooduli kõigis valitud hostides. See on `for h in …; do ssh` ja `sysinfo.sh` ühe reana, sama inventory, `forks`-i ja väljundiga nagu playbook.

1. Proovi ühendust ja mustreid.

    ```bash
    ansible all -m ansible.builtin.ping -o
    ansible 'all:!rocky' --list-hosts
    ansible webhosts --list-hosts
    ```

2. Vaata fakte: Ansible kogub need igast hostist ise, `os-release`-i ei pea lugema.

    ```bash
    ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*'
    ansible all -m ansible.builtin.setup -a 'filter=ansible_os_family' -o
    ansible all -m ansible.builtin.setup -a 'filter=ansible_memfree_mb' -o
    ```

3. Käivita sama käsk kaks korda ja võrdle paralleelsust `webdeploy.sh -j`-ga.

    ```bash
    ansible web -m ansible.builtin.command -a 'uptime'
    ansible web -m ansible.builtin.command -a 'uptime'
    time ansible all -m ansible.builtin.command -a 'sleep 3' -f 1
    time ansible all -m ansible.builtin.command -a 'sleep 3' -f 5
    ```

4. Kirjuta `k01-bash/NOTES.md`-sse pealkirja "Ansible" alla: db01 `ansible_distribution` ja `ansible_os_family`, miks `command` on mõlemal korral `CHANGED` ja kumb `-f` väärtus vastab `-j 5`-le.

`pong` tõestab rohkem kui ICMP ping: SSH-ühendus, võti ja kasutaja töötavad ning sihtmasinas leidus Python, millega moodul käivitus. Kas iga moodul töötab sama Pythoniga, see ei ütle: interpreter'i valib Ansible seade `interpreter_python` järgi (sinu `auto_silent` otsib selle ise). `os_family` on see fakt, mille järgi playbook distro valib, sama mis sinu `detect_distro`. `command` on alati `CHANGED`, sest Ansible ei tea, mida suvaline käsk muudab, ja eeldab halvimat; see on põhjus, miks playbook'is eelistad moodulit, mis teab.

✅ **Edasi saad minna, kui** saad viis `pong`-i, Ubuntu hostide `os_family` on `Debian` ja Rocky omade `RedHat` ning `-f 5` lõpetab selgelt kiiremini kui `-f 1`.

## Ad-hoc muudatused: soovitud seis

Ansible'i paketi moodulile kirjeldatakse soovitud olekut "peab olema paigaldatud". Moodul võrdleb seda tegelikuga ja muudab ainult erinevuse.

See on sama mõte, mille sa `websetup.sh`-is käsitsi kirjutasid: kontroll enne muutust. Vahe on selles, et moodulis on kontroll juba olemas ja testitud, nii et sa ei pea iga paketi ja teenuse jaoks uuesti `dpkg-query` ja `is-active` loogikat kirjutama.

1. Paigalda pakett ilma `-b`-ta, siis kaks korda `-b`-ga, siis eemalda.

    ```bash
    ansible webhosts -m ansible.builtin.package -a 'name=tree state=present'
    ansible webhosts -b -m ansible.builtin.package -a 'name=tree state=present'
    ansible webhosts -b -m ansible.builtin.package -a 'name=tree state=present'
    ansible webhosts -b -m ansible.builtin.package -a 'name=tree state=absent'
    ```

2. Juhi teenust soovitud seisuga ja vaata, mida `check.sh` märkab.

    ```bash
    ansible cache -b -m ansible.builtin.service -a 'name=memcached state=started'
    ansible cache -b -m ansible.builtin.service -a 'name=memcached state=stopped'
    (cd ../k01-bash && ./check.sh); echo "kood $?"
    ansible cache -b -m ansible.builtin.service -a 'name=memcached state=started'
    ```

3. Vaata muudatust enne, kui see tehakse.

    > Check-režiim ennustab, ta ei tee midagi. Kui ülesanne sõltub eelmise ülesande tulemusest (fail, mille eelmine alles looks või lahti pakiks), ebaõnnestub see check-režiimis või näitab vale plaani. Tühjas hostis on `--check` seega ebatäpne, ja `command`-i ning `shell`-i jätab check-režiim üldse vahele.

    ```bash
    ansible all -b -m ansible.builtin.copy -a 'content="Labori seis: hallatud Ansible" dest=/etc/motd mode=0644' --check --diff
    ssh db01 cat /etc/motd
    ```

4. Kirjuta `NOTES.md`-sse, miks esimene `package` ebaõnnestus, mille poolest erineb `state=absent` käsust `apt remove` ja miks ad-hoc muudatus Gitti ei jõua.

Teine `present` on roheline, sest midagi polnud vaja teha. See on idempotentsus, mille eest sa `websetup.sh`-is vaeva nägid. `--check --diff` näitab sama, mida sinu `-n`: plaani ilma muudatuseta. Ad-hoc muudatus on aga sama habras kui käsitsi parandus: järgmine inimene ei tea, et see tehti, ja järgmine uus VM seda ei saa.

✅ **Edasi saad minna, kui** teine `present` on roheline `SUCCESS`, peatatud memcached annab `check.sh` koodi 1, `started` taastab selle ja `--check --diff` näitab viie hosti `/etc/motd` erinevust, kuid db01 fail on muutmata.

## Maas host ja väljumiskood

`webdeploy.sh`-iga tegid kindlaks, et üks maas host ei peata teisi ja kood ütleb kutsujale, et kõik ei õnnestunud. Kontrolli, kuidas Ansible sama olukorda käsitleb, ilma ühtki VM-i peatamata.

1. Tee ajutine inventory, mis annab db01-le olematu aadressi. Teine `-i` kirjutab esimese väärtuse üle.

    ```bash
    printf 'db01 ansible_host=10.255.255.1\n' > /tmp/maas.ini
    ansible all -i inventory.ini -i /tmp/maas.ini -m ansible.builtin.ping -o; echo "kood $?"
    ```

2. Võrdle koodi sellega, mida annab ebaõnnestunud ülesanne töötavas hostis.

    ```bash
    ansible db01 -m ansible.builtin.command -a 'false'; echo "kood $?"
    rm /tmp/maas.ini
    ```

Neli hosti vastasid `pong`, db01 oli `UNREACHABLE` ja kood oli 4. Ebaõnnestunud käsk töötavas hostis andis `FAILED` ja koodi 2. Ansible eristab koodiga, kas hostini ei jõutud või jõuti, aga töö ebaõnnestus. Sinu `webdeploy.sh` andis mõlemal juhul 1; kui käivitaja (timer, pipeline) peab otsustama, kas proovida uuesti, on see vahe kasulik.

✅ **Edasi saad minna, kui** esimene käsk annab neli `SUCCESS`-i, ühe `UNREACHABLE`-i ja koodi 4, teine käsk koodi 2 ning mõlemad koodid on `NOTES.md`-s.

## Esimene playbook: web.yml

Playbook on soovitud seis failis. Kirjuta `k02-ansible/web.yml`, mis teeb webhosts grupis sama, mida `websetup.sh`. Erinevalt ad-hoc käsust on see repos, läbib lint'i ja annab teisel käivitusel `changed=0`, nii et saad seda käivitada nii palju kui vaja. Alusta nii:

```yaml
---
- name: Veebileht webhosts grupile
  hosts: webhosts
  become: true
  vars:
    web_template_url: https://www.tooplate.com/zip-templates/2135_mini_finance.zip
```

Nõuded:

- muutuja `web_service`: `apache2`, kui `ansible_facts['os_family'] == 'Debian'`, muidu `httpd`; paketid (veebiserver, `unzip`) kahe ülesandega, `ansible.builtin.apt` (`update_cache`, `cache_valid_time`) ja `ansible.builtin.dnf`, kumbki oma `when`-iga
- teenus `ansible.builtin.service`-ga: `started` ja `enabled`
- mall: `ansible.builtin.unarchive` (`remote_src: true`, `creates:`) kausta `/opt/labseis-mall`, siis `ansible.builtin.copy` (`remote_src: true`) malli kausta **sisu** `/var/www/html/` alla; failidel on `owner` ja `mode`
- Rocky tulemüür: `ansible.builtin.service_facts` ütleb, kas firewalld töötab; päring `firewall-cmd --permanent --query-service=http` (`changed_when: false`, kood 0 või 1 pole viga), lisamine ainult koodi 1 korral ja `firewall-cmd --reload` handleris
- lõpus `ansible.builtin.uri` kontrollib, et `http://localhost/` annab 200; igal ülesandel on suure tähega nimi ja täisnimega moodul (`ansible.builtin.…`)

```yaml
    - name: Veebiserver ja unzip (Rocky)
      ansible.builtin.dnf:
        name: [httpd, unzip]
        lock_timeout: 120
      when: ansible_facts['os_family'] == 'RedHat'
```

Vaata fail üle enne, kui see hostidesse jõuab, siis käivita kaks korda. Järjekord on sama mis koodi ülevaatusel: süntaks, stiil, plaan ja alles siis tegelik käivitus.

```bash
ansible-playbook web.yml --syntax-check && ansible-lint web.yml
ansible-playbook web.yml --list-tasks
ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL"
ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL" | tee ../k01-bash/logs/web-run2.txt
for h in rmq01 mc01; do curl -sI "http://$h" | head -1; done
```

<!-- EKRAANIPILT: terminal control node'il kaustas k02-ansible, ansible-playbook web.yml teise käivituse lõpp: PLAY RECAP, read rmq01 ja mc01 kujul ok=N changed=0 unreachable=0 failed=0. Tee pärast teist käivitust.
<figure markdown="span">
  ![Teise käivituse PLAY RECAP, mõlemal hostil changed=0](assets/k01_web_yml_recap.png)
  <figcaption>Joonis L1.7. <code>web.yml</code> teine käivitus: midagi pole vaja muuta.</figcaption>
</figure>
-->

> Esimesel käivitusel kestab `apt` ja malli allalaadimine mõne minuti. `-v` näitab iga ülesande tulemust, `--start-at-task` jätkab ebaõnnestunud ülesandest.

PLAY RECAP on Ansible'i kokkuvõte, sama mis sinu `webdeploy.sh` tabel. `changed=0` teisel jooksul on idempotentsuse tõend. Kui mõni ülesanne on igal jooksul `changed`, on selles tingimuseta muudatus: tavaliselt `command` ilma `changed_when`-ita või `apt` ilma `cache_valid_time`-ita. Kaks `200 OK`-d tõestavad, et Rocky tulemüür avati, sest muidu vastaks mc01 ainult `localhost`-ile.

✅ **Edasi saad minna, kui** syntax-check ja ansible-lint vaikivad, teise käivituse PLAY RECAP on mõlemal hostil `changed=0` ning mõlemad `curl`-id annavad `200 OK`.

## Lõhu ja vaata, mida Ansible märkab

`websetup.sh`-i testis muutsid malli faili käsitsi ja skript võttis muudatuse tagasi. Sama test playbook'iga, lisaks peatatud teenus.

See on drift'i test. Tootmisserverites muudab keegi midagi käsitsi "ainult korraks", ja küsimus on, kas järgmine automaatne jooks seda märkab ja parandab ainult selle, mitte kogu hosti.

1. Muuda rmq01-s malli faili ja peata mc01-s veebiserver.

    ```bash
    ssh rmq01 "echo '<!-- käsitsi -->' | sudo tee -a /var/www/html/index.html"
    ssh mc01 sudo systemctl stop httpd
    ```

2. Vaata check-režiimis, mida playbook teeks, ja kontrolli, et midagi ei muutunud.

    ```bash
    ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL" --check --diff
    curl -sI http://mc01 | head -1
    ```

3. Paranda ainult üks host, siis teine, ja käivita lõpuks kogu grupp.

    ```bash
    ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL" --limit mc01
    ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL" --limit rmq01
    ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL"
    ```

4. Kirjuta `NOTES.md`-sse, milline ülesanne kummaski hostis `changed` oli ja mida check-režiim teha ei saa: milline ülesanne ebaõnnestuks `--check`-iga esimesena täiesti tühjas hostis, kus malli pole veel alla laaditud?

Check-jooks leidis mõlemad muudatused, aga ei teinud midagi: mc01 ei vastanud ka pärast seda. `--limit` näitab, kuidas parandada ühte hosti, kui teised on töös ja sa ei taha neid puudutada. Viimane `changed=0` tõestab, et pärast parandust on grupp jälle soovitud seisus ja järgmine jooks ei tee midagi.

✅ **Edasi saad minna, kui** check-jooks näitab rmq01-l muutust malli kopeerimises ja mc01-l teenuse käivitamises, mc01 ei vasta pärast seda endiselt, `--limit` jooksud parandavad kumbagi ja viimane jooks annab `changed=0`.

## websetup.sh ja web.yml kõrvuti

Nüüd on sama töö kahel kujul. Kirjuta üles, mida sa Ansible'iga enam ise ei kirjuta ja mida Ansible sinu eest ei tee.

See tabel on sinu argument järgmiseks korraks, kui keegi küsib, kas Ansible on väikese töö jaoks liiga suur. Vastus sõltub sellest, mitu rida sinu enda kontrolli- ja veakoodist moodul asendab.

- `NOTES.md`-sse tabel "Bash → Ansible" vähemalt kuue reaga: näiteks `webhosts`, `detect_distro`, `pkg_installed`, `change` + `CHANGED`, `-n`, `logger`, `webdeploy.sh -j`, `on_err`, `flock`; teises veerus see, mis selle asendab (või "puudub")
- kaks asja, mida `websetup.sh` tegi ja `web.yml` ei tee või teeb teisiti
- ridade arv ilma kommentaaride ja tühjade ridadeta kolmes failis

```bash
grep -cvE '^\s*(#|$)' ../k01-bash/websetup.sh ../k01-bash/webdeploy.sh web.yml
grep -E 'changed=' ../k01-bash/logs/web-run2.txt
grep -c 'PLAY RECAP' ansible.log
```

Ridade arv näitab, kui suur osa sinu Bashist oli töökindlus, mitte töö ise. `ansible.log` on sinu `logger`-i vaste: iga jooks on seal, ka need, mille väljundit sa ei salvestanud. Tabelis olev "puudub" on sama tähtis kui asendused, sest just need kohad pead Ansible'is ise lahendama.

✅ **Edasi saad minna, kui** tabelis on vähemalt kuus rida ja kaks erinevust ning `ansible.log`-is on kõigi selle mooduli jooksude PLAY RECAP.

## Commit

Kolm faili lähevad Giti, logi mitte. Järgmisel korral jätkad samas kaustas uuel harul.

`ansible.log` sisaldab hostinimesid, IP-sid ja `--diff` korral ka failide sisu. Seepärast on see `.gitignore`-s, mitte ainult müra pärast: `--diff` võib näidata ka faili, milles on saladus.

```bash
cd ~/labori-seis
git check-ignore -v k02-ansible/ansible.log
git add .gitignore k02-ansible/ansible.cfg k02-ansible/inventory.ini k02-ansible/web.yml k01-bash/NOTES.md
git commit -m "ansible: inventory, ad-hoc, web.yml" && git push
git ls-files k02-ansible
```

`git ls-files` on sama nimekiri, mida näevad automaatne hindaja ja järgmise kohtumise algus.

✅ **Edasi saad minna, kui** `git ls-files k02-ansible` näitab täpselt kolme faili ja `ansible.log` pole nende hulgas.

📎 **Selle mooduli tõend:** commit `ansible: inventory, ad-hoc, web.yml`; `NOTES.md`-s faktid db01 kohta, `-f 1` ja `-f 5` ajad, `state=absent` lause, maas hosti ja ebaõnnestunud käsu koodid, rikketesti `changed` read, tabel "Bash → Ansible" ja ridade arv.

## Miks see nii töötab

**pipx.** pipx paigaldab Ansible'i eraldi venv'i, sest Ubuntu 24.04 süsteemne Python on märgitud "externally managed" (PEP 668) ja `pip install` keeldub sinna paigaldamast. Lisaks on Ubuntu 24.04 apt-i ansible-core (2.16) vanem kui automaatse hindaja kasutatav versioon.

**`become` ja grupp `[webhosts]`.** `become` tõstab õigused `become_method`-iga (vaikimisi `sudo`, kasutaja `root`); pipelining'u korral saadetakse moodul sudo all töötava Pythoni stdin'i. `become` on konfifailist välja jäetud, et näeksid, mida võti `-b` muudab. Järgmisel kohtumisel lisatakse see faili `ansible.cfg`. Grupis `[webhosts]` on rmq01 ja mc01, sest web01-s kasutab porti 80 juba rakenduse Nginx.

**`ansible_host` ja SSH võti.** `ansible_host` on IP-aadress, seega `~/.ssh/config` plokk `Host web01 …` ei rakendu. Kui võtit pole `private_key_file`-iga määratud, kasutab ssh vaikevõtmeid (näiteks `id_ed25519`), mitte automatiseerimise võtit.

**`unarchive` ja `copy`.** `unarchive` koos `creates:`-iga laadib malli alla ja pakib lahti ainult siis, kui `creates`-is nimetatud fail puudub. `copy` koos `remote_src`-iga võrdleb iga faili ja kopeerib ainult erinevad, nii et käsitsi muudetud fail kirjutatakse üle algse failiga.

**Tulemüür ilma moodulita.** Tulemüüri moodul (`ansible.posix.firewalld`) ei kuulu ansible-core'i, vaid kollektsiooni `ansible.posix`. Seepärast kirjutad kontrolli ise samamoodi nagu Bashis: päring, otsus, muudatus.

**Mida Ansible sinu eest ei tee.** Ansible ei pane lukku kahe samaaegse jooksu vastu nagu sinu `flock`. Teenuse vastamist ei kontrolli ta enne, kui kirjutad selle ise (`wait_for`, `uri`). Cloud-init'i lõppu ta samuti ei oota: värske VM-i puhul peab `cloud-init status --wait` olema playbook'i esimene samm või tehtud enne playbook'i.

Kui jõudsid kiiremini: [Lisaülesanded → 13. Teine mall ja vanad failid](lisa.md#13-teine-mall-ja-vanad-failid), muudad `web.yml`-i nii, et malli vahetus ei jäta veebijuurde vanu faile.
