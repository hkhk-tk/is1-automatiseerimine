---
tags:
  - Bash
  - Ansible
  - Info
---

# 01 · Linuxi haldusest automatiseerimiseni

Üks väike ülesanne kolm korda: käsitsi, Bashi skriptiga ja Ansible'iga. Iga kord kontrollid tulemust samamoodi.

[Lugemismaterjal](loeng.md){ .md-button } [Praktikum](lab.md){ .md-button .md-button--primary } [Kodutöö](kodutoo.md){ .md-button }

## Mida täna õpid

- kirjeldada ülesannet tulemusena ja koostada sellele kontrollnimekirja;
- käivitada Ansible'i ad-hoc käske mitmes masinas korraga;
- käivitada Ansible'i playbook'i ja lugeda selle tulemust;
- kontrollida, mis juhtub teisel käivitusel ja pärast käsitsi muudatust.

## Päeva käik

| | Osa |
|---|---|
| 1 | Miks automatiseerida ja mis on Ansible: loeng |
| 2 | [Keskkond](lab-1-keskkond.md): SSH-võti, masinate nimed, repo |
| 3 | [Käsitsi ja skriptina](lab-2-kasitsi.md) |
| 4 | [Ansible'i alused](lab-3-ansible-alused.md): ad-hoc käsud viiel masinal |
| 5 | [Esimene playbook](lab-4-playbook.md) |
| 6 | [Playbook viiele masinale](lab-5-parem-playbook.md): `when`, `--limit`, `tags` |
| 7 | [Lõpuülesanne ja esitamine](lab-6-esitamine.md) |

*Tabel 1. Päeva järjekord.*

## Mida päeva lõpuks esitad

Kaustas `k01/` on `prepare-training.sh`, `ansible.cfg`, `inventory.ini`, `training.yml` ja `tools.yml`, `git push` tehtud.

## Abi

[Linux + Bash spikker](spikker.md) · [Abi](abi.md) · [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions)
