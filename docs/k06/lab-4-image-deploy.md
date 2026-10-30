---
tags:
  - Jenkins
  - Docker
  - CI/CD
---

# 4. Image, paralleel ja deploy

Kui testkeskkonda läheb teine fail kui see, mis läbis kontrollid, või paigaldus käivitub iga commit'i peale, ei saa testkeskkonna tulemusi usaldada. Pipeline kontrollib nüüd koodi, kuid ei paigalda seda kuhugi. Sama WAR, mis läbis quality gate'i ja on Nexuses, läheb Docker image'isse ning Nexuse upload ja image'i build käivituvad korraga. Avaldamine käib ainult põhiharult ja testkeskkonda paigaldab pipeline alles siis, kui inimene selle kinnitab. Iga otsus on Jenkinsfile'is kirjas, nii et seda saab üle vaadata nagu iga teist koodi.

**Kui teed seda tööl iga päev:** build once (sama artefakt Nexuses ja image'is) ja kinnitusega deploy on sul tööl juba nõue. Kui see on sul juba korras, mine otse etappi [„Paigalda testkeskkonda kinnitusega“](#paigalda-testkeskkonda-kinnitusega).

## Kirjuta build once Dockerfile

3. kohtumise mitmeastmeline Dockerfile (`k03-docker/app/Dockerfile`) kompileerib WAR-i uuesti ja see pole enam sama WAR, mis läbis quality gate'i. Teine kompileerimine võib saada teise sõltuvuse versiooni või teise JDK ja siis testisid üht faili, aga paigaldad teist. Loo `k06-jenkins/Dockerfile`, mis ise midagi ei kompileeri. Nõuded:

- alus `tomcat:10.1-jre21-temurin`, `curl` HEALTHCHECK'i jaoks
- `COPY labori-seis.war /usr/local/tomcat/webapps/ROOT.war`
- HEALTHCHECK `/health` peale
- viimastena `ARG GIT_SHA` ja `ENV GIT_SHA`, et eelmised kihid tuleksid cache'ist

```bash
diff <(grep -E '^(FROM|RUN|COPY)' k03-docker/app/Dockerfile) <(grep -E '^(FROM|RUN|COPY)' k06-jenkins/Dockerfile)
grep -c mvn k06-jenkins/Dockerfile
bash autograde/check.sh k06 files
```

`diff` näitab, et 3. kohtumise failist kadus Maveni etapp ja `COPY --from=...` asendus tavalise `COPY`-ga. `ARG GIT_SHA` on viimane, sest `ARG`-i väärtuse muutus tühistab cache'i alates esimesest reast, mis seda kasutab, ja iga `RUN` kasutab seda kaudselt. Faili alguses ehitaks see iga commit'iga ka `apt-get` kihi uuesti.

**Edasi saad minna, kui** Dockerfile'is pole Maveni etappi (`grep -c mvn` annab `0`) ja kontroll annab `OK`.

## Ehita image pipeline'is

Nüüd ehitab image'i pipeline, mitte sina. `docker build` töötab agendil kasutajana `jenkins`, nii et see kasutaja peab saama Docker daemoniga suhelda. Build context on `target/`, mis sisaldab juba kontrollitud WAR-i.

`docker` grupp võrdub sellel masinal root-õigusega ja Jenkinsfile'i muutja saab selle õiguse endale. Seepärast on see lubatud ühe õppija agendil, aga mitte jagatud controlleris. Mitme meeskonnaga agentidel kasutatakse selle asemel rootless-Dockerit, Podmani või ajutisi agente, mis pärast buildi kustutatakse.

1. Kontrolli, et kasutaja `jenkins` on agendil grupis `docker`: `id jenkins | grep -o docker`.
2. Lisa pärast Nexuse etappi etapp Docker image. Build context on `target/`, nii et Docker saadab daemonile ainult WAR-i.

    ```groovy
            stage('Docker image') {
                steps { sh 'docker build -f k06-jenkins/Dockerfile --build-arg GIT_SHA=$GIT_COMMIT -t labori-seis:$ART_VERSION target' }
            }
    ```

3. Täienda plokki `post { cleanup { } }` enne `cleanWs()`-i nii, et agendile jääks alles kuni 3 `labori-seis` image'it. Läheb vaja: `docker image ls labori-seis --format …`, `tail -n +4`, `xargs -r docker rmi`. Koristus ei tohi buildi nurjata.
4. Push ja oota buildi.

```bash
docker image ls labori-seis
docker inspect --format '{{.Config.Env}}' labori-seis:<tag> | tr ' ' '\n' | grep GIT_SHA
bash autograde/check.sh k06 docker
```

> Teade `permission denied ... /var/run/docker.sock` tähendab, et kasutaja `jenkins` ei ole `docker` grupis või agenti pole pärast seda taaskäivitatud (`sudo systemctl restart jenkins-agent`).

Image'i tag ja Nexuse versioon on sama string, nii et ühest leiad alati teise. `GIT_SHA` image'i keskkonnas on kolmas sõltumatu viide samale commit'ile. Iga build lisab ühe WAR-i suuruse kihi, nii et koristus `cleanup` plokis hoiab agendi ketta stabiilsena.

**Edasi saad minna, kui** `docker image ls labori-seis` näitab uusimat tag'i, mis on sama mis Nexuses, `GIT_SHA` on sama commit ja kontroll annab `OK`.

## Avalda Nexusesse ja image'isse korraga

Nexuse upload ja `docker build` ainult loevad valmis WAR-i ega kirjuta `target/`-i, seega võivad need töötada korraga samas workspace'is. Mõõdad aega enne ja pärast.

Ilma etapipõhise `agent`-ita töötavad paralleelsed harud sama executori ja sama workspace'i peal: Jenkins ei anna neile eraldi kausta ega lisa-executorit. Kaks haru, mis kirjutavad `target/`-i, annavad siis tulemuse, mis sõltub ajastusest.

1. Vaata Pipeline Graph View's viimase buildi Nexuse ja Docker image'i etapi aega.
2. Pane mõlemad etapid ühe etapi `Avaldamine` alla `parallel` plokki. Etappide sisu jääb samaks.

    ```groovy
            stage('Avaldamine') {
                parallel {
                    stage('Nexus') { steps { /* senine nexusArtifactUploader */ } }
                    stage('Docker image') { steps { /* senine docker build */ } }
                }
            }
    ```

3. **Ennusta:** kui kaua kestab `Avaldamine` võrreldes kahe etapi ajaga eraldi? Push ja oota buildi. Vaata Graph View's, kas harud töötasid kõrvuti, ja võrdle aega.

> Test ja Checkstyle kirjutavad mõlemad `target/`-i. Neid paralleelseks panna ei ole ohutu (vt [Lisaülesanded → 7. Paralleelsed testid ja jagatud workspace](lisa.md#7-paralleelsed-testid-ja-jagatud-workspace)).

`Avaldamine` kestab nüüd umbes nii kaua kui pikem kahest harust, mitte nende summa. Kui aeg peaaegu ei muutunud, oli üks haru teisest palju pikem või piiras mõlemat sama ressurss, näiteks võrk. Paralleel aitab ainult siis, kui harud ootavad eri ressursse.

**Edasi saad minna, kui** Graph View näitab `Avaldamine` all kahte kõrvuti haru, mõlemad on rohelised ja PR-i kirjelduses on etappide ajad enne ja pärast.

## Avalda ainult põhiharult

Igal harul peavad käima build, testid ja quality gate, aga artefakt avaldatakse ainult põhiharult. Muidu tekib Nexusesse versioone igast katsetusest ja keegi ei tea, milline neist on põhiharust.

Job on tavaline Pipeline job, mitte multibranch, seega pole `when { branch 'main' }` siin kasutatav: haru on muutujas `GIT_BRANCH` kujul `origin/k06-jenkins`. Kui kirjutad tingimuse, mis kunagi ei kehti, jääb avaldamine vaikselt vahele ja keegi ei märka, et Nexusesse ei tule enam midagi.

1. Lisa etapile `Avaldamine` tingimus `when { expression { … } }`. Nõuded:
    - tingimus kehtib `GIT_BRANCH` väärtustel `origin/main`, `main`, `origin/k06-jenkins` ja `k06-jenkins`;
    - tingimus ei kehti `origin/k06-proov` ega `origin/k06-jenkins-vana` peal, seega mustrit tuleb võrrelda tervikuna (`==~`), mitte `contains`-iga;
    - Groovy regulaaravaldises on kaldkriips `/…/` vahel, nii et `/` mustri sees vajab paomärki.

2. Push ja oota buildi. Haru `k06-jenkins` peab avaldama nagu enne.
3. Loo proovi-haru ja temale eraldi job.

    ```bash
    git switch -c k06-proov && git push -u origin k06-proov && git switch k06-jenkins
    ```

4. Jenkinsis folderis `<gh>`: **New Item → `labori-seis-proov` → Copy from `labori-seis`**. Configure → *Branch Specifier* `*/k06-proov`. **Build Now**.
5. Kui build on läbi, kustuta job `labori-seis-proov` ja haru: `git push origin --delete k06-proov && git branch -D k06-proov`.

Proovi-job tegi kõik kontrollid, aga `Avaldamine` oli hall. See tõestab tingimuse mõlemat poolt: põhiharu avaldab, muu haru mitte. Proovi-job kustutatakse, sest see analüüsis sama Sonari projekti ja Community Build ei erista harusid: selle analüüs kirjutas sinu põhiharu oma üle.

**Edasi saad minna, kui** `labori-seis-proov` töötas Buildist Quality Gate'ini ja `Avaldamine` oli Graph View's vahele jäetud (hall), Nexusesse uut versiooni ei tulnud ja proovi-job ning haru on kustutatud.

## Paigalda testkeskkonda kinnitusega

Viimane etapp viib image'i käima. Pipeline paigaldab image'i agendile konteinerisse `labseis-ci` (port 8085). Commit'i peale käivitunud build ei tohi seda teha ega jääda kinnitust ootama, inimese käivitatud build küsib enne kinnitust. Siin kasutad põhjuste klasse (`UserIdCause`, `SCMTriggerCause`), mida triggereid proovides API-st lugesid.

Automaatne paigaldus igal commit'il katkestab testkeskkonna ka siis, kui keegi seal parasjagu midagi testib. Kinnitus ilma ajapiiranguta hoiab aga executorit kinni ja peatab kõik järgmised buildid.

Kirjuta etapp `Deploy` pärast `Avaldamine`-t. Nõuded:

- `when`: sama haru tingimus mis `Avaldamine`-l ja `triggeredBy 'UserIdCause'`; `beforeOptions true` ja `beforeInput true`, et tingimust kontrollitakse enne ootamist
- `options { timeout(time: 10, unit: 'MINUTES') }` ja `input` direktiiv sõnumi ning nupuga `Paigalda`
- samm eemaldab vana konteineri (`docker rm -f labseis-ci`, viga ignoreeritakse), käivitab uue image'iga `labori-seis:$ART_VERSION` (`--memory 768m`, `-p 8085:8080`)
- samm ootab, kuni `curl -fsS http://localhost:8085/version` sisaldab commit'i 7 esimest märki, ja ebaõnnestub, kui seda ei juhtu; ebaõnnestumisel näitab `docker logs --tail 30 labseis-ci`
- direktiivide süntaksi annab **Pipeline Syntax → Declarative Directive Generator** (`when`, `input`, `options`)

**Ennusta:** mis juhtub etapiga `Deploy` pollSCM-i buildis, käsitsi käivitatud buildis ja Abort'iga katkestatud buildis?

1. Tee väike commit ja oota pollSCM-i buildi. `Deploy` peab olema vahele jäetud ja build lõpeb ilma ootamata.
2. Vajuta **Build Now**. Build peatub etapis `Deploy`: vajuta konsoolis või Graph View's **Paigalda**.
3. Vajuta veel kord **Build Now** ja seekord **Abort**. Vaata buildi tulemust.

Kontrolli konteinerit ja salvesta Jenkinsfile repositooriumi:

```bash
docker ps --filter name=labseis-ci --format '{{.Image}} {{.Status}}'
curl -s http://localhost:8085/version; echo
git commit -am "k06: parallel, when, input + deploy" && git push
```

Kolm buildi andsid kolm eri tulemust sama Jenkinsfile'iga: pollSCM jättis etapi vahele, kinnitus paigaldas, Abort katkestas. `/version` vastus sama räsiga tõestab, et käima läks just see build, mitte vana image. Abort'iga build jättis vana konteineri tööle, sest `docker rm` käivitub alles pärast kinnitust.

**Edasi saad minna, kui** pollSCM-i build jättis `Deploy` vahele, kinnitatud build töötas lõpuni ja `/version` näitab sama commit'i mis buildi nimi, Abort'iga build on ABORTED ja konteiner `labseis-ci` töötab edasi viimati kinnitatud versiooniga.

## Tõesta, et konteineris on sama WAR

`sha1sum` tõestas, et Jenkinsi ja Nexuse WAR on sama. Nüüd lõpetad ahela: töötavas konteineris olev fail peab andma sama räsi. Vaatad ka, mida ütleb Dockeri healthcheck.

Ilma selle kontrollita on "build once" ainult lubadus Dockerfile'is. Auditis küsitakse, kas tootmises töötav fail on sama, mis testiti, ja vastus peab olema käsk, mitte arvamus.

1. Arvuta räsi otse image'ist ja võrdle seda Nexuse `.sha1` failiga.

    ```bash
    v=$(docker inspect --format '{{.Config.Image}}' labseis-ci | cut -d: -f2)
    docker run --rm --entrypoint sha1sum "labori-seis:$v" /usr/local/tomcat/webapps/ROOT.war
    curl -fsS "http://nexus.lab.hkhk.ee:8081/repository/labori-seis/ee/hkhk/<gh>/labori-seis/$v/labori-seis-$v.war.sha1"; echo
    ```

2. Vaata HEALTHCHECK'i olekut ja viimaseid kontrolle.

    ```bash
    docker inspect --format '{{.State.Health.Status}}' labseis-ci
    docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{end}}' labseis-ci; echo
    ```

Sama räsi image'is ja Nexuses lõpetab tõendi ahela: Jenkins, Nexus ja konteiner kasutavad üht faili. `healthy` ja rida nulle tähendavad, et `/health` vastab. Kui räsi erineb, on Dockerfile'is midagi, mis WAR-i muudab, või käivitasid käsitsi vana image'i.

**Edasi saad minna, kui** kaks räsi on samad, konteiner on `healthy` ja PR-i kirjelduses on mõlemad read.

**Selle mooduli tõend:** commit `k06: parallel, when, input + deploy`; PR-i kirjelduses `docker image ls` ja `docker inspect` väljund, `Avaldamine` etappide ajad enne ja pärast `parallel`-it, proovi-jobi Graph View ekraanipilt, `/version` väljund, kolme buildi põhjus ja tulemus (SCM change, Paigalda, Abort), konteineri ja Nexuse räsi ning healthcheck'i olek; `files` ja `docker` `OK`.

## Miks see nii töötab

**Docker socket ja grupp.** Ubuntu Dockeri paketis kuulub `/var/run/docker.sock` grupile `docker` õigustega `srw-rw----`. Rootless-Dockeris on socket `$XDG_RUNTIME_DIR/docker.sock` ja daemon töötab kasutaja õigustes, nii et `-v /:/host` annab ainult selle kasutaja failid.

**Grupi muutus jõustub uues protsessis.** Seetõttu käivitab `jenkins-agent.sh` lõpus käsu `systemctl restart jenkins-agent`.

**Image'ite koristus.** `docker image ls` järjestab uusimad ette. Töötava konteineri image'it `docker rmi` ilma `-f`-ita ei kustuta, nii et koristus ei saa testkonteinerit alt ära võtta.

**Tingimus `branch`.** Tingimus `branch` loeb muutujat `BRANCH_NAME`, mille Jenkins määrab multibranch-job'is, seega tavalises Pipeline job'is see tingimus ei rakendu.

**`input` ja executor.** Kui pipeline'i ülaosas on `agent none` ja agent on määratud ainult ehitavatele etappidele, ootab kinnitus ilma executorita ([Lisaülesanded → 8. Kinnitus ilma executorita](lisa.md#8-kinnitus-ilma-executorita)).

**HEALTHCHECK'i olek.** HEALTHCHECK'i olekut jälgib Docker, kuid tavaline `docker run` ei tee `unhealthy`-olekuga midagi. Olek on signaal monitooringule ja Docker Swarmile, mis asendab `unhealthy`-olekus konteineri; Docker ise konteinerit ei paranda. Kubernetes Dockerfile'i HEALTHCHECK'i ei kasuta: seal kirjeldatakse liveness- ja readiness-probe'id manifestis, seda näed 7. kohtumisel.

Lisaülesanne [14. WAR Nexusest app01-le koos rollback'iga](lisa.md#14-war-nexusest-app01-le-koos-rollbackiga): paigaldad sama WAR-i Ansible'iga app01 Tomcatisse ja tõestad, et vigane versioon jätab tööle eelmise.
