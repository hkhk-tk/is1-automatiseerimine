---
tags:
  - Ansible
  - Praktikum
---

# 5. Rakendus ja veebiserver

Kõik kolm taustateenust töötavad. Nüüd paigaldad app01-sse Tomcati koos Labori seisu rakendusega ja web01-sse Nginxi, mis suunab brauseri päringud rakendusse. Selle osa lõpus avaneb Labori seis web01 kaudu.

## A1 · Rakenduse seaded

Rakendus loeb andmebaasi, vahemälu ja järjekorra aadressid ning paroolid keskkonnamuutujatest. Need on failis `/etc/labori-seis/env`, mis tehakse mallist. Aadressid tulevad inventory gruppidest, paroolid Vaultist.

```bash
mkdir -p roles/tomcat/tasks roles/tomcat/templates roles/tomcat/defaults roles/tomcat/handlers
```

Fail `roles/tomcat/templates/env.j2`:

```bash
# {{ ansible_managed }}
DB_HOST={{ groups['db'][0] }}
DB_NAME={{ labseis_db_name }}
DB_USER={{ labseis_db_user }}
DB_PASSWORD={{ labseis_db_password }}
MEMCACHED_HOST={{ groups['cache'][0] }}
RABBITMQ_HOST={{ groups['queue'][0] }}
RABBITMQ_USER={{ labseis_mq_user }}
RABBITMQ_PASSWORD={{ labseis_mq_password }}
TEACHER_TOKEN={{ labseis_teacher_token }}
```

`groups['db'][0]` on grupi `db` esimene masin. Kui andmebaas kolib teise masinasse, muudad ainult inventory't.

Tomcat käivitatakse systemd teenusena. Fail `roles/tomcat/templates/labori-seis.conf.j2` lisab teenusele rakenduse seaded ja Java 21:

```ini
# {{ ansible_managed }}
[Service]
EnvironmentFile=/etc/labori-seis/env
Environment=JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
Environment=CATALINA_OPTS=-Xmx{{ tomcat_heap }}
```

Fail `roles/tomcat/defaults/main.yml`:

```yaml
tomcat_heap: 256m
tomcat_webapps: /var/lib/tomcat10/webapps
# WAR kursuse starteri release'ist. Kui tomcat_war_url on tühi, kopeeritakse fail tomcat_war_src control node'ist.
tomcat_war_url: https://github.com/hkhk-tk/is1-starter/releases/download/v1.1.0/labori-seis.war
tomcat_war_src: "{{ playbook_dir }}/../labori-seis.war"
```

Fail `roles/tomcat/handlers/main.yml`:

```yaml
- name: Restart tomcat
  ansible.builtin.systemd_service:
    name: tomcat10
    state: restarted
    daemon_reload: true
```

## A2 · Tomcat ja rakendus

Fail `roles/tomcat/tasks/main.yml`:

```yaml
- name: Java 21 ja Tomcat 10 on paigaldatud
  ansible.builtin.apt:
    name:
      - openjdk-21-jre-headless
      - tomcat10
    state: present
    update_cache: true
    cache_valid_time: 3600

- name: Rakenduse seadete kaust on olemas
  ansible.builtin.file:
    path: /etc/labori-seis
    state: directory
    owner: root
    group: tomcat
    mode: "0750"

- name: Rakenduse seaded (paroolid) on failis
  ansible.builtin.template:
    src: env.j2
    dest: /etc/labori-seis/env
    owner: root
    group: tomcat
    mode: "0640"
  notify: Restart tomcat
  no_log: true

- name: Tomcati teenuse lisaseadete kaust on olemas
  ansible.builtin.file:
    path: /etc/systemd/system/tomcat10.service.d
    state: directory
    mode: "0755"

- name: Tomcat loeb rakenduse seaded ja kasutab Java 21
  ansible.builtin.template:
    src: labori-seis.conf.j2
    dest: /etc/systemd/system/tomcat10.service.d/labori-seis.conf
    mode: "0644"
  notify: Restart tomcat

- name: Kas juurkontekstis on Tomcati näidisleht?
  ansible.builtin.stat:
    path: "{{ tomcat_webapps }}/ROOT/index.html"
  register: tomcat_naidis

- name: Näidislehe kaust on eemaldatud
  ansible.builtin.file:
    path: "{{ tomcat_webapps }}/ROOT"
    state: absent
  when: tomcat_naidis.stat.exists

- name: Rakendus (WAR) on alla laaditud
  ansible.builtin.get_url:
    url: "{{ tomcat_war_url }}"
    dest: "{{ tomcat_webapps }}/ROOT.war"
    owner: tomcat
    group: tomcat
    mode: "0644"
  when: tomcat_war_url | length > 0

- name: Rakendus (WAR) on kopeeritud control node'ist
  ansible.builtin.copy:
    src: "{{ tomcat_war_src }}"
    dest: "{{ tomcat_webapps }}/ROOT.war"
    owner: tomcat
    group: tomcat
    mode: "0644"
  when: tomcat_war_url | length == 0

- name: Tomcat töötab ja käivitub koos masinaga
  ansible.builtin.service:
    name: tomcat10
    state: started
    enabled: true

- name: Muudatused rakenduvad enne kontrolli
  ansible.builtin.meta: flush_handlers

- name: Rakendus vastab app01-s
  ansible.builtin.uri:
    url: http://localhost:8080/health/live
    status_code: 200
  register: tomcat_live
  until: tomcat_live.status == 200
  retries: 40
  delay: 5
```

| Moodul või võti | Mida teeb |
|---|---|
| [`ansible.builtin.stat`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/stat_module.html) | loeb faili andmeid; `register` salvestab tulemuse, `when: ….stat.exists` kasutab seda |
| [`ansible.builtin.get_url`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/get_url_module.html) | laadib faili alla; kui fail on olemas ja sama, ei laadi uuesti |
| [`ansible.builtin.systemd_service`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/systemd_service_module.html) | `daemon_reload: true` loeb muutunud teenusefailid enne taaskäivitust |
| [`ansible.builtin.uri`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/uri_module.html) | teeb HTTP päringu; `until`, `retries` ja `delay` kordavad seda, kuni rakendus vastab |

*Tabel 1. Uued moodulid ja võtmed.*

Tomcati pakett paigaldab näidislehe kausta `ROOT`, mis takistaks rakendusel juurkontekstis käivitumast. Ülesanne eemaldab selle ainult siis, kui seal on Tomcati näidisleht, nii et hiljem rakenduse lahtipakitud faile ei puututa.

Lisa `site.yml`-i play ja käivita:

```yaml
- name: Rakendusserver
  hosts: app
  become: true
  roles:
    - tomcat
```

```bash
ansible-playbook site.yml --limit app01
ssh app01 curl -s http://localhost:8080/health
```

??? success "Oodatav tulemus"

    Ülesanne `Rakendus vastab app01-s` võib paar korda kirjutada `FAILED - RETRYING`, kuni rakendus käivitub. `/health` vastab `{"status":"UP","db":"UP","queue":"UP","cache":"UP"}`. Kui mõni neist on `DOWN`, vaata vastava teenuse osa uuesti.

## A3 · Nginx: kirjuta roll ise

Nginx web01-s võtab vastu päringud pordil 80 ja edastab need app01-le. Muutuja `nginx_upstream` tuli 1. osas failist `host_vars/web01.yml`. Rolli kirjutad ise, mall on antud.

```bash
mkdir -p roles/nginx/tasks roles/nginx/templates roles/nginx/defaults roles/nginx/handlers
```

Mall, fail `roles/nginx/templates/labori-seis.conf.j2`:

```nginx
# {{ ansible_managed }}
upstream labori_seis {
    server {{ nginx_upstream }};
}

server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://labori_seis;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

Ubuntus on Nginxi saidid kaustas `/etc/nginx/sites-available` ja sait lülitatakse sisse lingiga kausta `/etc/nginx/sites-enabled`. Paketiga tuleb vaikesait `sites-enabled/default`, mis kuulab samuti porti 80 ja tuleb välja lülitada.

Rolli nõuded:

| Fail | Mis seal peab olema |
|---|---|
| `defaults/main.yml` | `nginx_upstream: app01:8080` |
| `handlers/main.yml` | handler `Reload nginx`, mis laeb teenuse `nginx` seaded uuesti (`state: reloaded`) |
| `tasks/main.yml` | 1) pakett `nginx` on paigaldatud; 2) mallist fail `/etc/nginx/sites-available/labori-seis`; 3) link `/etc/nginx/sites-enabled/labori-seis` sellele failile; 4) faili `/etc/nginx/sites-enabled/default` ei ole; 5) teenus töötab ja käivitub koos masinaga. Ülesanded 2–4 teavitavad handlerit. |

*Tabel 2. Rolli `nginx` nõuded.*

Lingi ja faili eemaldamise teeb moodul [`ansible.builtin.file`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/file_module.html): link on `src`, `dest` ja `state: link`, eemaldamine `path` ja `state: absent`. Handler `Reload nginx` loeb seaded uuesti ilma ühendusi katkestamata. Seda teavitavad kolm ülesannet, aga handler käivitub ühe korra.

Lisa `site.yml`-i play grupile `web` rolliga `nginx`.

??? tip "Lahendus"

    `roles/nginx/defaults/main.yml` ja `roles/nginx/handlers/main.yml`:

    ```yaml
    nginx_upstream: app01:8080
    ```

    ```yaml
    - name: Reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
    ```

    `roles/nginx/tasks/main.yml`:

    ```yaml
    - name: Nginx on paigaldatud
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: Labori seisu sait on seadistatud
      ansible.builtin.template:
        src: labori-seis.conf.j2
        dest: /etc/nginx/sites-available/labori-seis
        mode: "0644"
      notify: Reload nginx

    - name: Labori seisu sait on sisse lülitatud
      ansible.builtin.file:
        src: /etc/nginx/sites-available/labori-seis
        dest: /etc/nginx/sites-enabled/labori-seis
        state: link
      notify: Reload nginx

    - name: Vaikesait on välja lülitatud
      ansible.builtin.file:
        path: /etc/nginx/sites-enabled/default
        state: absent
      notify: Reload nginx

    - name: Nginx töötab ja käivitub koos masinaga
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
    ```

    `site.yml`-i play:

    ```yaml
    - name: Veebiserver
      hosts: web
      become: true
      roles:
        - nginx
    ```

## A4 · Terve `site.yml`

Lisa `site.yml`-i lõppu play, mis kontrollib, et kogu Labori seis vastab web01 kaudu:

```yaml
- name: Labori seis vastab
  hosts: web
  gather_facts: false
  tasks:
    - name: Rakendus vastab web01 kaudu
      ansible.builtin.uri:
        url: http://localhost/health
        status_code: 200
      register: health
      until: health.status == 200
      retries: 30
      delay: 5
```

**Ennusta:** mida näitab viimane play, kui app01-s Tomcat ei tööta?

```bash
ansible-playbook site.yml
curl -s http://<web01 IP-aadress>/health
```

Ava brauseris `http://<web01 IP-aadress>/`. Avaneb Labori seisu leht.

??? success "Oodatav tulemus"

    Kõik play'd lõpevad ilma vigadeta ja `/health` vastab web01 kaudu `"status":"UP"`. Kui Tomcat ei tööta, annab Nginx vastuse 502 ja viimane play kordab päringut 30 korda ning ebaõnnestub.

Salvesta töö:

```bash
git add -A
git commit -m "k02: rollid tomcat ja nginx"
git push
```

**Valmis, kui** `/health` vastab web01 kaudu `UP` ja Labori seisu leht avaneb brauseris.

??? info "Loe juurde"

    - [Controlling where tasks run: `meta: flush_handlers`](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html#controlling-when-handlers-run)
    - [Retrying a task until a condition is met](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_loops.html#retrying-a-task-until-a-condition-is-met)
