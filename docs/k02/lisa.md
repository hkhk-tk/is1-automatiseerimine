---
tags:
  - Ansible
  - Lisaülesanne
---

# 2. kohtumine · Lisaülesanded

Kui praktikum on tehtud ja aega jääb. Kõik ülesanded käivad control node'il kaustas `~/kursus/k02`.

## L1 · Kasutajad sõnastikena

Praegu on `labori_kasutajad` nimede nimekiri. Tee sellest sõnastike nimekiri, kus igal kasutajal on ka shell ja kommentaar:

```yaml
labori_kasutajad:
  - { nimi: anna, shell: /bin/bash, kommentaar: "Anna Tamm" }
  - { nimi: peeter, shell: /bin/sh, kommentaar: "Peeter Mets" }
```

Muuda rolli `common` ülesannet ja veebilehe malli nii, et need kasutavad välja `item.nimi`.

??? tip "Vihje"

    Mallis on nimede nimekiri `{{ labori_kasutajad | map(attribute='nimi') | join(', ') }}`.

**Miks:** päris andmetes on ühel asjal mitu omadust. Sõnastik hoiab need koos ja tsükkel jääb samaks.

## L2 · Vaikeväärtus ja selle üle kirjutamine

Lisa rolli `veeb` `defaults/main.yml`-i muutuja `veeb_taustavarv: "#ffffff"` ja kasuta seda mallis (`<body style="background: {{ veeb_taustavarv }}">`). Kirjuta see üle ainult app01-le `host_vars/app01.yml`-is.

```bash
ansible veeb -m ansible.builtin.debug -a "var=veeb_taustavarv"
```

**Miks:** rolli kasutaja ei pea teadma kõiki muutujaid. Vaikeväärtus teeb rolli kasutatavaks kohe, üle kirjutada saab ainult vajaliku.

## L3 · Viga ja `-vvv`

Tee `roles/veeb/tasks/main.yml`-is meelega taandeviga (nihuta üks `ansible.builtin.template:` rida kahe tühiku võrra paremale) ja käivita:

```bash
ansible-playbook site.yml --syntax-check
```

Loe veateates rea ja veeru numbrit, paranda. Seejärel käivita playbook väga jutukalt:

```bash
ansible-playbook site.yml -K --ask-vault-pass --limit web01 --check -vvv | head -60
```

Vaata väljundist, millise kasutajaga ja millise SSH käsuga Ansible ühendub.

**Miks:** veateade ütleb tavaliselt täpselt, kus viga on. `-vvv` näitab, mida Ansible SSH-ga päriselt teeb, see aitab ühendusvigade korral.

## L4 · Kogu `community.general`: ajavöönd

Lisa `requirements.yml`-i kogu `community.general` ja rolli `common` ülesanne, mis paneb kõigis masinates ajavööndiks `Europe/Tallinn` (moodul `community.general.timezone`).

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml -K --ask-vault-pass
ansible all -m ansible.builtin.command -a "timedatectl show -p Timezone"
```

**Miks:** paljud igapäevased tööd on kogudes, mitte `ansible.builtin`-is. `requirements.yml` hoiab projekti sõltuvused koos koodiga.
