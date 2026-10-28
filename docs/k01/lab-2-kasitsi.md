---
tags:
  - Linux
  - Bash
  - Praktikum
---

# 2. Käsitsi ja skriptina

!!! abstract "Eesmärgid"

    - teed päeva ülesande web01-s käsitsi ja kontrollid tulemust;
    - paned samad käsud skripti ja näed, mida skript teisel käivitusel teeb.

!!! info "Päeva ülesanne"

    Masinas **web01** on kasutaja `kasutaja` kodukaustas kaust `automation-lab` õigustega `0750` ja selles fail `training.conf` õigustega `0640`. Failis on kaks rida:

    ```ini
    environment=training
    enabled=true
    ```

## A1 · Käsitsi

```bash
ssh web01
mkdir ~/automation-lab
chmod 0750 ~/automation-lab
printf '%s\n' 'environment=training' 'enabled=true' > ~/automation-lab/training.conf
chmod 0640 ~/automation-lab/training.conf
```

Kontrolli:

```bash
cat ~/automation-lab/training.conf
stat -c '%a %U %n' ~/automation-lab ~/automation-lab/training.conf
```

??? success "Oodatav tulemus"

    ```
    environment=training
    enabled=true
    750 kasutaja /home/kasutaja/automation-lab
    640 kasutaja /home/kasutaja/automation-lab/training.conf
    ```

    Need kaks kontrollkäsku kasutad kogu päeva.

Proovi `mkdir ~/automation-lab` uuesti. Tuleb viga `File exists`: käsk ei tea, et kaust on juba olemas ja õige. Eemalda kaust ja mine tagasi control node'ile:

```bash
rm -r ~/automation-lab
exit
```

## A2 · Skriptina

Control node'il, oma repos, loo fail `~/kursus/k01/prepare-training.sh`:

```bash
#!/usr/bin/env bash
mkdir -p ~/automation-lab
chmod 0750 ~/automation-lab
printf '%s\n' 'environment=training' 'enabled=true' > ~/automation-lab/training.conf
chmod 0640 ~/automation-lab/training.conf
echo "Valmis"
```

`mkdir -p` ei anna viga, kui kaust on juba olemas. Kopeeri skript web01-le ja käivita seal:

```bash
cd ~/kursus/k01
scp prepare-training.sh web01:
ssh web01 bash prepare-training.sh
```

## A3 · Teine käivitus

Ennusta enne: kas skript kirjutab faili teisel korral uuesti? Vaata faili muutmise aega enne ja pärast:

```bash
ssh web01 stat -c '%y' automation-lab/training.conf
ssh web01 bash prepare-training.sh
ssh web01 stat -c '%y' automation-lab/training.conf
```

??? success "Oodatav tulemus"

    Aeg on teisel korral uus: fail kirjutati üle, kuigi sisu oli juba õige. Skript ei kontrolli seisu, ta lihtsalt teeb käsud uuesti. Ansible'is näed sama tööd tegemas moodulit, mis kontrollib enne, kas muutmine on vaja.

```bash
cd ~/kursus
git add k01/prepare-training.sh
git commit -m "k01: prepare-training.sh"
git push
```

**Valmis, kui** skript on GitHubis ja oskad öelda, mis juhtus teisel käivitusel.
