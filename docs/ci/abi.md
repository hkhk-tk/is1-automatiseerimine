---
tags:
  - veaotsing
---

# Abi: veaotsing

| Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
|---|---|---|---|
| **1. Maven** | | | |
| `docker compose ps` ei näita nelja teenust või `curl /health` ei vasta | `cd k03-docker && docker compose logs --tail 30` | stack on maas: `docker compose up -d` | VM-i taaskäivituse järel käivituvad uuesti ainult teenused, millel on `restart:` poliitika; käsitsi peatatud stack jääb maha |
| `gh repo view` näitab `viewerPermission` `WRITE` või `READ` | repo *Settings* puudub | sul pole admin-õigust: koolitaja annab | runner'i ja environment'i loomine on repo seadete muutmine, mida GitHub lubab ainult adminile |
| `mvn: command not found` või Java 17 | `mvn -v`, `java -version` | `sudo apt-get install -y openjdk-21-jdk-headless maven` | Ubuntu vaikimisi JDK võib olla vanem kui pom'i nõue ja Maven ei tule JDK-ga kaasa |
| `Unknown lifecycle phase` | käsu kirjapilt | faasi nimes on trükiviga, kood 1 | Maven tunneb ainult elutsükli faase ja `plugin:goal` kuju; muu sõna on tema jaoks tundmatu |
| **2. Esimene workflow** | | | |
| käivitust pole üldse | faili tee ja laiend, `branches:` | fail pole `.github/workflows/*.yml` või haru nimi ei klapi | GitHub otsib workflow'sid ainult sellest kaustast ja käivitab need ainult `on:` tingimustele vastavatel sündmustel |
| punane käivitus ilma job'ideta, `Invalid workflow file` | `actionlint` | YAML-i viga: taane või koolon | GitHub ei saa vigasest failist job'e luua, seega pole ühtegi sammu, mille logi näidata |
| `Unable to resolve action …@vX` | action'i *Releases* leht | olematu versioon või lühike SHA | *Set up job* laadib action'id alla enne ühtki sammu ja peatab job'i, kui viidet pole |
| `command not found`, `exit code 127` | sammu `run:` rida | käsk on valesti kirjutatud või runner'il puudub | runner'i image'il on oma PATH ja tööriistad; sinu masina alias'ed ja paketid sinna ei kandu |
| `release version 21 not supported` CI-s | setup-java samm | setup-java puudub või `java-version` pole `"21"` | runner'i image'il on vaikimisi oma Java ja ilma setup-java'ta kasutab Maven seda |
| `actionlint: command not found` | `ls ~/.local/bin`, `echo $PATH` | `~/.local/bin` pole PATH-is | Ubuntu lisab `~/.local/bin` PATH-i ainult siis, kui kaust oli sisselogimisel olemas |
| PR-il pole kontrolli | `on:` plokk | `pull_request:` puudub või `branches:` pole `main` | `branches:` all on PR-i sihtharu, mitte sinu haru nimi |
| `No files were found with the provided path` | build'i logi, `ls target` | WAR-i tee vale või build ebaõnnestus enne; `if-no-files-found: error` teeb selle punaseks | upload-artifact otsib faili runner'i töökaustast ja Maveni ebaõnnestumisel `target/` WAR-i pole |
| **3. Trivy ja õigused** | | | |
| Trivy samm: `Unable to resolve action` | SHA pikkus | SHA pole 40 märki või võeti tag-objekti SHA, mitte `^{}` rida | annotated tag'il on oma SHA, mis pole commit; `uses:` vajab commit'i |
| kokkuvõttes pole Trivy tabelit | sammu tingimus | kokkuvõtte samm pole `if: always()` või `output:` fail on teise nimega | vaikimisi tingimus `success()` jätab sammu vahele, kui Trivy samm ebaõnnestus |
| checkout: `Repository not found` või `403` | *Set up job* → *GITHUB_TOKEN Permissions* | job'il pole `contents: read`: job'i plokk asendab workflow oma | privaatset repot saab kloonida ainult lugemisõigusega token ja `{}` ei anna midagi |
| `k05 hygiene`: Node 20 action'id | `grep -n 'uses:' .github/workflows/*.yml` | `@v4` või vanem major | vanad major'id töötavad Node 20 peal, mida GitHubi runner enam ei toeta |
| `k05 hygiene`: trivy-action täis-SHA | Trivy `uses:` rida | tag'iga või lühikese SHA-ga | tag'i saab ümber suunata ja just seda tehti trivy-action'i intsidendis |
| **4. Image ja deploy** | | | |
| `printenv GIT_SHA` annab `unknown` või tühja | `grep -n GIT_SHA k03-docker/app/Dockerfile` | runtime stage'is puudub `ARG GIT_SHA` + `ENV GIT_SHA=${GIT_SHA}` | multi-stage Dockerfile'is kehtib `ARG` ainult selles stage'is, kus see on öeldud |
| `denied: installation not allowed to Create organization package` | org'i *Packages* seaded | org keelab pakette luua: koolitaja | org'i seade on tugevam kui job'i `packages: write` |
| `denied` / `unauthorized` ghcr.io | job'i `permissions:`, login samm | `packages: write` (image) või `packages: read` (deploy) puudub, login puudub | ghcr.io kontrollib tokeni õigust iga push'i ja pull'i juures eraldi |
| `repository name must be lowercase` | `meta` samm | nimi pole väiketähtedega: `${IMAGE,,}` | `github.repository` hoiab omaniku nime suurtähti, aga registry nõuab väiketähti |
| `actionlint`: `label "labseis" is unknown` | `.github/actionlint.yaml` | label on kirjutamata või vale võtme all | actionlint tunneb ainult GitHubi runner'ite label'eid, sinu omad pead ise ütlema |
| `permission denied … docker.sock` | `groups` runner'i kasutajana | `sudo usermod -aG docker $USER`, siis `sudo ./svc.sh stop && sudo ./svc.sh start` | grupiliikmesus loetakse protsessi käivitamisel, seega töötav teenus uut gruppi ei näe |
| deploy `Waiting for a runner` | `systemctl status 'actions.runner.*'`, `gh api …/actions/runners` | runner maas või `runs-on` label'id ei klapi | GitHub annab job'i ainult runner'ile, millel on kõik `runs-on` label'id ja mis on `online` |
| `unauthorized` pull'il deploy job'is | login samm, `packages: read` | login puudub või õigus puudub | privaatse paketi pull vajab sama palju autentimist kui push |
| app01 `unhealthy` | `docker compose logs app01 \| tail -50` | `.env` paroolid erinevad sellest, millega db01 volume 3. kohtumisel loodi: pane `.env`-i tagasi õiged paroolid. Volume'i kustutamine aitab ainult tühja või taastatavate laboriandmete korral; tootmises tee enne varukoopia ja kontrolli taastamist | MariaDB loeb parooli ainult esimesel käivitusel tühja volume'iga, hiljem muudetud `.env` seda ei muuda |
| `/version` näitab vana commit'i | `docker inspect` image, sammu `env:` | `--no-build` puudub või `APP_IMAGE` pole sammu `env:`-is | ilma `APP_IMAGE`-ita kasutab compose vaikimisi image'it ja `build:` plokk ehitab vana koodi |
| leht annab 502 pärast deploy'd | `docker compose logs web01` | `restart web01` puudub: nginx lahendas vana IP | nginx lahendab nime ainult käivitudes ja uuel konteineril on teine IP |
| PR-il käivitus deploy | deploy `if:` | tingimus ei piira `push` + `main`: self-hosted job PR-il on turvaoht | ilma tingimuseta käivituvad kõik job'id igal `on:` sündmusel, ka PR-il |
| **5. Käsitsi käivitus ja saladused** | | | |
| nuppu *Run workflow* pole | `on:` main'i harus | `workflow_dispatch` on ainult harul, mitte main'is | GitHub näitab nuppu vaikeharu workflow faili järgi |
| `secret … puudub` või väärtus tühi | job'i `environment:`, `gh secret list --env proxmox` | secret on environment'is, aga job ei ütle `environment: proxmox`, või vastupidi | environment'i secret antakse ainult job'ile, mis selle environment'i nimetab; puuduv secret on tühi string, mitte viga |
| `required variable REGISTRY is missing a value` | `.env` samm | samm ei saa `vars.REGISTRY` / `vars.OWNER` | Compose interpoleerib kogu faili enne teenuse valimist ja `:?` nõuab väärtust |
| deploy käivitub, kuigi `DEPLOY_ENABLED=false` | deploy `if:` | `vars.DEPLOY_ENABLED == 'true'` puudub push-tingimusest | muutuja on ainult väärtus; seda loeb ainult tingimus, mis seda nimetab |
| **6. Esitamine** | | | |
| tag pole GitHubis | `git ls-remote --tags origin` | tavaline `git push` tag'e ei lükka: `git push origin k05` | Git lükkab vaikimisi ainult harud, tag tuleb nimetada eraldi |
| parandus pärast esitust | `git log --oneline -1 k05` | tag on vana commit'i peal: `git tag -f k05 && git push -f origin k05` | tag on fikseeritud viide ega liigu uue commit'iga kaasa |
| `gh pr create`: `No commits between main and k05-actions` | `git log main..k05-actions` | kõik on juba main'is: jäta PR vahele | haru muudatused on varasemate PR-idega juba main'i jõudnud |
| `k05 files`: `k03-docker/.env on Gitis` | `git ls-files k03-docker` | `git rm --cached k03-docker/.env` ja parool vahetada | fail lisati enne, kui `.gitignore` seda välja jättis, ja ajaloos on parool alles |
