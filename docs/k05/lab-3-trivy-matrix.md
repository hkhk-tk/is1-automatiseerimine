---
tags:
  - GitHub Actions
  - Trivy
  - turve
---

# 3. Trivy, matrix ja õigused

Roheline build ütleb ainult, et build õnnestub. See ei ütle, kas sõltuvustes on teadaolev CVE, kas build töötab ka järgmise Java'ga ja kas pipeline ise on rünnatav. Viimane puudutab adminit otse, sest pipeline'il on ligipääs registry'le ja hiljem ka sinu serverile.

Mooduli lõpuks skännib teine job sõltuvusi build'iga samal ajal ja kolmas proovib build'i järgmise JDK-ga. Igal job'il on ainult talle vajalikud tokeni õigused ja action'id on SHA-ga fikseeritud. Dependabot hoiab action'id ja image'id värskena, kuid andmebaasi uus põhiversioon ei tule sisse ilma sinu otsuseta.

**Kui teed seda tööl iga päev:** job'id `security` ja `compat` on olemas, igal job'il on oma `permissions:` ja `bash autograde/check.sh k05 hygiene` annab `OK`. Kui see on sul juba korras, mine otse etappi „[Baas-image'id ja Compose'i teenused](#baas-imageid-ja-composei-teenused)“.

## Turvaskänn eraldi job'ina

Lisad job'i `security`, mis töötab build'iga kõrvuti ja kirjutab Trivy tulemuse käivituse kokkuvõttesse. `aquasecurity/trivy-action` vanad tag'id suunati pahatahtlikele commit'idele ([GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy-action/security/advisories)). Seepärast kasutad täis-SHA-d.

See intsident on hea näide, miks tag'i usaldamine on risk: sama nimi, mis eile osutas korralikule koodile, osutas järgmisel päeval koodile, mis luges runner'ilt saladusi. Kõik, kes kasutasid tag'i, käivitasid seda koodi ilma ühtki faili muutmata.

1. Leia v0.36.0 commit'i SHA. Kui väljundis on rida `^{}` lõpuga, võta selle SHA: see on commit, mitte tag-objekt.

    ```bash
    git ls-remote https://github.com/aquasecurity/trivy-action 'refs/tags/v0.36.0*'
    ```

2. Lisa job `security` (`runs-on: ubuntu-latest`, checkout ja Trivy), ilma `needs`-ita:
    - `uses:` rida kujul `aquasecurity/trivy-action@<40 märki>  # v0.36.0`
    - sisendid `scan-type: fs`, `scan-ref: .`, `scanners: vuln`, `severity: CRITICAL,HIGH`
    - `format: table`, `output: trivy.txt`, `exit-code: "0"`
    - kaks sammu `if: always()`: üks kirjutab `trivy.txt` sisu `$GITHUB_STEP_SUMMARY`-sse, teine laadib selle artefaktina üles
3. Tee push ja ava käivituse *Summary*.
4. Kirjuta märkmikku HIGH ja CRITICAL leidude arv, enim leide andnud teek ja kas see on otse pom'is või tuleb parent'ist (`mvn dependency:tree`).

<!-- EKRAANIPILT: Actions → käivitus → Summary leht, kerida security job'i kokkuvõtteni; näha Trivy tabel (Library, Vulnerability, Severity veerud) ja allosas Artifacts plokk. Pärast security job'i esimest käivitust.
<figure markdown="span">
  ![Käivituse kokkuvõte Trivy leidude tabeliga](assets/k05_trivy_kokkuvote.png)
  <figcaption>Joonis L5.3. Trivy tabel käivituse kokkuvõttes.</figcaption>
</figure>
-->

<!-- EKRAANIPILT: Actions → käivitus pärast security job'i lisamist → Summary ülaosa graaf; näha build ja security kõrvuti (paralleelselt), mõlemad rohelised, all Artifacts: labori-seis-war ja Trivy raport.
<figure markdown="span">
  ![Käivituse graaf, kus build ja security töötavad kõrvuti](assets/k05_actions_graaf.png)
  <figcaption>Joonis L5.4. Build ja security töötavad paralleelselt.</figcaption>
</figure>
-->

> `Unable to resolve action` tähendab tavaliselt vale SHA-d: see peab olema täpselt 40 kuueteistkümnendmärki, lühike SHA ei tööta.

Kõrvuti töötavad job'id tähendavad, et skänn ei lisa käivitusele aega, kui ta pole build'ist aeglasem. `exit-code: "0"` jätab job'i roheliseks ka leidude korral: täna sa kogud infot, otsus "kas leid peatab pipeline'i" on lisaülesandes [10. Trivy poliitika](lisa.md#10-trivy-poliitika). `if: always()` on vajalik, sest muidu kaoks raport just siis, kui Trivy ise ebaõnnestub. Kui leide on null, kontrolli, kas `scan-ref` osutab repo juurele, kus on `pom.xml`.

✅ **Edasi saad minna, kui** graafis on `build` ja `security` kõrvuti, kokkuvõttes on Trivy tabel ja *Artifacts* all on WAR ja Trivy raport.

## Ühe leiu jälg: kust see teek tuleb

Trivy tabel ütleb, mis teegis on auk, aga mitte seda, kes selle teegi projekti tõi. Võtad ühe leiu ja jälitad selle Maveni sõltuvuspuust oma pom'ini. Nii jõuad otsuseni, kes ja kuidas seda parandab.

Ilma selle sammuta näeb turvaraport välja nagu nimekiri, mida keegi ei oska käsitleda. Tööl küsib turvameeskond sinult just seda: kas parandus on meie käes ja kui kiiresti.

1. Laadi Trivy raport alla ja vali üks HIGH või CRITICAL rida, millel on täidetud *Fixed Version*.

    ```bash
    gh run download --name trivy-raport --dir /tmp/trivy
    grep -E 'HIGH|CRITICAL' /tmp/trivy/trivy.txt | head -5
    ```

2. Leia selle teegi tee pom'ini (asenda `groupId:artifactId` leiu omaga).

    ```bash
    mvn -B -q dependency:tree -Dincludes=groupId:artifactId
    ```

3. Kirjuta märkmikku: teek, praegune ja parandatud versioon, otsene või transitiivne sõltuvus ning kes selle versiooni määrab (sinu pom, `spring-boot-starter-parent` või mõni muu teek).

Kui teek on puus otse sinu projekti all, on parandus sinu pom'is. Kui see tuleb parent'i kaudu, saad versiooni üle kirjutada `<properties>`-is, aga siis võtad vastutuse, et uus versioon sobib ülejäänud komplektiga. Sageli on parem oodata parent'i patch-versiooni, mida Dependabot pakub. Kui `dependency:tree` ei näita teeki üldse, tuleb leid failist, mis pole Maveni sõltuvus, näiteks `k03-docker/` all olevast konfiguratsioonifailist.

✅ **Edasi saad minna, kui** märkmikus on ühe leiu kohta neli nimetatud asja ja `dependency:tree` väljund näitab teed sinu projektini.

## Compat-matrix: kas build töötab Java 25-ga

Lisad job'i, mis käivitab sama build'i kahe JDK-ga. Control node'il ebaõnnestus build nii Java 17 kui ka JaCoCo 0.8.8-ga. Matrix küsib sama küsimust igal push'il: kas järgmine JDK töötab, enne kui keegi runner'i JDK-d uuendab.

JDK uuendus tuleb tavaliselt väljastpoolt: runner'i image vahetub, baas-image saab uue Java või turvauuendus nõuab uuemat versiooni. Kui sa ei tea ette, mis katki läheb, avastad selle tootmisrikke ajal.

1. Lisa job `compat`, mis kordab build'i Maveni sammu ja mille järel ükski job ei oota:
    - `strategy.matrix.java: ["21", "25"]` ja `fail-fast: false`
    - setup-java `java-version: ${{ matrix.java }}` ja `cache: maven`
    - job `build` jääb muutmata: see teeb WAR-i ja selle `java-version` on `"21"`
2. Kirjuta märkmikku ennustus: kas Java 25-ga läheb `mvn -B verify` läbi?
3. Tee push ja vaata graafi.

    ```bash
    git commit -am "ci: compat matrix" && git push
    gh run watch
    gh run view "$(gh run list -w ci -L 1 --json databaseId --jq '.[0].databaseId')" --json jobs --jq '.jobs[] | [.name, .conclusion] | @tsv'
    ```

> Ilma `fail-fast: false`-ta tühistab ühe kombinatsiooni ebaõnnestumine teised ja sa ei tea, kas viga on ühes või kõigis.

`compat` on teadlikult eraldi job: tema tulemus on info, mitte quality gate. Kui `compat (25)` ebaõnnestub, ei peatu image ega deploy, aga sa tead, mis tuleb parandada enne JDK tõstmist. Kui mõlemad on rohelised, on sinu ennustus kas õige või oli sinu pilt pluginatest liiga pessimistlik. Kui ebaõnnestub ka `compat (21)`, ei ole viga JDK-s, vaid samas kohas mis `build`-is.

✅ **Edasi saad minna, kui** graafis on `compat (21)` ja `compat (25)` eraldi job'idena, mõlema tulemus on märkmikus ennustuse kõrval ja `bash autograde/check.sh k05 build` annab endiselt `OK`.

## Vahemälu tööle

Kontrollid, kas `cache: maven` midagi taastab.

Vahemälu, mis ei tööta, ei anna veateadet. Build on lihtsalt aeglasem ja Maven Central saab iga push'iga sadu päringuid. Ainus viis seda teada on logist vaadata.

1. Leia viimase käivituse build job'i logist read, mis algavad `Cache restored` või `Cache saved`.

    ```bash
    run=$(gh run list -w ci -L 1 --json databaseId --jq '.[0].databaseId')
    gh run view "$run" --log | grep -iE 'cache (restored|saved|not found)'
    ```

2. Võrdle repo vahemälu kirjeid ja nende suurust.

    ```bash
    gh cache list
    ```

3. Kirjuta märkmikku, mitu vahemälu kirjet on ja miks `compat (25)` ja `build` võivad kasutada sama kirjet.

`Cache restored from key` ütleb, et runner sai `~/.m2` kätte ega pidanud kõike alla laadima. Võtmes on pom'i räsi, seega iga pom'i muutus teeb uue kirje ja vana jääb aeguma. Kui logis on igal käivitusel `Cache not found`, muutub pom igas commit'is või on `cache:` rida puudu. Võrdle sammude kestusi nendega, mille esimese workflow juures üles kirjutasid: vahemäluga peaks Maveni samm olema märgatavalt lühem.

✅ **Edasi saad minna, kui** teises käivituses on build'i logis `Cache restored from key`, `gh cache list` näitab vähemalt ühte `setup-java-…-maven-…` kirjet ja vastus on märkmikus.

## Iga job oma õigustega

Võtad kõik tokeni õigused workflow tasemel ära ja annad iga job'ile tagasi ainult lugemisõiguse. `GITHUB_TOKEN` antakse igale sammule, ka kolmanda osapoole action'ile.

Trivy intsidendi pahatahtlik kood kasutas just seda tokenit. Kui tokenil on kirjutusõigus, võib kompromiteeritud action muuta sinu koodi, release'e või pakette. Lugemisõigusega token saab ainult lugeda seda, mida runner niikuinii näeb.

1. Ava viimase käivituse build job'i *Set up job* ja vaata plokki *GITHUB_TOKEN Permissions*.
2. Lisa faili ülaossa (mitte job'i alla) `permissions: {}` ja igale kolmele job'ile `permissions:` plokk `contents: read`.
3. Proovi, mis juhtub ilma job'i plokita: eemalda see ajutiselt `compat` job'ilt, tee push ja vaata checkout'i viga. Siis pane tagasi.
4. Tee push ja kontrolli.

    ```bash
    bash autograde/check.sh k05 hygiene
    bash autograde/check.sh k05 actionlint
    ```

<!-- EKRAANIPILT: Actions → käivitus pärast permissions muudatust → job build → Set up job laiendatud; näha plokk "GITHUB_TOKEN Permissions" ridadega Contents: read ja Metadata: read.
<figure markdown="span">
  ![Set up job sammu plokk GITHUB_TOKEN Permissions](assets/k05_token_oigused.png)
  <figcaption>Joonis L5.5. Pärast job'i plokki <code>contents: read</code> on tokenil ainult lugemisõigus.</figcaption>
</figure>
-->

Plokita `compat` sai workflow tasemelt `{}` ehk mitte midagi ja privaatse repo checkout ebaõnnestus. See tõestab, et piirang kehtib. `Metadata: read` on alati olemas ja seda ei saa ära võtta. Kui pärast muudatust näed plokis endiselt `Contents: write`, on `permissions:` vales taandes ja GitHub ei loe seda job'i omaks.

✅ **Edasi saad minna, kui** enne muudatust oli plokis mitu õigust ja pärast ainult `Contents: read` ja `Metadata: read`, plokita `compat` ebaõnnestus checkout'is ning mõlemad kontrollid annavad `OK`.

## Action'id täis-SHA-ga

Kinnitad ka GitHubi ja Dockeri action'id commit'i SHA-ga, nagu Trivy. Tag on muudetav viide.

Ametlike action'ite kompromiteerimine on harvem, aga mõju oleks suurem, sest neid kasutavad kõik. SHA-ga fikseerimine teeb muutuse nähtavaks: uus versioon tuleb ainult PR-iga, mida keegi vaatab.

1. Leia iga kasutatud action'i ja versiooni SHA samamoodi nagu Trivy puhul, näiteks:

    ```bash
    git ls-remote --tags https://github.com/actions/checkout 'v5*' | sort -k2 -V | tail -3
    ```

2. Muuda iga `uses:` rida nii:
    - `@` järel 40-märgiline SHA, mitte tag
    - rea lõpus kommentaar täpse versiooniga, nt `# v5.1.0`
    - kohalikud action'id (`./…`) jäävad nagu on
3. Kontrolli, et ükski rida pole jäänud tag'iga.

    ```bash
    grep -n 'uses:' .github/workflows/*.yml | grep -vE '@[0-9a-f]{40}  # v[0-9]|uses: \./'
    actionlint && bash autograde/check.sh k05 hygiene
    ```

Tühi `grep` tähendab, et iga väline action on kinnitatud ja kommentaar ütleb inimesele, mis versioon see on. Kommentaar ei ole ainult inimesele: Dependabot loeb sealt versiooni ja uuendab SHA-d ja kommentaari koos. Kui kommentaar ja SHA lähevad lahku, usu SHA-d, sest just see töötab.

✅ **Edasi saad minna, kui** `grep` on tühi, actionlint vaikib ja `hygiene` annab `OK`.

## Dependabot hoiab need värsked

Paned Dependaboti jälgima action'eid, Maveni sõltuvusi ja Dockerfile'i baas-image'it. SHA ei uuene ise. Dependabot avab PR-i, mis vahetab SHA ja kommentaari koos ([Dependaboti seadistus](https://docs.github.com/code-security/dependabot/working-with-dependabot/dependabot-options-reference)).

Kinnitatud versioon, mida keegi ei uuenda, muutub ise turvaauguks. Dependabot teeb uuenduse väikeseks ja korrapäraseks: üks PR nädalas, mille CI kontrollib enne, kui sina seda vaatad.

1. Kirjuta `.github/dependabot.yml`:
    - `version: 2`
    - ökosüsteem `github-actions`, `directory: /`, kord nädalas, kõik uuendused ühes grupis (`groups`)
    - ökosüsteem `maven`, `directory: /`, kord nädalas, kuni 5 avatud PR-i
    - ökosüsteem `docker`, `directory: /k03-docker/app` (Dockerfile'i `FROM` read)
2. Kontrolli süntaksit ja tee commit.

    ```bash
    python3 -c 'import yaml,sys; d=yaml.safe_load(open(".github/dependabot.yml")); print([u["package-ecosystem"] for u in d["updates"]])'
    git add .github/dependabot.yml && git commit -m "ci: dependabot" && git push
    ```

> Dependabot loeb faili ainult vaikeharult. Esimesed PR-id tulevad pärast seda, kui `k05-actions` jõuab main'i (image'i ja deploy juures); seni on fail lihtsalt repos.

Kolm ökosüsteemi jälgivad kolme kohta, kust vana kood sinu pipeline'i jõuab: action'id, Java teegid ja konteineri baas. Grupp action'itele hoiab PR-ide arvu väiksena, sest neid uuendatakse sageli koos. Kui `python3` trükib vähem kui kolm nime, on mõni plokk vale taandega ja Dependabot ignoreerib seda vaikselt.

✅ **Edasi saad minna, kui** `python3` trükib `['github-actions', 'maven', 'docker']` ja fail on push'itud.

## Baas-image'id ja Compose'i teenused

Dependabot vaatab praegu ainult rakenduse Dockerfile'i. db01 ja web01 baas-image'id ning `compose.yaml`-is olevad `memcached` ja `rabbitmq` vananevad vaikselt: Trivy `fs`-skänn loeb pom'i, mitte image'eid, ja ükski PR ei ütle, et `rabbitmq:4.1-management-alpine` all on uus Alpine'i parandus. Samal ajal ei tohi andmebaasi uus seeria tulla nädala PR-iga. MariaDB 11.4 → 11.8 on uus major-seeria: see uuendab andmekataloogi ja allapoole MariaDB ametlikult ei toeta, seega rollback'i pärast seda ei ole.

Teine probleem on liikuv tag. `FROM mariadb:11.4` annab iga build'i ajal selle, mis registry's parasjagu on: kui upstream ehitab tag'i turvaparandusega uuesti, muutub sinu db01 image järgmisel build'il ilma ühegi commit'ita. Digest teeb sama muutuse nähtavaks: Dependabot avab PR-i, mis vahetab digest'i, ja CI kontrollib seda enne sind.

Nõuded failile `.github/dependabot.yml` ja db01 Dockerfile'ile:

- ökosüsteem `docker` jälgib kõiki kolme Dockerfile'i (`directories` glob'iga `/k03-docker/*`)
- uus ökosüsteem `docker-compose` jälgib faili `k03-docker/compose.yaml`, kord nädalas
- `mariadb` uut minor- ega major-versiooni Dependabot ei paku (`ignore` + `update-types`)
- db01 baas-image on kinnitatud digest'iga kujul `FROM mariadb:11.4@sha256:<digest>`; digest on sama, mida registry praegu tag'ile `11.4` annab
- 3. kohtumise automaatse hindaja `tags` kontroll on endiselt `OK` (tag jääb digest'i kõrvale alles, `latest`-i pole)

```bash
python3 -c 'import yaml; d=yaml.safe_load(open(".github/dependabot.yml")); print([u["package-ecosystem"] for u in d["updates"]])'
grep -n '^FROM' k03-docker/db/Dockerfile
docker buildx imagetools inspect mariadb:11.4 | awk '/^Digest:/{print $2}'
bash autograde/check.sh k03 tags
```

Dependaboti viide ([`ignore`](https://docs.github.com/code-security/dependabot/working-with-dependabot/dependabot-options-reference#ignore--), [`docker-compose`](https://docs.github.com/code-security/dependabot/working-with-dependabot/dependabot-options-reference#package-ecosystem-)) ütleb võtmete täpse kuju. Kui `python3` ei näita `docker-compose`-i, on plokk vale taandega ja Dependabot jätab selle vaikselt vahele. `compose.yaml`-i read, kus `image:` sisaldab muutujat (`${REGISTRY}`), on sinu oma image'id ja need uuendab pipeline, mitte Dependabot. Digest'iga rida tähendab, et db01 image muutub ainult PR-iga, mille diff näitab vana ja uut digest'i. Kui `ignore` puudub, tuleb esimene MariaDB PR uue seeriaga ja roheline CI ei ütle midagi andmekataloogi uuenduse kohta, sest testid ei käivita andmebaasi.

✅ **Edasi saad minna, kui** `python3` trükib `['github-actions', 'maven', 'docker', 'docker-compose']`, `FROM` real on `mariadb:11.4@sha256:` ja sama digest, mida näitab `imagetools`, `k03 tags` annab `OK` ning commit on push'itud. Pärast main'i jõudmist näitab *Insights → Dependency graph → Dependabot* ka faili `k03-docker/compose.yaml`.

📎 **Selle mooduli tõend:** märkmikus Trivy leidude arv ja teek, ühe leiu jälg pom'ini, matrix'i ennustus ja tulemus, vahemälu kirjed; graafis `build`, `security` ja `compat` paralleelselt; `.github/dependabot.yml` nelja ökosüsteemiga repos ja db01 `FROM` digest'iga; `check.sh k05 hygiene`, `k05 actionlint` ja `k03 tags` → `OK`.

## Miks see nii töötab

**Matrix'i job'i nimi.** Matrix'i job'i nimele lisatakse sulgudesse kombinatsioon (`compat (25)`). Seetõttu saab ruleset'is nõuda ka ainult osa kombinatsioonidest. Üks matrix genereerib käivituses kuni 256 job'i ja `max-parallel` piirab, mitu neist töötab korraga.

**`setup-java` vahemälu.** `actions/setup-java` v5 vahemälu võti sisaldab platvormi ja pom'i räsi, kuid mitte Java versiooni. Seetõttu võivad matrix'i harud kasutada sama vahemälukirjet. Üldine põhimõte: kõik, mida vahemälu võti ei sisalda, on käivituste vahel jagatud. Võtme koostis tasub kasutatava versiooni README-st järele vaadata, mitte eeldada. GitHub hoiab repo kohta kuni 10 GB vahemälu ja kustutab kirjed, mida 7 päeva ei loeta. Käivitus loeb ainult oma haru ja vaikeharu kirjeid, nii et PR-i haru ei saa main'i vahemälu üle kirjutada.

**Job'i `permissions:`.** Job'i `permissions:`-plokk asendab workflow tasemel määratud õigused täielikult. Kui job'i plokist jääb välja `contents: read`, ei saa checkout privaatset repot lugeda. `GITHUB_TOKEN` kehtib job'i lõpuni, kuid mitte üle 24 tunni. Repo vaikeõigus (*Settings → Actions → Workflow permissions*) on 2023. aasta veebruarist alates uutes repodes lugemine, vanemates sageli kirjutamine.

**Trivy failisüsteemi skännimine.** Failisüsteemi skännimisel loeb Trivy faili `pom.xml` ja lahendab sõltuvuspuu. Seetõttu leiab Trivy ka transitiivsed sõltuvused, mida pom'is otse kirjas ei ole. Sõltuvuspuu lahendamiseks vajab Trivy võrguühendust Maven Centralisse. Kui kaustas on juba ehitatud WAR või JAR, skännib Trivy ka neid.

**Haavatavuste andmebaas.** Trivy haavatavuste andmebaasi uuendatakse mitu korda päevas ja Trivy laadib uue versiooni, kui kohalik koopia on aegunud. Seetõttu võib sama kood anda homme teise tulemuse kui täna. Sel põhjusel on ajastatud skännimine vajalik ja turvaraporteid saab võrrelda ainult koos kuupäeva ja andmebaasi versiooniga. JSON-väljundis on leiu ID, teek ja parandatud versioon eraldi väljadena; neid on vaja, kui tahad iga leiu kohta automaatselt pileti avada.

**Avaldis ja shell.** Avaldis `${{ }}` asendatakse enne, kui shell skripti saab. Shell saab valmis teksti ega tea, et osa sellest tuli kasutajalt, nii et haru nimi `x$(curl …)` otse `run:`-ploki sees oleks käsk. `env:` kaudu jõuab väärtus shelli muutujana ja jutumärkides muutuja sisu shell käsuna ei käivita, kui sa ise seda `eval`-i ega `sh -c` kaudu ei käivita. Põhimõte: kõik, mida saab kirjutada keegi peale sinu (haru nimi, PR-i pealkiri, commit'i sõnum), antakse edasi `env:` kaudu.

Kui jõudsid kiiremini: [Lisaülesanded → 8. Matrix kahes mõõtmes](lisa.md#8-matrix-kahes-mootmes), lisad `compat` job'ile teise mõõtme, ennustad ebaõnnestuva kombinatsiooni ja kontrollid ennustust.
