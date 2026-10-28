---
tags:
  - Ansible
  - Praktikum
---

# 6. Lõpuülesanne ja esitamine

!!! abstract "Eesmärgid"

    - lisad playbook'i ise ühe ülesande;
    - esitad töö GitHubi.

## A1 · Lõpuülesanne

Lisa `training.yml`-i kolmas ülesanne: kaustas `automation-lab` peab olema fail `README.txt` õigustega `0644` ja sisuga:

```text
Seda kausta haldab Ansible. Ära muuda käsitsi.
```

Käivita kaks korda ja kontrolli masinas:

```bash
ansible-playbook training.yml
ansible-playbook training.yml
ssh web01 "cat automation-lab/README.txt; stat -c '%a %n' automation-lab/README.txt"
```

??? success "Oodatav tulemus"

    Esimene käivitus: uus ülesanne `changed`, teised `ok`. Teine käivitus: `changed=0`. `stat` näitab `644`.

??? tip "Vihje"

    Kopeeri playbook'is olemasolev `ansible.builtin.copy` ülesanne ja muuda `name`, `dest`, `content` ja `mode`.

## A2 · Esita

```bash
cd ~/kursus
git add k01/
git commit -m "k01: lõpuülesanne"
git push
```

Ava oma repo GitHubis ja vaata, et kaustas `k01/` on need failid:

| Fail | Kust |
|---|---|
| `prepare-training.sh` | [2. Käsitsi ja skriptina](lab-2-kasitsi.md) |
| `ansible.cfg`, `inventory.ini` | [3. Ansible'i alused](lab-3-ansible-alused.md) |
| `training.yml` | [4. Esimene playbook](lab-4-playbook.md) ja A1 |
| `tools.yml` | [5. Playbook viiele masinale](lab-5-parem-playbook.md) |

*Tabel 1. Esitatavad failid.*

**Valmis, kui** kõik viis faili on GitHubis ja playbook'i teine käivitus annab `changed=0`.

Edasi: [Kodutöö](kodutoo.md).
