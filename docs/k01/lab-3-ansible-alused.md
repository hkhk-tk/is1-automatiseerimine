---
tags:
  - Ansible
  - Praktikum
---

# 3. Ansible'i alused

Eelmises osas tegid ülesande ühes masinas käsitsi ja skriptiga. Nüüd paigaldad Ansible'i, kirjeldad talle viis masinat ja käivitad käske kõigis masinates korraga. Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

!!! abstract "Dokumentatsioonis"

    [Start automating with Ansible](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_ansible.html) · [Building an inventory](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_inventory.html) · [Introduction to ad hoc commands](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)

## A1 · Paigalda Ansible

Ansible paigaldatakse ainult control node'i. Hallatavates masinates piisab SSH-st ja Pythonist, mis seal juba on.

```bash
sudo apt update
sudo apt install -y ansible-core
ansible --version
```

Esimene rida näitab versiooni (`ansible [core 2.x.y]`). Rida `config file = None` tähendab, et Ansible ei leidnud veel konfiguratsioonifaili. Selle lood järgmises sammus.

Paigaldamiseks on mitu viisi ([Installing Ansible](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html)). Valik sõltub sellest, kas tähtsam on lihtsus või kindel versioon:

| Viis | Käsk | Millal |
|---|---|---|
| distributsiooni pakett | `sudo apt install ansible-core` | lihtne ja uueneb koos süsteemiga, aga versioon on vanem (Ubuntu 24.04: 2.16) |
| pipx | `pipx install ansible-core` või `pipx install --include-deps ansible` | dokumentatsiooni soovitus: uusim või valitud versioon, eraldi Pythoni keskkonnas |
| pip ja venv | `python3 -m venv ~/ansible && ~/ansible/bin/pip install "ansible-core==2.21.*"` | versioon on projektis kinni, nii töötab ka kursuse automaatne hindaja |
| konteiner (Execution Environment) | `ansible-navigator run site.yml` | Ansible, kogud ja Pythoni teegid ühes konteineris, sama keskkond igal control node'il (3. kohtumine) |

*Tabel 1. Ansible'i paigaldusviisid.*

Pakette on kaks: `ansible-core` sisaldab Ansible'it ja kogu `ansible.builtin`, `ansible` lisab sellele valiku kogukonna kogusid. Kursusel kasutame `ansible-core`'i ja paigaldame vajalikud kogud 2. kohtumisel ise.

## A2 · Kirjelda masinad: `ansible.cfg` ja inventory

Ansible peab teadma, milliseid masinaid ta haldab. Need on kirjas **inventory** failis. Fail `ansible.cfg` ütleb Ansible'ile, millist inventory't kasutada, nii et seda ei pea iga käsu juurde kirjutama.

Mine projekti kausta ja loo fail `ansible.cfg`:

```bash
cd ~/kursus/k01
```

```ini
[defaults]
inventory = inventory.ini
```

Seejärel loo samasse kausta fail `inventory.ini`. Masinad on jagatud gruppidesse distributsiooni järgi, et saaksid hiljem käivitada ülesandeid ainult Ubuntu või ainult AlmaLinuxi masinates:

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

IP-aadresse inventory's ei ole, sest masinate nimed on juba failis `~/.ssh/config`. Dokumentatsiooni näidetes on igal käsul `-i inventory.ini`, meil teeb seda `ansible.cfg`. Kontrolli, et Ansible leiab mõlemad failid:

```bash
ansible --version | grep 'config file'
ansible-inventory --graph
```

??? success "Oodatav tulemus"

    ```
      config file = /home/kasutaja/kursus/k01/ansible.cfg
    @all:
      |--@ungrouped:
      |--@ubuntu:
      |  |--web01
      |  |--app01
      |  |--rmq01
      |--@alma:
      |  |--mc01
      |  |--db01
    ```

Ansible'i seaded võivad tulla mitmest kohast: projekti kausta `ansible.cfg`, kodukausta `~/.ansible.cfg`, `/etc/ansible/ansible.cfg` ja keskkonnamuutujad. Kehtib esimene leitud fail. Käsk näitab ainult neid seadeid, mis erinevad vaikeväärtustest, ja seda, kust need tulid:

```bash
ansible-config dump --only-changed
```

??? success "Oodatav tulemus"

    ```
    CONFIG_FILE() = /home/kasutaja/kursus/k01/ansible.cfg
    DEFAULT_HOST_LIST(/home/kasutaja/kursus/k01/ansible.cfg) = ['/home/kasutaja/kursus/k01/inventory.ini']
    ```

Inventory võib olla ka YAML-is. Väikese masinahulga puhul on INI loetavam, aga suurema ja automaatselt genereeritud inventory puhul kasutatakse sageli YAML-i. Ansible teisendab sinu inventory ise YAML-iks:

```bash
ansible-inventory --list --yaml
```

Loo samasse kausta fail `inventory.yml` sama sisuga, ilma tühjade gruppideta:

```yaml
ubuntu:
  hosts:
    web01:
    app01:
    rmq01:
alma:
  hosts:
    mc01:
    db01:
all:
  vars:
    ansible_user: kasutaja
```

Grupi all on võti `hosts` ja masina nime järel koolon, sest YAML-is on iga masin sõnastiku võti. Muutujad on võtme `vars` all. Võti `-i` valib inventory käsu jaoks, `ansible.cfg` seadet see ei muuda.

**Ennusta:** kas YAML-inventory annab sama puu?

```bash
ansible-inventory -i inventory.yml --graph
```

??? success "Oodatav tulemus"

    Sama puu nagu `inventory.ini` puhul. Edasi kasutad `inventory.ini`-d, sest see on failis `ansible.cfg`.

## A3 · Käsud kõigis masinates korraga

Ad-hoc käsk käivitab ühe Ansible'i **mooduli** kohe, ilma playbook'ita: `ansible <masinad või grupp> -m <moodul> -a "<parameetrid>"`. Esimene kontroll on moodul [`ansible.builtin.ping`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/ping_module.html). See ei saada võrgupaketti nagu käsk `ping`, vaid kontrollib, kas Ansible saab masinasse SSH kaudu sisse ja seal töötab Python:

```bash
ansible all -m ansible.builtin.ping
```

??? success "Oodatav tulemus"

    Kõik viis masinat vastavad `SUCCESS` ja `"ping": "pong"`.

Kui ühendus töötab, saad käivitada mis tahes käsu mitmes masinas korraga. Moodul [`ansible.builtin.command`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/command_module.html) käivitab käsu, mille annad võtmega `-a`. Esimene käsk käib kõigis masinates, teine ainult grupis `alma`:

```bash
ansible all -m ansible.builtin.command -a uptime
ansible alma -m ansible.builtin.command -a "df -h /"
```

Mitu korda oleksid pidanud käsitsi `ssh`-ga sisse logima, et sama tulemus saada?

Ansible kogub masinatest ka **fakte**: operatsioonisüsteemi, versiooni, mälu ja võrgu andmeid. Neid näitab moodul [`ansible.builtin.setup`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/setup_module.html). Parameeter `filter` jätab alles ainult need faktid, mille nimi sobib mustriga:

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

??? success "Oodatav tulemus"

    Masinates web01, app01 ja rmq01 on `"ansible_distribution": "Ubuntu"`, masinates mc01 ja db01 `"AlmaLinux"`. 5. osas kasutad neid fakte tingimustes.

## A4 · Paigalda pakett kõigisse masinatesse

Paketi paigaldamiseks on vaja administraatori õigusi. Võti `--become` (`-b`) käivitab mooduli `sudo` kaudu. Laboris `sudo` parooli ei küsi, töökohas lisatakse käsule `-K`.

Moodul [`ansible.builtin.package`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/package_module.html) paigaldab paketi selle distributsiooni paketihalduriga: Ubuntus `apt`, AlmaLinuxis `dnf`. Parameeter `name` on paketi nimi ja `state=present` tähendab, et pakett peab olemas olema. Paigalda kõigisse masinatesse tööriist `tree`:

```bash
ansible all -m ansible.builtin.package -a "name=tree state=present" -b
```

??? success "Oodatav tulemus"

    Kõigi viie masina olek on `CHANGED`.

**Ennusta:** mida näitab sama käsk teisel käivitusel? Käivita see uuesti.

??? success "Oodatav tulemus"

    Kõik viis masinat vastavad `SUCCESS` ja `"changed": false`. Pakett oli juba olemas, seega Ansible midagi ei muutnud. Erinevalt skriptist kontrollib moodul enne, kas muudatus on vajalik.

Kõigi moodulite parameetrid ja näited on käsureal olemas. Vaata, milliseid väärtusi saab parameetril `state` olla:

```bash
ansible-doc ansible.builtin.package
```

Parameetrid on osas `OPTIONS`, näited osas `EXAMPLES`. Väljumiseks vajuta `q`. Sama käsuga leiad iga mooduli kirjelduse, kui playbook'is on midagi arusaamatut.

**Valmis, kui** kõik viis masinat vastavad `pong` ja paketi `tree` teine paigaldus annab kõikjal `changed: false`.

??? info "Loe juurde"

    - [Introduction to ad hoc commands](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)
    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
