---
tags:
  - Ansible
  - nginx
  - Praktikum
---

# 3. Veebiserver

!!! abstract "Eesmärgid"

    - paigaldad nginx-i grupi `veeb` masinatesse;
    - lood veebilehe ja nginx-i konfiguratsiooni mallist;
    - laadid nginx-i konfiguratsiooni uuesti ainult siis, kui see muutus (handler).

Kõik käsud käivita control node'is kaustas `~/kursus/k02`.

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
ansible-playbook veeb.yml
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on ülesanded `changed` ja lõpus:

    ```
    RUNNING HANDLER [reload nginx] ************
    changed: [web01]
    changed: [app01]
    ```

    Handler käivitati igas masinas üks kord, kuigi seda teavitasid kaks ülesannet.

## A3 · Kontrolli

```bash
ssh web01 "sudo nginx -t"
ssh web01 curl -s http://localhost
ssh app01 curl -s http://localhost | grep Masin
```

??? success "Oodatav tulemus"

    Käsk `nginx -t` väljastab `syntax is ok` ja `test is successful`. web01 veebilehel on pealkiri `IS1 labor · peamine veebiserver` (`host_vars`), app01 veebilehel `Masin: app01 (Ubuntu 24.04)`.

    VPN-iga saad lehte vaadata ka brauseris: `http://<web01-ip>/`.

## A4 · Teine käivitus ja handler

```bash
ansible-playbook veeb.yml
```

??? success "Oodatav tulemus"

    Kokkuvõttes on `changed=0` ja handler'it ei käivitata: väljundis puudub rida `RUNNING HANDLER`.

Muuda nüüd ainult veebilehte: määra failis `group_vars/veeb.yml` väärtuseks `veeb_pealkiri: "IS1 labor 2"`. Enne käivitamist ennusta, kas handler käivitub.

```bash
ansible-playbook veeb.yml
```

??? success "Oodatav tulemus"

    Ülesande `Veebileht on olemas` tulemus on app01-s `changed`, web01-s jääb kehtima `host_vars` väärtus. Handler ei käivitu, sest veebilehe ülesanne handler'it ei teavita: nginx loeb lehe faili igal päringul uuesti. Konfiguratsiooni on vaja uuesti laadida ainult siis, kui konfiguratsioon muutub.

Muuda nüüd porti: määra `veeb_port: 8080`, käivita playbook ja kontrolli tulemust käsuga `ssh app01 curl -s http://localhost:8080 | grep Masin`. Seejärel taasta väärtus `80` ja käivita playbook uuesti.

??? success "Oodatav tulemus"

    Konfiguratsiooni muutus käivitas handler'i `reload nginx` ja leht vastab pordil 8080. Pärast väärtuse taastamist vastab leht jälle pordil 80.

## A5 · Commit

```bash
cd ~/kursus
git add k02
git commit -m "k02: veebiserver malli ja handler'iga"
git push
```

**Valmis, kui** web01 ja app01 veebilehel on masina nimi ning teisel käivitusel on `changed=0` ja handler'it ei käivitata.

??? info "Loe juurde"

    - [Templating (Jinja2)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_templating.html)
    - [Handlers](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_handlers.html)
    - [nginx: Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
