---
tags:
  - Ansible
  - Praktikum
---

# 3. Ansible'i alused

!!! abstract "Eesmärgid"

    - paigaldad Ansible'i control node'ile;
    - kirjutad `ansible.cfg` ja inventory kõigi viie masinaga;
    - käivitad ad-hoc käske, ka administraatori õigustega.

Kõik käsud käivad control node'il kaustas `~/kursus/k01`.

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

    Esimene rida on kujul `ansible [core 2.x.y]`. Rida `config file = None`: seadistusfaili veel pole.

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

Nimed `web01` jne töötavad ilma IP-deta, sest [1. Keskkonna](lab-1-keskkond.md) skript kirjutas need faili `~/.ssh/config`. Grupid `ubuntu` ja `alma` lubavad hiljem käivitada töö ühe distro masinatel.

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

    Viis plokki `SUCCESS` ja `"ping": "pong"`. Ansible jõudis SSH-ga igasse masinasse ja seal töötab Python.

Käsk kõigis masinates korraga ja ainult ühes grupis:

```bash
ansible all -m ansible.builtin.command -a uptime
ansible alma -m ansible.builtin.command -a "df -h /"
```

Faktid: mis OS igas masinas on?

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

??? success "Oodatav tulemus"

    web01, app01, rmq01: `"ansible_distribution": "Ubuntu"`. mc01, db01: `"AlmaLinux"`. Neid fakte kasutad lehel 5, et teha Ubuntul ja AlmaLinuxil õiget asja.

??? question "Mõtle"

    Mitu korda oleksid pidanud käsitsi `ssh`-ga sisse logima, et `uptime` igast masinast kätte saada?

## A4 · Ad-hoc käsk õigustega

Paigalda kõigisse masinatesse tööriist `tree`. Paketi paigaldamiseks on vaja administraatori õigusi: `--become` (`-b`) tõstab need `sudo` kaudu ja `-K` küsib `sudo` parooli üks kord.

```bash
ansible all -m ansible.builtin.package -a "name=tree state=present" -b -K
```

??? success "Oodatav tulemus"

    `BECOME password:` küsib parooli. Seejärel viis plokki `CHANGED`: Ubuntul paigaldas `apt`, AlmaLinuxil `dnf`. Moodul `package` valis paketihalduri ise.

Käivita sama käsk uuesti.

??? success "Oodatav tulemus"

    Kõik viis `SUCCESS` ja `"changed": false`: `tree` oli juba olemas, midagi ei tehtud.

??? warning "Parool küsitakse, aga tuleb viga"

    `-K` küsib ühe parooli kõigi masinate jaoks. Kui mõnes masinas on teine parool, tuleb seal `Incorrect sudo password`. Kõigis labori masinates on alguses sama parool.

**Valmis, kui** `ansible all -m ansible.builtin.ping` annab viis `pong`-i ja teine `tree` paigaldus annab kõikjal `changed: false`.

??? info "Loe juurde"

    - [Introduction to ad hoc commands](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)
    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
    - [Configuring Ansible](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_configuration.html)
