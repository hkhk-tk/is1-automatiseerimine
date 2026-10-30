---
tags:
  - Docker
  - Dockerfile
  - multistage
---

# 3. App image

Paisunud või root'ina töötavat app-image'it ei paranda ühes kohas: app-image'i ehitab GitHub Actionsi pipeline iga commit'iga ja Kubernetese klaster käivitab, nii et iga siin tehtud viga korrutub hiljem iga build'i ja iga node'iga. 300 MB image tõmmatakse igale node'ile kolm korda kiiremini kui 1 GB image ja Trivy leiab sealt vähem asju, mida keegi ei kasuta. Lõpuks on app-image mitmeastmeline, kasutab cache'i, tema PID 1 saab SIGTERM-i kätte ja ta ei tööta root'ina. Kõrval on väike tööriista-image, millega kontrollid stacki seestpoolt.

**Kui teed seda tööl iga päev:** sinu Java image on mitmeastmeline, töötab mitte-root UID-ga ja `docker history` näitab, et koodimuudatus ei tühista sõltuvuste kihti. Kui see on sul juba korras, kirjuta mitmeastmeline Dockerfile ise ja mine otse etappi „[Kihid kettal: history, GraphDriver ja kirjutatav kiht](#kihid-kettal-history-graphdriver-ja-kirjutatav-kiht)“.

## Naiivne variant ja selle suurus

Võrdluseks teed kõigepealt image'i nii, nagu enamik veebinäiteid: üks aste, kogu repo sisse, Maven ehitab. See töötab, aga image kannab kaasas JDK, Maveni ja kogu sõltuvuste vahemälu.

Kirjuta ajutine `k03-docker/app/Dockerfile.naive` (Giti see ei lähe):

- üks aste `maven:3-eclipse-temurin-21` peal
- `COPY . .` ja `mvn -B -q package -DskipTests`
- käivitus `java -jar target/labori-seis.war` (WAR on käivitatav, Tomcat on selle sees)

```bash
time docker build -f k03-docker/app/Dockerfile.naive -t labseis-app:naive .
docker image ls labseis-app
```

> Kui `COPY . .` ei too lähtekoodi kaasa, töötab sinu allowlist: kontrolli, et `pom.xml` ja `src` on lubatud.

Build'i aeg tuli peamiselt sõltuvuste allalaadimisest, suurus ehitustööriistadest.

**Edasi saad minna, kui** image on suurusjärgus 800 MB või rohkem ja esimene build oli aeglane (Maven laeb sõltuvusi).

## Mitmeastmeline Dockerfile

Kirjutad Dockerfile'i kahes astmes. Esimene aste ehitab WAR-i, teine käivitab selle. Lõppimage'isse jõuab ainult see, mille sa `COPY --from` abil teisest astmest üle tood.

Tabel L3.2 on plaan astmete kaupa: esimene aste on ehitusmasin, mis pärast ehitust kustutatakse; teine on see, mis tootmisse läheb; lõpu read on metaandmed, mis muutuvad iga commit'iga ja peavad seepärast olema viimased.

| Aste | Mida teeb |
|---|---|
| `FROM maven:3-eclipse-temurin-21 AS build` | töökataloog `/src`; **ainult** `pom.xml`; `mvn -B -q dependency:go-offline`; siis `src/`; `mvn -B -q package -DskipTests` |
| `FROM tomcat:10.1-jre21-temurin` | ühes `RUN`-is: `apt-get update`, `curl` (`--no-install-recommends`), apt nimekirjade ja `webapps/*` kustutamine; `COPY --from=build` WAR → `webapps/ROOT.war`; `EXPOSE 8080`; `HEALTHCHECK` `curl -fsS http://localhost:8080/health` (`--start-period=60s`) |
| lõpp | `ARG GIT_SHA=unknown`, `ENV GIT_SHA=${GIT_SHA}`, `LABEL org.opencontainers.image.revision="${GIT_SHA}"`, `CMD ["catalina.sh", "run"]` |

*Tabel L3.2. App-Dockerfile'i plaan.*

1. Kirjuta `k03-docker/app/Dockerfile` [kahes astmes](https://docs.docker.com/build/building/multi-stage/) tabeli L3.2 järgi. Kirjuta ise, ära kopeeri naiivset.
2. Ehita ja võrdle.

    ```bash
    docker build -f k03-docker/app/Dockerfile --build-arg GIT_SHA=$(git rev-parse --short HEAD) -t labseis-app:multi .
    docker image ls labseis-app
    docker history labseis-app:multi | head -8
    docker image inspect -f '{{json .Config.Labels}}' labseis-app:multi
    ```

Suuruse vahe on JDK, Maven ja `~/.m2`. `history` ülemised read on WAR ja metaandmed; kui näed seal Maveni kihte, kopeerib käitusaste valest kohast. Label SHA-ga ütleb hiljem registry's, millisest commit'ist image tehti, ilma Giti vaatamata.

**Edasi saad minna, kui** `multi` on mitusada MB väiksem kui `naive`, `history` ülemistes ridades on WAR (~50–60 MB) ja curl'i kiht, Maveni kihte pole, ja label'is on sinu SHA. Kirjuta mõlema suurus TOEND.md-sse.

## Mis lõppimage'isse jõudis

Suurus on üks mõõt. Teine on sisu: mis programmid on image'is olemas ja mida ründaja konteineris kasutada saaks. Vaatad mõlemat image'it seestpoolt, ilma teenust käivitamata.

Kompilaator ja ehitustööriistad tootmise image'is on ründajale tööriistakast. Nendega saab konteineris koodi ehitada, sõltuvusi alla laadida ja oma tööriistu kokku panna.

1. Otsi kummastki image'ist Javat, Mavenit ja kompilaatorit.

    ```bash
    docker run --rm --entrypoint sh labseis-app:naive -c 'command -v java mvn javac'
    docker run --rm --entrypoint sh labseis-app:multi -c 'command -v java mvn javac; java -version 2>&1 | head -1'
    ```

2. Vaata, mis on käitusastme `webapps` all ja kas lähtekood on kuskil alles.

    ```bash
    docker run --rm --entrypoint ls labseis-app:multi -l /usr/local/tomcat/webapps
    docker run --rm --entrypoint sh labseis-app:multi -c 'ls /src 2>&1; find / -name "*.java" 2>/dev/null | head -3'
    ```

`naive` image'is on `mvn` ja `javac`, `multi`-s ainult `java` (JRE). `webapps` all on üks WAR, Tomcati näiterakendusi pole. Lähtekoodi lõppimage'is pole: see jäi build-astmesse, mida registry'sse ei lükata.

**Edasi saad minna, kui** `naive` näitab kolme teed, `multi` ainult `java` teed, `webapps` all on ainult `ROOT.war` ja `/src` puudub. Kirjuta TOEND.md-sse üks lause: mida ründaja `naive` image'is teha saaks, mida `multi`-s ei saa.

## Cache töötab ja läheb katki

Cache teeb korduva build'i sekunditeks, aga ainult siis, kui juhiste järjekord seda lubab. Esimene muutunud kiht tühistab kõik järgnevad. Teed kaks katset: üks näitab cache'i töötamist, teine selle tahtmatut purunemist.

GitHub Actionsi CI-s tähendab purunenud cache iga commit'iga minuteid lisaaega ja uut apt-kihti, mis tuleb igale node'ile uuesti tõmmata.

1. Muuda üht rida mõnes Java-failis (näiteks kommentaar `VersionController.java`-s) ja ehita uuesti sama käsuga.
2. Tõsta ajutiselt `ARG GIT_SHA` ja `ENV GIT_SHA` käitusastme algusesse (kohe `FROM tomcat…` järele) ja ehita kaks korda erineva väärtusega.

    **Ennusta:** kas `apt-get` kiht ehitatakse teisel korral uuesti?

    ```bash
    docker build -f k03-docker/app/Dockerfile --build-arg GIT_SHA=aaa -t labseis-app:multi . 2>&1 | grep -E 'CACHED|apt-get' | head -5
    docker build -f k03-docker/app/Dockerfile --build-arg GIT_SHA=bbb -t labseis-app:multi . 2>&1 | grep -E 'CACHED|apt-get' | head -5
    ```

3. Pane read tagasi lõppu ja võta Java-faili muudatus tagasi (`git restore src`).

Esimene katse näitas, et `pom.xml`-i eraldi kopeerimine töötab: koodi muudatus ei laadinud sõltuvusi uuesti. Teine näitas, et ka üks `ARG` vales kohas ehitab kõik järgnevad kihid uuesti, sest muutuja väärtus on kihi sisendi osa. Reegel on lihtne: mida sagedamini muutub, seda lõpus.

**Edasi saad minna, kui** esimesel korral oli `dependency:go-offline` samm `CACHED` ja uuesti käivitusid ainult `COPY src` ja järgmised, teisel katsel töötas `apt-get` iga SHA-ga uuesti, kuigi midagi ei muutunud.

## Kihid kettal: history, GraphDriver ja kirjutatav kiht

Vaatad kihte kettal: kui suur on iga kiht, kus need hostis asuvad ja kuhu läheb see, mida konteiner kirjutab.

Kui saladus või suur fail satub ühte kihti ja järgmine `RUN rm` selle "eemaldab", jääb see registry'sse ja igale node'ile alles. Igaüks, kes image'i tõmbab, saab kihi lahti pakkida ja faili kätte ilma konteinerit käivitamata.

1. Vaata app-image'i kihte koos suuruse ja juhisega, kihtide arvu ja salvestusdraiverit.

    ```bash
    docker history --format '{{.Size}}\t{{.CreatedBy}}' labseis-app:multi | head -8 | cut -c1-100
    docker image inspect -f '{{len .RootFS.Layers}} kihti' labseis-app:multi; docker info -f '{{.Driver}}'
    docker image inspect labseis-app:multi | jq '.[0].GraphDriver // "GraphDriver puudub: containerd store"'
    ```

2. Ehita proov-image, kus fail luuakse ühes kihis ja kustutatakse järgmises.

    ```bash
    printf 'FROM alpine:3.22\nRUN head -c 50000000 /dev/urandom > /suur\nRUN rm /suur\n' | docker build -q -t kihtproov -
    docker image ls kihtproov; docker history kihtproov | head -4
    ```

3. Käivita app konteinerina, kirjuta konteineris fail ja vaata kirjutatavat kihti `docker diff`-iga ja hostist.

    ```bash
    docker run -d --name kiht labseis-app:multi && sleep 20
    docker exec kiht sh -c 'echo proov > /tmp/minu.txt'; docker diff kiht | head -8
    U=$(sudo grep -o 'upperdir=[^,]*' /proc/"$(docker inspect -f '{{.State.Pid}}' kiht)"/mountinfo | head -1 | cut -d= -f2)
    echo "$U"; sudo ls -l "$U/tmp"; docker rm -f kiht
    ```

> `overlay2` draiveriga näitab `GraphDriver.Data` kihtide kaustu (`LowerDir`, `UpperDir`) otse ja `docker inspect kiht | jq -r '.[0].GraphDriver.Data.UpperDir'` annab sama kausta. containerd'i image store'iga (`overlayfs`) välja `GraphDriver` pole, ja kaust tuleb konteineri mount'ist, nagu sammus 3; see töötab mõlemaga.

`history` näitas, et suured on ainult apt'i ja WAR-i kihid; `ENV`, `LABEL` ja `CMD` on 0 B, sest need muudavad ainult metaandmeid. `kihtproov` on üle 50 MB, kuigi alpine ise on alla 10 MB ja `/suur` on kustutatud: 50 MB kiht on alles ja `rm` lisas paari KB suuruse kihi, mis ainult peidab faili. `docker diff` näitas `A` (lisatud) ja `C` (muudetud) ridu, sh Tomcati `work` ja `logs` muudatusi. Sama fail paistis hostis kirjutatava kihi kaustas. Konteineri kirjutatav kiht on lihtsalt kataloog hosti kettal ja kaob `docker rm`-iga.

**Edasi saad minna, kui** tead app-image'i kihtide arvu ja draiverit, `kihtproov` on üle 50 MB ja tema `history`-s on 50 MB kiht, `docker diff` näitab `A /tmp/minu.txt` ja hostis on `minu.txt` kirjutatava kihi `tmp` all. Kirjuta TOEND.md-sse `kihtproov` suurus ja üks lause: kuidas saladuse image'ist tegelikult välja saad.

## Kes on PID 1

`docker stop` saadab PID 1-le SIGTERM-i ja ootab 10 sekundit. Kas Tomcat selle kätte saab, sõltub CMD vormist. Mõõdad mõlemat varianti.

Tomcat, kes ei saa SIGTERM-i, ei lõpeta pooleli päringuid ega sulge andmebaasi ühendusi. Iga deploy katkestab siis kasutajate päringuid ja lisab 10 sekundit seisakut.

1. Käivita app ja vaata, kes on PID 1 ja kui kaua `stop` kestab.

    ```bash
    docker run -d --name appt labseis-app:multi
    docker exec appt cat /proc/1/cmdline | tr '\0' ' '; echo
    time docker stop appt
    ```

2. Muuda viimane rida ajutiselt shell-vormi `CMD catalina.sh run`, ehita, käivita uue konteinerina ja korda sama.
3. Pane exec-vorm tagasi ja ehita uuesti.

> Olek `unhealthy` on siin õige: andmebaasi pole ja `/health` annab 503. Rakendus ise vastab: `docker exec appt curl -s localhost:8080/health/live`.

Shell-vormis on PID 1 `sh`, kes signaali edasi ei anna; 10 sekundi pärast tuli SIGKILL. Exec-vormis sai Java signaali ja lõpetas paari sekundiga. Kui `docker logs appt` näitab pärast stoppi `Stopping service [Catalina]`, jõudis signaal kohale.

**Edasi saad minna, kui** exec-vormiga on PID 1 `java` ja `stop` võtab paar sekundit, shell-vormiga on PID 1 `/bin/sh -c …` ja `stop` umbes 10 s. Kirjuta mõlemad ajad TOEND.md-sse.

## Mitte-root kasutaja

Ametlik Tomcati image töötab root'ina, ja konteineri root on hosti root, kui user namespace'i pole, ja vaikimisi seda pole. Annad Tomcatile oma kasutaja ja ainult need kaustad, kuhu ta kirjutab.

Kui rakenduses on kaugkäivituse haavatavus, saab root'ina töötav protsess üle kirjutada Tomcati binaarid ja konfiguratsiooni. UID 10001-na saab ründaja kirjutada ainult logidesse ja ajutistesse kaustadesse.

Muuda `k03-docker/app/Dockerfile` nii:

- käitusastmes luuakse süsteemikasutaja UID-ga 10001 ilma kodukataloogi ja shellita (`useradd --system`)
- kasutajale kuuluvad ainult `logs`, `temp`, `work`, `webapps` ja `conf/Catalina` kaust `/usr/local/tomcat` all; ülejäänu jääb root'ile
- WAR kopeeritakse `COPY --from=build --chown=10001:10001`
- `USER 10001` numbrina, enne `CMD`-i
- kasutaja loomine on samas `RUN`-is mis apt, et kihte ei tuleks juurde

```bash
docker rm -f appt; docker build -q -f k03-docker/app/Dockerfile -t labseis-app:multi .
docker run -d --name appt labseis-app:multi && sleep 40
docker exec appt id; docker exec appt curl -s localhost:8080/health/live; echo
docker exec appt touch /usr/local/tomcat/conf/x
docker image inspect -f '{{.Config.User}}' labseis-app:multi
```

> Kui Tomcat ei käivitu ja logis on `Permission denied` mõne kausta kohta, kuulub see kaust veel root'ile.

`touch` `conf/` alla ebaõnnestus: konfiguratsioon on kirjutuskaitstud ka töötavale rakendusele. `/health/live` vastas, seega said kõik kirjutatavad kaustad õige omaniku. Numbriline `User` on see, mida kontrollivad Trivy `config` registry lehel ja hiljem Kubernetes.

**Edasi saad minna, kui** `id` näitab `uid=10001`, `/health/live` vastab `{"status":"UP"}`, `touch` annab `Permission denied` ja image'i `User` on `10001`.

## ENTRYPOINT ja CMD: kontroll-image

See image on tööriist, mis teeb ühe asja ja lõpetab. Tööriista-image küsib Labori seisult olekut; Compose'i stackis kontrollid sellega stacki seestpoolt. ENTRYPOINT on programm, CMD tema vaikeargument, ja mõlemat saab käsureal asendada.

Sama muster on Trivy, kubectl'i ja CI image'itel. Kui sa ei tea, mis on ENTRYPOINT, ei saa sa neid pipeline'is õigesti kasutada ja saad vea `unknown command`.

Kirjuta `k03-docker/kontroll/Dockerfile` (kontekst on see kaust):

- baas `alpine:3.22`, `apk add --no-cache curl`
- `LABEL org.opencontainers.image.description="Labori seisu kontroll"`
- `USER nobody`
- `ENTRYPOINT ["curl", "-fsS", "--max-time", "5"]` ja `CMD ["http://web01/health"]`

1. Ehita ja käivita app testvõrgus.

    ```bash
    docker build -t labseis-kontroll:test k03-docker/kontroll
    docker network create k03test
    docker rm -f appt; docker run -d --name appt --network k03test labseis-app:multi
    ```

2. Käivita kontroll-image kolmel viisil: ilma argumendita, argumendiga ja asendatud ENTRYPOINT-iga.

    ```bash
    docker run --rm --network k03test labseis-kontroll:test; echo "exit=$?"
    sleep 30; docker run --rm --network k03test labseis-kontroll:test http://appt:8080/health/live; echo
    docker run --rm --entrypoint sh labseis-kontroll:test -c 'id; head -2 /etc/os-release'
    ```

3. Koristus: `docker rm -f appt && docker network rm k03test`.

Vaikimisi käivitus ENTRYPOINT koos CMD-ga, argument asendas ainult CMD-i, `--entrypoint` asendas programmi. Kood 6 on curl'i kood "nime ei lahendatud", nii et skript saab eristada nimeviga ühendusveast (7) või HTTP veast (22).

**Edasi saad minna, kui** esimene annab `Could not resolve host: web01` ja `exit=6` (töötas vaike-CMD), teine `{"status":"UP"}` (argument asendas CMD-i) ja kolmas `uid=65534(nobody)` (asendati programm ise). Kirjuta kolm väljundit TOEND.md-sse.

## Commit

Enne commit'i käivitad automaatse hindaja testi, mis vaatab app-Dockerfile'i kuju.

```bash
rm -f k03-docker/app/Dockerfile.naive
bash autograde/check.sh k03 multistage
git add k03-docker/app k03-docker/kontroll k03-docker/TOEND.md
git commit -m "K3.3 mitmeastmeline app, mitte-root, kontroll-image" && git push
```

`multistage` vaatab ainult faili kuju: kaks `FROM`-i ja `COPY --from`. Kas image töötab, nägid sa ise; automaatse hindaja `build` ehitab selle esitamisel värskest kloonist.

**Edasi saad minna, kui** `multistage` annab `OK` ja `Dockerfile.naive` pole Gitis. `tags` vajab ka `compose.yaml`-i ja läheb läbi alles siis, kui stack on Compose'is kirjas.

**Selle osa tõend:** commit `K3.3 …`; TOEND.md-s image'ite suurused, lõppimage'i sisu lause, `kihtproov` suurus ja saladuse lause, kaks `docker stop` aega, `id` väljund ja kontroll-image'i kolm käivitust.

## Miks see nii töötab

**Kihid ja kettaruum.** `docker history` loetleb kihid koos suurusega. `docker system df` näitab, kui palju ruumi võtavad image'id, konteinerid, volume'id ja ehituse vahemälu (build cache).

**Mitmeastmeline ehitus.** Mitmeastmelise ehituse (multi-stage build) vaheaste ei jõua registry'sse. See jääb ainult ehituse vahemällu ja eemaldatakse käsuga `docker builder prune`. Seetõttu pole lõpp-image'is lähtekoodi ega kompilaatorit.

**Numbriline UID.** Mitte-root kasutaja numbriline UID on vajalik Kubernetese `runAsNonRoot` jaoks. Kubernetes peab suutma kindlaks teha, et kasutaja ei ole UID 0; ainult kasutajanime (`USER labseis`) põhjal ei pruugi see image'i metaandmetest selguda.

**Shell- ja exec-vorm.** Exec-vormis (`CMD ["java", "-jar", "app.jar"]`) on rakendus ise PID 1 ja saab käsu `docker stop` saadetud signaali `SIGTERM` otse kätte. Shell-vormis (`CMD java -jar app.jar`) käivitab Docker `/bin/sh -c …` ja PID 1 on shell, mis signaali rakendusele edasi ei anna. Siis ootab `docker stop` 10 sekundit ja lõpetab konteineri signaaliga `SIGKILL`. Kui enne rakendust on vaja käivitada skript, lõpeta see käsuga `exec "$@"`, nagu ametlikud entrypoint'id teevad: rakendus asendab shelli ja saab ise PID 1-ks.

**Kontroll-image ja tööriista-image'id.** Kontroll-image'is on image'i põhiprotsess (`ENTRYPOINT`) tööriist ise, nii et `docker run` argumendid lähevad tööriistale, mitte shellile. Samamoodi on ehitatud tööriista-image'id, näiteks Trivy ja GitHub Actionsi CI konteinerid. Tööriista asemel muu käsu käivitamiseks tuleb `ENTRYPOINT` üle kirjutada (`docker run --entrypoint sh …`).

**Image store.** Image'i kihtide salvestus sõltub Docker Engine'i seadistusest. Vanemates ja uuendatud paigaldustes on salvestusdraiver `overlay2` ja kihid asuvad kataloogis `/var/lib/docker/overlay2`. Docker 29 uutes paigaldustes on vaikimisi containerd'i image store: `docker info` näitab draiverit `overlayfs` ja kihid asuvad kataloogis `/var/lib/containerd`. Kumb variant sinu masinas on, näitab `docker info -f '{{.Driver}}'`.

**Overlay-ühendus.** Konteineri juurfailisüsteem on mõlemal juhul overlay-ühendus (overlay mount): kirjutuskaitstud alumised kihid (`lowerdir`) ja üks kirjutatav ülemine kiht (`upperdir`). Kui hilisem kiht faili kustutab, lisatakse ülemisse kihti whiteout-kirje, aga alumises kihis jääb fail alles. Kui konteiner muudab alumises kihis olevat faili, kopeerib overlayfs enne esimest kirjutust terve faili `upperdir`-i (copy-up). Seepärast on suur ja sageli muutuv fail, näiteks andmebaasi tabelifail, kirjutatavas kihis aeglane ja täidab `/var/lib/docker` partitsiooni.

**Pakitud ja lahtipakitud suurus.** Registry's hoitakse kihte pakitud tar-arhiividena, `docker image ls` näitab lahtipakitud suurust.

Kui jõudsid kiiremini: [Lisaülesanded → 7. Väiksem image ilma Tomcatita](lisa.md#7-vaiksem-image-ilma-tomcatita), ehitad sama rakenduse JRE-alpine peale ja võrdled suurust ning Trivy leide.
