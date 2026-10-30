---
tags:
  - Docker
  - Compose
  - veaotsing
---

# 8. Kolm riket

Kaskaadis kaotab kõige rohkem aega see, kes parandab esimest nähtud sümptomit: `dependency failed to start` ütleb, et midagi ahelas on katki, aga mitte, mis. Failis `k03-docker/intsident/compose.yaml` on sama Labori seis eraldi projektina `labori-seis-intsident` pordil 8090, sinu image'itega, ja selles on kolm viga eri kohtades. Liigu väljast sisse nagu tootmisintsidendis: sümptomist põhjuseni, parandus failis, mitte töötavas konteineris, ja uuesti luuakse ainult need teenused, mida parandus puudutab. Kiirus pole eesmärk, iga järeldus peab põhinema käsu väljundil, mitte oletusel. Lõpuks on kolm parandust koodis ja tõend, et need peavad vastu ka uuel masinal ja daemoni restardil.

**Kui teed seda tööl iga päev:** Compose'i stacki veaotsingu alustad `docker compose ps -a` ja `docker inspect -f '{{json .State.Health}}'`-iga ning tead, mida `depends_on` daemoni restardil ei tee. Kui see on sul juba korras, paranda kolm riket ilma tabelita ja mine otse etappi „[Hoolduse järgne taaskäivitus: stack käivitub ise](#hoolduse-jargne-taaskaivitus-stack-kaivitub-ise)“.

Veaotsingu tabelit L3.7 loe ülevalt alla: esimene rida on kõige laiem sümptom, iga järgmine kitsendab otsingu ühe teenuse ja ühe põhjuseni.

| Sümptom | Vaata esimesena | Tõenäoline koht |
|---|---|---|
| `up` lõpeb `dependency failed to start` | `docker compose ps -a`: kes on `Exited`, kes `unhealthy` | sõltuvus, mitte app01 ise |
| teenus `Exited (1)` kohe pärast starti | `docker compose logs <teenus> \| tail -20` | andmekataloog, õigused, kasutaja |
| teenus `unhealthy`, aga protsess töötab | `docker inspect -f '{{json .State.Health}}' <konteiner> \| jq` | healthcheck'i käsk, port |
| web01 `unhealthy`, `curl` annab 502 | `docker compose exec web01 nslookup app01` | võrgud: kes on millises võrgus |
| kõik `healthy`, aga `/health` ütleb `DOWN` | `docker compose exec app01 curl -s localhost:8080/health` | parool või volume, mis initsialiseeriti varem |

*Tabel L3.7. Veaotsingu tabel.*

## Algseis

Kahe stacki jaoks pole control node'is mälu. Peata põhistack (volume'id jäävad alles) ja käivita intsidendistack. Salvestad esimese `up`-i väljundi, sest see on intsidendi algne sümptom ja kokkuvõttes viitad sellele.

Kahe stacki samaaegne käivitamine 4 GB masinas annab OOM-kille, mis näevad välja nagu intsidendi vead, aga ei ole. Siis parandaksid asja, mis polnud katki.

1. Peata põhistack ja vaata, et intsidendifail on olemas ja valideerub.

    ```bash
    cd ~/<sinu repo>/k03-docker && docker compose down
    git log --oneline -1 -- intsident/compose.yaml
    docker compose -f intsident/compose.yaml --env-file .env config -q && echo OK
    ```

2. Tee kogu ülesande ajaks lühike käsk, käivita stack ja salvesta väljund.

    ```bash
    alias dci='docker compose -f intsident/compose.yaml --env-file .env'
    dci up -d 2>&1 | tee intsident/up-1.log
    dci ps -a
    ```

> Projekti nimi `labori-seis-intsident` hoiab konteinerid, võrgud ja volume'id põhistackist eraldi: `docker volume ls` näitab mõlema projekti omi.

`dependency failed to start` ütleb ainult, et keegi ahelas ei jõudnud `healthy` olekusse. Kaskaad peidab algpõhjuse: teenused, kes ootavad, ei käivitunudki ja nende logid on tühjad. Alusta sellest, kes on `Exited` või `unhealthy`, mitte sellest, kes on ahela lõpus.

**Edasi saad minna, kui** `up` lõppes veaga `dependency failed to start`, `up-1.log` on salvestatud ja tead, millised teenused on `Exited` ja millised `unhealthy`.

## Andmebaas ei käivitu

db01 lõpetab kohe pärast starti. Alusta temast, sest kõik teised ootavad teda. Leia põhjus ja paranda see failis `intsident/compose.yaml`.

1. Vaata väljumiskoodi, logi ja seda, mis on konteineri andmekataloogis.

    ```bash
    dci ps -a db01; dci logs db01 | tail -10
    docker inspect -f '{{.Config.User}} {{json .Mounts}}' labori-seis-intsident-db01-1 | jq .
    ls -ln intsident/data
    ```

2. Võrdle, mis kasutajana MariaDB töötab ja kellele kuulub kataloog, kuhu ta kirjutab. Kes selle kataloogi lõi?
3. Paranda põhjus failis. `user: "999:999"` jääb alles: andmebaas ei tohi töötada root'ina. Lahendus ei tohi nõuda käsitsi `chown`-i igal uuel masinal.
4. Loo uuesti ainult db01: `dci up -d --wait db01`

Hea parandus töötab ka uuel masinal, kus keegi pole midagi käsitsi ette valmistanud. Kui sinu parandus vajab enne `up`-i mõnda käsku, mida failis pole, on see ajutine lahendus, mitte parandus.

**Edasi saad minna, kui** db01 on `(healthy)` ja `dci exec db01 id` näitab `uid=999`. Esita see commit'ina `fix(intsident): db01 …`, sõnumis põhjus.

## Vahemälu on unhealthy

Teine viga on mujal. mc01 protsess töötab, aga Docker peab teda haigeks ja app01 ei käivitu tema pärast.

1. Vaata healthcheck'i ajalugu ja seda, kus memcached tegelikult kuulab.

    ```bash
    docker inspect -f '{{json .State.Health}}' labori-seis-intsident-mc01-1 | jq '.Status, .Log[-1]'
    dci exec mc01 sh -c 'netstat -tln 2>/dev/null || cat /proc/net/tcp'
    dci exec mc01 sh -c 'echo stats | nc -w 1 127.0.0.1 11211 | head -2'
    ```

2. Paranda põhjus failis ja loo uuesti ainult mc01: `dci up -d --wait mc01`

Healthcheck on kood nagu iga teine. Kui see kontrollib vale asja, annab ta vale vastuse, ja iga `depends_on` sõltuvus usaldab seda vastust. Teenuse enda logis pole siin midagi: viga on selles, kuidas teda väljast vaadatakse.

**Edasi saad minna, kui** mc01 on `(healthy)` ja `dci up -d --wait app01` jõuab app01 `(healthy)` olekusse. Esita see commit'ina `fix(intsident): mc01 …`.

## web01 annab 502

Kolmas viga ei ole üheski konteineris eraldi. app01 on `healthy`, web01 töötab, aga web01 on `unhealthy` ja `curl -s -o /dev/null -w '%{http_code}\n' localhost:8090/` annab 502.

1. Vaata, kas web01 leiab app01 ja millistes võrkudes kumbki on.

    ```bash
    dci exec web01 nslookup app01
    dci logs web01 | grep -m3 -iE 'resolve|upstream|error'
    docker network ls --filter name=labori-seis-intsident
    docker network inspect -f '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}' labori-seis-intsident_front labori-seis-intsident_back
    ```

2. Paranda põhjus failis nii, et app01 jääb sisemisse võrku ja ainult web01 on väljast nähtav.
3. Loo uuesti ainult web01: `dci up -d --wait web01`

Parandus peab hoidma `front`- ja `back`-võrgu jaotuse. Lahendus, mis paneb kõik teenused ühte võrku, töötab samuti, aga avab app01 ja andmebaasi väljapääsu ning see oleks uus viga vana asemel.

**Edasi saad minna, kui** web01 on `(healthy)` ja `curl -s localhost:8090/health` annab `"status":"UP"`. Esita see commit'ina `fix(intsident): web01 …`.

## Hoolduse järgne taaskäivitus: stack käivitub ise

Kolm riket on parandatud, aga stack töötab ainult seni, kuni keegi daemonit ei puutu. Hooldusaknas taaskäivitatakse Docker või kogu VM. Kontrolli, kas intsidendistack tuleb sellest tagasi ilma sinu käeta. Samal ajal peab hoolduseks käsitsi peatatud teenus jääma seisma.

`live-restore` on vaikimisi välja lülitatud, nii et `systemctl restart docker` peatab kõik hosti konteinerid. Taaskäivitamisel ei arvesta `dockerd` `depends_on`-i: see kehtib ainult `docker compose up`-i ajal. Konteinerid käivituvad seega korraga ja suvalises järjekorras.

1. Peata mc01, nagu hoolduseks, ja taaskäivita daemon. Pärast seda ära anna ühtegi `dci` käsku peale `ps`-i.

    ```bash
    dci stop mc01 && sudo systemctl restart docker
    sleep 120; dci ps -a --format '{{.Service}} {{.Status}}'
    curl -s -w ' HTTP %{http_code}\n' localhost:8090/health
    ```

2. Paranda fail nende nõuete järgi:
    - pärast daemoni restarti on db01, rmq01, app01 ja web01 `healthy` 120 s jooksul ilma käsitsi sekkumiseta;
    - käsitsi peatatud mc01 jääb `Exited` olekusse;
    - app01 ja web01 taluvad seda, et sõltuvus käivitub neist hiljem: kumbagi ei tohi käsitsi taaskäivitada;
    - nõue on kirjas ühes kohas, mitte viie teenuse juures eraldi.
3. Uuenda stacki (`dci up -d --wait`), korda sammu 1 käske ja lõpuks käivita mc01: `dci start mc01`.

Kui stack ei käivitunud, vaata enne faili muutmist iga konteineri poliitikat: `docker inspect -f '{{.Name}} {{.HostConfig.RestartPolicy.Name}}' $(dci ps -aq)`. Kui mc01 käivitus koos teistega, on poliitika vale. Kui app01 oli `Up`, aga `unhealthy` ka siis, kui db01 oli juba `healthy`, on viga rakenduses: see ei talu sõltuvuse puudumist.

**Edasi saad minna, kui** teine restart andis 120 s pärast neli `healthy` teenust ja mc01 olekuga `Exited`, `/health` pordil 8090 andis HTTP 200 ja `"cache":"DOWN"` ning pärast `dci start mc01` `"cache":"UP"`. Esita see commit'ina `fix(intsident): restart-poliitika …` ja kirjuta sõnumisse, miks valisid just selle poliitika.

## Stack nullist

Viimane kontroll kustutab konteinerid ja käivitab stacki nullist. Kui stack käivitub ilma sinu sekkumiseta, on parandused failis, mitte töötavates konteinerites.

```bash
dci down && dci up -d --wait
dci ps --format '{{.Service}} {{.Status}}'
curl -s localhost:8090/health; echo
git log --oneline -4 -- intsident/compose.yaml
```

Lõpus korista intsidendistack ja käivita põhistack tagasi. `down -v` ja `rm -rf` kustutavad intsidendistacki andmed, mis loodi ainult rikete jaoks.

```bash
dci down -v && sudo rm -rf intsident/data
docker compose up -d --wait && curl -s localhost:8080/health; echo
```

Neli commit'i nelja põhjusega on intsidendi ajalugu, mida järgmine admin saab lugeda ilma sinult küsimata. `down -v` ja uus `up` tõestasid, et ükski parandus ei sõltunud varem loodud volume'ist ega kaustast.

**Edasi saad minna, kui** pärast `down` ja `up` on viis teenust `healthy` ilma käsitsi sekkumiseta, `/health` pordil 8090 on `UP`, Gitis on neli `fix(intsident)` commit'i ja põhistack on jälle üleval.

## Intsidendi kokkuvõte

Kokkuvõte vastab küsimusele, miks `docker compose config -q` kõik kolm viga läbi laskis ja milline kontroll oleks iga vea leidnud enne `up`-i.

Kirjuta TOEND.md-sse jaotis `## Intsident` nende nõuete järgi:

- tabel kolme reaga: sümptom, käsk, mis põhjuse näitas, põhjus, parandus
- iga rikke koht (andmed, healthcheck, võrk) ja järjekord, milles rikked nähtavaks said
- üks lõik: kuidas üks viga peitis teisi ja miks app01 ning web01 logid alguses midagi ei näidanud
- iga rikke kohta üks kontroll, mis oleks selle leidnud enne `up`-i (staatiline kontroll, test või monitooring)

```bash
grep -A25 '^## Intsident' TOEND.md | head -30
```

Kui iga rikke juures on kontroll, mis oleks selle varem leidnud, on sul GitHub Actionsi pipeline'i jaoks kolm testi ideed.

**Edasi saad minna, kui** jaotises `## Intsident` on tabel, rikete kohad ja järjekord, kaskaadi lõik ning iga rikke kohta üks ennetav kontroll.

**Selle osa tõend:** neli commit'i `fix(intsident): …` põhjusega sõnumis (kolm riket ja restart-poliitika); `intsident/up-1.log`; TOEND.md-s jaotis `## Intsident` tabeli, kaskaadi lõigu ja kolme ennetava kontrolliga.

## Miks see nii töötab

**Volume'i omanik.** Kui nimega volume on tühi, täidab Docker selle esimesel ühendamisel image'i sihtkataloogi sisuga, sealhulgas omaniku ja õigustega. Tulemus sõltub seega image'ist: kui image'is sihtkataloogi pole või selle omanik on root, ei saa mitte-root teenus volume'isse kirjutada.

**Bind mount'i kaust.** Compose'i lühivorm (`- ./data:/var/lib/mysql`) loob puuduva hosti kausta root'i omana. Mitte-root teenus (`user: "999:999"`) ei saa siis oma andmekataloogi kirjutada.

**Vale port healthcheck'is.** Healthcheck, mis küsib vale porti, muudab muidu töötava teenuse olekuks `unhealthy`. Kõik teenused, mille käivitamine sõltub selle teenuse olekust `service_healthy`, võivad jääda käivitamata.

**Võrk teenuse omadusena.** Compose'is määratakse võrgud iga teenuse juures. Kui web01 ja app01 pole ühes võrgus, ei lahendu nimi `app01` ja nginx vastab 502-ga.

**Restart ja `depends_on`.** `depends_on` koos `condition: service_healthy`-ga on Compose'i kliendi loogika: `docker compose up` ootab enne järgmise teenuse loomist. Daemon ei tea sellest midagi. Pärast `dockerd` taaskäivitust käivitab ta kõik konteinerid, mille restart-poliitika seda lubab, paralleelselt ja ilma järjekorrata. `unless-stopped` jätab vahele konteinerid, mille admin peatas `docker stop`-iga, `always` käivitab ka need. Järjekorra puudumist peab taluma rakendus ise. app01 HikariCP pool (`initialization-fail-timeout=-1`) lubab Springil käivituda ka ilma andmebaasita ja ühendus luuakse hiljem, RabbitMQ listener proovib uuesti ja nginx lahendab `app01` nime uuesti iga 10 s järel. Ühel YAML-ankrul (`x-…: &…`) põhinev ühine plokk hoiab poliitika ühes kohas nagu põhistacki `compose.yaml`-is.

**Süntaktiliselt korras fail.** Kõigil kolmel rikkel on ühine joon: fail on süntaktiliselt korras ja `docker compose config -q` laseb selle läbi. Need vead avastab ainult käivitamine või test, mis kontrollib tulemust, mitte üksnes faili süntaksit. Seetõttu on GitHub Actionsi pipeline'is lisaks süntaksikontrollile (lint) ka samm, mis käivitab stacki ja küsib `/health`-i.

**Ennetav kontroll.** Intsidendi järel lisatakse kontroll, mis püüab sama vea järgmine kord varem kinni, juba enne käivitamist.

Kui jõudsid kiiremini: [Lisaülesanded → 3. Monitooring](lisa.md#3-monitooring), paned Uptime Kuma jälgima `/health`-i, et järgmine `unhealthy` jõuaks sinuni enne kasutajat.
