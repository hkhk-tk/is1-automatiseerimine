---
tags:
  - Ansible
  - Praktikum
---

# 6. Muutujad ja grupimuutujad

5. osas lahendasid distributsioonide erinevuse tingimusega `when`: iga paketinime jaoks oli eraldi ülesanne. Kui erinevusi on palju, kasvab playbook kiiresti. Parem lahendus on hoida playbook ühesugune ja panna erinevused muutujatesse, mille väärtus sõltub masina grupist inventory's.

Selles osas kirjutad playbook'i `haldus.yml`, mis loob kõigisse masinatesse kaks administraatori kontot ja hoiab käigus teenuse cron. Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

## A1 · Muutuja ja tsükkel

Muutuja defineeritakse play osas `vars` ja seda kasutatakse kujul `{{ muutuja }}`. Kui muutuja väärtus on loend, käivitab võti `loop` sama ülesande iga loendi elemendiga. Jooksev element on muutujas `item`.

Loo fail `haldus.yml`:

```yaml
- name: Haldus
  hosts: all
  become: true
  vars:
    haldurid:
      - ops1
      - ops2
  tasks:
    - name: Haldurid on olemas
      ansible.builtin.user:
        name: "{{ item }}"
        groups: sudo
        append: true
        shell: /bin/bash
      loop: "{{ haldurid }}"
```

| Moodul | Mida teeb | Parameetrid |
|---|---|---|
| [`ansible.builtin.user`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/user_module.html) | loob kasutaja või muudab olemasolevat | `name`: kasutajanimi, `groups`: lisagrupid, `append: true`: lisa gruppidesse, ära eemalda teistest, `shell`: sisselogimise kest |

*Tabel 1. Moodul `user`.*

Kui muutuja väärtus on rea alguses, peab see olema jutumärkides (`"{{ item }}"`), sest muidu loeb YAML loogelist sulgu sõnastiku alguseks.

**Ennusta:** grupp `sudo` on Ubuntus olemas. Mis juhtub AlmaLinuxi masinates mc01 ja db01?

```bash
ansible-playbook haldus.yml
```

??? success "Oodatav tulemus"

    Ubuntu masinates on ülesanne `changed`. Masinates mc01 ja db01 on see `failed` veaga `Group sudo does not exist`. AlmaLinuxis on administraatorite grupp `wheel`.

## A2 · Grupimuutujad

Inventory's on grupid `ubuntu` ja `alma`. Kui kaustas `group_vars` on grupi nimega fail, loeb Ansible sealt selle grupi kõigi masinate muutujad. Kaust peab asuma inventory faili kõrval.

```bash
mkdir group_vars
```

Loo fail `group_vars/ubuntu.yml`:

```yaml
admin_grupp: sudo
```

ja fail `group_vars/alma.yml`:

```yaml
admin_grupp: wheel
```

Kontrolli, millise väärtuse iga masin saab:

```bash
ansible all -m ansible.builtin.debug -a var=admin_grupp
ansible-inventory --graph --vars
```

Moodul `debug` ei muuda masinas midagi, vaid näitab muutuja väärtust. `ansible-inventory --graph --vars` näitab gruppe, masinaid ja kõigi muutujate väärtusi, ka faili `inventory.ini` muutujat `ansible_user`.

Asenda playbook'is `groups: sudo` reaga `groups: "{{ admin_grupp }}"` ja käivita playbook kaks korda:

```bash
ansible-playbook haldus.yml
ansible-playbook haldus.yml
ansible all -a "id ops1"
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on mc01 ja db01 ülesanne `changed`, Ubuntu masinates `ok`, sest seal olid kasutajad juba olemas. Teisel käivitusel on kõigis masinates `changed=0`. `id ops1` näitab Ubuntus gruppi `sudo`, AlmaLinuxis gruppi `wheel`.

## A3 · Muutuja kõigile masinatele

Haldurite loend on praegu playbook'is. Kui sama loendit vajab ka mõni teine playbook, tuleb see viia inventory juurde. Fail `group_vars/all.yml` kehtib kõigile masinatele.

Tõsta osa `vars` playbook'ist faili `group_vars/all.yml`:

```yaml
haldurid:
  - ops1
  - ops2
```

**Ennusta:** muutuja asukoht muutus, kasutajad mitte. Mida näitab käivituse kokkuvõte?

```bash
ansible-playbook haldus.yml
```

??? success "Oodatav tulemus"

    Kõigis masinates on `changed=0`. Ansible võrdleb masina tegelikku olekut soovitud olekuga. Kust muutuja väärtus tuli, ei ole selle jaoks oluline.

Kui sama muutuja on defineeritud mitmes kohas, kehtib täpsem: `group_vars/ubuntu.yml` on tähtsam kui `group_vars/all.yml` ja play `vars` on tähtsam kui mõlemad. Kogu järjekord on dokumentatsioonis [Variable precedence](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence).

## A4 · Teenus

Cron käivitab ajastatud ülesandeid. Ka siin erinevad distributsioonid:

| | Ubuntu | AlmaLinux |
|---|---|---|
| pakett | `cron` | `cronie` |
| teenus | `cron` | `crond` |

*Tabel 2. Cron'i pakett ja teenus.*

Lisa grupimuutujate failidesse muutujad `cron_pakett` ja `cron_teenus` ning playbook'i kaks ülesannet: üks paigaldab paketi, teine hoiab teenuse käigus ja lülitab selle alglaadimisel sisse. Kumbki ülesanne peab töötama mõlemas distributsioonis ilma võtmeta `when`.

| Moodul | Mida teeb | Parameetrid |
|---|---|---|
| [`ansible.builtin.package`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/package_module.html) | paigaldab paketi | `name`, `state: present` |
| [`ansible.builtin.service`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/service_module.html) | haldab teenust | `name`, `state: started`: teenus töötab, `enabled: true`: käivitub alglaadimisel |

*Tabel 3. Moodulid `package` ja `service`.*

```bash
ansible-playbook haldus.yml --check --diff
ansible-playbook haldus.yml
ansible-playbook haldus.yml
ansible all -a "systemctl is-active {{ cron_teenus }}"
```

Viimases käsus asendab Ansible muutuja enne käsu saatmist, nii et iga masin saab oma teenuse nime.

??? success "Oodatav tulemus"

    Teisel käivitusel on kõigis masinates `changed=0`. Viimane käsk vastab igas masinas `active`. Labori masinates on cron tavaliselt juba paigaldatud ja käigus, seega võivad ülesanded olla kohe `ok`.

??? tip "Lahendus"

    ```yaml
        - name: cron on paigaldatud
          ansible.builtin.package:
            name: "{{ cron_pakett }}"
            state: present

        - name: cron töötab ja käivitub alglaadimisel
          ansible.builtin.service:
            name: "{{ cron_teenus }}"
            state: started
            enabled: true
    ```

## A5 · Commit

```bash
cd ~/kursus
git add k01/haldus.yml k01/group_vars
git commit -m "k01: haldus.yml grupimuutujatega"
git push
```

**Valmis, kui** `haldus.yml` korduv käivitus annab kõigis viies masinas `changed=0`, playbook'is ei ole võtit `when` ja kaust `group_vars` on GitHubis.

??? info "Loe juurde"

    - [Using variables](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html)
    - [Organizing host and group variables](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html#organizing-host-and-group-variables)
    - [Loops](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_loops.html)
