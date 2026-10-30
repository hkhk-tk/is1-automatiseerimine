---
tags:
  - Bash
  - Ansible
  - Praktikum
---

# 1. kohtumine · Praktikum

!!! info "Selle korra töö"

    - **Masinad:** control node ja viis labori VM-i (web01, app01, rmq01 Ubuntu; mc01, db01 AlmaLinux), kasutaja `kasutaja`
    - **Failid:** kursuse repositooriumi kaust `~/kursus/k01/`
    - **Esitamine:** tag `k01` GitHubis

| Etapp | Mida teed | Valmis, kui |
|---|---|---|
| [1. Keskkond](lab-1-keskkond.md) | SSH-võti, masinate nimed, repo | `ssh web01` töötab parooli küsimata |
| [2. Käsitsi ja skriptina](lab-2-kasitsi.md) | sama ülesanne esmalt käsitsi ja seejärel Bashi skriptiga | oskad selgitada, miks skript kirjutab faili teisel käivitusel uuesti üle |
| [3. Ansible'i alused](lab-3-ansible-alused.md) | paigaldus, `ansible.cfg`, inventory, ad-hoc käsud | kõik viis masinat vastavad `pong` |
| [4. Esimene playbook](lab-4-playbook.md) | päeva ülesanne playbook'ina, triiv | teine käivitus annab `changed=0` |
| [5. Playbook viiele masinale](lab-5-parem-playbook.md) | `when`, `--limit`, `tags` | `tools.yml` teine käivitus annab `changed=0` |
| [6. Lõpuülesanne ja esitamine](lab-6-esitamine.md) | iseseisev playbook'i ülesanne ja töö esitamine | viis faili ja tag `k01` on GitHubis |

*Tabel 1. Praktikumi etapid.*

Vajad abi? [Abi](abi.md) · [Linuxi ja Bashi spikker](spikker.md)

Jäi aega üle? [Lisaülesanded](lisa.md)
