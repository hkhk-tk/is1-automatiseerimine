---
tags:
  - Ansible
  - Praktikum
---

# 2. kohtumine · Praktikum

!!! info "Selle korra töö"

    - **Masinad:** control node ja viis labori VM-i (web01, app01, rmq01 Ubuntu; mc01, db01 AlmaLinux), kasutaja `kasutaja`
    - **Failid:** sinu kursuse repo, kaust `~/kursus/k02/`
    - **Esitamine:** `git push`

| Etapp | Mida teed | Valmis, kui |
|---|---|---|
| [1. Algseis](lab-1-algseis.md) | projekt 1. kohtumise failide põhjal, uued grupid, `group_vars` ja `host_vars` | web01-l on muutuja väärtus teistest erinev |
| [2. Kasutajad](lab-2-kasutajad.md) | kolm kasutajat `loop`-iga, `register` | teisel käivitusel on `changed=0` |
| [3. Veebiserver](lab-3-veebiserver.md) | nginx, mall ja handler | web01 ja app01 veebilehel on masina nimi |
| [4. Andmebaas](lab-4-andmebaas.md) | MariaDB db01-s, kogu, parool Vaultis | kasutaja `labor` saab andmebaasi sisse logida |
| [5. Rollid](lab-5-rollid.md) | kõik kolm osa rollideks, `site.yml` | `site.yml` teisel käivitusel on `changed=0` |
| [6. Kontrollitud muudatus ja esitamine](lab-6-esitamine.md) | `--check --diff`, `serial` ja töö esitamine | projekt on GitHubis, Vaulti parool ei ole |

*Tabel 1. Praktikumi etapid.*

Vajad abi? [Abi](abi.md)

Jäi aega üle? [Lisaülesanded](lisa.md)
