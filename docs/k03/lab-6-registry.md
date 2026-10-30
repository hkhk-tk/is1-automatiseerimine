---
tags:
  - Docker
  - registry
  - Trivy
  - SBOM
---

# 6. Registry, Trivy ja SBOM

Image, mis on ainult sinu masinas, ei jõua kunagi tootmisse ja rollback'i hetkel pole teda kusagilt võtta: GitHub Actionsi ja Jenkinsi pipeline'id ning Kubernetese klaster tõmbavad selle registry'st, kus tal on nimi, versioon ja ligipääs igale masinale, kellel on õigus. Lõpuks on sinu kolm image'it kooli Gitea registry's git-SHA tag'iga, stack käib sealt ilma lokaalse build'ita ja Trivy raporti põhjal on otsus kirja pandud. App-image'ist on SBOM, millega vastad auditis või intsidendi järel küsimusele, mis selles image'is on ja kas sa teadsid, et see on haavatav, ning mille vastu saab hiljem skännida ilma image'it tõmbamata. Käsud käivita kaustas `k03-docker/`, põhistackiga (`COMPOSE_FILE` seadmata).

**Kui teed seda tööl iga päev:** lükkad image'eid asutuse registry'sse git-SHA tag'iga ja `trivy image` töötab sinu pipeline'is. Kui see on sul juba korras, tee push ja Trivy skänn ise ja mine otse etappi „[SBOM](#sbom)“.

## Login ja push

Logid Gitea registry'sse tokeniga ja lükkad sinna kolm image'it. Tag'iks saab commit'i lühike SHA, et iga image'i saaks seostada koodiga.

Tag `latest` või `dev` ei ütle, mis kood image'is on. Kui midagi läheb katki, ei tea sa, millise versiooni juurde tagasi minna, ega saa tõestada, mis tootmises töötas.

1. Gitea kasutaja on sul olemas (kasutajanimi = GitHubi kasutajanimi, ajutine parool koolitajalt). Loo **Gitea → Settings → Applications** token õigusega `write:package` ([juhend](https://docs.gitea.com/usage/packages/container)).

    <!-- EKRAANIPILT: Gitea, https://gitea.lab.hkhk.ee/user/settings/applications → "Generate New Token" vorm, tokeni nimi k03 ja õiguste all package: Read and Write valitud; enne nupu vajutamist
    <figure markdown="span">
      ![Gitea tokeni loomise vorm, õigus package: Read and Write](assets/k03_gitea_token.png)
      <figcaption>Joonis L3.6. Tokenile piisab paketiõigusest.</figcaption>
    </figure>
    -->

2. Pane `.env`-i tag'iks commit'i SHA, logi sisse tokeniga ja pushi.

    ```bash
    TAG=$(git rev-parse --short HEAD) && sed -i "s/^TAG=.*/TAG=$TAG/" .env
    docker login gitea.lab.hkhk.ee -u <sinu-github>
    docker compose build && docker compose push
    ```

    <!-- EKRAANIPILT: Gitea, https://gitea.lab.hkhk.ee/<kasutaja>/-/packages → nimekiri kolme konteineripaketiga labori-seis-app, labori-seis-db, labori-seis-web, igaühel lühike git-SHA tag; pärast `docker compose push`
    <figure markdown="span">
      ![Gitea Packages vaade kolme image'iga labori-seis-app, -db ja -web](assets/k03_gitea_packages.png)
      <figcaption>Joonis L3.7. Kolm image'it Gitea registry's git-SHA tag'iga.</figcaption>
    </figure>
    -->

3. Anna web-image'ile teine nimi ja pushi see.

    ```bash
    W=gitea.lab.hkhk.ee/<sinu-github>/labori-seis-web
    docker tag "$W:$TAG" "$W:k03" && docker image ls "$W"
    docker push "$W:k03"
    ```

> `x509: certificate signed by unknown authority`: kooli CA tuleb panna faili `/etc/docker/certs.d/gitea.lab.hkhk.ee/ca.crt`, mitte `insecure-registries` alla. `insecure-registries` lülitab sertifikaadi kontrolli välja ja token liigub siis serverile, kelle identiteeti keegi ei kontrolli.

`Layer already exists` teisel push'il tähendab, et registry hoiab kihte, mitte terveid image'eid: sama sisuga kiht salvestatakse üks kord. Uus tag on ainult uus nimi sama manifesti juurde, seepärast on IMAGE ID mõlemal real sama.

**Edasi saad minna, kui** Gitea **Packages** all on kolm image'it tag'iga `<lühike SHA>`, web-image'i kahel real on sama IMAGE ID ja teine push ütles iga kihi kohta `Layer already exists`. Salvesta Packages vaade faili `img/gitea-packages.png`.

## Tag ja digest

Tag on silt, mida saab ümber tõsta. Digest on manifesti räsi ja ei muutu kunagi. Vaatad, et sinu kaks web-tag'i viitavad samale digest'ile, ja tõmbad image'i digesti järgi.

Kui keegi lükkab sama tag'i alla uue image'i, saab järgmine `pull` teise sisu, ilma et keegi seda märkaks. Digest'iga viide garanteerib, et tootmises töötab täpselt see, mida testisid.

1. Vaata kummagi tag'i digesti ja tõmba image digesti järgi.

    ```bash
    docker image inspect -f '{{json .RepoDigests}}' "$W:$TAG" | jq .
    D=$(docker image inspect -f '{{index .RepoDigests 0}}' "$W:k03")
    docker pull "$D" && docker image ls --digests "$W"
    ```

2. Vaata, mida Compose näeb: `docker compose config --images` ja võrdle seda `docker compose images` väljundiga.

Mõlemal tag'il on sama digest: nimi on erinev, sisu sama. `pull` digesti järgi ei laadinud midagi alla, sest kõik kihid olid olemas. Compose'is ja Kubernetes'es saab image'i kirjutada kujul `nimi@sha256:…`, ja siis ei muuda ükski uus push seda, mis töötab.

**Edasi saad minna, kui** `RepoDigests` näitab mõlemal tag'il sama `sha256:` väärtust, `pull "$D"` ütles `Image is up to date` ja `image ls --digests` näitab kaht rida sama digestiga. Kirjuta TOEND.md-sse digest ja üks lause: millal kasutaksid tootmises digesti, millal tag'i.

## Stack registry'st

Kustutad oma image'id lokaalselt ja käivitad stacki ainult registry'st: nii käivitavad rakenduse GitHub Actionsi pipeline ja Kubernetese klaster. Kui stack käivitub ilma ühegi lokaalse build'ita, on registry's kõik vajalik ja `.env` viitab õigetele tag'idele.

Kui mõni image on ainult sinu masinas, töötab deploy sinu juures ja ebaõnnestub igal teisel masinal. Seda viga on lihtne mitte märgata, sest sinu masinas on kõik alati olemas.

```bash
docker compose down
docker image rm $(docker compose config --images | grep labori-seis-)
docker compose pull && docker compose up -d --no-build --wait
docker compose images
curl -s http://localhost:8080/version; echo
```

`/version` ja image'i tag on sama SHA: töötav kood on tõendatavalt see, mis on Gitis. Andmed jäid alles, sest `down` ilma `-v`-ta ei puuduta volume'eid. `Already exists` kihid tulid kohalikust cache'ist, sest baasimage'id (`tomcat`, `mariadb`, `nginx`) jäid alles.

**Edasi saad minna, kui** `pull` tõmbas app-, db- ja web-image'i Gitea'st (olemasolevad kihid `Already exists`), `docker compose images` näitab Gitea nimesid SHA-tag'iga, `/version` sama SHA-d ja Compose'i stacki kaudu lisatud tulemus on andmebaasis alles. Kirjuta `docker compose images` TOEND.md-sse.

## Trivy image'itele

Trivy loeb image'i kihtidest paketid ja teegid ning võrdleb neid haavatavuste andmebaasiga.

Trivy tuvastab OS-paketid paketihalduri andmebaasist (`/var/lib/dpkg/status`, `/lib/apk/db/installed`) ja Java teegid WAR-i sees olevate JAR-ide `pom.properties` failidest. Allikast kompileeritud C-binaar, millel pole paketi- ega manifestiinfot, jääb skannerile nähtamatuks.

1. Kontrolli Trivy't; kui see puudub, paigalda [ametliku juhendi](https://trivy.dev/docs/latest/getting-started/installation/) järgi (Ubuntu apt repo). Esimene käivitus laeb haavatavuste andmebaasi alla.
2. Skänni kõik kolm image'it faili.

    ```bash
    R=gitea.lab.hkhk.ee/<sinu-github>
    for i in app db web; do
        trivy image --severity HIGH,CRITICAL --format table "$R/labori-seis-$i:$TAG"
    done > trivy.txt 2>&1
    grep -E '^Total|labori-seis' trivy.txt
    ```

3. Vaata, mitu leidu jääb alles, kui jätta välja need, millele parandust veel pole.

    ```bash
    trivy image -q --severity HIGH,CRITICAL --ignore-unfixed "$R/labori-seis-app:$TAG" | grep -E '^Total'
    ```

4. Ava `trivy.txt` ja vasta TOEND.md-s:

    - Millises image'is on kõige rohkem leide ja kas need on OS-paketid või Java teegid?
    - Vali üks CRITICAL või HIGH leid: mis pakett, mis versioonis on parandus (`Fixed Version`)?
    - Mida teed: uuendad baasimage'it, teeki `pom.xml`-is või aktsepteerid? Miks?

Leidude jaotus ütleb, kus tööd teha. OS-paketi leid kaob baasimage'i uuendusega, Java teegi leid vajab `pom.xml`-i muudatust ja uut build'i. `--ignore-unfixed` vahe näitab, kui paljudega sa praegu midagi teha ei saa; need on aktsepteerimise või komponendi vahetamise küsimused.

**Edasi saad minna, kui** `trivy.txt` sisaldab kolme image'i tabelit, tead `--ignore-unfixed` vahet ja TOEND.md-s on kolm vastust.

## Trivy lähtekoodile ja konfiguratsioonile

Image'i skänn tuleb pärast build'i. `fs` ja `config` töötavad lähtekoodi peal ja sobivad seepärast pipeline'i algusesse, enne kui keegi minuteid build'ile kulutab.

Root'ina töötav image või liiga laialt avatud port on seadistusviga, mida CVE-skänn ei näe. Selle leiab ainult konfiguratsiooni kontroll, ja just sellised vead teevad haavatavuse ärakasutamise lihtsaks.

1. Skänni repo juurest lähtekood ja Dockerfile'ide ning Compose'i seadistus.

    ```bash
    cd "$(git rev-parse --show-toplevel)"
    trivy fs --severity HIGH,CRITICAL .
    trivy config --severity HIGH,CRITICAL k03-docker/
    cd k03-docker
    ```

2. Proovi Trivy't konteinerist ja vaata, mida ENTRYPOINT teeb.

    ```bash
    V=$(trivy --version | awk 'NR==1{print $2}')
    docker run --rm aquasec/trivy:"$V" --version
    docker run --rm aquasec/trivy:"$V" trivy --version
    docker run --rm --entrypoint "" aquasec/trivy:"$V" trivy --version
    ```

`fs` nägi ainult `pom.xml`-i sõltuvusi, sest lähtekoodis pole OS-pakette; image'i skänn näeb mõlemat. Konteineris töötav Trivy näitas sama ENTRYPOINT-i mustrit mis sinu kontroll-image: programm on juba ENTRYPOINT ja teine `trivy` sai argumendiks. GitHub Actionsi pipeline kasutab Trivy't just konteinerina.

**Edasi saad minna, kui** `fs` leidis `pom.xml`-ist Java teegid ilma OS-pakettideta, `config` ei märgi app-Dockerfile'i root-kasutaja pärast (db ja web võivad olla märgitud) ja konteinerist töötas esimene ja kolmas käsk, teine andis `unknown command "trivy"`. Kirjuta TOEND.md-sse üks lause `fs` ja `image` vahe kohta ja üks `config` leid koos otsusega.

## SBOM

SBOM on image'i komponentide nimekiri. Haavatavuste andmebaas muutub iga päev, image mitte: SBOM-i vastu skännimine ei vaja image'it. Teed SBOM-i app-image'ist ja skännid seda nagu image'it.

Kui avaldatakse uus kriitiline CVE laialt kasutatud teegis (nagu Log4Shell), on esimene küsimus "kus meil see teek on". SBOM-idega vastad minutitega, ilma kõiki image'eid tõmbamata ja lahti pakkimata.

1. Tee app-image'ist CycloneDX SBOM ja vaata, mis selles on.

    ```bash
    trivy image --format cyclonedx --output sbom-app.json "$R/labori-seis-app:$TAG"
    jq -r '.bomFormat, .specVersion, (.components | length)' sbom-app.json
    jq -r '.components[] | select(.name | test("spring-core|tomcat-embed-core")) | "\(.name) \(.version)"' sbom-app.json
    ```

2. Skänni SBOM-i, mitte image'it, ja võrdle tulemust image'i skänniga.

    ```bash
    trivy sbom --severity HIGH,CRITICAL sbom-app.json | grep -E '^Total'
    grep -A2 'labori-seis-app' trivy.txt | grep -E '^Total'
    ```

Sama suurusjärk SBOM-ist ja image'ist tõestab, et SBOM sisaldab kõike, mida Trivy image'ist leiab. Homme saad sama faili uuesti skännida uuema andmebaasiga. `jq` päring näitas, et konkreetse teegi versiooni leidmiseks ei pea image'it üldse käivitama.

**Edasi saad minna, kui** `bomFormat` on `CycloneDX`, komponente on sadu, Spring'i ja Tomcati versioonid on nähtavad ja `trivy sbom` annab leide samas suurusjärgus kui image'i skänn. Kirjuta TOEND.md-sse, kuidas kasutaksid SBOM-i, kui homme avaldatakse uus CVE.

## Commit

`trivy.txt` ja `sbom-*.json` on `k03-docker/.gitignore`-is. Otsusta, kas mõni neist kuulub Giti, ja põhjenda TOEND.md-s.

```bash
git add k03-docker/img k03-docker/TOEND.md && git status --short
git commit -m "K3.6 registry, Trivy ja SBOM" && git push
```

Raport ja SBOM on ajahetke tulemused ja vananevad kiiresti. GitHub Actionsi pipeline'is tehakse need iga build'iga uuesti ja hoitakse koos image'iga artefaktina, mitte Giti ajaloos.

**Edasi saad minna, kui** commit on GitHubis ja `git status` ei näita `.env`-i ega `secrets/`-i.

**Selle osa tõend:** commit `K3.6 …`; `img/gitea-packages.png`; TOEND.md-s digest ja selle lause, `docker compose images`, Trivy kolm vastust, `fs`/`image` lause, `config` otsus ja SBOM-i kasutuse lause.

## Miks see nii töötab

**Registry sisselogimine.** `~/.docker/config.json` näitab, milliste registry'de autentimisandmed on salvestatud. Kui credential helper puudub, on token seal Base64-kodeeringus, mitte krüpteeritult, seetõttu ei jagata faili kellegagi.

**Registry garbage collection.** Kustutatud tag ei vabasta kohe kettaruumi. Kihid jäävad registry's alles, kuni registry garbage collection need eemaldab.

**CI token.** Kasutatava Gitea versiooni õiguste mudelis annab `write:package` lisaks push'imisele ka õiguse pakette kustutada. Seepärast antakse CI-le eraldi token ainult vajaliku õigusega ja seda ei jagata kasutajate vahel.

**Trivy pakettide nimekiri.** `trivy image --list-all-pkgs --format json` näitab kõiki pakette, mille Trivy image'ist leidis. Samast paketiloendist koosneb ka SBOM.

**`--ignore-unfixed`.** `--ignore-unfixed` peidab leiud, millele parandust veel pole. See sobib pipeline'i peatamise tingimuseks, aga mitte raportiks, sest parandamata riski peab keegi teadlikult aktsepteerima.

**X-tee konteinerina.** Samad küsimused tulevad ette ka Eesti riigi taristus. X-tee turvaserverit levitatakse ka konteineri image'ina ([Security Server Sidecar](https://github.com/nordic-institute/X-Road-Security-Server-sidecar)), nii et asutus saab selle käivitada ilma eraldi virtuaalmasinat ehitamata. Ka selle image'i puhul tuleb jälgida versiooni, CVE-sid ja SBOM-i samamoodi nagu laboris.

Kui jõudsid kiiremini: [Lisaülesanded → Lisaprojekt: oma registry control node'is](lisa.md#lisaprojekt-oma-registry-control-nodeis), paned `registry:2` käima TLS-i ja paroolidega ning lükkad sinna oma web-image'i.
