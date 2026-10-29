---
tags:
  - Ansible
  - MariaDB
  - Praktikum
---

# 4. Andmebaas

!!! abstract "Eesmärgid"

    - paigaldad kogu `ansible.mysql` faili `requirements.yml` kaudu;
    - paigaldad MariaDB db01-le (AlmaLinux);
    - hoiad andmebaasi kasutaja parooli Vaultis.

Kõik käsud käivad control node'il kaustas `~/kursus/k02`.

## A1 · Kogu

Fail `requirements.yml`:

```yaml
collections:
  - name: ansible.mysql
```

```bash
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection list ansible.mysql
ansible-doc ansible.mysql.mysql_user | head -20
```

??? success "Oodatav tulemus"

    `ansible.mysql` on nimekirjas koos versiooniga. `ansible-doc` näitab mooduli kirjeldust.

??? warning "Kogu vajab `ansible-core` 2.16 või uuemat"

    Kontrolli `ansible --version`. Ubuntu 24.04 paketis on 2.16. Kui control node'il on vanem (näiteks AlmaLinux 9 paketist 2.14), paigalda uuem: `sudo dnf remove -y ansible-core && sudo dnf install -y python3.12-pip && pip3.12 install --user ansible-core`.

## A2 · Muutujad ja Vault

```bash
mkdir -p group_vars/andmebaas
```

Fail `group_vars/andmebaas/vars.yml`:

```yaml
db_nimi: labor
db_kasutaja: labor
db_parool: "{{ vault_db_parool }}"
```

Krüpteeritud fail. Vali Vaulti parool ja jäta see meelde; Giti see ei lähe:

```bash
ansible-vault create group_vars/andmebaas/vault.yml
```

Avaneb redaktor (vaikimisi `vi`; `nano` jaoks enne `export EDITOR=nano`). Kirjuta:

```yaml
vault_db_parool: "MuudaMind-2026"
```

Salvesta ja kontrolli:

```bash
cat group_vars/andmebaas/vault.yml
ansible-vault view group_vars/andmebaas/vault.yml
```

??? success "Oodatav tulemus"

    `cat` näitab `$ANSIBLE_VAULT;1.1;AES256` ja numbrirodu. `view` küsib Vaulti parooli ja näitab sisu.

## A3 · Playbook

Fail `andmebaas.yml`:

```yaml
- name: Andmebaas
  hosts: andmebaas
  become: true
  tasks:
    - name: MariaDB ja Pythoni teek on paigaldatud
      ansible.builtin.package:
        name:
          - mariadb-server
          - python3-PyMySQL
        state: present

    - name: MariaDB töötab ja käivitub boodil
      ansible.builtin.service:
        name: mariadb
        state: started
        enabled: true

    - name: Andmebaas on olemas
      ansible.mysql.mysql_db:
        name: "{{ db_nimi }}"
        state: present
        login_unix_socket: /var/lib/mysql/mysql.sock

    - name: Andmebaasi kasutaja on olemas
      ansible.mysql.mysql_user:
        name: "{{ db_kasutaja }}"
        password: "{{ db_parool }}"
        priv: "{{ db_nimi }}.*:ALL"
        state: present
        login_unix_socket: /var/lib/mysql/mysql.sock
      no_log: true
```

`python3-PyMySQL` on vaja, sest `ansible.mysql` moodulid räägivad andmebaasiga Pythoni kaudu masinas endas.

```bash
ansible-playbook andmebaas.yml --syntax-check --ask-vault-pass
ansible-playbook andmebaas.yml -K --ask-vault-pass
```

??? success "Oodatav tulemus"

    Küsitakse kaks parooli: `BECOME password` (`sudo`) ja `Vault password`. db01-l neli ülesannet `changed`. Kasutaja ülesande juures on `censored` väljundi asemel: `no_log` töötab.

## A4 · Kontrolli

```bash
ansible andmebaas -b -K -m ansible.builtin.command -a "mysql -e 'SHOW DATABASES; SELECT user, host FROM mysql.user;'"
ssh -t db01 "mysql -u labor -p -e 'SELECT DATABASE();' labor"
```

??? success "Oodatav tulemus"

    Esimene käsk: andmebaas `labor` ja kasutaja `labor` `localhost`-is. Teine küsib parooli (`MuudaMind-2026`) ja vastab `labor`.

Käivita playbook teist korda: `changed=0`.

## A5 · Commit

```bash
cd ~/kursus
git add k02
git status
git commit -m "k02: andmebaas, kogu ja Vault"
git push
```

Vaata enne commit'i `git status`-ist: `vault.yml` on nimekirjas, aga see on krüpteeritud. Vaulti parooli ei ole üheski failis.

**Valmis, kui** kasutaja `labor` saab parooliga sisse, teine käivitus annab `changed=0` ja GitHubis on `vault.yml` loetamatu.

??? info "Loe juurde"

    - [Installing collections](https://docs.ansible.com/projects/ansible/latest/collections_guide/collections_installing.html)
    - [`ansible.mysql.mysql_user`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/mysql/mysql_user_module.html)
    - [Ansible Vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html)
