---
tags:
  - Ansible
  - Praktikum
---

# 2. kohtumine · Praktikum

!!! info "Selle korra töö"

    - **Masinad:** control node ja viis labori VM-i (web01, app01, rmq01 Ubuntu; mc01, db01 Rocky), kasutaja `kasutaja`
    - **Failid:** sinu kursuse repo, kaust `~/kursus/k02/`
    - **Esitamine:** `git push`

| Etapp | Mida teed | Valmis, kui |
|---|---|---|
| [1. Algseis](lab-1-algseis.md) | projekt k01 põhjal, uued grupid, `group_vars` ja `host_vars` | web01 näitab teist väärtust kui teised |
| [2. Kasutajad](lab-2-kasutajad.md) | kolm kasutajat `loop`-iga, `register` | teine käivitus `changed=0` |
| [3. Veebiserver](lab-3-veebiserver.md) | nginx, mall, handler | web01 ja app01 näitavad oma nime |
| [4. Andmebaas](lab-4-andmebaas.md) | MariaDB db01-l, kogu, parool Vaultis | kasutaja `labor` saab sisse |
| [5. Rollid](lab-5-rollid.md) | kõik kolm osa rollideks, `site.yml` | `site.yml` teine käivitus `changed=0` |
| [6. Kontrollitud muudatus ja esitamine](lab-6-esitamine.md) | `--check --diff`, `serial`, `git push` | projekt GitHubis, Vaulti parool mitte |

*Tabel 1. Praktikumi etapid.*

Kinni jäid? [Abi](abi.md)

Jäi aega üle? [Lisaülesanded](lisa.md)
