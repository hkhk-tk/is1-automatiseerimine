---
tags:
  - Kubernetes
  - k3s
---

# Loeng: Kubernetes

3\. kohtumisel käivitasid Dockeri ja Compose'iga konteinerid ühes masinas ning 4. kohtumisel lõid OpenTofuga masinad koodist. Täna vaatad, kuidas konteinereid hallatakse siis, kui masinaid on mitu ja rakendus peab töötama ka rikke ajal. Selleks on Kubernetes: sina kirjeldad soovitud olekut ja Kubernetes hoiab seda pidevalt.

??? abstract "Õpiväljundid"

    Pärast loengut ja praktikumi oskad:

    - selgitada, miks konteinereid hallatakse klastris ja mida teeb orkestreerija;
    - selgitada soovitud ja tegeliku oleku abil, miks Kubernetes asendab kustutatud pod'i ise;
    - nimetada klastri osad ja selgitada, kuidas `kubectl` klastriga räägib;
    - lugeda Deployment'i ja Service'i YAML-faili ning selgitada, kuidas need siltide kaudu seotud on;
    - leida pod'i olekust ja sündmustest, miks pod ei käivitu;
    - selgitada, mida teevad Helm ja Argo CD ning kuhu need Kubernetese kõrval kuuluvad.

## 1. Miks orkestreerimine

Compose'iga töötasid kõik konteinerid ühes masinas. Restart-reegel (`restart: unless-stopped`) käivitab seiskunud konteineri uuesti, aga ainult samas masinas. Kui masin ise läheb rikki või vajab hooldust, ei vii keegi konteinereid teise masinasse ja rakendus seisab.

Seda probleemi lahendab **orkestreerimine**. Orkestreerija on tarkvara, mis otsustab, millises masinas konteiner töötab, asendab rikkis koopiad ja vahetab versioonid järk-järgult välja. Administraator kirjeldab, mis peab töötama ja mitu koopiat, ja masina valib orkestreerija.

<figure style="max-width:690px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 690 250" role="img" aria-label="Vasakul üks Docker-host, kus kõik neli teenust seisavad, kui host läheb rikki. Paremal klaster: control plane hoiab soovitud olekut, node 2 läks rikki ja app01 pod luuakse uuesti node 3-l." xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .ok{fill:#2e7d32;fill-opacity:.14;stroke:#2e7d32;stroke-width:1.3}.lx .bad{fill:#c62828;fill-opacity:.12;stroke:#c62828;stroke-width:1.3}.lx .zone{fill:none;stroke:var(--md-default-fg-color--lighter);stroke-width:1.2;stroke-dasharray:5 4}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:13px;font-family:var(--md-code-font-family,monospace)}.lx .w{fill:#c62828;font-size:13.5px;font-weight:700}.lx .g{fill:#2e7d32;font-size:13.5px;font-weight:700}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:4 3}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<text class="t" x="165" y="22" text-anchor="middle">Compose: üks host</text>
<rect class="zone" x="10" y="34" width="310" height="210" rx="8"/>
<rect class="bad" x="40" y="58" width="250" height="110" rx="6"/><text class="b" x="165.0" y="100.0" text-anchor="middle">docker01</text><text class="s" x="165.0" y="118.0" text-anchor="middle">app01, db01, mc01, rmq01</text><text class="s" x="165.0" y="136.0" text-anchor="middle">host läks rikki</text>
<text class="w" x="165" y="200" text-anchor="middle">Teenused seisavad, kuni keegi</text>
<text class="w" x="165" y="220" text-anchor="middle">hosti parandab või uue teeb</text>
<text class="t" x="515" y="22" text-anchor="middle">Kubernetes: klaster</text>
<rect class="zone" x="360" y="34" width="320" height="210" rx="8"/>
<rect class="hi" x="380" y="48" width="280" height="44" rx="6"/><text class="b" x="520.0" y="66.0" text-anchor="middle">control plane</text><text class="s" x="520.0" y="84.0" text-anchor="middle">hoiab soovitud olekut: app01 × 2</text>
<rect class="box" x="380" y="120" width="84" height="70" rx="6"/><text class="b" x="422.0" y="151.0" text-anchor="middle">node 1</text><text class="s" x="422.0" y="169.0" text-anchor="middle">app01</text>
<rect class="bad" x="478" y="120" width="84" height="70" rx="6"/><text class="b" x="520.0" y="142.0" text-anchor="middle">node 2</text><text class="s" x="520.0" y="160.0" text-anchor="middle">app01</text><text class="s" x="520.0" y="178.0" text-anchor="middle">rikkis</text>
<rect class="ok" x="576" y="120" width="84" height="70" rx="6"/><text class="b" x="618.0" y="151.0" text-anchor="middle">node 3</text><text class="s" x="618.0" y="169.0" text-anchor="middle">app01 uus</text>
<path class="a d" d="M520,190 C520,222 618,222 618,193" marker-end="url(#lxa)"/>
<text class="g" x="520" y="236" text-anchor="middle">pod luuakse uuesti teisel node'il</text>
</svg>
<figcaption>Joonis 5.1. Ühe hosti rike peatab Compose'i stacki, klastris luuakse pod teisel node'il uuesti (Talvik, 2026).</figcaption>
</figure>

Virtuaalmasinatega töötanud administraator tunneb sama mõtet Proxmoxi kõrgkäideldavusest (HA): kui server kaob, käivitatakse VM teises serveris. Kubernetes teeb sama üksiku rakenduse tasemel ja palju kiiremini, sest konteineri käivitamiseks ei pea operatsioonisüsteemi laadima.

??? note "Tabel 5.1. Compose ja Kubernetes"

    | | Docker Compose | Kubernetes |
    |---|---|---|
    | Masinad | üks | mitu node'i |
    | Kui masin kaob | konteinerid seisavad, kuni masin on tagasi | pod'id luuakse teistel node'idel uuesti |
    | Koopiate arv | tavaliselt üks konteiner teenuse kohta | `replicas` ütleb, mitu koopiat töötab |
    | Kirjeldus | `compose.yaml` | YAML-failid, igas üks või mitu objekti |
    | Väljast ligipääs | masina port | Service ja Ingress |

**Millal Kubernetest ei ole vaja.** Klaster lisab tööd: seda tuleb uuendada, jälgida ja varundada ning meeskond peab õppima uue sõnavara. Üks väike rakendus ühes serveris töötab hästi ka Compose'i või systemd teenusena. Kubernetes tasub ära siis, kui teenuseid ja masinaid on palju või kui rakendus peab rikke ajal töötama.

## 2. Kust Kubernetes tuli ja mis on k3s

**Mis see on.** Kubernetes on avatud lähtekoodiga orkestreerija. Nimi tuleb kreeka keelest ja tähendab tüürimeest. Lühend K8s tähendab, et K ja s vahel on kaheksa tähte.

**Mis oli enne.** Google käitas oma teenuseid konteinerites juba 2000. aastate keskel ja haldas neid sisemise süsteemiga Borg. Teised ettevõtted haldasid servereid ja nende teenuseid skriptide ja käsitsi.

**Mis on praegu.** 2014. aastal avaldas Google Borgi kogemuse põhjal Kubernetese ja 2015. aastal anti see Cloud Native Computing Foundationile ([CNCF](https://www.cncf.io/)), nii et Kubernetes ei kuulu ühele ettevõttele. Kubernetes on konteinerite haldamise standard ja kõigil suurtel pilveteenuse pakkujatel on hallatud Kubernetes: Amazon EKS, Azure AKS ja Google GKE.

**Kuhu see läheb.** Kubernetes muutub platvormiks, mille peale ehitatakse teisi tööriistu: paketihaldur Helm, GitOpsi tööriistad nagu Argo CD ja ettevõtete sisemised arendusplatvormid. Paljud meeskonnad ei halda klastrit ise, vaid kasutavad pilve hallatud klastrit ja tegelevad ainult rakendustega.

Kubernetes on standard, mille põhjal teevad mitu tootjat oma **jaotuse** ehk distributsiooni, nagu Linuxi tuumast tehakse Ubuntu ja AlmaLinux. Käsud ja YAML-failid on kõigis samad, erinevad paigaldus ja kaasa pandud lisad.

??? note "Tabel 5.2. Kubernetese jaotused"

    | Jaotus | Kellele | Märkus |
    |---|---|---|
    | **k3s** | väike klaster, servamasinad, õppimine | Rancher, 2019. Ühes programmis, kaasas Traefik ja kettaruum. Kursusel kasutad seda |
    | **k0s** | väike klaster | Mirantis. Samuti üks programm, lisad paigaldad ise |
    | **minikube**, **kind** | arendaja arvuti | ühe node'iga klaster virtuaalmasinas või Dockeris |
    | **EKS**, **AKS**, **GKE** | pilv | control plane'i haldab pilveteenuse pakkuja |
    | **OpenShift** | suured asutused | Red Hati Kubernetes koos lisatööriistade ja tasulise toega |

**k3s** paigaldub ühe käsuga ja vajab vähe mälu, sest kogu juhtimise osa on ühes programmis. Ühe masinaga klastris hoiab k3s andmeid SQLite'i andmebaasis. Täpsemalt: [k3s dokumentatsioon](https://docs.k3s.io/).

## 3. Soovitud olek ja kontroller

`docker run` on **imperatiivne** käsk: see ütleb, mida teha. Kubernetese YAML-fail on **deklaratiivne** kirjeldus: see ütleb, milline olek peab olema, ja süsteem leiab ise, mida selleks teha. Sama mõtet kasutasid Ansible'is ja OpenTofus: `state: present` või `resource` kirjeldab tulemust.

Lihtne näide: Deployment `tere` ütleb, et image'ist `traefik/whoami` peab töötama kolm pod'i. Kui klastris on kaks pod'i, luuakse kolmas. Kui neli, kustutatakse üks. Kui kolm, ei tehta midagi.

Kirjelduse täitmise eest vastutavad **kontrollerid**. Iga [kontroller](https://kubernetes.io/docs/concepts/architecture/controller/) on lõputu tsükkel: loe soovitud olekut, vaata tegelikku olekut ja tee samm, et vahe kaoks.

<figure markdown="span">
  ![Kontrolltsükkel: kubectl apply muudab soovitud olekut, kubectl delete pod muudab tegelikku olekut; kontroller loeb mõlemat ja loob puuduva pod'i](assets/k05_kontrolltsukkel.svg)
  <figcaption>Joonis 5.2. Kontroller võrdleb soovitud ja tegelikku olekut ning kõrvaldab vahe (Talvik, 2026).</figcaption>
</figure>

Kui pod kustutatakse, näeb kontroller vahet „soovitud 3, tegelik 2“ ja loob uue pod'i. Uus pod saab uue nime ja uue IP-aadressi. Seepärast ei tohi miski sõltuda pod'i nimest ega aadressist.

??? note "Tabel 5.3. Ansible ja Kubernetes"

    | | Ansible | Kubernetes |
    |---|---|---|
    | Soovitud olek | playbook ja muutujad | YAML-failid, salvestatud klastrisse |
    | Millal olekut kontrollitakse | siis, kui playbook'i käivitad | pidevalt |
    | Kui teenus seiskub | jääb seisma järgmise käivituseni | pod luuakse uuesti mõne sekundiga |
    | Mida hallatakse | masinad: paketid, failid, teenused | konteinerid, nende võrk ja seadistus |

Ansible ja Kubernetes ei välista teineteist. Ansible'iga paigaldatakse sageli klastri masinad ja k3s ise, Kubernetes hoiab seejärel rakendusi.

??? question "Kontrolli ennast"

    Administraator kustutab Deployment'i `tere` pod'i, et rakendus peatada. Minuti pärast töötab rakendus jälle. Miks?

    ??? success "Vastus"

        Pod'i kustutamine muutis ainult tegelikku olekut. Deployment'is on soovitud olek endiselt kolm pod'i ja kontroller lõi puuduva pod'i uuesti. Rakenduse peatamiseks tuleb muuta soovitud olekut: `replicas: 0` või kustutada Deployment ise.

## 4. Klastri osad ja kubectl

Klaster koosneb kahest osast. **Control plane** hoiab klastri kirjeldust ja otsustab, kus miski töötab. **Node**'idel töötavad pod'id. k3s-is võib sama masin olla korraga control plane ja node, nagu praktikumis sinu control.

<figure markdown="span">
  ![Control plane: API server, andmebaas, scheduler ja kontrollerid; node'il kubelet ja containerd](assets/k05_juhttasand.svg)
  <figcaption>Joonis 5.3. Kõik osad suhtlevad ainult API serveriga (Talvik, 2026).</figcaption>
</figure>

- **API server** võtab vastu kõik päringud ja kontrollib õigusi. Ta kuulab porti 6443.
- **etcd** (k3s-is ühe masina puhul SQLite) on andmebaas, kus on kogu soovitud olek.
- **Scheduler** valib igale uuele pod'ile node'i, kus on piisavalt vaba protsessorit ja mälu.
- **Kontrollerid** hoiavad soovitud olekut, näiteks pod'ide arvu.
- **kubelet** töötab igal node'il ja käivitab sellele node'ile määratud pod'id.
- **containerd** laadib image'i ja käivitab konteineri, nagu Docker.

Administraator ei logi node'idesse sisse ega käivita seal konteinereid. Kõik käsud lähevad API serverile käsuga **kubectl**. SSH leiab failist `~/.ssh/config`, kuhu ühenduda ja millise võtmega. kubectl leiab sama info failist `~/.kube/config`. Sellist faili nimetatakse lühidalt **kubeconfig**'iks. Seal on klastri aadress, sinu sertifikaat või token ja vaikimisi **nimeruum** (namespace). Nimeruum jagab klastri osadeks, näiteks iga meeskonna või keskkonna jaoks oma.

??? note "Tabel 5.4. Sagedasemad kubectl käsud"

    | Käsk | Mida teeb | Tuttav vaste |
    |---|---|---|
    | `kubectl get pods` | näitab pod'e ja nende olekut | `docker ps` |
    | `kubectl describe pod <nimi>` | näitab kõike pod'i kohta ja lõpus sündmusi | `docker inspect` |
    | `kubectl logs <nimi>` | näitab konteineri väljundit | `docker logs` |
    | `kubectl apply -f <fail>` | viib klastri failiga kooskõlla | `ansible-playbook`, `tofu apply` |
    | `kubectl diff -f <fail>` | näitab, mis muutuks | `--check --diff`, `tofu plan` |
    | `kubectl delete -f <fail>` | kustutab failis kirjeldatud objektid | `tofu destroy` |

## 5. Pod, Deployment ja Service

**Pod** on väikseim üksus, mida Kubernetes käivitab: üks või mitu konteinerit, millel on ühine IP-aadress. Pod'e otse tavaliselt ei looda. **Deployment** kirjeldab, mitu ühesugust pod'i peab töötama ja millisest image'ist. Deployment teeb vahepealse objekti **ReplicaSet**, mis hoiab pod'ide arvu. Versiooni uuendamisel teeb Deployment uue ReplicaSet'i ja vahetab pod'id järk-järgult. Seda nimetatakse **rolling update**'iks.

Iga uus pod saab uue IP-aadressi. **Service** annab pod'ide grupile püsiva nime ja aadressi ning jagab päringud nende vahel. Compose'is lahendas sama teenuse nimi: konteiner leidis teise nime järgi.

Deployment ja Service ei tea pod'ide nimesid. Need leiavad pod'id **siltide** (labels) järgi. Silt on võti ja väärtus, näiteks `app: tere`. Deployment paneb sildi igale pod'ile, mille ta loob, ja Service saadab liikluse kõigile pod'idele, millel see silt on. Sama mõte oli Ansible'i inventory gruppides.

<figure markdown="span">
  ![Deployment loob ReplicaSet'i, ReplicaSet loob pod'id, Service leiab pod'id sildi järgi](assets/k05_labelid.svg)
  <figcaption>Joonis 5.4. Deployment, ReplicaSet, pod ja Service on seotud ainult siltide kaudu (Talvik, 2026).</figcaption>
</figure>

Igas Kubernetese YAML-failis on samad neli osa. `apiVersion` ja `kind` ütlevad, mis tüüpi objekt see on. `metadata` annab nime ja sildid. `spec` on soovitud olek, mille kirjutad sina. `status` on tegelik olek, mille kirjutab Kubernetes.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tere
spec:
  replicas: 3                 # mitu pod'i peab töötama
  selector:
    matchLabels:
      app: tere               # Deployment'ile kuuluvad selle sildiga pod'id
  template:                   # mall, millest pod'id tehakse
    metadata:
      labels:
        app: tere             # sama silt igale uuele pod'ile
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.11.0
```

Service'i tüüp ütleb, kust see on kättesaadav. **ClusterIP** on vaikimisi tüüp ja on nähtav ainult klastri sees. **NodePort** avab lisaks pordi igal node'il vahemikus 30000–32767. **LoadBalancer** küsib pilves koormusjaoturi. Veebirakenduse jaoks kasutatakse tootmises **Ingress**'i, mis suunab päringu nime järgi õigesse Service'isse. k3s-is teeb seda Traefik.

??? question "Kontrolli ennast"

    Service'i failis on `selector: app: tere`, aga Deployment'i mallis on silt `app: Tere`. Mis juhtub, kui teed mõlemale `kubectl apply`?

    ??? success "Vastus"

        Mõlemad failid võetakse vastu ja pod'id töötavad, aga Service ei leia ühtegi pod'i, sest sildid on tõstutundlikud. `kubectl get endpointslices` näitab, et Service'il pole aadresse, ja päringud ei jõua kuhugi.

## 6. Kui pod ei käivitu

Pod'i olek ütleb, millises etapis see pidama jäi, ja põhjus on pod'i sündmustes. Kolm käsku leiavad enamiku vigu: `kubectl get pods` näitab olekut, `kubectl describe pod <nimi>` näitab lõpus sündmusi ja `kubectl logs <nimi>` näitab konteineri väljundit.

??? note "Tabel 5.5. Pod'i olekud ja kust põhjust otsida"

    | Olek | Mida tähendab | Kust otsida |
    |---|---|---|
    | `Pending` | pod'ile ei leitud node'i | `describe pod`: sündmused, näiteks `Insufficient memory` |
    | `ContainerCreating` | image laaditakse alla | oota, siis `describe pod` |
    | `ErrImagePull`, `ImagePullBackOff` | image'i ei saanud alla laadida | `describe pod`: `not found` tähendab vale nime või tag'i |
    | `CrashLoopBackOff` | konteiner lõpeb kohe ja käivitatakse üha pikema ootega uuesti | `logs <pod> --previous` |
    | `Running`, aga `READY 0/1` | konteiner töötab, aga ei ole valmis päringuid vastu võtma | `describe pod`: `Readiness probe failed` |

Rolling update kaitseb vigase versiooni eest. Kui uus pod ei käivitu, jäävad vanad pod'id tööle ja rakendus vastab edasi. `kubectl get deployment` näitab siis, et `UP-TO-DATE` on väiksem kui soovitud arv.

??? question "Leia viga"

    Administraator muudab Deployment'is image'i real `traefik/whoami:v1.11.0` väärtuseks `traefik/whoami:latest-amd`. Pärast `apply`-d näitab `kubectl get pods` üht pod'i olekus `ImagePullBackOff` ja kolme `Running`. Kas rakendus töötab? Kust põhjus leida ja kuidas parandada?

    ??? success "Vastus"

        Rakendus töötab, sest kolm vana pod'i jäid alles. `kubectl describe pod` näitab sündmust `not found`: Docker Hubis on tag `latest-amd64`, mitte `latest-amd`. Parandus käib failis: õige tag, seejärel `kubectl apply`. Tootmises ei kasutata tag'i `latest`, sest siis ei tea keegi, milline versioon töötab.

## 7. Helm ja GitOps

Kui rakenduses on kümneid YAML-faile ja neid on vaja paigaldada mitmesse keskkonda, muutub failide käsitsi haldamine raskeks. Selleks on kaks tööriista, mida praktikumi lisaülesannetes proovid.

**Helm** on Kubernetese paketihaldur, nagu `apt` Ubuntus. Pakett on **chart**: YAML-failide mallid koos vaikeväärtustega. Käsk `helm install` teeb mallidest failid ja saadab need klastrisse, `helm upgrade` uuendab ja `helm rollback` viib eelmise versiooni juurde. k3s paigaldab Traefiku ise Helmi chart'ina. Enamik valmis tarkvara, näiteks Argo CD, Prometheus ja andmebaasid, paigaldatakse Kubernetesesse Helmiga.

**GitOps** tähendab, et soovitud olek on Gitis ja klastris töötav tööriist viib klastri sellega kooskõlla. **Argo CD** on selline tööriist. See on samasugune kontroller nagu Kubernetese enda omad, ainult soovitud olek tuleb Gitist. Kui keegi muudab klastris midagi käsitsi, märkab Argo CD erinevust Gitiga ehk **triivi** (drift) ja muudab klastri tagasi.

<figure style="max-width:690px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 690 286" role="img" aria-label="Push-mudelis loeb CI runner Gitist ja käivitab kubectl apply, klastri võti on runneril. Pull-mudelis töötab Argo CD klastri sees, loeb Gitist soovitud oleku, rakendab selle ja pöörab käsitsi tehtud muudatused tagasi." xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .ok{fill:#2e7d32;fill-opacity:.14;stroke:#2e7d32;stroke-width:1.3}.lx .bad{fill:#c62828;fill-opacity:.12;stroke:#c62828;stroke-width:1.3}.lx .zone{fill:none;stroke:var(--md-default-fg-color--lighter);stroke-width:1.2;stroke-dasharray:5 4}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:13px;font-family:var(--md-code-font-family,monospace)}.lx .w{fill:#c62828;font-size:13.5px;font-weight:700}.lx .g{fill:#2e7d32;font-size:13.5px;font-weight:700}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:4 3}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<text class="t" x="10" y="22" text-anchor="start">Push: CI teeb deploy</text>
<rect class="box" x="10" y="34" width="140" height="56" rx="6"/><text class="b" x="80.0" y="58.0" text-anchor="middle">Git</text><text class="s" x="80.0" y="76.0" text-anchor="middle">manifestid</text>
<rect class="bad" x="250" y="34" width="170" height="56" rx="6"/><text class="b" x="335.0" y="58.0" text-anchor="middle">CI runner</text><text class="s" x="335.0" y="76.0" text-anchor="middle">hoiab klastri võtit</text>
<rect class="box" x="520" y="34" width="160" height="56" rx="6"/><text class="b" x="600.0" y="67.0" text-anchor="middle">klaster</text>
<line class="a" x1="150" y1="62" x2="248" y2="62" marker-end="url(#lxa)"/><text class="s" x="199" y="54" text-anchor="middle">push</text>
<line class="a" x1="420" y1="62" x2="518" y2="62" marker-end="url(#lxa)"/><text class="s" x="469" y="54" text-anchor="middle">kubectl apply</text>
<text class="w" x="345" y="112" text-anchor="middle">Käsitsi muudatus klastris jääb märkamata kuni järgmise deploy'ni.</text>
<text class="t" x="10" y="150" text-anchor="start">Pull: GitOps</text>
<rect class="box" x="10" y="162" width="140" height="56" rx="6"/><text class="b" x="80.0" y="186.0" text-anchor="middle">Git</text><text class="s" x="80.0" y="204.0" text-anchor="middle">soovitud olek</text>
<rect class="zone" x="250" y="156" width="430" height="120" rx="8"/>
<text class="s" x="680" y="150" text-anchor="end">klaster</text>
<rect class="hi" x="265" y="162" width="160" height="56" rx="6"/><text class="b" x="345.0" y="186.0" text-anchor="middle">Argo CD</text><text class="s" x="345.0" y="204.0" text-anchor="middle">klastri sees</text>
<rect class="ok" x="520" y="162" width="145" height="56" rx="6"/><text class="b" x="592.5" y="186.0" text-anchor="middle">default</text><text class="s" x="592.5" y="204.0" text-anchor="middle">tegelik olek</text>
<line class="a" x1="263" y1="182" x2="152" y2="182" marker-end="url(#lxa)"/><text class="s" x="208" y="174" text-anchor="middle">loeb</text>
<line class="a" x1="425" y1="182" x2="518" y2="182" marker-end="url(#lxa)"/><text class="s" x="471" y="174" text-anchor="middle">rakendab</text>
<path class="a d" d="M592,220 V244 H345 V222" marker-end="url(#lxa)"/>
<text class="s" x="470" y="258" text-anchor="middle">jälgib triivi, pöörab tagasi</text>
</svg>
<figcaption>Joonis 5.5. Push-mudelis saadab CI muudatuse klastrisse, pull-mudelis loeb klastris töötav agent selle Gitist (Talvik, 2026).</figcaption>
</figure>

Tavaline ahel töökohas on selline: konveier, näiteks GitHub Actions, ehitab ja testib image'i ning kirjutab selle uue tag'i Gitis olevasse YAML-faili. Argo CD näeb Gitis muudatust ja uuendab klastrit. Konveier ei vaja klastri parooli, klastrisse kirjutab ainult Argo CD. Nii töötavad ka Eesti ettevõtted, näiteks on Entigo kirjutanud selle ahela jaoks oma tööriista [k8s-entigo-gitops](https://github.com/entigolabs/entigo-k8s-gitops).

Helmi ja OpenTofut võrreldakse sageli, aga need töötavad eri tasemel. OpenTofu loob infrastruktuuri: võrgu, masinad ja klastri. Helm ja Argo CD paigaldavad rakendused juba olemasolevasse klastrisse. OpenTofus on olemas ka Helmi provider, aga klastri loomine ja rakenduste paigaldamine samas `apply`-s tekitab probleeme, sest provider vajab klastri aadressi juba enne, kui klaster on olemas. Seepärast hoitakse need tavaliselt eraldi.

??? abstract "Kokkuvõte"

    | Mõiste | Lühidalt |
    |---|---|
    | orkestreerimine | tarkvara valib konteinerile masina ja asendab rikkis koopiad |
    | k3s | ühes programmis Kubernetes, paigaldub ühe käsuga |
    | soovitud ja tegelik olek | kontroller võrdleb neid pidevalt ja kõrvaldab vahe |
    | control plane, node | juhtimise osa ja masinad, kus pod'id töötavad |
    | kubectl, kubeconfig | käsk klastriga rääkimiseks ja fail, kust see leiab aadressi ja sertifikaadi |
    | pod | üks või mitu konteinerit ühise IP-ga |
    | Deployment | hoiab soovitud arvu pod'e ja vahetab versioone järk-järgult |
    | Service | püsiv nimi ja aadress pod'ide grupile |
    | silt (label) | võti ja väärtus, mille järgi objektid üksteist leiavad |
    | Helm | paketihaldur, chart'id |
    | Argo CD | viib klastri Gitis kirjeldatud olekusse ja märkab triivi |
