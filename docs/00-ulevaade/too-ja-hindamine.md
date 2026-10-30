---
tags:
  - Kursuse ülevaade
---

# Töö repositooriumis ja hindamine

## Repositoorium

Classroom 50 loob sulle repositooriumi `<klassiruum>-labori-seis-<github>`.

| Kaust | Kohtumine |
|---|---|
| `k01/` | 1 (`prepare-training.sh`, `ansible.cfg`, `inventory.ini`, `training.yml`, `tools.yml`) |
| `k02-ansible/` | 2 |
| `k03-docker/`, `.dockerignore` | 3 |
| `k04-tofu/` | 4 |
| `.github/workflows/` | 5 (`ci.yml`), 7 (`gitops.yml`) |
| `k06-jenkins/` | 6 |
| `k07-k8s/` | 7 (starteris mustandid) |
| `cloud/` | AWS kodutööd |

*Tabel 0.4. Repositooriumi kaustad.*

## Igal kohtumisel

1. 1. kohtumisel salvestad failid kausta `k01/` ja töötad otse harus `main`. Alates 2. kohtumisest töötad oma harus: `git switch -c k02` jne.
2. Iga kohtumise ülesanded on sinu repositooriumis issue'na (vahekaart **Issues**). Issue'is on märkeruut iga praktikumi osa ja kodutöö kohta. Märgi osa tehtuks, kui oled selle lõpetanud.
3. Kohtumise lõpus esita töö tag'iga. Alates 2. kohtumisest tee enne seda pull request harusse `main` ja ühenda see (merge).

    ```bash
    git switch main && git pull
    git tag k01 && git push origin k01
    ```

Kui pead pärast tag'i midagi parandama, tee uus commit ja seejärel `git tag -f k01 && git push -f origin k01`. Võti `-f` kehtib ainult tag'i kohta: harule `main` ei tehta kunagi force-push'i. Kui jäid maha, kirjuta arutelu kategooriasse **Küsimused**.

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

Automaatne hindaja annab iga kohtumise tag'ile kuni 100 punkti. Tag'i `k03` puhul arvestatakse ainult 3. kohtumise
teste ja hilisemate kohtumiste testide tulemus on `SKIP`. Kas rakendus Proxmoxis ja klastris töötab, näeb koolitaja rakendusest Labori seis, kuhu `check.sh` tulemused saadab.
