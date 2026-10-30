---
tags:
  - Linux
  - Bash
  - Praktikum
---

# 2. Käsitsi ja skriptina

!!! abstract "Eesmärgid"

    - täidad päeva ülesande masinas web01 käsitsi ja kontrollid tulemust;
    - koondad samad käsud Bashi skripti ja uurid selle käitumist korduval käivitamisel.

!!! info "Päeva ülesanne"

    Masinas **web01** peab kasutaja `kasutaja` kodukaustas olema kaust `automation-lab` õigustega `0750` ja selles fail `training.conf` õigustega `0640`. Failis on kaks rida:

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

    Neid kahte kontrollkäsku kasutad kogu päeva.

Käivita `mkdir ~/automation-lab` uuesti. Kuna sama nimega kaust on juba olemas, lõpetab `mkdir` veaga `File exists`.

💭 **Mõtle:** mida peaks skript tegema teisiti, et seda saaks käivitada mitu korda?

Eemalda kaust ja naase control node'i:

```bash
rm -r ~/automation-lab
exit
```

## A2 · Skriptina

Loo control node'is oma repositooriumisse fail `~/kursus/k01/prepare-training.sh`:

```bash
#!/usr/bin/env bash
mkdir -p ~/automation-lab
chmod 0750 ~/automation-lab
printf '%s\n' 'environment=training' 'enabled=true' > ~/automation-lab/training.conf
chmod 0640 ~/automation-lab/training.conf
echo "Valmis"
```

`mkdir -p` ei anna viga, kui kaust on juba olemas. Kopeeri skript masinasse web01 ja käivita see seal:

```bash
cd ~/kursus/k01
scp prepare-training.sh web01:
ssh web01 bash prepare-training.sh
```

## A3 · Teine käivitus

Enne käivitamist ennusta tulemust: kas skript kirjutab faili teisel käivitusel uuesti? Vaata faili muutmise aega enne ja pärast käivitamist:

```bash
ssh web01 stat -c '%y' automation-lab/training.conf
ssh web01 bash prepare-training.sh
ssh web01 stat -c '%y' automation-lab/training.conf
```

??? success "Oodatav tulemus"

    Teisel käivitusel on muutmise aeg uus: fail kirjutati üle, kuigi selle sisu oli juba õige. Meie skript ei kontrolli enne faili kirjutamist, kas selle sisu on juba õige. Seetõttu kirjutatakse fail igal käivitusel uuesti. Ansible'is teeb sama töö moodul, mis kontrollib kõigepealt tegelikku olekut ja muudab faili ainult siis, kui see on vajalik.

```bash
cd ~/kursus
git add k01/prepare-training.sh
git commit -m "k01: prepare-training.sh"
git push
```

**Valmis, kui** skript on GitHubis ja oskad selgitada, mis juhtus teisel käivitusel.
