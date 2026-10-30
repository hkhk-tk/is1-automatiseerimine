---
tags:
  - Ansible
  - Vault
  - Praktikum
---

# 3. Andmebaas

Andmebaas on teiste teenuste alus, seega alustad sellest. Selles osas paigaldad db01-sse MariaDB, kasutad Ansible'iga kaasa mitte tulevaid mooduleid (**kogu**), hoiad paroole krüpteeritult (**Vault**) ja muudad konfiguratsiooni nii, et teenus taaskäivitatakse ainult siis, kui konfiguratsioon muutus (**handler**).

!!! abstract "Dokumentatsioonis"

    [Using collections](https://docs.ansible.com/projects/ansible/latest/collections_guide/index.html) · [Ansible Vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html) · [Handlers](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html)

## A1 · Kogud

Andmebaasi ja RabbitMQ kasutajate haldamise moodulid ei ole `ansible-core`'is, vaid eraldi **kogudes** (collections). Fail `requirements.yml` loetleb vajalikud kogud koos versioonidega, et kõigil oleks sama komplekt. Loo fail `requirements.yml`:

```yaml
collections:
  - name: ansible.posix
    version: 1.6.2
  - name: community.mysql
    version: 3.12.0
  - name: community.rabbitmq
    version: 1.4.0
```

```bash
ansible-galaxy collection install -r requirements.yml
ansible-doc community.mysql.mysql_user | head -30
```

Kogu `ansible.posix` sisaldab tulemüüri moodulit, `community.mysql` andmebaasi ja `community.rabbitmq` RabbitMQ mooduleid.

## A2 · Paroolid Vaulti

Rakendus vajab kolme saladust: andmebaasi parooli, RabbitMQ parooli ja koolitaja tokenit. Need ei tohi Gitis olla avatekstina. **Ansible Vault** krüpteerib faili parooliga. Vaulti parool on failis väljaspool repositooriumi ja `ansible.cfg` ütleb, kust see võtta:

```bash
mkdir -p ~/.config/is1
read -rsp "Vaulti parool: " p && printf '%s\n' "$p" > ~/.config/is1/vault_pass && unset p
chmod 600 ~/.config/is1/vault_pass
echo "vault_password_file = ~/.config/is1/vault_pass" >> ansible.cfg
```

Loo krüpteeritud fail. Käsk avab redaktori, kirjuta sinna kolm rida oma paroolidega ja salvesta:

```bash
ansible-vault create group_vars/all/vault.yml
```

```yaml
vault_db_password: "<andmebaasi parool>"
vault_rabbitmq_password: "<RabbitMQ parool>"
vault_teacher_token: "<token koolitajalt>"
```

Lisa faili `group_vars/all/main.yml` read, mis seovad saladused rollides kasutatavate nimedega:

```yaml
labseis_db_password: "{{ vault_db_password }}"
labseis_mq_password: "{{ vault_rabbitmq_password }}"
labseis_teacher_token: "{{ vault_teacher_token }}"
```

![Vault: saladus vault.yml-is, nimi main.yml-is, kasutus mallis](assets/k02_vault_vahekiht.svg){ width="720" }

*Joonis 1. `main.yml` on loetav ja näitab, millised saladused on olemas. Väärtused on ainult krüpteeritud failis.*

Kontrolli, et fail on krüpteeritud ja Ansible saab selle lahti:

```bash
head -1 group_vars/all/vault.yml
ansible db01 -m ansible.builtin.debug -a "var=labseis_db_name"
```

Esimene rida on `$ANSIBLE_VAULT;1.1;AES256`. Sisu näed käsuga `ansible-vault view group_vars/all/vault.yml`, muudad käsuga `ansible-vault edit`.

## A3 · MariaDB paigaldus

Roll `mariadb` ehitatakse kolmes sammus ja iga samm proovitakse kohe läbi. Loo kaustad ja esimene osa ülesannetest:

```bash
mkdir -p roles/mariadb/tasks roles/mariadb/templates roles/mariadb/defaults roles/mariadb/handlers
```

Rolli vaikeväärtused on AlmaLinuxi omad, sest andmebaas on db01-s. Paketinimed, konfiguratsioonifailide kaust ja MariaDB sokli tee erinevad distributsiooniti, seepärast on need muutujates. Kui rolli on vaja Ubuntus, kirjutad need üle failis `group_vars/ubuntu.yml`, nagu tegid 1. kohtumisel, ja roll jääb samaks.

Fail `roles/mariadb/defaults/main.yml`:

```yaml
mariadb_port: 3306

# AlmaLinuxi väärtused. Teises distributsioonis kirjuta need üle grupimuutujatega.
mariadb_paketid:
  - mariadb-server
  - python3-PyMySQL
mariadb_conf_dir: /etc/my.cnf.d
mariadb_socket: /var/lib/mysql/mysql.sock
```

Pakett `python3-PyMySQL` on vajalik, sest kogu `community.mysql` moodulid ühenduvad andmebaasiga Pythoni kaudu.

Fail `roles/mariadb/tasks/main.yml`, esimene osa:

```yaml
- name: MariaDB ja Pythoni teek on paigaldatud
  ansible.builtin.package:
    name: "{{ mariadb_paketid }}"
    state: present

- name: MariaDB töötab ja käivitub koos masinaga
  ansible.builtin.service:
    name: mariadb
    state: started
    enabled: true

- name: Tulemüür lubab andmebaasi pordi
  ansible.posix.firewalld:
    port: "{{ mariadb_port }}/tcp"
    permanent: true
    immediate: true
    state: enabled
  when: ansible_facts['os_family'] == "RedHat"
```

| Moodul | Mida teeb | Parameetrid |
|---|---|---|
| [`ansible.builtin.package`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/package_module.html) | paigaldab paketid distributsiooni paketihalduriga | `name`: pakett või paketiloend, `state: present` |
| [`ansible.builtin.service`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/service_module.html) | teenuse olek | `state: started`, `enabled: true` (käivitub koos masinaga) |
| [`ansible.posix.firewalld`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/posix/firewalld_module.html) | AlmaLinuxi tulemüür | `port`, `permanent` (jääb alles taaskäivitusel), `immediate` (kehtib kohe) |

*Tabel 1. Moodulid rolli esimeses osas.*

Tulemüüri ülesandes on tingimus `when`, sest `firewalld` on ainult AlmaLinuxis. Ubuntus jääb ülesanne vahele. See on teistsugune olukord kui paketinimed: ülesanne ei ole teises distributsioonis teise nimega, vaid seda pole seal vaja.

Lisa `site.yml`-i play:

```yaml
- name: Andmebaas
  hosts: db
  become: true
  roles:
    - mariadb
```

```bash
ansible-playbook site.yml --limit db01
ssh db01 systemctl is-active mariadb
```

## A4 · Konfiguratsioon ja handler

Vaikimisi kuulab MariaDB ainult kohalikke ühendusi, aga rakendus ühendub app01-st. Konfiguratsioonifail tehakse mallist. Kui fail muutub, tuleb MariaDB taaskäivitada, aga ainult siis. Selleks on **handler**: ülesanne, mis käivitub play lõpus ainult siis, kui mõni ülesanne teatas sellest võtmega `notify` ja tegi muudatuse.

Fail `roles/mariadb/templates/60-labseis.cnf.j2`:

```ini
# {{ ansible_managed }}
[mysqld]
bind-address = 0.0.0.0
port = {{ mariadb_port }}
```

Fail `roles/mariadb/handlers/main.yml` (esimene handler):

```yaml
- name: Restart mariadb
  ansible.builtin.service:
    name: mariadb
    state: restarted
```

Lisa `tasks/main.yml`-i paigaldusülesannete järele (enne teenuse ülesannet):

```yaml
- name: MariaDB kuulab kõigil liidestel
  ansible.builtin.template:
    src: 60-labseis.cnf.j2
    dest: "{{ mariadb_conf_dir }}/60-labseis.cnf"
    mode: "0644"
  notify: Restart mariadb
```

Moodul [`ansible.builtin.template`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/template_module.html) teeb mallist faili masinas. `{{ ansible_managed }}` lisab faili algusesse märke, et faili haldab Ansible.

**Ennusta:** kas handler käivitub esimesel ja teisel käivitusel?

```bash
ansible-playbook site.yml --limit db01
ansible-playbook site.yml --limit db01
ssh db01 ss -tln | grep 3306
```

??? success "Oodatav tulemus"

    Esimesel käivitusel loob mall faili ja väljundis on `RUNNING HANDLER [mariadb : Restart mariadb]`. Teisel käivitusel fail ei muutu ja handler ei käivitu. MariaDB kuulab aadressil `0.0.0.0:3306`.

## A5 · Andmebaas, kasutaja ja skeem

Viimases sammus loob roll andmebaasi ja rakenduse kasutaja ning laadib tabelid. Tabelid laaditakse ainult siis, kui andmebaas just loodi, muidu kirjutaks iga käivitus andmed üle. Seepärast on laadimine handler, mida teavitab andmebaasi loomise ülesanne.

Lisa `tasks/main.yml`-i lõppu:

```yaml
- name: Muudatused rakenduvad enne andmebaasi seadistamist
  ansible.builtin.meta: flush_handlers

- name: Andmebaas on olemas
  community.mysql.mysql_db:
    name: "{{ labseis_db_name }}"
    encoding: utf8mb4
    state: present
    login_unix_socket: "{{ mariadb_socket }}"
  notify: Load schema

- name: Rakenduse kasutaja on olemas
  community.mysql.mysql_user:
    name: "{{ labseis_db_user }}"
    host: "%"
    password: "{{ labseis_db_password }}"
    priv: "{{ labseis_db_name }}.*:ALL"
    state: present
    login_unix_socket: "{{ mariadb_socket }}"
  no_log: true

- name: Skeem ja algandmed on kopeeritud
  ansible.builtin.copy:
    src: "{{ playbook_dir }}/../db/{{ item }}"
    dest: "/root/{{ item }}"
    mode: "0600"
  loop:
    - schema.sql
    - seed.sql
```

Lisa faili `handlers/main.yml` teine handler:

```yaml
- name: Load schema
  community.mysql.mysql_db:
    name: "{{ labseis_db_name }}"
    state: import
    target: "/root/{{ item }}"
    login_unix_socket: "{{ mariadb_socket }}"
  loop:
    - schema.sql
    - seed.sql
```

| Moodul või võti | Mida teeb |
|---|---|
| [`community.mysql.mysql_db`](https://docs.ansible.com/projects/ansible/latest/collections/community/mysql/mysql_db_module.html) | loob andmebaasi (`state: present`) või laadib SQL-faili (`state: import`) |
| [`community.mysql.mysql_user`](https://docs.ansible.com/projects/ansible/latest/collections/community/mysql/mysql_user_module.html) | loob kasutaja; `host: "%"` lubab ühenduse teisest masinast, `priv` annab õigused |
| `login_unix_socket` | moodul ühendub MariaDB-ga kohaliku sokli kaudu juurkasutajana, parooli pole vaja |
| `meta: flush_handlers` | käivitab ootel handlerid kohe, et MariaDB oleks uue konfiguratsiooniga enne andmebaasi loomist |
| `no_log: true` | ülesande väljundis ei näidata parooli |

*Tabel 2. Moodulid ja võtmed rolli viimases osas.*

SQL-failid on sinu repositooriumi kaustas `db/`, seega on tee `{{ playbook_dir }}/../db/`.

```bash
ansible-playbook site.yml --limit db01
ansible db -b -m ansible.builtin.command -a "mysql -N -e 'SELECT COUNT(*) FROM labseis.student'"
```

??? success "Oodatav tulemus"

    Väljundis on `RUNNING HANDLER [mariadb : Load schema]` ja päring tagastab algandmete õppijate arvu (suurem kui 0).

Salvesta töö:

```bash
git add -A
git commit -m "k02: roll mariadb, Vault"
git push
```

**Valmis, kui** andmebaasis on tabelid ja algandmed, `vault.yml` algab reaga `$ANSIBLE_VAULT` ja teine käivitus ei käivita ühtegi handlerit.

??? info "Loe juurde"

    - [Using collections](https://docs.ansible.com/projects/ansible/latest/collections_guide/index.html)
    - [Protecting sensitive data with Ansible Vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html)
    - [Handlers](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html)
