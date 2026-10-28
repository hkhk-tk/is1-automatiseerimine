---
tags:
  - Docker
  - Dockerfile
  - nginx
---

# 2. db ja web image

Oma Dockerfile, mis kordab ametliku image'i entrypoint'i tööd, jääb baasimage'i turvaparandustest maha ja läheb katki esimesel suuremal uuendusel. db01 ja web01 ehituvad sinu Dockerfile'idest ametlike image'ite peale. Kõigepealt vaatad, mida ametlik image juba teeb, ja kirjutad ainult puuduva osa: nii jääb Dockerfile lühikeseks ja baasimage'i uuendus toob parandused kaasa ilma, et peaksid oma faili muutma. db ja app vajavad repo faile, seega on nende ehituskontekst **repo juur**; web'i kontekst on tema oma kaust. Lõpus on ehituskontekst `.dockerignore`-iga väike ja saladustest puhas.

**Kui teed seda tööl iga päev:** `docker build --check` sinu db- ja web-Dockerfile'ile ei anna hoiatusi ja tead, millal MariaDB image'i init-skriptid käivituvad. Kui see on sul juba korras, kirjuta mõlemad Dockerfile'id ise ja mine otse etappi „[Init-skripti lõks](#init-skripti-loks)“.

Allolev puu näitab, kuhu iga fail läheb ja millal see tekib. Rakenduse failid repo juures jäävad puutumata: Dockerfile'id ainult loevad neid.

```text
<sinu repo>/
├── .dockerignore                      ← siin
├── pom.xml  src/  db/                 ← rakendus, ei muuda
└── k03-docker/
    ├── db/Dockerfile                  ← siin
    ├── web/Dockerfile  web/nginx.conf ← siin
    ├── app/Dockerfile  kontroll/      ← App image
    └── compose.yaml  .env.example     ← Compose
```

## Mis on ametliku image'i sees

Ametlik image on kellegi teise tehtud töö: entrypoint, vaikekasutaja, avatud pordid ja volume'id. Need on image'i metaandmetes ja `docker image inspect` näitab neid ilma konteinerit käivitamata. Enne oma Dockerfile'i vaata, mida baasimage juba teeb.

Kui sa ei tea, et MariaDB image kuulutab `/var/lib/mysql` volume'iks, tekib iga testkonteineriga hosti uus nimeta volume. Need kasvavad `/var/lib/docker/volumes` all ja keegi ei tea, kellele need kuuluvad.

```bash
docker image inspect mariadb:11.4 --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}'
docker image inspect mariadb:11.4 --format '{{json .Config.Volumes}} {{json .Config.ExposedPorts}} {{.Config.User}}'
docker image inspect nginx:1.30-alpine --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}'
docker run --rm --entrypoint ls nginx:1.30-alpine /docker-entrypoint.d
```

Tühi `User` tähendab, et image käivitub root'ina ja entrypoint vahetab kasutaja ise, kui ettevalmistus on tehtud. `Volumes` väljal olev kataloog saab iga konteineriga anonüümse volume'i, kui sa ise nime ei anna. nginx'i kaust `/docker-entrypoint.d` on hook: iga sinna pandud skript käivitub enne nginx'it.

✅ **Edasi saad minna, kui** tead, et MariaDB ENTRYPOINT on skript, mis initsialiseerib tühja `/var/lib/mysql` ja loeb kausta `/docker-entrypoint-initdb.d/`, ning et nginx'i entrypoint käivitab enne nginx'it skriptid kaustast `/docker-entrypoint.d/`, sh `20-envsubst-on-templates.sh`, mis teeb template'ist lõpliku konfi.

## db/Dockerfile

Andmebaasi image on ametlik MariaDB pluss Labori seisu skeem ja näidisandmed. Ise kirjutad ainult kopeerimise; initsialiseerimise teeb entrypoint. Kui skeem on image'is, on andmebaasi struktuur versioonitud koos rakendusega ja iga uus keskkond saab sama alguse.

Kirjuta `k03-docker/db/Dockerfile` ([juhiste viide](https://docs.docker.com/reference/dockerfile/)), kokku kolm rida:

- baas `mariadb:11.4`
- `db/schema.sql` ja `db/seed.sql` lähevad kausta `/docker-entrypoint-initdb.d/` nii, et skeem käivitub enne andmeid (failid käivitatakse tähestiku järjekorras)
- `COPY`, mitte `ADD`: `ADD` pakib arhiive lahti ja laeb URL-ilt, mida siin vaja pole

Ehita ja kontrolli:

```bash
docker build -f k03-docker/db/Dockerfile -t labseis-db:test .
docker run -d --name dbt -e MARIADB_ROOT_PASSWORD=x -e MARIADB_DATABASE=labseis labseis-db:test
sleep 20; docker exec dbt mariadb -uroot -px labseis -e "SHOW TABLES;"
```

> `"/db/schema.sql": not found` tähendab, et kontekst pole repo juur: viimane argument `.` peab olema repo juur.

Neli tabelit tähendab, et mõlemad SQL-failid käivitusid ja õiges järjekorras: seed kirjutab tabelitesse, mille skeem lõi. Vale järjekorraga lõpetaks konteiner esimesel käivitusel veaga `Table doesn't exist`. Volume jääks siis pooleldi initsialiseerituks ja järgmine käivitus jätaks init-skriptid vahele.

✅ **Edasi saad minna, kui** `SHOW TABLES` näitab nelja tabelit: course, lab, result, student.

## Init-skripti lõks

Init-skriptid käivituvad ainult tühja andmekataloogiga. Tõestad selle ise: muudad seed-faili, ehitad image'i uuesti ja vaatad, kas muudatus jõuab baasi. Kas jõuab, sõltub ainult sellest, kas volume on tühi.

Tootmises tähendab see, et skeemi muudatus ei saa tugineda init-skriptile. Olemasolev baas vajab migratsiooni (Flyway, Liquibase või käsitsi SQL), mitte uut image'it.

1. Lisa `db/seed.sql` lõppu ajutiselt rida, mis lisab kursuse `('TEST', 'proov')` tabelisse `course` (vaata faili algusest, kuidas teised read on kirjutatud).
2. Ehita image uuesti ja käivita `dbt` uue volume'iga, siis kontrolli rida.

    ```bash
    docker rm -f dbt
    docker build -q -f k03-docker/db/Dockerfile -t labseis-db:test .
    docker run -d --name dbt -v dbt:/var/lib/mysql -e MARIADB_ROOT_PASSWORD=x -e MARIADB_DATABASE=labseis labseis-db:test
    sleep 20; docker exec dbt mariadb -uroot -px labseis -e "SELECT * FROM course"
    ```

3. Muuda lisatud rida (`'TEST2'`), ehita uuesti ja käivita `dbt` **sama volume'iga** `dbt`. Kontrolli sama päringuga.
4. Võta muudatus tagasi ja korista.

    ```bash
    git restore db/seed.sql
    docker rm -f dbt && docker volume rm dbt
    ```

Teine käivitus leidis volume'ist valmis andmekataloogi ja jättis kogu `/docker-entrypoint-initdb.d/` vahele. Image oli uus, andmed vanad. Sama juhtub parooliga: muudetud `MARIADB_PASSWORD` ei muuda olemasoleva kasutaja parooli, ja see on Compose'i stacki juures kõige sagedasem `Access denied` põhjus.

✅ **Edasi saad minna, kui** esimesel käivitusel oli `TEST` tabelis ja teisel `TEST2` ei olnud. Kirjuta TOEND.md-sse üks lause: millal init-skriptid käivituvad ja mida teed, kui skeem muutub.

## web/Dockerfile ja nginx'i template

web01 on app01 ees pöördproksi. nginx lahendab `upstream` nime ainult käivitusel; kui app01 konteiner luuakse uuesti uue IP-ga, vastab web01 502-ga. [Ametlik nginx-image](https://hub.docker.com/_/nginx) oskab konfifaili template'ist teha ja konteineri DNS-serveri sinna kirjutada.

GitHub Actionsi pipeline uuendab app01 iga commit'iga, nii et see juhtuks iga päev.

Kirjuta `k03-docker/web/nginx.conf` ja `k03-docker/web/Dockerfile` nende nõuete järgi:

- üks `server`-plokk pordil 80, `location /` suunab `http://app01:8080` poole ja edastab päised `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`
- faili algus `resolver ${NGINX_LOCAL_RESOLVERS} valid=10s ipv6=off;`, `server`-plokis `set $app_upstream http://app01:8080;` ja `proxy_pass $app_upstream;`
- Dockerfile: `nginx:1.30-alpine`, konfifail kopeeritakse `/etc/nginx/templates/default.conf.template`, `ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1`
- `HEALTHCHECK`, mis küsib `wget`-iga `http://127.0.0.1/health` (alpine'is curl'i pole)

```bash
docker build -t labseis-web:test k03-docker/web
docker run --rm labseis-web:test nginx -T 2>/dev/null | grep -E 'resolver|proxy_pass'
```

> Kui näed `${NGINX_LOCAL_RESOLVERS}` muutmata kujul, jäi ENV puudu või fail pole `templates/` all.

`nginx -T` näitab lõplikku konfi, mille entrypoint template'ist tegi. IP-aadress `resolver` real tähendab, et envsubst sai muutuja kätte. `proxy_pass $app_upstream` alles tähendab, et nginx lahendab nime iga päringu ajal resolver'i kaudu, mitte ainult käivitusel.

✅ **Edasi saad minna, kui** `resolver` real on päris IP-aadress ja `proxy_pass $app_upstream;` on alles. Kirjuta TOEND.md-sse, miks `$host` ja `$app_upstream` jäid envsubst'ist puutumata, aga `${NGINX_LOCAL_RESOLVERS}` asendati.

## Mis juhtub, kui app01 puudub

Sinu web-image peab käivituma ka siis, kui app01 veel pole. Proovid seda testvõrgus ilma app01-ta ja võrdled tavalise staatilise `proxy_pass`-iga, mida enamik veebinäiteid kasutab.

Staatilise upstream'iga nginx keeldub käivitumast, kui nimi ei lahendu. Compose'is tähendaks see, et web01 ebaõnnestub iga kord, kui app01 on alles käivitumas, ja restart-poliitika taaskäivitab teda tsüklis.

1. Käivita oma web-image võrgus, kus app01 pole, ja küsi temalt avalehte.

    ```bash
    docker network create k03web
    docker run -d --name webt --network k03web labseis-web:test
    sleep 3; docker exec webt wget -qO- -T 3 http://127.0.0.1/; echo "kood $?"
    docker logs webt 2>&1 | grep -m1 'could not be resolved'
    ```

2. Proovi sama staatilise `proxy_pass`-iga ametlikus image'is.

    ```bash
    docker run --rm --network k03web nginx:1.30-alpine sh -c \
      'echo "server { listen 80; location / { proxy_pass http://app01:8080; } }" > /etc/nginx/conf.d/default.conf && nginx -t'
    docker rm -f webt && docker network rm k03web
    ```

Sinu image käivitus ja vastas 502-ga: konf on korras, puudu on ainult backend, ja seda ütleb ka logi. Staatiline variant ei jõudnud kuulamiseni, `nginx -t` peatus juba nime peal. 502 tähendab "nginx töötab, upstream ei vasta", `Exited (1)` tähendab "konf ei lähe läbi".

✅ **Edasi saad minna, kui** `webt` oli `Up` ja `wget` sai 502 (kood ≠ 0), logis oli `could not be resolved`, staatiline konf andis `host not found in upstream` ning testkonteiner ja võrk on kustutatud.

## .dockerignore

Ehituskontekst on kõik, mis saadetakse builderile enne esimest juhist. Docker ei vaata, mida Dockerfile tegelikult kasutab. Kõik, mis on kontekstis, võib `COPY . .` abil image'isse jõuda, sh `.env` paroolidega ja OpenTofu `tfstate`.

Saladus image'is jõuab igasse koopiasse: registry'sse, iga node'i kettale ja igaühele, kes image'i tõmbab. Kustutamine hilisemas kihis ei aita, sest varasem kiht on alles.

1. Mõõda praegust ehituskonteksti.

    ```bash
    docker build --no-cache -f k03-docker/db/Dockerfile . 2>&1 | grep -i 'transferring context'
    ```

2. Loo repo juurde [`.dockerignore`](https://docs.docker.com/build/concepts/context/) allowlist'ina: esimene rida `*`, siis `!` ridadega tagasi ainult see, mida Dockerfile'id kopeerivad (`pom.xml`, `src`, `db`).
3. Mõõda uuesti ja ehita db-image.

    ```bash
    docker build --no-cache -f k03-docker/db/Dockerfile . 2>&1 | grep -i 'transferring context'
    bash autograde/check.sh k03 files
    ```

Väiksem kontekst tähendab kiiremat build'i, aga peamine võit on turvalisus. Allowlist'iga ei jõua uus fail image'isse enne, kui sa selle ise lubad. Denylist'i (`.env`, `.git`) tuleb iga uue saladusefailiga täiendada, ja see ununeb.

✅ **Edasi saad minna, kui** kontekst langes MB-delt mõnesaja KB-ni, db-image ehitub endiselt ja `k03 files` annab `OK` või kurdab ainult app-image'i ja Compose'i failide üle, mida sul veel pole.

## Commit

```bash
git add .dockerignore k03-docker/db k03-docker/web k03-docker/TOEND.md
git commit -m "K3.2 db ja web Dockerfile, .dockerignore (closes #N)" && git push -u origin k03-docker
```

`git ls-files` näitab, mida automaatne hindaja näeb. Fail, mis on töökaustas, aga mitte Gitis, puudub ka GitHubi build'is, ja see viga tuleb välja alles esitamisel.

✅ **Edasi saad minna, kui** `git status` on puhas ja `git ls-files k03-docker` näitab kolme uut faili.

📎 **Selle mooduli tõend:** commit `K3.2 …`; TOEND.md-s init-lõksu lause, envsubst'i selgitus, 502 ja `host not found` võrdlus ning konteksti suurus enne ja pärast.

## Miks see nii töötab

**MariaDB init-skriptid.** MariaDB image'i entrypoint-skript `docker-entrypoint.sh` algseadistab tühja andmekataloogi ja käivitab seejärel kaustas `/docker-entrypoint-initdb.d/` olevad failid tähestikulises järjekorras. Kui andmekataloogis on juba andmebaas, jäetakse need skriptid vahele. See on teadlik disain: image ei tea, kas olemasolevas baasis on tootmisandmed, ega riski nende ülekirjutamisega.

**Skeemi muudatus.** Kui algskript ebaõnnestub poole käivituse pealt, võib andmekataloog jääda osaliselt algseadistatuks ja järgmine käivitus peab seda valmis baasiks. Ära kustuta volume'it enne, kui oled veendunud, et selle andmed võib kaotada või need on varundatud. Laboris saab vajaduse korral andmekataloogi uuesti luua; tootmisbaasis tuleb olukord enne parandada või varukoopiast taastada.

**nginx'i template'id.** Ametlik nginx'i image genereerib kaustas `/etc/nginx/templates/` olevatest `*.template` failidest `envsubst`'iga konfiguratsioonifailid. `envsubst` asendab ainult keskkonnas defineeritud muutujad, seetõttu jäävad nginx'i enda muutujad `$host` ja `$app_upstream` puutumata.

**Resolver ja muutuja `proxy_pass`-is.** `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` salvestab muutujasse `NGINX_LOCAL_RESOLVERS` konteineri `/etc/resolv.conf`-is oleva DNS-serveri aadressi, Dockeri kasutaja loodud võrgus `127.0.0.11`. Millal nginx nime lahendab, sõltub sellest, kuidas `proxy_pass` on kirjutatud:

- `proxy_pass http://app01:8080;` lahendab nime `app01` ainult nginx'i käivitamisel. Kui app01 konteinerit sel hetkel pole, keeldub nginx käivitumast (`host not found in upstream`).
- `set $app_upstream http://app01:8080;` ja `proxy_pass $app_upstream;` lahendab nime iga päringu ajal `resolver`-real määratud DNS-serverist. nginx käivitub ka ilma app01-ta ja vastab 502-ga, kuni app01 on üleval; kui app01 saab uue IP-aadressi, leiab nginx selle ise.

**`.dockerignore` allowlist'ina.** `.dockerignore` reeglid loetakse ülevalt alla ja hilisem reegel kirjutab varasema üle. Allowlist algab reaga `*`, mis jätab ehituskontekstist välja kõik, ja `!`-ga algavad read toovad tagasi ainult selle, mida Dockerfile'id kopeerivad (`!pom.xml`, `!src`, `!db`).

Kui jõudsid kiiremini: [Lisaülesanded → 5. Skeemi muudatus olemasolevas baasis](lisa.md#5-skeemi-muudatus-olemasolevas-baasis), kirjutad korduvalt käivitatava migratsiooni, mis muudab töötava baasi skeemi ilma volume'it kustutamata.
