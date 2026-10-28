---
tags:
  - Ansible
  - Praktikum
---

# 6. Kontrollitud muudatus ja esitamine

!!! abstract "Eesmärgid"

    - näed muudatust enne tegemist (`--check --diff`);
    - proovid muudatust ühel masinal (`--limit`);
    - levitad muudatust masinhaaval (`serial`);
    - esitad projekti.

Kõik käsud käivad control node'il kaustas `~/kursus/k02`.

## A1 · Muudatus mallis

Lisa `roles/veeb/templates/index.html.j2`-sse enne `</body>` rida:

```html
  <p>Kursus: {{ kursus }}</p>
```

Vaata enne, mis muutuks, ainult web01-l:

```bash
ansible-playbook site.yml -K --ask-vault-pass --check --diff --limit web01
```

??? success "Oodatav tulemus"

    ```
    +  <p>Kursus: IS1-26</p>
    changed: [web01]
    ```

    `--check` ei muutnud midagi: `ssh web01 curl -s http://localhost | grep Kursus` ei leia veel midagi.

Nüüd päriselt ühel masinal, siis kontroll:

```bash
ansible-playbook site.yml -K --ask-vault-pass --limit web01
ssh web01 curl -s http://localhost | grep Kursus
```

## A2 · `serial`

Lisa `site.yml`-is play'le `Veebiserverid` rida `serial: 1` (rea `become: true` alla):

```yaml
- name: Veebiserverid
  hosts: veeb
  become: true
  serial: 1
  roles:
    - veeb
```

```bash
ansible-playbook site.yml -K --ask-vault-pass
```

??? success "Oodatav tulemus"

    Veebiserverite play käib kaks korda: kõigepealt kõik ülesanded web01-l, siis app01-l (inventory järjekorras). web01 oli juba muudetud, seega seal `ok`; app01-l `changed`. Kui web01-l oleks midagi ebaõnnestunud, ei oleks play app01-ni jõudnud.

Teine käivitus: `changed=0`.

## A3 · Esita

```bash
cd ~/kursus
git add -A k02
git commit -m "k02: serial ja muudatus mallis"
git push
```

Ava oma repo GitHubis ja kontrolli:

| Fail või kaust | Kust |
|---|---|
| `ansible.cfg`, `inventory.ini` | [1. Algseis](lab-1-algseis.md) |
| `group_vars/`, `host_vars/` | [1. Algseis](lab-1-algseis.md), [4. Andmebaas](lab-4-andmebaas.md) |
| `requirements.yml` | [4. Andmebaas](lab-4-andmebaas.md) |
| `roles/common`, `roles/veeb`, `roles/andmebaas` | [5. Rollid](lab-5-rollid.md) |
| `site.yml` | [5. Rollid](lab-5-rollid.md) ja A2 |

*Tabel 1. Esitatavad failid.*

Ava GitHubis `group_vars/andmebaas/vault.yml`: sisu peab algama `$ANSIBLE_VAULT`.

**Valmis, kui** kõik failid on GitHubis, `vault.yml` on krüpteeritud ja `site.yml` teine käivitus annab `changed=0`.

Edasi: [Kodutöö](kodutoo.md).
