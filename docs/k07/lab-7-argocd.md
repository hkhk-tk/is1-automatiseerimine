---
tags:
  - Argo CD
  - GitOps
  - GitHub Actions
---

# 7. GitOps Argo CD-ga

`rollout undo`, käsitsi `scale`, `helm rollback` ja koolitaja neli riket jätsid klastri ja Giti lahku, ja keegi ei saanud sellest teada enne, kui vaatas. GitOps muudab reegli: klastrisse ei kirjuta keegi peale Argo CD, Argo kirjutab ainult seda, mis on Gitis, ja iga muudatus on commit, millel on autor, aeg ja põhjus. Lõpuks kirjutab pipeline uue image'i tag'i Giti, Argo viib selle klastrisse, käsitsi muudatus keeratakse tagasi ja halb commit parandatakse `git revert`-iga.

Argo CD loeb haru `main` ja `gitops.yml` kirjutab harusse `main`, seega töötad main'il. Väikesed manifestide muudatused lähevad otse main'i, `gitops.yml` tuleb PR-iga, sest just merge käivitab ahela.

**Kui teed seda tööl iga päev:** Argo CD või Flux haldab sinu klastreid ja selfHeal, prune ning `ComparisonError` on sulle tuttavad. Kui see on sul juba korras, tee Application ja `gitops.yml` valmis, kontrolli drift'i, prune'i ja katkise YAML-i ✅ read ühe katsega ja mine otse etappi „[Halb kood main'is: rollback kahe commit'iga](#halb-kood-mainis-rollback-kahe-commitiga)“.

## Application

Kirjutad Application'i: objekti, mis ütleb Argo CD-le, millist repot, haru ja kausta jälgida ning kuhu tulemus panna. Siis teed sellele `kubectl apply` ja vaatad, kuidas Argo sinu olemasolevad objektid üle võtab.

Application on alamkaustas, et ta ei haldaks iseennast ja et `kubectl apply -f k07-k8s/` teda ei puudutaks. Kui Application oleks kaustas, mida ta ise jälgib, kustutaks vale commit ka Application'i ja koos sellega kogu järelevalve.

1. Täida `k07-k8s/argocd/application.yaml` starteri järgi:
    - project `is-<github>`
    - `repoURL` on sinu repo (`https://github.com/hkhk-tk/<repo>.git`), `targetRevision: main`, `path: k07-k8s`
    - destination `https://kubernetes.default.svc`, namespace `is-<github>`
    - [`automated`](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/) koos `prune: true` ja `selfHeal: true`
2. Kontrolli, commit'i ja tee `kubectl apply`:

    ```bash
    bash autograde/check.sh k07 gitops
    git add k07-k8s/argocd/application.yaml && git commit -m "K7.7 Argo CD Application" && git push
    kubectl apply -f k07-k8s/argocd/application.yaml
    kubectl get application labori-seis -w
    ```

3. Salvesta olek: `kubectl get application labori-seis -o jsonpath='{.status.sync.status} {.status.health.status}'; echo`
4. Vaata, et Argo märkis objektid enda omaks:

    ```bash
    kubectl get deploy app01 -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'; echo
    ```

> Kui näed `repository not accessible`, on `repoURL`-is kirjaviga või repositoorium ei ole org'is `hkhk-tk`. Kui näed `destination … is not permitted in project`, ei ole destination namespace sinu oma.

`Synced Healthy` tuli mõne sekundiga, sest klastris oli juba täpselt see, mis Gitis: rikete parandamise lõpus tegid `kubectl diff` tühjaks. Argo ei loonud midagi uuesti, ta võttis olemasolevad objektid üle, sest nimed on samad. Tracking-id annotatsioon on märk, mille järgi Argo hiljem teab, mis on tema hallata. Kui olek on kohe `OutOfSync`, on mõni rike parandamata või parandus Giti viimata.

✅ **Edasi saad minna, kui** olek on mõne sekundiga `Synced Healthy` ja app01 Deployment'il on tracking-id annotatsioon.

## Argo CD UI ja CLI

Vaatad sama Application'it kolmest kohast: kubectl, Argo CLI ja veebiliides. Application'i nimi on kujul `<namespace>/<nimi>`, sest Application elab sinu namespace'is. Refresh loeb Giti kohe uuesti, Sync viib muudatused klastrisse.

UI ja `argocd` CLI räägivad argocd-server'i API-ga (CLI gRPC kaudu), mitte Kubernetese API-ga, seepärast vajab CLI eraldi sisselogimist ja õigused tulevad Argo enda RBAC-ist, mitte sinu kubeconfig'ist. Info on sama, mis Application-objekti `status` all.

1. Võta koolitajalt konto (`<github>`) ja parool. Paigalda CLI ja logi sisse:

    ```bash
    command -v argocd || { curl -fsSLo argocd https://github.com/argoproj/argo-cd/releases/download/v3.5.2/argocd-linux-amd64 && sudo install argocd /usr/local/bin/; }
    argocd login argocd.lab.hkhk.ee --grpc-web --username <github>
    argocd app list
    ```

2. Vaata rakendust CLI-s ([`argocd app`](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app/)):

    ```bash
    argocd app get is-<github>/labori-seis | head -12
    argocd app resources is-<github>/labori-seis
    argocd app history is-<github>/labori-seis
    argocd proj get is-<github>
    ```

3. Ava UI-s `https://argocd.lab.hkhk.ee` rakendus `labori-seis`, vaata ressursside puud (Application → Deployment → ReplicaSet → Pod), ava app01 pod'i **Logs** ja leia nupud **Refresh** ja **Sync**.

<!-- EKRAANIPILT: Argo CD UI, rakendus is-<github>/labori-seis, app01 pod'i detailaken avatud vahekaardil Logs; logis on näha Spring Booti käivitusread
<figure markdown="span">
  ![Argo CD UI, app01 pod'i logid](assets/k07_argocd_logs.png)
  <figcaption>Joonis L7.6. app01 pod'i logid Argo CD UI-s.</figcaption>
</figure>
-->

> Kui näed `permission denied`, on sinu kontol õigus ainult oma projektile, mille nimi on `is-<github>/labori-seis`. Kui sul Argo CD kontot pole, leiad sama info käsu `kubectl get application labori-seis -o yaml` väljundi plokist `status`.

`app resources` loetleb kõik objektid, mida Argo haldab. Secret'it `labori-seis` seal pole, sest seda pole Gitis, ja see on õige. `proj get` näitab piire, mille koolitaja sulle seadis: üks repo, üks namespace, klastritasandi objekte mitte. Isegi kui keegi kirjutaks sinu repo'sse ClusterRole'i, ei laseks Argo seda luua.

✅ **Edasi saad minna, kui** `app get` näitab `Sync Status: Synced to main (<sha7>)` ja `Health Status: Healthy`, `history`-s on üks revisjon ja `proj get` lubab ainult sinu repot ja sinu namespace'i.

## CI kirjutab tag'i, Argo viib klastrisse

Paned ahela kokku: kui `ci` on main'il roheline, kirjutab `gitops.yml` sama commit'i SHA `40-app.yaml`-i ja commit'ib. Argo näeb uut commit'i ja viib selle klastrisse. CI-l pole kubeconfig'i.

Kompromiteeritud CI saab kirjutada ainult Giti, kus muudatus jääb ajalukku ning branch protection ja CODEOWNERS saavad seda piirata. Klastri võtmega CI oleks otsetee tootmisse, millest Gitis jälgi ei jää.

1. Loo haru ja kopeeri starter:

    ```bash
    git switch -c k07-gitops
    cp ~/<kursuse materjalid>/k07/starter/.github/workflows/gitops.yml .github/workflows/gitops.yml
    ```

2. Täida TODO 1–5. Nõuded:
    - job käivitub ainult siis, kui `ci` lõppes edukalt ja selle käivitas `push`
    - job'il on õigus repo'sse kirjutada (`contents: write`)
    - `sed -i -E` asendab `ghcr.io/…` image'i rea ja `kubernetes.io/change-cause` väärtuse `"${SHA::7} (ci)"`
    - commit'i sõnum on `k07: app01 → <sha7> [skip ci]`, push `origin HEAD:main`, vahepealse push'i korral `git pull --rebase` ja uus katse
3. Kontrolli, siis PR, merge ja jälgi käivitu:

    ```bash
    actionlint .github/workflows/gitops.yml && bash autograde/check.sh k07 cibump
    git add .github/workflows/gitops.yml && git commit -m "K7.7 gitops: CI kirjutab image'i tagi (closes #<nr>)"
    git push -u origin k07-gitops && gh pr create --fill --base main && gh pr merge --merge
    gh run watch
    ```

4. Kui `gitops` on roheline, tõmba main ja vaata, kuidas Argo muudatuse klastrisse viib:

    ```bash
    git switch main && git pull && git log --oneline -3
    kubectl get application labori-seis -w
    kubectl rollout history deploy/app01
    argocd app history is-<github>/labori-seis
    ```

5. Võrdle kolme SHA-d: boti commit'i sõnumis, `/version`-is ja Argo revisjonis:

    ```bash
    curl -s -H 'Host: labori-seis-<github>.lab.hkhk.ee' http://k3s.lab.hkhk.ee/version; echo
    kubectl get application labori-seis -o jsonpath='{.status.sync.revision}'; echo
    git rev-parse HEAD
    ```

<!-- EKRAANIPILT: GitHubi repo Actions vaade pärast PR-i merge'i; järjest kaks rohelist jooksu: ci (push main) ja gitops (workflow_run), gitops on ci järel
<figure markdown="span">
  ![GitHub Actions: ci jooks ja selle järel gitops jooks](assets/k07_actions_ci_gitops.png)
  <figcaption>Joonis L7.7. <code>ci</code> lõpeb edukalt ja käivitab <code>gitops</code>-i.</figcaption>
</figure>
-->

<!-- EKRAANIPILT: GitHubi repo Commits vaade harul main pärast gitops jooksu; ülemine commit on github-actions[bot] sõnumiga "k07: app01 → <sha7> [skip ci]", selle all PR-i merge commit
<figure markdown="span">
  ![Main'i commit'ide ajalugu, ülemine on boti commit](assets/k07_boti_commit.png)
  <figcaption>Joonis L7.8. Boti commit main'il: CI muutis ainult image'i tag'i.</figcaption>
</figure>
-->

> `gitops` ei käivitu: [`workflow_run`](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#workflow_run) töötab ainult siis, kui fail on main'il, ja `workflows: [ci]` peab vastama `ci.yml` workflow'i `name:` reale. `skipped`: `ci` ei olnud roheline või polnud tegu push'iga.

Kolm SHA-d tähendavad kolme eri asja. Boti commit'i sõnumis on rakenduse koodi commit, millest image ehitati. `/version` näitab, mis kood pod'is töötab. `status.sync.revision` on manifestide commit, mille Argo klastrisse viis, ehk boti commit ise. Kui `/version` ja boti sõnum klapivad ning Argo revisjon on `git rev-parse HEAD`, on ahel koodist klastrini katkematu. Kui `/version` näitaks vana SHA-d, oleks Argo sünkroonis, aga rollout jäänud pooleli.

✅ **Edasi saad minna, kui** main'il on boti commit `k07: app01 → <sha7> [skip ci]`, selle peale uut `ci`-d ei käivitunud, `rollout history` viimases reas on `<sha7> (ci)` ning `/version` SHA ja `status.sync.revision` klapivad boti commit'iga.

## Drift ja selfHeal

Teed käsitsi muudatuse, nagu koolitaja rikete juures tegi, ja vaatad, mida Argo teeb. `selfHeal: true` viib klastri drift'i järel tagasi Gitis kirjeldatud olekusse. Tee see ajal, kui eelmise etapi `ci` töötab.

selfHeal'i käivitab application-controller'i watch Kubernetese API-s, mitte Giti lugemine: objekti muutus paneb Application'i kohe uuesti võrdlusesse. Käsitsi `kubectl edit` elab seepärast paar sekundit ja intsidendi ajal tuleb kas parandus commit'ida või selfHeal teadlikult välja lülitada.

1. Muuda klastris käsitsi koopiate arvu ja ConfigMap'i ning vaata, mis juhtub:

    ```bash
    kubectl scale deploy/app01 --replicas=3
    kubectl get deploy app01 -w
    kubectl patch configmap labori-seis -p '{"data":{"MEMCACHED_HOST":"mc99"}}'
    kubectl get configmap labori-seis -o jsonpath='{.data.MEMCACHED_HOST}'; echo
    ```

2. Korda viimast käsku paari sekundi pärast ja mõõda, kaua muudatus kestis.
3. Vaata, kas Argo jättis selfHeal'ist jälje:

    ```bash
    kubectl get application labori-seis -o jsonpath='{.status.operationState.message}'; echo
    kubectl get events --field-selector involvedObject.name=labori-seis --sort-by=.lastTimestamp | tail -3
    ```

Koopiaid oli hetkeks 3 ja siis jälle 1, ConfigMap'i väärtus tuli tagasi `mc01`-ks. Kogu muudatus kestis sekundeid. Operatsiooni sõnum ja Events näitavad, et rollback oli Argo tegu, mitte kokkusattumus.

✅ **Edasi saad minna, kui** koopiaid oli hetkeks 3 ja siis jälle 1, `MEMCACHED_HOST` on jälle `mc01` ja issue'sse on kirjas, mitu sekundit kulus ja mida see "kiirele parandusele" tähendab.

## Sync policy: drift ilma selfHeal'ita

Lülitad selfHeal'i välja ja teed sama muudatuse. Ilma `selfHeal`-ita näitab Argo drift'i `OutOfSync`-ina, aga ei paranda seda enne järgmist commit'i. Siis otsustad sina: kas Git võidab või läheb klastri muudatus Giti.

Mõnes meeskonnas on selfHeal tootmises teadlikult väljas, et intsidendi ajal saaks käsitsi sekkuda. Hind on see, et drift jääb alles, kuni keegi selle lahendab, ja `OutOfSync` muutub müraks, millele keegi enam ei reageeri.

1. Lülita selfHeal klastris välja ja tee sama muudatus:

    ```bash
    kubectl patch application labori-seis --type merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}'
    kubectl scale deploy/app01 --replicas=2
    kubectl get application labori-seis
    argocd app diff is-<github>/labori-seis
    ```

2. Las Git võita: `argocd app sync is-<github>/labori-seis`, siis `kubectl get deploy app01`.
3. Pane failis kirjas olev poliitika tagasi ja vaata, mis kehtib:

    ```bash
    kubectl apply -f k07-k8s/argocd/application.yaml
    kubectl get application labori-seis -o jsonpath='{.spec.syncPolicy.automated}'; echo
    ```

> Application'it ennast Argo ei halda. Kui muudad poliitikat käsitsi, kaob muudatus alles siis, kui teed failile uuesti `kubectl apply`.

`argocd app diff` näitas täpselt ühte erinevust, `replicas`, ja see on sama info, mille sa rikete juures `kubectl diff`-iga käsitsi leidsid. Sync rakendas Gitis kirjeldatud oleku klastris ja OutOfSync kadus. Kui oleksid tahtnud kahte koopiat alles jätta, oleks õige tee olnud muuta faili ja commit'ida, mitte jätta drift'i.

✅ **Edasi saad minna, kui** `replicas: 2` püsis seni, kuni tegid sync'i, Application oli selle aja `OutOfSync`, pärast sync'i on 1 koopia ja `automated` näitab jälle `"prune":true,"selfHeal":true`.

## Prune: Gitist kadunud objekt

Lisad Giti uue objekti, vaatad, kuidas see klastrisse tekib, ja kustutad selle Gitist. `prune: true` kustutab klastrist objekti, mis Gitist kadus. Ilma selleta jääks objekt klastrisse ja Application oleks `OutOfSync`.

Ilma prune'ita kogunevad klastrisse vanad ConfigMap'id, Service'id ja CronJob'id, mida keegi enam ei kasuta, aga mis võivad ikka töötada. Unustatud CronJob, mis töötab edasi vana parooliga, on tüüpiline leid turvaauditis.

Prune kustutab samamoodi ka PVC, kui selle fail Gitist kaob, ja koos PVC-ga kaovad andmed. Laboris on db01 andmed taastatavad algandmed. Tootmises märgitakse andmetega PVC annotatsiooniga `argocd.argoproj.io/sync-options: Prune=false`: Argo näitab objekti siis `OutOfSync`-ina, aga ei kustuta seda.

1. Kirjuta `k07-k8s/90-proov.yaml`: ConfigMap `proov`, üks võti `LAB: prune`, ilma `namespace:` reata. Lükka see main'i:

    ```bash
    git add k07-k8s/90-proov.yaml && git commit -m "proov: prune" && git push
    kubectl annotate application labori-seis argocd.argoproj.io/refresh=normal --overwrite
    kubectl get configmap proov -w
    ```

2. Kustuta fail Gitist ja vaata, mis klastris juhtub:

    ```bash
    git rm k07-k8s/90-proov.yaml && git commit -m "proov: prune ära" && git push
    kubectl annotate application labori-seis argocd.argoproj.io/refresh=normal --overwrite
    kubectl get configmap proov
    ```

> Refresh-annotatsioon ütleb Argole, et ta loeks Giti kohe, mitte järgmisel 60-sekundilisel küsimisel.

ConfigMap tekkis ilma, et sa oleksid `kubectl apply` käivitanud, ja kadus ilma `kubectl delete`-ta. Klastri muutmiseks piisas commit'ist. `NotFound` teisel korral tõestab, et Argo jälgib ka seda, mida Gitis enam pole, mitte ainult seda, mis seal on.

✅ **Edasi saad minna, kui** ConfigMap `proov` tekkis pärast esimest push'i ise ja kadus pärast teist (`NotFound`).

## Katkine YAML Gitis

Lükkad Giti faili, mida ei saa YAML-ina lugeda. Vaatad, mis juhtub Application'iga ja kas töötav rakendus kannatab.

Süntaksiviga manifestis on tavaline ja ohutu küsimus on: kas GitOps'i tööriist viib klastrisse poole failist või mitte midagi? Argo CD ei muuda klastris midagi, kui ta ei suuda kogu kausta renderdada. See kaitseb klastrit, aga peatab ka kõik teised uuendused, kuni viga on parandatud.

1. Kirjuta fail vale taandega ja lükka see main'i:

    ```bash
    printf 'apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: katki\n data: {}\n' > k07-k8s/91-katki.yaml
    git add k07-k8s/91-katki.yaml && git commit -m "katki: yaml" && git push
    kubectl annotate application labori-seis argocd.argoproj.io/refresh=normal --overwrite
    ```

2. Vaata Application'i olekut ja rakendust:

    ```bash
    kubectl get application labori-seis
    kubectl get application labori-seis -o jsonpath='{.status.conditions[*].message}'; echo
    curl -s -H 'Host: labori-seis-<github>.lab.hkhk.ee' http://k3s.lab.hkhk.ee/health; echo
    ```

3. Eemalda fail ja vaata, et olek taastus:

    ```bash
    git rm k07-k8s/91-katki.yaml && git commit -m "katki: yaml ära" && git push
    kubectl annotate application labori-seis argocd.argoproj.io/refresh=normal --overwrite
    kubectl get application labori-seis -w
    ```

Sync status oli `Unknown` ja tingimuses oli `ComparisonError` koos YAML-i reanumbriga. `/health` vastas ikka `UP`: klastris ei muutunud midagi, sest Argo ei suutnud uut soovitud olekut üldse välja arvutada. Kui sel ajal oleks CI kirjutanud uue tag'i, poleks see klastrisse jõudnud. Seepärast käivitad `kubeconform`-i enne push'i, mitte pärast.

✅ **Edasi saad minna, kui** katkise failiga oli olek `Unknown` ja `ComparisonError`, `/health` jäi `UP`-iks ja pärast faili eemaldamist on olek jälle `Synced Healthy`.

## Halb commit ja git revert

Lükkad Giti korrektse YAML-i, mis on sisult vale: olematu image'i tag. Argo teeb täpselt seda, mis Gitis on. [Sync status vastab küsimusele "kas klaster = Git", health küsimusele "kas rakendus töötab"](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/).

`git revert` teeb uue commit'i, nii et `argocd app history`-s on halb ja parandav revisjon kõrvuti ning sync'i ajad näitavad, kui kaua viga klastris oli.

1. Pane image'ile olematu tag ja push'i:

    ```bash
    sed -i 's|\(image: ghcr.io/.*\):.*|\1:olematu|' k07-k8s/40-app.yaml
    git commit -am "halb tag" && git push
    kubectl get application labori-seis -w
    kubectl get pods -l app=app01
    ```

2. Vaata `gitops` jooksu logi: commit muutis ainult `k07-k8s/`, seega jätab CI image'i rahule ega "paranda" sinu viga ise.
3. Proovi `kubectl rollout undo deploy/app01` ja vaata `kubectl get pods -l app=app01 -w`.
4. Tühista halb commit:

    ```bash
    git revert --no-edit HEAD && git push
    kubectl get application labori-seis -w
    git log --oneline -3
    ```

<!-- EKRAANIPILT: Argo CD UI, rakendus is-<github>/labori-seis pärast "halb tag" push'i; Sync Status Synced, App Health Degraded; puus on uus app01 pod punase märgiga ImagePullBackOff ja vana pod rohelisena
<figure markdown="span">
  ![Argo CD rakendus olekus Synced ja Degraded, uus pod ImagePullBackOff'is](assets/k07_argocd_degraded.png)
  <figcaption>Joonis L7.9. Synced, aga Degraded: klaster vastab Gitile, rakendus mitte.</figcaption>
</figure>
-->

Halva tag'iga oli olek `Synced` ja `Degraded` korraga: Argo tegi oma töö õigesti, aga Gitis oli viga. Kasutaja seda ei märganud, sest `maxUnavailable: 0` hoidis vana pod'i teenindamas. `rollout undo` keerati sekunditega tagasi, sest Git ütles ikka `olematu`. Ainus püsiv parandus oli Gitis ja `git log` näitab nüüd nii viga kui ka revert'i.

✅ **Edasi saad minna, kui** halva tag'iga oli olek Synced/Degraded ja uus pod `ImagePullBackOff`, `rollout undo` keerati tagasi, pärast revert'i on olek Synced/Healthy ja `git log` näitab halba commit'i ja selle revert'i.

## Halb kood main'is: rollback kahe commit'iga

Eelmises katses oli viga manifestis ja üks `git revert` parandas selle. Sagedamini on viga koodis: `ci` on roheline, image on registry's, bot on tag'i kirjutanud ja alles klastris selgub, et uus versioon ei saa Ready. Main'il on siis kaks commit'i, mida saab tagasi võtta, ja pipeline käsitleb neid erinevalt: koodi revert ehitab uue image'i, boti commit'i revert muudab ainult `k07-k8s/`-i ja `gitops` jätab selle vahele.

Piirangud on samad mis tööl. Kasutaja ei näe katkestust. Eelmine versioon peab olema klastris tagasi enne, kui uus `ci` jõuab lõppeda. Pärast taastamist ei tohi ükski järgmine commit vigast koodi uuesti klastrisse viia. Kumba commit'i ja mis järjekorras tagasi võtad, otsustad ise.

1. Käivita teises terminalis kasutaja vaate logi ja jäta see etapi lõpuni tööle:

    ```bash
    H='Host: labori-seis-<github>.lab.hkhk.ee'
    while sleep 2; do echo "$(date +%T) $(curl -s -o /dev/null -m 5 -w '%{http_code}' -H "$H" http://k3s.lab.hkhk.ee/health)"; done | tee ~/k07-katse/halb-kood.log
    ```

2. Tee main'i commit, mis läbib `ci` testid, aga mille järel rakendus ei leia andmebaasi:

    ```bash
    git switch main && git pull
    sed -i 's/DB_PORT:3306/DB_PORT:3307/' src/main/resources/application.properties
    git commit -am "db port" && git push
    ```

3. Kui `gitops` on tag'i kirjutanud ja Argo selle klastrisse viinud, vaata uue pod'i olekut ja põhjust:

    ```bash
    kubectl get rs,pods -l app=app01
    kubectl get events --field-selector reason=Unhealthy --sort-by=.lastTimestamp | tail -3
    ```

4. Taasta teenus ja main. Kirjuta issue'sse kolm kellaaega: halb tag klastris, eelmine image jälle ainus töötav, parandatud kood klastris.
5. Kontrolli tulemust:

    ```bash
    grep -vc ' 200$' ~/k07-katse/halb-kood.log
    grep -c 'DB_PORT:3306' src/main/resources/application.properties
    kubectl get deploy app01 -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
    curl -s -H "$H" http://k3s.lab.hkhk.ee/version; echo
    ```

Uus pod on `Running 0/1`: liveness kontrollib `/health/live`-i ja see vastab, readiness näeb `/health`-is `"db":"DOWN"`. Pod'i ei taaskäivitata, rollout jääb pooleli ja `maxUnavailable: 0` hoiab vana pod'i teenindamas, nii et logis on ainult `200`. Kiireim taastamine on boti commit'i revert: see muudab ainult `k07-k8s/40-app.yaml`-i, `gitops` jätab selle vahele ja Argo viib eelmise tag'i klastrisse järgmisel Giti lugemisel. Revert'i sõnumisse kopeeritakse ka `[skip ci]`, nii et `ci` ei käivitugi. Üksi sellest ei piisa: vigane kood on main'il alles ja järgmine koodimuudatus ehitab selle uuesti image'isse. Seepärast tuleb ka koodi revert, mis läbib `ci` ja mille SHA bot kirjutab manifesti. Kui push'id mõlemad revert'id korraga ja viimane neist on boti commit'i revert, võib `[skip ci]` jätta ka koodi revert'i ehitamata.

✅ **Edasi saad minna, kui** logis pole ühtegi muud koodi kui `200`, issue's on kolm kellaaega ja põhjendus, kumb revert enne, `grep -c 'DB_PORT:3306'` annab 1 ning `/version` näitab koodi revert'i SHA-d.

📎 **Selle mooduli tõend:** issue `K7.7` kommentaaris `Synced Healthy`, `argocd app get … | head -12`, kolm klappivat SHA-d, drift'i kestus sekundites, `OutOfSync` ilma selfHeal'ita, prune'i `NotFound`, katkise YAML-i `ComparisonError` rida, `git log --oneline -3` (halb commit + revert), halva koodi kolm kellaaega koos põhjendusega ja `grep -vc ' 200$'` tulemus 0.

## Miks see nii töötab

**Boti push ja tsükkel.** `GITHUB_TOKEN`-iga tehtud push ei käivita `push`- ega `pull_request`-sündmusega workflow'sid, seega boti commit ei tekita tsüklit. `gitops.yml` ei kirjuta üle commit'i, mis muutis ainult manifeste, muidu taastaks CI mõne minuti pärast sinu tehtud vea asemel eelmise oleku.

**Vanem SHA ei kirjuta uuemat üle.** Workflow kontrollib ka, kas manifestis on juba uuem SHA. Kui kaks `ci`-käivitust lõpevad vales järjekorras, ei asenda vanem SHA uuemat.

**Argo CD komponendid.** Koolitaja klastris näitab `kubectl -n argocd get pods` kolme põhikomponenti. `argocd-repo-server` kloonib repo ja renderdab manifestid, `argocd-application-controller` võrdleb neid klastriga ja viib muudatused klastrisse, `argocd-server` pakub kasutajaliidest ja API-t.

**Application'i olek.** Sinu vaates on sama info Application-objektis: `status.sync`, `status.health`, `status.operationState`. `argocd app diff` teeb sama võrdluse nagu `kubectl diff -f k07-k8s/`.

**Olek `Unknown`.** Kui repo-server ei suuda kausta renderdada, näiteks katkise YAML-i korral, ei jõua controller võrdluseni ja olek on `Unknown`.

**Argo CD kaks tempot.** Argo CD loeb Giti perioodiliselt (klassis iga 60 s järel) või kohe pärast refresh-signaali. Klastrit jälgib Argo CD pidevalt API serveri watch-mehhanismi kaudu. Seetõttu tühistas selfHeal käsitsi tehtud `scale`-muudatuse mõne sekundiga, kuid uus commit jõudis klastrisse alles järgmisel Giti lugemisel. Tootmises saadab GitHub pärast push'i Argo CD-le webhook'i ja Git loetakse kohe. Klassis webhook VPN-i taha ei jõua, seepärast küsib Argo CD Giti ise.

**Manifestid rakendusest lahus.** Levinud muster on eraldi repod rakenduse koodile ja manifestidele: rakenduse pipeline muudab teises repos näiteks `yq`-ga `values.yaml`-i ja push'ib. [Lahutusel on põhjus](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/): manifestide ajalugu on puhas deploy'de ajalugu ja ligipääsu saab anda eraldi. Meil on üks repo õppija kohta, nii et lahutus käib kaustade järgi: Argo CD loeb ainult `k07-k8s/` ülemist taset ja CI kirjutab ainult faili `k07-k8s/40-app.yaml`.

**Sync ja health.** Sync-olek ja health-olek ei sõltu teineteisest: `Synced` tähendab, et klaster vastab Gitile, `Healthy`, et objektid on oma tüübi kriteeriumide järgi korras.

**Application sinu namespace'is.** [Application sinu namespace'is](https://argo-cd.readthedocs.io/en/stable/operator-manual/app-any-namespace/) on Argo CD lisavõimalus. Vaikimisi asuvad Application'id namespace'is `argocd`.

**Ainult ülemine tase.** `kubectl apply -f k07-k8s/` ja Argo CD loevad vaikimisi ainult kausta ülemist taset. Seetõttu ei jõua kausta `examples/` all olev Secret'i näidis klastrisse.

Kui jõudsid kiiremini: [Lisaülesanded → 19. Deploy heakskiiduga: CI teeb PR-i](lisa.md#19-deploy-heakskiiduga-ci-teeb-pr-i), paned CI boti tegema PR-i, nii et Argo CD muudab klastrit alles pärast sinu merge'i.
