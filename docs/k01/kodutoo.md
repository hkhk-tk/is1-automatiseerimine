---
tags:
  - Bash
  - Ansible
  - Kodutöö
---

# 1. kohtumine · Kodutöö

## Test

Vasta [1. kohtumise testile](https://docs.google.com/forms/d/e/1FAIpQLSdd-Ah3cswzPvXM8J4PN3mUVHnoT7q67U9IZU3CokmbaLdl7w/viewform): 12 küsimust loengu ja praktikumi kohta. Pärast saatmist näed oma tulemust ja õigeid vastuseid.

## H1 · Muuda üht väärtust

Muuda playbook'is `training.yml` faili sisu: `enabled=true` → `enabled=false`. Käivita kaks korda:

```bash
ansible-playbook training.yml
ansible-playbook training.yml
```

??? success "Oodatav tulemus"

    Esimene kord: failiülesanne `changed`. Teine kord: `changed=0`. Kontroll masinas:

    ```bash
    ssh web01 cat ~/automation-lab/training.conf
    ```

Commit'i sõnumisse kirjuta üks lause: mis muutus ja mida näitas teine käivitus. `git push`.

## H2 · Sama seadistus kõigile Ubuntu masinatele

Muuda `training.yml`-is `hosts: web01` → `hosts: ubuntu`. Proovi enne ühe uue masinaga, siis kõigiga:

```bash
ansible-playbook training.yml --limit app01 --check --diff
ansible-playbook training.yml
```

??? success "Oodatav tulemus"

    `--check` näitab app01 kohta muudatusi, aga ei tee neid. Päris käivitusel on app01 ja rmq01 `changed`, web01 `ok`, sest seal oli kõik juba õige.

`git push`.

## H3 · Boonus: sama tööriist, eri nimi

Lisa `tools.yml`-i tööriist `dig` (DNS-päringud). Ubuntul on see paketis `dnsutils`, AlmaLinuxil `bind-utils`. Kasuta sama mustrit nagu `vim`-i puhul: kaks ülesannet, `when` ja silt `paketid`.

```bash
ansible-playbook tools.yml -K --tags paketid
ansible all -m ansible.builtin.command -a "dig +short github.com"
```

??? success "Oodatav tulemus"

    Esimene käsk: Ubuntu masinatel `dnsutils` `changed`, AlmaLinuxi masinatel `bind-utils` `changed`, vastupidised ülesanded `skipping`. Teine käsk: igast masinast üks või mitu IP-aadressi.

`git push`.

---

Jäid kinni? Küsi [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehel, lisa käsk ja kogu veateade tekstina.
