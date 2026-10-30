---
tags:
  - Ansible
  - Praktikum
---

# 5. Playbook viiele masinale

Kirjutad playbook'i, mis töötab nii Ubuntus kui ka AlmaLinuxis (`when`), ja käivitad selle ainult osas masinatest (`--limit`) või ainult osa ülesannetega (`tags`). Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

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

| Moodul | Mida teeb | Parameetrid selles playbook'is |
|---|---|---|
| [`ansible.builtin.apt`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/apt_module.html) | Ubuntu (Debiani) paketihaldur | `update_cache: true`: uuenda paketiloendit, `cache_valid_time: 3600`: jäta uuendamine vahele, kui loend on alla tunni vana |
| [`ansible.builtin.package`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/package_module.html) | paigaldab paketi distributsiooni paketihalduriga | `name`: paketi nimi, `state: present`: pakett peab olemas olema |
| [`ansible.builtin.copy`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/copy_module.html) | kirjutab faili sisu | `dest`: sihtfail, `content`: sisu, `mode`: õigused |

*Tabel 1. Moodulid selles playbook'is.*

`when` ja `tags` ei ole mooduli parameetrid, vaid ülesande võtmesõnad: need on samal taandel kui mooduli nimi. Kontrolli ise, mida teeb `cache_valid_time`:

```bash
ansible-doc ansible.builtin.apt
```

Kui `become: true` on play tasemel, käivitatakse kõik ülesanded `sudo` kaudu. `when` määrab tingimuse, mille korral ülesanne käivitatakse.

**Ennusta:** millised ülesanded jäävad Ubuntu masinates vahele (`skipping`) ja millised AlmaLinuxi masinates?

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

**Silt** (`tags`) on ülesandele antud nimi. Võtmega `--tags` käivitad ainult nende siltidega ülesanded. Kui muutsid ainult sisselogimise teadet, ei ole vaja paketiülesandeid uuesti käivitada. Playbook'is on kaks silti: `paketid` ja `motd`. Kõik playbook'i sildid näed käsuga:

```bash
ansible-playbook tools.yml --list-tags
```

Muuda playbook'is teate teksti (rida `content:`), näiteks lisa `Küsimused: IT-tugi.`, ja käivita ainult sildiga `motd` ülesanne.

**Ennusta:** millised ülesanded käivituvad ja mitu on `changed`?

```bash
ansible-playbook tools.yml --tags motd
```

??? success "Oodatav tulemus"

    Käivitub ainult ülesanne `Teade sisselogimisel` ja faktide kogumine. Paketiülesanded jäävad vahele. Kõigi viie masina kokkuvõttes on `changed=1`.

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
