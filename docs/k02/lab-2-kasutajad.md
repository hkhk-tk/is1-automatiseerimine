---
tags:
  - Ansible
  - Praktikum
---

# 2. Kasutajad

!!! abstract "Eesmärgid"

    - lood kolm kasutajat kõigis viies masinas ühe ülesandega (`loop`);
    - salvestad käsu tulemuse (`register`) ja kasutad seda järgmises ülesandes.

Kõik käsud käivita control node'is kaustas `~/kursus/k02`.

## A1 · `loop`

Fail `users.yml`:

```yaml
- name: Labori kasutajad
  hosts: all
  become: true
  tasks:
    - name: Kasutajad on olemas
      ansible.builtin.user:
        name: "{{ item }}"
        shell: /bin/bash
        state: present
      loop: "{{ labori_kasutajad }}"
```

Nimekiri `labori_kasutajad` tuleb failist `group_vars/all.yml`.

```bash
ansible-playbook users.yml --syntax-check
ansible-playbook users.yml
```

??? success "Oodatav tulemus"

    Iga masina ja kasutaja kohta oma rida:

    ```
    changed: [web01] => (item=anna)
    changed: [web01] => (item=peeter)
    changed: [web01] => (item=mari)
    ...
    ```

    PLAY RECAP-is on igas viies masinas `changed=1`. Tsükliga ülesande tulemus on `changed`, kui vähemalt üks element muutis midagi.

## A2 · `register`

Lisa `users.yml`-i lõppu kaks ülesannet (sama taandega nagu esimene):

```yaml
    - name: Kodukaustade nimekiri
      ansible.builtin.command: ls /home
      register: kodud
      changed_when: false

    - name: Näita kodukaustu
      ansible.builtin.debug:
        msg: "{{ inventory_hostname }}: {{ kodud.stdout_lines | join(', ') }}"
```

```bash
ansible-playbook users.yml
```

??? success "Oodatav tulemus"

    Kasutajate ülesande tulemus on nüüd kõigis masinates `ok`. Debug näitab iga masina kohta näiteks:

    ```
    "msg": "web01: anna, kasutaja, mari, peeter"
    ```

    PLAY RECAP-is on `changed=0`. Rida `changed_when: false` määrab, et `ls` käsu tulemus on alati `ok`.

??? question "Mõtle"

    Kustuta ajutiselt rida `changed_when: false` ja käivita uuesti. Mis muutus PLAY RECAP-is ja miks? Pane rida tagasi.

## A3 · Uus kasutaja

Lisa `group_vars/all.yml`-is nimekirja neljas nimi, näiteks `jaan`. Käivita playbook ainult ühes masinas:

```bash
ansible-playbook users.yml --limit web01
```

??? success "Oodatav tulemus"

    Kolme olemasoleva kasutaja tulemus on `ok`, ainult kasutaja `jaan` tulemus on `changed`. Playbook'i sa ei muutnud, muutus ainult kasutajate nimekiri.

Seejärel käivita playbook ilma `--limit`-ita, et kõigis masinates oleks jälle sama olek.

## A4 · Commit

```bash
cd ~/kursus
git add k02
git commit -m "k02: kasutajad loop'iga"
git push
```

**Valmis, kui** `users.yml` teine käivitus annab kõigil viiel masinal `changed=0`.

??? info "Loe juurde"

    - [Loops](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_loops.html)
    - [`ansible.builtin.user`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/user_module.html)
