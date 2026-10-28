---
tags:
  - Ansible
  - Praktikum
---

# 4. Esimene playbook

!!! abstract "Eesmärgid"

    - kirjutad päeva ülesande playbook'ina;
    - näed teisel käivitusel `changed=0`;
    - parandad käsitsi tehtud muudatuse ja vaatad muudatust enne `--check --diff`-iga.

Kõik käsud käivad control node'il kaustas `~/kursus/k01`.

## A1 · Playbook

Loo fail `training.yml`. Taane on tühikutega, mitte tabulaatoriga:

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

Kontrolli enne käivitamist:

```bash
ansible-playbook training.yml --syntax-check
```

## A2 · Esimene käivitus

Ennusta enne: kaust ja fail on skripti osast juba olemas ja õiged. Mida Ansible teeb?

```bash
ansible-playbook training.yml
```

??? success "Oodatav tulemus"

    Mõlemad ülesanded `ok`, kokkuvõttes `changed=0`. Ansible võrdles soovitud ja tegelikku seisu ning erinevust polnud.

Eemalda kaust ja käivita uuesti:

```bash
ssh web01 rm -r automation-lab
ansible-playbook training.yml
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

## A3 · Teine käivitus

```bash
ssh web01 stat -c '%y' automation-lab/training.conf
ansible-playbook training.yml
ssh web01 stat -c '%y' automation-lab/training.conf
```

??? success "Oodatav tulemus"

    `changed=0` ja muutmise aeg on sama. Erinevalt skriptist ei kirjutanud Ansible faili üle.

## A4 · Triiv

Muuda faili käsitsi, nagu teeks kolleeg öösel, ja vaata enne, mida Ansible muudaks:

```bash
ssh web01 "sed -i 's/enabled=true/enabled=false/' automation-lab/training.conf"
ansible-playbook training.yml --check --diff
```

??? success "Oodatav tulemus"

    ```
    -enabled=false
    +enabled=true
    changed: [web01]
    ```

    `--check` ei muutnud midagi, `--diff` näitas erinevust.

Nüüd päriselt ja kontroll:

```bash
ansible-playbook training.yml
ssh web01 cat automation-lab/training.conf
```

??? success "Oodatav tulemus"

    `changed` ainult failiülesandel. Failis on jälle `enabled=true`.

## A5 · Commit

```bash
cd ~/kursus
git add k01/ansible.cfg k01/inventory.ini k01/training.yml
git commit -m "k01: ansible.cfg, inventory ja training.yml"
git push
```

**Valmis, kui** teine käivitus annab `changed=0` ja triivi järel taastas playbook õige sisu.

??? info "Loe juurde"

    - [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
    - [`ansible.builtin.file`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/file_module.html), [`ansible.builtin.copy`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/copy_module.html)
    - [Check mode ja diff](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)
