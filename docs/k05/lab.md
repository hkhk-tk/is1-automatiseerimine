---
tags:
  - CI/CD
  - Maven
  - GitHub Actions
---

# 5. kohtumine · Praktikum: Maven ja GitHub Actions

3. kohtumisel panid rakenduse konteineritesse ja 4. kohtumisel lõid OpenTofu'ga taristu. Seni käivitasid iga sammu ise. Täna paned ehitamise, kontrollimise ja paigaldamise käima automaatselt: iga push ehitab ja testib rakenduse, Trivy kontrollib sõltuvusi ning main'i commit jõuab image'ina ghcr.io-sse ja sealt self-hosted runner'i kaudu sinu stack'i. Ebaõnnestunud deploy teeb ise rollback'i.

!!! info "Selle korra töö"

    - **Masin:** control node (VPN), repositooriumi juurkaust, workflow'd kaustas `.github/workflows/`
    - **Eelmisest korrast vaja:** `k03-docker/` (`compose.yaml`, `app/Dockerfile`) on main'is, `k03-docker/.env` on control node'is (mitte Gitis), stack töötab, Trivy on paigaldatud, `gh auth status` on roheline ja sul on repositooriumis admin-õigus
    - **Ülesanded:** kohtumise issue sinu repositooriumis, märkeruut iga osa kohta
    - **Edenemine:** [laboritahvel](http://192.168.125.187:8093) (VPN-iga) ja Actionsi vahekaart
    - **Esitamine:** haru `k05-actions` → PR → merge → tag `k05`

Kui juhendis on **Ennusta:**, ütle vastus enne käsu käivitamist naabrile või mõtle see läbi. Seejärel võrdle tulemust oma ennustusega ja kui need erinevad, uuri, miks.

Iga osa algab reaga **Kui teed seda tööl iga päev:**. Kui seal nimetatud kontroll on sul juba korras, mine otse osa lõpuosasse.

| Osa | Mida teed | Millal |
|---|---|---|
| [1. Maven](lab-1-maven.md) | ehitad ja testid rakenduse control node'is ning tekitad teadlikult vead, mis tulevad hiljem CI logis tagasi | kohtumise ajal |
| [2. Esimene workflow](lab-2-workflow.md) | `ci.yml` push'il ja PR-il, actionlint, WAR artefaktina, ajapiir mõõtmise järgi | kohtumise ajal |
| [3. Trivy, matrix ja õigused](lab-3-trivy-matrix.md) | turvaskänn eraldi job'ina, järgmise JDK kontroll, job'i õigused, action'id SHA-ga, Dependabot | kohtumise ajal |
| [4. Image ja deploy](lab-4-deploy.md) | image ghcr.io-sse, self-hosted runner control node'is, deploy ja `/version` = commit | kohtumise ajal |
| [5. Triggerid, saladused ja environment](lab-5-saladused.md) | käsitsi käivitus ja ajakava, paroolid environment'i secret'itesse, üks deploy korraga | enne 6. kohtumist |
| [6. Health check ja rollback](lab-6-tagasipoore.md) | kontroll composite action'iks, katkine deploy teeb ise rollback'i | enne 6. kohtumist |
| [7. Katkine pipeline](lab-7-katkine-pipeline.md) | neli riket eri kohtades, järelanalüüs, runner'i valve | enne 6. kohtumist |
| [8. Esitamine](lab-8-esitamine.md) | Dependaboti PR, PR `main`-i, tag `k05` | kohtumise lõpus, parandused enne 6. kohtumist |

*Tabel 1. Praktikumi osad.*

Osad 1–7 lõpevad commit'iga. Töö esitatakse tag'iga `k05` `main`-i commit'il pärast merge'i. Automaatne hindaja kontrollib kuut asja (failid, actionlint, build, workflow'i struktuur, deploy ja saladused) ja tulemus ilmub GitHubi **Releases** alla. Kontroll `deploy` eeldab 5. osa environment'i ja saladusi. Kui teed pärast esitamist parandusi, tee uus commit ja saada tag uuesti (`git tag -f k05`).

??? info "Testitud versioonid ja dokumentatsioon"

    Spring Boot 3.5.16, Java 21 (Temurin) ja compat-matrix'is 25, Maven 3.9 (apt; lisaülesandes 3.9.11), JaCoCo 0.8.15, `actions/checkout@v5`, `actions/setup-java@v5`, `actions/upload-artifact@v7`, `actions/download-artifact@v8`, `docker/setup-buildx-action@v4`, `docker/login-action@v4`, `docker/build-push-action@v7`, `aquasecurity/trivy-action` v0.36.0, Trivy CLI kursuse VM-i versioon, actionlint 1.7.3, runner ≥ 2.327.1. Action'id on workflow'des SHA-ga kinnitatud, siin on nende tag.

    Dokumentatsioon: [GitHub Actions](https://docs.github.com/en/actions) · [Maven](https://maven.apache.org/guides/) · [Trivy](https://trivy.dev/docs/latest/) · [actionlint](https://github.com/rhysd/actionlint)

Veaotsing: [Abi](abi.md).
