---
tags:
  - Ansible
  - Kodutöö
---

# 2. kohtumine · Kodutöö

## H1 · Uus kasutaja

Lisa failis `group_vars/all.yml` kasutajate loendisse oma eesnimi. Kontrolli muudatust kõigepealt ühes masinas ja rakenda see seejärel kõigile:

```bash
ansible-playbook site.yml --ask-vault-pass --limit web01 --check
ansible-playbook site.yml --ask-vault-pass
ansible all -m ansible.builtin.command -a "id <sinu-nimi>"
```

??? success "Oodatav tulemus"

    `--check` näitab web01-s ühte muudatust (`changed`), kuid ei muuda midagi. Käivitamisel on igas masinas `changed=1` (kasutaja) ning veebiserverites on lisaks `changed` veebilehe ülesandel, sest kasutajate loend on lehel. Käsk `id` leiab kasutaja igast masinast.

Tee muudatustest commit ja saada need GitHubi.

## H2 · app01 oma pealkiri

Loo fail `host_vars/app01.yml`, milles on muutujal `veeb_pealkiri` teine väärtus. Vaata muudatust enne käivitamist ja rakenda see seejärel:

```bash
ansible-playbook site.yml --ask-vault-pass --limit app01 --check --diff
ansible-playbook site.yml --ask-vault-pass --limit app01
ssh app01 curl -s http://localhost | grep h1
```

??? success "Oodatav tulemus"

    `--diff` näitab muudetud `<h1>` rida. Pärast käivitamist on app01 veebilehel uus pealkiri ja web01 pealkiri jääb samaks.

Tee muudatustest commit ja saada need GitHubi.

## H3 · Uus parool

Vaheta andmebaasi kasutaja parool:

```bash
ansible-vault edit group_vars/andmebaas/vault.yml
ansible-playbook site.yml --ask-vault-pass --limit db01
ssh -t db01 "mysql -u labor -p -e 'SELECT 1;' labor"
```

??? success "Oodatav tulemus"

    Kasutaja ülesande tulemus on `changed` ja väljundis on `censored`. Uue parooliga sisselogimine töötab, vanaga mitte.

Tee muudatustest commit ja saada need GitHubi. Kontrolli GitHubis, et `vault.yml` on endiselt krüpteeritud.

## H4 · Boonus: kolmas veebiserver

Lisa `rmq01` gruppi `veeb` ainult inventory's. Rolli ega playbook'i ära muuda.

```bash
ansible-playbook site.yml --ask-vault-pass --limit rmq01
ssh rmq01 curl -s http://localhost | grep Masin
```

??? success "Oodatav tulemus"

    rmq01-s töötab nginx ja veebilehel on `Masin: rmq01`. Kolmanda veebiserveri lisamiseks piisas ühest reast inventory's.

Seejärel eemalda `rmq01` grupist `veeb` ja eemalda nginx: `ansible rmq01 -b -m ansible.builtin.package -a "name=nginx state=absent"`. rmq01-s hakkab hiljem tööle teine teenus.

---

Vajad abi? Kirjuta [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehele ning lisa käsk ja kogu veateade tekstina.
