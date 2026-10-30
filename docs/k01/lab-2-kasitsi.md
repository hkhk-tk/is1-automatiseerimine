---
tags:
  - Linux
  - Bash
  - Praktikum
---

# 2. Käsitsi ja skriptiga

Enne kui ülesande Ansible'ile annad, teed selle ise: kõigepealt käsitsi, siis Bashi skriptiga. Nii näed hiljem, mida Ansible teisiti teeb.

!!! info "Päeva ülesanne"

    Masinas **web01** peab kasutaja `kasutaja` kodukaustas olema kaust `automation-lab` õigustega `0750` ja selles fail `training.conf` õigustega `0640`. Failis on kaks rida:

    ```ini
    environment=training
    enabled=true
    ```

## A1 · Käsitsi

Logi masinasse web01 ja tee ülesanne nelja käsuga:

```bash
ssh web01
mkdir ~/automation-lab
chmod 0750 ~/automation-lab
printf '%s\n' 'environment=training' 'enabled=true' > ~/automation-lab/training.conf
chmod 0640 ~/automation-lab/training.conf
```

Kontrolli faili sisu ja õigusi. Samu kahte käsku kasutad kogu päeva, et kontrollida, kas tulemus on õige:

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

Käivita nüüd `mkdir ~/automation-lab` veel kord. Kuna kaust on juba olemas, lõpetab `mkdir` veaga `File exists`. Sama juhtuks, kui need käsud oleksid skriptis ja käivitaksid skripti teist korda.

Eemalda kaust, et skript saaks järgmises sammus alustada tühjalt, ja naase control node'i:

```bash
rm -r ~/automation-lab
exit
```

## A2 · Skriptiga

Samad käsud failis on skript. `mkdir -p` ei anna viga, kui kaust on juba olemas, nii et skripti saab käivitada mitu korda. Loo control node'is fail `~/kursus/k01/prepare-training.sh`:

```bash
#!/usr/bin/env bash
mkdir -p ~/automation-lab
chmod 0750 ~/automation-lab
printf '%s\n' 'environment=training' 'enabled=true' > ~/automation-lab/training.conf
chmod 0640 ~/automation-lab/training.conf
echo "Valmis"
```

Kopeeri skript masinasse web01 ja käivita see seal:

```bash
cd ~/kursus/k01
scp prepare-training.sh web01:
ssh web01 bash prepare-training.sh
```

## A3 · Korduv käivitus

Skript ei anna teisel käivitusel viga. Aga kas see teeb midagi, mida ei peaks?

**Ennusta:** kas skript kirjutab faili teisel käivitusel uuesti?

Vaata faili muutmise aega enne ja pärast käivitamist:

```bash
ssh web01 stat -c '%y' automation-lab/training.conf
ssh web01 bash prepare-training.sh
ssh web01 stat -c '%y' automation-lab/training.conf
```

??? success "Oodatav tulemus"

    Muutmise aeg on uus: skript kirjutas faili üle, kuigi sisu oli juba õige. Skript ei kontrolli enne, milline on masina tegelik olek. 4. osas teed sama katse Ansible'iga.

Salvesta skript repositooriumi ja saada see GitHubi:

```bash
cd ~/kursus
git add k01/prepare-training.sh
git commit -m "k01: prepare-training.sh"
git push
```

**Valmis, kui** skript on GitHubis ja oskad selgitada, mis juhtus teisel käivitusel.
