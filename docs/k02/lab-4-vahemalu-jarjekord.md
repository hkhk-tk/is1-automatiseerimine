---
tags:
  - Ansible
  - Praktikum
---

# 4. Vahemälu ja järjekord

Andmebaas töötab. Rakendus vajab veel kahte teenust: Memcached hoiab sagedasti küsitavaid andmeid mälus ja RabbitMQ edastab sõnumeid rakenduse osade vahel. Memcachedi rolli kirjutad ise, RabbitMQ rollis on uus kogu moodul.

## A1 · Memcached: kirjuta roll ise

Memcachedi roll kasutab samu võtteid nagu `mariadb`: paigaldus, mall ja handler, teenus ja tulemüür. Seepärast kirjutad selle ise. AlmaLinuxis kuulab Memcached vaikimisi ainult kohalikke ühendusi, aga rakendus ühendub app01-st. Seaded on failis `/etc/sysconfig/memcached`.

```bash
mkdir -p roles/memcached/tasks roles/memcached/templates roles/memcached/defaults roles/memcached/handlers
```

Vaikeväärtused, fail `roles/memcached/defaults/main.yml`:

```yaml
memcached_port: 11211
memcached_mem_mb: 64
# AlmaLinuxi seadete fail, mall on selle vormingus
memcached_conf: /etc/sysconfig/memcached
```

Mall, fail `roles/memcached/templates/memcached.j2`:

```bash
# {{ ansible_managed }}
PORT="{{ memcached_port }}"
USER="memcached"
MAXCONN="1024"
CACHESIZE="{{ memcached_mem_mb }}"
OPTIONS="-l 0.0.0.0"
```

Rolli nõuded:

| Fail | Mis seal peab olema |
|---|---|
| `handlers/main.yml` | handler `Restart memcached`, mis taaskäivitab teenuse `memcached` |
| `tasks/main.yml` | 1) pakett `memcached` on paigaldatud; 2) mallist tehtud fail `{{ memcached_conf }}`, mis muutumisel teavitab handlerit; 3) teenus töötab ja käivitub koos masinaga; 4) AlmaLinuxis lubab tulemüür pordi `{{ memcached_port }}/tcp` |
| `site.yml` | play `Vahemälu` grupile `cache` rolliga `memcached` |

*Tabel 1. Rolli `memcached` nõuded.*

Mooduleid ja nende parameetreid näed rollist `mariadb`. Kui mõni parameeter on segane, vaata `ansible-doc <moodul>`.

**Ennusta:** mitu ülesannet on esimesel käivitusel `changed` ja kas handler käivitub teisel käivitusel?

```bash
ansible-playbook site.yml --limit mc01
ansible-playbook site.yml --limit mc01
ssh mc01 ss -tln | grep 11211
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on muudatused paigalduses, mallis ja tulemüüris ning handler taaskäivitab Memcachedi. Teisel käivitusel on `changed=0` ja handler ei käivitu. Memcached kuulab aadressil `0.0.0.0:11211`.

??? tip "Lahendus"

    `roles/memcached/handlers/main.yml`:

    ```yaml
    - name: Restart memcached
      ansible.builtin.service:
        name: memcached
        state: restarted
    ```

    `roles/memcached/tasks/main.yml`:

    ```yaml
    - name: Memcached on paigaldatud
      ansible.builtin.package:
        name: memcached
        state: present

    - name: Memcached kuulab kõigil liidestel
      ansible.builtin.template:
        src: memcached.j2
        dest: "{{ memcached_conf }}"
        mode: "0644"
      notify: Restart memcached

    - name: Memcached töötab ja käivitub koos masinaga
      ansible.builtin.service:
        name: memcached
        state: started
        enabled: true

    - name: Tulemüür lubab vahemälu pordi
      ansible.posix.firewalld:
        port: "{{ memcached_port }}/tcp"
        permanent: true
        immediate: true
        state: enabled
      when: ansible_facts['os_family'] == "RedHat"
    ```

    `site.yml`-i play:

    ```yaml
    - name: Vahemälu
      hosts: cache
      become: true
      roles:
        - memcached
    ```

## A2 · RabbitMQ

RabbitMQ paigaldatakse Ubuntus paketist. Rakendus logib sisse oma kasutajaga ja vaikekasutaja `guest` eemaldatakse, sest selle parool on kõigil teada.

```bash
mkdir -p roles/rabbitmq/tasks roles/rabbitmq/defaults
```

Fail `roles/rabbitmq/defaults/main.yml`:

```yaml
rabbitmq_vhost: /
```

Fail `roles/rabbitmq/tasks/main.yml`:

```yaml
- name: RabbitMQ on paigaldatud
  ansible.builtin.apt:
    name: rabbitmq-server
    state: present
    update_cache: true
    cache_valid_time: 3600

- name: RabbitMQ töötab ja käivitub koos masinaga
  ansible.builtin.service:
    name: rabbitmq-server
    state: started
    enabled: true

- name: Rakenduse kasutaja on olemas
  community.rabbitmq.rabbitmq_user:
    user: "{{ labseis_mq_user }}"
    password: "{{ labseis_mq_password }}"
    update_password: on_create
    vhost: "{{ rabbitmq_vhost }}"
    configure_priv: ".*"
    read_priv: ".*"
    write_priv: ".*"
    state: present
  no_log: true

- name: Vaikekasutajat guest ei ole
  community.rabbitmq.rabbitmq_user:
    user: guest
    state: absent
```

| Moodul või parameeter | Mida teeb |
|---|---|
| [`community.rabbitmq.rabbitmq_user`](https://docs.ansible.com/projects/ansible/latest/collections/community/rabbitmq/rabbitmq_user_module.html) | loob või eemaldab RabbitMQ kasutaja ja annab õigused virtuaalhostis |
| `update_password: on_create` | parool määratakse ainult kasutaja loomisel |
| `configure_priv`, `read_priv`, `write_priv` | õigused regulaaravaldisena, `.*` tähendab kõike |

*Tabel 2. RabbitMQ kasutaja haldus.*

Lisa `site.yml`-i play:

```yaml
- name: Sõnumijärjekord
  hosts: queue
  become: true
  roles:
    - rabbitmq
```

**Ennusta:** kas kasutaja ülesanne on teisel käivitusel `changed`? Mis juhtuks, kui `update_password` oleks `always`?

```bash
ansible-playbook site.yml --limit rmq01
ansible-playbook site.yml --limit rmq01
ssh rmq01 sudo rabbitmqctl list_users
```

??? success "Oodatav tulemus"

    Teisel käivitusel on `changed=0`. Väärtusega `always` kontrolliks moodul parooli igal käivitusel ja kui RabbitMQ ei saa parooli võrrelda, oleks tulemus iga kord `changed`. Kasutajate loendis on `labseis`, aga mitte `guest`.

Salvesta töö:

```bash
git add -A
git commit -m "k02: rollid memcached ja rabbitmq"
git push
```

**Valmis, kui** Memcached kuulab porti 11211, RabbitMQ-s on kasutaja `labseis` ja mõlema rolli teine käivitus annab `changed=0`.
