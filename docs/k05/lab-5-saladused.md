---
tags:
  - GitHub Actions
  - secrets
---

# 5. Triggerid, saladused ja environment

Deploy töötab, aga seda ei saa veel hallata: sa ei otsusta, millal see toimub, paroolid on failis `~/k03.env` ja keegi ei tea, mis juhtub, kui kaks inimest vajutavad korraga. Need on küsimused, mida küsib iga audit ja iga intsidendi järelanalüüs.

Lõpus käivitub pipeline ka nupust ja ajakavaga, paroolid on environment'i secret'ites ja `~/k03.env` on control node'ilt kadunud. Korraga käivitub ainult üks deploy ja PR-i vana jooks katkeb, kui tuleb uus.

**Kui teed seda tööl iga päev:** workflow'l on `workflow_dispatch` sisendiga `deploy` ja `schedule`, `gh secret list --env proxmox` näitab nelja nime, environment lubab ainult main'i ja `~/k03.env` on kustutatud. Kui see on sul juba korras, mine otse etappi „[Üks deploy korraga](#uks-deploy-korraga)“.

## Käsitsi käivitus sisendiga

Lisad workflow'le nupu, millega saab deploy käivitada ilma commit'ita. Sisend `deploy` on meie käsitsi kinnitus privaatses repos (vt allpool "Käsitsi kinnitus").

Ilma nuputa tähendab "deploy uuesti" tühja commit'i, mis risustab ajalugu ja käivitab kõik kontrollid. Sisendi kontroll takistab ka juhuslikku klikki: deploy toimub ainult siis, kui keegi kirjutab sõna välja.

1. Lisa `on:` alla [`workflow_dispatch:`](https://docs.github.com/actions/reference/workflows-and-actions/events-that-trigger-workflows) sisendiga `deploy` (`type: string`, `default: ""`).
2. Muuda deploy job'i `if:` nii, et see käivitub kas push'il main'i või siis, kui `inputs.deploy == 'deploy'`.
3. Vii muudatus main'i, siis käivita workflow kaks korda: tühja sisendiga ja sõnaga `deploy`.

    ```bash
    gh pr create --fill --base main && gh pr checks --watch && gh pr merge --merge
    gh workflow run ci --ref main
    gh workflow run ci --ref main -f deploy=deploy
    gh run list -w ci -L 3
    ```

<!-- EKRAANIPILT: Actions → ci → nupp "Run workflow" avatud; näha haru valik ja sisendväli deploy, kuhu on kirjutatud "deploy". Käsitsi käivituse ajal.
<figure markdown="span">
  ![Run workflow dialoog sisendiga deploy](assets/k05_run_workflow.png)
  <figcaption>Joonis L5.9. Käsitsi käivitus: sisend <code>deploy</code> on meie kinnitus.</figcaption>
</figure>
-->

Tühja sisendiga jooks tegi kõik peale deploy, mis tähendab, et nupp sobib ka lihtsalt "ehita uuesti" jaoks. Sõnaga jooks paigaldas sama commit'i uuesti, ja see on kasulik siis, kui keegi muutis serveris midagi käsitsi ja tahad tagasi teadaolevasse seisu. Nupp on näha ainult siis, kui `workflow_dispatch` on vaikeharul: seepärast pidi muudatus enne main'i jõudma.

✅ **Edasi saad minna, kui** tühja sisendiga jooksus on `deploy` hall (*skipped*) ja sõnaga `deploy` töötas see roheliselt; mõlema jooksu link on märkmikus.

## Ajakava

Lisad ajastatud jooksu, mis kontrollib koodi ka siis, kui keegi ei push'i. Uus CVE tuleb sõltuvusse ka ilma commit'ita. Cron on UTC-s ja käivitub ainult vaikeharul.

Repo, mida keegi kuu aega ei puuduta, on kuu aega skännimata. Ajastatud jooks muudab Trivy andmebaasi uuendused nähtavaks, ilma et peaksid ise meeles pidama.

1. Lisa `schedule:` cron'iga tööpäevadeks varahommikul, minut mitte `0` (nt `"17 4 * * 1-5"`).
2. Lisa `image` job'ile `if: github.event_name != 'schedule'`. Deploy jääb siis ise vahele, sest ta vajab image'it.
3. Kontrolli lokaalselt: `actionlint; echo $?`

Minut, mis pole `0`, on viisakus: täistunnil käivitavad oma jooksu tuhanded repod ja GitHub võib neid edasi lükata. Image'i ja deploy'd ajastatud jooks ei vaja, sest kood pole muutunud; uus image samast koodist oleks ainult uus tag ilma uue sisuta. Kui ajastatud jooksu järgmisel päeval pole, vaata kõigepealt, kas `schedule:` on main'is, sest teistel harudel GitHub seda ei loe.

✅ **Edasi saad minna, kui** `actionlint` annab `0`. Esimest ajastatud jooksu, kus töötavad ainult build, compat ja security, näed järgmisel tööpäeval.

## Environment, secret'id ja muutujad

Kolid paroolid failist GitHubi environment'i ja annad need deploy job'ile ainult siis, kui ta töötab main'ilt. Secret on logis `***`, muutuja (`vars`) pole saladus.

Fail `~/k03.env` on täna kolmes kohas: control node'i kodukaustas, runner'i töökaustas ja kõigis varukoopiates. Environment'i secret on ühes kohas, krüpteeritud, ja selle kasutamist näeb deployment'ide ajaloost.

1. Ava *Settings → Environments → New environment* ja loo [environment](https://docs.github.com/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments) `proxmox`: *Deployment branches and tags* → *Selected branches* → `main`.
2. Pane secret'id control node'il failist ([`gh secret set`](https://cli.github.com/manual/gh_secret_set)), mitte brauserisse kleepides.

    ```bash
    for k in DB_ROOT_PASSWORD DB_PASSWORD RABBITMQ_PASSWORD TEACHER_TOKEN; do
      grep "^$k=" ~/k03.env | cut -d= -f2- | gh secret set "$k" --env proxmox
    done
    gh secret list --env proxmox
    ```

3. Pane muutujad.

    ```bash
    for k in REGISTRY OWNER; do gh variable set "$k" --body "$(grep "^$k=" ~/k03.env | cut -d= -f2-)"; done
    gh variable set DEPLOY_ENABLED --body true
    gh variable list
    ```

4. Muuda deploy job'i:
    - `environment: proxmox`
    - `if:` push-tingimusse lisaks `&& vars.DEPLOY_ENABLED == 'true'`
    - `cp ~/k03.env .env` asemel samm, mis kirjutab `.env`-i (`umask 077`, `printf`); väärtused saab samm `env:` kaudu: neli secret'it ja `vars.REGISTRY`, `vars.OWNER`
    - lõppu samm `if: always()`, mis kustutab `.env`
5. Vii muudatus main'i ja kui deploy on roheline, kustuta koopia: `rm ~/k03.env`

<!-- EKRAANIPILT: repo Settings → Environments → proxmox; näha Deployment branches and tags: Selected branches → main ja Environment secrets nimekiri (4 nime, väärtusi ei näe). Pärast environment'i seadistamist.
<figure markdown="span">
  ![Environment proxmox: haru piirang ja secret'ite nimekiri](assets/k05_environment_proxmox.png)
  <figcaption>Joonis L5.10. Environment <code>proxmox</code>: ainult haru main ja neli secret'it.</figcaption>
</figure>
-->

> `compose.yaml` nõuab ka `REGISTRY` ja `OWNER`: ilma nendeta ebaõnnestub `docker compose up` ka siis, kui käivitad ainult app01.

Paroolid jõuavad sammu `env:` kaudu, mitte `run:` teksti sisse, seepärast on logis näha käsk ilma väärtusteta. Kui kirjutaksid `${{ secrets.DB_PASSWORD }}` otse `run:`-i, paneks GitHub väärtuse skripti teksti ja see jääks runner'i ajutisse skriptifaili. `if: always()` koristus eemaldab `.env`-i ka ebaõnnestunud deploy järel. Runner'i töökausta kontroll näitas, et ilma koristuseta jääb fail sinna.

✅ **Edasi saad minna, kui** `gh secret list --env proxmox` näitab nelja nime ilma väärtusteta, deploy käivitub nagu enne, repo lehel on paremal *Deployments → proxmox* ja logis on `.env` sammu käsurida ilma paroolideta.

## Proovi environment'i piiri

Kontrollid, kas haru piirang kehtib. Käivitad deploy harult `k05-actions`, kuigi environment lubab ainult main'i. Ootus on, et GitHub keeldub enne, kui ükski samm runner'il algab.

Kui piirang ei kehti, saab iga haru autor oma koodi koos tootmise paroolidega sinu serveris käivitada.

1. Käivita deploy oma harult.

    ```bash
    gh workflow run ci --ref k05-actions -f deploy=deploy
    gh run watch
    ```

2. Ava jooksu deploy job ja leia teade, miks see ei käivitunud.
3. Kontrolli, et runner'i töökaustas pole `.env`-i: `find ~/actions-runner/_work -name .env -path '*k03-docker*'`

Deploy ebaõnnestus teatega `Branch "k05-actions" is not allowed to deploy to proxmox` ja runner ei saanud tööd üldse. See tähendab, et secret'id ei lahkunud GitHubist: kontroll toimub enne, kui job runner'ile antakse. Tühi `find` kinnitab, et ka eelmise deploy fail on koristatud. Kui deploy oleks käivitunud, puudub environment'il haru piirang või on job'il `environment:` rida puudu.

✅ **Edasi saad minna, kui** deploy job on punane haru piirangu teatega, runner'i logis pole selle jooksu job'i ja `find` on tühi.

## Käsitsi kinnitus: sinu repo järgi

Valid, kuidas deploy enne käivitumist inimese otsust ootab. *Required reviewers* töötab GitHubi Free ja Team plaanil ainult avalikus repos. Self-hosted runner sobib aga ainult privaatsesse reposse.

Need kaks nõuet on vastuolus ja tööl lahendatakse see tavaliselt Enterprise plaaniga. Laboris kasutame nuppu: tulemus on sama, inimene otsustab enne deploy'd, aga kontroll elab workflow's, mitte environment'i seadetes.

| Repo | Kinnitus |
|---|---|
| privaatne (Classroom 50 vaikimisi) | `workflow_dispatch` sisend `deploy` + `DEPLOY_ENABLED=false`, kui tahad ainult käsitsi |
| avalik või Enterprise | environment `proxmox` → *Required reviewers* → sina ise |

*Tabel L5.1. Kinnituse viis repo nähtavuse järgi.*

1. Vaata oma repo nähtavust: `gh repo view --json visibility --jq .visibility`
2. Vali tabelist oma variant ja proovi see läbi: privaatses repos `gh variable set DEPLOY_ENABLED --body false`, siis tühi commit main'i, siis nupp sõnaga `deploy`.
3. Pane `DEPLOY_ENABLED` tagasi `true`-ks.

Muutujaga `DEPLOY_ENABLED=false` jäi push'i deploy vahele, aga nupp töötas: automaatne tee on kinni, käsitsi tee lahti. Nii käitub ka külmutusperiood tööl, kui enne puhkust või suurt üritust ei taheta automaatseid muudatusi. Muutuja on repo seadetes, seega muudad käitumist ilma commit'ita ja muutus on GitHubi auditilogis näha.

✅ **Edasi saad minna, kui** märkmikus on jooksu link, kus deploy jäi vahele või ootas, ja teise jooksu link, kus see käivitus pärast sinu otsust.

## Üks deploy korraga

Paned deploy järjekorda, et kaks jooksu ei teeks sama stack'iga korraga midagi. Kaks paralleelset `docker compose up`-i samas kaustas jätavad stack'i ettearvamatusse seisu. [`concurrency`](https://docs.github.com/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency) grupis on korraga üks töötav ja üks ootav töö.

Kaks kiiret merge'i järjest on tavaline olukord. Ilma järjekorrata võib vanem deploy lõppeda hiljem ja tootmisse jääb eelmine versioon, kuigi mõlemad jooksud on rohelised.

1. Nõuded workflow'le:
    - deploy job'il on concurrency-grupp `deploy-proxmox`, mis ei katkesta poolikut deploy'd
    - igal job'il on `timeout-minutes`
    - workflow tasemel grupp katkestab sama PR-i vana jooksu, aga main'i push'i ja nupu käivitused ei oota ega katkesta üksteist (grupi nimi peab sõltuma sündmusest; avaldiste süntaks: [`${{ }}` operaatorid](https://docs.github.com/actions/reference/workflows-and-actions/expressions))
2. Kontrolli `actionlint`-iga ja vii see main'i, siis käivita kolm deploy'd kiiresti järjest ja vaata, mis igaühega juhtub.

    ```bash
    for i in 1 2 3; do gh workflow run ci --ref main -f deploy=deploy; sleep 5; done
    gh run list -w ci -L 3 --json databaseId,status,conclusion
    ```

3. Kirjuta märkmikku kolme jooksu deploy job'i olek ja algus- ning lõpuaeg (*Actions* → jooks → deploy).
4. PR-il: tee kaks push'i kiiresti järjest harule `k05-actions` ja vaata, mis juhtub esimese PR-jooksuga.

Kui ootav on juba olemas, asendab uus selle ja vana ootaja tühistatakse. See on deploy puhul õige, sest viimane soov on ainus, millel on tähtsust. `cancel-in-progress: false` tähendab, et poolik deploy lõpetatakse alati, sest katkestatud `compose up` on halvim seis. PR-il tühistati vana jooks, sest selle tulemus polnud enam kellelegi vajalik.

✅ **Edasi saad minna, kui** teine deploy oli *Pending*, kuni esimene lõppes, või tühistati kolmanda tõttu, ükski kahest deploy'st ei käivitunud samal ajal, PR-i esimene jooks on *Cancelled* ja `bash autograde/check.sh k05 deploy` annab `OK`.

📎 **Selle mooduli tõend:** jooksude lingid (nupp tühja ja `deploy` sisendiga, haru piirangu keeldumine, kinnitus), `gh secret list --env proxmox` neli nime, `~/k03.env` kustutatud, kolme deploy olekud ja ajad märkmikus; `check.sh k05 deploy` → `OK`.

## Miks see nii töötab

**`gh secret set`.** Kui `gh secret set` küsib väärtust ise või loeb selle failist (`< fail`), ei jää väärtus shelli ajalukku ega lõikelauale. Rida `printf 'väärtus' | gh secret set …` jätab väärtuse shelli ajalukku.

**Compose'i interpoleerimine.** Compose asendab muutujad (`${REGISTRY:?}`, `${OWNER:?}`) kogu failis enne, kui valib käivitatava teenuse.

**Concurrency-grupp.** Workflow tasemel grupp, mille nimes on `github.run_id`, on igal PR-ivälisel käivitusel unikaalne. Seega main'i käivitused ei oota üksteist ja järjekorda hoiab ainult deploy job'i grupp.

**Environment.** Environment on GitHubi objekt, millel on oma secret'id, muutujad ja protection rule'id: haru piirang, kuni 6 ülevaatajat ja ooteaeg kuni 30 päeva. Secret võib olla kuni 48 KB ja environment'is on neid kuni 100.

**Repo tasemel secret.** Repo tasemel secret on seevastu kättesaadav igale workflow'le igas harus. Erand on forgist tulnud PR-id ja Dependaboti käivitused, mis tavalisi secret'eid ei saa. Seetõttu on tootmiskeskkonna paroolid environment'is ja repo tasemel on ainult need secret'id, mida vajab iga job.

**Ajakava avalikus repos.** Avalikus repos lülitab GitHub `schedule:` sündmuse välja, kui repos pole 60 päeva jooksul tegevust olnud. Kui öine jooks on vaikselt kadunud, vaata Actions lehelt, kas workflow on *disabled*.

**Muutujad `vars`.** Muutujad (`vars`) sobivad seadetele, mida tahad muuta ilma commit'ita, näiteks `DEPLOY_ENABLED`. Organisatsiooni repos salvestub nende muutmine organisatsiooni auditilogisse.

**Logi maskeerimine.** GitHub asendab logis secret'i väärtuse tärnidega ainult siis, kui väärtus ilmub täpselt sellisena, nagu see salvestati. Maskeerimine on tekstiasendus, mitte kaitse: iga teisendus, lõikamine või kodeerimine (näiteks base64) annab väärtuse, mida GitHub ei tunne. Sellest tuleneb kaks reeglit. Ära väljasta secret'it logisse, ka mitte kontrolli eesmärgil. Kui secret on mõnes logis teisendatud kujul nähtav, loe see lekkinuks ja vaheta see välja, sest logi võivad lugeda ka teised. `gh run delete` eemaldab logi, kuid ei muuda olematuks seda, et keegi võis logi juba näha.

Kui jõudsid kiiremini: [Lisaülesanded → 14. Sama WAR app01 VM-ile](lisa.md#14-sama-war-app01-vm-ile), viid sama WAR-i app01 VM-ile Ansible'iga, parool secret'ist ajutises failis.
