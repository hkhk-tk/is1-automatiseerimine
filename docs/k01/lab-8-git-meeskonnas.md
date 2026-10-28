---
tags:
  - Git
  - GitHub
---

# 8. Git meeskonnas

Kaks inimest muudavad sama `check.sh`-i, keegi lükkab kogemata üles saladuse, mõne päeva pärast selgub, et kontroll ei tööta enam, ja tootmises olev versioon vajab turvaparandust ilma pooleliolevate muudatusteta. Kõigil neil juhtudel on Git ainus koht, kust näed, mis, millal ja miks muutus. Seni oled repos üksi; nüüd teed need olukorrad läbi oma repos kahe rolliga: sina ja "kolleeg".

Töötad kaustas `~/labori-seis` ja harul `k01-bash`. Uued harud tehakse `k01-bash`-ist ja PR-id lähevad `k01-bash`-i, mitte `main`-i: `main` saab töö alles [Esitamise](lab-9-esitamine.md) lehel ja tag `k01` tuleb sinna nagu ennegi. Ühtegi käsku `git push -f` siin vaja pole. Selles kursuse töövoos ei kirjutata `main`-i ajalugu ümber, sest automaatse hindaja tag ja PR-id osutavad selle commit'idele.

**Kui teed seda tööl iga päev:** `gh pr list --state merged` näitab sinu PR-i `k01-runbook`, konflikt on lahendatud põhjendusega merge-commit'is ja `git log --oneline -1 -- .gitignore` näitab commit'i `gitignore: k01-bash/*.env` (etapi „Kontrolli oma repo ajalugu“ nõue). Kui see on sul juba korras, mine otse etappi [„Hotfix release-harule“](#hotfix-release-harule).

## Loe ajalugu, enne kui seda muudad

Enne kui hakkad harusid tegema, vaata, mida su repo juba teab.

1. Vaata harude kuju ja oma tänast ajalugu.

    ```bash
    cd ~/labori-seis
    git log --oneline --graph --all -15
    git log --oneline -- k01-bash/services/mariadb.sh
    ```

2. Leia, kes ja millal muutis rida, mis lubab andmebaasi kasutajal tulla app01-st.

    ```bash
    git blame k01-bash/services/mariadb.sh | grep "'%'"
    git show --stat <hash>
    ```

`git log -- <fail>` näitab ainult neid commit'e, mis seda faili puudutasid, nii et viie teenuse skriptist saad eraldi muudatuste logi. `git blame` peaks näitama sinu kolme vea parandamisel tehtud `fix(mariadb)` commit'i. Kui seal on starteri esimene commit, tegid paranduse mujal või kirjutasid kogu faili üle, ja siis ei ütle ajalugu enam, miks rida just selline on.

✅ **Edasi saad minna, kui** `git blame` näitab `'%'` rea juures sinu `fix(mariadb)` commit'i ja `NOTES.md`-s on selle hash.

## Haru, PR ja ülevaatus

Kirjutad `check.sh`-ile runbook'i omaette harul ja tood selle `k01-bash`-i PR-iga. Autor oled sina, "kolleeg" on ülevaataja, kelle kommentaari kirjutad ise `gh pr review`-ga. Nii käid läbi sama tee, mis meeskonnas.

1. Tee uus haru värskest `k01-bash`-ist.

    ```bash
    git switch k01-bash && git pull
    git switch -c k01-runbook
    ```

2. Kirjuta `k01-bash/RUNBOOK.md`:
    - neli pealkirja `## Kood 0`, `## Kood 1`, `## Kood 2`, `## Kood 3`
    - iga koodi all: mida kasutaja sel ajal näeb ja esimene käsk, mille käivitad
    - koodide 1 ja 2 all: millise käsuga taastad (`./deploy-all.sh <host>`) ja kust näed, et taastumine õnnestus
    - koodi 3 all: miks see pole stacki rike ja mida kontrollida control node'il
3. Kontrolli, commit'i ja lükka haru üles.

    ```bash
    grep -c '^## Kood' k01-bash/RUNBOOK.md
    git add k01-bash/RUNBOOK.md && git commit -m "runbook: check.sh koodid 0–3"
    git push -u origin k01-runbook
    ```

4. Ava PR `k01-bash`-i vastu ja vaata see üle.

    ```bash
    gh pr create --base k01-bash --head k01-runbook --title "Runbook check.sh koodidele" \
        --body "Mida teha koodide 0–3 korral. Ülevaatajale: kas koodi 3 juhis on piisav?"
    gh pr diff
    gh pr review --comment -b "Kood 2: lisa, kuidas näha, milline kiht on punane"
    ```

5. Paranda kommentaari põhjal, push'i ja merge'i.

    ```bash
    git commit -am "runbook: kood 2, kihi leidmine" && git push
    git switch k01-bash
    gh pr merge k01-runbook --merge --delete-branch
    git pull
    ```

> GitHub ei lase oma PR-i kinnitada (`--approve`), seepärast on ülevaatus kommentaar. Meeskonnas kinnitab teine inimene.

`--delete-branch` kustutab haru nii GitHubist kui ka sinu masinast. `git pull` on vajalik, sest merge toimus GitHubis. `closes #N` sõnumis ei sulge issue'd siin, sest GitHub sulgeb issue ainult siis, kui commit jõuab vaikeharule ehk `main`-i.

✅ **Edasi saad minna, kui** `gh pr list --state merged` näitab sinu PR-i ja `git log --oneline --graph -4` näitab merge-commit'i `k01-bash`-is.

## Kaks muudatust samale reale

Nüüd tekitad meelega konflikti. Kaks "inimest" muudavad `check.sh`-is sama rida: üks tahab lühemat pordi timeout'i, et timer lõpetaks kiiremini, teine pikemat, sest Rocky VM vastab pärast reboot'i aeglaselt.

Three-way merge võrdleb mõlemat haru ühise eellasega; kui mõlemad muutsid sama rida, jätab Git otsuse sulle. `git checkout --ours`/`--theirs` pimesi kasutades kaob teise poole põhjendus vaikselt.

Sinu haru on `k01-timeout-kiire`, kolleegi oma `k01-timeout-aeglane`.

1. Tee kaks haru ja muuda kummaski `port()` funktsiooni timeout'i.

    ```bash
    git switch -c k01-timeout-kiire k01-bash
    sed -i 's/timeout 3 bash/timeout 2 bash/' k01-bash/check.sh
    git commit -am "check.sh: pordi ajapiir 2 s, timer lõpetab kiiremini"
    git switch -c k01-timeout-aeglane k01-bash
    sed -i 's/timeout 3 bash/timeout 5 bash/' k01-bash/check.sh
    git commit -am "check.sh: pordi ajapiir 5 s, Rocky vastab pärast reboot'i aeglaselt"
    ```

2. Merge'i mõlemad `k01-bash`-i. Esimene läheb puhtalt, teine annab konflikti.

    ```bash
    git switch k01-bash
    git merge k01-timeout-kiire
    git merge k01-timeout-aeglane
    git status --short
    git diff
    ```

3. Lahenda konflikt failis `k01-bash/check.sh`:
    - failis on üks väärtus ja ükski marker (`<<<<<<<`, `=======`, `>>>>>>>`) pole alles
    - väärtus on põhjendatud: arvuta, kui kaua kestab halvimal juhul viie pordi kontroll ja kas see mahub timeri intervalli
    - `bash -n` ja ShellCheck vaikivad, `./check.sh` annab koodi 0
    - merge-commit'i sõnumis on otsus ja põhjus
4. Lõpeta merge ja vaata tulemust.

    ```bash
    grep -nE '^(<<<<<<<|=======|>>>>>>>)' k01-bash/check.sh
    git add k01-bash/check.sh && git commit
    git log --oneline --graph -6
    git push && git branch -d k01-timeout-kiire k01-timeout-aeglane
    ```

> Kui esimene `git diff` oli tühi, on sinu `port()` timeout teistsugune: muuda `sed`-is `timeout 3` oma väärtuseks ja alusta uuesti.

`git status` näitas faili olekus `UU` ehk "mõlemad muutsid". Esimene merge oli fast-forward, sest `k01-bash` polnud vahepeal liikunud. Teine pidi kaks ajalugu kokku panema ja jäi samale reale. Graafis on nüüd kaks haru, mis saavad kokku sinu merge-commit'is, ja selle sõnum on ainus koht, kus on kirjas, miks valisid just selle väärtuse. GitHubis näeksid sama olukorda PR-i juures teatena "This branch has conflicts", ja lahendus käib samamoodi.

✅ **Edasi saad minna, kui** markerite `grep` on tühi, `./check.sh` annab koodi 0 ja `git log --graph` näitab merge-commit'i sinu põhjendusega.

## Rebase oma harul

Teed väikese muudatuse omaette harul, vahepeal liigub `k01-bash` edasi. Tood oma haru `k01-bash`-i otsa `git rebase`-iga ja vaatad, mis commit'idega juhtub.

Rebase loob sinu commit'id uue vanemaga uuesti, nii et hash'id muutuvad. Kui keegi teine on vana hash'iga commit'i juba võtnud, toob järgmine `pull` topelt-commit'id. Seepärast reegel: **rebase ainult harul, mis on ainult sinu oma**, mitte `k01-bash`-il ega `main`-il.

Sinu haru on `k01-runbook-kood3`. Kolleegi töö on commit, mis sel ajal `k01-bash`-i jõuab.

1. Tee haru ja lisa runbook'i koodi 3 alla üks konkreetne näide. Rida läheb faili lõppu; kui `## Kood 3` pole sinu failis viimane, lisa see redaktoriga.

    ```bash
    git switch -c k01-runbook-kood3
    echo "- Näide: journal'is UNKNOWN: fail 'hosts' puudub. Kontrolli: ls -l k01-bash/hosts" >> k01-bash/RUNBOOK.md
    tail -3 k01-bash/RUNBOOK.md
    git commit -am "runbook: koodi 3 näide, hosts puudub"
    ```

2. Kolleegi rollis liiguta vahepeal `k01-bash`-i edasi: vaheta harule `k01-bash`, lisa `k01-bash/NOTES.md`-sse üks rida pordi ajapiiri väärtuse ja põhjusega ning commit'i.

    ```bash
    git switch k01-bash
    git commit -am "notes: pordi ajapiiri otsus"
    git log --oneline --graph k01-bash k01-runbook-kood3 -5
    ```

3. Rebase'i oma haru, võrdle hash'i enne ja pärast, ja too see `k01-bash`-i.

    ```bash
    git switch k01-runbook-kood3 && git rev-parse --short HEAD
    git rebase k01-bash && git rev-parse --short HEAD
    git switch k01-bash && git merge --ff-only k01-runbook-kood3
    git push && git branch -d k01-runbook-kood3
    ```

> Kui oled oma haru juba üles lükanud, vajab see pärast rebase'i `git push --force-with-lease origin <sinu haru>`. Ainult sellele harule, mitte kunagi `main`-ile ega `k01-bash`-ile.

Kaks `rev-parse` väljundit erinevad, kuigi commit'i sisu ja sõnum on samad. `--ff-only` tõestab, et ajalugu on nüüd sirge: merge ei pidanud midagi kokku panema ja keeldub, kui peaks. Kui oleksid teinud tavalise merge'i, oleks graafis üks merge-commit rohkem, aga ükski hash poleks muutunud.

✅ **Edasi saad minna, kui** kaks hash'i on `NOTES.md`-s, `git log --oneline --graph -3` on sirge ja haru `k01-runbook-kood3` on kustutatud.

## Saladus, mis jõudis commit'i

Simuleerid kõige sagedasemat Giti intsidenti: konfifail tokeniga läheb `git add .`-iga commit'i, sest selle nimi pole `.gitignore`-is. Kolleegi rolli siin pole, eksid sina ise.

`.gitignore` kaitseb ainult failinimesid, mida keegi on ette näinud. Uus fail uue nimega (`prod.env`, `token.txt`, `backup.sql`) läheb `git add .`-iga läbi. Kui commit on push'itud, on saladus GitHubis, iga klooni ajaloos ja võib-olla CI logis. Sellest hetkest on küsimus selles, kui kiiresti saad saladuse vahetada.

1. Alusta puhtalt: `git status --short` peab olema tühi, vajadusel commit'i `NOTES.md`.
2. Tee ajutine haru ja "kogemata" commit. Ära seda haru push'i: `git push` viiks tokeni GitHubi ja siis aitaks ainult tokeni vahetamine.

    ```bash
    git switch -c saladus-proov
    printf 'API_TOKEN=proov-%s\n' "$RANDOM$RANDOM" > k01-bash/prod.env
    git add . && git commit -m "prod seaded"
    ```

3. "Märka" viga ja eemalda fail Gitist nii, nagu seda tavaliselt tehakse.

    ```bash
    git rm --cached k01-bash/prod.env
    echo 'k01-bash/*.env' >> .gitignore
    git add .gitignore && git commit -m "prod.env Gitist välja"
    git check-ignore -v k01-bash/prod.env
    ```

4. Vaata, kas saladus on ajaloost kadunud.

    ```bash
    git ls-files k01-bash/prod.env
    git log --oneline -- k01-bash/prod.env
    git show HEAD~1:k01-bash/prod.env
    ```

5. Koristus: `git switch k01-bash && git branch -D saladus-proov && rm k01-bash/prod.env`

`git ls-files` on tühi ja automaatse hindaja `secrets`-test läbiks, aga `git show HEAD~1:…` näitab tokenit ikka. `git rm --cached` eemaldab faili järgmisest commit'ist, mitte ajaloost. Kui see haru oleks olnud GitHubis, oleks ainus parandus tokeni vahetamine, sest ajaloo ümberkirjutamine ei jõua kloonideni, mis on juba tehtud. Pärast `branch -D`-d on commit sinu masinas veel `git reflog`-i kaudu kättesaadav, kuni Git selle prügikoristusega eemaldab.

✅ **Edasi saad minna, kui** `NOTES.md`-s on kirjas, mida `git show HEAD~1:…` näitas ja miks `git rm --cached` ei piisa, ning haru `saladus-proov` on kustutatud.

## Kontrolli oma repo ajalugu

Proovist teadsid, kuhu saladus läks. Nüüd kontrollid oma repot: kas `secrets.env` või selle paroolid on kunagi mõnda commit'i jõudnud, ka siis, kui praegune seis on puhas.

Automaatne hindaja ja `git ls-files` vaatavad ainult praegust seisu. Parool, mis oli kolm commit'i tagasi failis ja siis eemaldati, on GitHubis endiselt nähtav igaühele, kes repot näeb. Ainult ajaloo otsing ütleb, kas pead midagi vahetama.

1. Otsi faili ja parooli väärtust kogu ajaloost, kõigilt harudelt.

    ```bash
    git log --all --oneline -- k01-bash/secrets.env
    git log --all --oneline -S "$(grep '^DB_PASSWORD=' k01-bash/secrets.env | cut -d= -f2)"
    ```

2. Lisa haru `k01-bash` `.gitignore`-i rida `k01-bash/*.env` ja kontrolli, et näidisfailid jäävad jälgituks.

    ```bash
    echo 'k01-bash/*.env' >> .gitignore
    git check-ignore -v k01-bash/secrets.env
    git ls-files k01-bash/secrets.env.example
    git commit -am "gitignore: k01-bash/*.env" && git push
    ```

`-S` otsib commit'e, mis lisasid või eemaldasid antud teksti, ja jätab väärtuse ise ekraanilt välja. Mõlemad otsingud peavad olema tühjad. Kui mõni neist annab commit'i, on parool olnud repos ja stacki jaoks kirjutatud `secrets.env` tuleb vahetada nagu lisaülesandes [18. Parooli vahetus skriptiga](lisa.md#18-parooli-vahetus-skriptiga), isegi kui fail on praegu ignoreeritud.

✅ **Edasi saad minna, kui** mõlemad `git log` otsingud on tühjad, `check-ignore` näitab reeglit, mis `secrets.env`-i välja jätab, ja `secrets.env.example` on endiselt `git ls-files`-is.

## Katkestus poole töö pealt

Alustad `NOTES.md`-sse selle lehe kokkuvõtet ja siis tuleb kiire töö: kolleeg (skript `scripts/k01-bisect.sh` ja tema haru `bisect-proov`) palub uurida, miks tema harul `check.sh` ei tööta. Tema skript keeldub, kui sul on commit'imata muudatusi. `git stash` paneb poolelioleva töö kõrvale.

1. Kontrolli, et stack on praegu roheline, sest see on bisect'i "hea" seis.

    ```bash
    (cd k01-bash && ./check.sh > /dev/null); echo "kood $?"
    ```

2. Kirjuta `NOTES.md`-sse pealkiri "Git meeskonnas" ja paar rida. Ära commit'i.
3. Käivita kolleegi skript, pane töö kõrvale ja proovi uuesti.

    ```bash
    bash scripts/k01-bisect.sh
    git stash push -m "NOTES git meeskonnas pooleli"
    git stash list && git status --short
    bash scripts/k01-bisect.sh
    ```

> Stash võtab vaikimisi ainult jälgitavad failid. Uus fail, mida pole veel `git add`-itud, vajab `git stash push -u`.

Esimene käivitus keeldus, teine tegi haru `bisect-proov` ja vahetas sinu sinna. `git status` oli vahepeal tühi, aga muudatus pole kadunud: see on `git stash list`-is nimega, mille andsid. Stash elab ainult sinu masina `.git` kaustas ega lähe push'iga kaasa, nii et see pole varukoopia. Kui jätad selle nädalateks, unustad, mis seal oli.

✅ **Edasi saad minna, kui** stack andis koodi 0, `git stash list` näitab sinu kirjet ja `git branch --show-current` näitab `bisect-proov`.

## Leia commit, mis murdis `check.sh`

Kolleegi haru `bisect-proov` on kuus tema commit'i sinu `k01-bash`-i peal ja nende otsas annab `check.sh` vea. Üks commit murrab kontrolli. Leia see `git bisect`-iga, mitte diffe järjest lugedes.

Kuue commit'iga saaks diffe ka käsitsi lugeda. Tootmisrepos on vahemikus sageli 200 commit'i kolmelt inimeselt ja sõnumid on "väike parandus". Bisect poolitab vahemikku: iga samm jätab alles poole kahtlustatavatest, nii et 200 commit'i jaoks piisab umbes kaheksast testist. Tingimus on üks: sul peab olema käsk, mis ütleb väljumiskoodiga "hea" või "halb".

1. Veendu, et viga on olemas, ja vaata commit'e.

    ```bash
    (cd k01-bash && ./check.sh); echo "kood $?"
    git log --format='%h %an %s' k01-bash..bisect-proov
    ```

2. Kirjuta üles, millist commit'i sõnumi järgi kahtlustad. Ära diffe veel ava.
3. Käivita bisect: halb on praegune seis, hea on `k01-bash`, test on `check.sh`.

    ```bash
    git bisect start
    git bisect bad
    git bisect good k01-bash
    git bisect run k01-bash/check.sh
    ```

4. Vaata leitud commit'i, selle rida `git blame`-is ja lõpeta bisect.

    ```bash
    git bisect log | tail -4
    git show <leitud hash>
    git blame -L <rida>,<rida> bisect-proov -- k01-bash/check.sh
    git bisect reset
    ```

5. Koristus: `git switch k01-bash && git branch -D bisect-proov && git stash pop`, siis `(cd k01-bash && ./check.sh); echo "kood $?"`.

> `check.sh` saadab iga jooksu tulemuse Labori seisu. Bisect'i ajal lähevad sinu read korraks punaseks, koristuse järel viimane jooks teeb need jälle roheliseks.

`git bisect run` käivitas `check.sh`-i iga valitud commit'i peal. Väljundis on, mitu sammu kulus; võrdle seda oma oletusega ja sellega, mitu diffi oleksid käsitsi lugenud. Testiks valisid `check.sh`-i, nii et ka selle kood 3 (UNKNOWN) on bisect'i jaoks "halb", kuigi see tähendab "ei tea". See on testi valiku piirang: kui mõni commit annab UNKNOWN-i muul põhjusel kui murtud kontroll, võib bisect osutada valele commit'ile. Mõtle, kuidas seda vältida.

✅ **Edasi saad minna, kui** `NOTES.md`-s on leitud commit'i hash, selle sõnum, üks lause sellest, miks muudatus kontrolli murrab, sammude arv ja vastus koodi 3 küsimusele, ning `check.sh` annab `k01-bash`-is jälle koodi 0.

## Hotfix release-harule

Tootmises töötab versioon, mis oli `k01-bash`-is mooduli Operatsioon lõpus. Pärast seda on harule tulnud runbook, timeout'i muudatus, rebase ja `.gitignore` reegel `k01-bash/*.env`. Turvaparandus peab jõudma tootmise harule kohe, ülejäänu läbib tavalise ülevaatuse ja tuleb hiljem. Tootmispiirang: release-harule läheb täpselt see üks muudatus, mitte merge, ja `k01-bash`-i ajalugu ei muutu.

Nõuded:

- haru `release-k01` tehakse commit'ist, mille sõnum algab `systemd: check.sh timer` (leia see `git log --grep`-iga, mitte hash'i käsitsi kopeerides)
- `.gitignore` commit tuleb sinna `git cherry-pick -x`-iga, nii et sõnumis on viide algsele commit'ile
- release-harul muutub võrreldes alusega ainult `.gitignore`; kui algne commit sisaldas ka muid faile, otsustad, mis hotfix'i ei kuulu
- `git check-ignore -v k01-bash/secrets.env` töötab release-harul
- kahe haru hash'id ja otsus lähevad `NOTES.md`-sse `k01-bash`-is; haru `release-k01` on harjutus ja kustutatakse lõpus, GitHubi seda ei lükata

```bash
git log --oneline k01-bash..release-k01
git diff --stat release-k01~1 release-k01
git show -s --format=%B release-k01 | tail -2
git cherry -v k01-bash release-k01
git switch release-k01 && git check-ignore -v k01-bash/secrets.env; git switch k01-bash
```

> Konflikt `NOTES.md`-s tähendab, et `git commit -am` võttis ajaloo kontrolli ajal kaasa ka märkmed. Cherry-pick'is on `--ours` release-haru ja `--theirs` toodav commit; hotfix'i jääb ainult `.gitignore`.

`-x` lisab sõnumisse rea `(cherry picked from commit <hash>)`. Release-harul on nüüd uus commit uue hash'iga, aga sama diff'iga. `git cherry` märgib selle `-`-ga, sest sama muudatus on `k01-bash`-is juba olemas, ja hilisem merge ei too seda topelt. Merge `k01-bash` → `release-k01` oleks toonud tootmisse ka ülevaatamata runbook'i ja timeout'i muudatuse.

✅ **Edasi saad minna, kui** `git log k01-bash..release-k01` näitab ühte commit'i, `diff --stat` ainult `.gitignore`-i, sõnumi lõpus on `cherry picked from commit`, `git cherry` annab `-` ja `check-ignore` leiab reegli release-harul; seejärel `git branch -D release-k01`.

## Commit ja koristus

Nüüd on `k01-bash`-is runbook, konflikti lahendus, sirge rebase ja uus `.gitignore` reegel. Ajutised harud on kadunud ja GitHubis on ainult need harud, mida automaatne hindaja ja PR vajavad.

```bash
git add k01-bash/NOTES.md && git commit -m "notes: git meeskonnas, konflikt, bisect, saladuse proov" && git push
git branch
git ls-remote --heads origin
git log --oneline --graph -12
```

`git branch` ja `ls-remote` peaksid näitama ainult `main`-i ja `k01-bash`-i. Graafis on näha PR-i merge, konflikti merge ja nende vahel sirge rebase'itud commit. See on sinu tänase meeskonnatöö ajalugu ühes vaates ja esitamisel läheb see tervikuna `main`-i.

✅ **Edasi saad minna, kui** kohalikke ja GitHubi harusid on kaks, `git status` on puhas ja `git log --graph` näitab mõlemat merge-commit'i.

📎 **Selle mooduli tõend:** merge'itud PR `k01-runbook` → `k01-bash`; merge-commit pordi timeout'i põhjendusega; `NOTES.md`-s `fix(mariadb)` hash, rebase'i kaks hash'i, saladuse proovi tulemus, tühjad ajaloo otsingud, bisect'i leitud commit koos sammude arvuga ning hotfix'i kaks hash'i ja otsus `NOTES.md` konflikti kohta.

## Miks see nii töötab

**Merge ja rebase.** Merge ja rebase toovad sama muudatuse kokku eri viisil. Merge säilitab ajaloo sellisena, nagu see tekkis, ja lisab ühendamise commit'i, millel on kaks vanemat. Rebase võtab sinu commit'id ja loob need uue aluse peale uuesti: sisu jääb samaks, aga hash'id muutuvad.

**`--force-with-lease`.** Kui oma haru tuleb pärast rebase'i üles lükata, kasuta `--force-with-lease`, mitte `--force`. See keeldub, kui GitHubi harul on vahepeal commit, mida sinu kohalik repo pole näinud, ega kirjuta seega üle kolleegi tööd. Kaitse ei toimi, kui tegid vahepeal `git fetch`-i ega vaadanud uusi commit'e üle: siis loeb Git need juba nähtuks.

**Konfliktimarkerid `zdiff3`-ga.** Konflikti lahendamisel aitab `git config --global merge.conflictstyle zdiff3` (Git 2.35 või uuem). Markerite vahel on siis ka algne rida, mitte ainult kaks uut, ja näed, mida kumbki pool muutis. Kui lahendamine läks segaseks, viib `git merge --abort` tagasi seisu enne merge'i.

**Bisect.** `git bisect` otsib vea tekitanud commit'i poolitamise teel ja vajab umbes log₂(n) testi: kuue commit'i jaoks kolm, tuhande jaoks kümme. `git bisect run` tõlgendab testi väljumiskoodi nii: 0 tähendab head, 125 tähendab „seda commit'i ei saa testida" ja koodid 1–127 (peale 125) tähendavad halba. Kood 128 või suurem katkestab bisect'i.

**Kood UNKNOWN bisect'is.** Praktikas kirjutatakse wrapper, mis teisendab koodi 3 koodiks 125. Väljumiskoodi tähendus on kokkulepe: kui annad skripti teisele tööriistale, kontrolli, kas mõlemad tõlgendavad koode ühtemoodi.

**Cherry-pick ja release-harud.** Cherry-pick paneb ühe commit'i diff'i uue vanema peale ja loob uue commit'i. `git cherry` ja `git log --cherry-pick` võrdlevad diff'i (patch-id), mitte hash'i, seepärast tunnevad nad üle toodud parandused ära. Tavaline kord on "parandus enne `main`-i, siis cherry-pick release-harule": nii ei jää parandus järgmisest release'ist välja. Kui hotfix tehakse release-harul, tuleb see eraldi tagasi tuua, ja see unustatakse. Sama mehhanism toob parandused kolleegi või tarnija repost: GitHubi fork on serveripoolne kloon, kus `origin` on sinu koopia ja `upstream` algne repo ([Lisaülesanded → 16. Tarnija repo: fork ja upstream](lisa.md#16-tarnija-repo-fork-ja-upstream)).

**Lekkinud saladus.** Lekkinud saladuse puhul on järjekord sama: kõigepealt vaheta saladus, siis puhasta ajalugu, kui see on vajalik. Ajaloo ümberkirjutamine (`git filter-repo`) muudab kõigi järgnevate commit'ide hash'id ja kõik kloonid tuleb uuesti teha.

Kui jõudsid kiiremini: [Lisaülesanded → 15. Saladuste kontroll pre-commit hook'iga](lisa.md#15-saladuste-kontroll-pre-commit-hookiga), kirjutad hook'i, mis peatab commit'i enne, kui parool või token jõuab ajalukku.
