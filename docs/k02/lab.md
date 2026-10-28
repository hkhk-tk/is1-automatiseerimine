---
tags:
  - Ansible
  - Vault
  - rollid
---

# 2. kohtumine, labor: Labori seis Ansible'i rollidega

!!! info "Selle korra töö"
    - **Masin:** control node (tsüklite ja TLS-i lehel ka Docker ja teegid `cryptography`, `docker` Ansible'i pipx venv'is), repo `~/labori-seis`, töökaust `k02-ansible/`, märkmed `k02-ansible/README.md`
    - **Sihtmasinad:** web01, app01, rmq01 (Ubuntu 24.04), mc01, db01 (Rocky 9), kasutaja `kasutaja`, VPN
    - **Esitamine:** haru `k02-ansible` → PR → merge → tag `k02`
    - **Eelmisest korrast vaja:** `k02-ansible/` kolm faili (`ansible.cfg`, `inventory.ini`, `web.yml`), snapshot `enne-stack` viiel VM-il, `k01-bash/services/*.sh` (spetsifikatsioon), `k01-bash/check.sh`, `LABSEIS_TOKEN`; tahvlilt `TEMPLATE_URL`, `TEMPLATE_URL_2` ja uue rakenduse versiooni tag
    - **Testitud:** Ubuntu 24.04, Rocky 9, ansible-core 2.21, ansible-lint 26.9, `ansible.mariadb` 6.x, `community.rabbitmq` 1.7, `ansible.posix` 2.2, `community.crypto` 3.x, Tomcat 10.1 + OpenJDK 21, `community.general` ja `community.docker` `requirements.yml` vahemikus, `community.proxmox` ja Molecule paigaldamise hetke viimane versioon, MariaDB, Memcached, RabbitMQ ja Nginx distributsiooni paketist, Proxmox VE kursuse keskkonna versioon
    - **Dokumentatsioon:** [Ansible](https://docs.ansible.com/ansible/latest/) · [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) · [ansible-lint](https://ansible.readthedocs.io/projects/lint/) · [Molecule](https://ansible.readthedocs.io/projects/molecule/)

Kohtumise lõpuks tõuseb Labori seis viiel VM-il ühe käsuga `ansible-playbook site.yml` ja teine käivitus annab igal hostil `changed=0`. Kood on kuueks rolliks jagatud, saladused on Vaultis, web01 vastab HTTPS-il labori oma CA serdiga, ansible-lint on puhas ja `verify.yml` kontrollib stacki, serti ja RabbitMQ API-t sealt, kust neid kasutatakse. `deploy.yml` vahetab rakenduse versiooni üks host korraga ja läheb vea korral ise eelmisele versioonile tagasi.

Iga moodul lõpeb commit'iga. Kui moodulil on GitHubis issue (milestone `K2`), lisa sõnumisse `closes #N`.

## Mis on kohustuslik

| Osa | Mis | Millal |
|---|---|---|
| Kohtumise ajal | [Algseis](lab-1-lahteseis.md), [Andmebaas ühe playbook'iga](lab-2-andmebaas.md), [Rollid ja muutujad](lab-3-rollid.md), [Kogu stack](lab-4-stack.md), [Kontroll enne muudatust](lab-5-kontroll.md) | laboris 11:30–15:00 |
| Võib lõpetada pärast kohtumist | [Deploy ja rolling](lab-6-deploy.md), [Tsüklid, mallid ja TLS](lab-7-tsuklid-tls.md), [Intsident](lab-8-intsident.md); README täiendused; [Esitamise](lab-9-esitamine.md) kontrollid uuesti pärast viimast commit'i | enne 3. kohtumise, mis eeldab tag'i `k02` `main`-is; automaatse hindaja syntax-check vajab `deploy.yml`-i lehelt Deploy ja rolling |
| Hindamise eeltingimus | tag `k02` `main`-i commit'il pärast merge'i ja GitHubis näha (`git ls-remote --tags origin`); `run2.txt` on repos ja automaatse hindaja seitse kontrolli on ka värskes kloonis `OK` ([Esitamine](lab-9-esitamine.md)) | esimene tag kohtumise lõpus; hilisem töö uue commit'iga ja `git tag -f k02` |

## Moodulid

1. [Algseis](lab-1-lahteseis.md): VM-id `enne-stack` seisus, `ansible.cfg` tootmise seadetega, üks host maas, inventory puu ja muutujad.
2. [Andmebaas ühe playbook'iga](lab-2-andmebaas.md): `db.yml` MariaDB-ga, parool kohe Vaultis, import ainult tühja baasi korral, andmed pole soovitud seis.
3. [Rollid ja muutujad](lab-3-rollid.md): `site.yml` rollidega, hallatud plokk, muutujad oma tasemel, prioriteet tõestatud, Memcached ja valvekasutajad.
4. [Kogu stack](lab-4-stack.md): RabbitMQ, Tomcat ja Nginx rollidena, mallid ja handlerid, teenus maas, `/health` → `UP`, snapshot `k02-stack`.
5. [Kontroll enne muudatust](lab-5-kontroll.md): lint puhas, `--check` usaldusväärne, drift leitud, `failed_when` poliitika, `verify.yml`.
6. [Deploy ja rolling](lab-6-deploy.md): `block`/`rescue`/`always` koos rollback'iga, deploy ilma fact'ita, `serial` ja health check pärast deploy'd kahes playbook'is, OS-i paigad ja reboot lainetena.
7. [Tsüklid, mallid ja TLS](lab-7-tsuklid-tls.md): pordid ja paketid muutujast, eelkontroll `any_errors_fatal`-iga, mall `validate`-iga, HTTPS labori CA-ga, import vs include, RabbitMQ API, logid kokku ja esimene konteiner.
8. [Intsident](lab-8-intsident.md): kolleegi hotfix, veaotsingu tabel, iga rike parandatud koodis, regressioonikontroll ja postmortem.
9. [Esitamine](lab-9-esitamine.md): puhas masin, `run2.txt`, kloonist check, sinu töökoha esimene automatiseerimise samm, automaatse hindaja kontrollid, PR, tag `k02`.

Veaotsing: [Abi](abi.md).
