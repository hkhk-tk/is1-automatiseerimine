---
tags:
  - Jenkins
  - CI/CD
---

# 2. Triggerid, options ja post

Build, mille keegi peab nupust käivitama, jääb tegemata just siis, kui seda kõige rohkem vaja on, ja build ilma piirideta hõivab agendi ning ketta seni, kuni keegi seda märkab. Praegu on sinu pipeline'iga just nii. Lõpuks käivitub build commit'i peale ise ja väljast saab selle käivitada API tokeniga. Jenkinsfile ütleb, kui kaua build tohib kesta, mitu jooksu korraga on lubatud ja mis pärast jooksu alles jääb.

**Kui teed seda tööl iga päev:** `pollSCM` ja `options` ploki kirjutad peast ning buildi käivitamine API tokeniga on sul skriptis juba olemas. Kui see on sul juba korras, mine otse etappi [„Arhiveeri WAR ja korista õiges järjekorras“](#arhiveeri-war-ja-korista-oiges-jarjekorras).

## Vaata, miks webhook ei jõua

Webhook vajab, et GitHubi server jõuaks Jenkinsi aadressile `/github-webhook/`. Enne pollimise valimist kontrollid, miks see siin ei tööta. Tootmises on alternatiivid avada tulemüüris ainult GitHubi `hooks` aadressivahemikud (`https://api.github.com/meta`) või panna vahele vahendav server, mis võtab webhooki DMZ-s vastu ja edastab sisevõrku.

1. Küsi webhooki aadressi control node'ist.

    ```bash
    curl -sI http://jenkins.lab.hkhk.ee:8080/github-webhook/ | head -1
    getent hosts jenkins.lab.hkhk.ee
    ```

2. Kirjuta PR-i kirjeldusse üks lause: kust GitHubi server selle päringu teeks ja miks see meie Jenkinsini ei jõua.

Päring vastab sinu masinast, sest sina oled VPN-i sees ja `getent` annab sisevõrgu aadressi. GitHubi serveritel seda nime ega aadressi pole.

✅ **Edasi saad minna, kui** päring vastab sinu masinast ja PR-i kirjelduses on lause selle kohta, miks GitHub VPN-i taha ei näe.

## Lase commit'il buildi käivitada

Kui GitHub ei saa Jenkinsit kutsuda, küsib Jenkins ise. `pollSCM` vaatab ajakava järgi, kas harul on uus commit, ja käivitab buildi ainult siis, kui on. `H/2` tähendab "iga kahe minuti järel, minut valitakse jobi nimest", nii et 15 õppija pollimised ei tule samal sekundil.

Ilma `H`-ta teeksid kõik jobid oma `git ls-remote`-i samal sekundil: sada jobi annavad Giti serverile iga kahe minuti järel saja päringu tipu.

1. Lisa Jenkinsfile'i `pipeline {}` sisse pärast `tools` plokki:

    ```groovy
        triggers {
            pollSCM('H/2 * * * *')
        }
    ```

2. Push, siis **Build Now** üks kord käsitsi. `triggers` on osa Jenkinsfile'ist ja Jenkins loeb selle alles käivitamisel.
3. Tee väike commit (näiteks kommentaar Jenkinsfile'is), push ja oota järgmist pollimist.
4. Ava jobi menüüs **Git Polling Log**.

<!-- EKRAANIPILT: job mari-tamm/labori-seis → Git Polling Log pärast väikest commit'i: rida "Changes found" ja commit'i räsi; soovi korral kõrvale buildi leht tekstiga "Started by an SCM change". Sammu 27.2 lõpus.
<figure markdown="span">
  ![Git Polling Log: Jenkins leidis uue commit'i](assets/k06_polling_log.png)
  <figcaption>Joonis L6.6. Polling logis on näha, millise commit'i Jenkins leidis.</figcaption>
</figure>
-->

```bash
bash autograde/check.sh k06 triggers
```

> Build ei käivitu ise: `triggers` jõustub alles pärast esimest käsitsi buildi.

Polling logis on viimane räsi, mida Jenkins nägi, ja otsus "Changes found" või "No changes". Kui logis on vale räsi, vaatab job teist haru või teist repot.

✅ **Edasi saad minna, kui** uus build algas ise, buildi lehel on "Started by an SCM change", polling logis on sinu commit ja kontroll annab `OK`.

## Käivita build väljast

Kolmas viis buildi alustada on `POST` Jenkinsi API-le, näiteks GitHub Actionsi self-hosted runner'ist või cron'ist. Alates Jenkins 2.129-st võib kasutajal olla mitu nimega tokenit, Jenkins hoiab neist ainult räsi ja näitab iga tokeni viimast kasutust, nii et lekkinud tokeni saab eraldi tühistada.

1. Jenkinsis sinu nimi (paremal üleval) → **Security → API Token → Add new Token** ([Remote access API](https://www.jenkins.io/doc/book/using/remote-access-api/)).
2. Hoia token ainult keskkonnamuutujas ja käivita build.

    ```bash
    read -rs JENKINS_TOKEN && export JENKINS_TOKEN JENKINS_USER=<gh>
    k06-jenkins/trigger-jenkins.sh --wait
    ```

3. Vaata buildi lehelt, kes selle käivitas.

> 403: kasutasid parooli või token on kustutatud. 404: jobi tee on vale (`<gh>/labori-seis`).

Skript sai vastuseks `201` ja järjekorra aadressi, ootas, kuni järjekorrast tuli build, ja seejärel buildi tulemust.

✅ **Edasi saad minna, kui** väljund on `OK: build järjekorras`, buildi URL ja `Tulemus: SUCCESS` ning buildi lehel on "Started by user `<gh>`".

## Loe buildi põhjust API-st

Buildi lehel on inimloetaval kujul kirjas, mis buildi käivitas. Sama info on JSON-ina API-s ja seda kasutavad skriptid ja monitooring. Deploy etapis otsustab pipeline just selle põhjuse järgi, kas küsida kinnitust.

Tingimus "ainult inimese käivitatud build" kirjutatakse nende klassinimede järgi. Vale klassinime korral jääb kas iga pollSCM-i build kinnitust ootama või ei küsi keegi kunagi.

1. Küsi kahe viimase buildi number, tulemus ja põhjus. Token läheb `curl`-ile standardsisendist, mitte käsureale.

    ```bash
    j=http://jenkins.lab.hkhk.ee:8080/job/$JENKINS_USER/job/labori-seis
    for b in lastBuild lastBuild/previousBuild; do
        printf 'user = "%s:%s"\n' "$JENKINS_USER" "$JENKINS_TOKEN" | curl -gfsS -K- \
            "$j/$b/api/json?tree=number,result,actions[causes[_class,shortDescription]]" \
            | jq -c '{number, result, causes: [.actions[].causes? // empty | .[]._class]}'
    done
    ```

2. Kui mõlemal real on sama põhjus, tee üks commit, oota pollSCM-i buildi lõppu ja korda päringut.

Väljundis on kaks erinevat klassi: `hudson.model.Cause$UserIdCause` sinu skripti buildil ja `hudson.triggers.SCMTrigger$SCMTriggerCause` pollimise buildil. Need on nimed, mida Deploy etapi `triggeredBy` tingimus kasutab. Kui mõlemal on `UserIdCause`, käivitasid mõlemad ise ja pollimine pole veel tööle läinud.

✅ **Edasi saad minna, kui** väljundis on kaks rida eri põhjusega ja PR-i kirjelduses on need kaks klassinime.

## Pane buildile piirid

Jenkinsi vaikimisi pole job'il ajapiiri ega ajaloo piiri ja samaaegsete buildide arv on piiramata: teine jooks saab kausta `workspace@2`, aga jagab sama testkonteinerit, Nexuse versiooni ja agendi ketast. Lisa Jenkinsfile'i plokk `options` ([direktiivid](https://www.jenkins.io/doc/book/pipeline/syntax/#options)). Nõuded:

- kogu buildi aeg on piiratud 30 minutiga (`timeout`)
- alles jääb 10 viimast buildi ja 5 viimase artefaktid (`buildDiscarder`, `logRotator` koos `artifactNumToKeepStr`-iga)
- sama jobi kaks buildi ei tööta korraga (`disableConcurrentBuilds`)
- konsooli igal real on kellaaeg (`timestamps`)

```bash
git commit -am "k06: options" && git push
```

Vajuta pärast buildi algust kohe uuesti **Build Now** ja vaata järjekorda.

Teine build seisis järjekorras, kuigi agendil oli teine executor vaba. See tähendab, et piirang on jobi tasemel, mitte node'i tasemel: teised jobid saavad vaba executorit kasutada. Kellaajad konsoolis lubavad hiljem öelda, kas aeglane oli Maven, võrk või Sonari ootamine.

✅ **Edasi saad minna, kui** teine build ootab, kuni esimene lõpetab (järjekorras on teade, et build on juba käimas), ja konsooli read algavad kellaajaga.

## Arhiveeri WAR ja korista õiges järjekorras

WAR tuleb arhiveerida buildi juurde enne, kui workspace tühjendatakse. `post` tingimustel on kindel järjekord ja see etapp näitab, miks koristus ei kuulu plokki `always`. Arhiveeritud fail kopeeritakse controllerisse `jobs/<job>/builds/<n>/archive/` alla, nii et artefaktide arvu piir `buildDiscarder`-is kaitseb controlleri ketast.

1. Lisa `pipeline {}` lõppu ajutiselt see plokk, push ja oota buildi.

    ```groovy
        post {
            always { cleanWs() }
            success { archiveArtifacts artifacts: 'target/labori-seis.war', fingerprint: true }
        }
    ```

2. Vaata konsooli lõppu: millises järjekorras käivitusid `always` ja `success` ning mida ütleb `archiveArtifacts`.
3. Paranda: `cleanWs()` läheb plokki `cleanup`, mis käivitub pärast kõiki teisi. Push ja oota buildi.
4. Mõõda control node'il kettaruumi enne ja pärast parandatud buildi.

    ```bash
    df -h /opt/jenkins
    sudo du -sh /opt/jenkins/workspace/* /opt/jenkins/tools 2> /dev/null | sort -h
    ```

> `ERROR: No artifacts found that match the file pattern`: workspace tühjendati enne arhiveerimist.

Ajutine variant ebaõnnestus, sest `always` käivitub enne `success`-i ja WAR oli selleks ajaks kustutatud. Parandatud variant näitab vahet: workspace on tühi, aga WAR on buildi juures alles ja selle fingerprint seob faili konkreetse buildiga. `tools` jääb alles, sest see pole workspace'i osa: Maven laaditakse üks kord node'i kohta, mitte iga buildi jaoks.

✅ **Edasi saad minna, kui** ajutine variant ebaõnnestus arhiveerimisel, parandatud build on roheline, buildi lehel on *Build Artifacts* all `labori-seis.war` ja `labori-seis` workspace on pärast buildi tühi, `tools` (Maven) jääb alles.

📎 **Selle mooduli tõend:** commit'id `k06: options` ja `post`-i parandus; PR-i kirjelduses lause webhooki kohta, polling logi ekraanipilt, `trigger-jenkins.sh` väljund ilma tokenita, kahe buildi põhjuse klassid API-st, `archiveArtifacts` veateade, mõlemad `du` väljundid, `triggers` `OK`.

## Miks see nii töötab

**`H` cron'is.** Sama job'i päring toimub alati samal minutil, sest `H` on räsi job'i nimest.

**Remote trigger.** Remote trigger'iga saab GitHub Actionsi ühendada Jenkinsiga. Self-hosted runner töötab control node'il VPN-i sees ja saab Jenkinsi buildi käivitada kujul `curl -X POST -u kasutaja:API_TOKEN …/build`.

**API token ja crumb.** Paljudes juhendites küsitakse selleks crumb'i (Jenkinsi CSRF-token, mis on seotud veebisessiooniga) ja parooli. API tokeniga ei ole kumbagi vaja (Jenkins 2.96-st alates; vanemates versioonides nõuti crumb'i ka tokeniga), sest token ei ole brauseri sessioon ja CSRF-rünnak seda ei kasuta.

**`post`-tingimused.** `post`-tingimused täidetakse järjekorras `always`, `changed`, `fixed`, `regression`, `aborted`, `failure`, `success`, `unstable`, `unsuccessful`, `cleanup`.

**`abortPrevious`.** `disableConcurrentBuilds(abortPrevious: true)` katkestab vanema buildi, kui käivitatakse uus. See sobib harule, kus on oluline ainult viimane commit. Deploy'le see ei sobi, sest pooleli jäänud paigaldus võib jätta testkeskkonna vahepealsesse olekusse.

**Kettaruum.** Controlleril kasvavad `jobs/*/builds/` (logid ja arhiveeritud artefaktid) ning `fingerprints/`, agendil workspace'id, `tools/` ja Docker image'id. Jenkinsi node monitor viib node'i offline'i, kui `JENKINS_HOME`-i, workspace'i või temp-kausta vaba ruum langeb alla läve (vaikimisi 1 GiB), ja build jääb siis järjekorda nagu agendi kadumisel. Ennetus on Jenkinsfile'is: `buildDiscarder`, `cleanWs()` ja image'ite koristus plokis `cleanup`.

**Buildi põhjus.** Buildi põhjuse klassid (`UserIdCause`, `SCMTriggerCause`, `UpstreamCause`, `TimerTriggerCause`) on samad, mida kasutavad tingimus `triggeredBy` ja API.

Lisaülesanne [5. Actions käivitab Jenkinsi](lisa.md#5-actions-kaivitab-jenkinsi): asendad pollimise Actionsi workflow'ga, mis käivitab Jenkinsi kohe pärast push'i.
