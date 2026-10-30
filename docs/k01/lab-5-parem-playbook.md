---
tags:
  - Ansible
  - Praktikum
---

# 5. Playbook viiele masinale

Seni käis playbook ainult ühes masinas. Nüüd kirjutad playbook'i, mis paigaldab tööriistad kõigisse viide masinasse, kuigi neis on kaks eri distributsiooni. Lisaks õpid käivitama playbook'i ainult osas masinatest (`--limit`) ja ainult osa ülesandeid (`tags`). Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

!!! abstract "Dokumentatsioonis"

    [Conditionals](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_conditionals.html) · [Patterns (`--limit`)](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_patterns.html) · [Tags](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_tags.html) · [Privilege escalation (`become`)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_privilege_escalation.html)

## A1 · Probleem: sama programm, erinev paketinimi

Tekstiredaktori vim pakett on Ubuntus `vim`, AlmaLinuxis aga `vim-enhanced`. Üks ülesanne kindla paketinimega ei sobi seega mõlemale distributsioonile. Ansible'i faktidest näed, millisesse distributsioonide perekonda masin kuulub:

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_os_family'
```

Ubuntus on väärtus `Debian`, AlmaLinuxis `RedHat`. Selle järgi saab ülesannet käivitada ainult sobivas masinas.

## A2 · Tingimus `when`

Võti `when` määrab tingimuse, mille korral ülesanne käivitatakse. Kui tingimus ei ole tõene, jäetakse ülesanne vahele ja selle olek on `skipping`. Loo fail `tools.yml`:

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

Rida `become: true` play tasemel tähendab, et kõik ülesanded käivitatakse `sudo` kaudu, sest pakette paigaldada ja `/etc` all faile muuta saab ainult administraator. Playbook'is on kolm moodulit:

| Moodul | Mida teeb | Parameetrid selles playbook'is |
|---|---|---|
| [`ansible.builtin.apt`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/apt_module.html) | Ubuntu (Debiani) paketihaldur | `update_cache: true`: uuenda paketiloendit, `cache_valid_time: 3600`: jäta uuendamine vahele, kui loend on alla tunni vana |
| [`ansible.builtin.package`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/package_module.html) | paigaldab paketi distributsiooni paketihalduriga | `name`: paketi nimi, `state: present`: pakett peab olemas olema |
| [`ansible.builtin.copy`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/copy_module.html) | kirjutab faili sisu | `dest`: sihtfail, `content`: sisu, `mode`: õigused |

*Tabel 1. Moodulid selles playbook'is.*

`when` ja `tags` ei ole mooduli parameetrid, vaid ülesande võtmesõnad. Seepärast on nad samal taandel kui mooduli nimi. Kui tahad teada, miks `cache_valid_time` on kasulik, vaata `ansible-doc ansible.builtin.apt`.

**Ennusta:** millised ülesanded jäävad Ubuntu masinates vahele ja millised AlmaLinuxi masinates?

```bash
ansible-playbook tools.yml --syntax-check
ansible-playbook tools.yml
```

??? success "Oodatav tulemus"

    Ubuntu masinates on AlmaLinuxi ülesande olek `skipping`, AlmaLinuxi masinates Ubuntu kahe ülesande olek `skipping`. PLAY RECAP real näitab väli `skipped`, mitu ülesannet jäi vahele.

Teade `/etc/motd` kuvatakse sisselogimisel. Kontrolli seda mõnes masinas:

```bash
ssh mc01
```

Sisselogimisel on ekraanil rida `Seda masinat haldab Ansible.` Logi välja käsuga `exit`.

## A3 · Ainult osa masinatest: `--limit`

Muudatust on ohutum proovida kõigepealt ühes masinas või grupis. Võti `--limit` käivitab playbook'i ainult valitud masinates, ilma et playbook'is peaks rida `hosts: all` muutma. Võti `--list-hosts` näitab enne käivitamist, millised masinad valikusse jäävad, midagi käivitamata:

```bash
ansible-playbook tools.yml --limit alma --list-hosts
ansible-playbook tools.yml --limit alma
ansible-playbook tools.yml --limit web01
```

??? success "Oodatav tulemus"

    PLAY RECAP näitab ainult valitud masinaid: esimesel korral mc01 ja db01, teisel korral web01.

## A4 · Ainult osa ülesandeid: sildid

**Silt** (`tags`) on ülesandele antud nimi. Võtmega `--tags` käivitad ainult nende siltidega ülesanded. Kui muudad ainult sisselogimise teadet, ei ole vaja paketiülesandeid uuesti läbi käia. Playbook'is on kaks silti, `paketid` ja `motd`. Kõik playbook'i sildid näed käsuga:

```bash
ansible-playbook tools.yml --list-tags
ansible-playbook tools.yml --list-tasks
```

Teine käsk näitab kõiki ülesandeid koos siltidega. Pika playbook'i puhul on sellest abi, kui tahad teada, mis järjekorras ülesanded käivituvad.

Muuda playbook'is teate teksti (rida `content:`), näiteks lisa `Küsimused: IT-tugi.`, ja käivita ainult sildiga `motd` ülesanne.

**Ennusta:** millised ülesanded käivituvad ja mitu on `changed`?

```bash
ansible-playbook tools.yml --tags motd
```

??? success "Oodatav tulemus"

    Käivituvad ainult faktide kogumine ja ülesanne `Teade sisselogimisel`. Kõigi viie masina kokkuvõttes on `changed=1`.

Kui playbook katkes keskel, ei pea seda algusest käivitama. Võti `--start-at-task` alustab nimetatud ülesandest ja `--step` küsib iga ülesande eel, kas see käivitada: `y` jah, `n` ei (vaikimisi), `c` jätka edasi küsimata. Esimene küsimus on faktide kogumise kohta, vasta `y` või `c`, sest ilma faktideta ei tööta tingimused `when`:

```bash
ansible-playbook tools.yml --start-at-task "Teade sisselogimisel" --step
```

Kõik käsurea võtmed on lehel [Ansible CLI cheatsheet](https://docs.ansible.com/projects/ansible/latest/command_guide/cheatsheet.html).

## A5 · Korduv käivitus ja commit

Lõpuks kontrolli, et kogu playbook on idempotentne.

**Ennusta:** kõik paketid on paigaldatud ja teade on olemas. Mida näitab playbook'i käivitus nüüd?

```bash
ansible-playbook tools.yml
```

??? success "Oodatav tulemus"

    Kõigi viie masina kokkuvõttes on `changed=0`.

Salvesta playbook repositooriumi ja saada see GitHubi:

```bash
cd ~/kursus
git add k01/tools.yml
git commit -m "k01: tools.yml when, limit ja tags"
git push
```

**Valmis, kui** `tools.yml` korduv käivitus annab kõigil viiel masinal `changed=0` ja fail on GitHubis.

??? info "Loe juurde"

    - [Conditionals (`when`)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_conditionals.html)
    - [Tags](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_tags.html)
    - [Patterns: targeting hosts and groups](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_patterns.html)
