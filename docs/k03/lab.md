---
tags:
  - Docker
  - Compose
  - Trivy
---

# 3. kohtumine · Praktikum: Labori seis konteinerites

Kahel esimesel kohtumisel seadistasid Ansible'iga teenused otse virtuaalmasinatesse. Nüüd pakid sama rakenduse, Labori seisu, konteineritesse: viis teenust käivituvad ühe `compose.yaml`-iga control node'is, image'id tulevad sinu Dockerfile'idest ja lõpuks on need kooli registry's.

!!! info "Selle korra töö"
    - **Masin:** control node (Ubuntu 24.04), kaust `k03-docker/` repositooriumi juures; Podmani osas mc01 ja db01 (AlmaLinux 9)
    - **Ülesanded:** issue `K3` sinu repositooriumis, märkeruut iga osa kohta
    - **Tõendid:** fail `k03-docker/TOEND.md`, sellest saab PR-i kirjeldus
    - **Esitamine:** haru `k03-docker` → PR → merge → tag `k03`
    - **Eelmisest korrast vaja:** tag `k02` `main`-is; koolitajalt Gitea ajutine parool

Kui juhendis on **Ennusta:**, ütle vastus enne käsu käivitamist naabrile või mõtle see läbi. Seejärel käivita käsk ja võrdle tulemust oma ennustusega.

Iga osa alguses on rida **Kui teed seda tööl iga päev**. Kui see kirjeldab sinu igapäevast tööd, võid osa alguse vahele jätta ja minna otse viidatud etappi.

## Mis on kohustuslik

Osad 1–4 teed kohtumisel (laupäeval kell 10–15). Osad 5–9 võid lõpetada pärast kohtumist, kuid enne 4. kohtumist: 4. kohtumine eeldab töötavat stacki ja `main`-is olevat `compose.yaml`-i.

| Osa | Mida teed |
|---|---|
| [1. Konteinerid käsitsi](lab-1-kasitsi.md) | Docker hostis, elutsükkel, võrgud, mälu- ja CPU-piirangud, restart-poliitika, volume |
| [2. db ja web image](lab-2-db-web.md) | kaks Dockerfile'i ametlike image'ite põhjal, init-skripti lõks, `.dockerignore` |
| [3. App image](lab-3-app-image.md) | mitmeastmeline build, cache, kihid, mitte-root kasutaja |
| [4. Kogu stack Compose'iga](lab-4-compose.md) | viis teenust healthcheck'idega, idempotentne `up -d`, rikketest |
| [5. Tootmiskeskkonda sobiv stack](lab-5-tootmine.md) | piirangud, saladused failidest, sisemine võrk, logid, varundus |
| [6. Registry, Trivy ja SBOM](lab-6-registry.md) | image'id Gitea's, tag ja digest, haavatavused, SBOM |
| [7. Sama teenus Podmaniga](lab-7-podman.md) | mc01 ja db01 rootless Podmanis, Quadlet, SELinux |
| [8. Kolm riket](lab-8-kolm-riket.md) | vigane stack, diagnoos ja parandus koodis |
| [9. Esitamine](lab-9-esitamine.md) | värske klooni test, PR, tag `k03` |

*Tabel 1. Praktikumi osad.*

Iga osa lõpeb commit'iga. Automaatne hindaja kontrollib tag'i `k03` juures faile, Compose'i faili, sõltuvusi, build'i ja image'ite versioone. Registry, Trivy, Podmani ja intsidendi osa vaatab koolitaja PR-ist.

??? info "Testitud versioonid"

    Docker Engine 29 (vähemalt 28), Compose v5, `mariadb:11.4`, `rabbitmq:4.1-management-alpine`, `memcached:1.6-alpine`, `nginx:1.30-alpine`, `tomcat:10.1-jre21-temurin`, `maven:3-eclipse-temurin-21`; Podman 5 (AlmaLinux 9). Lisaülesannetes ka rootless Docker, `registry:2`, `louislam/uptime-kuma:2`, `alpine:3.22` ja `docker:29-cli`.

    Dokumentatsioon: [Dockerfile](https://docs.docker.com/reference/dockerfile/) · [Compose](https://docs.docker.com/reference/compose-file/) · [Podman](https://docs.podman.io/) · [Trivy](https://trivy.dev/docs/latest/)

Veaotsing: [Abi](abi.md).
