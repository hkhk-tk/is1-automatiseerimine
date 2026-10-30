---
tags:
  - Ansible
  - Lisaülesanne
---

# 2. kohtumine · Lisaülesanded

Need ülesanded on neile, kes on praktikumi lõpetanud. Kõik käsud käivitad control node'is kaustas `~/kursus/k02-ansible`.

## L1 · Distributsiooni väärtused rolli sees

Rolli `mariadb` vaikeväärtused on AlmaLinuxi omad ja Ubuntus tuleks need grupimuutujatega üle kirjutada. Teine võimalus on, et roll valib väärtused ise masina distributsiooni järgi. Loo failid `roles/mariadb/vars/RedHat.yml` (praegused väärtused) ja `roles/mariadb/vars/Debian.yml`:

```yaml
mariadb_paketid:
  - mariadb-server
  - python3-pymysql
mariadb_conf_dir: /etc/mysql/mariadb.conf.d
mariadb_socket: /run/mysqld/mysqld.sock
```

Eemalda need kolm muutujat failist `defaults/main.yml` ja lisa rolli ülesannete algusesse:

```yaml
- name: Distributsiooni väärtused
  ansible.builtin.include_vars: "{{ ansible_facts['os_family'] }}.yml"
```

Teine käivitus peab andma `changed=0`. Mõtle: millal on parem, et roll teab distributsioonide väärtusi ise, ja millal, et need on inventory juures grupimuutujates?

## L2 · `ansible-lint`

Automaatne hindaja kontrollib projekti `ansible-lint`-iga. Paigalda see ja kontrolli oma projekti enne esitamist:

```bash
sudo apt install -y ansible-lint
ansible-lint
```

Iga leiu juures on reegli nimi, näiteks `fqcn` (mooduli täisnimi) või `name[casing]` (ülesande nimi algab suure tähega). Reegli kirjelduse leiad [ansible-lint reeglite lehelt](https://ansible.readthedocs.io/projects/lint/rules/).

## L3 · Viga ja `-vvv`

Tekita failis `roles/nginx/tasks/main.yml` meelega taandeviga: nihuta üks `ansible.builtin.template:` rida kahe tühiku võrra paremale. Käivita:

```bash
ansible-playbook site.yml --syntax-check
```

Veateade näitab rea ja veeru numbrit. Paranda viga ja käivita playbook ühes masinas detailse väljundiga:

```bash
ansible-playbook site.yml --limit web01 --check -vvv | head -60
```

Väljundist näed, millise kasutajaga ja millise SSH käsuga Ansible ühendub. See aitab ühendusvigade korral.

## L4 · Ainult rakenduse uuendus

Uue rakenduse versiooni paigaldamiseks ei ole vaja kogu süsteemi läbi käia. Lisa rolli `tomcat` WAR-i ülesannetele silt `deploy` ja käivita ainult need:

```bash
ansible-playbook site.yml --tags deploy --limit app01
```

Mõtle, mis peab juhtuma pärast uue WAR-i paigaldamist ja kuidas seda rollis kirjeldada.

## L5 · Üks krüpteeritud väärtus: `encrypt_string`

`vault.yml` krüpteerib terve faili. Vahel on mugavam krüpteerida ainult üks väärtus ja hoida see tavalises muutujate failis, kus ülejäänu on loetav. Käsk kasutab sama Vaulti parooli, mille `ansible.cfg` ette annab:

```bash
ansible-vault encrypt_string 'proov123' --name vault_proov
```

Kopeeri väljund faili `host_vars/db01.yml` ja kontrolli, et Ansible saab väärtuse lahti:

```bash
ansible db01 -m ansible.builtin.debug -a var=vault_proov
```

Väljundis on `"vault_proov": "proov123"`. Mõtle: millal on parem krüpteerida terve fail ja millal üks väärtus? Mis juhtub `git diff`-is, kui muudad krüpteeritud faili ühte parooli? Loe edasi: [Encrypting content with Ansible Vault](https://docs.ansible.com/projects/ansible/latest/vault_guide/vault_encrypting_content.html). Kustuta katse lõpus fail `host_vars/db01.yml`.

