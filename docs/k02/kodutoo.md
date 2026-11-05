---
tags:
  - Ansible
  - Kodutöö
---

# Kodutöö: muutujad ja paroolid töötavas süsteemis

Kodutöös muudad töötavat Labori seisu ja kontrollid, kuhu muudatus jõuab. Kolm esimest osa muudavad muutujat kolmel tasemel. Faili asukoht määrab, millistele masinatele muutuja on kättesaadav. Masin muutub aga ainult siis, kui mõni selle masina ülesanne seda väärtust kasutab. Kodutöö on boonus.

??? note "Tabel 2.9. Muudatuse ulatus"

    | Osa | Muutuja asukoht | Kättesaadav | Mida uurid |
    |---|---|---|---|
    | 1 | `host_vars/mc01.yml` | ainult mc01 | ühe masina seadistus |
    | 2 | `group_vars/app.yml` | grupp `app` | teenusegrupi seadistus |
    | 3 | `group_vars/all/vault.yml` | kõik viis masinat | ühine väärtus, mida kasutavad kaks teenust |

Kodutöö tehakse harus `main` pärast seda, kui praktikumi pull request on ühendatud. Väikese muudatuse puhul jätame haru ja pull request'i selles kursuses vahele. Käsud käivitad control node'is kaustas `~/kursus/k02-ansible`.

Iga osa ennustus ja tulemus lähevad faili `README.md` samas kaustas (tabel töö esitamise juures). Ära kirjuta README-sse, logidesse ega ekraanipiltidele parooli ega Vaulti avatud sisu.

## Osa 1 · Suurem vahemälu

Memcachedi mälu on rolli vaikeväärtuses 64 MB. Suurenda seda ainult masinas mc01. Fail `host_vars/mc01.yml`:

```yaml
memcached_mem_mb: 128
```

**Ennusta** enne käivitamist ja kirjuta README-sse: muutub fail ____, seda muudab ülesanne ____, handler ____ käivitub või ei käivitu, sest ____.

```bash
ansible-playbook site.yml --check --diff --limit mc01
ansible-playbook site.yml --limit mc01
ansible-playbook site.yml --limit mc01
ssh mc01 grep CACHESIZE /etc/sysconfig/memcached
```

??? success "Oodatav tulemus"

    `--diff` näitab rida `CACHESIZE`. Esimesel käivitusel muutub mall `memcached.j2` põhjal fail `/etc/sysconfig/memcached` ja väljundis on `RUNNING HANDLER [memcached : Restart memcached]`. Teisel käivitusel on `changed=0` ja handler ei käivitu. Failis on `CACHESIZE="128"`.

## Osa 2 · Rakenduse mälu

Muuda failis `group_vars/app.yml` väärtus `tomcat_heap: 384m`. Leia enne käivitamist ise, millise malli kaudu väärtus serverisse jõuab ja millist handler'it see teavitab.

```bash
ansible-playbook site.yml --limit app01
ansible-playbook site.yml --limit app01
ssh app01 "ps -o args= -C java | grep -o 'Xmx[0-9a-z]*'"
ssh web01 curl -fsS localhost/health
```

??? success "Oodatav tulemus"

    Esimesel käivitusel muutub teenuse lisaseadete fail `/etc/systemd/system/tomcat10.service.d/labori-seis.conf` ja handler taaskäivitab Tomcati. Teisel käivitusel on `changed=0`. `ps` näitab `Xmx384m` ja `/health` vastab `{"status":"UP","db":"UP","queue":"UP","cache":"UP"}`.

## Osa 3 · Uus andmebaasi parool

Andmebaasi parooli kasutavad kaks masinat: db01-s andmebaasi kasutaja ja app01-s rakenduse seaded. Muutuja on kättesaadav kõigis viies masinas, aga muutuvad ainult need kaks. Vaheta Vaultis väärtus `vault_db_password`:

```bash
ansible-vault edit group_vars/all/vault.yml
```

Moodul `community.mysql.mysql_user` uuendab olemasoleva kasutaja parooli, kui see erineb, sest parameetri `update_password` vaikeväärtus on `always`. Väärtusega `on_create` määrataks parool ainult kasutaja loomisel ([mysql_user](https://docs.ansible.com/projects/ansible/latest/collections/community/mysql/mysql_user_module.html)).

Paroolivahetus ei toimu mõlemas masinas samal hetkel. `site.yml` seadistab andmebaasi enne rakendusserverit, nii et vahepeal on andmebaasis uus parool ja rakenduse seadetes vana. Rakendus võib selle aja jooksul andmebaasiühenduse loomisel vea saada. Selles praktikumis kontrollime tulemust pärast kogu playbook'i lõppu, katkestuseta paroolivahetus on eraldi teema.

**Ennusta:** millistes masinates on käivitusel muudatusi?

```bash
ansible-playbook site.yml
ssh web01 curl -fsS localhost/health
```

??? success "Oodatav tulemus"

    db01-s muutub kasutaja parool ja app01-s rakenduse seadete fail, mille järel Tomcat taaskäivitatakse. Teistes masinates on `changed=0`. Lõpus vastab `/health` `{"status":"UP","db":"UP","queue":"UP","cache":"UP"}`. `vault.yml` jääb GitHubis krüpteerituks.

??? question "Küsimused"

    1. Miks ei piisa ainult käsust `ansible-playbook site.yml --limit db01`?
    2. Mis jääks valesti, kui playbook katkeks pärast andmebaasi muutmist, aga enne rakendusserveri seadistamist? Kuidas selle parandaksid?

## Osa 4 · Ajavöönd kõigis masinates

Ajavööndi moodul on kogus `community.general`, mida praktikumis ei paigaldatud. Kogu tuleb enne paigaldada, alles siis saab selle mooduleid uurida. Lisa faili `requirements.yml` kogu kontrollitud versiooniga:

```yaml
  - name: community.general
    version: 11.4.1
```

```bash
ansible-galaxy collection install -r requirements.yml
ansible-doc -l community.general | grep -i timezone
ansible-doc community.general.timezone
```

Lisa rolli `common` ülesanne, mis määrab kõigis masinates ajavööndiks `Europe/Tallinn`. Parameetri nime leiad `ansible-doc` väljundist.

??? tip "Vihje"

    ```yaml
    - name: Masina ajavöönd on määratud
      community.general.timezone:
        name: Europe/Tallinn
    ```

```bash
ansible-playbook site.yml
ansible all -m ansible.builtin.command -a "timedatectl show -p Timezone"
```

??? success "Oodatav tulemus"

    Kõigis viies masinas on `Timezone=Europe/Tallinn` ja teine käivitus annab `changed=0`. Kui ajavöönd oli juba `Europe/Tallinn`, võib ülesanne olla kohe `ok`: moodul võrdles soovitud ja tegelikku olekut ning muudatust polnud vaja.

## Töö esitamine

Lisa faili `README.md` tabel ja täida see konkreetse väljundi põhjal, üks-kaks lauset lahtris:

```markdown
| Muudatus | Minu ennustus | Muutunud ülesanded ja handler'id | Kuidas kontrollisin |
|---|---|---|---|
| Memcached 128 MB | | | |
| Tomcat 384m | | | |
| Andmebaasi parool | | | |
| Ajavöönd | | | |
```

Kontrolli kogu projekti ja uuenda `run2.txt`, et see vastaks viimasele seisule:

```bash
ansible-lint
ansible-playbook site.yml | tee run2.txt
ssh web01 curl -fsS localhost/health
```

Selles kursuses tähistab tag `k02` viimast esitatud versiooni. Seepärast liigutad pärast kodutööd sama tag'i uuele commit'ile:

```bash
(cd ~/kursus && git add -A k02-ansible && git commit -m "k02: kodutöö" && git push)
(cd ~/kursus && git tag -f k02 && git push -f origin k02)
```

Tulemuse näed Classroom 50-s.
