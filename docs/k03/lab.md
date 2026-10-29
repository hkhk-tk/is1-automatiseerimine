---
tags:
  - Docker
  - Compose
  - Trivy
---

# 3. kohtumine, labor: Labori seis konteinerites

!!! info "Selle korra töö"
    - **Masin:** control node (Ubuntu 24.04, ≥ 4 GB RAM, 20 GB vaba), kaust `k03-docker/` repo juures, tõendid `k03-docker/TOEND.md`
    - **Sihtmasinad:** Compose'i stack töötab control node'is (app01-s töötab 1. ja 2. kohtumisel paigaldatud Tomcat pordil 8080); Podmani moodulis mc01 ja db01 (AlmaLinux 9) kasutajana `kasutaja`
    - **Esitamine:** haru `k03-docker` → PR → merge → tag `k03`
    - **Eelmisest korrast vaja:** tag `k02` `main`-is; repo juures rakendus (`pom.xml`, `src/`, `db/schema.sql`, `db/seed.sql`) ja `autograde/`; koolitajalt Gitea ajutine parool ja kooli CA, kui registry seda nõuab
    - **Testitud:** Docker Engine 29 (vähemalt 28), Compose v5, `mariadb:11.4`, `rabbitmq:4.1-management-alpine`, `memcached:1.6-alpine`, `nginx:1.30-alpine`, `tomcat:10.1-jre21-temurin`, `maven:3-eclipse-temurin-21`; Trivy kursuse VM-i versioon; Podman 5 (AlmaLinux 9.6 AppStream, mc01 ja db01). Lisaülesannetes ka rootless Docker (`docker-ce-rootless-extras`, sama versioon mis Engine), `python:3.12-slim` (võrguinseneri rada, siin ehitamata), `eclipse-temurin:21-jre-alpine`, `nginx:1.27-alpine` ja `nginx:1.29-alpine`, `registry:2`, `louislam/uptime-kuma:2`, abikonteinerid `alpine:3.22`, `ubuntu:24.04`, `httpd:2.4` ja `docker:29-cli`
    - **Dokumentatsioon:** [Dockerfile](https://docs.docker.com/reference/dockerfile/) · [Compose](https://docs.docker.com/reference/compose-file/) · [Docker Engine](https://docs.docker.com/engine/) · [Podman](https://docs.podman.io/) · [Trivy](https://trivy.dev/docs/latest/)

Kohtumise lõpuks käib kogu Labori seis ühe `compose.yaml`-iga control node'is: viis teenust healthcheck'idega, image'id sinu Dockerfile'idest, mitmeastmeline app-image mitte-root kasutajaga. Prod-fail `compose.prod.yaml` lisab ressursipiirangud, saladused failidest, sisemise võrgu ja kirjutuskaitstud konteinerid, volume'i varukoopia on tehtud ja taastatud. Image'id on kooli registry's, Trivy raport ja SBOM on tõlgendatud, mc01 ja db01 teenused on läbinud sama image'iga rootless Podmani ja Quadleti katse SELinuxi all ning vigane intsidendistack on parandatud koodis.

Iga moodul lõpeb commit'iga. Kui moodulil on GitHubis issue (milestone `K3`), lisa sõnumisse `closes #N`.

Kui jätad etappe vahele rea **Kui teed seda tööl iga päev** järgi, kirjuta `TOEND.md`-sse kontrollkäsk ja selle väljund.

## Mis on kohustuslik

| Osa | Mis | Millal |
|---|---|---|
| Kohtumise ajal | [Konteinerid käsitsi](lab-1-kasitsi.md), [db ja web image](lab-2-db-web.md), [App image](lab-3-app-image.md), [Kogu stack Compose'iga](lab-4-compose.md) | laboris 11:30–15:00 |
| Võib lõpetada pärast kohtumist | [Tootmiskeskkonda sobiv stack](lab-5-tootmine.md), [Registry, Trivy ja SBOM](lab-6-registry.md), [Sama teenus Podmaniga](lab-7-podman.md), [Kolm riket](lab-8-kolm-riket.md); `TOEND.md`; [Esitamise](lab-9-esitamine.md) kontrollid uuesti pärast viimast commit'i | enne 5. kohtumist: see eeldab töötavat stacki, `main`-is `compose.yaml`-i ja `app/Dockerfile`-i ning paigaldatud Trivy't |
| Hindamise eeltingimus | tag `k03` `main`-i commit'il pärast merge'i ja GitHubis näha (`git ls-remote --tags origin`); automaatse hindaja seitse kontrolli on ka värskes kloonis `OK` ([Esitamine](lab-9-esitamine.md)) | esimene tag kohtumise lõpus; hilisem töö uue commit'iga ja `git tag -f k03` |

## Moodulid

1. [Konteinerid käsitsi](lab-1-kasitsi.md): Engine hostis, elutsükkel ja PID 1, võrgudraiverid, cgroup'i piirangud ja OOM, restart-poliitika, `docker run` võtmed, oma võrk ja andmed volume'is.
2. [db ja web image](lab-2-db-web.md): kaks Dockerfile'i, init-skripti lõks, nginx'i template, käivitus ilma app01-ta ja `.dockerignore`.
3. [App image](lab-3-app-image.md): mitmeastmeline build, lõppimage'i sisu, cache, kihid kettal, PID 1 signaalid, mitte-root kasutaja ja kontroll-image.
4. [Kogu stack Compose'iga](lab-4-compose.md): viis teenust healthcheck'idega, töötava teenuse uurimine, idempotentne `up -d`, tulemus läbib ahela, rikketest.
5. [Tootmiskeskkonda sobiv stack](lab-5-tootmine.md): piirangud ja PID-piiri katse, saladused failidest, sisemine võrk, `read_only`, logid, varundus ja koristus.
6. [Registry, Trivy ja SBOM](lab-6-registry.md): image'id Gitea's, tag ja digest, stack registry'st, CVE-otsused ja CycloneDX.
7. [Sama teenus Podmaniga](lab-7-podman.md): mc01 ja db01 rootless Podmanis, Quadlet ja linger, andmebaasi kolimine hooldusaknas, SELinuxi `:Z`, cgroup'i piirangud, Docker API ja tagasi algseisu.
8. [Kolm riket](lab-8-kolm-riket.md): intsidendistack diagnoositud rikke kaupa, parandatud failis, tõuseb ise pärast daemoni restarti ja kokkuvõte kirjas.
9. [Esitamine](lab-9-esitamine.md): kontrollid, värske klooni test, ülekanne oma töökohale, PR, tag `k03`, automaatse hindaja tulemus.

Veaotsing: [Abi](abi.md).
