---
tags:
  - Ansible
  - Praktikum
---

# 6. Lõpuülesanne ja esitamine

!!! abstract "Eesmärgid"

    - lisad iseseisvalt olemasolevasse playbook'i uue ülesande;
    - esitad töö GitHubis.

## A1 · Lõpuülesanne

Lisa `training.yml`-i kolmas ülesanne: kaustas `automation-lab` peab olema fail `README.txt` õigustega `0644` ja sisuga:

```text
Seda kausta haldab Ansible. Ära muuda käsitsi.
```

Käivita playbook kaks korda ja kontrolli seejärel faili sisu ning õigusi masinas:

```bash
ansible-playbook training.yml
ansible-playbook training.yml
ssh web01 "cat automation-lab/README.txt; stat -c '%a %n' automation-lab/README.txt"
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on uue ülesande olek `changed` ja olemasolevate ülesannete olek `ok`. Teisel käivitusel peab kokkuvõttes olema `changed=0`. Käsk `stat` näitab õigusi `644`.

??? tip "Vihje"

    Kopeeri playbook'is olemasolev `ansible.builtin.copy` ülesanne ja muuda selle väärtusi `name`, `dest`, `content` ja `mode`.

## A2 · Töö esitamine

Tee muudatustest commit, saada need GitHubi ja lisa tag `k01`:

```bash
cd ~/kursus
git add k01/
git commit -m "k01: lõpuülesanne"
git push
git tag k01
git push origin k01
```

Töö esitatakse tag'iga `k01`. Automaatne hindaja kontrollib tag'iga `k01` märgitud versiooni ja tulemus ilmub [Classroom 50](https://classroom50.org/hkhk-tk/is126-automatiseerimine/assignments) lehele.

Kõik viis faili on kohustuslikud: hindaja kontrollib, et need on olemas ja süntaktiliselt korras. Kohustuslik osa annab 80 punkti. Lisaks saab 10 punkti boonust `tools.yml`-i ülesannete eest, kus on kasutatud `when`-i ja silte (`tags`), ning 10 punkti boonust lõpuülesande (`README.txt`) eest.

Kui midagi jäi puudu, paranda see, tee uus commit ja saada tag uuesti GitHubi:

```bash
git tag -f k01
git push -f origin k01
```

Ava oma repositoorium GitHubis ja kontrolli, et kaustas `k01/` on järgmised failid:

| Fail | Kus see valmib |
|---|---|
| `prepare-training.sh` | [2. Käsitsi ja skriptina](lab-2-kasitsi.md) |
| `ansible.cfg`, `inventory.ini` | [3. Ansible'i alused](lab-3-ansible-alused.md) |
| `training.yml` | [4. Esimene playbook](lab-4-playbook.md) ja A1 |
| `tools.yml` | [5. Playbook viiele masinale](lab-5-parem-playbook.md) |

*Tabel 1. Esitatavad failid.*

**Valmis, kui** kõik viis faili on GitHubis, tag `k01` on GitHubis olemas ja Classroom 50 näitab kohustusliku osa eest 80 punkti.

Edasi: [Kodutöö](kodutoo.md).
