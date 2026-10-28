---
tags:
  - Kursuse ülevaade
---

# Töö repos ja hindamine

## Päev

| Kell | Mis |
|---|---|
| 10:00–11:30 | loeng |
| 11:30–12:30 | labor |
| 12:30–13:00 | lõuna |
| 13:00–15:00 | labor |

*Tabel 0.3. Kohtumise päev.*

Labor on jagatud mooduliteks. Iga kohtumise laborilehel on tabel „Mis on kohustuslik“: millised moodulid teed kohtumise ajal ja mida
võid lõpetada hiljem. Mis klassis pooleli jääb, lõpetad kodus VPN-i kaudu. 7. kohtumise lõpus on lõputest.

## Repo

Classroom 50 annab sulle repo `<klassiruum>-labori-seis-<github>`.

| Kaust | Kohtumine |
|---|---|
| `k01-bash/` | 1 (starteris mustandid, kolm tahtlikku viga) |
| `k02-ansible/` | 2 |
| `k03-docker/`, `.dockerignore` | 3 |
| `k04-tofu/` | 4 |
| `.github/workflows/` | 5 (`ci.yml`), 7 (`gitops.yml`) |
| `k06-jenkins/` | 6 |
| `k07-k8s/` | 7 (starteris mustandid) |
| `cloud/` | AWS kodutööd |

*Tabel 0.4. Repo kaustad.*

## Igal kohtumisel

1. Uus haru: `git switch -c k01-bash` (2. kohtumisel `k02-ansible` jne).
2. Kohtumise issue'd on milestone'is `K1` … `K7`, label `plokk`. Üks issue on üks plokk. Sulge see commit'iga `… (closes #3)`.
3. Kontrolli ise: `bash autograde/check.sh k01 shellcheck`. Kõik testid on failis `autograde/TESTS.md`.
4. Kohtumise lõpus: PR `main`-i, merge, siis tag:

    ```bash
    git switch main && git pull
    git tag k01 && git push origin k01
    ```

Parandus pärast tag'i: uus commit, siis `git tag -f k01 && git push -f origin k01`. `-f` käib ainult tag'i kohta, `main`-i ei
force-push'ita kunagi. Kui jäid maha, võta koolitaja eelmise korra lahendus (`lahendus/kNN`, vt repo `README.md`) ja jätka sealt.

## Hindamine

| Hindamiskriteerium | Kohtumine | Mis näitab |
|---|---|---|
| HK1 | 1 | Bashi skriptid: stack üles, ShellCheck puhas, saladused Gitist väljas |
| HK2 | 2 | Ansible'i rollid, Vault, idempotentsus |
| HK3 | 4 | OpenTofu: viis VM-i, moodul, inventory Ansible'ile |
| HK4 | 3 | Dockerfile'id, Compose, image registry's |
| HK5 | 5 ja 6 | CI/CD pipeline GitHub Actionsis ja Jenkinsis |
| HK6 | 7 | lõputest, Kubernetes ja GitOps |

*Tabel 0.5. Hindamiskriteeriumid. Numbrid tulevad õppekavast, seepärast on HK3 4. ja HK4 3. kohtumisel.*

Automaatne hindaja annab iga kohtumise tag'ile kuni 100 punkti. Tag'i `k03` juures loeb ainult 3. kohtumise osa, hilisemate kohtumiste
testid näitavad `SKIP`. Kas stack Proxmoxis ja klastris töötab, näeb koolitaja Labori seisust, kuhu sinu `check.sh` tulemused saadab.
