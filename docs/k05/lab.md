---
tags:
  - CI/CD
  - Maven
  - GitHub Actions
---

# 5. kohtumine, labor: Maven ja GitHub Actions

!!! info "Selle korra töö"
    - **Masin:** control node (VPN), sinu repo juurkaust, workflow'd kaustas `.github/workflows/`, tõendid märkmikus
    - **Sihtmasinad:** 3. kohtumise stack samas masinas (`k03-docker`), GitHubi runner'id ja sinu self-hosted runner
    - **Esitamine:** haru `k05-actions` → PR → merge → tag `k05`
    - **Eelmisest korrast vaja:** `k03-docker/` (`compose.yaml`, `app/Dockerfile`) on main'is, `k03-docker/.env` on control node'il (mitte Gitis), stack töötab, Trivy on paigaldatud, `gh auth status` on roheline ja sul on repos admin-õigus
    - **Testitud:** Spring Boot 3.5.16, Java 21 (Temurin) ja compat-matrix'is 25, Maven 3.9 (apt; lisaülesandes 3.9.11), JaCoCo 0.8.15, `actions/checkout@v5`, `actions/setup-java@v5`, `actions/upload-artifact@v7`, `actions/download-artifact@v8`, `docker/setup-buildx-action@v4`, `docker/login-action@v4`, `docker/build-push-action@v7`, `aquasecurity/trivy-action` v0.36.0, Trivy CLI kursuse VM-i versioon, actionlint 1.7.3, runner ≥ 2.327.1; action'id on workflow'des SHA-ga kinnitatud, siin on nende tag
    - **Dokumentatsioon:** [GitHub Actions](https://docs.github.com/en/actions) · [Maven](https://maven.apache.org/guides/) · [Trivy](https://trivy.dev/docs/latest/) · [actionlint](https://github.com/rhysd/actionlint)

Kohtumise lõpuks ehitab ja testib iga push sinu rakenduse, Trivy skännib sõltuvused ja matrix proovib järgmist JDK-d. Main'i commit jõuab image'ina ghcr.io-sse ja sealt self-hosted runner'i kaudu sinu stack'i, korraga üks deploy, ning ebaõnnestunud deploy teeb ise rollback'i. Igal job'il on ainult tema õigused, action'id on SHA-ga kinnitatud ja Dependabot hoiab need värsked.

Kõik moodulid peale Maveni ja esitamise lõpevad commit'iga. Kui moodulil on GitHubis issue (milestone `K5`), lisa sõnumisse `closes #N`.

## Mis on kohustuslik

| Osa | Mis | Millal |
|---|---|---|
| Kohtumise ajal | [Maven](lab-1-maven.md), [Esimene workflow](lab-2-workflow.md), [Trivy, matrix ja õigused](lab-3-trivy-matrix.md), [Image ja deploy](lab-4-deploy.md) | laboris 11:30–15:00 |
| Võib lõpetada pärast kohtumist | [Triggerid, saladused ja environment](lab-5-saladused.md), [Health check ja rollback](lab-6-tagasipoore.md), [Katkine pipeline](lab-7-katkine-pipeline.md); Dependaboti PR-i otsus märkmikus; [Esitamise](lab-8-esitamine.md) kontrollid uuesti pärast viimast commit'i | enne 6. kohtumise; automaatse hindaja `deploy` kontroll vajab environment'i ja saladusi lehelt Triggerid, saladused ja environment |
| Hindamise eeltingimus | tag `k05` `main`-i commit'il pärast merge'i ja GitHubis näha (`git ls-remote --tags origin`); automaatse hindaja kuus kontrolli on `OK` ja `main`-i viimane deploy on roheline ([Esitamine](lab-8-esitamine.md)) | esimene tag kohtumise lõpus; hilisem töö uue commit'iga ja `git tag -f k05` |

## Moodulid

1. [Maven](lab-1-maven.md): faasid, pom, WAR, JDK-, plugina- ja mäluvead, värske kloon ja offline-build; `mvn -B verify` on roheline.
2. [Esimene workflow](lab-2-workflow.md): `ci.yml` push'il ja PR-il, teadlikud vead, actionlint, WAR artefaktina, sammude kestus API-st ja selle järgi arvutatud ajapiir.
3. [Trivy, matrix ja õigused](lab-3-trivy-matrix.md): build ‖ security, ühe CVE jälg pom'ini, compat-matrix, job'i õigused, SHA-d, Dependabot ka baas-image'itele ja Compose'ile, db01 digest'iga.
4. [Image ja deploy](lab-4-deploy.md): image ghcr.io-sse kihtide vahemäluga, runner control node'il, `/version` = commit, mis jääb runner'isse maha.
5. [Triggerid, saladused ja environment](lab-5-saladused.md): nupp, ajakava, environment `proxmox` ja selle haru piirangu katse, üks deploy korraga.
6. [Health check ja rollback](lab-6-tagasipoore.md): composite action, katkine deploy teeb ise rollback'i, katkestuse ajajoon Dockeri sündmustest, rollback ka tühistamisel ja viimase terve image'i järgi.
7. [Katkine pipeline](lab-7-katkine-pipeline.md): neli riket eri kohtades, parandus failis või runner'is, runner'i valve skript.
8. [Esitamine](lab-8-esitamine.md): kontrollid, Dependaboti PR-i ülevaatus, sinu töökoha esimene automatiseerimise samm `NOTES.md`-s, PR, tag `k05`, automaatse hindaja tulemus.

Veaotsing: [Abi](abi.md).
