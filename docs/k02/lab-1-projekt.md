---
tags:
  - Ansible
  - Praktikum
---

# 1. Projekt ja inventory

1. kohtumisel oli inventory's kaks gruppi distributsiooni järgi. Labori seisus on igal masinal oma ülesanne, seega lisandub grupp iga teenuse kohta ja distributsioonigrupid koostatakse teenusegruppidest. Selles osas lood projekti kausta, kirjeldad masinad gruppidena ja paned paika muutujad.

!!! abstract "Dokumentatsioonis"

    [Building an inventory: metagroups](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_inventory.html) · [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)

## A1 · Uus haru ja kaust

Alates 2. kohtumisest teed iga kohtumise töö eraldi harus ja ühendad selle päeva lõpus pull request'iga harusse `main`. Nii on `main`-is alati ainult valmis ja kontrollitud töö.

```bash
cd ~/kursus
git switch main
git pull
git switch -c k02-ansible
mkdir -p k02-ansible
cd k02-ansible
```

Kõik selle kohtumise käsud käivitad kaustas `~/kursus/k02-ansible`.

## A2 · `ansible.cfg` ja inventory

Fail `ansible.cfg` on sama mis 1. kohtumisel, lisandub kaust, kust Ansible rolle otsib. Loo fail `ansible.cfg`:

```ini
[defaults]
inventory = inventory.ini
roles_path = roles
interpreter_python = auto_silent
```

Rida `interpreter_python = auto_silent` jätab ära hoiatuse, mille Ansible annab, kui leiab masinast Pythoni ise.

Inventory's on grupp iga teenuse kohta: `web`, `app`, `queue`, `cache` ja `db`. Distributsiooni grupid `ubuntu` ja `alma` koosnevad nüüd teistest gruppidest. Seda tähendab järelliide `:children`. Asenda `<web01-IP>` jt oma masinate aadressidega (Proxmox, Summary → IPs või 1. kohtumise fail `~/.ssh/config`):

```ini
[web]
web01 ansible_host=<web01-IP>

[app]
app01 ansible_host=<app01-IP>

[queue]
rmq01 ansible_host=<rmq01-IP>

[cache]
mc01 ansible_host=<mc01-IP>

[db]
db01 ansible_host=<db01-IP>

[ubuntu:children]
web
app
queue

[alma:children]
cache
db

[all:vars]
ansible_user=kasutaja
```

![Inventory: grupid teenuse ja distributsiooni järgi](assets/k02_inventory.svg){ width="720" }

*Joonis 2. Iga masin on kahes grupis: teenuse grupis ja distributsiooni grupis.*

Muutuja `ansible_host` on masina IP-aadress. SSH leiaks masinad ka nime järgi, aga IP-aadressi vajad 2. osas, kui masinad peavad üksteist tundma.

**Ennusta:** millised masinad on grupis `ubuntu`?

```bash
ansible-inventory --graph
ansible all -m ansible.builtin.ping
```

??? success "Oodatav tulemus"

    Grupi `ubuntu` all on grupid `web`, `app` ja `queue` ning nende kaudu masinad web01, app01 ja rmq01. Kõik viis masinat vastavad `pong`.

## A3 · Muutujad

Grupimuutujad on sulle tuttavad 1. kohtumisest. Kaks uut asja: kõigi masinate muutujad on nüüd kaustas `group_vars/all/`, sest 3. osas lisandub sinna krüpteeritud fail, ja ühe masina muutujad on kaustas `host_vars`. Kui sama muutuja on mitmes kohas, kehtib täpsem: masina väärtus enne grupi oma.

```bash
mkdir -p group_vars/all host_vars
```

Fail `group_vars/all/main.yml` (paroolid lisanduvad 3. osas):

```yaml
labseis_db_name: labseis
labseis_db_user: labseis
labseis_mq_user: labseis
```

Fail `group_vars/app.yml`:

```yaml
# Rakendusserveri JVM-i mälu (app01-l on 1 GB RAM-i)
tomcat_heap: 512m
```

Fail `host_vars/web01.yml`:

```yaml
# web01 suunab päringud rakendusserverisse
nginx_upstream: app01:8080
```

**Ennusta:** mida näitab muutuja `tomcat_heap` masinas app01 ja mida web01-s?

```bash
ansible app01,web01 -m ansible.builtin.debug -a "var=tomcat_heap"
```

??? success "Oodatav tulemus"

    app01-s on väärtus `512m`, web01-s `VARIABLE IS NOT DEFINED!`, sest web01 ei ole grupis `app`.

## A4 · Commit

Salvesta projekt repositooriumi ja saada haru GitHubi:

```bash
cd ~/kursus
git add k02-ansible
git commit -m "k02: inventory ja muutujad"
git push -u origin k02-ansible
```

**Valmis, kui** kõik viis masinat vastavad `pong` ja muutuja `tomcat_heap` on ainult app01-s.

??? info "Loe juurde"

    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
    - [Variable precedence](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence)
