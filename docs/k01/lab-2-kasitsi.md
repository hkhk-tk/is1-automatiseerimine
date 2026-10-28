---
tags:
  - Linux
  - Praktikum
---

# 2. Ülesanne käsitsi

!!! abstract "Eesmärgid"

    - teed päeva ülesande web01-s käsk-käsult;
    - ennustad enne iga käsku, mis muutub;
    - kontrollid tulemust kontrollnimekirja järgi.

!!! info "Päeva ülesanne"

    Masinas **web01** on kasutaja `kasutaja` kodukaustas kaust `automation-lab` õigustega `0750` ja selles fail `training.conf` õigustega `0640`. Failis on kaks rida:

    ```ini
    environment=training
    enabled=true
    ```

## A1 · Mine web01-sse

Control node'il:

```bash
ssh web01
```

Prompt on nüüd `kasutaja@web01`. Kõik selle osa käsud käivad web01-s.

## A2 · Kaust

Ennusta enne: mis õigused saab uus kaust?

```bash
cd ~
mkdir automation-lab
ls -ld automation-lab
```

??? success "Oodatav tulemus"

    ```
    drwxr-xr-x 2 kasutaja kasutaja 4096 ... automation-lab
    ```

    Vaikimisi õigused on `755` (`rwxr-xr-x`): kõik masina kasutajad saavad kausta sisu lugeda. Meie nõue on `750`: grupp loeb, teised mitte.

```bash
chmod 0750 automation-lab
ls -ld automation-lab
```

??? success "Oodatav tulemus"

    ```
    drwxr-x--- 2 kasutaja kasutaja 4096 ... automation-lab
    ```

## A3 · Fail

```bash
printf '%s\n' 'environment=training' 'enabled=true' > automation-lab/training.conf
chmod 0640 automation-lab/training.conf
```

`printf '%s\n'` trükib iga järgneva teksti eraldi reale. `>` suunab väljundi faili.

## A4 · Kontrolli

Kontrollnimekiri: kas kaust on olemas, kas failis on täpselt kaks rida, kas õigused on `750` ja `640`, kas omanik on `kasutaja`.

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

    `stat -c '%a %U %n'` näitab õigusi numbrina, omanikku ja nime. Seda kahte käsku kasutad kogu päeva.

??? question "Mõtle"

    Käivita `mkdir automation-lab` uuesti. Mis juhtub ja miks? Mis peaks juhtuma, kui seda tööd teeb skript?

## A5 · Koristus

Järgmises osas teeb sama töö skript. Et näha, kas skript töötab, eemalda kaust:

```bash
rm -r ~/automation-lab
exit
```

!!! warning "Kustutad ainult selle kausta"

    Kontrolli enne Enterit, et tee on täpselt `~/automation-lab`. `rm -r` ei küsi kinnitust ja prügikasti pole.

**Valmis, kui** kontrollkäskude väljund klappis oodatavaga ja oled tagasi control node'il.
