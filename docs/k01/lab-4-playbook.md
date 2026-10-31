---
tags:
  - Ansible
  - Praktikum
---

# 4. Esimene playbook

Ad-hoc käsk sobib kiireks kontrolliks, aga seadistust, mida tahad korrata, hoitakse failis. Selles osas kirjutad päeva ülesande **playbook'ina**, käivitad selle mitu korda ja vaatad, kuidas Ansible taastab käsitsi muudetud faili. Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

!!! abstract "Dokumentatsioonis"

    [Getting started: Creating a playbook](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_playbook.html) · [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)

## A1 · Kirjuta playbook

Playbook kirjeldab sama tulemust, mida skript 2. osas tegi: kaust õigustega `0750` ja selles fail kahe reaga. Erinevus on selles, et iga ülesanne kirjeldab soovitud olekut, mitte käsku. Loo fail `training.yml` (taandeks tühikud, mitte tabulaator):

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

Playbook'is on kaks ülesannet ja kumbki kasutab üht moodulit:

| Moodul | Mida teeb | Parameetrid selles playbook'is |
|---|---|---|
| [`ansible.builtin.file`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/file_module.html) | haldab faili või kausta olemasolu, õigusi ja omanikku | `path`: tee, `state: directory`: see peab olema kaust, `mode`: õigused |
| [`ansible.builtin.copy`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/copy_module.html) | kirjutab faili sisu (failist või tekstist) | `dest`: sihtfail, `content`: faili sisu, `mode`: õigused |

*Tabel 1. Moodulid selles playbook'is.*

Parameetril `state` on veel väärtusi. Vaata käsuga `ansible-doc ansible.builtin.file`, mida tähendavad `absent` ja `touch`.

Enne käivitamist kontrolli süntaksit:

```bash
ansible-playbook training.yml --syntax-check
```

## A2 · Käivita playbook

Kaust ja fail on web01-s juba olemas, sest skript lõi need 2. osas.

**Ennusta:** kas Ansible muudab midagi?

```bash
ansible-playbook training.yml
```

??? success "Oodatav tulemus"

    Mõlema ülesande olek on `ok` ja kokkuvõttes on `changed=0`. Ansible võrdles soovitud olekut tegelikuga ega leidnud erinevust.

Et näha, kuidas Ansible loob puuduva seadistuse, kustuta kaust ja käivita playbook uuesti.

**Ennusta:** mitu ülesannet on nüüd `changed`?

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

## A3 · Korduv käivitus

2. osas kirjutas skript faili igal käivitusel üle. Nüüd kontrolli sama asja playbook'iga.

**Ennusta:** kas faili muutmise aeg muutub?

```bash
ssh web01 stat -c '%y' automation-lab/training.conf
ansible-playbook training.yml
ssh web01 stat -c '%y' automation-lab/training.conf
```

??? success "Oodatav tulemus"

    Kokkuvõttes on `changed=0` ja muutmise aeg jäi samaks. Moodul kontrollis sisu ja jättis faili puutumata, sest see oli juba õige.

## A4 · Käsitsi tehtud muudatus

Kui keegi muudab hallatavat faili käsitsi, erineb masina tegelik olek playbook'is kirjeldatud soovitud olekust. Seda nimetatakse **triiviks** (drift). Tekita triiv ise ja vaata enne parandamist, mida Ansible muudaks. Võti `--check` ei muuda masinas midagi ja `--diff` näitab erinevust.

**Ennusta:** mida näitab `--check --diff` ja kas fail masinas muutub?

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

    Ansible leidis erinevuse, aga failis on endiselt `enabled=false`.

Nüüd rakenda muudatus ja kontrolli faili sisu:

```bash
ansible-playbook training.yml
ssh web01 cat automation-lab/training.conf
```

??? success "Oodatav tulemus"

    `changed` on ainult failiülesandel ja failis on jälle `enabled=true`.

## A5 · Commit

Salvesta `ansible.cfg`, inventory ja playbook repositooriumi ja saada need GitHubi:

```bash
cd ~/kursus
git add k01/ansible.cfg k01/inventory.ini k01/inventory.yml k01/training.yml
git commit -m "k01: ansible.cfg, inventory ja training.yml"
git push
```

**Valmis, kui** korduv käivitus annab `changed=0` ja pärast käsitsi tehtud muudatust taastas playbook faili soovitud oleku.

??? info "Loe juurde"

    - [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
    - [Check mode ja diff](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)
