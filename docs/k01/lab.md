---
tags:
  - Bash
  - Ansible
  - Praktikum
---

# 1. kohtumine · Praktikum

!!! info "Selle korra töö"

    - **Masinad:** control node ja viis labori VM-i (web01, app01, rmq01 Ubuntu; mc01, db01 Rocky), kasutaja `kasutaja`
    - **Failid:** sinu kursuse repo, kaust `~/kursus/k01/`
    - **Esitamine:** `git push`

| Etapp | Mida teed | Valmis, kui |
|---|---|---|
| [1. Keskkond](lab-1-keskkond.md) | SSH-võti, masinate nimed, repo | `ssh web01` töötab parooli küsimata |
| [2. Käsitsi ja skriptina](lab-2-kasitsi.md) | ülesanne web01-s käsitsi, siis skriptiga | teine käivitus kirjutab faili üle |
| [3. Ansible'i alused](lab-3-ansible-alused.md) | paigaldus, `ansible.cfg`, inventory, ad-hoc käsud | viis `pong`-i |
| [4. Esimene playbook](lab-4-playbook.md) | päeva ülesanne playbook'ina, triiv | teine käivitus annab `changed=0` |
| [5. Playbook viiele masinale](lab-5-parem-playbook.md) | `when`, `--limit`, `tags` | `tools.yml` teine käivitus annab `changed=0` |
| [6. Kontroll ja esitamine](lab-6-esitamine.md) | võrdlus, lõpuülesanne, `git push` | kuus faili GitHubis |

*Tabel 1. Praktikumi etapid.*

Kinni jäid? [Abi](abi.md) · [Linux + Bash spikker](spikker.md)
