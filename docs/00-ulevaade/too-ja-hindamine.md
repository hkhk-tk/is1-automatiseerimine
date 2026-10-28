---
tags:
  - Kursuse ülevaade
---

# Töö repos ja hindamine

## Repo

Classroom 50 annab sulle repo `<klassiruum>-labori-seis-<github>`.

| Kaust | Kohtumine |
|---|---|
| `k01/` | 1 (`ansible.cfg`, `inventory.ini`, `training.yml`, `tools.yml`) |
| `k02-ansible/` | 2 |
| `k03-docker/`, `.dockerignore` | 3 |
| `k04-tofu/` | 4 |
| `.github/workflows/` | 5 (`ci.yml`), 7 (`gitops.yml`) |
| `k06-jenkins/` | 6 |
| `k07-k8s/` | 7 (starteris mustandid) |
| `cloud/` | AWS kodutööd |

*Tabel 0.4. Repo kaustad.*

## Igal kohtumisel

1. 1. kohtumisel lähevad failid kausta `k01/` ja töötad otse `main`-is. Alates 2. kohtumisest töötad oma harus: `git switch -c k02` jne.
2. Kohtumise issue'd on milestone'is `K1` … `K7`, label `plokk`. Üks issue on üks plokk. Sulge see commit'iga `… (closes #3)`.
3. Kontrolli ise, näiteks: `bash autograde/check.sh k01 files`. Kõik testid on failis `autograde/TESTS.md`.
4. Kohtumise lõpus esita tag'iga. Alates 2. kohtumisest tee enne PR `main`-i ja merge.

    ```bash
    git switch main && git pull
    git tag k01 && git push origin k01
    ```

Parandus pärast tag'i: uus commit, siis `git tag -f k01 && git push -f origin k01`. `-f` käib ainult tag'i kohta, `main`-i ei
force-push'ita kunagi. Kui jäid maha, võta koolitaja eelmise korra lahendus (`lahendus/kNN`, vt repo `README.md`) ja jätka sealt.

## Hindamine

| Hindamiskriteerium | Kohtumine | Mis näitab |
|---|---|---|
| HK1 | 1 | Bashi skript ja Ansible'i playbook annavad nõutud tulemuse; korduva käivituse käitumine on kontrollitud |
| HK2 | 2 | Ansible'i rollid, Vault, idempotentsus |
| HK3 | 4 | OpenTofu: viis VM-i, moodul, inventory Ansible'ile |
| HK4 | 3 | Dockerfile'id, Compose, image registry's |
| HK5 | 5 ja 6 | CI/CD pipeline GitHub Actionsis ja Jenkinsis |
| HK6 | 7 | lõputest, Kubernetes ja GitOps |

*Tabel 0.5. Hindamiskriteeriumid. Numbrid tulevad õppekavast, seepärast on HK3 4. ja HK4 3. kohtumisel.*

Automaatne hindaja annab iga kohtumise tag'ile kuni 100 punkti. Tag'i `k03` juures loeb ainult 3. kohtumise osa, hilisemate kohtumiste
testid näitavad `SKIP`. Kas stack Proxmoxis ja klastris töötab, näeb koolitaja Labori seisust, kuhu sinu `check.sh` tulemused saadab.
