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

Kui soovitud olek muutub, muudad playbook'i, mitte masinat. Asenda playbook'is `training.yml` rida `enabled=true` reaga `enabled=false` ja käivita playbook kaks korda:

```bash
ansible-playbook training.yml
ansible-playbook training.yml
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on faili ülesande olek `changed`, teisel käivitusel on kokkuvõttes `changed=0`. Kontrolli faili sisu masinas:

    ```bash
    ssh web01 cat ~/automation-lab/training.conf
    ```

Tee muudatustest commit. Kirjelda commit'i sõnumis lühidalt, mida muutsid. Seejärel saada muudatused GitHubi.

**Mõtle:** mida näitas teine käivitus ja miks Ansible ei muutnud faili uuesti?

## H2 · Sama seadistus kõigile Ubuntu masinatele

Sama playbook sobib kõigile Ubuntu masinatele, kui muuta ainult sihtmasinaid. Asenda `training.yml`-is `hosts: web01` reaga `hosts: ubuntu`. Kontrolli muudatust kõigepealt masinas `app01` ja rakenda see seejärel kõigile grupi masinatele:

```bash
ansible-playbook training.yml --limit app01 --check --diff
ansible-playbook training.yml
```

??? success "Oodatav tulemus"

    `--check` näitab, mida Ansible masinas app01 muudaks, kuid ei tee muudatusi. Tavalisel käivitusel on app01 ja rmq01 olek `changed` ning web01 olek `ok`, sest web01 tegelik olek vastas juba soovitud olekule.

Tee muudatustest commit ja saada need GitHubi.

## H3 · Boonus: sama programm, erinev paketinimi

Lisa `tools.yml`-i programm `dig`, millega saab teha DNS-päringuid. Ubuntus on see paketis `dnsutils`, AlmaLinuxis paketis `bind-utils`. Kasuta sama mustrit nagu `vim`-i puhul: kaks ülesannet, `when` ja silt `paketid`.

```bash
ansible-playbook tools.yml --tags paketid
ansible all -m ansible.builtin.command -a "dig +short github.com"
```

??? success "Oodatav tulemus"

    Esimese käsu järel on Ubuntu masinates paketi `dnsutils` ülesande olek `changed` ja AlmaLinuxi masinates paketi `bind-utils` ülesande olek `changed`. Teise distributsiooni ülesanded on olekus `skipping`. Teine käsk kuvab igast masinast ühe või mitu IP-aadressi.

Tee muudatustest commit ja saada need GitHubi.

Vajad abi? Kirjuta [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehele. Lisa käsk ja kogu veateade tekstina.
