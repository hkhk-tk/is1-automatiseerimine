---
tags:
  - Kubernetes
  - RBAC
---

# 2. Namespace ja põhiobjektid

Jagatud klastris ebaõnnestub deploy sageli põhjusel, mida sinu YAML-is pole: RBAC keelab, kvoot on täis või Service ei leia pod'e, sest label ei klapi. Koolitaja klastris on sul üks namespace `is-<github>`, ja enne kui sinna midagi paigaldad, pead teadma, mida sul seal teha lubatakse ja kui palju ressurssi sul on. Siis lood YAML-failist Deployment'i, Service'i, ConfigMap'i ja Secret'i ning vaatad, kuidas Deployment, ReplicaSet, pod ja Service label'ite kaudu üksteist leiavad. Samadest objektidest koosneb Labori seis, ja kui seal mõni lüli katki läheb, tunned selle ära.

Katsefailid on kaustas `~/k07-katse`, mitte repos.

**Kui teed seda tööl iga päev:** `kubectl auth can-i --list` ja Service'i selector'i ning Endpoints'i seos on sulle tuttavad. Kui see on sul juba korras, tee esimeste etappide tõendi käsud ära ja mine otse etappi „[ConfigMap ja Secret testpodis](#configmap-ja-secret-testpodis)“.

## Kes sa klastris oled

Manifestides namespace'i ei ole, see tuleb context'ist. Õigused tulevad RoleBinding'ust, mille koolitaja sinu namespace'is ClusterRole'ile `edit` tegi. Sa ei näe RoleBinding'ut ise, aga saad API serverilt küsida, mida sa teha tohid.

Kui sa oma õigusi ei tea, tõlgendad `Forbidden`-it valesti: otsid viga manifestist, kuigi API server keeldus päringut täitmast. Teisalt peab admin teadma, mida kasutaja *saab* teha, sest see on ka see, mida ründaja tema kubeconfig'iga teha saaks.

1. Vaata context'i, kasutajat ja kahte põhiõigust:

    ```bash
    kubectl config get-contexts
    kubectl auth whoami
    kubectl auth can-i create deployments
    kubectl auth can-i create namespaces
    ```

2. Küsi veel viie tegevuse kohta. Kirjuta issue'sse tabel "tegevus | vastus | miks nii":

    ```bash
    for r in 'get nodes' 'create networkpolicies' 'create rolebindings' 'create applications.argoproj.io' 'list secrets'; do
        printf '%-36s %s\n' "$r" "$(kubectl auth can-i $r)"
    done
    kubectl auth can-i patch pods --subresource=ephemeralcontainers
    ```

3. Vaata kvooti, vaikeväärtusi ja node'e:

    ```bash
    kubectl describe resourcequota
    kubectl describe limitrange
    kubectl get nodes -o wide
    ```

4. Salvesta oma õiguste nimekirja algus:

    ```bash
    kubectl auth can-i --list | head -20
    ```

5. Proovi sama küsimust teise namespace'i kohta. Nii näed, et õigus kehtib ainult sinu omas:

    ```bash
    kubectl auth can-i create deployments -n kube-system
    kubectl get pods -n kube-system
    ```

> Ajutise konteineri vastus sõltub koolitaja seadistusest. Vaikimisi `edit`-rollis seda pole, sest debug-konteiner läheb mööda pod'i loomise kontrollidest. Kui vastus on `no`, kasuta `kubectl debug --copy-to`-d, mida proovid [Ressursside ja rikkeotsingu](lab-3-ressursid.md) lehel.

Nende vastuste põhjal joonistub välja sinu piir. Workload'e ja Secret'eid tohid luua, aga Role'e, RoleBinding'uid, namespace'e ega kvooti mitte. Seega ei saa sa endale ise õigusi juurde anda ega naaberõppija tööd puutuda. `get nodes` võib vastata `yes`, sest node'ide lugemine on lisatud eraldi: näed, kus pod'id töötavad, aga node'e muuta ei saa. `kube-system` vastus `no` tõestab, et RoleBinding kehtib ainult sinu namespace'is.

✅ **Edasi saad minna, kui** context'i NAMESPACE veerus on `is-<github>`, deployment'e `yes`, namespace'e `no`, `kube-system`-is `no`, ja tead oma [kvoodi](https://kubernetes.io/docs/concepts/policy/resource-quotas/) piire (requests 1 CPU / 2 Gi, 15 pod'i, 1 NodePort, 0 LoadBalancer'it) ning LimitRange'i vaikeväärtusi.

## Deployment failist, mitte peast

YAML-i ei kirjutata nullist. Lased kubectl'il manifesti genereerida, loed läbi, mis tuli, ja eemaldad tühjad väljad. Siis lisad requests'id, sest sinu namespace'i kvoot nõuab neid.

Peast kirjutatud YAML-is on taandevead ja valesti kirjutatud väljanimed. API server lükkab osa neist tagasi, aga osa jätab vaikselt tähelepanuta, ja siis töötab objekt teisiti, kui arvasid. Genereeritud template annab sulle õige kuju ja sina muudad ainult väärtusi.

1. Genereeri manifest:

    ```bash
    mkdir -p ~/k07-katse && cd ~/k07-katse
    kubectl create deployment web --image=nginx:1.30-alpine --port=80 --dry-run=client -o yaml > web.yaml
    ```

2. Kustuta failist read `creationTimestamp: null`, `strategy: {}`, `resources: {}` ja `status: {}`.
3. Lisa konteinerile `resources.requests` (`cpu: 20m`, `memory: 32Mi`) ja kontrolli faili serveri vastu enne `apply`-d:

    ```bash
    kubectl apply -f web.yaml --dry-run=server
    kubectl explain deployment.spec.template.spec.containers.resources
    ```

4. Tee `kubectl apply` ja vaata omandiahelat:

    ```bash
    kubectl apply -f web.yaml
    kubectl get deploy,rs,pods -l app=web
    kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}'; echo
    ```

Nimedest näed omandiahelat: pod `web-<räsi>-<juhuslik>` kuulub ReplicaSet'ile `web-<räsi>`, ReplicaSet Deployment'ile. `--dry-run=server` saatis faili API serverile kontrolliks, aga ei salvestanud seda. Nii leiad kvoodi, LimitRange'i ja skeemi vead enne, kui midagi klastris muutub. Kui ownerReference oleks puudu, oleks pod "orb" ja keegi ei looks seda uuesti.

✅ **Edasi saad minna, kui** `--dry-run=server` vastas `(server dry run)`, näed üht Deployment'i, üht ReplicaSet'i ja üht pod'i olekus READY 1/1 ning pod'i omanik on `ReplicaSet`.

## Kustutatud pod tuleb tagasi

Kustutad pod'i ja vaatad, kuidas klaster selle asendab. Kubernetes võrdleb pidevalt soovitud ja tegelikku olekut. ReplicaSet-kontroller näeb vahet "soovitud 1, tegelik 0" ja loob uue pod'i.

Klassikalises serveris taastab seiskunud teenuse systemd samal masinal. Siin on uus pod uue nimega ja võib-olla teisel node'il. Seepärast ei tohi miski sõltuda pod'i nimest ega IP-st, ainult Service'ist ja label'itest.

1. Jälgi pod'e teises terminalis:

    ```bash
    kubectl get pods -l app=web -w -o wide
    ```

2. Kustuta esimeses terminalis pod: `kubectl delete pod -l app=web`
3. Muuda failis `replicas: 2` ja käivita `kubectl apply -f web.yaml`.
4. Vaata, mida kontroller sündmustesse kirjutas:

    ```bash
    kubectl get events --field-selector involvedObject.kind=ReplicaSet --sort-by=.lastTimestamp | tail -3
    ```

Jälgimisaknas tekkis uus pod enne, kui vana oli lõplikult kadunud: kontroller ei oota koristust, vaid täidab puuduva koha kohe. IP oli uus, node võis olla teine. Sündmustes on `SuccessfulCreate` ReplicaSet'i nimel, mitte sinu nimel, sest pod'i lõi kontroller.

✅ **Edasi saad minna, kui** vana pod oli Terminating, uus tekkis sekunditega uue nime ja IP-ga, Events'is on `SuccessfulCreate` ja `kubectl get pods -l app=web` näitab nüüd kahte pod'i.

## Service ja port-forward

Paned pod'ide ette Service'i. Service valib pod'id label'i järgi ja annab neile ühe püsiva nime ja ClusterIP. ClusterIP töötab ainult klastri sees. `port-forward` teeb API serveri kaudu tunneli sinu masinasse, et saaksid teenust testida ilma Ingress'ita.

Service'i ja pod'i seos on ainult label'is. Üks kirjaviga selector'is ja Service on olemas, DNS-nimi laheneb, aga liiklus ei jõua kuhugi. See on üks levinumaid põhjuseid, miks "kõik on roheline, aga leht ei avane".

1. Loo Service failist ja vaata Endpoints'e:

    ```bash
    kubectl expose deployment web --port=80 --dry-run=client -o yaml > web-svc.yaml
    kubectl apply -f web-svc.yaml
    kubectl get svc web
    kubectl get endpoints web
    kubectl get pods -l app=web -o wide
    ```

2. Tee tunnel ja proovi:

    ```bash
    kubectl port-forward svc/web 8080:80 &
    curl -sI http://localhost:8080 | head -1
    kill %1
    ```

3. Proovi LoadBalancer-tüüpi Service'it. LoadBalancer võtaks pordi kõigil node'idel kogu klassi eest:

    ```bash
    kubectl expose deployment web --name=web-lb --port=8081 --target-port=80 --type=LoadBalancer
    ```

> Kui Endpoints on `<none>`, ei vasta Service'i `selector` pod'i label'ile. Võrdle `kubectl get svc web -o yaml | grep -A2 selector` ja `kubectl get pods --show-labels`.

Endpoints'i IP-d on samad mis pod'ide IP-d. See on tõend, et selector leidis pod'id ja et need on Ready. LoadBalancer'i viga ei tulnud võrgust, vaid kvoodist: API server keeldus objekti salvestamast, enne kui ükski kontroller seda nägi.

✅ **Edasi saad minna, kui** Endpoints'i IP-d on samad mis pod'ide IP-d, curl annab `HTTP/1.1 200 OK` ja LoadBalancer annab vea `exceeded quota: … services.loadbalancers=0`.

## Pod karantiini label'iga

Seda võtet kasutavad adminid tootmises. Kui üks pod käitub imelikult, ei kustuta sa seda, vaid muudad tema label'it. Service ja ReplicaSet ei vali seda pod'i enam: liiklus lõpeb, kontroller loob asenduse, ja vigane pod jääb uurimiseks alles.

Pärast pod'i kustutamist näitab `kubectl logs` midagi ainult siis, kui logikoguja jõudis read ära saata, ja protsessi mälu ning ühenduste olekut ei näita enam miski. Label'i muutmine annab sulle aega põhjust otsida, ilma et kasutajad seda pod'i näeksid.

1. Vali üks pod ja vii see karantiini:

    ```bash
    P=$(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}')
    kubectl label pod "$P" app=karantiin --overwrite
    kubectl get pods -L app
    kubectl get endpoints web
    ```

2. Vaata, kellele pod nüüd kuulub:

    ```bash
    kubectl get pod "$P" -o jsonpath='{.metadata.ownerReferences}'; echo
    kubectl logs "$P" --tail=3
    ```

3. Kui oled valmis, kustuta karantiinis pod: `kubectl delete pod "$P"`

Pärast label'i muutmist on pod'e kolm: kaks `app=web` ja üks `app=karantiin`. Endpoints'is on ainult kaks IP-d ja karantiinis pod'i IP sealt kadus. `ownerReferences` on tühi, sest ReplicaSet vabastas pod'i, mis tema selector'iga enam ei sobi. Pod töötab edasi ja tema logid on alles, aga keegi ei saada talle liiklust.

✅ **Edasi saad minna, kui** karantiinis pod'i IP kadus Endpoints'ist, ReplicaSet lõi asenduse, karantiinis pod'il polnud omanikku ja ta on nüüd kustutatud.

## ConfigMap ja Secret testpodis

Annad konteinerile seadistust kahel viisil: keskkonnamuutujana ja failina. Konteiner ei tea, kust muutuja või fail tuli. Siis muudad mõlemat ja vaatad, kumb jõuab töötavasse pod'i.

See vahe on sage intsidentide põhjus. Keegi muudab ConfigMap'i, näeb, et objekt on uuendatud, ja eeldab, et rakendus kasutab uut väärtust. Kui rakendus loeb seda keskkonnamuutujast, töötab ta vana väärtusega seni, kuni pod uuesti käivitub.

1. Loo kaks ConfigMap'i ja Secret:

    ```bash
    kubectl create configmap katse --from-literal=DB_HOST=db01 --from-literal=LAB=lab-07
    kubectl create secret generic katse --from-literal=PAROOL=salajane
    printf 'tase=1\n' > app.conf && kubectl create configmap katse-fail --from-file=app.conf
    ```

2. Kirjuta `test-pod.yaml` ise:
    - Pod `test`, image `busybox:1.37`, `resources.requests` nagu `web`-il
    - `command: ["sh", "-c", "printenv | sort; sleep 3600"]`
    - `envFrom` mõlemast (`configMapRef` ja `secretRef`)
    - volume ConfigMap'ist `katse-fail` kausta `/etc/katse`

    Välju leiad käsuga `kubectl explain pod.spec.containers.envFrom` ja `kubectl explain pod.spec.volumes.configMap`.

3. Tee `kubectl apply` ja loe väärtused:

    ```bash
    kubectl apply -f test-pod.yaml
    kubectl logs test | grep -E 'DB_HOST|LAB|PAROOL'
    kubectl exec test -- cat /etc/katse/app.conf
    kubectl get secret katse -o jsonpath='{.data.PAROOL}' | base64 -d; echo
    ```

4. Muuda nüüd mõlemat ja oota, kuni kubelet volume'i uuendab:

    ```bash
    printf 'tase=2\n' > app.conf
    kubectl create configmap katse-fail --from-file=app.conf --dry-run=client -o yaml | kubectl apply -f -
    kubectl patch configmap katse -p '{"data":{"LAB":"lab-99"}}'
    sleep 60; kubectl exec test -- cat /etc/katse/app.conf; kubectl exec test -- printenv LAB
    ```

5. Vaata, kus parool nähtav on ja kus mitte:

    ```bash
    kubectl describe secret katse | tail -3
    kubectl get pod test -o yaml | grep -c salajane
    kubectl exec test -- printenv PAROOL
    ```

> [kubelet uuendab ConfigMap'i volume'it](https://kubernetes.io/docs/concepts/configuration/configmap/), keskkonnamuutujad loetakse aga ainult konteineri käivitusel. Seepärast ei piisa keskkonnamuutujana loetud ConfigMap'i parandamisel `apply`-st, vaja on ka `rollout restart`-i.

Fail näitas pärast minutit `tase=2`, muutuja näitas ikka `lab-07`. Sama ConfigMap'i objekt, kaks eri tulemust, ja vahe on ainult selles, kuidas pod seda loeb. `describe secret` näitab ainult baitide arvu ja pod'i YAML-is parooli pole, aga `exec` näitab seda selgelt. Parooli kaitseb seega õigus `exec`-ile ja Secret'ite lugemisele, mitte base64.

✅ **Edasi saad minna, kui** logis on kõik kolm muutujat, Secret dekodeeritult on `salajane`, failis on pärast muudatust `tase=2`, `printenv LAB` näitab ikka `lab-07` ja `grep -c salajane` pod'i YAML-is annab 0.

📎 **Selle mooduli tõend:** issue `K7.2` kommentaaris `can-i` tabel viie tegevusega, `can-i --list` 20 rida, owner `ReplicaSet`, Endpoints = pod'ide IP-d, karantiini katse `get pods -L app` väljund, `kubectl logs test` kolm rida ja `printenv LAB` väljund.

## Miks see nii töötab

**Namespace context'ist.** Kui context'i namespace on vale, luuakse objektid vales namespace'is või saad vea `Forbidden`.

**RBAC-i piirang.** RBAC-is kehtib põhimõte, et kasutaja saab teisele anda ainult neid õigusi, mis tal endal on, ja roll `edit` ei luba RoleBinding'uid luua.

**Service'i tüübid.** LoadBalancer-tüüpi Service hõivaks k3s-i vaikimisi koormusjaoturiga (ServiceLB) pordi kõigil node'idel. NodePort'i vaikevahemik on 30000–32767 ja port avatakse igal node'il. Tootmises kasutatakse NodePort'i harva.

**Label'id ja karantiin.** Ka ReplicaSet'i ja pod'i seos põhineb ainult label'il. Seetõttu töötas karantiini võte: üks `kubectl label` eemaldas pod'i mõlemast seosest, kuid protsess ise jäi muutmata.

**ConfigMap'i uuendus.** Volume'ina mount'itud ConfigMap uueneb töötavas pod'is kubeleti sünkroonimise järel, vaikeseadetega tavaliselt umbes minuti jooksul. Kubelet kirjutab volume'isse faili uue versiooni ja vahetab sümbollingi, nii et rakendus näeb kas vana või uut faili, mitte poolikut. Erand on `subPath`-iga mount'itud fail, mis ei uuene üldse.

**Secret.** Secret'i väärtus on base64-kodeeringus, nii et kasutaja, kellel on õigus Secret'it lugeda (ka `list`, mitte ainult `get`), näeb parooli. Koolitaja klastris on Secret'id etcd-s lisaks krüpteeritud, kuid see kaitseb andmeid kettal, mitte API kaudu lugemise eest.

Kui jõudsid kiiremini: [Lisaülesanded → 15. Oma klaster: namespace nagu klassis](lisa.md#15-oma-klaster-namespace-nagu-klassis), teed oma klastris sama namespace'i, kvoodi ja piiratud õigustega kasutaja, mille koolitaja tegi sinu jaoks.
