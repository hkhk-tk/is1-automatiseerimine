---
tags:
  - Ansible
  - Praktikum
---

# 6. Kontrollitud muudatus ja esitamine

!!! abstract "Eesmärgid"

    - vaatad muudatust enne selle tegemist (`--check --diff`);
    - proovid muudatust kõigepealt ühes masinas (`--limit`);
    - rakendad muudatust masinhaaval (`serial`);
    - esitad projekti.

Kõik käsud käivita control node'is kaustas `~/kursus/k02`.

## A1 · Muudatus mallis

Lisa `roles/veeb/templates/index.html.j2`-sse enne `</body>` rida:

```html
  <p>Kursus: {{ kursus }}</p>
```

Kontrolli enne käivitamist, mis web01-s muutuks:

```bash
ansible-playbook site.yml --ask-vault-pass --check --diff --limit web01
```

??? success "Oodatav tulemus"

    ```
    +  <p>Kursus: IS1-26</p>
    changed: [web01]
    ```

    `--check` ei muutnud masinas midagi: käsk `ssh web01 curl -s http://localhost | grep Kursus` ei leia veel midagi.

Rakenda muudatus web01-s ja kontrolli tulemust:

```bash
ansible-playbook site.yml --ask-vault-pass --limit web01
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
ansible-playbook site.yml --ask-vault-pass
```

??? success "Oodatav tulemus"

    Veebiserverite play käivitatakse kaks korda: kõigepealt kõik ülesanded web01-s, seejärel app01-s (inventory järjekorras). web01 oli juba muudetud, seega on seal tulemus `ok`, app01-s `changed`. Kui web01-s oleks midagi ebaõnnestunud, ei oleks play app01-ni jõudnud.

Teisel käivitusel on `changed=0`.

## A3 · Töö esitamine

```bash
cd ~/kursus
git add -A k02
git commit -m "k02: serial ja muudatus mallis"
git push
```

Ava oma repositoorium GitHubis ja kontrolli, et seal on järgmised failid:

| Fail või kaust | Kus see tehti |
|---|---|
| `ansible.cfg`, `inventory.ini` | [1. Algseis](lab-1-algseis.md) |
| `group_vars/`, `host_vars/` | [1. Algseis](lab-1-algseis.md), [4. Andmebaas](lab-4-andmebaas.md) |
| `requirements.yml` | [4. Andmebaas](lab-4-andmebaas.md) |
| `roles/common`, `roles/veeb`, `roles/andmebaas` | [5. Rollid](lab-5-rollid.md) |
| `site.yml` | [5. Rollid](lab-5-rollid.md) ja A2 |

*Tabel 1. Esitatavad failid.*

Ava GitHubis fail `group_vars/andmebaas/vault.yml`. Selle sisu peab algama reaga `$ANSIBLE_VAULT`.

**Valmis, kui** kõik failid on GitHubis, `vault.yml` on krüpteeritud ja `site.yml` teisel käivitusel on `changed=0`.

Edasi: [Kodutöö](kodutoo.md).
