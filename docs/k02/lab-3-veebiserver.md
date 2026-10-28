---
tags:
  - Ansible
  - nginx
  - Praktikum
---

# 3. Veebiserver

!!! abstract "Eesmärgid"

    - paigaldad nginx-i grupi `veeb` masinatesse;
    - teed veebilehe ja nginx-i seadistuse mallist;
    - laadid nginx-i uuesti ainult siis, kui seadistus muutus (handler).

Kõik käsud käivad control node'il kaustas `~/kursus/k02`.

## A1 · Mallid

```bash
mkdir -p templates
```

Fail `templates/index.html.j2`:

```html
<!doctype html>
<html lang="et">
<head><meta charset="utf-8"><title>{{ veeb_pealkiri }}</title></head>
<body>
  <h1>{{ veeb_pealkiri }}</h1>
  <p>Masin: {{ inventory_hostname }} ({{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }})</p>
  <p>Kasutajad: {{ labori_kasutajad | join(', ') }}</p>
</body>
</html>
```

Fail `templates/labor.conf.j2`:

```nginx
# {{ ansible_managed }}
server {
    listen {{ veeb_port }} default_server;
    root /var/www/labor;
    index index.html;
}
```

## A2 · Playbook

Fail `veeb.yml`:

```yaml
- name: Veebiserver
  hosts: veeb
  become: true
  tasks:
    - name: nginx on paigaldatud
      ansible.builtin.package:
        name: nginx
        state: present

    - name: Ubuntu vaikesait on eemaldatud
      ansible.builtin.file:
        path: /etc/nginx/sites-enabled/default
        state: absent
      notify: reload nginx

    - name: Labori sait on seadistatud
      ansible.builtin.template:
        src: labor.conf.j2
        dest: /etc/nginx/conf.d/labor.conf
        mode: "0644"
      notify: reload nginx

    - name: Veebilehe kaust on olemas
      ansible.builtin.file:
        path: /var/www/labor
        state: directory
        mode: "0755"

    - name: Veebileht on olemas
      ansible.builtin.template:
        src: index.html.j2
        dest: /var/www/labor/index.html
        mode: "0644"

    - name: nginx töötab ja käivitub boodil
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

  handlers:
    - name: reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

```bash
ansible-playbook veeb.yml --syntax-check
ansible-playbook veeb.yml -K
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on ülesanded `changed` ja lõpus:

    ```
    RUNNING HANDLER [reload nginx] ************
    changed: [web01]
    changed: [app01]
    ```

    Handler käis üks kord masina kohta, kuigi teda teavitasid kaks ülesannet.

## A3 · Kontrolli

```bash
ssh web01 "sudo nginx -t"
ssh web01 curl -s http://localhost
ssh app01 curl -s http://localhost | grep Masin
```

??? success "Oodatav tulemus"

    `nginx -t`: `syntax is ok` ja `test is successful`. web01 lehel on pealkiri `IS1 labor · peamine veebiserver` (`host_vars`), app01 lehel `Masin: app01 (Ubuntu 24.04)`.

    VPN-iga saad lehte vaadata ka brauseris: `http://<web01-ip>/`.

## A4 · Teine käivitus ja handler

```bash
ansible-playbook veeb.yml -K
```

??? success "Oodatav tulemus"

    `changed=0` ja handler'it ei käivitata: rida `RUNNING HANDLER` puudub.

Muuda nüüd ainult veebilehte: `group_vars/veeb.yml`-is `veeb_pealkiri: "IS1 labor 2"`. Ennusta enne: kas handler käivitub?

```bash
ansible-playbook veeb.yml -K
```

??? success "Oodatav tulemus"

    `Veebileht on olemas` on app01-l `changed` (web01-l jääb `host_vars` väärtus). Handler ei käivitu: veebileht ei teavita handler'it, sest nginx loeb faili igal päringul ise. Uuesti laadimist on vaja ainult seadistuse muutumisel.

Muuda nüüd port: `veeb_port: 8080`, käivita, kontrolli `ssh app01 curl -s http://localhost:8080 | grep Masin`, siis pane tagasi `80` ja käivita uuesti.

??? success "Oodatav tulemus"

    Seadistuse muutus käivitas handler'i `reload nginx`; leht vastab pordil 8080. Pärast tagasipanekut vastab jälle pordil 80.

## A5 · Commit

```bash
cd ~/kursus
git add k02
git commit -m "k02: veebiserver malli ja handler'iga"
git push
```

**Valmis, kui** web01 ja app01 näitavad oma nime ja teine käivitus annab `changed=0` ilma handler'ita.

??? info "Loe juurde"

    - [Templating (Jinja2)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_templating.html)
    - [Handlers](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html)
    - [nginx: Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
