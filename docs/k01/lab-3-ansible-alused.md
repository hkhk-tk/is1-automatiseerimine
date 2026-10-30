---
tags:
  - Ansible
  - Praktikum
---

# 3. Ansible'i alused

Paigaldad Ansible'i, kirjeldad inventory's viis masinat ja käivitad käske kõigis masinates korraga. Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

## A1 · Paigalda Ansible

```bash
sudo apt update
sudo apt install -y ansible-core
```

```bash
ansible --version
```

??? success "Oodatav tulemus"

    Esimene rida on kujul `ansible [core 2.x.y]`. Rida `config file = None` näitab, et konfiguratsioonifaili veel ei ole.

## A2 · `ansible.cfg` ja inventory

```bash
cd ~/kursus/k01
```

Loo fail `ansible.cfg`:

```ini
[defaults]
inventory = inventory.ini
```

Loo fail `inventory.ini`:

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

Nimed töötavad ilma IP-aadressideta, sest need on failis `~/.ssh/config`. Gruppide `ubuntu` ja `alma` abil saad käivitada ülesandeid ainult ühe distributsiooni masinates.

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

## A3 · Esimesed ad-hoc käsud

Ad-hoc käsk käivitab ühe mooduli: `ansible <masinad> -m <moodul> -a "<parameetrid>"`. Selles osas kasutad nelja moodulit:

| Moodul | Mida teeb | Parameetrid |
|---|---|---|
| [`ansible.builtin.ping`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/ping_module.html) | kontrollib, kas Ansible saab masinaga ühenduse ja seal töötab Python | puuduvad |
| [`ansible.builtin.command`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/command_module.html) | käivitab masinas ühe käsu | käsk ise, näiteks `-a uptime` |
| [`ansible.builtin.setup`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/setup_module.html) | kogub masina kohta fakte | `filter`: ainult nende faktide nimed, mis sobivad mustriga |
| [`ansible.builtin.package`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/package_module.html) | paigaldab või eemaldab paketi, kasutades distributsiooni paketihaldurit (`apt` või `dnf`) | `name`: paketi nimi, `state: present`: pakett peab olemas olema |

*Tabel 1. Moodulid selles osas.*

Mooduli kirjelduse, kõik parameetrid ja näited näed käsuga `ansible-doc`. Vaata, milliseid väärtusi saab moodulil `package` olla parameetril `state`:

```bash
ansible-doc ansible.builtin.package
```

Parameetrite loend on osas `OPTIONS`, kasutusnäited osas `EXAMPLES`. Väljumiseks vajuta `q`.

```bash
ansible all -m ansible.builtin.ping
```

??? success "Oodatav tulemus"

    Kõik viis masinat vastavad `SUCCESS` ja `"ping": "pong"`. See tähendab, et Ansible sai igasse masinasse SSH kaudu ühenduse ja masinas töötab Python.

Käivita nüüd käsk kõigis masinates ja seejärel ainult grupis `alma`:

```bash
ansible all -m ansible.builtin.command -a uptime
ansible alma -m ansible.builtin.command -a "df -h /"
```

Vaata Ansible'i faktidest, milline operatsioonisüsteem igas masinas töötab:

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

??? success "Oodatav tulemus"

    Masinates web01, app01 ja rmq01 on `"ansible_distribution": "Ubuntu"`, masinates mc01 ja db01 `"AlmaLinux"`. Hiljem kasutad neid fakte tingimustes, et valida Ubuntu ja AlmaLinuxi jaoks sobivad ülesanded.

??? question "Mõtle"

    Mitu korda oleksid pidanud käsitsi `ssh`-ga sisse logima, et `uptime` igast masinast kätte saada?

## A4 · Ad-hoc käsk õigustega

Paigalda kõigisse masinatesse tööriist `tree`. Paketi paigaldamiseks on vaja administraatori õigusi: võti `--become` (`-b`) käivitab ülesande `sudo` kaudu.

```bash
ansible all -m ansible.builtin.package -a "name=tree state=present" -b
```

??? success "Oodatav tulemus"

    Kõigi viie masina olek on `CHANGED`. Ubuntus paigaldas paketi `apt`, AlmaLinuxis `dnf`. Moodul `package` valis paketihalduri ise.

**Ennusta:** mida näitab sama käsk teisel käivitusel? Käivita see uuesti.

??? success "Oodatav tulemus"

    Kõik viis masinat vastavad `SUCCESS` ja `"changed": false`. Pakett `tree` oli juba paigaldatud, seega Ansible midagi ei muutnud.

Laboris `sudo` parooli ei küsi. Kui töökohas küsib, lisa käsule `-K`.

**Valmis, kui** käsule `ansible all -m ansible.builtin.ping` vastavad kõik viis masinat `pong` ja paketi `tree` teine paigaldus annab kõikjal `changed: false`.

??? info "Loe juurde"

    - [Introduction to ad hoc commands](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)
    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
    - [Configuring Ansible](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_configuration.html)
