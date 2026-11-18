---
tags:
  - Maven
  - Java
---

# 1. Maven

Punase CI käivituse järel on esimene küsimus, kas viga on koodis, sõltuvuses, JDK-s või runner'is, ja GitHubis maksab iga katse minuteid. Mis control node'il ebaõnnestub, ebaõnnestub ka seal. Seepärast ehitad ja testid rakenduse kõigepealt üks kord käsitsi control node'il, ilma ühegi workflow'ta. Lõpus on `mvn -B verify` roheline ja sa tead, mida CI hakkab sama käsuga tegema.

**Kui teed seda tööl iga päev:** etapp [Haru ja stack valmis](#haru-ja-stack-valmis) on tehtud ja `mvn -B verify; echo $?` annab `0`. Kui see on sul juba korras, mine edasi [esimese workflow](lab-2-workflow.md) juurde. Maveni põhjalikum osa (pom, WAR-i sisu, teine JDK, build ilma võrguta) on IS2 süvenemises [Maven lähemalt](https://hkhk-tk.github.io/is2-automatiseerimine/k05/syvenemine/#osa-1-maven-lahemalt).

## Haru ja stack valmis

Alustad sellest, et kontrollid, kas eelmise korra tulemus on alles. Pipeline kasutab hiljem 3. kohtumisel tehtud stack'i: see vajab töötavat `compose.yaml`-i, `.env`-i väärtusi ja GitHubi ligipääsu. Kui siin on midagi katki, avastad selle muidu alles siis, kui esimene deploy ebaõnnestub ja sa ei tea, kas viga on pipeline'is või stack'is.

1. Loo haru ja kontrolli, et stack töötab.

    ```bash
    git switch main && git pull && git switch -c k05-actions
    (cd k03-docker && docker compose ps)
    curl -fsS http://localhost:8080/health; echo
    ```

2. Tee `.env`-ist runner'i jaoks koopia. Deploy kasutab seda seni, kuni paroolid kolivad environment'i secret'itesse, siis kustutad faili.

    ```bash
    cp k03-docker/.env ~/k03.env && chmod 600 ~/k03.env
    ```

3. Kontrolli GitHubi ligipääsu ja repo õigusi: repo *Settings* all peavad olema *Actions → Runners* ja *Environments*.

    ```bash
    gh auth status
    gh repo view --json visibility,viewerPermission
    ```

> Kui `viewerPermission` pole `ADMIN`, ei saa sa runner'it ega environment'i luua: ütle koolitajale.

Roheline `/health` tähendab, et app01 jõuab andmebaasi, järjekorra ja vahemäluni: Spring Boot Actuator koondab `/health`-i vastusesse iga sõltuvuse health indicator'i ja annab `DOWN`, kui mõni neist ei vasta. `PRIVATE` on vajalik self-hosted runner'i jaoks: runner käivitab iga koodi, mis workflow'sse jõuab, ja avalikus repos võib see tulla forgist.

**Edasi saad minna, kui** `docker compose ps` näitab nelja teenust (app01 ja db01 `healthy`), `curl` vastab `"status":"UP"`, `~/k03.env` on olemas ja repo on `PRIVATE`.

## Versioonid ja JDK

Nüüd vaatad, milline JDK ja milline Maven on masinas. `pom.xml` nõuab Java 21.

Versioonide erinevus control node'i ja CI runner'i vahel on tüüpiline põhjus, miks „minu masinas töötab“, ja hiljem võrdled CI viga just nende numbritega.

1. Vaata, mis on masinas, ja paigalda puuduv.

    ```bash
    java -version
    mvn -v
    sudo apt-get install -y openjdk-21-jdk-headless maven
    ```

2. Vaata, millised JDK paketid on saadaval.

    ```bash
    apt search openjdk 2>/dev/null | grep -E '^openjdk-(17|21)-j'
    ```

3. Võrdle `java -version` väljundit `mvn -v` reaga `Java home:`. Kas need näitavad sama JDK-d?

`java -version` ja `mvn -v` võivad näidata eri Java't. Esimene näitab, mis on PATH-is esimesena, teine seda, mida Maven kasutab. Maven eelistab `JAVA_HOME`-i ja ainult selle puudumisel otsib PATH-ist. Rida `Java home:` on seega see, mida usaldad, kui build käitub ootamatult.

**Edasi saad minna, kui** `java -version` näitab 21, Maven on 3.8 või uuem ja tead, millist JDK-d Maven kasutab.

## Faasid ükshaaval

Maven ei käivita üksikuid käske, vaid elutsükli faase. Iga [faas](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html) käivitab ka kõik eelnevad. `verify` on see, mida CI hakkab käivitama. Siin käivitad faasid ükshaaval ja vaatad, mida igaüks kettale jätab.

CI-s näed ainult lõpptulemust. Kui tead, mis kaust millise faasi järel tekib, saad punase käivituse järel kohe öelda, kui kaugele build jõudis.

1. Käivita repo juurkaustas faasid järjest ja vaata iga järel `ls target/` ning `echo $?`.

    ```bash
    mvn -B validate
    mvn -B test
    mvn -B verify
    ```

2. Proovi kirjaviga: `mvn -B validat; echo $?`
3. Vaata testide arvu ja kogukatvust. Neid võrdled hiljem CI logiga.

    ```bash
    grep -ho 'tests="[0-9]*"' target/surefire-reports/TEST-*.xml
    grep -o 'Total[^%]*%' target/site/jacoco/index.html
    ```

`validate` ei kirjuta kettale midagi, ta ainult kontrollib, et pom on loetav. `test` kompileerib ja käivitab testid, `verify` pakib lisaks WAR-i ja käivitab kvaliteedikontrollid. Kirjaviga annab koodi 1 ja CI näeb seda samamoodi: GitHub loeb sammu punaseks iga nullist erineva koodi peale. Testide arvu ja katvust vajad hiljem võrdluseks, kui CI-s käivitub ootamatult vähem teste.

**Edasi saad minna, kui** `validate` järel `target/` puudub, `test` järel on `classes`, `test-classes` ja `surefire-reports`, `verify` järel lisaks `labori-seis.war`, `site/jacoco/` ja `checkstyle-result.xml` ning kirjaviga annab `Unknown lifecycle phase "validat"` ja koodi 1.

## Miks see nii töötab

??? info "Ava selgitused"

    **Maveni faasid.** Checkstyle ja JaCoCo on seotud `verify` faasiga, mitte `package` faasiga. Seetõttu ei peata Dockerfile'is käsk `mvn package -DskipTests` build'i stiilivea tõttu ja koodi kvaliteedi üle otsustab CI.

    **Testid ilma teenusteta.** `mvn -B verify` käivitab 25 testi, mis ei vaja andmebaasi, RabbitMQ-d ega Memcachedit, sest need teenused asendatakse testides Mockitoga. Seetõttu töötab sama käsk ka GitHubi runner'il, kus neid teenuseid ei ole.

    **`install` ja `deploy`.** `install` paigutab artefakti kohalikku hoidlasse, `deploy` kaughoidlasse (Nexus, 6. kohtumine).

    **Batch-režiim.** Lipp `-B` (batch) lülitab välja Maveni interaktiivse väljundi ja allalaadimise edenemisribad. Logifailis muudaksid edenemisribad väljundi raskesti loetavaks.

Kui jõudsid kiiremini: [Lisaülesanded → 3. Maven Wrapper](https://hkhk-tk.github.io/is2-automatiseerimine/k05/lisa/#3-maven-wrapper), paned Maveni versiooni repo sisse, et iga masin ja runner ehitaks sama versiooniga.
