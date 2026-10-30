---
tags:
  - Ansible
  - Lisaülesanne
---

# 2. kohtumine · Lisaülesanded

Need ülesanded on neile, kes on praktikumi lõpetanud. Kõik käsud käivita control node'is kaustas `~/kursus/k02`.

## L1 · Kasutajad sõnastikena

Praegu on `labori_kasutajad` nimede loend. Muuda see sõnastike loendiks, kus igal kasutajal on ka shell ja kommentaar:

```yaml
labori_kasutajad:
  - { nimi: anna, shell: /bin/bash, kommentaar: "Anna Tamm" }
  - { nimi: peeter, shell: /bin/sh, kommentaar: "Peeter Mets" }
```

Muuda rolli `common` ülesannet ja veebilehe malli nii, et need kasutaksid välja `item.nimi`.

??? tip "Vihje"

    Mallis saad nimede loendi avaldisega `{{ labori_kasutajad | map(attribute='nimi') | join(', ') }}`.

Sõnastik hoiab ühe kasutaja omadused koos ja tsükkel jääb samaks.

## L2 · Vaikeväärtus ja selle üle kirjutamine

Lisa rolli `veeb` `defaults/main.yml`-i muutuja `veeb_taustavarv: "#ffffff"` ja kasuta seda mallis (`<body style="background: {{ veeb_taustavarv }}">`). Kirjuta see üle ainult app01-le `host_vars/app01.yml`-is.

```bash
ansible veeb -m ansible.builtin.debug -a "var=veeb_taustavarv"
```

Vaikeväärtus teeb rolli kohe kasutatavaks ja üle tuleb kirjutada ainult vajalikud muutujad.

## L3 · Viga ja `-vvv`

Tekita failis `roles/veeb/tasks/main.yml` meelega taandeviga (nihuta üks `ansible.builtin.template:` rida kahe tühiku võrra paremale) ja käivita:

```bash
ansible-playbook site.yml --syntax-check
```

Leia veateatest rea ja veeru number ning paranda viga. Seejärel käivita playbook detailse väljundiga:

```bash
ansible-playbook site.yml --ask-vault-pass --limit web01 --check -vvv | head -60
```

Vaata väljundist, millise kasutajaga ja millise SSH käsuga Ansible ühendub.

Veateade näitab tavaliselt täpselt, kus viga on. `-vvv` näitab, mida Ansible SSH kaudu tegelikult teeb, ja aitab ühendusvigade korral.

## L4 · Kogu `community.general`: ajavöönd

Lisa `requirements.yml`-i kogu `community.general` ja rolli `common` ülesanne, mis määrab kõigis masinates ajavööndiks `Europe/Tallinn` (moodul `community.general.timezone`).

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml --ask-vault-pass
ansible all -m ansible.builtin.command -a "timedatectl show -p Timezone"
```

Paljud igapäevased moodulid on kogudes, mitte `ansible.builtin`-is. Fail `requirements.yml` hoiab projekti sõltuvused koodiga samas repositooriumis.
