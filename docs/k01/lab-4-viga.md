---
tags:
  - Bash
  - Praktikum
---

# 4. Teine käivitus, triiv ja viga

!!! abstract "Eesmärgid"

    - näed, mida skript teeb teisel käivitusel;
    - parandad käsitsi tehtud muudatuse skriptiga;
    - tekitad kontrollitud vea ja loed väljumiskoodi.

Kõik käsud käivad control node'il kaustas `~/kursus/k01`.

## A1 · Teine käivitus

Ennusta enne: kas skript annab teisel korral vea, sest kaust on juba olemas? Kas fail kirjutatakse uuesti?

Vaata faili muutmise aega, käivita skript ja vaata uuesti:

```bash
ssh web01 stat -c '%y' automation-lab/training.conf
ssh web01 bash prepare-training.sh
ssh web01 stat -c '%y' automation-lab/training.conf
```

??? success "Oodatav tulemus"

    Skript lõpeb reaga `Valmis:` ja viga ei tule, sest `mkdir -p` ei kaeba olemasoleva kausta peale. Muutmise aeg on aga uus: fail kirjutati üle, kuigi sisu oli juba õige.

    Lõpptulemus on sama, aga töö tehti uuesti. Päris teenuse puhul võib iga ülekirjutus tähendada teenuse taaskäivitust.

## A2 · Triiv: keegi muutis faili

Muuda faili web01-s käsitsi, nagu teeks kolleeg öösel:

```bash
ssh web01 "sed -i 's/enabled=true/enabled=false/' automation-lab/training.conf"
ssh web01 cat automation-lab/training.conf
```

Käivita skript ja vaata uuesti:

```bash
ssh web01 bash prepare-training.sh
ssh web01 cat automation-lab/training.conf
```

??? success "Oodatav tulemus"

    Enne skripti: `enabled=false`. Pärast: `enabled=true`. Skript taastas soovitud sisu, sest fail on täielikult skripti hallata.

## A3 · Kontrollitud viga

Pane kausta asemele samanimeline **fail**. Siis ei saa `mkdir` kausta teha:

```bash
ssh web01 "rm -r automation-lab && touch automation-lab"
```

Ennusta enne: millisel real skript peatub ja mis on väljumiskood?

```bash
ssh web01 bash prepare-training.sh; echo "väljumiskood: $?"
```

??? success "Oodatav tulemus"

    ```
    Sihtkaust: /home/kasutaja/automation-lab
    mkdir: cannot create directory '/home/kasutaja/automation-lab': File exists
    Viga: ei saa kausta teha: /home/kasutaja/automation-lab
    väljumiskood: 1
    ```

    Skript peatus esimese `if`-i juures ega proovinud faili kirjutada. Väljumiskood `1` ütleb ka teisele programmile, et midagi läks valesti.

Paranda ja käivita uuesti:

```bash
ssh web01 rm automation-lab
ssh web01 bash prepare-training.sh; echo "väljumiskood: $?"
```

??? success "Oodatav tulemus"

    `Valmis:` ja `väljumiskood: 0`.

??? question "Mõtle"

    Skript peatub vea juures, aga kas ta võtab tagasi juba tehtud sammud? Mis jääks maha, kui faili kirjutamine õnnestuks ja õiguste muutmine ebaõnnestuks?

## A4 · Boonus: kirjuta ainult siis, kui vaja

Muuda skripti nii, et fail kirjutatakse ainult siis, kui sisu erineb. Asenda faili kirjutav `if`-plokk sellega:

```bash
if printf '%s\n' 'environment=training' 'enabled=true' | cmp -s - "$config_file"; then
    printf 'Sisu on juba õige: %s\n' "$config_file"
elif ! printf '%s\n' 'environment=training' 'enabled=true' > "$config_file"; then
    printf 'Viga: ei saa faili kirjutada: %s\n' "$config_file" >&2
    exit 1
fi
```

Käivita kaks korda (`scp` uuesti!) ja vaata muutmise aega. Teisel korral see ei muutu.

**Valmis, kui** oskad öelda, mis juhtus teisel käivitusel, pärast triivi ja vea korral, ning skript lõpetab koodiga `0`.
