---
tags:
  - Bash
  - Ansible
  - Info
---

# 01 · Linuxi haldusest automatiseerimiseni

Täna lahendad sama ülesande kolmel viisil: kõigepealt käsitsi, seejärel Bashi skriptiga ja lõpuks Ansible'iga. Pärast iga lahendust kontrollid tulemust samade kriteeriumide järgi.

[Lugemismaterjal](loeng.md){ .md-button } [Praktikum](lab.md){ .md-button .md-button--primary } [Kodutöö](kodutoo.md){ .md-button }

## Mida täna õpid

Päeva lõpuks oskad:

- käivitada Ansible'i ad-hoc käske mitmes masinas korraga;
- käivitada Ansible'i playbook'i ja lugeda käivituse tulemust;
- kontrollida, mis juhtub playbook'i korduval käivitamisel;
- kontrollida, kuidas Ansible reageerib käsitsi tehtud muudatusele.

## Päeva käik

| | Osa |
|---|---|
| 1 | Miks automatiseerida? Ansible'i tutvustus ja loeng |
| 2 | [Keskkonna ettevalmistamine](lab-1-keskkond.md): SSH-võti, masinate nimed ja repositoorium |
| 3 | [Ülesande täitmine käsitsi ja Bashi skriptiga](lab-2-kasitsi.md) |
| 4 | [Ansible'i alused](lab-3-ansible-alused.md): ad-hoc käsud viiel masinal |
| 5 | [Esimene playbook](lab-4-playbook.md) |
| 6 | [Playbook viiele masinale](lab-5-parem-playbook.md): `when`, `--limit` ja `tags` |
| 7 | [Iseseisev ülesanne ja töö esitamine](lab-6-esitamine.md) |

*Tabel 1. Päeva tegevused.*

## Mida päeva lõpuks esitad

Kaustas `k01/` peavad olema järgmised failid:

- `prepare-training.sh`
- `ansible.cfg`
- `inventory.ini`
- `training.yml`
- `tools.yml`

Töö esitatakse tag'iga `k01`. Automaatne hindaja kontrollib tag'iga märgitud versiooni ja tulemuse näed Classroom 50-s. Päeva jooksul näitab laboritahvel, millised sammud on sinu masinates tehtud.

## Abi

[Linuxi ja Bashi spikker](spikker.md) · [Abi](abi.md) · [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions)
