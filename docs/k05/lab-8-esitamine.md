---
tags:
  - Git
  - Hindamine
---

# 8. Esitamine

Ülevaataja näeb ainult repot ja Actionsi ajalugu. Kui kontroll käis ainult sinu masinas või parool jäi faili, ei tea ta sellest enne, kui see kuskil välja tuleb.

Lõpus on töö `main`-is, `NOTES.md`-s on kirjas, kus sinu töökohal sama töö täna käsitsi käib, tag `k05` on käivitanud automaatse hindaja ja tulemus on GitHubi Releases all.

**Kui teed seda tööl iga päev:** `for c in files actionlint build structure deploy hygiene; do bash autograde/check.sh k05 "$c"; done` annab kuus `OK`-d ja `gh secret list --env proxmox` näitab nelja nime. Kui see on sul juba korras, mine otse etappi „[Esimene Dependaboti PR](#esimene-dependaboti-pr)“.

## Enne esitamist

Käivitad repo juurkaustas kõik kontrollid, mida automaatne hindaja ja sinu pipeline teevad, ning otsid saladusi kohtadest, kuhu need võisid jääda.

```bash
mvn -B -q verify; echo "mvn $?"
actionlint; echo "actionlint $?"
git ls-files | grep -E '(^|/)\.env$|k03\.env|\.pem$|id_rsa'
test -e ~/k03.env && echo "k03.env alles" || echo "k03.env kustutatud"
for c in files actionlint build structure deploy hygiene; do bash autograde/check.sh k05 "$c"; done
```

Seejärel GitHubi pool: secret'id, Dependabot, runner ja tühi `git status`.

```bash
gh secret list --env proxmox
gh pr list --author 'app/dependabot' --state all -L 5
gh api 'repos/{owner}/{repo}/actions/runners' --jq '.runners[] | [.name, .status] | @tsv'
git status --short
```

> Kui Dependabot pole veel ühtegi PR-i avanud, vaata *Insights → Dependency graph → Dependabot*: seal on viimase kontrolli aeg ja võimalik viga failis `.github/dependabot.yml`.

Tühi `git ls-files | grep` tähendab, et ükski tuntud saladusfail pole Gitis. See ei tõesta, et saladusi pole üldse, aga `hygiene` kontroll otsib lisaks tokenite ja paroolide mustreid workflow failidest. `k03.env kustutatud` kinnitab, et control node'il on paroolid ainult seal, kus stack neid vajab. Kui mõni kontroll annab siin `FAIL`, annab sama ka automaatne hindaja, seega paranda kohe.

✅ **Edasi saad minna, kui** `mvn` ja `actionlint` annavad `0`, `git ls-files | grep` on tühi, `k03.env kustutatud`, kõik kuus kontrolli annavad `OK`, `gh secret list` näitab nelja nime, runner on `online` ja `git status` on tühi.

## Esimene Dependaboti PR

Vaatad läbi ühe Dependaboti PR-i nii, nagu teeksid seda tööl iga nädal: mida see muudab, mida CI selle kohta ütles ja kas julged selle merge'ida. Dependaboti PR-i käivitus saab ainult lugemisõigusega tokeni ega näe Actionsi secret'eid: Dependabotil on oma secret'id.

Automaatne uuendus, mida keegi ei vaata, on sama risk kui uuendus, mida ei tehta: üks muudab tootmist ilma otsuseta, teine jätab augud lahti. Sinu töö on otsustada, CI töö on anda otsuseks andmed.

1. Leia avatud Dependaboti PR. Kui ühtegi pole, käivita kontroll käsitsi: *Insights → Dependency graph → Dependabot* → ökosüsteemi rida → *Check for updates*.

    ```bash
    gh pr list --author 'app/dependabot' --state open
    ```

2. Vaata ühe PR-i muudatust ja kontrolle (asenda `<nr>`).

    ```bash
    gh pr diff <nr> | grep -E '^[-+][^-+]'
    gh pr checks <nr>
    ```

3. Kirjuta märkmikku: mis versioon mis versiooniks muutus, kas see on patch, minor või major, kas kõik kontrollid on rohelised ja sinu otsus (merge või mitte) ühe lausega.
4. Kui otsustasid merge'ida, tee seda ja kontrolli deploy'd: `/version` peab võrduma uue `origin/main`-iga.

Action'i PR-is muutub SHA ja kommentaar koos, Maveni PR-is versiooninumber pom'is. Deploy PR-il ei käivitunud, sest `if:` lubab ainult push'i main'i, seega ei saanud Dependaboti kood sinu serverisse ilma sinu merge'ita. Major-versiooni hüpe on koht, kus loed muudatuste logi, isegi kui CI on roheline, sest testid ei kata kogu käitumist. Kui ükski PR ei tulnud ka pärast käsitsi kontrolli, on kõik juba uusimad või on `dependabot.yml` vigane: sama lehe viga ütleb, kumb.

✅ **Edasi saad minna, kui** märkmikus on ühe Dependaboti PR-i muudatus, kontrollide tulemus ja sinu otsus, või kirje, et Dependabot kontrollis ja uuendusi polnud.

## Sinu töökohal

Täna ehitasid ahela, kus commit jõuab testide, skänni ja kontrolliga tootmisse ning ebaõnnestunud deploy teeb ise rollback'i.

Kirjuta repo juurkausta `NOTES.md`-sse pealkirja `## K5: sinu töökohal` alla 3–5 lauset: kus sinu töökohal see täna käsitsi käib ja mis oleks esimene samm automatiseerida? Nimeta protsess (näiteks rakenduse uuendus, konfiguratsiooni muudatus, sertifikaadi vahetus), kes seda praegu teeb ja millise kontrolliga, ning esimene job või workflow, mille sa teeks. Hostinimesid, IP-sid ja saladusi sinna ei kirjuta.

```bash
awk '/^## K5: sinu töökohal/{f=1;next} /^## /{f=0} f' NOTES.md | grep -o '[.?!]\( \|$\)' | wc -l
git add NOTES.md && git commit -m "notes: K5 sinu töökohal" && git push
```

✅ **Edasi saad minna, kui** `wc -l` annab 3–5 ja commit on harus `k05-actions`.

## PR, merge ja tag

Viid oma haru viimast korda main'i ja paned tag'i, mis käivitab automaatse hindaja. Tag peab olema `main`-i peal pärast merge'i. Kui `git log` näitab, et `k05-actions`-il pole main'ist erinevaid commit'e, jäta PR-i rida vahele.

Tag, mis on vale commit'i peal, tähendab, et automaatne hindaja hindab teist koodi kui see, mis tootmises käivitub. Seepärast teed tag'i alles pärast `git pull`-i main'il.

```bash
git switch k05-actions && git merge main && git push
git log --oneline main..k05-actions
gh pr create --fill --base main && gh pr checks --watch && gh pr merge --merge
git switch main && git pull
git tag k05 && git push origin k05
```

> Parandus pärast esitust: uus commit `main`-i, siis `git tag -f k05 && git push -f origin k05`.

`git ls-remote --tags origin` näitab, millised tag'id on GitHubis. Viimane merge käivitas veel ühe deploy, seega tootmises töötab täpselt see commit, millele tag osutab. Kui deploy pärast viimast merge'i ebaõnnestus, paranda see enne automaatse hindaja tulemuse vaatamist, sest koolitaja vaatab ka Actions vaadet.

✅ **Edasi saad minna, kui** `git ls-remote --tags origin` näitab `k05` ja main'i viimane deploy on roheline.

## Automaatse hindaja tulemus

Tag `k05` käivitab GitHubis automaatse hindaja. See kontrollib, kas vajalikud failid on olemas, kas workflow'd läbivad actionlinti, kas build, Trivy, image ja deploy on workflow's olemas ning kas saladused on Gitist väljas. Tulemus on paari minuti pärast: repo → **Releases** → viimane `submit/…`, iga mitteläbinud kontrolli juures on põhjus. Testide nimekiri on repos failis `autograde/TESTS.md`. Automaatne hindaja näeb ainult faile: kas pipeline oli roheline ja deploy toimus, näeb koolitaja sinu Actions vaatest ja Labori seisust.

Kui tulemus erineb sellest, mida said lokaalselt, on peaaegu alati põhjus selles, et tag on teise commit'i peal kui sinu töökaust. Võrdle `git rev-parse k05` ja `git rev-parse origin/main`: need peavad olema samad.

✅ **Edasi saad minna, kui** Releases näitab tulemust 100 lähedal.

## Tõendid moodulite kaupa

Viimane kontroll on sinu enda märkmik. Iga rida allpool on üks moodul ja selle tõendid samas järjekorras, nagu need moodulite lõpus olid. Kui mõni puudub, leiad enamiku *Actions* vahekaardilt, sest tõendid on käivituste lingid ja need jäävad alles.

- [ ] Maven: versioonid, testide arv ja katvus, `spring-core` versioon, WAR-i suurus, major version'i viga, mäluviga ja AI hinnang, JDK 17 viga, värske kloon ja offline-build
- [ ] Esimene workflow: runner'i image ja Java, kahe punase käivituse ja katkise YAML-i lingid, roheline PR, `unzip -l`, `failure()` käivituse link, sammude kestused, `timeout-minutes` arvutus ja prooviks käivitatud workflow
- [ ] Trivy, matrix ja õigused: Trivy leiud, ühe leiu jälg pom'ini, matrix'i ennustus ja tulemus, vahemälu kirjed, *GITHUB_TOKEN Permissions*, SHA-d, `dependabot.yml` nelja ökosüsteemiga, db01 `FROM` digest'iga
- [ ] Image ja deploy: sama SHA, ghcr.io tag = sha7, `CACHED`, runner `online`, `docker inspect`, `/version` = commit, runner'i töökaust, muudatus haru kaudu
- [ ] Triggerid, saladused ja environment: nupu ja kinnituse käivitused, haru piirangu keeldumine, neli secret'it, `~/k03.env` kustutatud, kolme deploy olekud ja ajad
- [ ] Health check ja rollback: `verify-deploy` action, punane deploy rollback'iga, revert ja roheline deploy, katkestuse ajajoon
- [ ] Katkine pipeline: `fix(ci)` commit'id, nelja vea tabel, roheline deploy, `runner-valve.sh`
- [ ] Esitamine: Dependaboti PR-i otsus, `NOTES.md` jaotis `## K5: sinu töökohal`, tag `k05`, Releases tulemus

✅ **Edasi saad minna, kui** kõik linnukesed on tehtud.

📎 **Selle mooduli tõend:** Dependaboti PR-i otsus märkmikus, `NOTES.md` jaotis `## K5: sinu töökohal` 3–5 lausega, tag `k05` `main`-i peal ja automaatse hindaja tulemus GitHubi Releases all.

## Pärast esitamist: stack maha

6. kohtumisel on control node Jenkinsi agent: seal käivad Maven, `docker build`, testkonteiner ja sinu sandbox-Jenkins. Control node'i mälu on 4 GB ja 3. kohtumise stack võtab sellest üle gigabaidi. 6. ja 7. kohtumine stacki ei vaja.

Kui Releases on roheline ja `main`-i viimane deploy on roheline, võta stack maha. `down` ilma `-v`-ta eemaldab konteinerid, aga jätab volume'id ja image'id alles, nii et `up -d` toob sama oleku tagasi. `stop`-ist ei piisa: `restart`-poliitikaga konteinerid käivituvad control node'i taaskäivitusel uuesti.

```bash
docker compose ls
docker compose -p <projekti nimi> down
docker ps --format '{{.Names}}'
```

✅ **Edasi saad minna, kui** `docker compose ls` stacki enam ei näita ja `docker ps` ei näita ühtegi stacki teenust.
