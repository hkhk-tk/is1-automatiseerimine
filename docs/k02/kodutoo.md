---
tags:
  - Ansible
  - Kodutöö
---

# 2. kohtumine · Kodutöö

## H1 · Uus kasutaja

Lisa `group_vars/all.yml`-is kasutajate nimekirja oma eesnimi. Proovi enne ühel masinal, siis kõigil:

```bash
ansible-playbook site.yml -K --ask-vault-pass --limit web01 --check
ansible-playbook site.yml -K --ask-vault-pass
ansible all -m ansible.builtin.command -a "id <sinu-nimi>"
```

??? success "Oodatav tulemus"

    `--check` näitab web01-l ühte `changed`-i, aga ei tee midagi. Päris käivitusel on igal masinal `changed=1` (kasutaja) ja veebiserveritel lisaks `changed` veebilehel, sest kasutajate nimekiri on lehel. `id` vastab igast masinast.

`git push`.

## H2 · app01 oma pealkiri

Tee fail `host_vars/app01.yml`, kus `veeb_pealkiri` on teistsugune. Vaata enne muudatust, siis tee:

```bash
ansible-playbook site.yml -K --ask-vault-pass --limit app01 --check --diff
ansible-playbook site.yml -K --ask-vault-pass --limit app01
ssh app01 curl -s http://localhost | grep h1
```

??? success "Oodatav tulemus"

    `--diff` näitab muudetud `<h1>` rida. Pärast käivitust on app01 lehel uus pealkiri, web01 oma jääb samaks.

`git push`.

## H3 · Uus parool

Vaheta andmebaasi kasutaja parool:

```bash
ansible-vault edit group_vars/andmebaas/vault.yml
ansible-playbook site.yml -K --ask-vault-pass --limit db01
ssh -t db01 "mysql -u labor -p -e 'SELECT 1;' labor"
```

??? success "Oodatav tulemus"

    Kasutaja ülesanne on `changed` ja väljundis `censored`. Uue parooliga sisselogimine töötab, vanaga mitte.

`git push`. Kontrolli GitHubis, et `vault.yml` on endiselt krüpteeritud.

## H4 · Boonus: kolmas veebiserver

Lisa `rmq01` gruppi `veeb` ainult inventory's. Rolli ega playbook'i ei muuda.

```bash
ansible-playbook site.yml -K --ask-vault-pass --limit rmq01
ssh rmq01 curl -s http://localhost | grep Masin
```

??? success "Oodatav tulemus"

    rmq01-l on nginx ja leht `Masin: rmq01`. Kolmanda veebiserveri lisamiseks kulus üks rida inventory's.

Võta `rmq01` pärast grupist välja ja eemalda nginx: `ansible rmq01 -b -K -m ansible.builtin.package -a "name=nginx state=absent"`. rmq01 läheb hiljem vaja teise teenuse jaoks.

---

Jäid kinni? Küsi [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehel, lisa käsk ja kogu veateade tekstina.
