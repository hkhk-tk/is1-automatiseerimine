---
tags:
  - Git
  - Hindamine
---

# 9. Esitamine

Image, mis ehitub ainult sinu töökaustas, ebaõnnestub pipeline'i esimesel käivitusel: 5. kohtumisel võtab pipeline sinu `compose.yaml`-i, Dockerfile'id ja `.env.example`-i täpselt sellisel kujul, nagu need `main`-is on. Seepärast käivitad enne samad kontrollid ise ja vaatad, et stack töötab nii, nagu pipeline seda ootab. Lõpus jõuab töö `main`-i, tag `k03` käivitab automaatse hindaja ja tulemus on GitHubi Releases all.

**Kui teed seda tööl iga päev:** värske klooni build ja tag'iga esitus on sul tavaline release'i samm ja `bash autograde/check.sh k03 build` annab värskes kloonis `OK`. Kui see on sul juba korras, mine otse etappi „[Lõpukontroll](#lopukontroll)“.

## Enne esitamist

Automaatne hindaja näeb ainult repot. Kõigepealt kontrolli repo juurest Compose'i failid ja Dockerfile'id.

```bash
cd "$(git rev-parse --show-toplevel)"
docker compose -f k03-docker/compose.yaml config -q && echo compose OK
docker compose -f k03-docker/compose.yaml -f k03-docker/compose.prod.yaml config -q && echo prod OK
for d in app db; do docker build --check -f k03-docker/$d/Dockerfile .; done
for d in web kontroll; do docker build --check k03-docker/$d; done
```

Siis automaatse hindaja kontrollid, saladused ja idempotentsus.

```bash
for t in files compose deps multistage tags quadlet build; do bash autograde/check.sh k03 "$t"; done
git ls-files | grep -E '(^|/)\.env$|secrets/|backup/|\.pem$|\.key$|tfstate'
docker compose -f k03-docker/compose.yaml up -d --wait
shellcheck -S warning k03-docker/prune.sh
git status --short
```

`build --check` leiab Dockerfile'i vead (näiteks shell-vormi CMD või vale suurtähtedega `AS`) ilma ehitamata. Tühi `git ls-files | grep` tähendab, et ükski saladus ega varukoopia pole Giti ajalukku jõudnud. `up -d --wait` ilma uuesti loomiseta tõestab, et töötav stack vastab failile.

**Edasi saad minna, kui** `build --check` ei anna hoiatusi, seitse kontrolli annavad `OK` (`build` ehitab kõik kolm image'it ja on aeglaseim), `git ls-files | grep` on tühi, `up -d` ütleb kõigi kohta `Running` või `Healthy` ja midagi ei looda uuesti.

## Värske klooni test

Lokaalne kontroll käivitub sinu töökaustas, kus on ka commit'imata failid. Automaatne hindaja alustab värskest kloonist. Teed sama: kloonid oma haru ajutisse kausta ja ehitad sealt.

See on klassikaline "minu masinas töötab". Dockerfile kopeerib faili, mis on töökaustas, aga mitte Gitis, ja GitHubis ebaõnnestub build, kuigi sinu juures läks kõik läbi.

1. Commit'i ja pushi kõik, siis klooni haru ajutisse kausta.

    ```bash
    rm -rf /tmp/k03-proov
    git clone -q -b k03-docker "$(git rev-parse --show-toplevel)" /tmp/k03-proov
    ls -a /tmp/k03-proov/k03-docker
    ```

2. Käivita kloonis failide ja build'i kontroll ning korista.

    ```bash
    cd /tmp/k03-proov && bash autograde/check.sh k03 files && bash autograde/check.sh k03 build
    cd - && rm -rf /tmp/k03-proov
    ```

Kloonis pole `.env`-i ega `secrets/`-i, ja see on õige: automaatne hindaja töötab `.env.example`-iga. Kui klooni build õnnestus, ei sõltu image ühestki failist, mis on ainult sinu töökaustas. Kui see ebaõnnestus, näitab veateade puuduvat faili: lisa see Giti või `.dockerignore` allowlist'i.

**Edasi saad minna, kui** kloonis puuduvad `.env` ja `secrets/`, `files` ja `build` annavad kloonis `OK` ja ajutine kaust on kustutatud.

## Lõpukontroll

Kontrolli stacki olekut, mida automaatne hindaja ei näe: täielik restart, versioon, rikkele reageerimine ja kontroll seestpoolt. Need on samad asjad, mida koolitaja PR-i juures vaatab.

```bash
cd k03-docker && docker compose down && docker compose up -d --wait && docker compose ps
curl -s http://localhost:8080/version; echo
docker compose stop rmq01; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/health
docker compose start rmq01 && sleep 30; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/health
docker run --rm --network labori-seis_default labseis-kontroll:test; echo
```

Kui `/version` ja Gitea image'i tag on sama SHA, töötab see image, mille sa lükkasid. 503 ja siis 200 ilma app01 restardita kordab Compose'i rikketesti viimase koodiga: rakendus taastub ise, kui sõltuvus tagasi tuleb.

**Edasi saad minna, kui** viis teenust on `(healthy)` pärast `down` ja `up`-i, `/version` näitab sama SHA-d mis Gitea image'i tag, `/health` annab rmq01 peatamisel 503 ja pärast starti 200 ilma app01 taaskäivituseta ning kontroll-image annab `/health` JSON-i.

## Vii see oma töökohale

Labori seisus käib iga teenus image'ist, mille sisu ja versioon on teada; sinu töökohal on osa teenuseid tõenäoliselt käsitsi paigaldatud või käsitsi uuendatavad. Kirjuta see üles enne PR-i, et see jõuaks esitatud commit'i.

Lisa faili `k03-docker/NOTES.md` jaotis `## Minu töökohal` ja vasta 3–5 lausega: kus sinu töökohal käib teenuse paigaldus, uuendus või konteineri käivitus täna käsitsi (`docker run` ajaloos, käsitsi `systemctl`, vendor'i juhend, pilet) ja mis oleks esimene samm seda automatiseerida? Nimeta konkreetne süsteem ja samm. Hea esimene samm on väike ja tagasi võetav, näiteks üks olemasolev `docker run` Compose'i faili või Quadleti unit'iks koos versiooni tag'iga, mitte "kõik Kubernetesesse".

```bash
sed -n '/^## Minu töökohal/,$p' k03-docker/NOTES.md
git add k03-docker/NOTES.md && git commit -m "K3 NOTES: minu töökohal" && git push
```

**Edasi saad minna, kui** `sed` näitab jaotist 3–5 lausega, milles on nimetatud üks konkreetne käsitsi protsess ja üks esimene samm, ja commit on harus.

## PR, merge ja tag

Tag peab olema `main`-i peal pärast merge'i. PR-i kirjeldus on sinu TOEND.md, nii et koolitaja näeb tõendeid ühest kohast.

```bash
git push
gh pr create --base main --head k03-docker --title "K3 Docker" --body-file k03-docker/TOEND.md
gh pr merge --merge
git switch main && git pull
git tag k03 && git push origin k03
```

<!-- EKRAANIPILT: GitHub, oma repo → Pull requests → PR k03-docker → main, vaade Conversation: kirjeldus TOEND.md kokkuvõttega ja rohelised kontrollid enne Merge-nuppu; pärast `git push -u origin k03-docker`
<figure markdown="span">
  ![GitHubi PR k03-docker harult main harule koos kirjelduse ja kontrollidega](assets/k03_github_pr.png)
  <figcaption>Joonis L3.8. PR enne merge'i: kirjeldus ja kontrollid.</figcaption>
</figure>
-->

> Parandus pärast esitust: uus commit `main`-i, siis `git tag -f k03 && git push -f origin k03`.

Tag `main`-i peal tähendab, et automaatne hindaja hindab sama koodi, mis on kursuse põhiharus. Tag haru peal hindaks koodi, mida `main` ei sisalda, ja 5. kohtumine algaks valest olekust.

**Edasi saad minna, kui** `git ls-remote --tags origin` näitab `k03`.

## Automaatse hindaja tulemus

Tag `k03` käivitab GitHubis automaatse hindaja: failid ja saladused, `compose.yaml` valideerumine, sõltuvused ja volume, mitmeastmeline build, versioonitud image'id, Quadleti failid ja kolme image'i ehitus. Tulemus on paari minuti pärast: repo → **Releases** → viimane `submit/…`, iga mitteläbinud kontrolli juures on põhjus. Testide nimekiri on failis `autograde/TESTS.md`. Registry, Trivy, prod-faili, Podmani ja intsidendi osa automaatne hindaja ei näe (VPN-i taga): Quadleti failidest kontrollib ta ainult kuju, mitte seda, kas teenus mc01-s ja db01-s käivitus. Neid vaatab koolitaja PR-ist, TOEND.md-st ja Gitea'st.

Kui mõni kontroll ebaõnnestus, loe põhjust ja korda sama testi lokaalselt `bash autograde/check.sh k03 <test>` abil. Lokaalne ja GitHubi tulemus peavad klappima; kui ei klapi, on vahe peaaegu alati commit'imata failis.

**Edasi saad minna, kui** Releases näitab tulemust 100 lähedal.

## Mida koolitaja vaatab

Registry, Trivy, prod-faili, Podmani ja intsidendi osa automaatne hindaja ei näe. Need vaatab koolitaja PR-ist: PR-i kirjeldus on sinu TOEND.md, lisaks Gitea registry. Kontrolli enne merge'i, et TOEND.md on viimases commit'is.

**Selle osa tõend:** `NOTES.md` jaotis „Minu töökohal“, tag `k03` `main`-i peal ja automaatse hindaja tulemus GitHubi Releases all.

## Pärast esitamist: mc01 ja db01 välja

Podmani moodul oli viimane, mis vajas mc01 ja db01. Enne 4. kohtumist kustutab koolitaja kõik viis labori VM-i ja 4. kohtumisel lood need ise OpenTofuga uuesti. Kuni selleni võtavad need mälu, mida teised õppijad vajavad.

Kui Releases on roheline ja Podmani moodulis on hostid algseisus, lülita Proxmoxis välja mc01 ja db01: **VM → Shutdown**. Compose'i stack control node'is jääb tööle, sest 5. kohtumine eeldab, et see töötab.

**Edasi saad minna, kui** Proxmoxis on sinu pool'is web01…db01 kõik olekus *stopped* ja control node'is näitab `docker compose -f k03-docker/compose.yaml ps` viit teenust.

## Miks see nii töötab

**Värske kloon.** Värske kloon sisaldab ainult commit'itud ja push'itud faile. Automaatne hindaja ja pipeline näevad sama mis värske kloon: `.env`, `secrets/`, `backup/` ja commit'imata muudatused sealt puuduvad, aga `docker build` ehituskontekst töökaustas sisaldab neid.

**`.env.example`.** `.env.example` kirjeldab nõutavaid keskkonnamuutujaid ja võimaldab konfiguratsiooni valideerida. See peab sisaldama iga muutujat, mida `compose.yaml` nõuab, väärtustega, millega fail valideerub.

**Tag `k03`.** Tag `k03` määrab, milline commit esitatakse, ja automaatne hindaja hindab alati seda commit'i, millele tag viitab. Kursusel on tag'i ümbertõstmine pärast parandust lubatud.

Kui jõudsid kiiremini: [Lisaülesanded → 1. Swarm ühel node'il](lisa.md#1-swarm-uhel-nodeil), käivitad sama nginx'i kolme koopiana Swarmi teenusena ja vaatad, mida orkestraator sinu eest teeb.
