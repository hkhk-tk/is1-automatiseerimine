---
tags:
  - Ansible
  - Praktikum
---

# 5. Rollid

!!! abstract "Eesmärgid"

    - viid kolme playbook'i sisu üle rollidesse `common`, `veeb` ja `andmebaas`;
    - paned rolli vaikeväärtused `defaults/main.yml`-i;
    - seadistad kogu labori ühe käsuga, käivitades `site.yml`-i.

Kõik käsud käivita control node'is kaustas `~/kursus/k02`. Masinates ei muutu midagi: töötav kood saab uue ülesehituse.

## A1 · Kaustad

```bash
mkdir -p roles/common/tasks
mkdir -p roles/veeb/{tasks,handlers,templates,defaults}
mkdir -p roles/andmebaas/tasks
git mv templates/index.html.j2 templates/labor.conf.j2 roles/veeb/templates/
```

## A2 · Ülesanded rollidesse

Rolli failis on ainult ülesannete loend, ilma ridadeta `hosts`, `become` ja `tasks:`.

1. `roles/common/tasks/main.yml`: kopeeri `users.yml`-ist kõik kolm ülesannet.
2. `roles/veeb/tasks/main.yml`: kopeeri `veeb.yml`-ist kõik ülesanded.
3. `roles/veeb/handlers/main.yml`: kopeeri handler `reload nginx`.
4. `roles/andmebaas/tasks/main.yml`: kopeeri `andmebaas.yml`-ist kõik neli ülesannet.

Pane tähele taanet: rolli failis algab iga ülesande rida `- name:` vasakust servast.

??? tip "Vihje: nii näeb välja `roles/veeb/handlers/main.yml`"

    ```yaml
    - name: reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
    ```

## A3 · Vaikeväärtused

Fail `roles/veeb/defaults/main.yml`:

```yaml
veeb_pealkiri: "Veebiserver"
veeb_port: 80
```

Rolli vaikeväärtustel on kõige madalam prioriteet: `group_vars/veeb.yml` ja `host_vars/web01.yml` kirjutavad need üle. Roll töötab ka siis, kui keegi neid muutujaid ei määra.

## A4 · `site.yml`

Fail `site.yml`:

```yaml
- name: Kõik masinad
  hosts: all
  become: true
  roles:
    - common

- name: Veebiserverid
  hosts: veeb
  become: true
  roles:
    - veeb

- name: Andmebaas
  hosts: andmebaas
  become: true
  roles:
    - andmebaas
```

Vanu playbook'e pole enam vaja:

```bash
git rm users.yml veeb.yml andmebaas.yml
ansible-playbook site.yml --syntax-check --ask-vault-pass
```

## A5 · Käivita

Enne käivitamist ennusta tulemust. Masinate tegelik olek vastab juba soovitud olekule. Mida näitab PLAY RECAP?

```bash
ansible-playbook site.yml --ask-vault-pass
```

??? success "Oodatav tulemus"

    Väljundis on kolm play'd ja ülesannete ees on rolli nimi (`TASK [veeb : nginx on paigaldatud]`). Kõigis viies masinas on `changed=0`: rollid tegid sama tööd mis playbook'id ja tegelik olek vastas juba soovitud olekule.

??? warning "Kui midagi on `changed` või `failed`"

    Võrdle rolli faili vana playbook'iga (`git show HEAD:k02/veeb.yml`). Sagedased vead: rida `- name:` on taandega, handler'i nimi erineb `notify` väärtusest või mall on vales kaustas.

```bash
find roles -type f
```

## A6 · Commit

```bash
cd ~/kursus
git add -A k02
git commit -m "k02: rollid ja site.yml"
git push
```

**Valmis, kui** `site.yml` teisel käivitusel on kõigis viies masinas `changed=0`.

??? info "Loe juurde"

    - [Roles](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
    - [Sample Ansible setup](https://docs.ansible.com/projects/ansible/latest/tips_tricks/sample_setup.html)
