---
tags:
  - Ansible
  - Kodutöö
---

# Kodutöö: muutujad ja paroolid töötavas süsteemis

Kodutöös muudad töötava süsteemi seadeid ja näed, et muutuja uus väärtus jõuab mallide ja handler'ite kaudu ainult nendesse masinatesse, mida see puudutab. Kodutöö on boonus. Käsud käivitad control node'is kaustas `~/kursus/k02-ansible` harus `main`, pärast seda, kui praktikumi pull request on ühendatud.

## Osa 1 · Suurem vahemälu

Memcachedi mälu on rolli vaikeväärtuses 64 MB. Suurenda seda ainult masinas mc01: loo fail `host_vars/mc01.yml` ja pane sinna `memcached_mem_mb: 128`.

**Ennusta:** millised ülesanded on `changed` ja kas Memcached taaskäivitatakse?

```bash
ansible-playbook site.yml --check --diff --limit mc01
ansible-playbook site.yml --limit mc01
ssh mc01 cat /etc/sysconfig/memcached
```

??? success "Oodatav tulemus"

    `--diff` näitab rida `CACHESIZE`. Käivitamisel muutub mall ja väljundis on `RUNNING HANDLER [memcached : Restart memcached]`. Failis on `CACHESIZE="128"`.

## Osa 2 · Rakenduse mälu

Muuda failis `group_vars/app.yml` väärtus `tomcat_heap: 384m`. Käivita playbook ainult rakendusserveris ja kontrolli, et rakendus töötab pärast taaskäivitust:

```bash
ansible-playbook site.yml --limit app01
ssh app01 "ps -o args= -C java | grep -o 'Xmx[0-9a-z]*'"
ssh web01 curl -s localhost/health
```

??? success "Oodatav tulemus"

    Muutub teenuse lisaseadete fail, handler taaskäivitab Tomcati ja `ps` näitab `Xmx384m`. `/health` vastab `UP`.

## Osa 3 · Uus andmebaasi parool

Paroolivahetus puudutab kahte masinat: andmebaasi kasutajat db01-s ja rakenduse seadeid app01-s. Vaheta Vaultis väärtus `vault_db_password`:

```bash
ansible-vault edit group_vars/all/vault.yml
```

**Ennusta:** millistes masinates on käivitusel muudatusi?

```bash
ansible-playbook site.yml
ssh web01 curl -s localhost/health
```

??? success "Oodatav tulemus"

    db01-s muutub kasutaja parool ja app01-s rakenduse seadete fail, mille järel Tomcat taaskäivitatakse. Teistes masinates on `changed=0`. `/health` vastab `UP`, sest mõlemad pooled said sama parooli. `vault.yml` jääb GitHubis krüpteerituks.

## Osa 4 · Ajavöönd kõigis masinates

Lisa `requirements.yml`-i kogu `community.general` koos versiooniga ja rolli `common` ülesanne, mis määrab kõigis masinates ajavööndiks `Europe/Tallinn`. Sobiva mooduli leiad käsuga `ansible-doc -l community.general | grep -i timezone`.

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml
ansible all -m ansible.builtin.command -a "timedatectl show -p Timezone"
```

??? success "Oodatav tulemus"

    Kõigis viies masinas on `Timezone=Europe/Tallinn` ja teine käivitus annab `changed=0`.

## Töö esitamine

Kodutöö esitatakse sama tag'iga `k02`: tee muudatustest commit, saada need GitHubi ja liiguta tag viimasele commit'ile.

```bash
cd ~/kursus
git add -A k02-ansible && git commit -m "k02: kodutöö" && git push
git tag -f k02 && git push -f origin k02
```

Tulemuse näed Classroom 50-s.
