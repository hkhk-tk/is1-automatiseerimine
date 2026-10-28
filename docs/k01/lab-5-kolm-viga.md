---
tags:
  - Bash
  - Labori seis
  - veaotsing
---

# 5. Kolm viga

Kõige kallim viga intsidendis on parandus vales kohas: masinas tehtud muudatus kaob järgmise rollback'i, uue VM-i või kolleegi deploy'ga ja rike tuleb tagasi ajal, mil keegi seda ei oota. Starteri teenuse-skriptides on kolm viga, igaüks eri kihis. Sul on sümptomid, logid ja skriptid, aga mitte vastust. Liigu väljast sisse, paranda iga viga skriptis, mitte masinas käsitsi, ja käivita uuesti ainult need hostid, mida parandus puudutab.

**Kui teed seda tööl iga päev:** parandad kolm viga tabeli L1.3 järgi ilma etappide juhisteta, iga parandus on oma `fix(…)` commit'is ja `bash ../autograde/check.sh k01 fixed` annab `OK`. Kui see on sul juba korras, mine otse etappi [„Tõesta, et parandus on skriptis“](#toesta-et-parandus-on-skriptis).

Tabel ütleb, kust otsida, mitte mis on valesti.

| Sümptom | Vaata esimesena | Tõenäoline koht |
|---|---|---|
| `deploy-all.sh` jääb app01 juures seisma, "Rakendus ei vasta" | `ssh app01 sudo journalctl -u tomcat -n 50 --no-pager` | app01: `services/tomcat.sh`, unit ja õigused |
| web01 annab `502 Bad Gateway` | sama Tomcati logi | app01: Tomcat ei vasta |
| `/health` → `"db":"DOWN"` | app01 logi andmebaasi kohta, db01 `mysql.user` | db01: `services/mariadb.sh` |
| `/health` → `"cache":"DOWN"`, `check.sh` kood 1 | `ssh mc01 sudo ss -tlnp` | mc01: `services/memcache.sh` |
| `/health` → `"queue":"DOWN"` | `ssh rmq01 sudo rabbitmqctl list_users` | rmq01 või `secrets.env` parool |

*Tabel L1.3. Veaotsingu tabel.*

> ⚠️ Kui stack on täiesti segamini: rollback kõigil viiel `enne-stack`-ile kustutab VM-idest kõik hilisema, ka db01 andmebaasi; repo jääb alles; siis `./deploy-all.sh`.

## app01 ei käivitu

`deploy-all.sh` jäi app01 juures seisma. Leia põhjus ja paranda see failis `services/tomcat.sh`.

Alustad siit, sest app01 on ainus host, kus health check ebaõnnestus. Kuni Tomcat ei vasta, ei saa sa `/health`-ilt teada, kas andmebaas ja vahemälu on korras: kõik, mis on Tomcatist sügavamal, on praegu nähtamatu.

1. Ava Tomcati logi ja unit-fail.

    ```bash
    ssh app01 sudo journalctl -u tomcat -n 50 --no-pager
    ssh app01 systemctl cat tomcat
    ```

2. Kontrolli, mis kasutajana Tomcat töötab ja kellele kuuluvad Tomcati kataloogid.
3. Mõtle enne parandust: millise kasutajana teenus käivitub, kust tulevad keskkonnamuutujad, kas sellel kasutajal on õigus kirjutada sinna, kuhu Tomcat kirjutab.
4. Paranda põhjus failis `k01-bash/services/tomcat.sh`. Ära paranda app01 masinat käsitsi.
5. Käivita uuesti ainult vajalikud hostid: `./deploy-all.sh app01 web01`
6. Kontrolli tulemust: `curl -s http://web01/health`

> Kui nginx ei käivitu pordil 80, töötab web01-s veel Apache.

JSON-vastus tähendab, et kogu tee brauserist Tomcatini töötab. Vastuse sisu ei pruugi veel olla hea: kui seal on `DOWN` väärtusi, näed nüüd esimest korda sügavamaid kihte.

✅ **Edasi saad minna, kui** Tomcat käivitub, nginx test läbib ja `/health` tagastab JSON-vastuse. Esita see commit'ina `fix(tomcat): …`.

## Andmebaas on DOWN

`/health` näitab `"db":"DOWN"`, kuigi MariaDB töötab ja health check ütles "db01 terve". Leia põhjus ja paranda see failis `services/mariadb.sh`.

Vastuolu on siin vihje. Health check kontrollib db01 seest ja ütleb "terve", rakendus ühendub app01-st ja ütleb "DOWN". Kui kaks kontrolli annavad eri vastuse, on erinevus nende vahel: aadress, kust ühendutakse, või õigus, millega ühendutakse.

1. Vaata, mida rakendus andmebaasi kohta ütleb, kas MariaDB kuulab võrgus ja kes tohib sisse tulla.

    ```bash
    ssh app01 sudo journalctl -u tomcat --no-pager | grep -iE 'jdbc|sql|denied' | tail -5
    ssh db01 sudo ss -tlnp | grep 3306
    ssh db01 sudo mysql -e "SELECT user, host FROM mysql.user"
    ```

2. Võrdle, kust app01 ühendub ja kust kasutaja `labseis` tohib tulla.
3. Paranda põhjus failis `k01-bash/services/mariadb.sh`. Skript peab jääma idempotentseks: ka teine käivitus ei tohi ebaõnnestuda.
4. Käivita uuesti ainult db01: `./deploy-all.sh db01`
5. Kontrolli tulemust: `curl -s http://web01/health; echo`

Kui `db` on nüüd `UP`, tõestas see, et parandus on skriptis ja jõudis db01-sse ainult skripti kaudu. Kui tulemus ei muutunud, kuigi skripti muutsid, vaata, kas teine käivitus ebaõnnestus: andmebaasi kasutaja loomine, mis töötab ainult esimesel korral, on tüüpiline idempotentsuse viga.

✅ **Edasi saad minna, kui** `/health` näitab `"db":"UP"`. Esita see commit'ina `fix(mariadb): …`, sõnumis põhjus.

## Vahemälu on DOWN

`/health` näitab `"cache":"DOWN"` ja `check.sh` lõpeb koodiga 1, kuigi memcached töötab ja health check ütles "mc01 terve". Leia põhjus ja paranda see failis `services/memcache.sh`.

Muster on sama mis andmebaasiga, aga seekord on kontrollpunkte kolm: hosti sees, control node'ilt ja app01-st. Võrdle neid ja leia, kus vastus muutub.

1. Vaata, millisel aadressil memcached kuulab ja kas port on control node'ilt kättesaadav.

    ```bash
    ssh mc01 sudo ss -tlnp | grep 11211
    ssh mc01 cat /etc/sysconfig/memcached
    timeout 3 bash -c '</dev/tcp/mc01/11211' && echo avatud
    ```

2. Leia memcached'i dokumentatsioonist, mida teeb võti `-l`.
3. Mõtle, miks health check läbis, aga `check.sh` mitte: kust kontrollib üks ja kust teine.
4. Paranda põhjus failis `k01-bash/services/memcache.sh` mõlema distro jaoks ja vaata, kas mc01 tulemüür laseb 11211 läbi.
5. Käivita uuesti ainult mc01: `./deploy-all.sh mc01`
6. Kontrolli tulemust: `./check.sh; echo "kood $?"`

> Ubuntu hoiab memcached'i võtmeid failis `/etc/memcached.conf`, Rocky `/etc/sysconfig/memcached`-is.

Kood 0 tähendab, et kõik kihid on nüüd sama vastusega nii seest kui väljast. See on ka põhjus, miks vahemälu viga annab WARNING, mitte CRITICAL: leht töötas kogu aeg, ainult aeglasemalt. Kui kood oleks endiselt 1, võrdle uuesti kolme kontrollpunkti: kus vastus muutub, seal on parandus veel puudu.

✅ **Edasi saad minna, kui** `/health` näitab `"cache":"UP"`. Esita see commit'ina `fix(memcache): …`, sõnumis põhjus.

## Kõik kihid koos

`/health` ütleb, et Memcached vastab. `X-Cache` päis näitab, et rakendus seda ka kasutab.

See on kahe tasandi kontroll. Esimene tõestab, et ühendus on olemas, teine, et kasutajapäring sellest kasu saab. Esimene päring peab olema `MISS`, sest vahemälu on tühi; teine peab tulema vahemälust.

```bash
. ./secrets.env
for i in 1 2; do curl -s -o /dev/null -D - "http://web01/?token=$TEACHER_TOKEN" | grep -i x-cache; done
./check.sh; echo "kood $?"
bash ../autograde/check.sh k01 fixed
```

Kui `/health` on UP, aga `X-Cache` jääb `MISS`-iks, vaata app01-s `/etc/labori-seis/env` rida `MEMCACHED_HOST`.

<!-- EKRAANIPILT: Labori seisu koondtabel brauseris (http://web01/?token=<TEACHER_TOKEN> või koolitaja vaade), näha õppija rida lab-01 kontrollidega nginx, tomcat, health-db, health-queue, health-cache, cache olekus OK (roheline). Tee pärast esimest õnnestunud ./check.sh käivitust. Token ei tohi pildil näha olla.
<figure markdown="span">
  ![Labori seisu koondtabel, õppija lab-01 read rohelised](assets/k01_labori_seis_koondtabel.png)
  <figcaption>Joonis L1.6. <code>check.sh</code> tulemused Labori seisu koondtabelis.</figcaption>
</figure>
-->

`MISS` → `HIT` ja kood 0 koos tõestavad, et stack töötab nii, nagu kasutaja seda kogeb. `fixed` test kontrollib skriptide sisu, mitte VM-e: see ei tea, kas sinu stack töötab, ainult seda, kas parandused on failides.

✅ **Edasi saad minna, kui** `X-Cache` on esimesel korral `MISS` ja teisel `HIT`, `check.sh` kood on 0 ja sinu rida on Labori seisus roheline.

## Tõesta, et parandus on skriptis

Kõik kihid on rohelised, aga see ei tõesta veel, kust parandus tuli. Kui mõni muudatus jäi kogemata masinasse, töötab stack täna ja ebaõnnestub järgmisel uuel VM-il. Kontrolli seda nagu tootmises: võta host tühjaks ja lase skriptil see uuesti üles ehitada. Rollback kustutab ka db01 andmebaasi; laboris on andmestik skriptiga taastatav.

1. Vaata, et kõik parandused on commit'itud ja push'itud.

    ```bash
    git status --short services/
    git log --oneline -3
    ```

2. Proxmoxis **db01 → Snapshots → `enne-stack` → Rollback**, siis **Start**.
3. Oota, kuni host vastab, ja vaata, mida `check.sh` nüüd ütleb.

    ```bash
    until ssh db01 true; do sleep 3; done
    ./check.sh; echo "kood $?"
    ```

4. Ehita db01 skriptiga uuesti ja kontrolli tervet stacki.

    ```bash
    ./deploy-all.sh db01
    ./check.sh; echo "kood $?"
    ```

Pärast rollback'i oli kood 2, sest andmebaas oli kadunud. Pärast `deploy-all.sh db01`-i on kood jälle 0, ilma et oleksid db01-s midagi käsitsi teinud. See tõestab, et `services/mariadb.sh` sisaldab kogu parandust. Kui `db` oleks jäänud `DOWN`-iks, oleks osa parandusest olnud ainult masinas ja nüüd tead, et pead selle skripti tooma.

✅ **Edasi saad minna, kui** `check.sh` andis pärast rollback'i koodi 2, pärast `deploy-all.sh db01` koodi 0 ja `git status --short services/` on tühi.

📎 **Selle mooduli tõend:** kolm commit'i `fix(tomcat)`, `fix(mariadb)`, `fix(memcache)` põhjusega sõnumis; `bash ../autograde/check.sh k01 fixed` → `OK`; `NOTES.md`-s db01 rollback'i ja taastamise koodid.

## Miks see nii töötab

**Starteri kolm viga.** Need on tüüpilised: teenus kuulab ainult loopback-liidesel, andmebaasi kasutaja tohib ühenduda ainult samast masinast ja lahtipakitud failid kuuluvad root'ile.

**Vaikeväärtused ja omanikud.** Kaks esimest viga tulenevad paketi turvalistest vaikeväärtustest: MariaDB-s on `'labseis'@'localhost'` ja `'labseis'@'%'` kaks eri kontot eri paroolide ja õigustega. Memcached ei autentiseeri vaikimisi kedagi, seepärast seavad distro-paketid `-l 127.0.0.1`; pärast 2018. aasta memcrashed-võimendusrünnakuid lülitas memcached 1.5.6 välja ka UDP. Kolmas tekib, kui paigaldad failid root'ina, aga teenus töötab teise kasutajana. Kaks esimest viga läbivad hosti seest tehtud kontrolli, sest hosti seest on teenus kättesaadav.

**Väljast sisse.** Veaotsingul on tavaliselt kiireim liikuda väljast sisse (web01 → app01 → taustateenused), sest iga kiht näitab, kas viga on selles kihis või sügavamal.

**Commit intsidendi logina.** Kui iga parandus on eraldi commit ja sõnumis on põhjus, saab `git log`-ist intsidendi logi. Kuude pärast näed sealt, miks seadistus on just selline.

Kui jõudsid kiiremini: [Lisaülesanded → 3. X-Cache rikketest](lisa.md#3-x-cache-rikketest), võtad vahemälu ära ja vaatad, mida `/health` ja `X-Cache` selle kohta eraldi ütlevad.
