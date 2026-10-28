---
tags:
  - Bash
  - Ansible
  - Kodutöö
---

# 1. kohtumine · Kodutöö

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

## H2 · Sama seadistus teise masinasse

Lisa inventory'sse `app01` gruppi `veeb` ja muuda playbook'is `hosts: web01` → `hosts: veeb`. Proovi enne ainult uue masinaga:

```bash
ansible-playbook training.yml --limit app01 --check --diff
ansible-playbook training.yml
```

??? success "Oodatav tulemus"

    `--check` näitab app01 kohta muudatusi, aga ei tee neid. Päris käivitusel on app01 `changed`, web01 `ok`, sest seal oli kõik juba õige.

`git push`.

## H3 · Boonus: skript, mis ei tee asjata tööd

Praktikumi `ssh-seadistus.sh` paneb igal käivitusel masinale nime, ka siis, kui nimi on juba õige. Muuda funktsiooni `seadista` nii, et `hostnamectl` käivitub ainult siis, kui praegune nimi on vale.

??? tip "Vihje"

    ```bash
    praegune=$(ssh -n "$nimi" hostname)
    if [[ "$praegune" != "$nimi" ]]; then
        ...
    fi
    ```

??? success "Oodatav tulemus"

    Teisel käivitusel ei küsi `sudo` enam ühtegi parooli.

`git push`.

---

Jäid kinni? Küsi [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehel, lisa käsk ja kogu veateade tekstina.
