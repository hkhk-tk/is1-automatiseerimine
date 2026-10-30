---
tags:
  - Ansible
  - Info
---

# 02 · Ansible mitmele masinale

Sel kohtumisel kasvab ühest playbook'ist terve projekt: lisanduvad muutujad, mallid, handler'id ja rollid. Päeva lõpuks seadistab üks käsk kasutajad kõigis masinates, veebiserveri kahes masinas ja andmebaasi ühes masinas.

[Lugemismaterjal](loeng.md){ .md-button } [Praktikum](lab.md){ .md-button .md-button--primary } [Kodutöö](kodutoo.md){ .md-button }

## Mida täna õpid

Päeva lõpuks oskad:

- hoida väärtusi muutujates grupi ja masina kaupa;
- korrata ülesannet `loop`-iga ja taaskäivitada teenust handler'iga;
- teha Jinja2 malliga igale masinale oma konfiguratsioonifail;
- paigaldada Ansible'i kogu (collection) ja hoida parooli Vaultis;
- jagada projekti rollideks ja rakendada muudatust masinhaaval.

## Päeva käik

| | Osa |
|---|---|
| 1 | Loeng: muutujad, tsüklid, handler'id ja mallid |
| 2 | [Algseis](lab-1-algseis.md): projekt, grupid ja muutujad |
| 3 | [Kasutajad](lab-2-kasutajad.md): `loop` ja `register` |
| 4 | [Veebiserver](lab-3-veebiserver.md): mall ja handler |
| 5 | Loeng: rollid, kogud ja Vault |
| 6 | [Andmebaas](lab-4-andmebaas.md): kogu ja Vault |
| 7 | [Rollid](lab-5-rollid.md): `site.yml` |
| 8 | [Kontrollitud muudatus ja esitamine](lab-6-esitamine.md) |

*Tabel 1. Päeva tegevused.*

## Mida päeva lõpuks esitad

Kaustas `k02/` peavad olema `ansible.cfg`, `inventory.ini`, `group_vars/`, `host_vars/`, `requirements.yml`, `roles/` ja `site.yml`. Kontrolli, et kõik muudatused on commit'itud ja GitHubi saadetud. Vaulti parool ei tohi Gitis olla.

## Abi

[Abi](abi.md) · [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions)
