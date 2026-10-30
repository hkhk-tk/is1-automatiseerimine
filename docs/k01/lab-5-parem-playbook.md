---
tags:
  - Ansible
  - Praktikum
---

# 5. Playbook viiele masinale

!!! abstract "Eesmärgid"

    - kirjutad playbook'i, mis valib Ubuntu ja AlmaLinuxi jaoks sobivad ülesanded (`when`);
    - valid, millistes masinates playbook käivitatakse (`hosts`, `--limit`);
    - käivitad ainult osa ülesandeid (`tags`).

Kõik käsud käivitad control node'is kaustas `~/kursus/k01`. Fail `tools.yml` on esitamisel kohustuslik. Tingimuste (`when`) ja siltide (`tags`) eest annab automaatne hindaja boonuspunkte.

## A1 · Probleem: sama programm, erinev paketinimi

Tekstiredaktori `vim` pakett on Ubuntus `vim`, AlmaLinuxis `vim-enhanced`. Sama paketinime ei saa siin kasutada mõlema distributsiooni puhul. Fakt `ansible_facts['os_family']` näitab, millisesse distributsioonide perekonda masin kuulub: Ubuntus on see `Debian`, AlmaLinuxis `RedHat`.

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_os_family'
```

## A2 · `when`: ülesande käivitamine vastavalt distributsioonile

Loo fail `tools.yml`:

```yaml
- name: Tööriistad
  hosts: all
  become: true
  tasks:
    - name: Ubuntu paketiloend on värske
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600
      when: ansible_facts['os_family'] == "Debian"
      tags: paketid

    - name: vim on paigaldatud (Ubuntu)
      ansible.builtin.package:
        name: vim
        state: present
      when: ansible_facts['os_family'] == "Debian"
      tags: paketid

    - name: vim on paigaldatud (AlmaLinux)
      ansible.builtin.package:
        name: vim-enhanced
        state: present
      when: ansible_facts['os_family'] == "RedHat"
      tags: paketid

    - name: Teade sisselogimisel
      ansible.builtin.copy:
        dest: /etc/motd
        content: "Seda masinat haldab Ansible.\n"
        mode: "0644"
      tags: motd
```

Kui `become: true` on play tasemel, käivitatakse kõik ülesanded `sudo` kaudu. `when` määrab tingimuse, mille korral ülesanne käivitatakse.

```bash
ansible-playbook tools.yml --syntax-check
ansible-playbook tools.yml
```

??? success "Oodatav tulemus"

    Ubuntu masinates on AlmaLinuxi ülesande olek `skipping` ja AlmaLinuxi masinates on Ubuntu ülesannete olek `skipping`. PLAY RECAP real näitab väli `skipped` vahele jäetud ülesannete arvu.

Logi mõnda masinasse sisse ja vaata sisselogimisel kuvatavat teadet:

```bash
ssh mc01
```

??? success "Oodatav tulemus"

    Sisselogimisel kuvatakse rida `Seda masinat haldab Ansible.` Logi välja käsuga `exit`.

## A3 · Sihtmasinad

`--limit` võimaldab sama playbook'i käivitada ainult valitud grupis või masinas, ilma playbook'i muutmata:

```bash
ansible-playbook tools.yml --limit alma
ansible-playbook tools.yml --limit web01
```

??? success "Oodatav tulemus"

    PLAY RECAP näitab ainult valitud masinaid. `--limit` piirab käivitamise ka siis, kui playbook'is on `hosts: all`. Nii saad muudatust enne kõigisse masinatesse rakendamist proovida näiteks ühes masinas.

## A4 · Sildid

Muuda playbook'is teate teksti (rida `content:`), näiteks lisa `Küsimused: IT-tugi.`, ja käivita ainult sildiga `motd` ülesanne:

```bash
ansible-playbook tools.yml --tags motd
```

??? success "Oodatav tulemus"

    Käivitub ainult ülesanne `Teade sisselogimisel` ja faktide kogumine. Paketiülesanded jäävad vahele. Kõigi viie masina kokkuvõttes on `changed=1`.

```bash
ansible-playbook tools.yml --list-tags
```

## A5 · Commit

```bash
cd ~/kursus
git add k01/tools.yml
git commit -m "k01: tools.yml when, limit ja tags"
git push
```

**Valmis, kui** `tools.yml` teine käivitus annab kõigil viiel masinal `changed=0`.

??? info "Loe juurde"

    - [Conditionals (`when`)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_conditionals.html)
    - [Tags](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_tags.html)
    - [Patterns: targeting hosts and groups](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_patterns.html)
    - [Understanding privilege escalation: become](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_privilege_escalation.html)
