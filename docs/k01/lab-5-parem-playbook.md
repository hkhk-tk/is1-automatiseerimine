---
tags:
  - Ansible
  - Praktikum
---

# 5. Playbook viiele masinale

!!! abstract "Eesmärgid"

    - kirjutad playbook'i, mis teeb Ubuntul ja Rockyl õiget asja (`when`);
    - valid, millistes masinates töö tehakse (`hosts`, `--limit`);
    - käivitad ainult osa ülesandeid (`tags`).

Kõik käsud käivad control node'il kaustas `~/kursus/k01`.

## A1 · Probleem: sama programm, eri paketinimi

Tekstiredaktor `vim` on Ubuntul pakett `vim`, Rockyl `vim-enhanced`. Üks ülesanne ühe nimega ei tööta mõlemal. Fakt `ansible_facts['os_family']` ütleb, kumb on kumb: Ubuntul `Debian`, Rockyl `RedHat`.

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_os_family'
```

## A2 · `when`: ülesanne ainult õigel distrol

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

    - name: vim on paigaldatud (Rocky)
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

`become: true` play tasemel tähendab, et kõik ülesanded teevad tööd `sudo` kaudu. `when` paneb ülesande käima ainult siis, kui tingimus on tõene.

```bash
ansible-playbook tools.yml --syntax-check
ansible-playbook tools.yml -K
```

??? success "Oodatav tulemus"

    Ubuntu masinatel on Rocky ülesanne `skipping`, Rocky masinatel Ubuntu omad `skipping`. PLAY RECAP reas on `skipped` väljal vahele jäetud ülesannete arv.

Logi mõnda masinasse ja vaata teadet:

```bash
ssh mc01
```

??? success "Oodatav tulemus"

    Sisselogimisel on rida `Seda masinat haldab Ansible.` Logi välja: `exit`.

## A3 · Sihtmasinad

Sama playbook ainult ühe grupi või ühe masina vastu, ilma faili muutmata:

```bash
ansible-playbook tools.yml -K --limit rocky
ansible-playbook tools.yml -K --limit web01
```

??? success "Oodatav tulemus"

    PLAY RECAP näitab ainult valitud masinaid. `--limit` piirab töö ka siis, kui playbook'is on `hosts: all`. Nii proovid muudatust kõigepealt ühel masinal.

## A4 · Sildid

Muuda teadet failis (`content:` rida), näiteks lisa `Küsimused: Maria.` ja käivita ainult sildiga `motd` ülesanne:

```bash
ansible-playbook tools.yml -K --tags motd
```

??? success "Oodatav tulemus"

    Käivitub ainult `Teade sisselogimisel` (ja faktide kogumine). Paketiülesanded jäävad vahele. Viis masinat `changed=1`.

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
