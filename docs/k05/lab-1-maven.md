---
tags:
  - Maven
  - Java
---

# 1. Maven

Punase CI käivituse järel on esimene küsimus, kas viga on koodis, sõltuvuses, JDK-s või runner'is, ja GitHubis maksab iga katse minuteid. Mis control node'il ebaõnnestub, ebaõnnestub ka seal. Seepärast ehitad, testid ja pakid rakenduse kõigepealt control node'il, ilma ühegi workflow'ta, ja tekitad teadlikult vead, mis tulevad hiljem CI logis sama teksti ja sama exit code'iga tagasi. Lõpus on `mvn -B verify` roheline ja sa tunned need vead logist ära, ilma et peaksid arvama.

**Kui teed seda tööl iga päev:** etapp [Haru ja stack valmis](#haru-ja-stack-valmis) on tehtud ja `mvn -B verify; echo $?` annab `0`. Kui see on sul juba korras, mine otse etappi „[Värske kloon ja build ilma võrguta](#varske-kloon-ja-build-ilma-vorguta)“.

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

✅ **Edasi saad minna, kui** `docker compose ps` näitab nelja teenust (app01 ja db01 `healthy`), `curl` vastab `"status":"UP"`, `~/k03.env` on olemas ja repo on `PRIVATE`.

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

3. Kirjuta märkmikku Java ja Maveni versioon ning `mvn -v` rida `Java home:`.

`java -version` ja `mvn -v` võivad näidata eri Java't. Esimene näitab, mis on PATH-is esimesena, teine seda, mida Maven kasutab. Maven eelistab `JAVA_HOME`-i ja ainult selle puudumisel otsib PATH-ist. Rida `Java home:` on seega see, mida usaldad, kui build käitub ootamatult.

✅ **Edasi saad minna, kui** `java -version` näitab 21, Maven on 3.8 või uuem ja tead, millist JDK-d Maven kasutab.

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
3. Loe testide arv ja kogukatvus ning kirjuta need märkmikku.

    ```bash
    grep -ho 'tests="[0-9]*"' target/surefire-reports/TEST-*.xml
    grep -o 'Total[^%]*%' target/site/jacoco/index.html
    ```

`validate` ei kirjuta kettale midagi, ta ainult kontrollib, et pom on loetav. `test` kompileerib ja käivitab testid, `verify` pakib lisaks WAR-i ja käivitab kvaliteedikontrollid. Kirjaviga annab koodi 1 ja CI näeb seda samamoodi: GitHub loeb sammu punaseks iga nullist erineva koodi peale. Testide arvu ja katvust vajad hiljem võrdluseks, kui CI-s käivitub ootamatult vähem teste.

✅ **Edasi saad minna, kui** `validate` järel `target/` puudub, `test` järel on `classes`, `test-classes` ja `surefire-reports`, `verify` järel lisaks `labori-seis.war`, `site/jacoco/` ja `checkstyle-result.xml` ning kirjaviga annab `Unknown lifecycle phase "validat"` ja koodi 1.

## Loe pom.xml

`pom.xml` on projekti kirjeldus: mis see on, millest sõltub ja kuidas ehitatakse. Siin otsid sealt üles need kohad, mida turvaskänn ja versioonivead hiljem puudutavad.

1. Ava `pom.xml` ([POM-i ülesehitus](https://maven.apache.org/guides/introduction/introduction-to-the-pom.html)) ja leia `groupId`, `artifactId`, `version`, `packaging` ja `<parent>`.
2. Leia `<properties>`-plokist `jacoco.version` ja koht, kus seda kasutatakse (`${jacoco.version}`).
3. Vaata sõltuvusi ja projekti versiooni.

    ```bash
    grep -c '<dependency>' pom.xml
    mvn -B -q dependency:tree -Dincludes=org.springframework:spring-core
    mvn -B -q help:evaluate -Dexpression=project.version -DforceStdout; echo
    ```

4. Kirjuta märkmikku `spring-core` versioon ja üks sõltuvus, millel on versioon otse pom'is.

Enamik sõltuvusi on ilma versioonita, sest `spring-boot-starter-parent` määrab need ühe komplektina. See on hea: teegid on omavahel testitud. Aga see tähendab ka, et pom'i lugedes sa versiooni ei näe ja pead küsima Mavenilt (`dependency:tree`, `help:evaluate`). Kui `help:evaluate` annaks muu versiooni kui pom'i `<version>` rida, oleks see kusagilt üle kirjutatud.

✅ **Edasi saad minna, kui** näed, et enamikul `<dependency>` plokkidel pole `<version>`-it, puu näitab `spring-core` versiooni `spring-boot-starter-parent` 3.5.16 kaudu ja `help:evaluate` trükib `1.1.0`.

## WAR ja selle sisu

Build'i tulemus on üks fail. Vaatad selle sisse, et teaksid, mida pipeline hakkab edasi andma. See fail on artefakt ja sinu esimene workflow salvestab sama faili GitHubis.

Kui WAR-i sisu on teada, saad CI vea korral öelda, kas viga on koodis, sõltuvuses või pakkimises.

1. Vaata WAR-i sisu ja suurust.

    ```bash
    unzip -l target/labori-seis.war | head -20
    unzip -l target/labori-seis.war | grep -c 'WEB-INF/lib/'
    ls -lh target/labori-seis.war
    ```

2. Leia pom'ist rida, mis annab failile nime.

> `WEB-INF/lib-provided` on Tomcati teegid, mida app01 Tomcat ise pakub. Need teevad WAR-i ka iseseisvalt käivitatavaks.

WAR on ZIP-fail kindla kaustastruktuuriga. Kümned teegid `WEB-INF/lib` all selgitavad, miks fail on mitukümmend megabaiti, kuigi meie oma kood on väike. Fikseeritud nimi on oluline, sest workflow ja Dockerfile otsivad faili nime järgi. Kui nimi sisaldaks versiooni, peaks iga versiooni tõstmise järel muutma ka pipeline'i.

✅ **Edasi saad minna, kui** tead, et nimi tuleb reast `<finalName>`, `WEB-INF/classes` on meie kood ja `WEB-INF/lib` sõltuvused, ning WAR-i suurus on märkmikus.

## Ennusta ja proovi: plugin ja checkstyle

Nüüd tekitad kaks viga, mis tulevad CI-s ette: plugina versioon, mis ei sobi JDK-ga, ja stiiliviga, mis ei ole testiviga. Kirjuta enne iga käivitust üles, mis sinu arvates juhtub.

Plugina viga tuleb tavaliselt siis, kui keegi uuendab runner'i JDK-d ja pom'i ei kohandata. Ennustus enne käivitust on harjutus: kui see läheb mööda, on sinu pilt sellest, mida Maven teeb, vale.

1. Anna `jacoco.version` käsurealt, faili muutmata.

    ```bash
    mvn -B verify -Djacoco.version=0.8.8
    ```

2. Lisa `src/test/java/ee/hkhk/laboriseis/TokenServiceTest.java` algusesse kasutamata import `import java.util.List;` ja käivita `mvn -B verify`.
3. Taasta ja kontrolli.

    ```bash
    git restore src/
    git status --short
    ```

4. Kirjuta märkmikku vea rida, mis nimetab major version'it.

Major version 65 on Java 21 klassifaili number. JaCoCo 0.8.8 loeb klassifaile, et katvust mõõta, ega tunne seda numbrit. Seega ebaõnnestub ta aruande koostamisel, mitte testide ajal. Checkstyle'i puhul läksid testid läbi ja build ebaõnnestus ikka. Punane CI ei tähenda alati katkist koodi: loe logist, mis plugin ebaõnnestus, enne kui hakkad koodi parandama.

✅ **Edasi saad minna, kui** JaCoCo 0.8.8 nurjas `jacoco:report`-i põhjusega `Unsupported class file major version 65`, checkstyle nurjas build'i teatega `Unused import - java.util.List` (testid läksid läbi) ja `git status` on puhas.

## Mälu otsas ja AI kui abiline

Simuleerid väikese mäluga masinat ja küsid AI-lt abi nii, nagu teeksid seda tööl. Tööl tekib see viga 1 GB mäluga VM-il või konteineris. AI vastus on täpselt nii hea kui kontekst, mille talle annad.

Mäluviga tuleb tihti siis, kui runner või build-konteiner on liiga väike või kui mitu build'i töötab korraga. JVM arvestab vaikimisi heap'i laeks veerandi mälust, mida ta näeb, konteineris cgroup'i limiidist.

1. Simuleeri väikese mäluga masinat.

    ```bash
    MAVEN_OPTS=-Xmx24m mvn -B package -DskipTests
    ```

2. Kopeeri AI-le vea rida koos `mvn -v` väljundi ja käsuga, mille käivitasid, ning küsi põhjust. `.env`-i, tokeneid ega `~/k03.env` sisu AI-le ei anta.
3. Kontrolli vastust ise.

    ```bash
    MAVEN_OPTS=-Xmx512m mvn -B -q package -DskipTests; echo $?
    ```

4. Kirjuta märkmikku vea rida ja üks lause selle kohta, kas AI soovitus oli õige.

`Java heap space` tähendab, et JVM-ile antud mälu sai otsa, mitte masina mälu. `free -m` võib näidata palju vaba mälu ja viga tuleb ikka, sest `-Xmx` paneb lae. Kui AI soovitas "lisa masinale mälu", vastas ta valele küsimusele. Õige parandus on JVM-i lagi ja seda saad kontrollida ühe käsuga.

✅ **Edasi saad minna, kui** 24 MB-ga ebaõnnestus build `java.lang.OutOfMemoryError: Java heap space` ja 512 MB-ga andis `0`.

## Teine JDK kõrvale

Paigaldad teise JDK ja vaatad, kumba Maven valib. Kui `JAVA_HOME` on seatud, võtab Maven JDK sealt. Mitme JDK-ga masinas tekib segadus kõige sagedamini just siin. Sama küsimust küsib hiljem pipeline'i matrix igal push'il.

Tootmises juhtub see siis, kui keegi paigaldab serverisse teise rakenduse jaoks vanema Java ja ühine `JAVA_HOME` hakkab osutama sellele. Järgmine build ebaõnnestub, kuigi keegi koodi ei muutnud.

1. Paigalda JDK 17 ja vaata, millised Java'd on masinas.

    ```bash
    sudo apt-get install -y openjdk-17-jdk-headless
    update-alternatives --list java
    ```

2. Ennusta ja käivita.

    ```bash
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 mvn -B -q compile
    java -version
    ```

3. Kirjuta vea rida märkmikku. `sudo update-alternatives --config java` muudaks vaikimisi JDK-d kogu masinas, seda täna ei tee.

JDK 17 kompilaator ei oska toota Java 21 klassifaile, seepärast ebaõnnestub juba `compile`. `java -version` näitab samal ajal 21, sest muutuja kehtis ainult sellele ühele käsule. Sama mehhanismi kasutab setup-java CI-s: ta seab `JAVA_HOME`-i, mitte süsteemi vaikimisi Java't. Kui build oleks JDK 17-ga läbi läinud, oleks pom'i Java versiooni seade vale.

✅ **Edasi saad minna, kui** kompileerimine ebaõnnestus `release version 21 not supported`, `java -version` näitab endiselt 21 ning `mvn -B verify; echo $?` annab `0`.

## Värske kloon ja build ilma võrguta

Lõpuks kontrollid kahte asja, mida CI runner sinu eest kunagi ei tee: kas build sõltub ainult Gitis olevatest failidest ja kas kõik vajalik on juba kohalikus hoidlas. Runner saab ainult commit'itud faile. Kui build vajab midagi, mis on ainult sinu töökaustas, ebaõnnestub see GitHubis ja sinu masinas mitte.

Selline viga on tüütu, sest näeb välja nagu CI probleem. Tegelikult on fail lihtsalt `.gitignore`-is või commit'imata.

1. Klooni repo ajutisse kausta ja ehita seal.

    ```bash
    git clone -q . /tmp/k05-puhas
    (cd /tmp/k05-puhas && mvn -B -q verify; echo "kloon $?")
    rm -rf /tmp/k05-puhas
    ```

2. Ehita oma kaustas ilma võrguta (`-o`, offline): Maven ei tohi midagi alla laadida.

    ```bash
    mvn -B -o -q verify; echo "offline $?"
    ```

3. Kirjuta märkmikku mõlemad koodid ja üks lause selle kohta, mida offline-build tõestab.

Kui kloon on roheline, on build korratav: kõik vajalik on Gitis. Kui kloon ebaõnnestuks ja sinu kaust mitte, oleks vahe täpselt see fail, mis on sinu kaustas, aga mitte Gitis (`git status --ignored` näitaks seda). Roheline offline-build tõestab, et kõik pluginad ja teegid on `~/.m2` all. Just selle kausta salvestab workflow'i `cache: maven` runner'i jaoks.

✅ **Edasi saad minna, kui** mõlemad käsud andsid `0` ja `/tmp/k05-puhas` on kustutatud.

📎 **Selle mooduli tõend:** märkmikus versioonid, testide arv ja katvus, `spring-core` versioon, WAR-i suurus, major version'i viga, mäluviga koos AI hinnanguga, JDK 17 viga ning värske klooni ja offline-build'i koodid; `target/labori-seis.war` on olemas ja `git status` puhas.

## Miks see nii töötab

**Parent ja versioonid.** Sõltuvuste versioonid määrab enamasti parent-pom (`spring-boot-starter-parent`). Kui Trivy leiab teegist CVE, näitab `dependency:tree`, kas versioon tuleb meie pom'ist või parent'ist. Selle järgi selgub, kas parandus on üks rida `<properties>`-plokis või parent'i uuendus. Versioonikonflikti lahendab Maven reegliga „lähim võidab“: kui sama teek on puus kahel sügavusel, võetakse madalam, mitte uuem. Uue otsese sõltuvuse lisamine võib seega transitiivse versiooni vaikselt alla viia. `maven-enforcer-plugin`-i reegel `dependencyConvergence` teeb sellise lahknevuse build'i veaks. [Spring Boot 3.5.16](https://spring.io/blog/2026/06/25/spring-boot-3-5-16-available-now/) on 3.x viimane OSS-väljalase ja Boot 4 vajab Tomcat 11-t, seega Trivy leide tuleb juurde ka siis, kui koodi keegi ei muuda.

**Maveni faasid.** Checkstyle ja JaCoCo on seotud `verify` faasiga, mitte `package` faasiga. Seetõttu ei peata Dockerfile'is käsk `mvn package -DskipTests` build'i stiilivea tõttu ja koodi kvaliteedi üle otsustab CI.

**Testid ilma teenusteta.** `mvn -B verify` käivitab 25 testi, mis ei vaja andmebaasi, RabbitMQ-d ega Memcachedit, sest need teenused asendatakse testides Mockitoga. Seetõttu töötab sama käsk ka GitHubi runner'il, kus neid teenuseid ei ole.

**`install` ja `deploy`.** `install` paigutab artefakti kohalikku hoidlasse, `deploy` kaughoidlasse (Nexus, 6. kohtumine).

**Kohalik hoidla.** Kohalik hoidla `~/.m2/repository` on Maveni vahemälu. Release-versioon laaditakse sinna üks kord, sest Maven Centralis on see muutumatu. `-SNAPSHOT` sõltuvust kontrollib Maven vaikimisi kord päevas uuesti (`updatePolicy daily`), seega võib sama pom anda eri päevadel eri build'i.

**Värske kloon ja võrguühenduseta build.** Kui mõlemad õnnestuvad, sõltub build runner'il ainult kahest asjast: Gitist ja võrguühendusest Maven Centralisse.

**Batch-režiim.** Lipp `-B` (batch) lülitab välja Maveni interaktiivse väljundi ja allalaadimise edenemisribad. Logifailis muudaksid edenemisribad väljundi raskesti loetavaks.

**Mitu Maveni versiooni.** Maven on Java programm kaustas ja kaks versiooni ei sega teineteist. Mõlemad kasutavad sama hoidlat `~/.m2`, seega teisel korral midagi uuesti alla ei laadita. Kui build õnnestuks ühe versiooniga ja ebaõnnestuks teisega, oleks pom'is plugin, mis sõltub Maveni versioonist. Just sellisel juhul on vaja Maven Wrapper'it, mis paneb versiooni repo sisse.

**Vahemälu CI-s.** GitHubi hallatud runner on iga job'i alguses tühi masin ja ilma `cache: maven`-ita laaditakse igal käivitusel kogu hoidla uuesti Maven Centralist. Tühja ja täis hoidlaga build'i ajavahe korda push'ide arv päevas näitab, miks vahemälu on aeglase pipeline'i puhul esimene asi, mida kontrollida. Sama kehtib Maven Centrali koormuse kohta: tuhanded tühja hoidlaga build'id päevas on üks põhjus, miks suuremad organisatsioonid kasutavad vahendajana oma hoidlat (Nexus, 6. kohtumine).

Kui jõudsid kiiremini: [Lisaülesanded → 3. Maven Wrapper](lisa.md#3-maven-wrapper), paned Maveni versiooni repo sisse, et iga masin ja runner ehitaks sama versiooniga.
