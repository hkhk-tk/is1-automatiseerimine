---
tags:
  - Ansible
  - Info
---

# 02 · Ansible mitmele masinale

Ühe töötava playbook'i asemel terve projekt: muutujad, mallid, handler'id ja rollid. Lõpuks seadistab üks käsk kasutajad kõigis masinates, veebiserveri kahes ja andmebaasi ühes.

[Lugemismaterjal](loeng.md){ .md-button } [Praktikum](lab.md){ .md-button .md-button--primary } [Kodutöö](kodutoo.md){ .md-button }

## Mida täna õpid

- hoida väärtusi muutujates grupi ja masina kaupa;
- korrata ülesannet `loop`-iga ja taaskäivitada teenust handler'iga;
- teha Jinja2 malliga igale masinale oma konfiguratsioonifail;
- paigaldada kogu ja hoida parooli Vaultis;
- jagada projekti rollideks ja muuta seda masinhaaval.

## Päeva käik

| | Osa |
|---|---|
| 1 | Muutujad, tsüklid, handler'id ja mallid: loeng |
| 2 | [Algseis](lab-1-algseis.md): projekt, grupid, muutujad |
| 3 | [Kasutajad](lab-2-kasutajad.md): `loop` ja `register` |
| 4 | [Veebiserver](lab-3-veebiserver.md): mall ja handler |
| 5 | Rollid, kogud ja Vault: loeng |
| 6 | [Andmebaas](lab-4-andmebaas.md): kogu ja Vault |
| 7 | [Rollid](lab-5-rollid.md): `site.yml` |
| 8 | [Kontrollitud muudatus ja esitamine](lab-6-esitamine.md) |

*Tabel 1. Päeva järjekord.*

## Mida päeva lõpuks esitad

Kaustas `k02/` on `ansible.cfg`, `inventory.ini`, `group_vars/`, `host_vars/`, `requirements.yml`, `roles/` ja `site.yml`, `git push` tehtud. Vaulti parool ei ole Gitis.

## Abi

[Abi](abi.md) · [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions)
