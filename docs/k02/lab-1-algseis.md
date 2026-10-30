---
tags:
  - Ansible
  - Praktikum
---

# 1. Algseis

!!! abstract "Eesmärgid"

    - lood 2. kohtumise projekti 1. kohtumise failide põhjal;
    - lisad grupid masinate otstarbe järgi;
    - paned väärtused `group_vars`-i ja `host_vars`-i ning uurid, kumb väärtus jääb kehtima.

Kõik käsud käivita control node'is.

## A1 · Projekt

```bash
cd ~/kursus
git pull
mkdir -p k02
cp k01/ansible.cfg k01/inventory.ini k02/
cd k02
ansible all -m ansible.builtin.ping
```

??? success "Oodatav tulemus"

    Väljundis on viis plokki `SUCCESS` ja `"ping": "pong"`. Keskkond töötab samamoodi nagu 1. kohtumise lõpus.

## A2 · Grupid masinate otstarbe järgi

Lisa `inventory.ini` lõppu (enne `[all:vars]`) kaks gruppi:

```ini
[veeb]
web01
app01

[andmebaas]
db01
```

```bash
ansible-inventory --graph
```

??? success "Oodatav tulemus"

    web01 on nii grupis `ubuntu` kui ka `veeb` ning db01 on grupis `alma` ja `andmebaas`.

## A3 · Muutujad gruppidele

```bash
mkdir -p group_vars host_vars
```

Fail `group_vars/all.yml`:

```yaml
kursus: IS1-26
labori_kasutajad:
  - anna
  - peeter
  - mari
```

Fail `group_vars/veeb.yml`:

```yaml
veeb_pealkiri: "IS1 labor"
veeb_port: 80
```

Kontrolli, millised väärtused Ansible igale masinale annab:

```bash
ansible all -m ansible.builtin.debug -a "var=kursus"
ansible all -m ansible.builtin.debug -a "var=veeb_pealkiri"
```

??? success "Oodatav tulemus"

    Muutuja `kursus` väärtus on kõigis viies masinas `IS1-26`. Muutuja `veeb_pealkiri` väärtus on web01-s ja app01-s `IS1 labor`, teistes masinates `VARIABLE IS NOT DEFINED!`, sest need ei kuulu gruppi `veeb`.

## A4 · Üks masin teistest erinev

Fail `host_vars/web01.yml`:

```yaml
veeb_pealkiri: "IS1 labor · peamine veebiserver"
```

Enne käivitamist ennusta, milline on muutuja `veeb_pealkiri` väärtus web01-s ja app01-s.

```bash
ansible veeb -m ansible.builtin.debug -a "var=veeb_pealkiri"
```

??? success "Oodatav tulemus"

    web01-s on väärtus `IS1 labor · peamine veebiserver`, app01-s `IS1 labor`. `host_vars` on täpsem kui `group_vars`, seetõttu jääb kehtima masina enda väärtus.

Proovi väärtus käsurealt ühekordselt üle kirjutada:

```bash
ansible veeb -m ansible.builtin.debug -a "var=veeb_pealkiri" -e veeb_pealkiri=Proov
```

??? success "Oodatav tulemus"

    Mõlemas masinas on väärtus `Proov`, sest käsurealt võtmega `-e` antud väärtusel on kõige kõrgem prioriteet.

## A5 · Commit

```bash
cd ~/kursus
git add k02
git commit -m "k02: algseis, grupid ja muutujad"
git push
```

**Valmis, kui** web01-s ja app01-s on muutujal `veeb_pealkiri` eri väärtus ja muudatus on GitHubis.
