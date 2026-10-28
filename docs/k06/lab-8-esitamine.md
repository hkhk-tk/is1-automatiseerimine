---
tags:
  - Git
  - Hindamine
---

# 8. Esitamine

Väljalase, mille sisu keegi enne ei vaadanud, toob kaasa unustatud faile, saladusi repos ja tag'i, mis ei viita sellele, mida testiti. Töö jõuab `main`-i, tag `k06` käivitab automaatse hindaja ja tulemus on GitHubi Releases all. Enne seda käivitad samad kontrollid ise ja vaatad, et ükski saladus ega varukoopia pole Gitis. Järjekord on sama nagu igas väljalaskes: kontrolli ise, vaata, mis täpselt välja läheb, ühenda põhiharuga ja märgi seis tag'iga, millele saab hiljem viidata.

**Kui teed seda tööl iga päev:** `gh pr create`, merge ja tag'i push on sul igapäevane töö. Kui see on sul juba korras, mine otse etappi [„Enne esitamist“](#enne-esitamist).

## Vaata, mida automaatne hindaja näeb

Automaatne hindaja ei näe sinu masinat, Jenkinsit ega Nexust. See näeb ainult seda, mis on Gitis commit'itud. Enne kontrollide käivitamist veendud, et kohalik kaust ja repo on samad.

Fail, mis on kettal, aga mitte Gitis, annab kohalikult `OK` ja automaatses hindajas `FAIL`. Vastupidi juhtub siis, kui fail on Gitis vana kujuga ja parandus on ainult töökaustas.

1. Võrdle, mis on kaustas ja mis on Gitis.

    ```bash
    git switch k06-jenkins && git pull
    diff <(git ls-files k06-jenkins | sort) <(find k06-jenkins -type f | sort)
    git status --short k06-jenkins
    ```

2. Kui `diff` näitab faili, mis peab olema esitatud, lisa see; kui see on ajutine, kustuta.

Tühi `diff` ja tühi `git status` tähendavad, et automaatne hindaja näeb täpselt sama, mida sina. Kui `diff` näitab näiteks `k06-jenkins/casc/plugins.txt` ainult paremal pool, siis see fail on olemas, aga commit'imata, ja sandbox-Jenkinsi pluginate nimekiri jääks hindamisel nägemata.

✅ **Edasi saad minna, kui** `diff` ja `git status --short k06-jenkins` on mõlemad tühjad.

## Enne esitamist

Nüüd käivitad kõik kontrollid viimase seisu peal ja vaatad üle failide sisu. Pipeline'i tulemust (roheline build, quality gate, WAR Nexuses) see VPN-i tõttu ei näe, selle kontrollib koolitaja klastris ja PR-i tõenditest.

1. Võrdle Jenkinsfile'i etappide järjekorda: Build → Test → Checkstyle → SonarQube → Quality Gate → Avaldamine (Nexus ‖ Docker image) → Deploy. Failis on ainult credential ID-d, mitte saladused.
2. Käivita automaatse hindaja kontrollid viimase seisu peal. Täpne nimekiri on failis `autograde/TESTS.md`.

    ```bash
    for t in files agent stages triggers quality nexus secrets docker; do
        bash autograde/check.sh k06 "$t"
    done
    ```

3. Kontrolli failide sisu.

    ```bash
    grep -c "stage('" k06-jenkins/Jenkinsfile
    grep -c mvn k06-jenkins/Dockerfile
    git ls-files | grep -E '\.tgz$|\.key$|initialAdminPassword|\.env$'
    python3 -c 'import yaml; yaml.safe_load(open("k06-jenkins/casc/jenkins.yaml"))' && echo yaml ok
    ```

4. Kontrolli image'eid ja töökausta: `docker image ls labori-seis` ja `git status`.
5. Vajuta **Build Now** ja kinnita deploy. Teine järjestikune build peab samuti olema roheline: uus versioon, Nexus ei anna 400.

Üheksa tuleb nii: seitse järjestikust etappi koos `Avaldamine`-ga ja selle kaks paralleelset haru. Tühi `git ls-files | grep` tõestab, et varukoopia ja võtmed jäid repost välja. Teine roheline build järjest kinnitab, et versioonimine ei sõltu juhusest.

✅ **Edasi saad minna, kui** kõik kaheksa kontrolli annavad `OK`, etappe on `9`, Dockerfile'is `0` korda `mvn`, `git ls-files | grep` on tühi, agendil on kuni 3 `labori-seis` image'it ja uusim on sama mis Nexuses ning `git status` on puhas.

## Vii see oma töökohale

Kirjuta faili `k06-jenkins/NOTES.md` 3–5 lauset vastuseks küsimusele: kus sinu töökohal käib build, kvaliteedikontroll, artefakti avaldamine või CI-serveri haldus täna käsitsi ja mis oleks esimene samm seda automatiseerida? Nimeta konkreetne süsteem ja samm, mitte üldine soov. Näiteks: "WAR-i kopeerib Tomcatisse `scp`-ga see, kes parasjagu valves on; esimene samm on Nexuse hosted repo ja versioon kujul `<pom>-<build>-<sha>`".

```bash
wc -w k06-jenkins/NOTES.md
git add k06-jenkins/NOTES.md && git commit -m "k06: ülekanne töökohale" && git push
```

✅ **Edasi saad minna, kui** `k06-jenkins/NOTES.md`-s on 3–5 lauset, neis on üks sinu töökoha süsteem ja üks konkreetne esimene samm ning fail on commit'itud.

## PR, merge ja tag

Automaatne hindaja otsib tag'i `k06` `main`-i commit'il pärast merge'i, mitte haru commit'il.

```bash
git push
gh pr create --base main --head k06-jenkins --title "K6 Jenkins" --body-file ~/pr-k06.md
gh pr merge --merge
git switch main && git pull
git tag k06 && git push origin k06
```

`~/pr-k06.md` on sinu PR-i kirjeldus moodulite tõenditega (vastused, logiread, `du` ja `sha1sum` väljund, sandboxi read, intsidendi tabel). See on repost väljas, ekraanipildid lisad PR-i GitHubis.

> Job ehitab ainult haru `k06-jenkins`. Kui tahad pärast merge'i ehitada ka `main`-i, muuda jobi *Branch Specifier*: sul on folderis Job/Configure õigus ja `when` tingimused lasevad `main`-il avaldada.

Automaatne hindaja käivitub tag'i push'i peale, nii et ainult kohalik tag ei käivita midagi.

✅ **Edasi saad minna, kui** `git ls-remote --tags origin` näitab `k06`.

## Automaatse hindaja tulemus

Tag `k06` käivitab GitHubis automaatse hindaja. Tulemus on paari minuti pärast: repo → **Releases** → viimane `submit/…`, iga mitteläbinud kontrolli juures on põhjus. Kontrollitakse, kas failid on olemas, kas Jenkinsfile'is on õiged etapid ja quality gate, kas Nexus ja triggerid on seadistatud ja kas saladused on Gitist väljas.

Kui tulemus erineb sinu kohalikust kontrollist, on põhjus peaaegu alati see, et tag viitab teisele commit'ile kui sinu töökaust. Vaata `git log --oneline -1 k06` ja võrdle `main`-iga.

✅ **Edasi saad minna, kui** Releases näitab tulemust 100 lähedal.

## Tõendid moodulite kaupa

Märgi iga rida alles siis, kui tõend on PR-i kirjelduses, mitte siis, kui töö on tehtud: koolitaja näeb ainult PR-i.

- [ ] 1. Agent ja esimene pipeline: avaleht, agendi `systemctl`/`journalctl`, kolm vastust skripti kohta, neli vastust `kes-olen` jobist, agendi katkestuse kaks lauset, Credentials leht, Graph View, `stages` + `agent` `OK`
- [ ] 2. Triggerid, options ja post: lause webhooki kohta, polling logi, `trigger-jenkins.sh` väljund, kahe buildi põhjuse klassid, `archiveArtifacts` viga ja parandus, kaks `du`, `triggers` `OK`
- [ ] 3. Quality gate ja Nexus: Sonari projekt, quality gate'i tingimused, ebaõnnestunud tingimus, Nexuse logirida ja ajad, kolm `sha1sum` rida, Nexus Browse, redeploy katse `400`, `quality` + `nexus` + `secrets` `OK`
- [ ] 4. Image, paralleel ja deploy: `docker image ls` + `docker inspect`, `parallel` ajad, proovi-jobi Graph View, `/version`, kolm buildi (SCM, Paigalda, Abort), konteineri räsi ja healthcheck, `files` + `docker` `OK`
- [ ] 5. Jenkins koodina: `casc/plugins.txt`, `casc/jenkins.yaml`, `Cannot run program "mvn"`, Maveni logiread, `Git client` sõltuvused, uuendatavad pluginad, viis vastust `klass-jenkins.yaml` kohta, drift'i lause, vigase faili logirida
- [ ] 6. Õigused, varundus ja taaste: naabri 403, `vaatleja` vaade, `du` + `ls -l` enne ja pärast `chmod`-i, `plugins.txt` diff, taastatud Jenkinsi `credential loetav`, võtmeta taaste tulemus, sandbox ja arhiiv kustutatud
- [ ] 7. Neli punast buildi: `fix(...)` commit'id, logiread, agendi restart'i kontroll, kaks Nexuse versiooni, intsidendi tabel
- [ ] 8. Esitamine: tühi `diff`, `NOTES.md` ülekande lausetega, tag `k06`, Releases tulemus

✅ **Edasi saad minna, kui** kõik linnukesed on tehtud ja PR-i kirjelduses on iga mooduli tõend.

📎 **Selle mooduli tõend:** commit `k06: ülekanne töökohale`, tag `k06` `main`-i peal, PR tõenditega ja automaatse hindaja tulemus GitHubi Releases all.

## Pärast esitamist: agent ja testkonteiner maha

7. kohtumine Jenkinsit ei kasuta ja koolitaja lülitab Jenkinsi, Sonari ja Nexuse pärast 6. kohtumise järeltööde tähtaega välja. Agent ja testkonteiner võtavad seni control node'i mälu, mida 7. kohtumisel vajad.

Kui Releases on roheline ja PR on koolitajale näha, eemalda testkonteiner ja peata agent. Kontrolli ka, et sandbox-Jenkins on kustutatud (moodul Õigused, varundus ja taaste).

```bash
docker rm -f labseis-ci
sudo systemctl disable --now jenkins-agent
docker ps --format '{{.Names}}'
```

✅ **Edasi saad minna, kui** `docker ps` on tühi ja `systemctl is-active jenkins-agent` vastab `inactive`.

## Miks see nii töötab

**Automaatse hindaja piir.** Automaatne hindaja töötab GitHubis ja näeb ainult repot, sest Jenkins, Sonar ja Nexus on VPN-i taga. See piir on teadlik: automaatne hindaja kontrollib, kas fail on õige kujuga, koolitaja kontrollib PR-i tõendite põhjal, kas lahendus ka töötas.

**Staatiline ja käitumise kontroll.** Staatiline kontroll (lint, saladuste otsing) käivitatakse igal PR-il, käitumise kontroll (integratsioonitest, smoke test) eraldi keskkonnas.

**Tag ja väljalase.** Tavapraktikas väljalaske tag'i ümber ei tõsteta. Sellel kursusel on erand esitamise parandus: uus commit `main`-i ja seejärel `git tag -f k06 && git push -f origin k06`, nagu teiste päevade esitamisel.

**Olek failides.** Jenkins on tavaline Linuxi teenus, mille olek on failides. Kui tead, millised failid on asendamatud ja kellel on õigus neid lugeda, saad Jenkinsit hallata nagu iga teist serverit.
