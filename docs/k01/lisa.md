---
tags:
  - Ansible
  - Lisaülesanne
---

# 1. kohtumine · Lisaülesanded

Kui praktikum on tehtud ja aega jääb. Kõik ülesanded käivad control node'il kaustas `~/kursus/k01`.

## L1 · Kasutaja kõigis masinates

Lisa uus playbook `users.yml`, mis loob kõigis viies masinas kasutaja `kolleeg` kodukaustaga ja shelliga `/bin/bash`. Kasutaja loomiseks on vaja administraatori õigusi.

??? tip "Vihje"

    Moodul on `ansible.builtin.user`. Parameetrid näed käsuga `ansible-doc ansible.builtin.user`; vaata juhendi lõpus näiteid (`EXAMPLES`).

```bash
ansible-playbook users.yml -K
ansible all -m ansible.builtin.command -a "id kolleeg"
```

??? success "Oodatav tulemus"

    Esimene käivitus: viis `changed`. Teine: `changed=0`. `id kolleeg` vastab igast masinast.

**Miks:** kasutajate haldus on üks sagedasemaid korduvaid töid. Sama playbook teeb seda viie või saja masina peal.

## L2 · ansible-lint

Paigalda `ansible-lint` ja lase sellel oma playbook'id läbi vaadata:

=== "Ubuntu"

    ```bash
    sudo apt install -y ansible-lint
    ```

=== "AlmaLinux / Rocky"

    ```bash
    sudo dnf install -y python3-pip && pip3 install --user ansible-lint
    ```

```bash
ansible-lint training.yml tools.yml
```

Paranda vähemalt üks leitud märkus ja käivita uuesti.

**Miks:** `--syntax-check` ütleb ainult, kas fail on loetav. `ansible-lint` leiab levinud vigu ja halbu tavasid enne, kui playbook masinaid muudab.

## L3 · Fail masinast tagasi

Moodul `ansible.builtin.fetch` toob faili hallatavast masinast control node'ile. Too kõigist viiest masinast fail `/etc/os-release` kausta `~/kursus/k01/os/`.

??? tip "Vihje"

    ```bash
    ansible all -m ansible.builtin.fetch -a "src=/etc/os-release dest=os/"
    ```

    Vaata, millise kaustastruktuuri `fetch` tegi: `find os -type f`.

**Miks:** sageli on vaja masinatest midagi kokku koguda (konfiguratsioon, logi, versioon). Ad-hoc `fetch` teeb seda kõigist masinatest ühe käsuga.
