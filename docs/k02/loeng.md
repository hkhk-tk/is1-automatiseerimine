---
tags:
  - Ansible
  - Loeng
---

# 2. kohtumine · Ansible mitmele masinale

??? abstract "Õpiväljundid"

    Pärast seda kohtumist oskad:

    - hoida väärtusi muutujates ja valida, kas need kuuluvad kõigile masinatele, grupile või ühele masinale;
    - korrata ülesannet `loop`-iga, salvestada tulemust `register`-iga ja taaskäivitada teenust handler'iga ainult siis, kui konfiguratsioon muutus;
    - kirjutada Jinja2 malli, mille väärtused tulevad muutujatest ja faktidest;
    - jagada töötav playbook rollideks ja panna need kokku failis `site.yml`;
    - paigaldada kogu (collection) faili `requirements.yml` abil ja kasutada selle mooduleid;
    - hoida parooli Vaulti abil krüpteeritult Gitis;
    - vaadata muudatust enne selle tegemist (`--check --diff`) ja rakendada seda masinhaaval (`serial`, `--limit`).

## 1. Ühest masinast mitme masinani

**Küsimus:** mis muutub, kui masinaid on mitu ja need ei ole ühesugused?

Eelmisel kohtumisel seadistasid Ansible'iga ühe masina ja kontrollisid korduva käivituse tulemust. Nüüd kasutad sama põhimõtet mitme masina seadistamiseks. Masinad vajavad erinevat konfiguratsiooni: veebiserver vajab nginx-i, andmebaasiserver MariaDB-d ja kasutajad tuleb luua kõigis masinates. Kasvaval playbook'il peab olema selge ülesehitus, muidu tekib mõne nädalaga sadade ridadega fail, mida keegi ei julge muuta.

Tänase päeva lõpuks on sul projekt, kus:

- **muutujad** hoiavad väärtusi eraldi ülesannetest;
- **mallid** teevad muutujatest konfiguratsioonifailid;
- **handler'id** taaskäivitavad teenuse ainult siis, kui konfiguratsioon muutus;
- **rollid** jagavad töö loogilisteks osadeks: ühine, veeb, andmebaas;
- **Vault** hoiab andmebaasi parooli krüpteeritult;
- **`site.yml`** ühendab kõik osad ja teisel käivitusel on `changed=0`.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 200" role="img" aria-label="Täna ehitatav projekt: site.yml käivitab rollid common kõigile masinatele, veeb gruppi veeb ja andmebaas gruppi andmebaas" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.14;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxs2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="hi" x="280" y="10" width="160" height="44" rx="8"/><text class="c" x="360" y="37" text-anchor="middle">site.yml</text>
<line class="a" x1="320" y1="54" x2="110" y2="96" marker-end="url(#lxs2)"/><line class="a" x1="360" y1="54" x2="360" y2="96" marker-end="url(#lxs2)"/><line class="a" x1="400" y1="54" x2="610" y2="96" marker-end="url(#lxs2)"/>
<rect class="box" x="20" y="98" width="180" height="90" rx="8"/><text class="b" x="110" y="122" text-anchor="middle">roll common</text><text class="s" x="110" y="146" text-anchor="middle">kasutajad</text><text class="s" x="110" y="170" text-anchor="middle">kõik 5 masinat</text>
<rect class="box" x="270" y="98" width="180" height="90" rx="8"/><text class="b" x="360" y="122" text-anchor="middle">roll veeb</text><text class="s" x="360" y="146" text-anchor="middle">nginx, mall, handler</text><text class="s" x="360" y="170" text-anchor="middle">web01, app01</text>
<rect class="box" x="520" y="98" width="180" height="90" rx="8"/><text class="b" x="610" y="122" text-anchor="middle">roll andmebaas</text><text class="s" x="610" y="146" text-anchor="middle">MariaDB, parool Vaultist</text><text class="s" x="610" y="170" text-anchor="middle">db01</text>
</svg>
<figcaption>Joonis 1.1. Selle kohtumise projekt.</figcaption>
</figure>

Inventory jääb samaks nagu 1. kohtumisel, lisanduvad kaks gruppi masinate otstarbe järgi:

```ini
[ubuntu]
web01
app01
rmq01

[alma]
mc01
db01

[veeb]
web01
app01

[andmebaas]
db01

[all:vars]
ansible_user=kasutaja
```

Sama masin võib olla mitmes grupis: web01 kuulub nii gruppi `ubuntu` kui ka `veeb`. Operatsioonisüsteemi järgi grupid aitavad otsustada, kuidas midagi teha. Otstarbe järgi grupid määravad, mida masinas teha.

??? note "Süvenemiseks: teised konfiguratsioonihalduse tööriistad"

    Puppet, Chef ja Salt lahendavad sama ülesannet agendi ja serveriga. Nende võrdlus on lehel [Konfiguratsioonihaldus](../teemad/konfiguratsioonihaldus.md).

??? question "Kontrolli ennast"

    1. Miks on web01 kahes grupis ja mida kumbki grupp tähendab?
    2. Mis juhtub, kui kõik tänased ülesanded oleksid ühes playbook'is ühe play all?

## 2. Muutujad ja faktid

**Küsimus:** kuhu panna väärtused, mis on masinatel erinevad?

### Muutuja

**Muutuja** on nimega väärtus. Playbook'is kasutad seda kujul `{{ nimi }}`. Nii jääb ülesanne samaks, kuid väärtus võib masinati erineda:

```yaml
- name: Veebilehe kaust on olemas
  ansible.builtin.file:
    path: "{{ veeb_juur }}"
    state: directory
```

Kui väärtus algab `{{`-ga, pane kogu väärtus jutumärkidesse. Muidu tõlgendab YAML seda sõnastikuna ja tekib viga.

### Kus muutujaid hoitakse

Väärtused hoitakse projekti kaustades inventory kõrval:

```text
k02/
├── inventory.ini
├── group_vars/
│   ├── all.yml          # kõigile masinatele
│   ├── veeb.yml         # grupile veeb
│   └── andmebaas/       # grupile andmebaas, mitu faili
│       ├── vars.yml
│       └── vault.yml
└── host_vars/
    └── web01.yml        # ainult web01-le
```

Faili nimi on grupi või masina nimi. Ansible loeb need failid automaatselt ja playbook'is ei ole vaja midagi lisada.

```yaml
# group_vars/veeb.yml
veeb_pealkiri: "IS1 labor"
veeb_port: 80
```

### Milline väärtus jääb kehtima

Kui sama muutuja on määratud mitmes kohas, jääb kehtima täpsem väärtus. Ansible'i täielik prioriteetide järjekord on pikk, alustamiseks piisab järgmisest:

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 120" role="img" aria-label="Muutujate järjekord nõrgemast tugevamani: rolli defaults, group_vars all, group_vars grupp, host_vars, play vars, -e" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxv2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="5" y="20" width="108" height="44" rx="6"/><text class="c" x="59" y="47" text-anchor="middle">defaults</text>
<rect class="box" x="125" y="20" width="108" height="44" rx="6"/><text class="c" x="179" y="47" text-anchor="middle">group all</text>
<rect class="box" x="245" y="20" width="108" height="44" rx="6"/><text class="c" x="299" y="47" text-anchor="middle">group veeb</text>
<rect class="box" x="365" y="20" width="108" height="44" rx="6"/><text class="c" x="419" y="47" text-anchor="middle">host_vars</text>
<rect class="box" x="485" y="20" width="108" height="44" rx="6"/><text class="c" x="539" y="47" text-anchor="middle">play vars</text>
<rect class="hi" x="605" y="20" width="108" height="44" rx="6"/><text class="c" x="659" y="47" text-anchor="middle">-e</text>
<line class="a" x1="20" y1="90" x2="700" y2="90" marker-end="url(#lxv2)"/><text class="s" x="20" y="112">nõrgem</text><text class="s" x="700" y="112" text-anchor="end">tugevam: võidab</text>
</svg>
<figcaption>Joonis 2.1. Kui muutuja on määratud mitmes kohas, jääb kehtima paremal olev väärtus.</figcaption>
</figure>

| Koht | Millal kasutada |
|---|---|
| rolli `defaults/main.yml` | mõistlik vaikeväärtus, mida kasutaja võib üle kirjutada |
| `group_vars/all.yml` | kõigile masinatele ühine väärtus, näiteks kasutajate loend |
| `group_vars/<grupp>.yml` | ühe grupi väärtused, näiteks veebiserveri port |
| `host_vars/<masin>.yml` | üks masin on teistest erinev |
| play `vars:` | väärtus kuulub selle playbook'i juurde |
| `-e nimi=väärtus` | ühekordne üle kirjutamine käsurealt |

*Tabel 2.1. Kuhu muutuja panna.*

Muutuja väärtust näed ad-hoc käsuga. Nii saad kõige kindlamalt kontrollida, millist väärtust Ansible kasutab:

```bash
ansible web01 -m ansible.builtin.debug -a "var=veeb_pealkiri"
```

### Faktid tingimustes

1. kohtumisel nägid, et Ansible kogub masinast fakte. Ka faktid on muutujad, kuid nende väärtused kogub Ansible ise:

| Fakt | Näide |
|---|---|
| `ansible_facts['os_family']` | `Debian`, `RedHat` |
| `ansible_facts['distribution']` | `Ubuntu`, `AlmaLinux` |
| `ansible_facts['default_ipv4']['address']` | masina IP |
| `ansible_facts['memtotal_mb']` | mälu megabaitides |

*Tabel 2.2. Sagedasemad faktid.*

**`inventory_hostname`** on masina nimi inventory's (`web01`). See ei ole fakt, vaid Ansible'i enda muutuja ja on olemas ka siis, kui fakte ei koguta.

??? note "Muutujate nimed"

    Pane muutuja nime ette rolli või teema nimi: `veeb_port`, mitte `port`. Siis ei kirjuta kaks rolli kogemata teineteise väärtust üle. Nimes on ainult väiketähed, numbrid ja alakriips.

??? question "Kontrolli ennast"

    1. `veeb_port` on `group_vars/veeb.yml`-is `80` ja `host_vars/app01.yml`-is `8080`. Millist porti app01 kasutab?
    2. Miks on `path: "{{ veeb_juur }}"` jutumärkides?
    3. Mis vahe on `inventory_hostname`-il ja `ansible_facts['hostname']`-il?

??? info "Loe juurde"

    - [Using variables](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html)
    - [Variable precedence](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
    - [Organizing host and group variables](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables)
    - [Discovering variables: facts](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_vars_facts.html)

## 3. Tsükkel, tulemus ja handler

**Küsimus:** kuidas käivitada sama ülesannet mitu korda, kasutada eelmise ülesande tulemust ja taaskäivitada teenust ainult vajaduse korral?

### `loop`: üks ülesanne, mitu väärtust

Kolme kasutaja jaoks kolme eraldi ülesande kirjutamine oleks kordamine. **`loop`** käivitab sama ülesande loendi iga elemendiga ja element on muutujas `item`:

```yaml
# group_vars/all.yml
labori_kasutajad:
  - anna
  - peeter
  - mari
```

```yaml
- name: Kasutajad on olemas
  ansible.builtin.user:
    name: "{{ item }}"
    shell: /bin/bash
    state: present
  loop: "{{ labori_kasutajad }}"
```

Uue kasutaja lisamiseks muudad ainult loendit, ülesanne jääb samaks. Väljundis on iga element eraldi real: `changed: [web01] => (item=anna)`.

Loendi element võib olla ka sõnastik. Siis loed välja väärtuse punktiga:

```yaml
labori_kasutajad:
  - { nimi: anna, shell: /bin/bash }
  - { nimi: peeter, shell: /bin/sh }
```

```yaml
    name: "{{ item.nimi }}"
    shell: "{{ item.shell }}"
```

### `register`: ülesande tulemus muutujasse

Iga moodul tagastab tulemuse. **`register`** salvestab selle muutujasse, mida saad järgmistes ülesannetes kasutada:

```yaml
- name: Kodukaustade nimekiri
  ansible.builtin.command: ls /home
  register: kodud
  changed_when: false

- name: Näita tulemust
  ansible.builtin.debug:
    var: kodud.stdout_lines
```

| Väli | Sisu |
|---|---|
| `kodud.stdout` | käsu väljund ühe tekstina |
| `kodud.stdout_lines` | väljund ridade loendina |
| `kodud.rc` | väljumiskood |
| `kodud.changed` | kas ülesanne muutis midagi |

*Tabel 3.1. `register`-iga salvestatud tulemus.*

`changed_when: false` määrab, et see käsk ainult loeb ega muuda midagi. Ilma selleta oleks `command` ülesande tulemus igal käivitusel `changed` (vt 1. kohtumine).

### `when` uuesti

1. kohtumisel valisid `when` abil ülesande operatsioonisüsteemi järgi. Sama tingimus töötab ka `register`-i tulemusega:

```yaml
- name: Hoiatus, kui kodukaustu on liiga palju
  ansible.builtin.debug:
    msg: "Kodukaustu on {{ kodud.stdout_lines | length }}"
  when: kodud.stdout_lines | length > 5
```

`| length` on **filter**: see tagastab väärtuse pikkuse. Filtritest tuleb rohkem juttu mallide juures.

### Handler: taaskäivitus ainult muudatuse korral

Kui muudad teenuse konfiguratsioonifaili, peab teenus selle uuesti lugema. Kui fail ei muutunud, oleks taaskäivitus tarbetu katkestus. **Handler** on ülesanne, mis käivitub ainult siis, kui mõni teine ülesanne seda **`notify`**-ga teavitas ja selle ülesande tulemus oli `changed`:

```yaml
- name: Veebiserver
  hosts: veeb
  become: true
  tasks:
    - name: nginx-i seadistus on olemas
      ansible.builtin.template:
        src: labor.conf.j2
        dest: /etc/nginx/conf.d/labor.conf
        mode: "0644"
      notify: reload nginx

  handlers:
    - name: reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 150" role="img" aria-label="Ülesanne muudab faili ja teavitab handlerit; handler käivitub play lõpus üks kord; kui ülesanne on ok, handler ei käivitu" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:4 3}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxh2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="15" width="200" height="50" rx="8"/><text class="b" x="110" y="37" text-anchor="middle">template</text><text class="s" x="110" y="55" text-anchor="middle">changed</text>
<line class="a" x1="210" y1="40" x2="268" y2="40" marker-end="url(#lxh2)"/><text class="s" x="239" y="32" text-anchor="middle">notify</text>
<rect class="hi" x="270" y="15" width="200" height="50" rx="8"/><text class="b" x="370" y="37" text-anchor="middle">handler ootab</text><text class="s" x="370" y="55" text-anchor="middle">play lõpuni</text>
<line class="a" x1="470" y1="40" x2="528" y2="40" marker-end="url(#lxh2)"/>
<rect class="box" x="530" y="15" width="180" height="50" rx="8"/><text class="b" x="620" y="37" text-anchor="middle">reload nginx</text><text class="s" x="620" y="55" text-anchor="middle">üks kord</text>
<rect class="box" x="10" y="90" width="200" height="50" rx="8"/><text class="b" x="110" y="112" text-anchor="middle">template</text><text class="s" x="110" y="130" text-anchor="middle">ok</text>
<line class="a d" x1="210" y1="115" x2="268" y2="115"/><text class="s" x="280" y="120">handler ei käivitu, teenus jääb puutumata</text>
</svg>
<figcaption>Joonis 3.1. Handler käivitub ainult siis, kui teavitanud ülesanne oli <code>changed</code>.</figcaption>
</figure>

Handler'ite kohta kehtib kolm reeglit:

- `notify` väärtus peab olema täpselt handler'i nimi;
- handler käivitub **play lõpus**, mitte kohe;
- handler käivitub **üks kord**, olenemata sellest, mitu ülesannet seda teavitas.

??? note "Kui handler peab käivituma kohe"

    `- ansible.builtin.meta: flush_handlers` käivitab ootel handler'id selles kohas. Seda on vaja, kui järgmine ülesanne eeldab, et teenus juba töötab uue konfiguratsiooniga.

??? question "Kontrolli ennast"

    1. Mis on `loop`-i sees muutujas `item`?
    2. Miks on `ls /home` ülesandel `changed_when: false`?
    3. Kaks ülesannet teavitavad sama handler'it. Mitu korda handler käivitub?
    4. Mis juhtub handler'iga, kui konfiguratsioonifail ei muutunud?

??? info "Loe juurde"

    - [Loops](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_loops.html)
    - [Return values](https://docs.ansible.com/projects/ansible/latest/reference_appendices/common_return_values.html)
    - [Handlers](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html)
    - [Defining failure and changed](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html)

## 4. Mallid

**Küsimus:** kuidas saavad muutujate väärtused konfiguratsioonifaili?

### `copy` ja `template`

1. kohtumisel kirjutas `copy` faili täpselt sellise sisuga, nagu playbook'is oli kirjas. **`template`** loeb faili, asendab selles muutujad ja kirjutab tulemuse masinasse. Mall on tavaline tekstifail laiendiga `.j2` ja asub kaustas `templates/`. Mallikeel on **Jinja2**.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 150" role="img" aria-label="Mall index.html.j2 ja muutujad koos faktidega annavad iga masina jaoks oma valmis faili" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .c{fill:var(--md-default-fg-color);font-size:12px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxm2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="10" width="220" height="60" rx="8"/><text class="b" x="120" y="32" text-anchor="middle">index.html.j2</text><text class="c" x="120" y="54" text-anchor="middle">&lt;h1&gt;{{ veeb_pealkiri }}&lt;/h1&gt;</text>
<rect class="box" x="10" y="80" width="220" height="60" rx="8"/><text class="b" x="120" y="102" text-anchor="middle">muutujad ja faktid</text><text class="c" x="120" y="124" text-anchor="middle">veeb_pealkiri: IS1 labor</text>
<line class="a" x1="230" y1="40" x2="298" y2="68" marker-end="url(#lxm2)"/><line class="a" x1="230" y1="110" x2="298" y2="82" marker-end="url(#lxm2)"/>
<rect class="hi" x="300" y="50" width="120" height="50" rx="8"/><text class="b" x="360" y="80" text-anchor="middle">template</text>
<line class="a" x1="420" y1="75" x2="478" y2="75" marker-end="url(#lxm2)"/>
<rect class="box" x="480" y="40" width="230" height="70" rx="8"/><text class="b" x="595" y="64" text-anchor="middle">web01: index.html</text><text class="c" x="595" y="88" text-anchor="middle">&lt;h1&gt;IS1 labor&lt;/h1&gt;</text>
</svg>
<figcaption>Joonis 4.1. Mallist ja muutujate väärtustest tekib iga masina jaoks oma fail.</figcaption>
</figure>

### Jinja2 põhivõtted

| Kirjutis | Mida teeb | Näide |
|---|---|---|
| `{{ ... }}` | väljastab väärtuse | `{{ inventory_hostname }}` |
| <code>{{ x &#124; filter }}</code> | muudab väärtust | <code>{{ veeb_pealkiri &#124; upper }}</code> |
| <code>{{ x &#124; default('...') }}</code> | vaikeväärtus, kui muutujat pole | <code>{{ veeb_port &#124; default(80) }}</code> |
| `{% if %} ... {% endif %}` | tingimus | `{% if ansible_facts['os_family'] == 'Debian' %}` |
| `{% for x in list %} ... {% endfor %}` | tsükkel | kõik kasutajad loendis |
| `{# ... #}` | kommentaar, väljundisse ei jõua | |

*Tabel 4.1. Jinja2 põhivõtted.*

Veebilehe mall:

```html
<!doctype html>
<html lang="et">
<head><meta charset="utf-8"><title>{{ veeb_pealkiri }}</title></head>
<body>
  <h1>{{ veeb_pealkiri }}</h1>
  <p>Masin: {{ inventory_hostname }} ({{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }})</p>
  <p>Kasutajad: {{ labori_kasutajad | join(', ') }}</p>
</body>
</html>
```

```yaml
- name: Veebileht on olemas
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/labor/index.html
    mode: "0644"
```

Samast mallist tekib web01-s ja app01-s erinev fail, sest `inventory_hostname` on erinev. `template` on idempotentne nagu `copy`: kui mallist tekkinud fail on sama mis masinas olev fail, on tulemus `ok`.

### Vigane konfiguratsioon ei jõua teenuseni

Vigane konfiguratsioonifail võib teenuse töö peatada. **`validate`** kontrollib uut faili **enne**, kui see sihtkohta kopeeritakse. `%s` asendatakse ajutise faili teega:

```yaml
- name: sudo reegel laborile
  ansible.builtin.template:
    src: labor-sudoers.j2
    dest: /etc/sudoers.d/labor
    mode: "0440"
    validate: visudo -cf %s
```

Kui `visudo` leiab vea, ülesanne ebaõnnestub ja vana fail jääb alles. `validate` töötab ainult siis, kui kontrollitav fail on iseseisev. nginx-i puhul kontrollitakse kogu konfiguratsiooni käsuga `nginx -t`. Laboris teed seda pärast muudatust.

??? note "Päis `ansible_managed`"

    Pane malli esimesele reale `# {{ ansible_managed }}`. Siis on valmis failis kommentaar „Ansible managed“ ja faili avaja näeb, et käsitsi tehtud muudatus kirjutatakse järgmisel käivitusel üle.

??? question "Kontrolli ennast"

    1. Mis vahe on moodulitel `copy` ja `template`?
    2. Mida teeb `{{ labori_kasutajad | join(', ') }}`?
    3. Millal kasutad `validate`-i ja mis juhtub, kui kontroll ebaõnnestub?

??? info "Loe juurde"

    - [Templating (Jinja2)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_templating.html)
    - [Using filters](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_filters.html)
    - [`ansible.builtin.template`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/template_module.html)

## 5. Rollid

**Küsimus:** kuidas jagada kasvav projekt osadeks, mida saab eraldi muuta ja uuesti kasutada?

### Mis on roll

Pärast muutujaid, malle ja handler'eid on veebiserveri playbook juba pikk. Andmebaas ja kasutajad pikendavad seda veelgi. **Roll** on kindla ülesehitusega kaust, kuhu läheb kõik, mis ühe osa juurde kuulub: ülesanded, handler'id, mallid ja vaikeväärtused. Playbook määrab siis ainult, millist rolli millistes masinates kasutatakse.

```text
roles/veeb/
├── defaults/main.yml     # vaikeväärtused, kõige nõrgemad
├── handlers/main.yml     # handler'id
├── tasks/main.yml        # ülesanded
└── templates/            # mallid
    ├── index.html.j2
    └── labor.conf.j2
```

Kaustu, mida roll ei kasuta, ei ole vaja luua. Tühja rolli ülesehituse loob käsk `ansible-galaxy role init roles/veeb`, kuid käsitsi loomine on algajale arusaadavam.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 170" role="img" aria-label="Playbook'i osad lähevad rolli kaustadesse: tasks tasks/main.yml-i, handlers handlers/main.yml-i, mallid templates kausta, vaikeväärtused defaults/main.yml-i" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.14;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxr2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="10" width="250" height="150" rx="10"/><text class="b" x="26" y="34">veeb.yml (playbook)</text>
<text class="c" x="26" y="62">tasks:</text><text class="c" x="26" y="88">handlers:</text><text class="c" x="26" y="114">vars:</text><text class="c" x="26" y="140">templates/*.j2</text>
<line class="a" x1="150" y1="58" x2="408" y2="40" marker-end="url(#lxr2)"/><line class="a" x1="150" y1="84" x2="408" y2="76" marker-end="url(#lxr2)"/><line class="a" x1="150" y1="110" x2="408" y2="112" marker-end="url(#lxr2)"/><line class="a" x1="150" y1="136" x2="408" y2="148" marker-end="url(#lxr2)"/>
<rect class="hi" x="410" y="10" width="300" height="150" rx="10"/>
<text class="c" x="426" y="44">roles/veeb/tasks/main.yml</text><text class="c" x="426" y="80">roles/veeb/handlers/main.yml</text><text class="c" x="426" y="116">roles/veeb/defaults/main.yml</text><text class="c" x="426" y="152">roles/veeb/templates/</text>
</svg>
<figcaption>Joonis 5.1. Rolli loomisel tõstetakse töötava playbook'i osad rolli kaustadesse.</figcaption>
</figure>

Rolli failides ei ole play päist (`hosts`, `tasks:`), on ainult ülesannete loend:

```yaml
# roles/veeb/tasks/main.yml
- name: nginx on paigaldatud
  ansible.builtin.package:
    name: nginx
    state: present

- name: nginx töötab ja käivitub boodil
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

Rollis otsitakse malli `src: index.html.j2` automaatselt kaustast `roles/veeb/templates/`.

### `defaults` ja `vars`

| Kaust | Prioriteet | Kasutus |
|---|---|---|
| `defaults/main.yml` | kõige madalam | väärtused, mida rolli kasutaja tohib üle kirjutada: port, pealkiri |
| `vars/main.yml` | kõrgem kui `group_vars` | rolli sisemised väärtused, mida väljast muuta ei tohiks |

*Tabel 5.1. Rolli muutujad.*

Alustamiseks piisab reeglist: pane rolli väärtused `defaults/main.yml`-i ja kirjuta need vajadusel üle `group_vars`-is või `host_vars`-is.

### `site.yml`: kõik rollid koos

```yaml
- name: Kõik masinad
  hosts: all
  become: true
  roles:
    - common

- name: Veebiserverid
  hosts: veeb
  become: true
  roles:
    - veeb

- name: Andmebaas
  hosts: andmebaas
  become: true
  roles:
    - andmebaas
```

Üks käsk seadistab kogu labori. Iga play määrab, millist rolli millise grupi masinates kasutatakse. Ansible otsib rolle kaustast `roles/` playbook'i kõrval.

??? note "Roll Galaxyst"

    Valmis rolle jagatakse [Ansible Galaxys](https://galaxy.ansible.com/). Enne võõra rolli kasutamist vaata, millal seda viimati uuendati, mida selle ülesanded täpselt teevad ja millised muutujad sellel on. Võõras roll töötab sinu masinates `become`-iga ehk samade õigustega nagu sinu enda kood.

??? question "Kontrolli ennast"

    1. Mis kaustadest roll koosneb ja mis igaühes on?
    2. Miks pole rolli `tasks/main.yml`-is rida `hosts:`?
    3. Kummal on madalam prioriteet, `defaults`-il või `group_vars`-il? Miks on see rolli puhul kasulik?

??? info "Loe juurde"

    - [Roles](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
    - [Sample Ansible setup](https://docs.ansible.com/projects/ansible/latest/tips_tricks/sample_setup.html)

## 6. Kogud ja Galaxy

**Küsimus:** kust tulevad moodulid, mida `ansible-core`'is pole?

### Kogu

`ansible-core` sisaldab ainult põhimooduleid (`ansible.builtin.*`). Kõik muu tuleb **kogudest** (collection): pakkidest, kus on moodulid, rollid ja pluginad ühe teema kohta. Kogu nimi koosneb kahest osast: nimeruumist ja nimest.

| Kogu | Mida sisaldab |
|---|---|
| `ansible.mysql` | MariaDB ja MySQL: andmebaasid, kasutajad, õigused (vanades juhendites nimega `community.mysql`) |
| `community.general` | sadu eri valdkondade mooduleid, näiteks ajavöönd, UFW tulemüür |
| `ansible.posix` | Linuxi lisad: `firewalld`, `sysctl`, `authorized_key` |
| `community.docker` | Docker: image'id, konteinerid, Compose (3. kohtumine) |

*Tabel 6.1. Sagedasemad kogud.*

Mooduli täisnimi näitab, millisest kogust see pärineb: `ansible.mysql.mysql_db` on moodul `mysql_db` kogust `ansible.mysql`.

### `requirements.yml`

Kogud paigaldatakse control node'ile käsuga `ansible-galaxy`. Et projekt töötaks ka kolleegi masinas, kirjuta vajalikud kogud faili `requirements.yml` ja lisa see Giti:

```yaml
collections:
  - name: ansible.mysql
```

```bash
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection list ansible.mysql
```

Kogud lähevad vaikimisi kausta `~/.ansible/collections/`. Mooduli juhendi näed samamoodi nagu sisseehitatud moodulitel: `ansible-doc ansible.mysql.mysql_user`.

??? note "Versiooni piiramine"

    `requirements.yml`-is saab versiooni piirata: `version: ">=3.0.0,<4.0.0"`. Siis ei muuda uus suurversioon sinu projekti käitumist ootamatult. Galaxy ja Red Hati automation hub'i vahet näed 1. kohtumise loengu tabelis „Ansible Automation Platformi komponendid“.

### Moodul kogust laboris

```yaml
- name: Andmebaas labor on olemas
  ansible.mysql.mysql_db:
    name: labor
    state: present
    login_unix_socket: /var/lib/mysql/mysql.sock
```

AlmaLinuxi MariaDB-s saab `root` sisse logida Unixi sokli kaudu ilma paroolita, kui ühendus tuleb sama masina kasutajalt `root`. `become: true` tagab just selle.

??? question "Kontrolli ennast"

    1. Mis vahe on `ansible-core`'il ja kogul?
    2. Miks panna kogud `requirements.yml`-i, mitte lihtsalt käsurealt paigaldada?
    3. Millisest kogust tuleb moodul `ansible.posix.firewalld`?

??? info "Loe juurde"

    - [Using Ansible collections](https://docs.ansible.com/projects/ansible/latest/collections_guide/index.html)
    - [Installing collections](https://docs.ansible.com/projects/ansible/latest/collections_guide/collections_installing.html)
    - [`ansible.mysql` kogu](https://docs.ansible.com/projects/ansible/latest/collections/ansible/mysql/index.html)

## 7. Saladused Vaultiga

**Küsimus:** kuidas hoida parooli Gitis nii, et kõrvaline isik seda lugeda ei saa?

### Probleem

Andmebaasi kasutaja vajab parooli. Kui see on `group_vars`-is avatekstina, on see Gitis kõigile nähtav ja jääb ajalukku ka pärast kustutamist. GitHubi saladuste skanner seda ei tuvasta, sest `db_parool: Salajane123` ei sarnane ühegi teenuse tokeniga.

### `ansible-vault`

**Ansible Vault** krüpteerib faili parooliga. Krüpteeritud fail võib olla Gitis, sest ilma Vaulti paroolita on see loetamatu. Ansible dekrüpteerib selle käivitamise ajal mälus.

```bash
ansible-vault create group_vars/andmebaas/vault.yml
```

Avaneb tekstiredaktor. Kirjuta faili:

```yaml
vault_db_parool: "MuudaMind-2026"
```

| Käsk | Mida teeb |
|---|---|
| `ansible-vault create fail.yml` | loob uue krüpteeritud faili |
| `ansible-vault view fail.yml` | näitab faili sisu |
| `ansible-vault edit fail.yml` | avab faili muutmiseks |
| `ansible-vault encrypt fail.yml` | krüpteerib olemasoleva avatekstiga faili |
| `ansible-vault rekey fail.yml` | vahetab Vaulti parooli |

*Tabel 7.1. `ansible-vault` käsud.*

Playbook'i käivitamisel lase Ansible'il Vaulti parooli küsida:

```bash
ansible-playbook site.yml --ask-vault-pass
```

`--ask-vault-pass` (lühidalt `-J`) küsib Vaulti parooli. See ei ole sama mis `sudo` parool: töökohas, kus `sudo` nõuab parooli, lisatakse käsule ka `-K` ja siis küsitakse kahte eri parooli.

### Kaks faili: `vars.yml` ja `vault.yml`

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 140" role="img" aria-label="vars.yml on loetav ja viitab muutujale vault_db_parool, mis on krüpteeritud failis vault.yml; Vaulti parool on ainult inimese peas või failis väljaspool Giti" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .c{fill:var(--md-default-fg-color);font-size:12px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxq2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="20" width="230" height="70" rx="8"/><text class="b" x="125" y="44" text-anchor="middle">vars.yml · Gitis loetav</text><text class="c" x="125" y="70" text-anchor="middle">db_parool: "{{ vault_db_parool }}"</text>
<line class="a" x1="240" y1="55" x2="298" y2="55" marker-end="url(#lxq2)"/>
<rect class="hi" x="300" y="20" width="230" height="70" rx="8"/><text class="b" x="415" y="44" text-anchor="middle">vault.yml · Gitis krüpteeritud</text><text class="c" x="415" y="70" text-anchor="middle">$ANSIBLE_VAULT;1.1;AES256…</text>
<line class="a" x1="620" y1="55" x2="532" y2="55" marker-end="url(#lxq2)"/>
<rect class="box" x="560" y="20" width="150" height="70" rx="8"/><text class="b" x="635" y="44" text-anchor="middle">Vaulti parool</text><text class="s" x="635" y="68" text-anchor="middle">ei ole Gitis</text>
<text class="s" x="360" y="125" text-anchor="middle">grep db_parool leiab muutuja, aga mitte väärtuse</text>
</svg>
<figcaption>Joonis 7.1. Loetav viide ja krüpteeritud väärtus on eraldi failides.</figcaption>
</figure>

```yaml
# group_vars/andmebaas/vars.yml  (loetav)
db_nimi: labor
db_kasutaja: labor
db_parool: "{{ vault_db_parool }}"
```

Nii on `grep`-iga ja koodiülevaatusel näha, millised muutujad on olemas ja kus neid kasutatakse, kuid väärtus jääb krüpteerituks. Eesliide `vault_` näitab, et väärtus tuleb Vaultist.

### Parool väljundis

Ansible väljastab ülesande parameetrid, kui midagi läheb valesti või kui käivitad `-v`-ga. Ülesandel, mis kasutab parooli, peab olema **`no_log: true`**:

```yaml
- name: Andmebaasi kasutaja on olemas
  ansible.mysql.mysql_user:
    name: "{{ db_kasutaja }}"
    password: "{{ db_parool }}"
    priv: "{{ db_nimi }}.*:ALL"
    state: present
    login_unix_socket: /var/lib/mysql/mysql.sock
  no_log: true
```

!!! warning "Mis ei lähe Giti"

    Vaulti parool, avatekstiga paroolifailid ja privaatvõtmed. Kui avatekstiga parool jõudis kordki GitHubi, vaheta see kohe: ajaloo ümberkirjutamine ei eemalda parooli juba tehtud kloonidest.

??? question "Kontrolli ennast"

    1. Miks võib krüpteeritud `vault.yml` olla Gitis?
    2. Miks on parool kahes failis (`vars.yml` ja `vault.yml`)?
    3. Mida teeb `no_log: true`?

??? info "Loe juurde"

    - [Protecting sensitive data with Ansible Vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html)
    - [Keep vaulted variables safely visible](https://docs.ansible.com/projects/ansible/latest/tips_tricks/ansible_tips_tricks.html#keep-vaulted-variables-safely-visible)

## 8. Kontrollitud muudatus

**Küsimus:** kuidas muuta viit masinat nii, et viga ei jõuaks korraga kõigini?

1. kohtumisel kasutasid `--check --diff`-i ja `--limit`-i ühe faili puhul. Mitme masina ja teenusega projektis on need veel olulisemad, sest üks vigane mall võib peatada kõigi veebiserverite töö korraga.

| Võte | Mida annab | Näide |
|---|---|---|
| `--check --diff` | näitab failide muudatust enne selle tegemist | `ansible-playbook site.yml --check --diff -J` |
| `--limit` | rakendab muudatuse ainult valitud masinates | `--limit web01` |
| `serial` | play töötleb korraga ainult osa masinatest | `serial: 1` |
| `--syntax-check`, `ansible-lint` | leiab vead enne käivitamist | `ansible-lint site.yml` |

*Tabel 8.1. Kontrollitud muudatuse võtted.*

### `serial`: masinhaaval

Vaikimisi täidab Ansible iga ülesande kõigis masinates ja liigub seejärel järgmise ülesande juurde. Kui mall on vigane, lakkab nginx kõigis veebiserverites töötamast peaaegu samal ajal. **`serial: 1`** täidab kogu play ühes masinas ja alles seejärel järgmises:

```yaml
- name: Veebiserverid
  hosts: veeb
  become: true
  serial: 1
  roles:
    - veeb
```

Kui esimeses masinas mõni ülesanne ebaõnnestub, peatub play enne, kui viga teise masinani jõuab. `serial` võib olla ka protsent (`"50%"`) või loend (`[1, "50%"]`): kõigepealt üks masin proovina, seejärel pooled masinad korraga.

### Muudatuse tegemise järjekord

1. muuda muutujat või malli;
2. vaata `--check --diff --limit web01` abil, mis failis muutuks;
3. rakenda muudatus `--limit web01` abil ja kontrolli teenust (`curl`);
4. rakenda muudatus kõigis masinates `serial`-iga;
5. käivita playbook uuesti ja veendu, et kokkuvõttes on `changed=0`;
6. tee commit ja saada muudatused GitHubi.

??? question "Kontrolli ennast"

    1. Mis vahe on `--limit`-il ja `serial`-il?
    2. Miks rakendad muudatuse kõigepealt ühes masinas?

??? info "Loe juurde"

    - [Controlling playbook execution: strategies and serial](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_strategies.html)
    - [Check mode ja diff](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)

## 9. Kokkuvõte

- **Muutujad** hoiavad väärtusi eraldi ülesannetest; kehtima jääb täpsem väärtus: `host_vars` on `group_vars`-ist tähtsam.
- **`loop`** kordab ülesannet, **`register`** salvestab tulemuse, **handler** taaskäivitab teenuse ainult muudatuse korral.
- **Mallist** tekib muutujate ja faktide põhjal iga masina jaoks oma fail.
- **Roll** hoiab ühe osa kõiki faile ühes kaustas; **`site.yml`** määrab, millist rolli millises grupis kasutatakse.
- **Kogud** paigaldatakse faili `requirements.yml` järgi ja mooduli täisnimi näitab, millisest kogust see pärineb.
- **Vault** hoiab parooli Gitis krüpteeritult; Vaulti parool Giti ei lähe.
- **Muudatus:** kõigepealt `--check --diff`, siis üks masin ja seejärel kõik masinad `serial`-iga.

Järgmisel kohtumisel paned rakenduse konteinerisse: rakendus ja kõik, mida see vajab, ühes pakis. Ansible jääb tööriistaks, mis paigaldab masinatesse Dockeri ja käivitab konteinerid.
