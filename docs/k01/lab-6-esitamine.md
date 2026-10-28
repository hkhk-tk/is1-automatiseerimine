---
tags:
  - Ansible
  - Praktikum
---

# 6. Kontroll, lõpuülesanne ja esitamine

!!! abstract "Eesmärgid"

    - võrdled kolme teostust;
    - lisad playbook'i ise ühe ülesande;
    - esitad töö GitHubi.

## A1 · Võrdle

Loo fail `~/kursus/k01/vordlus.md` ja täida tabel paari sõnaga lahtri kohta, oma praktikumi põhjal:

```markdown
| Küsimus | Käsitsi | Bash | Ansible |
|---|---|---|---|
| Mis juhtus teisel käivitusel? | | | |
| Mis juhtus pärast käsitsi muudatust? | | | |
| Kust on näha soovitud tulemus? | | | |
```

## A2 · Lõpuülesanne

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

## A3 · Esita

```bash
cd ~/kursus
git add k01/
git commit -m "k01: võrdlus ja lõpuülesanne"
git push
```

Ava oma repo GitHubis ja vaata, et kaustas `k01/` on need failid:

| Fail | Kust |
|---|---|
| `prepare-training.sh` | [2. Käsitsi ja skriptina](lab-2-kasitsi.md) |
| `ansible.cfg`, `inventory.ini` | [3. Ansible'i alused](lab-3-ansible-alused.md) |
| `training.yml` | [4. Esimene playbook](lab-4-playbook.md) ja A2 |
| `tools.yml` | [5. Playbook viiele masinale](lab-5-parem-playbook.md) |
| `vordlus.md` | A1 |

*Tabel 1. Esitatavad failid.*

**Valmis, kui** kõik kuus faili on GitHubis ja playbook'i teine käivitus annab `changed=0`.

Edasi: [Kodutöö](kodutoo.md).
