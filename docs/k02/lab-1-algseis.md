---
tags:
  - Ansible
  - Praktikum
---

# 1. Algseis

!!! abstract "Eesmärgid"

    - teed 2. kohtumise projekti 1. kohtumise failide põhjal;
    - lisad grupid masinate ülesande järgi;
    - paned väärtused `group_vars`-i ja `host_vars`-i ning näed, kumb võidab.

Kõik käsud käivad control node'il.

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

    Viis plokki `SUCCESS` ja `"ping": "pong"`. Keskkond töötab samamoodi nagu 1. kohtumise lõpus.

## A2 · Grupid ülesande järgi

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

    web01 on nii grupis `ubuntu` kui ka `veeb`, db01 grupis `rocky` ja `andmebaas`.

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

    `kursus` on kõigil viiel `IS1-26`. `veeb_pealkiri` on web01-l ja app01-l `IS1 labor`, teistel `VARIABLE IS NOT DEFINED!`: need pole grupis `veeb`.

## A4 · Üks masin teistest erinev

Fail `host_vars/web01.yml`:

```yaml
veeb_pealkiri: "IS1 labor · peamine veebiserver"
```

Ennusta enne: mis on web01 ja app01 `veeb_pealkiri`?

```bash
ansible veeb -m ansible.builtin.debug -a "var=veeb_pealkiri"
```

??? success "Oodatav tulemus"

    web01: `IS1 labor · peamine veebiserver`, app01: `IS1 labor`. `host_vars` on täpsem kui `group_vars` ja võidab.

Proovi ühekordset üle kirjutamist käsurealt:

```bash
ansible veeb -m ansible.builtin.debug -a "var=veeb_pealkiri" -e veeb_pealkiri=Proov
```

??? success "Oodatav tulemus"

    Mõlemal `Proov`: `-e` on kõige tugevam.

## A5 · Commit

```bash
cd ~/kursus
git add k02
git commit -m "k02: algseis, grupid ja muutujad"
git push
```

**Valmis, kui** web01 ja app01 näitavad eri `veeb_pealkiri` väärtust ja muudatus on GitHubis.
