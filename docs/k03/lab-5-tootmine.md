---
tags:
  - Docker
  - Compose
  - turve
  - operatsioon
---

# 5. Tootmiskeskkonda sobiv stack

Stack töötab, aga paroolid on konteineri keskkonnas, kõik teenused on ühes võrgus internetiga, mälupiire pole ja logid ning ketas kasvavad vabalt. Tootmisserveris tähendab see, et teenus sööb teiste mälu, parool lekib `inspect`-ist, kompromiteeritud rakendus saab internetti, veebijuurde ilmub võõras fail ja ketas saab täis. Kirjutad prod-faili `compose.prod.yaml`, mis tuleb `compose.yaml` peale, varundad ja taastad andmebaasi volume'i ning paned paika koristuspoliitika; `compose.yaml` jääb muutmata, sest seda loevad automaatne hindaja, GitHub Actionsi deploy ja 7. kohtumise töö. Lõpus on sul fail, mille saad panna mis tahes Dockeri hostis põhistacki peale.

**Kui teed seda tööl iga päev:** sinu tootmise Compose'is on ressursipiirangud, saladused failidest ja `internal` võrk ning `docker inspect` ei näita ühtegi parooli. Kui see on sul juba korras, kirjuta `compose.prod.yaml` tabeli L3.5 järgi ise ja mine otse etappi „[Volume'i varundus ja taastamine](#volumei-varundus-ja-taastamine)“.

Tabel L3.5 on prod-faili sisu ühe pildina. Iga rida vastab küsimustele: kui palju see teenus tohib võtta, kuhu ta näeb ja mis on temas kirjutuskaitstud. Väärtused on valitud 4 GB control node'ile. Tootmisserveris mõõdad need `docker stats`-iga koormuse all.

| Teenus | Mälu | CPU | PID-id | Võrgud | Muu |
|---|---|---|---|---|---|
| db01 | 512m | 1.0 | 200 | back | saladused failidest |
| mc01 | 128m | 0.5 | 100 | back | `read_only`, `command: ["memcached", "-m", "64"]` |
| rmq01 | 512m | 1.0 | 300 | back, front | UI ainult `127.0.0.1:15672` |
| app01 | 768m | 1.5 | 300 | back | saladused failidest, `CATALINA_OPTS`, journald |
| web01 | 64m | 0.5 | 100 | front, back | `read_only` + `tmpfs` |

*Tabel L3.5. Prod-faili sisu teenuste kaupa.*

## Prod-fail ja ressursipiirangud

Prod-fail on teine Compose'i fail, mis liidetakse põhifaili peale. Alustad ressursipiirangutest, sest need on kõige lihtsamad ja nende mõju näed kohe `docker stats`-is.

Ilma piiranguteta võib üks teenus teised nälga jätta. Java võtab mälu, mida MariaDB vajaks puhvriteks, ja hosti OOM killer valib ohvri kogu masina seast.

1. Tee kaustas `k03-docker/` fail `.gitignore` ridadega `secrets/`, `backup/`, `trivy.txt`, `sbom-*.json`, `intsident/data/`.
2. Kirjuta `compose.prod.yaml` algus: igale teenusele `deploy.resources.limits` (`memory`, `cpus`, `pids`) tabeli L3.5 järgi ja mc01-le `command`. Faili `name:` ega `build:` ei kordu, need tulevad `compose.yaml`-ist.
3. Vaata ühendatud tulemust ja käivita stack mõlema failiga. `COMPOSE_FILE` kehtib selle shelli lõpuni, `--wait` ootab, kuni kõik healthcheck'id on rohelised.

    ```bash
    export COMPOSE_FILE=compose.yaml:compose.prod.yaml
    docker compose config | grep -A4 'limits:' | head -12
    docker compose up -d --wait && docker compose ps
    docker stats --no-stream
    ```

4. Vaata, mida JVM piirist arvab, siis lisa app01-le `environment`-i `CATALINA_OPTS: "-XX:MaxRAMPercentage=75"` ja korda.

    ```bash
    docker compose exec app01 cat /sys/fs/cgroup/memory.max
    docker compose exec app01 sh -c 'java -XX:+PrintFlagsFinal -version 2>/dev/null | grep -E "MaxHeapSize|MaxRAMPercentage"'
    ```

> `java -XX:+PrintFlagsFinal` käivitab uue JVM-i ilma `CATALINA_OPTS`-ita. Tomcati enda väärtust näed `docker compose exec app01 ps -o args= -p 1`.

JVM luges cgroup'i piiri ja arvutas heap'i selle järgi. Vaikimisi veerand 768 MB-st on alla 200 MB, ja raske päring võib anda `OutOfMemoryError`, kuigi konteiner pole piirile lähedalgi. `MaxRAMPercentage=75` annab heap'ile kolm neljandikku ja jätab ülejäänu metaspace'ile ja lõimedele.

✅ **Edasi saad minna, kui** `docker stats` näitab igal teenusel LIMIT-veerus tabeli väärtust, app01 `memory.max` on `805306368`, vaikimisi `MaxHeapSize` on umbes veerand sellest ja Tomcati käsureal on `-XX:MaxRAMPercentage=75`.

## Piir peab vastu: protsesside arv

Mälupiiri nägid juba `docker run -m`-iga. Protsesside piir kaitseb teise vea eest: fork-pomm või lekkiv skript, mis käivitab protsesse lõputult. Proovid seda web01-s, mille piir on 100.

Ilma `pids`-piiranguta täidab üks konteiner hosti protsessitabeli. Siis ei saa ka `sshd` uut sessiooni avada ja masinat saad parandada ainult konsoolist.

1. Käivita web01-s 150 taustaprotsessi ja vaata, mis juhtub konteineris, `docker stats`-is ja teenusega.

    ```bash
    docker compose exec web01 sh -c 'for i in $(seq 150); do sleep 30 & done' 2>&1 | sort | uniq -c
    docker stats --no-stream --format '{{.Name}} {{.PIDs}}' labori-seis-web01-1
    curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/health
    ```

2. Oota 30 sekundit ja vaata `docker stats` PIDs-veergu uuesti.

Kui piir täis sai, keeldus tuum uut protsessi loomast ja sh andis `can't fork`. Ülejäänud host seda ei tundnud. nginx teenindas päringuid edasi, sest olemasolevad workerid ei vaja uusi protsesse. Pärast `sleep`-ide lõppu langes PID-ide arv tagasi ja konteinerit polnud vaja taaskäivitada.

✅ **Edasi saad minna, kui** osa `sleep`-e andis `can't fork`, PIDs jõudis 100-ni, `/health` andis 200 ja pärast ootamist on PIDs jälle tavalisel tasemel. Kirjuta TOEND.md-sse üks lause: mis oleks juhtunud sama katsega ilma `pids`-piiranguta.

## Saladused failidest

`docker inspect` näitab praegu paroole igale, kes pääseb socket'i juurde. Tee neist failid ja anna need teenustele [`secrets:`](https://docs.docker.com/compose/how-tos/use-secrets/) kaudu. Konteiner näeb faili kaustas `/run/secrets/` ja keskkonda jääb ainult faili tee.

Keskkonnamuutuja lekib mitmest kohast: `docker inspect`, `/proc/<pid>/environ`, rakenduse veateade, mis väljastab keskkonna, ja iga lapsprotsess, mis selle pärib. Faili sisu ei jõua neist ühtegi.

1. Vaata, mida keskkond praegu näitab.

    ```bash
    docker inspect -f '{{json .Config.Env}}' labori-seis-app01-1 | tr ',' '\n' | grep -iE 'pass|token'
    ```

2. Tee saladuste kaust ja failid `.env`-i väärtustest, ilma reavahetuseta.

    ```bash
    mkdir -m 700 secrets
    set -a; . ./.env; set +a
    for k in DB_PASSWORD DB_ROOT_PASSWORD RABBITMQ_PASSWORD TEACHER_TOKEN; do printf '%s' "${!k}" > "secrets/$k"; done
    chmod 644 secrets/*; ls -la secrets; git status --short
    ```

3. Lisa `compose.prod.yaml`-i nende nõuete järgi:

    - faili lõpus tipptaseme `secrets:` neli kirjet, igaüks `file: ./secrets/<NIMI>`
    - db01: `secrets: [DB_ROOT_PASSWORD, DB_PASSWORD]` ja `environment: !override` ainult `MARIADB_ROOT_PASSWORD_FILE`, `MARIADB_PASSWORD_FILE` (`/run/secrets/…`), `MARIADB_DATABASE`, `MARIADB_USER`
    - app01: `secrets: [DB_PASSWORD, RABBITMQ_PASSWORD, TEACHER_TOKEN]` ja `environment: !override` ainult `SPRING_CONFIG_IMPORT: "optional:configtree:/run/secrets/"` ja `CATALINA_OPTS`
    - [`!override`](https://docs.docker.com/reference/compose-file/merge/) on vajalik: ilma selleta liidetakse mapping'ud ja `MARIADB_PASSWORD` jääb alles

4. Uuenda stacki ja kontrolli.

    ```bash
    docker compose config | grep -E '_FILE|SPRING_CONFIG|PASSWORD:' 
    docker compose up -d --wait && docker compose ps
    docker inspect -f '{{json .Config.Env}}' labori-seis-app01-1 | tr ',' '\n' | grep -iE 'pass|token'
    docker compose exec app01 ls -l /run/secrets; curl -s localhost:8080/health; echo
    ```

> Failid on 644, sest konteiner näeb faili hosti omaniku ja õigustega ja app01 töötab UID 10001-na. Kaitse annab kaust 700: hostis ei pääse teised kasutajad failideni.

Pärast `!override`-i on keskkonnas ainult failide teed ja configtree import. `/health` UP tõestab, et rakendus luges paroolid failidest ja need klappisid volume'i omadega. Kui parool oleks failis reavahetusega, oleks `db` DOWN: `printf '%s'` on seepärast `echo` asemel.

✅ **Edasi saad minna, kui** `git status` ei näita `secrets/`-i, `config` ei näita ühtegi `MARIADB_PASSWORD:` ega `DB_PASSWORD:` rida db01 ja app01 all, `inspect` ei leia app01 keskkonnast parooli ja `/health` on `UP`. Kirjuta TOEND.md-sse, milline teenus hoiab parooli veel keskkonnas ja miks (vt [lehe lõpus](#miks-see-nii-tootab) lõiku "RabbitMQ parool").

## Sisemine võrk ja haldus-UI loopback'il

`--internal` võrku proovisid juba käsitsi. Nüüd jagad stacki kaheks: `front` väljapoole ja `back` ilma väljapääsuta. web01 on mõlemas ja on ainus sild nende vahel.

Kui app01 on kompromiteeritud, ei saa ründaja sealt otse internetti ühendust võtta ega tööriistu alla laadida. Halduse UI, mis on nähtav kogu VPN-ile, on parooli ära arvamise sihtmärk; loopback'il näeb seda ainult SSH-ga sisse loginud admin.

1. Lisa `compose.prod.yaml`-i tipptasemele võrgud `front: {}` ja `back: {internal: true}` ning igale teenusele `networks` tabeli L3.5 järgi.
2. rmq01 halduse UI ainult loopback'ile: `ports: !override` ühe reaga `"127.0.0.1:15672:15672"`. Avaldatud port vajab mitte-sisemist võrku, seepärast on rmq01 ka `front`-is.
3. Uuenda stacki ja kontrolli võrke, väljapääsu ja porte.

    ```bash
    docker compose up -d --wait && docker compose ps
    docker network inspect -f '{{.Name}} {{.Internal}}' labori-seis_back labori-seis_front
    docker compose exec app01 curl -sS -m 5 https://example.com -o /dev/null; echo "app01 kood $?"
    docker compose exec web01 wget -q -T 5 -O /dev/null http://example.com; echo "web01 kood $?"
    sudo ss -tlnp | grep -E ':(8080|15672) '
    ```

4. Ava sülearvutist SSH tunnel ja brauseris `http://localhost:15672`.

    ```bash
    ssh -L 15672:127.0.0.1:15672 <kasutaja>@<control node IP>
    ```

5. Kontrolli stacki seestpoolt: `docker run --rm --network labori-seis_back labseis-kontroll:test; echo`.

app01 kood ≠ 0 ja web01 kood 0 tähendavad, et segmenteerimine töötab mõlemas suunas õigesti. `ss` näitab, et 15672 kuulab ainult loopback'il: VPN-is olev kolleeg ei näe halduse UI-d enam. Kontroll-image `back`-võrgust tõestab, et teenuste vaheline DNS töötab ka sisemises võrgus.

✅ **Edasi saad minna, kui** `back` on `true`, app01 ei jõua internetti (kood ≠ 0), web01 jõuab, 15672 kuulab ainult `127.0.0.1`-l, UI avaneb tunneli kaudu ja kontroll-image annab `back`-võrgust `/health` JSON-i.

## Kirjutuskaitstud konteinerid

Kirjutuskaitstud juurfailisüsteem tähendab, et konteineris ei saa ükski protsess faile muuta väljaspool kaustu, mille sa eraldi lubad. Teed seda kahele teenusele, mis seda kergesti taluvad.

Veebiserveri kompromiteerimise tavaline järgmine samm on veebijuurde faili lisamine või konfiguratsiooni muutmine. `read_only` lõpetab selle failisüsteemi tasandil, sõltumata sellest, mis kasutajana ründaja protsess töötab.

1. Lisa mc01-le `read_only: true`. Lisa web01-le `read_only: true` ja `tmpfs` kaustadele, kuhu nginx kirjutab: `/var/cache/nginx`, `/run`, `/tmp` ja `/etc/nginx/conf.d` (sinna kirjutab entrypoint template'ist `default.conf`-i).
2. Uuenda stacki ja proovi kirjutada.

    ```bash
    docker compose up -d --wait && docker compose ps web01 mc01
    docker compose exec web01 touch /usr/share/nginx/html/x; docker compose exec web01 touch /tmp/x && echo tmp-ok
    docker inspect -f '{{.HostConfig.ReadonlyRootfs}} {{json .HostConfig.Tmpfs}}' labori-seis-web01-1
    curl -s localhost:8080/health; echo
    ```

3. Eemalda ajutiselt `/etc/nginx/conf.d` tmpfs'i nimekirjast, uuenda stacki ja vaata `docker compose logs web01 | head -15` ja `curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/health`. Pane rida tagasi.

`Read-only file system` tuli tuumalt, mitte nginx'ilt. Ilma `conf.d` tmpfs'ita ei saanud entrypoint template'ist konfiguratsiooni kirjutada; see on tüüpiline viga, kui `read_only` lisatakse ilma teenuse kirjutuskohti uurimata.

✅ **Edasi saad minna, kui** `touch` veebijuurde annab `Read-only file system`, `/tmp` on kirjutatav, `ReadonlyRootfs` on `true` ja `/health` on `UP`. Kirjuta TOEND.md-sse, mis juhtus ilma `conf.d` tmpfs'ita ja miks.

## Logid: rotatsioon ja journald

Logidega on kaks küsimust: kui suureks logifail kasvab ja kuhu logid lõpuks jõuavad. Esimene lahendus on daemoni vaikeseade, teine journald draiver ühele teenusele.

`json-file` draiveri vaikeseade on `max-size: -1`: `*-json.log` kasvab piiramatult ja seda ei pööra ka hosti `logrotate`, mis neid faile ei tunne. `daemon.json`-i `log-opts` kehtib ainult pärast seda loodud konteineritele.

1. Pane logide rotatsioon daemoni vaikeseadeks kõigile uutele konteineritele.

    ```bash
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
    jq '. + {"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}' /etc/docker/daemon.json.bak | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker && docker info --format '{{.LoggingDriver}}'
    docker run --rm -d --name logtest alpine:3.22 sleep 30
    docker inspect -f '{{json .HostConfig.LogConfig}}' logtest
    ```

2. Saada app01 logid hosti journal'isse: `compose.prod.yaml`-is app01-le `logging: !override` draiveriga [`journald`](https://docs.docker.com/engine/logging/drivers/journald/) ja valikuga `tag: "labseis/{{.Name}}"`.
3. Uuenda stacki ja loe logi kolmel viisil.

    ```bash
    docker compose up -d --wait app01
    sudo journalctl CONTAINER_NAME=labori-seis-app01-1 -n 5 --no-pager
    sudo journalctl -t labseis/labori-seis-app01-1 -n 200 --no-pager | grep -m1 'Server startup'
    docker compose logs app01 | tail -3
    ```

> Kui `daemon.json` puudub, alusta `echo '{}' | sudo tee /etc/docker/daemon.json`-ist. Vigase JSON-iga Docker ei käivitu: `sudo journalctl -u docker -n 20`.

`logtest` sai rotatsiooniseaded daemonilt, mitte käsurealt. Nüüd on kaitstud ka konteinerid, mida keegi Compose'iga ei käivita. app01 read on journal'is koos hosti teiste logidega ja filtreeritavad konteineri nime või tag'i järgi; logikoguja, mis juba journal'it loeb, saab need kaasa ilma lisaseadistuseta.

✅ **Edasi saad minna, kui** `logtest`-i `LogConfig` näitab `max-size` ja `max-file`, ilma et oleksid neid käsureal andnud, `journalctl` leiab app01 read mõlemal viisil ja `docker compose logs` töötab edasi. Kirjuta TOEND.md-sse, miks `logging` vajab `!override`-i.

## Volume'i varundus ja taastamine

Varundad andmebaasi volume'i abikonteineriga peatatud teenusest ja taastad selle uude volume'isse. Andmebaasis on tulemus, mille lisasid Compose'i stacki kaudu POST-iga, nii et taastamist kontrollid selle reaga.

Volume ilma varukoopiata on ühe `docker compose down -v` kaugusel andmete kaotusest. See käsk on Compose'i veaotsingus soovitatud, ja keegi kasutab seda varem või hiljem valel masinal.

1. Peata andmebaas ja app01, mis sinna kirjutab, arhiveeri volume ja käivita teenused.

    ```bash
    mkdir -p backup && docker compose stop app01 db01
    docker run --rm -v labori-seis_dbdata:/data:ro -v "$PWD/backup:/backup" ubuntu:24.04 \
        tar czf "/backup/dbdata-$(date +%F).tgz" -C /data .
    docker compose start db01 app01; ls -lh backup
    ```

2. Taasta arhiiv uude volume'isse, omanikud numbritena.

    ```bash
    docker volume create dbdata-taaste
    docker run --rm -v dbdata-taaste:/data -v "$PWD/backup:/backup:ro" ubuntu:24.04 \
        tar xzf "/backup/dbdata-$(date +%F).tgz" --numeric-owner -C /data
    docker run --rm -v dbdata-taaste:/data ubuntu:24.04 ls -ln /data | head -4
    ```

3. Käivita taastatud volume'i peal eraldi MariaDB ja küsi oma tulemust.

    ```bash
    docker run -d --name dbtaaste -v dbdata-taaste:/var/lib/mysql mariadb:11.4
    sleep 20; docker exec dbtaaste mariadb -ulabseis -p"$(cat secrets/DB_PASSWORD)" labseis \
        -e "SELECT lab_code, check_name, status FROM result WHERE lab_code='lab-03'"
    docker rm -f dbtaaste && docker volume rm dbdata-taaste
    ```

> Failikoopia on järjepidev ainult peatatud andmebaasist. Ilma katkestuseta varukoopia on `mariadb-dump --single-transaction`, vt [lehe lõpus](#miks-see-nii-tootab) lõiku "Varukoopia ilma katkestuseta".

Taastatud baas näitas sinu tulemust, seega on koopia kasutatav, mitte ainult olemas. Taastamine ei vajanud root-parooli ega init-skripte: andmekataloog oli juba valmis ja entrypoint jättis initsialiseerimise vahele. Seisak kestis `stop`-ist `start`-ini; suurema baasi puhul kasvab see ja siis on õige valik `mariadb-dump`.

✅ **Edasi saad minna, kui** `backup/` all on arhiiv, taastatud failide omanik on `999`, taastatud baas näitab rida `lab-03 compose OK` ja stack on jälle `healthy`. Kirjuta TOEND.md-sse arhiivi suurus ja seisaku pikkus.

## Kettaruum ja koristuspoliitika

Viimaks koristus. Iga build jätab vanad kihid ja cache'i alles ning ketas täitub vaikselt. Kirjutad skripti, mis koristab vanuse järgi ega puuduta kunagi andmeid.

Täis ketas on konteinerihostis üks levinumaid öiseid rikkeid. Vale koristus on veel hullem: `system prune --volumes` kustutab ka peatatud stacki andmebaasi, ja seda ei saa tagasi võtta.

1. Vaata, kus ruum on.

    ```bash
    docker system df
    docker system df -v | grep -A8 'Build cache' | head -10
    docker image ls --filter dangling=true
    ```

2. Kirjuta `k03-docker/prune.sh` nende nõuete järgi:

    - `set -euo pipefail`, võti `-n` näitab ainult, mida koristataks; tundmatu võti annab koodi 2
    - volume'eid ei puuduta kunagi (`docker volume prune` ja `system prune --volumes` puuduvad)
    - koristab peatatud konteinerid vanemad kui 24 h, `<none>` image'id, kasutamata image'id vanemad kui `KEEP_IMAGES` (vaikimisi `168h`) ja build cache'i vanem kui `KEEP_CACHE` (vaikimisi `72h`)
    - `docker system df` enne ja pärast, kokkuvõte `logger -t labseis-prune` kaudu journal'isse

3. Proovi ja kontrolli.

    ```bash
    chmod +x prune.sh && shellcheck -S warning prune.sh
    ./prune.sh -n; ./prune.sh
    docker volume ls | grep labori-seis
    sudo journalctl -t labseis-prune -n 1 --no-pager
    ```

`-n` näitas plaani, mitte tegevust: nii testid koristust tootmises enne tegelikku käivitust. Volume'id jäid alles, kuigi mõni neist pole parasjagu kasutusel. Journal'i rida on jälg, mida saad hiljem vaadata, kui keegi küsib, kuhu image kadus.

✅ **Edasi saad minna, kui** ShellCheck vaikib, `-n` ei muutnud midagi, `RECLAIMABLE` vähenes, `labori-seis_dbdata` ja `labori-seis_rmqdata` on alles ja journal'is on `labseis-prune` rida.

## Tagasi põhistacki peale ja commit

GitHub Actionsi deploy käivitab ainult `compose.yaml`-i. Kui jätad prod-faili peale, loob deploy app01 vaikevõrku ja see ei leia `back`-võrgus olevat andmebaasi. Seepärast valideerid prod-faili ja lähed tagasi põhistacki peale.

```bash
docker compose config -q && echo "prod OK"
unset COMPOSE_FILE && docker compose up -d --wait && docker compose ps
cd .. && bash autograde/check.sh k03 compose && bash autograde/check.sh k03 deps
git add k03-docker/compose.prod.yaml k03-docker/.gitignore k03-docker/prune.sh k03-docker/TOEND.md
git commit -m "K3.5 tootmiskiht: piirangud, saladused, võrgud, read_only, logid, prune (closes #N)" && git push
```

Prod-fail on Gitis ja valideerub, aga töötab ainult siis, kui keegi selle teadlikult peale paneb. Nii jääb `compose.yaml` kõigile ühiseks aluseks ja tootmise erisused on ühes failis üle vaadatavad.

✅ **Edasi saad minna, kui** viis teenust on põhistackiga `healthy`, `compose` ja `deps` annavad `OK` ja `git ls-files k03-docker | grep -E 'secrets|backup'` on tühi.

📎 **Selle mooduli tõend:** commit `K3.5 …`; TOEND.md-s `docker stats` piirid, PID-piiri katse, `inspect` enne ja pärast saladusi, võrgutesti koodid, `read_only` katse, journald'i rida, varukoopia suurus ja taastatud rida ning `prune.sh` kokkuvõte.

## Miks see nii töötab

**RabbitMQ parool.** Selles praktikumis kasutatav image `rabbitmq:4.1-management-alpine` ei toeta muutujat `RABBITMQ_DEFAULT_PASS_FILE`. Seetõttu jääb rmq01 parool failis `compose.prod.yaml` keskkonnamuutujasse. See on selle image'i piirang. Parooli kasutatakse ainult esimesel käivitusel tühja andmekataloogiga. Parooli saab anda failist, kui mount'id saladuse failina `/etc/rabbitmq/conf.d/20-labseis.conf` ridadega `default_user = labseis` ja `default_pass = …`. See näitab, miks "kasuta alati `_FILE`-muutujat" ei ole universaalne reegel: image'i ametlik entrypoint määrab, milliseid saladuse edastamise viise teenus tegelikult toetab.

**Spring Boot'i configtree.** Spring Boot'i configtree loeb kaustast `/run/secrets/` iga faili konfiguratsiooniomaduseks, mille nimi on failinimi. Rakenduse `application.properties` viitab `${DB_PASSWORD}`-ile ja rakendus saab väärtuse failist kätte samamoodi nagu keskkonnamuutujast.

**Avaldatud port ja `internal` võrk.** `internal: true` võrgul pole ühendust hostist väljapoole, seetõttu ei seo Docker sellise võrgu kaudu konteineri porti hosti pordiga. Avaldatud port (`ports`) vajab vähemalt ühte võrku, mis pole `internal`. Seepärast on rmq01 lisaks `back`-võrgule ka `front`-võrgus: haldusliidese port `127.0.0.1:15672` seotakse hostiga `front`-võrgu kaudu.

**Docker ja hosti tulemüür.** Docker lisab avaldatud portidele oma NAT-reeglid (iptables või nftables). Kas UFW või firewalld neid porte piirab, sõltub tulemüüri taustaprogrammist ja Dockeri versioonist; tavapärase UFW seadistusega jõuab liiklus avaldatud pordini UFW reeglitest mööda. Seetõttu kontrolli pordi ligipääsetavust eraldi, näiteks teisest masinast käsuga `nc -zv <host> 8080`. Kui porti pole väljast vaja, seo see aadressiga (`127.0.0.1:8080:80`), selle asemel et loota hosti tulemüürile.

**PID-piir.** PID-piir on cgroup'i `pids.max`. Linuxi protsesside arvestuses kuuluvad lõimed samasse piirangusse, sest tuum loeb iga lõime eraldi ülesandeks. Java teenusele, millel on sadu lõimi, tuleb piir seetõttu seada suuremaks kui nginx'ile.

**`read_only` ja `tmpfs`.** Võtmega `read_only` on konteineri juurfailisüsteem kirjutuskaitstud ja ajutised kirjutuskohad (näiteks `/tmp` või nginx'i vahemälukataloog) tuleb määrata `tmpfs`-ina. `tmpfs` asub mälus ja tühjeneb konteineri peatamisel, seetõttu ei jää ükski muudatus väljaspool volume'eid alles.

**Saladusefailide piir.** Saladusefailid ei kaitse kõige eest. Hosti root ja iga grupi `docker` liige loevad neid ikkagi, kas hostist või `docker exec`-iga. Need kaitsevad juhuslike lekete eest logis, veateates, `inspect`-i väljundis ja ekraanipildil, mis on intsidentides sagedased lekkekohad.

**Varukoopia ilma katkestuseta.** Loogiline koopia loeb andmed andmebaasi enda kaudu.

`mariadb-dump --single-transaction` loeb InnoDB tabelid ühest tehingust ega vaja seisakut. Koopia on SQL-tekst: taastamine on aeglasem kui failide lahtipakkimine, aga see ei sõltu MariaDB versioonist.

```bash
docker compose exec -T db01 sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --single-transaction labseis' | gzip > backup/labseis.sql.gz
docker run -d --name dbt -e MARIADB_ROOT_PASSWORD=x -e MARIADB_DATABASE=labseis mariadb:11.4
sleep 20; gunzip -c backup/labseis.sql.gz | docker exec -i dbt mariadb -uroot -px labseis
docker exec dbt mariadb -uroot -px labseis -e "SELECT COUNT(*) FROM result"; docker rm -f dbt
```

Prod-failiga on root-parool failis `/run/secrets/DB_ROOT_PASSWORD`, siis on käsus `-p"$(cat /run/secrets/DB_ROOT_PASSWORD)"`. Parool `-p` järel on konteineri protsessinimekirjas nähtav; `--defaults-extra-file` failiga väldib seda.

Konteineri-spetsiifiline vahe on selles, kust käsk käivitub: `docker compose exec` töötab db01 sees, nii et dump'i tööriist ja serveri versioon on alati samast image'ist. Ilma seisakuta füüsilise koopia annab `mariadb-backup`, mis on samuti MariaDB image'is olemas.

Kui jõudsid kiiremini: [Lisaülesanded → 8. Linuxi capability'd maha](lisa.md#8-linuxi-capabilityd-maha), võtad mc01-lt ja web01-lt Linuxi capability'd maha ja lisad tagasi ainult need, ilma milleta nginx ei käivitu.
