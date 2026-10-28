---
tags:
  - Git
  - Hindamine
---

# 8. Esitamine

Release'i tag, mille commit'is midagi puudub või midagi üleliigset on, jõuab tootmisse ja seda märkab alles see, kes kuu aja pärast kloonib. Kõik muudatused on juba main'il: Labori seis ja rikete parandus PR-iga, `gitops.yml` PR-iga, Application, values-fail ja revert otse. Tag `k07` läheb main'i HEAD-ile, kus on ka boti viimane commit, ja nagu release'i tag tootmises lubab ta, et selles commit'is on kõik vajalik ja mitte midagi, mida seal olla ei tohi. Enne tag'i käivitad samad kontrollid ise, ka värskes kloonis.

**Kui teed seda tööl iga päev:** enne release'i tag'i käivitad testid CI-s puhtast kloonist. Kui see on sul juba korras, kirjuta `NOTES.md` jaotis, tee etapi „Enne esitamist“ kontrollid ühe käsureaga ja mine otse etappi „[Värske kloon](#varske-kloon)“.

## Oma töökohale

Kirjuta repo `NOTES.md`-sse jaotis `## K7 tööl`, 3–5 lauset: kus sinu töökohal käib täna käsitsi midagi, mida see päev automatiseeris (deploy, konfiguratsiooni muudatus, rollback, saladuse vahetus, teenuse kolimine konteinerisse), ja mis oleks esimene samm selle automatiseerimiseks. Esimene samm on üks konkreetne töö, mille saad järgmisel nädalal ära teha, näiteks "üks teenus Helmi values-failiga Giti" või "staging'i namespace Argo CD alla".

```bash
grep -A6 '^## K7 tööl' NOTES.md
git switch main && git pull
git add NOTES.md && git commit -m "K7 tööl [skip ci]" && git push
```

✅ **Edasi saad minna, kui** `NOTES.md`-s on jaotis `## K7 tööl` 3–5 lausega ja see on main'il.

## Enne esitamist

Kontrollid repo ja klastri seisu oma masinas. Automaatne hindaja näeb ainult repot: failid, kubeconform, objektid, hügieen, Application ja `gitops.yml`. Klastri seisu näeb koolitaja eraldi.

`hygiene` test vaatab ainult manifeste. Kubeconfig või `.env` mujal repos jääb sellest märkamata, seepärast kontrollid `git ls-files`-iga kogu repot.

1. Vaata, et saladusi ja namespace'i ridu pole ning klaster vastab Gitile:

    ```bash
    actionlint .github/workflows/gitops.yml
    grep -rn 'namespace:\|kind: Secret' k07-k8s/*.yaml
    git ls-files | grep -E '(^|/)\.env$|kubeconfig|k3s01\.yaml|(^|/)secret\.yaml$'
    kubectl get application labori-seis
    git status --short
    ```

2. Käivita kõik kuus testi:

    ```bash
    git switch main && git pull
    for t in files kubeconform objects hygiene gitops cibump; do bash autograde/check.sh k07 $t; done
    bash autograde/check.sh cloud secrets
    ```

Tühjad `grep`-id ja tühi `git status` tähendavad, et kõik, mis on sinu kaustas, on ka commit'is, ja et saladusi commit'is pole. Kuus `OK`-d on sama tulemus, mida automaatne hindaja näeb, kui tema keskkond on sinu omaga sama.

✅ **Edasi saad minna, kui** `actionlint` vaikib, mõlemad `grep`-id on tühjad, Application on `Synced Healthy`, `git status` on tühi ja kõik kuus testi annavad `OK`.

## Värske kloon

Kloonid oma repo GitHubist uude kausta ja käivitad testid seal. Nii näed, mida automaatne hindaja näeb: ainult seda, mis on GitHubis, mitte sinu kohalikke faile.

Värske kloon leiab faili, mis on sinu kaustas, aga mitte Gitis: `.gitignore` peitis manifesti või jäi `git add` tegemata.

1. Klooni main ja käivita testid:

    ```bash
    D=$(mktemp -d) && git clone -q --depth 1 "$(git remote get-url origin)" "$D" && cd "$D"
    for t in files kubeconform objects hygiene gitops cibump; do bash autograde/check.sh k07 $t; done
    cd - && rm -rf "$D"
    ```

Kui kloonis on kõik kuus `OK`, ei sõltu tulemus sinu masinast. Kui mõni test ebaõnnestub kloonis, aga mitte sinu kaustas, näitab `git status --ignored` puuduva faili.

✅ **Edasi saad minna, kui** värskes kloonis annavad kõik kuus testi `OK`.

## Tag

Paned tag'i ja lükkad selle nimega üles.

Haru `main` liigub iga boti commit'iga edasi, seepärast hindab automaatne hindaja tag'i, mitte haru.

```bash
git tag k07 && git push origin k07
git ls-remote --tags origin | grep k07
```

> Parandus pärast esitust: uus commit `main`-i, siis `git tag -f k07 && git push -f origin k07`.

`ls-remote` näitab tag'i ja commit'i SHA-d GitHubis. Kui see SHA on sama mis `git rev-parse HEAD`, on tag õige commit'i peal.

✅ **Edasi saad minna, kui** `git ls-remote --tags origin` näitab `k07`.

## Automaatse hindaja tulemus

Tag `k07` käivitab GitHubis automaatse hindaja. Tulemus on paari minuti pärast: repo → **Releases** → viimane `submit/…`, iga mitteläbinud kontrolli juures on põhjus. Testide nimekiri on repos failis `autograde/TESTS.md`.

Kui tulemus erineb sellest, mida nägid kohapeal, on vahe keskkonnas: tööriista versioon või skeemide allalaadimine. Loe põhjust Releases'i kirjest, mitte ainult punkte.

✅ **Edasi saad minna, kui** Releases näitab tulemust 100 lähedal.

## Lõputest

Lõputest HK6 on kohtumise lõpus. Enne seda kontrolli klastri seis ise ja saada tulemus Labori seisu.

Repo ja klaster on kaks eri tõde. Repo võib olla laitmatu ja klaster ikka katki, näiteks kui Secret puudub või pod ei saa image'it kätte. Seepärast on lõputest klastri vastu, mitte faili vastu.

```bash
kubectl get deploy
curl -s -H 'Host: labori-seis-<github>.lab.hkhk.ee' http://k3s.lab.hkhk.ee/health; echo
kubectl get application labori-seis
LABSEIS_URL=http://labori-seis-<github>.lab.hkhk.ee LABSEIS_TOKEN=<sinu token> \
  bash scripts/labseis-report.sh lab-07 klaster OK "Synced/Healthy"
```

Koolitaja käivitab sama kontrolli kõigile (`k07-verify.sh`) ja tulemus jõuab Labori seisus `lab-07` alla.

<!-- EKRAANIPILT: Labori seisu leht (klassi oma, mitte õppija instants) pärast labseis-report.sh käivitamist; rida lab-07 koos õppija nime, oleku OK ja kommentaariga "Synced/Healthy"
<figure markdown="span">
  ![Labori seisu leht, rida lab-07 olekuga OK](assets/k07_labori_seis_lab07.png)
  <figcaption>Joonis L7.10. Tulemus Labori seisus <code>lab-07</code> all.</figcaption>
</figure>
-->

Neli Deployment'i 1/1, `/health` `UP` ja `Synced Healthy` koos tähendavad, et klaster vastab Gitile ja rakendus töötab. Rida Labori seisus tõestab veel ühte asja: sinu rakendus võttis vastu päringu väljastpoolt ja kirjutas selle andmebaasi.

✅ **Edasi saad minna, kui** db01, mc01, rmq01 ja app01 on 1/1, `/health` annab `UP`, Application on `Synced Healthy` ja Labori seisus on rida `lab-07`.

## Tõendid moodulite kaupa

Kontrolli, et iga mooduli issue's on tõend. Nimekiri on sama, mida koolitaja vaatab.

- [ ] 1. Oma klaster: kaks context'i, `pause`, iptables'i rida, `Allocated resources`, katse "k3s maas"; k3s01 on välja lülitatud
- [ ] 2. Namespace ja põhiobjektid: `can-i` tabel (namespace'e `no`, põhjus), owner `ReplicaSet`, Endpoints = pod'ide IP-d, karantiini katse, ConfigMap volume vs env
- [ ] 3. Ressursid ja rikkeotsing: `exceeded quota`, LimitRange'i vaikeväärtused, `FailedScheduling`, `OOMKilled` / 137, debug-konteiner, `katki-1` ja `katki-2` põhjused
- [ ] 4. Labori seis klastris: `/health` UP Ingress'i kaudu, rolling update'i logis ainult `200`, `lab-99` pärast pod'i vahetust, db01 0 koopiaga → 503 ja `Init:0/1`, miks `nslookup` ei sobi ootamiseks, NetworkPolicy enne/pärast ja `nc2`, `rollout history` ≥ 3 revisjoni
- [ ] 5. Neli riket: neli rida "sümptom → käsk → põhjus → parandus", ajajoon, `kubectl diff` tühi, PR main'is
- [ ] 6. Helm alused: `helm history` kolme revisjoniga, käsitsi muudatuse `diff`, ebaõnnestunud upgrade ja automaatne rollback logis ainult `200`-ga, values-fail Gitis, podinfo eemaldatud
- [ ] 7. GitOps: boti commit, `/version` SHA = boti commit'i SHA, drift'i kestus, `OutOfSync` ilma selfHeal'ita, prune, `ComparisonError`, halb commit + revert, halva koodi kolm kellaaega ja logis ainult `200`
- [ ] 8. Esitamine: kuus testi `OK` ka värskes kloonis, tag `k07`, Releases tulemus, Labori seisus `lab-07`, `NOTES.md` jaotis `## K7 tööl`

Kui mõni linnuke jääb tegemata, kirjuta issue'sse, mis jäi ja miks. Koolitaja hindab ka seda, kas sa tead, mis puudu on.

✅ **Edasi saad minna, kui** kõik linnukesed on tehtud ja iga mooduli issue on suletud.

📎 **Selle mooduli tõend:** tag `k07` main'i peal, värske klooni kuus `OK`-d, automaatse hindaja tulemus GitHubi Releases all, Labori seisus rida `lab-07` ja link `NOTES.md` jaotisele `## K7 tööl`.

## Miks see nii töötab

**Värske kloon.** Värske kloon põhineb samal põhimõttel, mida CI kasutab igal käivitusel: alusta tühjast kaustast ja kontrolli, kas Gitis olevast piisab.

**Viis mehhanismi.** Iga laboris nähtud väljund peaks olema seletatav ühe mehhanismiga: admission, scheduler, kubelet, kube-proxy või kontroller.
