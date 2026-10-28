---
tags:
  - Bash
  - Praktikum
---

# 3. Bashi skript

!!! abstract "Eesmärgid"

    - kirjutad skripti, mis teeb sama töö, mida tegid käsitsi;
    - kasutad muutujaid, jutumärke, väljumiskoodi ja `if`-i;
    - käivitad skripti web01-s ja kontrollid tulemust.

Skripti kirjutad control node'il oma repos ja käivitad web01-s.

```bash
cd ~/kursus/k01
```

## A1 · Esimene skript

Loo VS Code'is fail `~/kursus/k01/prepare-training.sh`:

```bash
#!/usr/bin/env bash
printf '%s\n' 'Valmistan ette koolituse kausta.'
```

Esimene rida (shebang) ütleb, et faili loeb Bash. Käivita kahel viisil:

```bash
bash prepare-training.sh
chmod u+x prepare-training.sh
./prepare-training.sh
```

??? success "Oodatav tulemus"

    Mõlemal korral `Valmistan ette koolituse kausta.` Esimesel juhul valid ise Bashi. Teisel juhul peab fail olema käivitatav (`chmod u+x`) ja shebang ütleb, mis programm seda loeb.

## A2 · Muutujad

Lisa skripti teise rea järele:

```bash
lab_dir="$HOME/automation-lab"
config_file="$lab_dir/training.conf"
printf 'Sihtkaust: %s\n' "$lab_dir"
```

```bash
bash prepare-training.sh
```

??? success "Oodatav tulemus"

    ```
    Valmistan ette koolituse kausta.
    Sihtkaust: /home/kasutaja/automation-lab
    ```

??? question "Mõtle"

    Kirjuta ajutiselt `lab_dir = "$HOME/automation-lab"` (tühikutega) ja käivita. Mida Bash ütleb ja miks? Pane tühikud tagasi ära.

## A3 · Terve skript

Asenda faili sisu sellega:

```bash
#!/usr/bin/env bash
# Valmistab ette koolituse kausta ja konfiguratsioonifaili.
# Fail on täielikult skripti hallata: iga käivitus kirjutab selle üle.

lab_dir="$HOME/automation-lab"
config_file="$lab_dir/training.conf"

printf 'Sihtkaust: %s\n' "$lab_dir"

if ! mkdir -p "$lab_dir"; then
    printf 'Viga: ei saa kausta teha: %s\n' "$lab_dir" >&2
    exit 1
fi

if ! chmod 0750 "$lab_dir"; then
    printf 'Viga: ei saa kausta õigusi muuta: %s\n' "$lab_dir" >&2
    exit 1
fi

if ! printf '%s\n' 'environment=training' 'enabled=true' > "$config_file"; then
    printf 'Viga: ei saa faili kirjutada: %s\n' "$config_file" >&2
    exit 1
fi

if ! chmod 0640 "$config_file"; then
    printf 'Viga: ei saa faili õigusi muuta: %s\n' "$config_file" >&2
    exit 1
fi

printf 'Valmis: %s\n' "$config_file"
```

??? note "Mis on uut"

    | Kirjutis | Tähendus |
    |---|---|
    | `mkdir -p` | teeb kausta; kui see on juba olemas, ei anna viga |
    | `if ! käsk; then` | kui käsk **ei** õnnestu |
    | `>&2` | teade läheb veaväljundisse |
    | `exit 1` | skript lõpeb veakoodiga |

Kontrolli süntaksit. See loeb skripti läbi, aga ei käivita midagi:

```bash
bash -n prepare-training.sh && echo "süntaks korras"
```

## A4 · Käivita web01-s

Kopeeri skript web01-le ja käivita seal:

```bash
scp prepare-training.sh web01:
ssh web01 bash prepare-training.sh
```

??? success "Oodatav tulemus"

    ```
    Sihtkaust: /home/kasutaja/automation-lab
    Valmis: /home/kasutaja/automation-lab/training.conf
    ```

    `$HOME` on web01-s `/home/kasutaja`, sest skript jookseb seal.

## A5 · Kontrolli

Sama kontroll nagu käsitsi osas, nüüd control node'ilt:

```bash
ssh web01 "cat ~/automation-lab/training.conf; stat -c '%a %U %n' ~/automation-lab ~/automation-lab/training.conf"
```

??? success "Oodatav tulemus"

    ```
    environment=training
    enabled=true
    750 kasutaja /home/kasutaja/automation-lab
    640 kasutaja /home/kasutaja/automation-lab/training.conf
    ```

## A6 · Commit

```bash
cd ~/kursus
git add k01/prepare-training.sh
git commit -m "k01: prepare-training.sh"
git push
```

**Valmis, kui** kontroll näitas sama tulemust mis käsitsi ja skript on GitHubis.
