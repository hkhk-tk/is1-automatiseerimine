---
tags:
  - CI/CD
  - Maven
  - GitHub Actions
---

# 5. kohtumine · Praktikum: Maven ja GitHub Actions

3\. kohtumisel panid rakenduse konteineritesse. Seni käivitasid iga sammu ise. Täna ehitad rakenduse kõigepealt üks kord käsitsi Maveniga ja paned siis sama töö käima automaatselt: iga push ehitab ja testib rakenduse, Trivy kontrollib sõltuvusi ning main'i commit jõuab image'ina ghcr.io-sse ja sealt self-hosted runner'i kaudu sinu stack'i.

!!! info "Selle korra töö"

    - **Masin:** control node (VPN), repositooriumi juurkaust, workflow'd kaustas `.github/workflows/`
    - **Ülesanded:** kohtumise issue sinu repositooriumis, märkeruut iga osa kohta
    - **Edenemine:** [laboritahvel](http://is126.kaaren.lab.hkhk.lan) (VPN-iga) ja Actionsi vahekaart
    - **Esitamine:** haru `k05-actions` → PR → merge → tag `k05`

??? tip "Algseis: mida saad valmis kujul ja mida teed ise"

    **Saad valmis kujul:** starteris on rakenduse kood (`pom.xml`, `src/`) ja automaatkontroll (`autograde/`). Deploy vajab 3. kohtumise stack'i: kausta `k03-docker` koos `compose.yaml`-i ja kolme Dockerfile'iga ning faili `k03-docker/.env`. 4. kohtumise tööd see praktikum ei vaja. Alustad harust `main`.

    Kui 3. kohtumine jäi pooleli või stack ei käivitu, ütle koolitajale. Koolitaja saadab sinu repositooriumi valmis `k03-docker` failid. Docker peab control node'il olemas olema: kui see puudub, paigalda see 3. kohtumise praktikumi sammu [1.2 Docker käsitsi](../k03/lab.md#12-docker-kasitsi) järgi. Seejärel käivita stack:

    ```bash
    git switch main && git pull
    cd k03-docker
    cp .env.example .env && nano .env    # paroolid ja OWNER = sinu GitHubi kasutajanimi
    docker compose up -d --build --wait
    curl -fsS http://localhost:8080/health; echo
    ```

    **Teed ise:** ehitad rakenduse Maveniga, kirjutad workflow `.github/workflows/ci.yml`, paigaldad control node'ile self-hosted runner'i, paned paroolid environment'i secret'itesse ja esitad töö tag'iga `k05`.

    **Kui midagi läks katki:** `git restore <fail>` toob faili tagasi viimase commit'i kujul. Punase käivituse järel paranda fail ja tee uus push, GitHub käivitab workflow uuesti. Kui stack ei vasta, käivita kaustas `k03-docker` käsk `docker compose up -d`.

??? abstract "Õpiväljundid"

    1. Ehitad ja testid Java rakenduse Maveniga käsitsi ja tead, mida `mvn -B verify` kettale jätab.
    2. Kirjutad GitHub Actionsi workflow, mis ehitab ja testib rakenduse igal push'il ja PR-il ning salvestab WAR-i artefaktina.
    3. Lisad turvaskänni eraldi job'ina ja annad igale job'ile ainult vajalikud tokeni õigused.
    4. Lükkad image'i ghcr.io-sse ja paigaldad selle self-hosted runner'iga nii, et deploy kontrollib `/version` vastust.
    5. Hoiad paroolid environment'i secret'ites ja esitad töö tag'iga.

Kui juhendis on **Ennusta:**, mõtle vastus enne käsu käivitamist läbi. Seejärel võrdle tulemust oma vastusega ja kui need erinevad, uuri, miks.

Iga osa algab reaga **Kui teed seda tööl iga päev:**. Kui seal nimetatud kontroll on sul juba korras, mine otse järgmise osa juurde.

| Osa | Mida teed |
|---|---|
| [1. Maven](lab-1-maven.md) | ehitad ja testid rakenduse control node'is käsitsi |
| [2. Esimene workflow](lab-2-workflow.md) | `ci.yml` push'il ja PR-il, üks teadlik viga, actionlint, WAR artefaktina |
| [3. Trivy ja õigused](lab-3-trivy-matrix.md) | turvaskänn eraldi job'ina, iga job'i tokeni õigused |
| [4. Image ja deploy](lab-4-deploy.md) | image ghcr.io-sse, self-hosted runner control node'is, deploy ja `/version` = commit |
| [5. Käsitsi käivitus ja saladused](lab-5-saladused.md) | käsitsi käivitus sisendiga, paroolid environment'i secret'itesse |
| [6. Esitamine](lab-8-esitamine.md) | PR `main`-i, tag `k05`, stack maha |

*Tabel 1. Praktikumi osad.*

Osad 1–5 lõpevad commit'iga. Töö esitatakse tag'iga `k05` `main`-i commit'il pärast merge'i. Automaatne hindaja kontrollib kuut asja (failid, actionlint, build, workflow'i struktuur, deploy ja saladused) ja tulemus ilmub GitHubi **Releases** alla. Kontroll `deploy` eeldab 5. osa environment'i ja saladusi. Kui teed pärast esitamist parandusi, tee uus commit ja saada tag uuesti (`git tag -f k05`).

Health check composite action'ina, automaatne rollback, rikete otsimine pipeline'is, Dependabot ja lisaülesanded on kursuse IS2 [süvenemises](https://hkhk-tk.github.io/is2-automatiseerimine/k05/syvenemine/) ja [lisaülesannetes](https://hkhk-tk.github.io/is2-automatiseerimine/k05/lisa/).

??? info "Testitud versioonid ja dokumentatsioon"

    Spring Boot 3.5.16, Java 21 (Temurin), Maven 3.9 (apt), JaCoCo 0.8.15, `actions/checkout@v5`, `actions/setup-java@v5`, `actions/upload-artifact@v7`, `docker/setup-buildx-action@v4`, `docker/login-action@v4`, `docker/build-push-action@v7`, `aquasecurity/trivy-action` v0.36.0 (workflow's SHA-ga kinnitatud), actionlint 1.7.3, runner ≥ 2.327.1.

    Dokumentatsioon: [GitHub Actions](https://docs.github.com/en/actions) · [Maven](https://maven.apache.org/guides/) · [Trivy](https://trivy.dev/docs/latest/) · [actionlint](https://github.com/rhysd/actionlint)

Veaotsing: [Abi](abi.md).
