---
tags:
  - Ansible
  - Info
---

# 02 · Labori seis viies masinas

Sel kohtumisel paigaldad Ansible'iga kogu Labori seisu: andmebaas, vahemälu, sõnumijärjekord, rakendus ja veebiserver viies masinas. Iga teenuse jaoks kirjutad oma rolli ja päeva lõpus seadistab üks käsk kogu süsteemi.

[Lugemismaterjal](loeng.md){ .md-button } [Praktikum](lab.md){ .md-button .md-button--primary } [Kodutöö](kodutoo.md){ .md-button }

## Mida täna õpid

Päeva lõpuks oskad:

- kirjeldada inventory's masinad teenuse ja distributsiooni gruppidena ning otsustada, kas väärtus kuulub rolli vaikeväärtustesse, grupile või ühele masinale;
- teha Jinja2 mallist igale masinale oma konfiguratsioonifaili ja taaskäivitada teenust handler'iga ainult muudatuse korral;
- paigaldada Ansible'i kogusid ja hoida paroole Vaultis;
- jagada projekti rollideks, kirjutada rolli ise nõuete järgi ja käivitada rollid ühest `site.yml`-ist;
- kontrollida muudatust enne rakendamist ja rakendada seda masinate kaupa.

## Päeva käik

| | Osa |
|---|---|
| 1 | Loeng: grupid, muutujad, mallid, handler'id ja rollid |
| 2 | [Projekt ja inventory](lab-1-projekt.md) |
| 3 | [Esimene roll](lab-2-common.md): `common` |
| 4 | Loeng: kogud ja Vault |
| 5 | [Andmebaas](lab-3-andmebaas.md): MariaDB |
| 6 | [Vahemälu ja järjekord](lab-4-vahemalu-jarjekord.md): Memcachedi roll ise, RabbitMQ |
| 7 | [Rakendus ja veebiserver](lab-5-rakendus.md): Tomcat, Nginxi roll ise |
| 8 | [Korduv käivitus ja esitamine](lab-6-esitamine.md) |

*Tabel 1. Päeva tegevused.*

## Mida päeva lõpuks esitad

Kaustas `k02-ansible/` on projekt, mis paigaldab Labori seisu, ja fail `run2.txt` teise käivituse väljundiga. Töö jõuab harusse `main` pull request'iga ja esitatakse tag'iga `k02`. Automaatne hindaja kontrollib tag'iga märgitud versiooni, tulemus on Classroom 50-s. Vaulti parool ei ole Gitis.

## Abi

[Abi](abi.md) · [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions)
