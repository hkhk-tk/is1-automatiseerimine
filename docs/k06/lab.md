---
tags:
  - Jenkins
  - SonarQube
  - Nexus
  - CI/CD
---

# 6. kohtumine · Praktikum: Jenkins, SonarQube ja Nexus

!!! info "Selle korra töö"
    - **Masin:** control node, kursuse repositoorium, töökaust `k06-jenkins/`
    - **Sihtmasinad:** `jenkins.lab.hkhk.ee:8080`, `sonar.lab.hkhk.ee:9000`, `nexus.lab.hkhk.ee:8081` (VPN)
    - **Esitamine:** haru `k06-jenkins` → PR → merge → tag `k06`
    - **Edenemine:** [laboritahvel](http://is126.kaaren.lab.hkhk.lan) (VPN-iga)
    - **Vaja koolitajalt:** neli parooli (Jenkins, agendi saladus, Sonar, Nexus); kasutajanimi = GitHubi nimi väiketähtedega, allpool `<gh>`
    - **Testitud:** Jenkins LTS 2.580.x, Java 21, Maven 3.9.16, SonarQube Community Build 26.9 (andmebaas PostgreSQL 17), SonarScanner for Maven 5.8.0.7211, Nexus CE 3.96.4, Tomcat 10.1 (`tomcat:10.1-jre21-temurin`), Docker 29, Ubuntu 24.04
    - **Dokumentatsioon:** [Jenkins Pipeline](https://www.jenkins.io/doc/book/pipeline/syntax/) · [SonarQube](https://docs.sonarsource.com/sonarqube-community-build/) · [Nexus Repository](https://help.sonatype.com/en/repository-types.html)

Kohtumise lõpuks ehitab koolitaja Jenkins iga commit'i sinu enda agendil, Sonari quality gate peatab halva koodi ning sama WAR läheb Nexusesse ja Docker image'isse. Esimese buildi käivitad käsitsi lihtsas Freestyle jobis, seejärel kirjutad kõik sammud Jenkinsfile'i ja lased commit'il buildi ise käivitada.

??? tip "Algseis: mida saad valmis kujul ja mida teed ise"

    **Saad valmis kujul:** starteri `main` haru rakenduse koodiga (`pom.xml`, `src/`), automaatkontrolli `autograde/` ja kaustas `k06-jenkins/` agendi paigaldusskripti `jenkins-agent.sh`. Klassi Jenkinsis on sinu folder `<gh>`, node `<gh>` ja job `labori-seis`, Sonaris projekt `labori-seis-<gh>` ja Nexuses repositoorium `labori-seis`. Varasemate kohtumiste tööd see praktikum ei vaja: alustad harust `main`.

    **Teed ise:** ühendad control node'i agendiks, kirjutad `Jenkinsfile`'i, `settings.xml`-i ja `Dockerfile`'i, lisad credential'id ning esitad töö tag'iga `k06`.

    **Docker:** etapp Docker image vajab control node'il Dockerit. Kui `docker version` annab vea, paigalda Docker 3. kohtumise praktikumi [osa 1.2](../k03/lab.md#12-paigalda-docker) järgi enne agendi paigaldust.

    **Kui midagi läks katki:** `git restore <fail>` toob faili tagasi viimase commit'i kujul. Agendi teenuse taaskäivitab `sudo systemctl restart jenkins-agent`.

Küsimused: [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions). Lisa küsimusele käsk ja kogu veateade tekstina. Enne saatmist eemalda paroolid ja tokenid.

## Moodulid

1. [Agent ja esimene pipeline](lab-1-agent.md): agent on roheline, Freestyle job näitab, kes ja kus ehitab, Build ja Test töötavad sinu masinas.
2. [Triggerid](lab-2-triggerid.md): commit käivitab buildi ise.
3. [Quality gate ja Nexus](lab-3-sonar-nexus.md): quality gate peatab halva koodi ja versioonitud WAR on Nexuses.
4. [Image samast WAR-ist](lab-4-image-deploy.md): pipeline ehitab Docker image'i samast WAR-ist.
5. [Esitamine](lab-5-esitamine.md): PR, tag `k06` ja automaatse hindaja tulemus.

Veaotsing: [Abi](abi.md). Süvenemine, sandbox-Jenkins, haldus, intsident ja lisaülesanded on kursusel IS2: [Jenkins, SonarQube ja Nexus lähemalt](https://hkhk-tk.github.io/is2-automatiseerimine/k06/syvenemine/).
