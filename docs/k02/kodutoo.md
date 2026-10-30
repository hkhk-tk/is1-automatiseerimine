---
tags:
  - Ansible
  - Kodutöö
---

# 2. kohtumine · Kodutöö

Kodutöös muudad töötava süsteemi seadeid ja näed, kuidas mallid ja handler'id viivad muudatuse õigetesse masinatesse. Kõik käsud käivitad control node'is kaustas `~/kursus/k02-ansible`. Tee kodutöö harus `main` pärast praktikumi ühendamist või uues harus.

## H1 · Suurem vahemälu

Memcachedi mälu on rolli vaikeväärtuses 64 MB. Suurenda seda ainult masinas mc01: loo fail `host_vars/mc01.yml` ja pane sinna `memcached_mem_mb: 128`.

**Ennusta:** millised ülesanded on `changed` ja kas Memcached taaskäivitatakse?

```bash
ansible-playbook site.yml --check --diff --limit mc01
ansible-playbook site.yml --limit mc01
ssh mc01 cat /etc/sysconfig/memcached
```

??? success "Oodatav tulemus"

    `--diff` näitab rida `CACHESIZE`. Käivitamisel muutub mall ja väljundis on `RUNNING HANDLER [memcached : Restart memcached]`. Failis on `CACHESIZE="128"`.

Tee muudatustest commit ja saada need GitHubi.

## H2 · Rakenduse mälu

Muuda failis `group_vars/app.yml` väärtus `tomcat_heap: 384m`. Käivita playbook ainult rakendusserveris ja kontrolli, et rakendus töötab pärast taaskäivitust:

```bash
ansible-playbook site.yml --limit app01
ssh app01 "ps -o args= -C java | grep -o 'Xmx[0-9a-z]*'"
curl -s http://<web01 IP-aadress>/health
```

??? success "Oodatav tulemus"

    Muutub teenuse lisaseadete fail, handler taaskäivitab Tomcati ja `ps` näitab `Xmx384m`. `/health` vastab `UP`.

Tee muudatustest commit ja saada need GitHubi.

## H3 · Uus andmebaasi parool

Paroolivahetus puudutab kahte masinat: andmebaasi kasutajat db01-s ja rakenduse seadeid app01-s. Vaheta Vaultis väärtus `vault_db_password`:

```bash
ansible-vault edit group_vars/all/vault.yml
```

**Ennusta:** millistes masinates on käivitusel muudatusi?

```bash
ansible-playbook site.yml
curl -s http://<web01 IP-aadress>/health
```

??? success "Oodatav tulemus"

    db01-s muutub kasutaja parool ja app01-s rakenduse seadete fail, mille järel Tomcat taaskäivitatakse. Teistes masinates on `changed=0`. `/health` vastab `UP`, sest mõlemad pooled said sama parooli.

Tee muudatustest commit ja saada need GitHubi. `vault.yml` on GitHubis endiselt krüpteeritud.

## H4 · Boonus: ajavöönd kõigis masinates

Lisa `requirements.yml`-i kogu `community.general` (koos versiooniga) ja rolli `common` ülesanne, mis määrab kõigis masinates ajavööndiks `Europe/Tallinn`. Sobiva mooduli leiad käsuga `ansible-doc -l community.general | grep -i timezone`.

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml
ansible all -m ansible.builtin.command -a "timedatectl show -p Timezone"
```

??? success "Oodatav tulemus"

    Kõigis viies masinas on `Timezone=Europe/Tallinn` ja teine käivitus annab `changed=0`.

Tee muudatustest commit ja saada need GitHubi.

Vajad abi? Kirjuta [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehele ning lisa käsk ja kogu veateade tekstina.
