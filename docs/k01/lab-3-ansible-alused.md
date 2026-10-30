---
tags:
  - Ansible
  - Praktikum
---

# 3. Ansible'i alused

!!! abstract "Eesmärgid"

    - paigaldad Ansible'i control node'ile;
    - kirjutad `ansible.cfg` ja inventory kõigi viie masinaga;
    - käivitad ad-hoc käske tavakasutaja ja administraatori õigustega.

Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

## A1 · Paigalda Ansible

=== "Ubuntu"

    ```bash
    sudo apt update
    sudo apt install -y ansible-core
    ```

=== "AlmaLinux"

    ```bash
    sudo dnf install -y ansible-core
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

Masinate nimed (`web01` jne) töötavad ilma IP-aadressideta, sest [1. osa](lab-1-keskkond.md) skript lisas need SSH konfiguratsioonifaili `~/.ssh/config`. Gruppide `ubuntu` ja `alma` abil saad hiljem käivitada ülesandeid ainult ühe distributsiooni masinates.

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

Paigalda kõigisse masinatesse tööriist `tree`. Paketi paigaldamiseks on vaja administraatori õigusi. Võti `--become` (`-b`) käivitab ülesande kõrgemate õigustega. Meie laboris kasutatakse selleks `sudo`-t.

```bash
ansible all -m ansible.builtin.package -a "name=tree state=present" -b
```

??? success "Oodatav tulemus"

    Kõigi viie masina olek on `CHANGED`. Ubuntus paigaldas paketi `apt`, AlmaLinuxis `dnf`. Moodul `package` valis paketihalduri ise.

Käivita sama käsk uuesti.

??? success "Oodatav tulemus"

    Kõik viis masinat vastavad `SUCCESS` ja `"changed": false`. Pakett `tree` oli juba paigaldatud, seega Ansible midagi ei muutnud.

!!! info "Laboris `sudo` parooli ei küsi"

    Labori masinates on `sudo` seadistatud parooli küsimata. Töökohas küsib `sudo` tavaliselt parooli. Sel juhul lisa käsule `-K` (`--ask-become-pass`): Ansible küsib parooli üks kord ja kasutab seda kõigis masinates. Kui vastuseks tuleb `Missing sudo password`, on just see põhjus.

**Valmis, kui** käsu `ansible all -m ansible.builtin.ping` peale vastavad kõik viis masinat `pong` ja paketi `tree` teine paigaldus annab kõikjal `changed: false`.

??? info "Loe juurde"

    - [Introduction to ad hoc commands](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)
    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
    - [Configuring Ansible](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_configuration.html)
