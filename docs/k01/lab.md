---
tags:
  - Bash
  - Ansible
  - Praktikum
---

# 1. kohtumine · Praktikum

!!! info "Selle korra töö"

    - **Masinad:** control node ja web01, kasutaja `kasutaja`
    - **Failid:** sinu kursuse repo, kaust `~/kursus/k01/`
    - **Esitamine:** `git push`

| Etapp | Mida teed | Valmis, kui |
|---|---|---|
| [1. Keskkond](lab-1-keskkond.md) | SSH-võti, masinate nimed, repo | `ssh web01` töötab parooli küsimata |
| [2. Käsitsi](lab-2-kasitsi.md) | kaust ja fail web01-s käsk-käsult | kontroll näitab `750` ja `640` |
| [3. Bashi skript](lab-3-bash.md) | sama töö skriptiga | skript annab sama tulemuse |
| [4. Teine käivitus, triiv ja viga](lab-4-viga.md) | mis juhtub korduval käivitusel ja vea korral | väljumiskood `1` vea korral, `0` pärast parandust |
| [5. Ansible](lab-5-ansible.md) | inventory ja playbook | teine käivitus annab `changed=0` |
| [6. Kontroll ja esitamine](lab-6-esitamine.md) | võrdlus, lõpuülesanne, `git push` | neli faili GitHubis |

*Tabel 1. Praktikumi etapid.*

Kinni jäid? [Abi](abi.md) · [Linux + Bash spikker](spikker.md)
