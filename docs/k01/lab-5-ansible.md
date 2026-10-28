---
tags:
  - Ansible
  - Praktikum
---

# 5. Sama ülesanne Ansible'iga

!!! abstract "Eesmärgid"

    - paigaldad Ansible'i control node'ile;
    - kirjutad inventory ja playbook'i;
    - loed tulemust `ok`, `changed` ja näed teisel käivitusel `changed=0`;
    - parandad triivi playbook'iga.

Kõik käsud käivad control node'il kaustas `~/kursus/k01`. Ansible jookseb siin ja teeb töö web01-s SSH kaudu.

## A1 · Paigalda Ansible

=== "Ubuntu"

    ```bash
    sudo apt update
    sudo apt install -y ansible-core
    ```

=== "AlmaLinux / Rocky"

    ```bash
    sudo dnf install -y ansible-core
    ```

```bash
ansible --version
```

??? success "Oodatav tulemus"

    Esimene rida on kujul `ansible [core 2.x.y]`. Täpne versioon sõltub distrost.

## A2 · Inventory

Loo fail `~/kursus/k01/inventory.ini`. IP on web01 aadress tabelist [Keskkonna](lab-1-keskkond.md) lehel:

```ini
[veeb]
web01 ansible_host=<web01-ip> ansible_user=kasutaja
```

Kontrolli ühendust:

```bash
ansible -i inventory.ini web01 -m ansible.builtin.ping
```

??? success "Oodatav tulemus"

    ```
    web01 | SUCCESS => {
        "changed": false,
        "ping": "pong"
    }
    ```

    `pong` tähendab, et Ansible jõuab SSH-ga masinasse ja seal töötab Python.

## A3 · Playbook

Loo fail `~/kursus/k01/training.yml`. Taane on tühikutega, mitte tabulaatoriga:

```yaml
- name: Koolituse seadistus
  hosts: web01
  tasks:
    - name: Kaust on olemas
      ansible.builtin.file:
        path: /home/kasutaja/automation-lab
        state: directory
        mode: "0750"

    - name: Konfiguratsioonifail on olemas
      ansible.builtin.copy:
        dest: /home/kasutaja/automation-lab/training.conf
        content: |
          environment=training
          enabled=true
        mode: "0640"
```

Kontrolli süntaksit:

```bash
ansible-playbook -i inventory.ini training.yml --syntax-check
```

## A4 · Esimene käivitus

Ennusta enne: kaust ja fail on Bashi osast juba olemas ja õiged. Mida Ansible teeb?

```bash
ansible-playbook -i inventory.ini training.yml
```

??? success "Oodatav tulemus"

    Mõlemad ülesanded `ok`, kokkuvõttes `changed=0`. Ansible võrdles soovitud seisu tegelikuga ja ei leidnud erinevust, seega ei muutnud midagi.

Nüüd eemalda kaust ja käivita uuesti:

```bash
ssh web01 rm -r automation-lab
ansible-playbook -i inventory.ini training.yml
```

??? success "Oodatav tulemus"

    ```
    TASK [Kaust on olemas] ********************
    changed: [web01]

    TASK [Konfiguratsioonifail on olemas] *****
    changed: [web01]

    PLAY RECAP ********************************
    web01 : ok=3  changed=2  unreachable=0  failed=0 ...
    ```

    `ok=3`, sest ka faktide kogumine (`Gathering Facts`) loetakse ülesandeks.

## A5 · Teine käivitus

```bash
ansible-playbook -i inventory.ini training.yml
```

??? success "Oodatav tulemus"

    Mõlemad ülesanded `ok`, `changed=0`. Erinevalt Bashi skriptist ei kirjutatud faili üle: kontrolli muutmise aega `ssh web01 stat -c '%y' automation-lab/training.conf`, see ei muutunud.

## A6 · Triiv

```bash
ssh web01 "sed -i 's/enabled=true/enabled=false/' automation-lab/training.conf"
ansible-playbook -i inventory.ini training.yml --check --diff
```

??? success "Oodatav tulemus"

    `--check --diff` näitab muudatust, aga ei tee seda:

    ```
    -enabled=false
    +enabled=true
    changed: [web01]
    ```

Nüüd päriselt ja kontroll:

```bash
ansible-playbook -i inventory.ini training.yml
ssh web01 cat automation-lab/training.conf
```

??? success "Oodatav tulemus"

    `changed` ainult failiülesandel, kaustaülesanne `ok`. Failis on jälle `enabled=true`.

## A7 · Commit

```bash
cd ~/kursus
git add k01/inventory.ini k01/training.yml
git commit -m "k01: inventory ja playbook"
git push
```

??? info "Loe juurde"

    - [Building an inventory](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_inventory.html)
    - [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
    - [`ansible.builtin.file`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/file_module.html), [`ansible.builtin.copy`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/copy_module.html)
    - [Check mode ja diff](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)

**Valmis, kui** teine käivitus annab `changed=0` ja triivi järel taastas playbook õige sisu.
