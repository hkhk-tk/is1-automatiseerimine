---
tags:
  - Ansible
  - Docker
  - Kodutöö
---

# Kodutöö: Docker rolliga ja stack playbook'iga

Praktikumis paigaldasid Dockeri käsitsi ja käivitasid stacki käsuga. Kodutöös kirjutad paigalduse rolliks `docker` ja paned sama playbook'i käivitama ka Labori seisu stacki. Lõpuks võtab playbook paroolid 2. kohtumise Vaultist. Nii saab uue masina seadistada ühe käsuga. Kodutöö on boonus.

Kodutöö teed samas harus `k03-docker`, kus oli praktikum. Starteris on `docker.yml` ja `roles/docker/files/harbor-ca.crt`.

## Osa 1 · Docker rolliga

**Eesmärk:** Docker on control'is paigaldatud rolliga `docker` ja teine käivitus annab `changed=0`.  
**Kontroll:** `ansible-playbook docker.yml` kaks korda järjest, teise lõpus `changed=0`.  
**Kus:** control, kaust `~/kursus/k03-docker`.

Praktikumis paigaldasid Dockeri käsitsi. Teises masinas tuleks kõik sammud samas järjekorras korrata ja üks unustatud samm, näiteks CA, annab vea alles esimesel `docker pull`-il. Rakendad rolli control'ile, kus Docker juba töötab.

### 1.1 Roll `docker`

2\. kohtumisel koondasid iga teenuse ülesanded rolli. Docker on samasugune teenus: pakettide repositoorium, paketid, konfiguratsioonifail, teenus ja kasutaja õigused.

Fail `docker.yml` on starteris olemas. See käivitab rolli control'is endas:

```yaml
- name: Docker control node'is
  hosts: localhost
  connection: local
  become: true
  roles:
    - docker
```

`hosts: localhost` koos `connection: local`-iga tähendab, et Ansible ei ühendu SSH-ga ja käivitab moodulid samas masinas. Inventory't pole vaja.

Vaata üle praktikumi sammud 1.2, 1.5 ja 1.6 ja kirjuta iga samm rolli ülesandeks. Logide piirid ja Trivy on süvenemise lehe sammudes 2.6 ja 3.1: kui sa neid käsitsi ei teinud, võta need ülesanded lahendusest. Roll teeb samad sammud moodulitega. Starteris on ainult kaust `roles/docker/files`, ülejäänud kaustad loo ise:

```bash
mkdir -p roles/docker/{defaults,tasks,templates,handlers}
```

??? example "Ülesanne: `roles/docker/defaults/main.yml`"

    Vaikeväärtused: kes saab grupi `docker` liikmeks, Harbori nimi ja logide piirid.

    ```yaml
    docker_kasutaja: "{{ ansible_env.SUDO_USER | default(ansible_user_id) }}"
    harbor_nimi: harbor.lab.hkhk.lan
    docker_log_max_size: 10m
    docker_log_max_file: 3
    ```

    `become: true` korral käivitab Ansible moodulid `sudo` kaudu. `SUDO_USER` on kasutaja, kes playbook'i käivitas, mitte `root`.

??? example "Ülesanne: repositoorium ja paketid (`roles/docker/tasks/main.yml`)"

    Moodul [`deb822_repository`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/deb822_repository_module.html) kirjutab faili `/etc/apt/sources.list.d/docker.sources`, sama faili, mille 1.2-s käsitsi tegid.

    ```yaml
    - name: Moodul deb822_repository vajab python3-debian paketti
      ansible.builtin.apt:
        name: python3-debian
        state: present
        update_cache: true

    - name: Ubuntu Dockeri paketid eemal
      ansible.builtin.apt:
        name: [docker.io, docker-compose, docker-compose-v2, podman-docker, containerd, runc]
        state: absent

    - name: Dockeri võtmete kaust
      ansible.builtin.file:
        path: /etc/apt/keyrings
        state: directory
        mode: "0755"

    - name: Dockeri GPG võti
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/ubuntu/gpg
        dest: /etc/apt/keyrings/docker.asc
        mode: "0644"

    - name: Dockeri apt-repositoorium
      ansible.builtin.deb822_repository:
        name: docker
        types: [deb]
        uris: https://download.docker.com/linux/ubuntu
        suites: ["{{ ansible_distribution_release }}"]
        components: [stable]
        signed_by: /etc/apt/keyrings/docker.asc

    - name: Docker Engine ja Compose
      ansible.builtin.apt:
        name: [docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin]
        state: present
        update_cache: true
    ```

    `ansible-doc ansible.builtin.deb822_repository`: mis vahe on võtmetel `uris` ja `suites`?

??? example "Ülesanne: daemoni seaded ja Harbori CA (jätka sama faili)"

    Võti `validate` kontrollib uut faili enne, kui see õigesse kohta kopeeritakse, nagu `dockerd --validate` praktikumi sammus 1.6: vigane fail ei jõua kunagi `/etc/docker` alla. Handler taaskäivitab Dockeri ainult siis, kui fail muutus.

    ```yaml
    - name: Daemoni seaded
      ansible.builtin.template:
        src: daemon.json.j2
        dest: /etc/docker/daemon.json
        mode: "0644"
        validate: dockerd --validate --config-file %s
      notify: Docker uuesti

    - name: Harbori sertifikaadi kaust Dockerile
      ansible.builtin.file:
        path: "/etc/docker/certs.d/{{ harbor_nimi }}"
        state: directory
        mode: "0755"

    - name: Harbori CA Dockerile
      ansible.builtin.copy:
        src: harbor-ca.crt
        dest: "/etc/docker/certs.d/{{ harbor_nimi }}/ca.crt"
        mode: "0644"

    - name: Harbori CA süsteemi usaldatud sertifikaatide hulka (curl, Trivy)
      ansible.builtin.copy:
        src: harbor-ca.crt
        dest: /usr/local/share/ca-certificates/labori-ca.crt
        mode: "0644"
      notify: CA nimekiri uuesti
    ```

    Mall `roles/docker/templates/daemon.json.j2` sisaldab samu logide piire, mis süvenemise sammus 2.6. Väärtused tulevad rolli vaikeväärtustest. `max-file` on JSON-is tekst, mitte number.

    ```json
    {
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "{{ docker_log_max_size }}",
        "max-file": "{{ docker_log_max_file }}"
      }
    }
    ```

??? example "Ülesanne: Trivy (jätka sama faili)"

    Samad sammud nagu süvenemise sammus 3.1.

    ```yaml
    - name: Trivy GPG võti
      ansible.builtin.get_url:
        url: https://aquasecurity.github.io/trivy-repo/deb/public.key
        dest: /etc/apt/keyrings/trivy.asc
        mode: "0644"

    - name: Trivy apt-repositoorium
      ansible.builtin.deb822_repository:
        name: trivy
        types: [deb]
        uris: https://aquasecurity.github.io/trivy-repo/deb
        suites: [generic]
        components: [main]
        signed_by: /etc/apt/keyrings/trivy.asc

    - name: Trivy
      ansible.builtin.apt:
        name: trivy
        update_cache: true
    ```

??? example "Ülesanne: teenus, grupp ja handler'id"

    Lisa `tasks/main.yml` lõppu:

    ```yaml
    - name: Teenus töötab ja käivitub koos masinaga
      ansible.builtin.service:
        name: docker
        state: started
        enabled: true

    - name: Kasutaja on grupis docker
      ansible.builtin.user:
        name: "{{ docker_kasutaja }}"
        groups: docker
        append: true
    ```

    Fail `roles/docker/handlers/main.yml`:

    ```yaml
    - name: Docker uuesti
      ansible.builtin.service:
        name: docker
        state: restarted

    - name: CA nimekiri uuesti
      ansible.builtin.command: update-ca-certificates
      changed_when: true
    ```

    `append: true` lisab grupi juurde. Ilma selleta eemaldaks moodul kasutaja kõigist teistest lisagruppidest, ka grupist `sudo`.

### 1.2 Käivita roll

Docker on control'is juba olemas. Enne muudatust vaata, mida roll muudaks.

**Küsimus enne käsku:** mitu ülesannet on `changed`, kui sama seadistus on juba käsitsi tehtud?

```bash
ansible-playbook docker.yml --check --diff
```

??? success "Oodatav tulemus"

    Paketid, teenus, grupp ja CA failid on juba soovitud olekus ja jäävad `ok`. `changed` on ainult failid, mille sisu erineb käsitsi tehtust, näiteks `daemon.json`-i vorming (tühikud ja reavahetused) või repositooriumi faili võtmete järjekord. `--diff` näitab iga erinevuse rida.

Rakenda roll kaks korda ja kontrolli tulemust:

```bash
ansible-playbook docker.yml
ansible-playbook docker.yml
docker compose ps
docker info --format '{{.LoggingDriver}}'
curl -s https://harbor.lab.hkhk.lan/api/v2.0/ping; echo
trivy --version | head -1
```

??? success "Oodatav tulemus"

    Esimene käivitus lõpeb `failed=0`, teine `changed=0`. Kui `daemon.json` muutus, taaskäivitas handler Dockeri ja stack käivitus uuesti tänu `restart: unless-stopped`-ile. Harbor vastab `Pong` ja Trivy versioon on alles.

??? warning "Kui esimene käivitus peatus vea tõttu ja `daemon.json` on muutunud, aga Docker kasutab vana seadet"

    Handler käivitub play lõpus. Kui play peatus enne lõppu, jäi handler käivitamata, kuigi fail muutus. Teisel käivitusel faili enam ei muudeta ja handler'it ei teavitata. Kontrolli faili (`sudo dockerd --validate --config-file /etc/docker/daemon.json`) ja käivita üks kord `sudo systemctl restart docker`. `--force-handlers` aitab ainult samas käivituses: see käivitab teavitatud handler'id ka siis, kui play peatub vea tõttu.

### 1.3 Commit

```bash
(cd ~/kursus && git add k03-docker && git commit -m "k03: Docker rolliga" && git push)
```

??? info "Miks see nii töötab"

    **Käsitsi ja rolliga.** Roll teeb samad sammud nagu käsitsi paigaldus, aga iga moodul kontrollib enne muutmist, kas masin on juba soovitud olekus. Seepärast saab rolli rakendada nii tühjale masinale kui ka masinale, kus Docker juba töötab, ja teine käivitus ei muuda midagi.

    **Erinevused käsitsi seadistusest.** `--check --diff` näitab faile, mille sisu erineb mallist või rolli kirjutatud kujust. Kui serveris on keegi `daemon.json`-i käsitsi muutnud, näitab sama käsk seda erinevust. Nii leiab triivi (drift): olukorra, kus masina tegelik olek on soovitud olekust eemaldunud.

    **Handler ja `validate`.** `validate` kontrollib uut faili enne asendamist. Vigane mall annab vea ja vana fail jääb alles. Handler taaskäivitab Dockeri ainult siis, kui fail muutus, sest iga taaskäivitus peatab hosti konteinerid.

## Osa 2 · Stack playbook'iga

**Eesmärk:** sama playbook paigaldab Dockeri ja käivitab Labori seisu stacki.  
**Kontroll:** `ansible-playbook stack.yml` teine käivitus annab `changed=0` ja `curl -s localhost:8080/health` annab neli `UP`-i.  
**Kus:** control, kaust `~/kursus/k03-docker`.

Roll paigaldab Dockeri, aga stack käivitati siiani käsuga `docker compose up -d`. Moodul [`community.docker.docker_compose_v2`](https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_compose_v2_module.html) käivitab sama `compose.yaml`-i Ansible'ist ja annab `changed` ainult siis, kui mõni teenus luuakse uuesti. Moodul on kollektsioonis `community.docker`:

```bash
ansible-galaxy collection install community.docker
ansible-doc community.docker.docker_compose_v2 | grep -A3 -E '^ +(project_src|state|wait)'
```

Kirjuta fail `stack.yml`: esimene play rakendab rolli `docker`, teine käivitab stacki kaustast `~/kursus/k03-docker` ja ootab, kuni teenused on `healthy`. Play käivitub kasutajana `kasutaja`, mitte root'ina, sest `.env` ja image'id on selle kasutaja omad.

??? example "Lahendus: `stack.yml`"

    ```yaml
    - name: Docker
      import_playbook: docker.yml

    - name: Labori seis
      hosts: localhost
      connection: local
      tasks:
        - name: Stack töötab
          community.docker.docker_compose_v2:
            project_src: "{{ playbook_dir }}"
            state: present
            wait: true
            wait_timeout: 300
    ```

```bash
ansible-playbook stack.yml
ansible-playbook stack.yml
curl -s localhost:8080/health; echo
```

??? success "Oodatav tulemus"

    Esimene käivitus on `ok` või `changed`, teine lõpeb `changed=0` ja `/health` annab neli `UP`-i. `wait: true` teeb sama mis `docker compose up -d --wait`: play jätkub alles siis, kui teenused on `healthy`.

## Osa 3 · Paroolid Vaultist

Praktikumis kirjutasid paroolid faili `.env` käsitsi. 2. kohtumisel olid samad paroolid Ansible Vaultis. Selles osas teeb Ansible `.env`-i Vaulti paroolidest, nii et paroolid on ühes kohas ja krüpteeritud.

Selleks on vaja 2. kohtumise Vaulti: faili `~/kursus/k02-ansible/group_vars/all/vault.yml` ja Vaulti parooli failis `~/.config/is1/vault_pass`. Kui sul neid pole, jäta see osa vahele.

Vaultis pole veel andmebaasi root'i parooli. Lisa see:

```bash
ansible-vault edit ~/kursus/k02-ansible/group_vars/all/vault.yml --vault-password-file ~/.config/is1/vault_pass
```

Lisa faili rida `vault_db_root_password: "<parool>"`, salvesta ja sulge redaktor.

Nüüd lisa `stack.yml`-i teise play'sse Vaulti fail ja ülesanne, mis kirjutab `.env`-i. `no_log: true` hoiab paroolid Ansible'i väljundist eemal.

??? example "Lahendus: `stack.yml` teine play"

    ```yaml
    - name: Labori seis
      hosts: localhost
      connection: local
      vars_files:
        - ../k02-ansible/group_vars/all/vault.yml
      vars:
        github_kasutaja: sinu-github-kasutaja
      tasks:
        - name: .env Vaulti paroolidest
          ansible.builtin.copy:
            dest: "{{ playbook_dir }}/.env"
            mode: "0600"
            content: |
              DB_PASSWORD={{ vault_db_password }}
              DB_ROOT_PASSWORD={{ vault_db_root_password }}
              RABBITMQ_PASSWORD={{ vault_rabbitmq_password }}
              TEACHER_TOKEN={{ vault_teacher_token }}
              HUB=harbor.lab.hkhk.lan/dockerhub/library
              REGISTRY=harbor.lab.hkhk.lan
              OWNER={{ github_kasutaja }}
              TAG=dev
              WEB_PORT=8080
          no_log: true

        - name: Stack töötab
          community.docker.docker_compose_v2:
            project_src: "{{ playbook_dir }}"
            state: present
            wait: true
            wait_timeout: 300
    ```

    Asenda `sinu-github-kasutaja` oma GitHubi kasutajanimega väikeste tähtedega.

!!! warning "Uued paroolid ja olemasolev andmebaas"

    MariaDB võtab paroolid ainult esimesel käivitusel. Kui Vaulti paroolid erinevad nendest, mis olid praktikumis `.env`-is, ei pääse rakendus andmebaasi. Siin on andmebaasis ainult näidisandmed, nii et kustuta enne käivitamist stack koos andmetega: `docker compose down -v`.

```bash
ansible-playbook stack.yml --vault-password-file ~/.config/is1/vault_pass
ansible-playbook stack.yml --vault-password-file ~/.config/is1/vault_pass
curl -s localhost:8080/health; echo
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on `.env` ülesanne `changed`, teisel `ok` ja kogu play lõpeb `changed=0`. `/health` annab neli `UP`-i. `.env`-is on nüüd Vaulti paroolid, aga Ansible'i väljundis neid ei näe.

## Töö esitamine

```bash
(cd ~/kursus && git add k03-docker && git commit -m "k03: Docker rolliga ja stack playbook'iga" && git push)
(cd ~/kursus && git tag -f k03 && git push -f origin k03)
```

Tag `k03` tähistab viimast esitatud versiooni, seepärast tõstad selle uuele commit'ile. Tulemuse näed Classroom 50-s.

## Rikkeotsing

??? note "Tabel 3.18. Osa 1 · Docker rolliga"

    | Mida näed | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | roll: `Destination directory /etc/docker/certs.d/… does not exist` | `ls /etc/docker/certs.d` | ülesanne „Harbori sertifikaadi kaust“ puudub või on pärast `copy`-t | `copy` ei loo puuduvat sihtkausta, kui `dest` on faili tee |
    | roll muutis `daemon.json`-i, aga Docker kasutab vana seadet | `sudo journalctl -u docker -n 5` | play peatus enne lõppu ja handler jäi käivitamata: `sudo systemctl restart docker` | handler käivitub play lõpus ainult siis, kui play jõuab lõpuni |
    | `deb822_repository`: `unsupported parameter` | `ansible --version` | ansible-core on vanem kui 2.15 | moodul lisati versioonis 2.15 |

