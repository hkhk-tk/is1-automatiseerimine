---
tags:
  - SonarQube
  - Nexus
  - CI/CD
---

# 3. Quality gate ja Nexus

Kui tootmises on vigane fail, on esimesed küsimused, kes selle läbi lasi ja milline täpselt see fail oli. Praegu ei oska pipeline kummalegi küsimusele vastata: roheline build tähendab ainult, et testid õnnestusid, ja WAR on ainult workspace'is. Sonar analüüsib iga buildi ja quality gate peatab halva koodi enne, kui WAR Nexusesse jõuab. Maven laeb sõltuvused kooli Nexusest ja pipeline laeb sinna versioonitud WAR-i.

## Loo Sonari token ja credential

Jenkins peab Sonarisse kirjutama ja selleks vajab ta tokenit. Lood tokeni, mis kehtib ainult sinu projektile, ja paned selle Jenkinsi folderisse, kust pipeline seda ID järgi küsib. Jenkinsfile'i jõuab ainult ID `sonar`, mitte väärtus.

Kasutaja token kehtiks kõigile sinu õigustega projektidele. Kui see lekib buildi logist, saab keegi kirjutada üle ka teiste projektide analüüse.

1. Kontrolli, et Sonar on üleval: `curl -s http://sonar.lab.hkhk.ee:9000/api/system/status` peab andma `"status":"UP"`.
2. Ava `http://sonar.lab.hkhk.ee:9000`, logi sisse `<gh>` ja koolitaja antud parooliga. Sinu projekt `labori-seis-<gh>` on olemas ja tühi.
3. **My Account → Security → Generate Token**: tüüp *Project Analysis Token*, projekt `labori-seis-<gh>`.
4. Jenkinsis folder `<gh>` → Credentials → *Secret text*, **ID = `sonar`**.

Kui token aegub kursuse ajal, näed seda buildis veana `Not authorized` ja parandus on uus token sama ID alla.

**Edasi saad minna, kui** Jenkinsi folderis on credential `sonar` ja Sonaris on token aegumiskuupäevaga.

## Analüüsi koodi Sonaris

Nüüd lisad etapi SonarQube. Sonari skanner töötab Maveni pluginana sinu agendil, loeb testide katvuse ja kontrollib koodi Sonari reeglitega ning saadab tulemuse serverisse, kus see töödeldakse.

Ilma JaCoCo raportita on katvus 0 % või puudub ja katvuse tingimus kas nurjab iga buildi või, kui tingimust pole, laseb läbi muudatuse, mida ükski test ei puuduta.

1. Lisa Jenkinsfile'i `environment` plokk ([SonarScanner for Maven](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/sonarscanner-for-maven)):

    ```groovy
        environment {
            SONAR_KEY = "labori-seis-${GH}"
        }
    ```

2. Lisa pärast Test'i etapp SonarQube.

    ```groovy
            stage('SonarQube') {
                steps { withSonarQubeEnv(installationName: 'sonar', credentialsId: 'sonar') {
                    sh 'mvn -B sonar:sonar -Dsonar.projectKey=$SONAR_KEY'
                } }
            }
    ```

3. Push ja oota buildi.

Katvus tuleb Test etapi JaCoCo XML-ist (`target/site/jacoco/jacoco.xml`), seega peab Sonar käivituma pärast Test'i samas workspace'is. `withSonarQubeEnv` annab Mavenile serveri aadressi ja tokeni keskkonnamuutujatena, nii et need ei paista käsureal ega logis.

<!-- EKRAANIPILT: sonar.lab.hkhk.ee:9000/dashboard?id=labori-seis-mari-tamm pärast esimest edukat analüüsi: Quality Gate Passed, Reliability/Security/Maintainability hinded, Coverage > 0 %. Pärast sammu 28.3.
<figure markdown="span">
  ![SonarQube'i projekti ülevaade: quality gate Passed, reliability, security, maintainability ja katvus](assets/k06_sonar_projekt.png)
  <figcaption>Joonis L6.7. Sonari projekti ülevaade: kolm mõõdet, katvus ja quality gate'i olek.</figcaption>
</figure>
-->

> Kui katvus on 0 %, käivitus Sonar enne `verify`-d või workspace tühjendati vahepeal. Kontrolliks lisa ajutiselt `sh 'ls target/site/jacoco'`.

`ANALYSIS SUCCESSFUL` tähendab ainult, et raport jõudis serverisse. Otsust selles veel pole: server töötleb raportit taustal ja hinnang tekib mõne sekundi või minuti pärast. Seepärast on järgmine etapp eraldi.

**Edasi saad minna, kui** logi lõpus on `ANALYSIS SUCCESSFUL, you can find the results at: http://sonar.lab.hkhk.ee:9000/dashboard?id=labori-seis-<gh>` ja Sonaris on katvus üle 0 %.

## Lisa quality gate

Quality gate on Sonari serveris kirjas olevate tingimuste kogum, näiteks "uue koodi reliability hinne peab olema A". Pipeline ootab, kuni server on analüüsi töödelnud, küsib tulemuse ja katkestab buildi, kui tingimus ei täitu.

`withSonarQubeEnv` loeb pärast skanneri lõppu taski ID failist `target/sonar/report-task.txt` ja jätab selle buildi juurde. `waitForQualityGate` küsib selle ID järgi API-lt korra, kas töötlus on juba valmis, ja jääb muidu webhooki ootama.

1. Ava Sonaris **Quality Gates → IS1** ja vaata, millised tingimused (meetrika, võrdlus, lävi) seal on.
2. Kirjuta etapp ise. Nõuded:
    - etapi nimi on täpselt `Quality Gate` ja see tuleb pärast SonarQube'i
    - samm `waitForQualityGate`, mille ERROR katkestab kogu pipeline'i ja järgmised etapid jäävad tegemata
    - ootamine on piiratud 15 minutiga (`timeout`), sest Sonar töötleb klassi raporteid ükshaaval
    - uut credential'it pole vaja: Sonar teatab tulemuse webhookiga (loengu joonis 6.3)
3. Süntaksi annab **Pipeline Syntax → Snippet Generator → `waitForQualityGate`**, linnuke *Abort pipeline*.
4. Push ja oota buildi.

??? example "Lahendus: etapp Quality Gate"

    ```groovy
            stage('Quality Gate') {
                steps {
                    timeout(time: 15, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
    ```

Kontrolli faili automaatse hindaja testiga:

```bash
bash autograde/check.sh k06 quality
```

> Kui etapp ootab ajapiirini, ei jõudnud webhook kohale. See ei ole Jenkinsfile'i viga: anna koolitajale teada, et ta kontrolliks Sonaris *Webhooks → Recent deliveries*.

`Quality gate is OK` tuli Jenkinsi tänu Sonari webhookile, mitte sellele, et Jenkins pidevalt küsiks. Kui etapp läks roheliseks mõne sekundiga, töötavad analüüs, taustatöötlus, webhook ja ootav samm. Kui see võttis minuteid, oli Sonaris järjekord, sest naabrid analüüsisid samal ajal.

**Edasi saad minna, kui** etapp läks roheliseks, logis on `Quality gate is OK` ja kontroll annab `OK`.

## Lase quality gate'il halb kood peatada

Roheline quality gate tõestab ainult, et hea kood pääseb läbi. Tingimus võib olla seatud kogu koodile, vale meetrikale või puududa, ja see tuleb välja alles siis, kui halb kood läbi läheb. Lisad koodi rea, mis kompileerub ja läbib testid, aga on ilmselgelt vale.

1. Ava `src/main/java/ee/hkhk/laboriseis/api/VersionController.java` ja lisa ajutiselt konstruktorisse rea `this.info = ...` ette:

    ```java
    if (gitSha == gitSha) { gitSha = gitSha.trim(); }
    ```

2. **Ennusta:** kood kompileerub ja testid õnnestuvad. Kas build jõuab Nexuse etapini? Push ja oota buildi.
3. Leia buildi logist etapp, kus build peatus, ja Sonari projektist reegel, fail ja rida, mis buildi peatas.
4. Eemalda rida, push ja oota buildi.

??? question "Leia põhjus"

    Build peatus etapis Quality Gate logireaga `Pipeline aborted due to quality gate failure: ERROR`. Sonaris on uus reliability leid: tingimus võrdleb muutujat iseendaga ja on alati tõene. Uue koodi reliability hinne pole enam A, nii et quality gate'i tingimus ei täitunud.

Halva koodiga build peatus etapis Quality Gate ja järgmised etapid jäid tegemata. See tähendab, et vigane versioon ei saanud kunagi numbrit Nexuses. Sonari leid näitab reeglit, faili ja rida.

**Edasi saad minna, kui** halva koodiga build oli FAILURE logireaga `Pipeline aborted due to quality gate failure: ERROR`, Sonaris oli uus reliability leid ja hinne polnud A ning pärast parandust on build jälle roheline.

## Lae sõltuvused Nexusest

Maven laeb igal puhtal buildil alla kümneid sõltuvusi. Kooli Nexus on cache: `maven-public` on group, mille taga on `maven-central` proxy. Esimene õppija laeb sõltuvused internetist, ülejäänud kohtvõrgust.

Proxy-repositoorium on ühtlasi nimekiri kõigist sõltuvustest, mida organisatsioon kasutab: kui tuleb teade haavatava teegi kohta, näitab Nexuse otsing, kas see on kunagi alla laaditud.

1. Kontrolli Nexust: `curl -s -o /dev/null -w '%{http_code}\n' http://nexus.lab.hkhk.ee:8081/service/rest/v1/status` peab andma `200`.
2. Loo `k06-jenkins/settings.xml`, kus on üks `<mirror>`. Nõuded:
    - id `kooli-nexus`, `<mirrorOf>*</mirrorOf>`
    - url `http://nexus.lab.hkhk.ee:8081/repository/maven-public/`
    - paroole pole, lugemine on anonüümne

    ??? example "Fail k06-jenkins/settings.xml"

        ```xml
        <settings>
          <mirrors>
            <mirror>
              <id>kooli-nexus</id>
              <mirrorOf>*</mirrorOf>
              <url>http://nexus.lab.hkhk.ee:8081/repository/maven-public/</url>
            </mirror>
          </mirrors>
        </settings>
        ```

3. Lisa `environment` plokki `MVN = 'mvn -B -s k06-jenkins/settings.xml'` ja asenda kõigis etappides `mvn -B` → `$MVN`.
4. Push ja oota kaks buildi. Võrdle Build etapi aega Pipeline Graph View's.

`<mirrorOf>*</mirrorOf>` tähendab, et Maven ei küsi enam ühtegi teist repositooriumi otse, ka siis, kui mõni pom seda nõuaks. Teine build on lühem kahel põhjusel: sõltuvused tulevad kohtvõrgust ja osa neist on juba agendi `~/.m2` all. Kui logis on endiselt `Downloading from central`, on mõni `mvn` käsk jäänud ilma `-s`-ta.

**Edasi saad minna, kui** logis on `Downloading from kooli-nexus: http://nexus.lab.hkhk.ee:8081/repository/maven-public/...` ja teine build on Build etapis lühem kui esimene.

## Lae WAR Nexusesse

Nüüd teed pipeline'ist väljundi, mida saab hiljem täpselt üles leida. Igale buildile antakse versioon, mis on unikaalne ja ütleb, millisest commit'ist fail tehti. Selle versiooniga läheb WAR Nexuse hosted repositooriumisse.

Release-repositoorium ei luba sama versiooni üle kirjutada. Versioon `<pom.version>-<BUILD_NUMBER>-<commit'i 7 märki>` on unikaalne ka siis, kui job luuakse uuesti ja `BUILD_NUMBER` algab 1-st.

1. Folder `<gh>` → Credentials → *Username with password*, kasutaja `<gh>`, Nexuse parool, **ID = `nexus`**.
2. Lisa `environment` plokki:

    ```groovy
            NEXUS_HOST  = 'nexus.lab.hkhk.ee:8081'
            NEXUS_REPO  = 'labori-seis'
            NEXUS_GROUP = "ee.hkhk.${GH}"
    ```

3. Arvuta versioon etapi Build alguses `script {}` plokis. Seda vajavad hiljem kaks etappi (Nexus ja Docker image), seepärast mitte Nexuse etapis. Nõuded:
    - pom loetakse sammuga `readMavenPom file: 'pom.xml'`
    - `env.ART_VERSION` on kujul `<pom.version>-<BUILD_NUMBER>-<GIT_COMMIT 7 esimest märki>`
    - `currentBuild.displayName` näitab versiooni, nii et buildi ajaloos on see kohe näha

    ??? example "Lahendus: etapp Build versiooniga"

        ```groovy
                stage('Build') {
                    steps {
                        script {
                            def pom = readMavenPom file: 'pom.xml'
                            env.ART_VERSION = "${pom.version}-${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0, 7)}"
                            currentBuild.displayName = env.ART_VERSION
                        }
                        sh '$MVN -DskipTests package'
                    }
                }
        ```

4. Lisa pärast Quality Gate'i etapp `Nexus`, mis kutsub `nexusArtifactUploader`-it (Snippet Generatoris olemas): `nexusVersion: 'nexus3'`, `protocol: 'http'`, `nexusUrl`, `repository`, `groupId`, `version`, `credentialsId: 'nexus'` ja üks artefakt `labori-seis`, fail `target/labori-seis.war`, tüüp `war`.
5. Push ja oota buildi.

??? example "Lahendus: etapp Nexus"

    ```groovy
            stage('Nexus') {
                steps {
                    nexusArtifactUploader(
                        nexusVersion: 'nexus3', protocol: 'http',
                        nexusUrl: env.NEXUS_HOST, repository: env.NEXUS_REPO,
                        groupId: env.NEXUS_GROUP, version: env.ART_VERSION,
                        credentialsId: 'nexus',
                        artifacts: [[artifactId: 'labori-seis', classifier: '', file: 'target/labori-seis.war', type: 'war']]
                    )
                }
            }
    ```

Kontrolli faili testidega ja salvesta töö GitHubi:

```bash
bash autograde/check.sh k06 nexus
bash autograde/check.sh k06 secrets
git add k06-jenkins/ && git commit -m "k06: sonar + quality gate + nexus" && git push
```

> Vastus 400 tähendab, et sama versioon on juba olemas, 403, et groupId ei ole `ee.hkhk.<gh>` või credential on vale, ja 401, et parool on vale.

Logirida `Uploaded:` näitab täielikku teed ja tee ise kirjeldab artefakti: repositoorium, groupId kaustadena, artifactId ja versioon. Kui buildi nimi ajaloos ja versioon teel on samad, saad igast buildist ühe klikiga õige faili juurde. `secrets` `OK` tähendab, et parool on Jenkinsis ja failis on ainult ID. Release-repositoorium ei luba sama versiooni üle kirjutada: kui versioonist kaob buildi number või commit'i räsi, annab järgmine build vastuse `400`.

**Edasi saad minna, kui** logis on `Uploaded: http://nexus.lab.hkhk.ee:8081/repository/labori-seis/ee/hkhk/<gh>/labori-seis/1.1.0-<n>-<sha>/...war`, buildi nimi näitab sama versiooni ja mõlemad kontrollid annavad `OK`.
