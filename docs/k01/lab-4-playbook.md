---
tags:
  - Ansible
  - Praktikum
---

# 4. Esimene playbook

Kirjutad päeva ülesande playbook'ina, käivitad selle korduvalt ja vaatad, kuidas Ansible parandab käsitsi tehtud muudatuse. Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

## A1 · Playbook

Loo fail `training.yml`. Kasuta taandeks tühikuid, mitte tabulaatorit:

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

Enne käivitamist ennusta tulemust. Kaust ja fail on eelmisest ülesandest juba olemas ning vastavad nõuetele. Kas Ansible muudab midagi?

```bash
ansible-playbook training.yml
```

??? success "Oodatav tulemus"

    Mõlema ülesande olek on `ok` ja kokkuvõttes on `changed=0`. Ansible võrdles soovitud olekut masina tegeliku olekuga ega leidnud erinevust.

Eemalda masinast web01 kaust `automation-lab` ja käivita playbook uuesti:

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

    Kokkuvõttes on `ok=3`, sest ka faktide kogumine (`Gathering Facts`) loetakse ülesandeks.

## A3 · Teine käivitus

```bash
ssh web01 stat -c '%y' automation-lab/training.conf
ansible-playbook training.yml
ssh web01 stat -c '%y' automation-lab/training.conf
```

??? success "Oodatav tulemus"

    Kokkuvõttes on `changed=0` ja faili muutmise aeg jäi samaks. Erinevalt skriptist ei kirjutanud Ansible faili üle.

## A4 · Triiv

**Triiv (drift)** tähendab, et masina tegelik olek erineb konfiguratsioonis kirjeldatud soovitud olekust.

Muuda faili käsitsi ja kontrolli enne playbook'i käivitamist, millise muudatuse Ansible tuvastab:

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

    Võti `--check` ei muutnud masinas midagi ja `--diff` näitas erinevust.

Rakenda muudatus ja kontrolli tulemust:

```bash
ansible-playbook training.yml
ssh web01 cat automation-lab/training.conf
```

??? success "Oodatav tulemus"

    Olek `changed` on ainult failiülesandel. Failis on jälle `enabled=true`.

## A5 · Commit

```bash
cd ~/kursus
git add k01/ansible.cfg k01/inventory.ini k01/training.yml
git commit -m "k01: ansible.cfg, inventory ja training.yml"
git push
```

**Valmis, kui** teine käivitus annab `changed=0` ja pärast käsitsi tehtud muudatust taastas playbook faili soovitud oleku.

??? info "Loe juurde"

    - [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
    - [`ansible.builtin.file`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/file_module.html), [`ansible.builtin.copy`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/copy_module.html)
    - [Check mode ja diff](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)
