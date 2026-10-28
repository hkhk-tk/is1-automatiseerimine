---
tags:
  - Jenkins
  - SonarQube
  - Nexus
  - CI/CD
---

# 6. kohtumine, labor: Jenkins, SonarQube ja Nexus

!!! info "Selle korra töö"
    - **Masin:** control node, repo `~/labori-seis`, töökaust `k06-jenkins/`, tõendid PR-i kirjeldusse
    - **Sihtmasinad:** `jenkins.lab.hkhk.ee:8080`, `sonar.lab.hkhk.ee:9000`, `nexus.lab.hkhk.ee:8081` (VPN); administraatori osas oma sandbox-Jenkins control node'il (`:8090`)
    - **Esitamine:** haru `k06-jenkins` → PR → merge → tag `k06`
    - **Vaja koolitajalt:** neli parooli (Jenkins, agendi saladus, Sonar, Nexus); kasutajanimi = GitHubi nimi väiketähtedega, allpool `<gh>`
    - **Eelmisest korrast:** `main` GitHub Actionsi korra seisuga (`pom.xml`, `src/`, `autograde/`), 3. kohtumisest `k03-docker/compose.yaml` ja `k03-docker/app/Dockerfile`, control node'il töötav VPN ja Docker
    - **Testitud:** Jenkins LTS 2.580.x, Java 21, Maven 3.9.16, SonarQube Community Build 26.9 (andmebaas PostgreSQL 17), SonarScanner for Maven 5.8.0.7211, Nexus CE 3.96.4, Tomcat 10.1 (`tomcat:10.1-jre21-temurin`), sandboxi image `jenkins/jenkins:lts-jdk21`, Docker 29, Ubuntu 24.04
    - **Dokumentatsioon:** [Jenkins Pipeline](https://www.jenkins.io/doc/book/pipeline/syntax/) · [Jenkins Configuration as Code](https://www.jenkins.io/projects/jcasc/) · [SonarQube](https://docs.sonarsource.com/sonarqube-community-build/) · [Nexus Repository](https://help.sonatype.com/en/repository-types.html)

Kohtumise lõpuks ehitab koolitaja Jenkins iga commit'i sinu enda agendil, Sonari quality gate peatab halva koodi ja sama WAR läheb Nexusesse ja Docker image'isse. Avaldamine käib ainult põhiharult, testkeskkonda paigaldus ainult inimese kinnitusega. Oma sandbox-Jenkinsi seadistad koodist, uuendad selle pluginat ja taastad selle varukoopiast.

Kui moodulil on GitHubis issue (milestone `K6`), lisa commit'i sõnumisse `closes #N`.

## Mis on kohustuslik

| Osa | Mis | Millal |
|---|---|---|
| Kohtumise ajal | [Agent ja esimene pipeline](lab-1-agent.md), [Triggerid, options ja post](lab-2-triggerid.md), [Quality gate ja Nexus](lab-3-sonar-nexus.md), [Image, paralleel ja deploy](lab-4-image-deploy.md) | laboris 11:30–15:00 |
| Võib lõpetada pärast kohtumist | [Jenkins koodina](lab-5-jenkins-koodina.md), [Õigused, varundus ja taaste](lab-6-haldus.md), [Neli punast buildi](lab-7-neli-punast.md); tõendid PR-i kirjeldusse; [Esitamise](lab-8-esitamine.md) kontrollid uuesti pärast viimast commit'i | pärast kohtumist VPN-i kaudu, sest koolitaja Jenkins, Sonar ja Nexus on VPN-i taga |
| Hindamise eeltingimus | tag `k06` `main`-i commit'il pärast merge'i ja GitHubis näha (`git ls-remote --tags origin`); automaatse hindaja kaheksa kontrolli on `OK` ja kohalik kaust klapib repoga ([Esitamine](lab-8-esitamine.md)) | esimene tag kohtumise lõpus; hilisem töö uue commit'iga ja `git tag -f k06` |

## Moodulid

1. [Agent ja esimene pipeline](lab-1-agent.md): agent on roheline, taastub ise pärast `kill -9`, Build ja Test töötavad sinu masinas.
2. [Triggerid, options ja post](lab-2-triggerid.md): commit käivitab buildi ise, käivituse põhjus on API-st loetav, buildil on piirid ja workspace tühjeneb.
3. [Quality gate ja Nexus](lab-3-sonar-nexus.md): quality gate peatab halva koodi, versioonitud WAR on Nexuses, `sha1sum` klapib ja üle kirjutada ei saa.
4. [Image, paralleel ja deploy](lab-4-image-deploy.md): Nexus ja image paralleelselt, avaldamine ainult põhiharult, deploy kinnitusega, konteineris sama WAR.
5. [Jenkins koodina](lab-5-jenkins-koodina.md): sandboxi pluginad `plugins.txt`-is, seaded JCasC failist, vigane fail leitud logist.
6. [Õigused, varundus ja taaste](lab-6-haldus.md): naabri folder on kinni, pluginauuendus varukoopiaga, taaste teise konteinerisse ja ilma võtmeta.
7. [Neli punast buildi](lab-7-neli-punast.md): neli riket leitud väljast sisse liikudes, parandused commit'idena, kaks rohelist buildi järjest, intsidendi jäetud image'id ja versioonid leitud.
8. [Esitamine](lab-8-esitamine.md): repo ja kaust klapivad, kontrollid, PR, tag `k06`, automaatse hindaja tulemus.

Veaotsing: [Abi](abi.md).
