---
tags:
  - Bash
  - Ansible
  - Loeng
---

# 1. kohtumine · Linuxi haldusest automatiseerimiseni

??? abstract "Õpiväljundid"

    Pärast kohtumist oskad:

    - selgitada, millal on korduva töö automatiseerimine mõistlik;
    - selgitada Bashi skripti ja Ansible'i playbook'i erinevat tööpõhimõtet;
    - kasutada mõisteid *control node*, *hallatav masin*, *inventory*, *moodul*, *ülesanne* ja *playbook*;
    - käivitada playbook'i ning tõlgendada tulemusi `ok`, `changed` ja `failed`.

!!! info "Päeva ülesanne"

    Masinas **web01** peab kasutaja `kasutaja` kodukaustas olema kaust `automation-lab` õigustega `0750` ja selles fail `training.conf` õigustega `0640`. Failis on kaks rida:

    ```ini
    environment=training
    enabled=true
    ```

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 95" role="img" aria-label="Sama ülesanne kolmel viisil: käsitsi, Bashi skriptiga ja Ansible'iga, iga kord sama kontroll" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:15px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxt" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="20" width="160" height="60" rx="8"/><text class="b" x="90" y="47" text-anchor="middle">Käsitsi</text><text class="s" x="90" y="66" text-anchor="middle">mkdir, printf, chmod</text>
<line class="a" x1="170" y1="50" x2="198" y2="50" marker-end="url(#lxt)"/>
<rect class="box" x="200" y="20" width="160" height="60" rx="8"/><text class="b" x="280" y="47" text-anchor="middle">Bashi skript</text><text class="s" x="280" y="66" text-anchor="middle">sammud failis</text>
<line class="a" x1="360" y1="50" x2="388" y2="50" marker-end="url(#lxt)"/>
<rect class="box" x="390" y="20" width="160" height="60" rx="8"/><text class="b" x="470" y="47" text-anchor="middle">Ansible</text><text class="s" x="470" y="66" text-anchor="middle">soovitud olek</text>
<line class="a" x1="550" y1="50" x2="578" y2="50" marker-end="url(#lxt)"/>
<rect class="hi" x="580" y="20" width="130" height="60" rx="8"/><text class="b" x="645" y="47" text-anchor="middle">Kontroll</text><text class="s" x="645" y="66" text-anchor="middle">cat, stat</text>
</svg>
<figcaption>Joonis 1.1. Päeva ülesanne lahendatakse kolmel viisil ja tulemust kontrollitakse iga kord samamoodi.</figcaption>
</figure>

## 1. Miks automatiseerida?

Kui sama seadistust tehakse käsitsi mitmes serveris, jääb mõnes neist kergesti mõni samm tegemata. Viga ilmneb sageli alles hiljem ja selle põhjust on raske leida, sest serverite soovitud olek on kirjas ainult kellegi mälus. Automatiseerimise eesmärk on muuta korduv töö korratavaks, kontrollitavaks ja teistele arusaadavaks.

Kõike ei ole mõtet automatiseerida. Automaatika tuleb kirjutada, testida ja hooldada. Esimesena tasub automatiseerida tööd, mida tehakse sageli, mille viga on kallis või mis võtab palju aega.

| Küsimus | Näide |
|---|---|
| Kui sageli seda tehakse? | kuine turvauuendus 40 serveris |
| Kui palju maksab käsitsi tehtud viga? | sertifikaadi vahetus, mille sammud on aastaga ununenud |
| Kui kaua üks kord aega võtab? | uue töötaja kasutajakontod kuues süsteemis |

*Tabel 1. Kolm küsimust automatiseerimise kandidaadile.*

??? example "Knight Capital 2012"

    Uus kood tuli käsitsi paigaldada kaheksasse serverisse. Ühte serverisse jäi see paigaldamata ja seal käivitus vana funktsioon. Firma kaotas 45 minutiga üle 460 miljoni dollari ([USA väärtpaberikomisjoni otsus](https://www.sec.gov/litigation/admin/2013/34-70694.pdf)).

## 2. Skripti piirid

Kui paned käsitsi tehtud käsud faili, saad skripti:

```bash
#!/usr/bin/env bash
mkdir -p ~/automation-lab
chmod 0750 ~/automation-lab
printf '%s\n' 'environment=training' 'enabled=true' > ~/automation-lab/training.conf
chmod 0640 ~/automation-lab/training.conf
```

Skript teeb töö kiiresti ja alati samas järjekorras, kuid see ei kontrolli masina tegelikku olekut:

- teine käivitus kirjutab faili uuesti üle, kuigi sisu on juba õige;
- kui üks käsk ebaõnnestub, jätkab skript järgmisega;
- iga kontrolli (kas kaust on olemas, kas sisu on õige) tuleb ise kirjutada.

Omadust, et korduv käivitus ei muuda midagi, kui soovitud olek on juba saavutatud, nimetatakse **idempotentsuseks**. Skriptis tuleb see ise kirjutada, Ansible'i moodulites on see olemas.

## 3. Ansible

**Ansible** on avatud lähtekoodiga tööriist serverite seadistamiseks. Failis kirjeldad, milline peab masin olema, ja Ansible teeb masinas ainult need muudatused, mis on selleks vajalikud. Ansible ilmus 2012. aastal ja seda arendab Red Hat.

Bashi skriptist eristavad Ansible'it kolm asja:

- **Soovitud olek, mitte käsud.** Kirjutad „kaust on olemas õigustega 0750“, mitte „tee kaust, siis muuda õigusi“.
- **Mitu masinat korraga.** Sama playbook'i saab käivitada ühes või sajas masinas.
- **Agenti pole vaja.** Hallatavas masinas piisab SSH-st ja Pythonist.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 220" role="img" aria-label="Control node'il on inventory, playbook ja ansible-playbook; Ansible saadab mooduli SSH-ga web01-le, kus Python võrdleb soovitud ja tegelikku olekut ning tagastab ok või changed" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.12;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:13.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxw" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="hi" x="10" y="10" width="290" height="200" rx="10"/><text class="t" x="26" y="36">control node</text>
<rect class="box" x="26" y="50" width="258" height="38" rx="6"/><text class="c" x="40" y="74">inventory.ini</text><text class="s" x="272" y="74" text-anchor="end">kus</text>
<rect class="box" x="26" y="98" width="258" height="38" rx="6"/><text class="c" x="40" y="122">training.yml</text><text class="s" x="272" y="122" text-anchor="end">mis</text>
<rect class="box" x="26" y="146" width="258" height="46" rx="6"/><text class="c" x="40" y="174">ansible-playbook</text><text class="s" x="272" y="174" text-anchor="end">käivitab</text>
<line class="a" x1="300" y1="90" x2="418" y2="90" marker-end="url(#lxw)"/><text class="s" x="359" y="80" text-anchor="middle">SSH: moodul</text>
<line class="a" x1="420" y1="140" x2="302" y2="140" marker-end="url(#lxw)"/><text class="s" x="361" y="160" text-anchor="middle">ok / changed</text>
<rect class="box" x="420" y="10" width="290" height="200" rx="10"/><text class="t" x="436" y="36">web01</text>
<text class="b" x="436" y="76">1. Python käivitab mooduli</text>
<text class="b" x="436" y="116">2. võrdleb soovitud ja tegelikku</text>
<text class="b" x="436" y="156">3. muudab ainult erinevuse</text>
<text class="s" x="436" y="190">pärast tööd moodul kustutatakse</text>
</svg>
<figcaption>Joonis 5.1. Ansible töötab control node'is ja teeb töö hallatavas masinas SSH kaudu.</figcaption>
</figure>

Ansible on paigaldatud ainult **control node**'i. Masinat, mida Ansible seadistab, nimetatakse **hallatavaks masinaks**. Iga ülesande jaoks saadab Ansible SSH kaudu hallatavasse masinasse väikese Pythoni programmi, **mooduli**. Moodul kontrollib tegelikku olekut, teeb vajaduse korral muudatuse ja tagastab tulemuse.

## 4. Inventory ja `ansible.cfg`

**Inventory** on fail, kus on kirjas hallatavad masinad ja grupid:

```ini
[ubuntu]
web01
app01
rmq01

[alma]
mc01
db01

[all:vars]
ansible_user=kasutaja
```

| Osa | Tähendus |
|---|---|
| `[ubuntu]`, `[alma]` | grupid; nende abil käivitad ülesandeid korraga kõigis grupi masinates |
| `web01` | masina nimi; IP-aadress tuleb SSH konfiguratsioonifailist |
| `[all:vars]`, `ansible_user` | kõigile masinatele kehtiv muutuja: kasutaja, kellena Ansible sisse logib |

*Tabel 2. Inventory osad.*

Fail `ansible.cfg` projekti kaustas ütleb, millist inventory't kasutada, nii et seda ei pea iga käsu juurde kirjutama:

```ini
[defaults]
inventory = inventory.ini
```

Hoia `ansible.cfg`, inventory ja playbook'id koos samas kaustas ja Gitis.

## 5. Ad-hoc käsk ja playbook

| Käsk | Mida teeb | Näide |
|---|---|---|
| `ansible` | käivitab ühe mooduli kohe (ad-hoc) | `ansible all -m ansible.builtin.ping` |
| `ansible-playbook` | käivitab playbook'i: mitu ülesannet järjest | `ansible-playbook training.yml` |

*Tabel 3. Ansible'i kaks põhikäsku.*

Vastus `pong` tähendab, et Ansible jõuab SSH kaudu masinasse ja seal töötab Python. Ad-hoc käsk sobib kiireks kontrolliks. Seadistuse, mida soovid korrata, kirjuta playbook'i.

**Moodulid** täidavad konkreetseid haldusülesandeid. Alustamiseks piisab mõnest:

| Moodul | Mida haldab |
|---|---|
| `ansible.builtin.file` | kaustad, õigused, omanikud |
| `ansible.builtin.copy` | faili sisu |
| `ansible.builtin.package` | paketid (`apt` või `dnf`) |
| `ansible.builtin.service` | teenused |
| `ansible.builtin.command` | käivitab käsu; soovitud olekut Ansible ei tea |

*Tabel 4. Sagedasemad moodulid.*

Mooduli parameetrid ja näited näed käsuga `ansible-doc ansible.builtin.file`.

**Playbook** on YAML-fail, milles on üks või mitu **play**'d. Play määrab, millistes masinates (`hosts`) millised **ülesanded** (`tasks`) täidetakse. Iga ülesanne kasutab üht moodulit. Päeva ülesanne playbook'ina:

```yaml
- name: Koolituse seadistus
  hosts: web01
  tasks:
    - name: Kaust on olemas
      ansible.builtin.file:
        path: /home/kasutaja/automation-lab
        state: directory
        mode: "0750"

    - name: Konfiguratsioonifail on olemas
      ansible.builtin.copy:
        dest: /home/kasutaja/automation-lab/training.conf
        content: |
          environment=training
          enabled=true
        mode: "0640"
```

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 230" role="img" aria-label="Playbook sisaldab play'd, play sisaldab ülesandeid, iga ülesanne kasutab üht moodulit koos parameetritega" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.12;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:13.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<rect class="box" x="10" y="10" width="700" height="210" rx="10"/><text class="t" x="26" y="34">training.yml · playbook</text>
<rect class="hi" x="26" y="46" width="668" height="160" rx="8"/><text class="b" x="42" y="68">play · name: Koolituse seadistus · hosts: web01</text>
<rect class="box" x="42" y="82" width="310" height="110" rx="6"/><text class="b" x="56" y="104">ülesanne: Kaust on olemas</text><text class="c" x="56" y="132">ansible.builtin.file</text><text class="s" x="56" y="160">path · state: directory · mode</text><text class="s" x="56" y="180">moodul + parameetrid</text>
<rect class="box" x="368" y="82" width="310" height="110" rx="6"/><text class="b" x="382" y="104">ülesanne: Konfiguratsioonifail …</text><text class="c" x="382" y="132">ansible.builtin.copy</text><text class="s" x="382" y="160">dest · content · mode</text><text class="s" x="382" y="180">moodul + parameetrid</text>
</svg>
<figcaption>Joonis 7.1. Playbook koosneb play'dest. Igal play'l on sihtmasinad ja ülesanded ning iga ülesanne kasutab üht moodulit.</figcaption>
</figure>

Ülesannete nimed kirjeldavad olekut („Kaust **on** olemas“), mitte tegevust („Tee kaust“).

**YAML-i põhireeglid:** võtme ja väärtuse vahel on koolon ja tühik (`mode: "0750"`), loendi element algab märgiga `-` ning taane tehakse tühikutega, mitte tabulaatoriga. Õigused kirjuta jutumärkides: `mode: 0750` loetakse arvuna ja tulemus võib olla vale. Süntaksit kontrollib käsk `ansible-playbook training.yml --syntax-check`.

**Administraatori õigused.** Päeva ülesanne ei vaja administraatori õigusi. Paketi paigaldamiseks või `/etc` all oleva faili muutmiseks lisatakse play'le või ülesandele `become: true`: Ansible logib sisse tavakasutajana ja käivitab ülesande `sudo` kaudu. Laboris `sudo` parooli ei küsi, töökohas lisatakse käsule `-K`.

**Tingimus, sihtmasinad ja sildid.** Labori masinates on kaks distributsiooni ja samal programmil võib olla eri paketinimi (Ubuntus `vim`, AlmaLinuxis `vim-enhanced`). Kolm vahendit aitavad sama playbook'i kasutada eri masinates ja osaliselt:

| Vahend | Mida teeb | Näide |
|---|---|---|
| `when` | ülesanne käivitatakse ainult siis, kui tingimus on tõene; muidu on tulemus `skipping` | `when: ansible_facts['os_family'] == "RedHat"` |
| `--limit` | käivitab playbook'i ainult osas masinatest, playbook'i muutmata | `ansible-playbook tools.yml --limit web01` |
| `tags` | ülesande silt; `--tags` käivitab ainult valitud siltidega ülesanded | `ansible-playbook tools.yml --tags motd` |

*Tabel 5. Tingimus, sihtmasinad ja sildid.*

Tingimus põhineb **faktidel**: andmetel, mida Ansible kogub masinast enne ülesandeid (operatsioonisüsteem, versioon, võrk). Ubuntus on `ansible_facts['os_family']` väärtus `Debian`, AlmaLinuxis `RedHat`.

## 6. Käivitamine ja tulemus

```bash
ansible-playbook training.yml
```

Ansible loeb inventory'st masinad, kogub neist fakte (`Gathering Facts`), saadab iga ülesande mooduli masinasse ja kuvab lõpus kokkuvõtte:

```text
PLAY RECAP *********************************************************
web01   : ok=3  changed=2  unreachable=0  failed=0  skipped=0
```

| Väli | Tähendus |
|---|---|
| `ok` | edukalt lõppenud ülesanded (ka need, mis midagi muutsid) |
| `changed` | neist need, mis midagi muutsid |
| `unreachable` | masinaga ei saanud ühendust |
| `failed` | ülesanne ebaõnnestus |
| `skipped` | ülesanne jäeti tingimuse (`when`) tõttu vahele |

*Tabel 6. PLAY RECAP väljad.*

Kui kaust ja fail on juba olemas ja õiged, on tulemus `ok` ja `changed=0`: Ansible ei muuda midagi ainult seetõttu, et playbook käivitati.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 150" role="img" aria-label="Soovitud ja tegelik faili sisu võrreldakse; kui erineb, kirjutatakse ja tulemus on changed, kui sama, ei kirjutata ja tulemus on ok" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxi" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="10" width="200" height="56" rx="8"/><text class="b" x="110" y="33" text-anchor="middle">Soovitud sisu</text><text class="s" x="110" y="52" text-anchor="middle">playbook'is</text>
<rect class="box" x="10" y="84" width="200" height="56" rx="8"/><text class="b" x="110" y="107" text-anchor="middle">Tegelik sisu</text><text class="s" x="110" y="126" text-anchor="middle">web01 training.conf</text>
<line class="a" x1="210" y1="38" x2="268" y2="68" marker-end="url(#lxi)"/><line class="a" x1="210" y1="112" x2="268" y2="82" marker-end="url(#lxi)"/>
<rect class="hi" x="270" y="50" width="130" height="50" rx="8"/><text class="b" x="335" y="80" text-anchor="middle">Võrdlus</text>
<line class="a" x1="400" y1="68" x2="458" y2="38" marker-end="url(#lxi)"/><line class="a" x1="400" y1="82" x2="458" y2="112" marker-end="url(#lxi)"/>
<rect class="box" x="460" y="10" width="250" height="56" rx="8"/><text class="b" x="585" y="33" text-anchor="middle">Erineb → kirjuta</text><text class="c" x="585" y="53" text-anchor="middle">changed</text>
<rect class="box" x="460" y="84" width="250" height="56" rx="8"/><text class="b" x="585" y="107" text-anchor="middle">Sama → ära kirjuta</text><text class="c" x="585" y="127" text-anchor="middle">ok</text>
</svg>
<figcaption>Joonis 7.2. Moodul võrdleb soovitud ja tegelikku sisu ning kirjutab ainult siis, kui need erinevad.</figcaption>
</figure>

Kui keegi muudab faili käsitsi, tekib **triiv (drift)**: tegelik olek erineb soovitud olekust. Järgmisel käivitusel taastab Ansible soovitud sisu ja `changed` on ainult sellel ülesandel. Võtmetega `--check --diff` näed enne käivitamist, mida Ansible muudaks.

Idempotentsus sõltub lahendusest, mitte tööriistast. Käsumoodulid (`command`, `shell`) ei tea soovitud olekut ja võivad anda igal käivitusel `changed`. Ka Bashi skripti saab kirjutada idempotentseks.

## 7. Kontrolli tulemust masinas

Kui Ansible lõpetab vigadeta, tähendab see ainult seda, et ülesanded käivitusid. See ei tõenda, et masinas on vajalik tulemus. Kui playbook'is on vale tee, vale õigus või vale masin, lõpetab Ansible samuti edukalt, aga ülesanne jääb tegemata. Seepärast kontrolli pärast käivitamist masinat ennast:

```bash
ssh web01 cat automation-lab/training.conf
ssh web01 stat -c '%a %U %n' automation-lab automation-lab/training.conf
```

Muudatuse mõju saab piirata juba enne käivitamist. Võti `--check --diff` näitab, mida Ansible muudaks, ilma midagi muutmata. Võti `--limit web01` käivitab playbook'i ainult ühes masinas. Nii proovid muudatust enne, kui see jõuab kõigisse masinatesse.

## 8. Kokkuvõte

- **Skriptis tuleb iga kontroll ise kirjutada,** Ansible'i moodulites on need olemas.
- **Playbook kirjeldab soovitud olekut:** inventory määrab masinad, playbook ülesanded ja moodul võrdleb soovitud olekut tegelikuga.
- **`changed=0` korduval käivitusel** näitab, et playbook käitus idempotentselt.
- **Edukas käivitus ei tõenda tulemust:** kontrolli masinat ennast.

Järgmisel kohtumisel seadistad playbook'iga mitut masinat korraga: lisanduvad grupid, muutujad, mallid ja rollid.

??? info "Loe juurde"

    - [Getting started with Ansible](https://docs.ansible.com/projects/ansible/latest/getting_started/index.html)
    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
    - [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
    - [`ansible.builtin` moodulite loend](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/index.html)
    - [Google SRE: Eliminating Toil](https://sre.google/sre-book/eliminating-toil/)
