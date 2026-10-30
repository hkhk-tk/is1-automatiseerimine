---
tags:
  - Ansible
  - Praktikum
---

# 2. Esimene roll

1. kohtumisel oli kõik ühes playbook'is. Viie teenuse puhul läheks selline fail pikaks ja segaseks. **Roll** on kaust, kus ühe teenuse ülesanded, mallid ja vaikeväärtused on koos kindlas ülesehituses. Playbook ütleb ainult, millised rollid millistes masinates käivitatakse.

Esimene roll `common` käib kõigis masinates. See kirjutab igasse masinasse kõigi viie masina nimed ja IP-aadressid, sest rakendus app01-s otsib andmebaasi nime `db01` järgi.

## A1 · Rolli kaustad

```bash
mkdir -p roles/common/tasks roles/common/templates roles/common/defaults
```

| Kaust | Mis seal on |
|---|---|
| `tasks/main.yml` | rolli ülesanded |
| `templates/` | mallid (`.j2`), millest Ansible teeb failid |
| `defaults/main.yml` | vaikeväärtused, mida grupi või masina muutuja saab üle kirjutada |
| `handlers/main.yml` | ülesanded, mis käivituvad ainult muudatuse järel (3. osas) |

*Tabel 1. Rolli ülesehitus.*

## A2 · Mall ja tsükkel

**Mall** on tekstifail, kuhu Ansible paneb muutujate väärtused. Mallid on Jinja2 keeles: `{{ muutuja }}` asendatakse väärtusega ja `{% for %}` kordab rida iga loendi elemendi kohta. Loo fail `roles/common/templates/hosts.j2`:

```jinja
{% for h in groups['all'] | sort %}
{{ hostvars[h].ansible_host }} {{ h }}
{% endfor %}
```

`groups['all']` on inventory kõigi masinate loend ja `hostvars[h].ansible_host` on masina `h` IP-aadress inventory's. Filter `sort` paneb nimed tähestiku järjekorda. Ilma selleta võib järjekord käivituste vahel erineda ja fail muutuks igal korral.

## A3 · Ülesanded

Fail `roles/common/defaults/main.yml`:

```yaml
common_motd: "Seda masinat haldab Ansible (Labori seis)."
```

Fail `roles/common/tasks/main.yml`:

```yaml
- name: Masinad tunnevad üksteist nime järgi
  ansible.builtin.blockinfile:
    path: /etc/hosts
    marker: "# {mark} labori-seis"
    block: "{{ lookup('ansible.builtin.template', 'hosts.j2') }}"

- name: Teade sisselogimisel
  ansible.builtin.copy:
    dest: /etc/motd
    content: "{{ common_motd }}\n"
    mode: "0644"
```

| Moodul | Mida teeb | Parameetrid selles rollis |
|---|---|---|
| [`ansible.builtin.blockinfile`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/blockinfile_module.html) | haldab failis ühte märgistatud plokki, ülejäänud faili ei puutu | `path`: fail, `marker`: ploki algus- ja lõpurida, `block`: ploki sisu |
| [`ansible.builtin.copy`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/copy_module.html) | kirjutab faili sisu | `dest`, `content`, `mode` |

*Tabel 2. Moodulid selles rollis.*

`lookup('ansible.builtin.template', 'hosts.j2')` teeb mallist teksti control node'is ja annab selle plokiks. Vaata, mida teeb `blockinfile` olemasoleva ploki korral: `ansible-doc ansible.builtin.blockinfile`.

## A4 · Playbook `site.yml`

Loo fail `site.yml`. Esimene play käivitab rolli `common` kõigis masinates. Järgmistes osades lisad siia iga teenuse play.

```yaml
- name: Kõik masinad
  hosts: all
  become: true
  roles:
    - common
```

**Ennusta:** mitu ülesannet on esimesel käivitusel `changed` ja mitu teisel?

```bash
ansible-playbook site.yml
ansible-playbook site.yml
ssh app01 getent hosts db01
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on igas masinas kaks muudatust, teisel `changed=0`. `getent` näitab db01 IP-aadressi, mille rakendus app01-s nüüd nime järgi leiab.

Salvesta roll ja playbook:

```bash
git add -A
git commit -m "k02: roll common"
git push
```

**Valmis, kui** `ssh app01 getent hosts db01` näitab db01 IP-aadressi ja teine käivitus annab `changed=0`.

??? info "Loe juurde"

    - [Roles](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
    - [Templating (Jinja2)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_templating.html)
