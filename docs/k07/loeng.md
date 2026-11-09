---
tags:
  - Kubernetes
  - k3s
  - Argo CD
  - GitOps
  - Loeng
---

# Loeng: Kubernetes ja GitOps

3\. kohtumisel käivitas Compose Labori seisu ühes Docker-hostis ja 6. kohtumisel jõudis testitud image registry'sse. Täna viid sama rakenduse Kubernetese klastrisse. Klastris hoiavad soovitud olekut kontrollerid, mis töötavad pidevalt: kui pod kaob, luuakse uus. Loengu lõpus annad oleku hoidmise Argo CD-le, mis loeb soovitud oleku Gitist ja viib klastri sellega kooskõlla.

??? abstract "Õpiväljundid"

    Pärast loengut ja praktikumi oskad:

    - selgitada, miks rakendust käitatakse mitme masinaga klastris ja mida teeb orkestreerija;
    - ühendada kubectl'i klastriga kubeconfig'i abil ning selgitada namespace'i, õiguste ja kvoodi rolli jagatud klastris;
    - selgitada control loop'i abil, miks Kubernetes taastab kustutatud pod'i ise;
    - lugeda Deployment'i, Service'i, ConfigMap'i, Secret'i, PVC ja Ingress'i manifesti ning selgitada, kuidas objektid label'ite kaudu seotud on;
    - eristada startup-, readiness- ja liveness-probe'i ning init-konteineri ülesannet ja leida käskudega `describe` ja `logs`, miks pod ei käivitu;
    - võrrelda push- ja pull-tüüpi deploy'd ning selgitada Argo CD sync policy't ja olekuid Synced ja Healthy.

    Requests'ide ja limits'ide valik, katkestuseta uuendus, NetworkPolicy, Helm ja Kustomize, GitOpsi riskid, klastri versiooniuuendus, SRE ja sündmuspõhine automaatika on kursuse IS2 [loengus](https://hkhk-tk.github.io/is2-automatiseerimine/k07/loeng/).

## Põhimõisted

Kubernetesel on oma sõnavara ja enamik termineid on inglise keeles. Materjalis kasutame ingliskeelseid termineid eestikeelsete käändelõppudega (pod'i, node'il), sest samu sõnu näed käskudes, veateadetes ja dokumentatsioonis.

- **Klaster** on hulk masinaid, mida hallatakse ühe tervikuna. Klastri masinat nimetatakse **node**'iks. Node võib olla virtuaalmasin või füüsiline server.
- **Pod** on väikseim üksus, mida Kubernetes käivitab: üks või mitu konteinerit, millel on ühine IP-aadress. Labori seisus on igas pod'is üks teenus.
- **Manifest** on YAML-fail, mis kirjeldab ühte või mitut objekti, näiteks „app01-st peab töötama üks koopia ja see käivitatakse sellest image'ist“.
- **kubectl** on käsurea tööriist, mis saadab manifestid ja päringud klastri API serverile.

??? note "Tabel 7.1. Kubernetese sõnavara ja tuttav vaste"

    | Termin | Tähendus | Tuttav vaste |
    |---|---|---|
    | klaster | masinad, mida hallatakse koos | Proxmoxi masinad, mis jagavad ühte haldust |
    | node | klastri masin | server |
    | control plane | klastri juhtkomponendid, mis hoiavad soovitud olekut | (uus mõiste, osa 3) |
    | pod | üks või mitu koos käivitatud konteinerit | Compose'i teenuse konteiner |
    | workload | klastris töötav rakendus või teenus | teenus serveris |
    | manifest | YAML-fail objekti kirjeldusega | `compose.yaml`, playbook |
    | namespace | nimeruum, mis eraldab objektid | Proxmoxi pool, kaust |
    | label, selector | silt ja sildi järgi valimine | Ansible'i inventory grupp |
    | probe | kontroll, kas konteiner töötab ja on valmis | Compose'i `healthcheck` |
    | Ingress | reegel väljast tuleva HTTP-liikluse suunamiseks | Nginxi `server_name` ja `proxy_pass` web01-s |

## 1. Miks orkestreerimine

### Üks host ei piisa

Compose'iga töötas Labori seis ühes Docker-hostis. Restart-poliitika (`restart: unless-stopped`) taaskäivitab seiskunud konteineri, aga ainult samas hostis. Kui host ise läheb rikki või vajab hooldust, ei vii keegi teenuseid teise masinasse ja rakendus seisab. Kui teenusel jääb ressurssidest puudu, saab teda kasvatada ainult sama hosti piires.

Neid probleeme lahendab **orkestreerimine**: tarkvara ehk orkestreerija otsustab, millises masinas konteiner töötab, asendab rikkis koopiad ja vahetab versioonid järjest välja. Masinad on orkestreerija jaoks ühine ressurss. Administraator kirjeldab, mida ja mitu koopiat peab töötama, ja masina valib orkestreerija.

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
<figcaption>Joonis 7.1. Ühe hosti rike peatab Compose'i stacki, klastris luuakse pod teisel node'il uuesti (Talvik, 2026).</figcaption>
</figure>

Virtuaalmasinatega töötanud admin tunneb sama mõtet Proxmoxi või VMware'i kõrgkäideldavusest (HA): kui server kaob, käivitatakse VM teises serveris. Kubernetes teeb sama üksiku rakenduse tasemel ja virtuaalmasinast palju kiiremini, sest konteineri käivitamiseks ei pea operatsioonisüsteemi laadima.

??? note "Tabel 7.2. Compose ja Kubernetes"

    | | Docker Compose | Kubernetes |
    |---|---|---|
    | Hostid | üks | mitu node'i |
    | Kui host kaob | teenused seisavad, kuni host on tagasi | pod'id luuakse teistel node'idel uuesti |
    | Hooldus | teenused seisavad hoolduse ajal | node tühjendatakse, pod'id kolivad mujale |
    | Koopiate arv | üks konteiner teenuse kohta (tavaliselt) | `replicas` ütleb, mitu koopiat töötab |
    | Kirjeldus | `compose.yaml` | YAML-manifestid, igas üks või mitu objekti |
    | Sõltuvused | `depends_on` | init-konteiner ja readiness-probe |
    | Väljast ligipääs | hosti port | Service ja Ingress |
    | Kus kasutatakse | arendaja arvuti, üks server | väike klaster ([k3s](https://docs.k3s.io/)), hallatud klaster pilves (EKS, AKS, GKE), OpenShift |

### Kust Kubernetes tuli

Google käitas oma teenuseid konteinerites juba 2000. aastate keskel ja haldas neid sisemise süsteemiga Borg. 2014. aastal avaldas Google Borgi kogemuse põhjal uue avatud lähtekoodiga projekti Kubernetes ja 2015. aastal ilmus versioon 1.0. Samal aastal anti projekt äsja loodud Cloud Native Computing Foundationile ([CNCF](https://www.cncf.io/)), nii et Kubernetes ei kuulu ühele ettevõttele. Nimi tuleb kreeka keelest ja tähendab tüürimeest, lühend K8s tähendab, et K ja s vahel on kaheksa tähte.

??? info "Süvenemiseks: Kubernetese jaotused ja alternatiivid"

    Kubernetes on standard, mille põhjal teevad mitu tootjat oma jaotuse ehk distributsiooni, nagu Linuxi tuumast tehakse Ubuntu ja AlmaLinux.

    - **k3s** on Rancheri (2019) väike jaotus, kus kogu control plane on ühes programmis. See sobib väikestesse klastritesse ja õppimiseks, kursusel töötab koolitaja klaster k3s-iga.
    - **Hallatud klaster** pilves (Amazon EKS, Azure AKS, Google GKE): control plane'i haldab teenusepakkuja, node'id ja rakendused jäävad kliendile.
    - **OpenShift** on Red Hati Kubernetes koos lisatööriistade ja tasulise toega, levinud suurtes asutustes.
    - **Docker Desktop** ja **minikube** käivitavad ühe node'iga klastri arendaja arvutis.
    - **Docker Swarm** on Dockeri enda orkestreerija. See on lihtsam, aga 2018. aastaks oli enamik tootjaid valinud Kubernetese.

### Millal Kubernetest ei ole vaja

Klaster lisab tööd: control plane'i ja node'e tuleb uuendada, jälgida ja varundada ning meeskond peab õppima uue sõnavara. Üks väike rakendus ühes serveris töötab hästi ka Compose'i või systemd teenusena. Kubernetes tasub ära siis, kui teenuseid ja masinaid on palju, kui rakendus peab rikke ajal töötama või kui asutus kasutab hallatud klastrit, mille control plane'i haldab teenusepakkuja.

**Leia viga.** Admin kirjutab plaani: „Panen `compose.yaml`-is kõigile teenustele `restart: always`. Kui host docker01 läheb rikki, käivituvad teenused ise uuesti.“

??? success "Vastus"

    - **Mida taheti:** rakendus peab töötama ka siis, kui host läheb rikki.
    - **Mis oli:** restart-poliitika, mis taaskäivitab konteineri sama hosti Dockeris.
    - **Õige:** teine host, kuhu teenused viiakse, ja orkestreerija, kes seda teeb, näiteks Kubernetese klaster, kus pod luuakse teisel node'il uuesti.
    - **Miks:** Compose ja Docker ei tea teistest hostidest midagi. Kui host on maas, ei tööta ka Docker, kes konteinerit taaskäivitaks.

## 2. Klaster, kubectl ja namespace

### Klastri osad

Klaster koosneb kahest osast. **Control plane** hoiab klastri kirjeldust ja otsustab, kus miski töötab. **Node**'idel töötavad pod'id. Väikeses k3s klastris võib sama masin olla korraga control plane ja node. Administraator ei logi node'idesse sisse ega käivita seal konteinereid: kõik käsud lähevad control plane'i **API serverile**, mis kuulab HTTPS-i porti 6443. Osa 3 näitab, mis API serveri taga juhtub.

### kubeconfig

SSH leiab failist `~/.ssh/config`, millise aadressiga ja millise kasutajaga ühenduda ning millist võtit kasutada. kubectl leiab sama info failist `~/.kube/config`. Sellist faili nimetatakse **kubeconfig**'iks ja selles on kolm osa:

- **klaster**: API serveri aadress ja CA sertifikaat, millega kubectl kontrollib, et räägib õige serveriga;
- **kasutaja**: sertifikaat või token, millega API server sind tuvastab;
- **context**: seob klastri ja kasutaja ning määrab vaikimisi namespace'i.

<figure style="max-width:690px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 690 200" role="img" aria-label="kubectl loeb failist ~/.kube/config klastri aadressi, kasutaja sertifikaadi ja context'i namespace'iga ning saadab päringu HTTPS-iga API serverile; klastris on igal õppijal oma namespace." xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .ok{fill:#2e7d32;fill-opacity:.14;stroke:#2e7d32;stroke-width:1.3}.lx .bad{fill:#c62828;fill-opacity:.12;stroke:#c62828;stroke-width:1.3}.lx .zone{fill:none;stroke:var(--md-default-fg-color--lighter);stroke-width:1.2;stroke-dasharray:5 4}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:13px;font-family:var(--md-code-font-family,monospace)}.lx .w{fill:#c62828;font-size:13.5px;font-weight:700}.lx .g{fill:#2e7d32;font-size:13.5px;font-weight:700}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:4 3}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="70" width="130" height="60" rx="6"/><text class="b" x="75.0" y="96.0" text-anchor="middle">control</text><text class="s" x="75.0" y="114.0" text-anchor="middle">kubectl</text>
<rect class="zone" x="165" y="20" width="230" height="170" rx="8"/>
<text class="c" x="280" y="42" text-anchor="middle">~/.kube/config</text>
<rect class="box" x="180" y="54" width="200" height="36" rx="6"/><text class="b" x="280.0" y="77.0" text-anchor="middle">klaster: aadress ja CA</text>
<rect class="box" x="180" y="98" width="200" height="36" rx="6"/><text class="b" x="280.0" y="121.0" text-anchor="middle">kasutaja: sertifikaat</text>
<rect class="hi" x="180" y="142" width="200" height="36" rx="6"/><text class="b" x="280.0" y="165.0" text-anchor="middle">context: namespace</text>
<line class="a" x1="140" y1="100" x2="163" y2="100" marker-end="url(#lxa)"/>
<line class="a" x1="395" y1="100" x2="445" y2="100" marker-end="url(#lxa)"/>
<text class="s" x="421" y="72" text-anchor="middle">HTTPS</text>
<text class="s" x="421" y="90" text-anchor="middle">:6443</text>
<rect class="hi" x="450" y="20" width="230" height="50" rx="6"/><text class="b" x="565.0" y="41.0" text-anchor="middle">API server</text><text class="s" x="565.0" y="59.0" text-anchor="middle">k3s.lab.hkhk.ee</text>
<rect class="ok" x="450" y="88" width="110" height="56" rx="6"/><text class="b" x="505.0" y="112.0" text-anchor="middle">is-maasikas</text><text class="s" x="505.0" y="130.0" text-anchor="middle">sinu ruum</text>
<rect class="box" x="570" y="88" width="110" height="56" rx="6"/><text class="b" x="625.0" y="112.0" text-anchor="middle">is-mtamm</text><text class="s" x="625.0" y="130.0" text-anchor="middle">teise õppija</text>
<text class="s" x="565" y="172" text-anchor="middle">kvoot ja õigused kehtivad</text>
<text class="s" x="565" y="190" text-anchor="middle">namespace'i kaupa</text>
</svg>
<figcaption>Joonis 7.2. kubectl leiab kubeconfig'ist, kuhu ühenduda, kes sa oled ja millises namespace'is töötad (Talvik, 2026).</figcaption>
</figure>

kubeconfig on sama tundlik kui SSH privaatvõti: kes faili saab, tegutseb klastris sinu nimel. Seepärast hoitakse seda õigustega `600` ja see ei lähe Giti. Käsk `kubectl config view --minify` näitab praegu kasutatava context'i sisu ilma võtmeteta.

### Namespace, õigused ja kvoot

Kursuse klaster on jagatud: kõik õppijad töötavad samas klastris. **Namespace** on nimeruum, mis eraldab objektid. Kahes namespace'is võib olla sama nimega Deployment `app01` ja need ei sega teineteist. Kursusel on igal õppijal oma namespace `is-<github>`.

Mida keegi klastris teha tohib, määrab **RBAC** (Role-Based Access Control, rollipõhine ligipääs). Õppija tohib oma namespace'is luua workload'e ja Secret'eid, aga ei tohi luua namespace'e ega muuta õigusi. Käsk `kubectl auth can-i create deployments` vastab `yes` või `no`.

**ResourceQuota** ehk kvoot piirab, kui palju protsessoriaega, mälu ja pod'e üks namespace kokku võtab. Jagatud klastris kaitseb kvoot teisi õppijaid: kui ühe õppija rakendus küsib liiga palju mälu, jääb see tema enda namespace'i piiresse. Kui kvoot piirab protsessori ja mälu reserveeringut, peab igal konteineril olema `requests` kirjas (osa 4).

??? note "Tabel 7.3. SSH ja kubectl"

    | Küsimus | SSH ja Linux | kubectl ja Kubernetes |
    |---|---|---|
    | Kuhu ühendud? | `~/.ssh/config`, rida `HostName` | kubeconfig, osa `clusters` |
    | Kes sa oled? | privaatvõti | sertifikaat või token, osa `users` |
    | Kus töötad? | kodukaust | namespace, osa `contexts` |
    | Mida tohid teha? | `sudoers` | RBAC Role ja RoleBinding |
    | Kuidas kontrollid? | `sudo -l` | `kubectl auth can-i --list` |
    | Kui palju tohid võtta? | kettakvoot, cgroup'id | ResourceQuota |

??? info "Süvenemiseks: mitu klastrit, võti `-n` ja Pod Security"

    Ühes kubeconfig'is võib olla mitu klastrit ja context'i. `kubectl config get-contexts` näitab neid ja `kubectl config use-context <nimi>` vahetab. Ühe käsu jaoks saab namespace'i anda võtmega `-n`, näiteks `kubectl get pods -n is-mtamm`, aga kursuse õigused lubavad lugeda ainult oma namespace'i.

    Namespace'il võib olla turvatase ([Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)). Tase `baseline` keelab näiteks privilegeeritud konteinerid ja hosti võrgu kasutamise. Kui namespace jõustab taset `baseline`, aga hoiatab rangema taseme `restricted` eest, näitab `kubectl apply` hoiatust, kuid pod käivitub.

**Leia viga.** Õppija kopeeris kubeconfig'i k3s serverist failist `/etc/rancher/k3s/k3s.yaml` oma control-masinasse. `kubectl get pods` vastab `connection refused`. Failis on rida:

```yaml
server: https://127.0.0.1:6443
```

??? success "Vastus"

    - **Mida taheti:** ühendust k3s serveri API-ga control-masinast.
    - **Mis oli:** aadress `127.0.0.1`, mis tähendab alati masinat ennast. kubectl otsis API serverit control-masinast.
    - **Õige:** `server: https://k3s.lab.hkhk.ee:6443`, st API serveri aadress, kuhu control-masinast jõuab.
    - **Miks:** k3s kirjutab oma kubeconfig'i serveri enda jaoks. Teises masinas tuleb aadress muuta. Kursusel annab koolitaja valmis faili õige aadressi ja sinu namespace'iga.

<a id="1-soovitud-olek-ja-control-loop"></a>

## 3. Soovitud olek ja control loop

### Käsk ja kirjeldus

`docker run` on **imperatiivne** käsk: see ütleb, mida teha. Kubernetese manifest on **deklaratiivne** kirjeldus: see ütleb, milline olek peab olema, ja süsteem leiab ise, mida selleks teha. Sama mõtet kasutas Ansible: `state: present` kirjeldab tulemust, pakett peab olemas olema.

Lihtne näide: Deployment `web` ütleb, et image'ist `nginx:1.30-alpine` peab töötama kaks pod'i. Kui klastris on üks pod, luuakse teine. Kui kolm, kustutatakse üks. Kui kaks, ei tehta midagi.

### Kontroller ja control loop

Kirjelduse täitmise eest vastutavad **kontrollerid**. Iga [kontroller](https://kubernetes.io/docs/concepts/architecture/controller/) on lõputu tsükkel (**control loop**): loe soovitud olekut, vaata tegelikku olekut ja tee väike samm, et vahe kaoks. Kontroller ei mäleta eelmist korda ja arvutab vahe iga kord uuesti.

<figure markdown="span">
  ![Control loop: kubectl apply muudab soovitud olekut, kubectl delete pod muudab tegelikku olekut; kontroller loeb mõlemat ja loob puuduva pod'i](assets/k07_kontrolltsukkel.svg)
  <figcaption>Joonis 7.3. Kontroller võrdleb soovitud ja tegelikku olekut ning kõrvaldab vahe (Talvik, 2026).</figcaption>
</figure>

Kui pod kustutatakse, näeb kontroller vahet „soovitud 1, tegelik 0“ ja loob uue pod'i. Uus pod saab uue nime ja uue IP-aadressi ning võib käivituda teisel node'il. Sündmuste logis (`kubectl get events`) on loomise kirje kontrolleri nimel, sest pod'i lõi kontroller. Seepärast ei tohi miski sõltuda pod'i nimest ega IP-aadressist.

Kontroller hoiab kirjeldust, mis on klastris. Kui muudad Deployment'it ennast, näiteks käsuga `kubectl scale deploy/web --replicas=3`, muutub soovitud olek ja kontroller järgib uut kirjeldust. Kubernetes ei tea, mis on kirjas sinu failis või Gitis. Faili ja klastri erinevuse leiab GitOps (osa 9).

??? note "Tabel 7.4. Ansible ja Kubernetes"

    | | Ansible | Kubernetes |
    |---|---|---|
    | Soovitud olek | playbook ja muutujad | manifestid, salvestatud API serverisse |
    | Millal olek rakendatakse | siis, kui playbook'i käivitad | pidevalt, kontrollerid töötavad kogu aeg |
    | Kui teenus seiskub | jääb seisma järgmise käivituseni | pod luuakse uuesti mõne sekundiga |
    | Kui keegi muudab käsitsi | muudatus püsib järgmise käivituseni | kontrollitava objekti, näiteks kustutatud pod'i, taastab kontroller |
    | Mida hallatakse | masinad: paketid, failid, teenused | konteinerid ja nende võrk, seadistus ja kettad |

Ansible ja Kubernetes ei välista teineteist. Ansible'iga paigaldatakse sageli klastri node'id ja k3s ise, Kubernetes hoiab seejärel rakendusi.

### Kuidas see sisemiselt töötab

Control plane'is on neli komponenti ja igal node'il kolm.

<figure markdown="span">
  ![Control plane: API server, etcd, scheduler ja kontrollerid; node'il kubelet, containerd ja kube-proxy](assets/k07_juhttasand.svg)
  <figcaption>Joonis 7.4. Kõik komponendid suhtlevad ainult API serveriga (Talvik, 2026).</figcaption>
</figure>

- **API server** võtab vastu kõik päringud, kontrollib õigusi ja on ainus komponent, mis kirjutab andmebaasi etcd.
- **etcd** on võti-väärtus andmebaas, kus on kogu klastri soovitud olek.
- **Scheduler** valib igale uuele pod'ile node'i, kus on piisavalt vaba protsessori ja mälu reserveeringut.
- **Kontrollerid** hoiavad objektide soovitud olekut, näiteks pod'ide arvu.
- **kubelet** töötab igal node'il, käivitab sellele node'ile määratud pod'ide konteinerid ja teatab nende oleku API serverile.
- **Konteinerite käivitaja** (k3s-is containerd) laadib image'i ja käivitab konteineri.
- **kube-proxy** seadistab node'i võrgureeglid, mis suunavad Service'i aadressile tulnud liikluse pod'idele (osa 5).

Komponendid ei suhtle omavahel otse. Kui lood Deployment'i, käib ahel nii: Deployment'i kontroller loob ReplicaSet'i, ReplicaSet'i kontroller loob pod'i kirjelduse, scheduler kirjutab pod'ile node'i nime ja selle node'i kubelet käivitab konteineri. Igaüks loeb API serverist oma tööd ja kirjutab sinna tulemuse.

??? info "Süvenemiseks: k3s komponendid"

    k3s paneb control plane'i komponendid ühte programmi ja teenusesse `k3s`. Ühe serveriga klastris kasutab k3s etcd asemel vaikimisi SQLite'i, mitme serveriga klastris sisseehitatud etcd-d. Vaikimisi paigaldatakse ka Ingress-kontroller Traefik (osa 8) ja kettaruumi teenus local-path (osa 6). Paigaldus ja valikud: [k3s dokumentatsioon](https://docs.k3s.io/).

### Tootmise erijuhud

Kontroller loob kustutatud pod'i uuesti mõne sekundiga. Kui kaob terve node, ootab Kubernetes vaikimisi umbes viis minutit, enne kui pod'id teistel node'idel uuesti luuakse, sest node võib olla ka ainult hetkeks võrgust ära. Andmebaas, mille andmed on ühe node'i kettal, ei saa teisele node'ile kolida enne, kui node on tagasi. Tootmises kasutatakse andmete jaoks võrguketast või andmebaasi, mis hoiab ise mitut koopiat.

**Leia viga.** Rakendus tuli hoolduse ajaks peatada. Admin kustutas pod'i:

```bash
kubectl delete pod app01-7c9d8f6b5-x2k4p
```

Minuti pärast töötas app01 uuesti.

??? success "Vastus"

    - **Mida taheti:** app01 ei tööta hoolduse ajal.
    - **Mis oli:** kustutati üks pod, aga Deployment ütles endiselt `replicas: 1`.
    - **Õige:** muuda soovitud olekut, `kubectl scale deploy/app01 --replicas=0`, ja hoolduse lõpus tagasi `--replicas=1`. Kui olekut hoiab Argo CD, tehakse sama muudatus Gitis.
    - **Miks:** ReplicaSet'i kontroller nägi vahet „soovitud 1, tegelik 0“ ja lõi uue pod'i.

## 4. Manifest ja Deployment

### Manifesti ülesehitus

Igal manifestil on neli tippvõtit. `apiVersion` ja `kind` ütlevad, mis tüüpi objekt see on. `metadata` annab objektile nime ja label'id. `spec` kirjeldab soovitud olekut. Kui objekt on klastris, lisab API server ise võtme `status`, kus on tegelik olek.

```yaml
apiVersion: apps/v1          # API rühm ja versioon
kind: Deployment             # objekti tüüp
metadata:
  name: web                  # nimi namespace'is
spec:
  replicas: 2                # mitu pod'i peab töötama
  selector:
    matchLabels:
      app: web               # millised pod'id on selle Deployment'i omad
  template:                  # pod'i mall: selle järgi luuakse pod'id
    metadata:
      labels:
        app: web             # peab vastama selektorile
    spec:
      containers:
        - name: nginx
          image: nginx:1.30-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 20m
              memory: 32Mi
```

`template` on pod'i mall: iga pod, mille Deployment loob, saab selle kirjelduse. `selector` ütleb, milliseid pod'e Deployment enda omaks loeb. Mallis peab olema label, mis vastab selektorile, muidu ei võta API server faili vastu. Manifestis ei ole namespace'i: see tuleb context'ist või hiljem Argo CD seadistusest.

### Manifest tehakse käsuga

YAML-i ei kirjutata peast. Peast kirjutatud failis on taandevead ja valesti kirjutatud väljanimed, mida API server osaliselt vaikselt eirab. Käsk `kubectl create deployment web --image=nginx:1.30-alpine --dry-run=client -o yaml` koostab manifesti ja trükib selle ekraanile ilma klastrit muutmata. Faili loed läbi, eemaldad tühjad väljad ja lisad, mis puudu. Iga välja tähenduse näitab `kubectl explain`, näiteks `kubectl explain deployment.spec.replicas`.

<figure style="max-width:690px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 690 160" role="img" aria-label="Manifesti teekond: fail, kubectl, API server, etcd ja kontrollerid. --dry-run=client lõpeb kubectl'is, --dry-run=server API serveris, kubectl apply jõuab etcd-sse." xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .ok{fill:#2e7d32;fill-opacity:.14;stroke:#2e7d32;stroke-width:1.3}.lx .bad{fill:#c62828;fill-opacity:.12;stroke:#c62828;stroke-width:1.3}.lx .zone{fill:none;stroke:var(--md-default-fg-color--lighter);stroke-width:1.2;stroke-dasharray:5 4}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:13px;font-family:var(--md-code-font-family,monospace)}.lx .w{fill:#c62828;font-size:13.5px;font-weight:700}.lx .g{fill:#2e7d32;font-size:13.5px;font-weight:700}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:4 3}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="20" width="130" height="60" rx="6"/><text class="b" x="75.0" y="46.0" text-anchor="middle">web.yaml</text><text class="s" x="75.0" y="64.0" text-anchor="middle">sinu fail</text>
<rect class="box" x="162" y="20" width="140" height="60" rx="6"/><text class="b" x="232.0" y="46.0" text-anchor="middle">kubectl</text><text class="s" x="232.0" y="64.0" text-anchor="middle">loeb faili, saadab</text>
<rect class="hi" x="324" y="20" width="172" height="60" rx="6"/><text class="b" x="410.0" y="46.0" text-anchor="middle">API server</text><text class="s" x="410.0" y="64.0" text-anchor="middle">skeem, õigused, kvoot</text>
<rect class="ok" x="518" y="20" width="166" height="60" rx="6"/><text class="b" x="601.0" y="46.0" text-anchor="middle">etcd + kontrollerid</text><text class="s" x="601.0" y="64.0" text-anchor="middle">salvestab, loob pod'id</text>
<line class="a" x1="140" y1="50" x2="160" y2="50" marker-end="url(#lxa)"/>
<line class="a" x1="302" y1="50" x2="322" y2="50" marker-end="url(#lxa)"/>
<line class="a" x1="496" y1="50" x2="516" y2="50" marker-end="url(#lxa)"/>
<path class="a d" d="M232,84 V112" marker-end="url(#lxa)"/>
<text class="c" x="232" y="130" text-anchor="middle">--dry-run=client</text>
<text class="s" x="232" y="148" text-anchor="middle">lõpeb siin</text>
<path class="a d" d="M410,84 V112" marker-end="url(#lxa)"/>
<text class="c" x="410" y="130" text-anchor="middle">--dry-run=server</text>
<text class="s" x="410" y="148" text-anchor="middle">lõpeb siin</text>
<path class="a d" d="M601,84 V112" marker-end="url(#lxa)"/>
<text class="c" x="601" y="130" text-anchor="middle">kubectl apply</text>
<text class="s" x="601" y="148" text-anchor="middle">jõuab siia</text>
</svg>
<figcaption>Joonis 7.5. Kui kaugele manifest jõuab: kaks proovimise viisi ja tegelik rakendamine (Talvik, 2026).</figcaption>
</figure>

`kubectl apply -f web.yaml` saadab faili API serverile. Võti `--dry-run=server` teeb sama, aga API server ainult kontrollib faili: skeemi, õigusi ja kvooti. Nii leiad vead enne, kui klastris midagi muutub. `apply` on idempotentne nagu Ansible'i moodul: esimesel korral vastab see `created`, muudatuse korral `configured` ja muutmata failiga `unchanged`.

### Deployment, ReplicaSet ja pod

Deployment ei loo pod'e ise. Iga pod'i malli versiooni jaoks loob see **ReplicaSet**'i, mis hoiab pod'ide arvu. Nimedest näed omandiahelat: pod `web-7d9f8c6b5-abcde` kuulub ReplicaSet'ile `web-7d9f8c6b5` ja see Deployment'ile `web`. Keskmine osa on malli räsi, viimane osa juhuslik.

??? note "Tabel 7.5. Põhiobjektid"

    | Objekt | Mida teeb |
    |---|---|
    | Pod | üks või mitu konteinerit ühise IP-aadressiga; ajutine, asendatakse uuega |
    | [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) | kirjeldab, mitu koopiat millisest pod'i mallist peab töötama; iga mallimuudatuse jaoks loob uue ReplicaSet'i |
    | ReplicaSet | hoiab koopiate arvu |
    | [Service](https://kubernetes.io/docs/concepts/services-networking/service/) | annab pod'ide hulgale püsiva nime ja IP-aadressi (osa 5) |
    | ConfigMap, Secret | seadistus ja saladused (osa 6) |
    | PersistentVolumeClaim | kettaruum, mis jääb alles ka siis, kui pod asendatakse (osa 6) |
    | [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) | suunab väljast tuleva HTTP-liikluse Service'ile (osa 8) |
    | Namespace | eraldab õppijate või meeskondade objektid (osa 2) |

### Requests

Ühte node'i jagavad paljud pod'id, nii et scheduler peab teadma, kui palju igaüks vajab. [`requests`](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) on reserveering: scheduler paneb pod'i ainult node'ile, kuhu reserveeringute summa veel mahub. `cpu: 250m` tähendab 250 millituuma ehk veerandit protsessorituumast, `memory: 256Mi` 256 mebibaiti. `limits` on ülempiir, millest konteiner üle minna ei tohi. Mälulimiidi ületanud konteiner peatatakse (olek `OOMKilled`).

```yaml
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    memory: 512Mi
```

Compose'i teenusest Kubernetese objektideks saab mitu faili osa. Tabel näitab, kuhu iga Compose'i võti läheb.

??? note "Tabel 7.6. Compose'i võti ja Kubernetese väli"

    | Compose | Kubernetes |
    |---|---|
    | `image` | Deployment: `containers[].image` |
    | `ports` | `containerPort` pod'is, Service, väljast Ingress |
    | `environment`, `.env` | `env`, ConfigMap, Secret |
    | `volumes` | `volumeMounts` pod'is ja PersistentVolumeClaim |
    | `healthcheck` | startup-, readiness- ja liveness-probe |
    | `depends_on` | init-konteiner |
    | `restart` | Deployment taaskäivitab ja asendab alati |
    | `deploy.replicas` | `replicas` |

??? info "Süvenemiseks: manifestid tootmises"

    Tootmises on manifestid Gitis ja `kubectl apply` käivitab konveier või GitOps'i tööriist (osa 9). `kubectl diff -f fail.yaml` näitab enne rakendamist, mis klastris muutub. Kui sama rakendus läheb mitmesse keskkonda, koostatakse manifestid mallidest (Helm) või kattekihtidega (Kustomize). Neid käsitleb kursus IS2.

**Leia viga.** `kubectl apply -f web.yaml` vastab:

```text
The Deployment "web" is invalid: spec.template.metadata.labels: Invalid value:
map[string]string{"app":"nginx"}: `selector` does not match template `labels`
```

Failis on:

```yaml
spec:
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: nginx
```

??? success "Vastus"

    - **Mida taheti:** Deployment, mis loob pod'id ja hoiab nende arvu.
    - **Mis oli:** selektor otsib label'it `app: web`, mallis on `app: nginx`.
    - **Õige:** mõlemas kohas sama label, näiteks `app: web`.
    - **Miks:** Deployment loeb enda omaks ainult pod'id, mis vastavad selektorile. Kui mallist tehtud pod selektorile ei vastaks, looks Deployment pod'e lõputult juurde. API server keeldub sellist faili vastu võtmast.

## 5. Service: püsiv nimi pod'idele

### Pod'i aadress muutub

Iga uus pod saab uue IP-aadressi. Kui app01 ühenduks andmebaasiga pod'i IP-aadressi kaudu, katkeks ühendus iga kord, kui db01 pod asendatakse. Compose'is lahendas selle teenuse nimi: konteiner `app01` jõudis andmebaasini nime `db01` kaudu. Kubernetesis teeb sama **Service**: see annab pod'ide hulgale püsiva nime ja püsiva IP-aadressi (ClusterIP).

Service ei tea pod'ide nimesid. Tal on **selektor**, näiteks `app: db01`, ja liiklus läheb kõigile pod'idele, millel on see label ja mis on valmis liiklust vastu võtma (Ready). Nende pod'ide aadressid on Service'i **lõpp-punktid** (Endpoints). Kui pod asendatakse, vahetub lõpp-punkt, aga nimi ja ClusterIP jäävad samaks.

<figure markdown="span">
  ![Deployment loob ReplicaSet'i, ReplicaSet loob pod'id, Service leiab pod'id label'i järgi ja Endpoints'is on kahe pod'i IP-aadressid](assets/k07_labelid.svg)
  <figcaption>Joonis 7.6. Deployment, ReplicaSet, pod ja Service on seotud ainult label'ite kaudu (Talvik, 2026).</figcaption>
</figure>

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db01            # nimi, mille kaudu teised teenused ühenduvad
spec:
  selector:
    app: db01           # pod'id, kuhu liiklus läheb
  ports:
    - port: 3306        # Service'i port
      targetPort: mysql # konteineri pordi nimi või number
```

Samas namespace'is jõuab app01 andmebaasini nime `db01` kaudu. Teises namespace'is oleva Service'i nimi on `db01.<namespace>`. `port` on Service'i port ja `targetPort` konteineri port. Kui konteineri pordil on nimi (`mysql`), viitab `targetPort` nimele ja pordi numbrit muudad ainult ühes kohas.

ClusterIP on kättesaadav ainult klastri sees. Proovimiseks teeb `kubectl port-forward svc/db01 3306:3306` API serveri kaudu tunneli sinu masinasse, nagu SSH pordisuunamine. Väljast kasutajatele avab rakenduse Ingress (osa 8).

??? note "Tabel 7.7. Ilma Service'ita ja Service'iga"

    | | Ilma Service'ita | Service'iga |
    |---|---|---|
    | Kuidas app01 andmebaasi leiab | pod'i IP-aadress, mis muutub | nimi `db01`, mis jääb |
    | Kui db01 pod asendatakse | ühendus katkeb, seadistus tuleb muuta | lõpp-punkt vahetub, nimi jääb |
    | Kui pod'e on kaks | app01 peab mõlemat teadma | liiklus jaotub mõlemale |
    | Kui pod ei ole valmis | liiklus läheb ikka sinna | pod eemaldatakse lõpp-punktidest |

??? info "Süvenemiseks: kuidas ClusterIP töötab ja Service'i tüübid"

    ClusterIP ei ole ühegi masina aadress. Iga node'i kube-proxy kirjutab tuuma võrgureeglid (iptables või nftables), mis suunavad sellele aadressile saadetud paketi ühele lõpp-punktile. Seepärast ei pruugi ClusterIP vastata `ping`-ile, kuigi TCP-ühendus töötab. Nime `db01` lahendab klastri DNS-teenus.

    Vaikimisi tüüp on `ClusterIP`. Tüüp `NodePort` avab teenuse iga node'i kindlal pordil ja `LoadBalancer` küsib pilveteenuselt välise koormusjaoturi. Kursuse kvoot keelab tüübi `LoadBalancer`, väljast ligipääs käib Ingress'i kaudu.

    Kubernetese versioonist 1.33 hoiatab `kubectl get endpoints`, et Endpoints on aegunud ja selle asemel on EndpointSlice. Käsk töötab edasi ja näitab samu aadresse.

**Leia viga.** Rakendus ei saa ühendust vahemäluga, kuigi `kubectl get pods` näitab, et mc01 pod töötab. Väljund:

```text
$ kubectl get endpoints mc01
NAME   ENDPOINTS   AGE
mc01   <none>      5m
$ kubectl get pods -L app
NAME                   READY   STATUS    RESTARTS   AGE   APP
mc01-5c7b9d4f8-q8w2n   1/1     Running   0          5m    memcached
```

Service'i failis on `selector: {app: mc01}`.

??? success "Vastus"

    - **Mida taheti:** Service `mc01` suunab liikluse memcached'i pod'ile.
    - **Mis oli:** Service otsib label'it `app: mc01`, pod'il on `app: memcached`.
    - **Õige:** Service'i selektor ja pod'i mallis olev label on samad, näiteks mõlemas `app: mc01`.
    - **Miks:** label'i viga ei anna veateadet. Mõlemad objektid luuakse edukalt, aga Service'il pole ühtegi lõpp-punkti. Tühi Endpoints on esimene asi, mida kontrollida, kui Service'i kaudu ühendus ei tööta.

## 6. Seadistus, saladused ja andmed

### ConfigMap ja Secret

Image on sama igas keskkonnas, seadistus tuleb väljast. Compose'is andsid seadistuse `environment` ja `.env` fail. Kubernetesis on selleks kaks objekti. **ConfigMap** hoiab tavalist seadistust, näiteks hostinimesid või SQL-faile. **Secret** hoiab paroole ja võtmeid. Pod saab mõlemast väärtused keskkonnamuutujatena (`env`, `envFrom`) või failidena kaustas (`volumes`).

Secret ei ole krüpteeritud. Väärtused on base64-kodeeringus, mille saab tagasi teisendada ühe käsuga (`base64 -d`). Kes tohib namespace'is Secret'eid lugeda, näeb kõiki paroole. Seepärast luuakse Secret käsurealt ja see ei lähe Giti, ConfigMap aga läheb Giti koos teiste manifestidega.

### PersistentVolumeClaim

Konteineri failisüsteem kaob koos konteineriga. Compose'is pandi andmebaasi andmed volume'isse, Kubernetesis küsitakse kettaruumi objektiga **PersistentVolumeClaim** (PVC). PVC on taotlus: „mulle on vaja 1 Gi ketast“. Klastri **StorageClass** loob taotluse peale ketta (PersistentVolume) ja seob selle PVC-ga. Pod ühendab PVC oma kausta, näiteks MariaDB andmekausta `/var/lib/mysql`.

<figure style="max-width:690px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 690 232" role="img" aria-label="Pod db01 saab ConfigMap'ist init-failid kausta initdb.d, Secret'ist parooli keskkonnamuutujana ja PVC kaudu ketta kausta /var/lib/mysql. PVC seotakse PersistentVolume'iga, mille loob StorageClass." xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .ok{fill:#2e7d32;fill-opacity:.14;stroke:#2e7d32;stroke-width:1.3}.lx .bad{fill:#c62828;fill-opacity:.12;stroke:#c62828;stroke-width:1.3}.lx .zone{fill:none;stroke:var(--md-default-fg-color--lighter);stroke-width:1.2;stroke-dasharray:5 4}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:13px;font-family:var(--md-code-font-family,monospace)}.lx .w{fill:#c62828;font-size:13.5px;font-weight:700}.lx .g{fill:#2e7d32;font-size:13.5px;font-weight:700}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:4 3}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="20" width="172" height="56" rx="6"/><text class="b" x="96.0" y="44.0" text-anchor="middle">ConfigMap</text><text class="s" x="96.0" y="62.0" text-anchor="middle">labori-seis-db (Gitis)</text>
<rect class="bad" x="10" y="96" width="172" height="56" rx="6"/><text class="b" x="96.0" y="120.0" text-anchor="middle">Secret</text><text class="s" x="96.0" y="138.0" text-anchor="middle">labori-seis (klastris)</text>
<rect class="zone" x="262" y="14" width="200" height="180" rx="8"/>
<text class="t" x="362" y="36" text-anchor="middle">Pod db01</text>
<rect class="box" x="274" y="48" width="176" height="40" rx="6"/><text class="b" x="362.0" y="73.0" text-anchor="middle">kaust initdb.d</text>
<rect class="box" x="274" y="96" width="176" height="40" rx="6"/><text class="b" x="362.0" y="121.0" text-anchor="middle">MARIADB_PASSWORD</text>
<rect class="box" x="274" y="144" width="176" height="40" rx="6"/><text class="b" x="362.0" y="169.0" text-anchor="middle">/var/lib/mysql</text>
<line class="a" x1="182" y1="54" x2="272" y2="68" marker-end="url(#lxa)"/><text class="s" x="222" y="48" text-anchor="middle">failidena</text>
<line class="a" x1="182" y1="124" x2="272" y2="116" marker-end="url(#lxa)"/><text class="s" x="222" y="112" text-anchor="middle">muutujana</text>
<rect class="ok" x="510" y="134" width="170" height="60" rx="6"/><text class="b" x="595.0" y="160.0" text-anchor="middle">PVC db01-data</text><text class="s" x="595.0" y="178.0" text-anchor="middle">kettaruumi taotlus</text>
<line class="a" x1="508" y1="164" x2="452" y2="164" marker-end="url(#lxa)"/>
<rect class="hi" x="510" y="20" width="170" height="80" rx="6"/><text class="b" x="595.0" y="47.0" text-anchor="middle">PersistentVolume</text><text class="s" x="595.0" y="65.0" text-anchor="middle">ketas node'il</text><text class="s" x="595.0" y="83.0" text-anchor="middle">loob StorageClass</text>
<line class="a" x1="595" y1="132" x2="595" y2="103" marker-end="url(#lxa)"/><text class="s" x="650" y="122" text-anchor="middle">seotakse</text>
<text class="s" x="345" y="222" text-anchor="middle">Pod asendatakse: ConfigMap, Secret ja PVC jäävad, uus pod saab samad andmed.</text>
</svg>
<figcaption>Joonis 7.7. Seadistus, saladus ja andmed on pod'ist eraldi objektid (Talvik, 2026).</figcaption>
</figure>

Andmebaasi Deployment kasutab strateegiat `Recreate`: vana pod peatatakse enne, kui uus käivitub. Vaikimisi strateegia käivitaks uue pod'i enne vana peatamist ja kaks MariaDB-d sama andmekausta peal rikuksid andmed.

??? note "Tabel 7.8. Seadistus ja andmed Compose'is ja Kubernetesis"

    | Mida | Compose | Kubernetes | Kas läheb Giti? |
    |---|---|---|---|
    | tavaline seadistus | `environment` | ConfigMap | jah |
    | paroolid | `.env` | Secret | ei |
    | init-skriptid | bind mount kausta `/docker-entrypoint-initdb.d` | ConfigMap failidena | jah |
    | andmed | nimega volume | PersistentVolumeClaim | ainult PVC kirjeldus, andmed ei lähe |

??? info "Süvenemiseks: saladused tootmises ja PVC olek Pending"

    Tootmises ei looda Secret'eid käsitsi. Saladused hoitakse saladuste halduris (näiteks HashiCorp Vault või OpenBao) ja klastrisse toob need eraldi tööriist. etcd krüpteerimine kettal tuleb klastris eraldi sisse lülitada.

    k3s-i StorageClass `local-path` loob ketta selle node'i kettale, kuhu pod paigutatakse. Seepärast on PVC olekus `Pending` seni, kuni scheduler on pod'ile node'i valinud, ja läheb siis olekusse `Bound`. Selline ketas on seotud ühe node'iga.

**Leia viga.** Õppija lõi Secret'i `labori-seis` uute paroolidega uuesti, PVC `db01-data` jäi alles. Pärast pod'ide asendamist on app01 logis:

```text
Access denied for user 'labseis'@'10.42.1.17' (using password: YES)
```

??? success "Vastus"

    - **Mida taheti:** uued paroolid kõigile teenustele.
    - **Mis oli:** app01 sai Secret'ist uue parooli, aga andmebaasis on kasutaja `labseis` vana parooliga.
    - **Õige:** kas muuda parool andmebaasis SQL-käsuga või, kui andmeid pole vaja, kustuta ka PVC, et MariaDB alustaks tühjast andmekaustast.
    - **Miks:** MariaDB image loeb muutujad `MARIADB_USER` ja `MARIADB_PASSWORD` ainult esimesel käivitusel, kui andmekaust on tühi. Andmed koos kasutajatega olid PVC-l ja jäid alles.

## 7. Millal pod on valmis: probe'id ja init-konteiner

### Töötav protsess ei ole veel töötav teenus

Kui konteineri protsess käivitub, ei ole teenus veel valmis. Java rakendusel kulub käivitumiseks mitukümmend sekundit, andmebaas loeb esimesel käivitusel init-skripte. Compose'is ütles `healthcheck`, millal teenus on terve, ja `depends_on` koos tingimusega `service_healthy` lasi teistel teenustel oodata. Kubernetesis kontrollib konteinerit kubelet kolme eri [probe'iga](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/) ja igaühel on oma tagajärg.

??? note "Tabel 7.9. Kolm probe'i ja nende tagajärg"

    | Probe | Küsimus | Kui ei vasta |
    |---|---|---|
    | startup | kas käivitus on läbi? | teisi probe'e veel ei tehta; kui aeg saab täis, taaskäivitatakse konteiner |
    | readiness | kas pod võtab praegu liiklust vastu? | pod eemaldatakse Service'i lõpp-punktidest, konteiner töötab edasi |
    | liveness | kas protsess on kinni jäänud? | kubelet taaskäivitab konteineri |

Probe võib olla HTTP-päring (`httpGet`, õnnestub vastusega 200–399), TCP-ühendus (`tcpSocket`, õnnestub, kui port vastab) või käsk konteineris (`exec`, õnnestub väljumiskoodiga 0). Probe'i vaikimisi ajapiir on üks sekund, aeglasema kontrolli jaoks kirjutatakse `timeoutSeconds`. Kui readiness-probe'i ei ole, loetakse pod valmis kohe, kui konteiner käivitus, ja Service saadab liikluse sinna enne, kui teenus porti kuulab.

### Init-konteiner

Compose'i `depends_on`-i Kubernetesis ei ole. Sõltuvusi ootab **init-konteiner**: see käivitub enne rakenduse konteinerit ja rakendus käivitub alles siis, kui init-konteiner on edukalt lõpetanud ([Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)). Labori seisus proovib init-konteiner `wait-deps` TCP-ühendust andmebaasi ja järjekorra pordiga ning lõpetab, kui mõlemad vastavad.

<figure style="max-width:690px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 690 192" role="img" aria-label="Pod'i olekud ajateljel: Pending, Init:0/1, Running 0/1 ja Running 1/1. Liveness-probe kontrollib pärast käivitumist kogu aeg, kas protsess on kinni jäänud." xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .ok{fill:#2e7d32;fill-opacity:.14;stroke:#2e7d32;stroke-width:1.3}.lx .bad{fill:#c62828;fill-opacity:.12;stroke:#c62828;stroke-width:1.3}.lx .zone{fill:none;stroke:var(--md-default-fg-color--lighter);stroke-width:1.2;stroke-dasharray:5 4}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:13px;font-family:var(--md-code-font-family,monospace)}.lx .w{fill:#c62828;font-size:13.5px;font-weight:700}.lx .g{fill:#2e7d32;font-size:13.5px;font-weight:700}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .d{stroke-dasharray:4 3}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="30" width="156" height="70" rx="6"/><text class="b" x="88.0" y="52.0" text-anchor="middle">Pending</text><text class="s" x="88.0" y="70.0" text-anchor="middle">scheduler valib node'i</text><text class="s" x="88.0" y="88.0" text-anchor="middle">PVC seotakse</text>
<line class="a" x1="166" y1="65" x2="178" y2="65" marker-end="url(#lxa)"/>
<rect class="box" x="180" y="30" width="156" height="70" rx="6"/><text class="b" x="258.0" y="52.0" text-anchor="middle">Init:0/1</text><text class="s" x="258.0" y="70.0" text-anchor="middle">wait-deps ootab</text><text class="s" x="258.0" y="88.0" text-anchor="middle">db01 ja rmq01 porti</text>
<line class="a" x1="336" y1="65" x2="348" y2="65" marker-end="url(#lxa)"/>
<rect class="box" x="350" y="30" width="156" height="70" rx="6"/><text class="b" x="428.0" y="52.0" text-anchor="middle">Running 0/1</text><text class="s" x="428.0" y="70.0" text-anchor="middle">startup-probe ootab,</text><text class="s" x="428.0" y="88.0" text-anchor="middle">readiness veel ei vasta</text>
<line class="a" x1="506" y1="65" x2="518" y2="65" marker-end="url(#lxa)"/>
<rect class="ok" x="520" y="30" width="156" height="70" rx="6"/><text class="b" x="598.0" y="52.0" text-anchor="middle">Running 1/1</text><text class="s" x="598.0" y="70.0" text-anchor="middle">readiness vastab:</text><text class="s" x="598.0" y="88.0" text-anchor="middle">pod saab liiklust</text>
<text class="s" x="345" y="18" text-anchor="middle">aeg →</text>
<rect class="hi" x="180" y="120" width="500" height="34" rx="6"/>
<text class="s" x="430" y="142" text-anchor="middle">liveness: kui protsess on kinni, kubelet taaskäivitab konteineri</text>
<text class="s" x="345" y="180" text-anchor="middle">Kui pod jääb mõnda olekusse pidama, näitab põhjust kubectl describe pod (Events).</text>
</svg>
<figcaption>Joonis 7.8. Uue app01 pod'i teekond: millal ootab init-konteiner ja millal saab pod liiklust (Talvik, 2026).</figcaption>
</figure>

### Kui pod ei käivitu

Pod'i olek ütleb, millises etapis see pidama jäi, ja põhjus on pod'i sündmustes. Kolm käsku leiavad enamiku vigu: `kubectl get pods` näitab olekut, `kubectl describe pod <nimi>` näitab lõpus sündmusi (Events) ja `kubectl logs <nimi>` näitab konteineri väljundit. Init-konteineri logi näeb võtmega `-c <konteineri nimi>` ja enne taaskäivitust töötanud konteineri logi võtmega `--previous`. Võti `-w` (`kubectl get pods -w`) jälgib olekute muutumist pidevalt. `kubectl exec deploy/db01 -- <käsk>` käivitab käsu töötavas konteineris nagu `docker exec` ja `kubectl rollout status deploy/app01` ootab, kuni Deployment'i kõik pod'id on valmis.

??? note "Tabel 7.10. Pod'i olekud ja kust põhjust otsida"

    | Olek | Mida tähendab | Kust otsida |
    |---|---|---|
    | `Pending` | pod'ile ei leitud node'i või PVC ei ole seotud | `describe pod`: Events, näiteks `Insufficient memory` |
    | `ContainerCreating` | image laaditakse või ketast ühendatakse | `describe pod`: Events |
    | `ErrImagePull`, `ImagePullBackOff` | image'it ei saanud alla laadida | `describe pod`: `not found` (nimi või tag vale) või `unauthorized` (privaatne pakett) |
    | `Init:0/1` | init-konteiner ei ole lõpetanud | `logs <pod> -c <init-konteiner>` |
    | `CrashLoopBackOff` | konteiner lõpeb kohe ja taaskäivitatakse üha pikema ootega | `logs <pod> --previous` |
    | `Running 0/1` | konteiner töötab, readiness ei vasta | `describe pod`: `Readiness probe failed` |
    | `OOMKilled` (viimane põhjus) | konteiner ületas mälulimiidi | `describe pod`: `Last State` |

??? info "Süvenemiseks: kes probe'e teeb ja mis on CrashLoopBackOff"

    Probe'e teeb iga node'i kubelet ja tulemus jõuab API serveri kaudu Service'i lõpp-punktidesse. Kui konteiner lõpeb korduvalt, ootab kubelet iga järgmise taaskäivituse eel kauem, kuni viie minutini. Seda ooteolekut näitab staatus `CrashLoopBackOff`. Ootamine kaitseb node'i, aga tähendab ka, et parandatud vea järel võib pod mõne minuti oodata. `kubectl delete pod` alustab uue pod'iga kohe.

### Tootmise erijuhud

Levinud viga on panna liveness kontrollima andmebaasi. Kui andmebaas läheb hetkeks maha, ebaõnnestub kõigi rakenduse pod'ide liveness korraga ja kubelet taaskäivitab kõik konteinerid. Iga järgmise ebaõnnestumise järel kasvab ooteaeg kuni viie minutini, nii et pod'id ootavad ka siis, kui andmebaas on juba tagasi. Andmebaasi kättesaadavus kuulub readiness'i alla: pod jääb ellu, aga liiklust ei saa.

**Leia viga.** Rakenduse probe'id on sellised:

```yaml
readinessProbe:
  httpGet: {path: /health/live, port: http}
livenessProbe:
  httpGet: {path: /health, port: http}   # /health kontrollib ka andmebaasi
```

Andmebaasi kahe minuti hoolduse ajal taaskäivitati kõik app01 pod'id mitu korda ja rakendus oli maas veel viis minutit pärast hoolduse lõppu.

??? success "Vastus"

    - **Mida taheti:** andmebaasi katkestuse ajal ei saa app01 liiklust, aga jääb ellu.
    - **Mis oli:** probe'id olid vahetuses: liveness kontrollis andmebaasi ja readiness ainult protsessi.
    - **Õige:** `readinessProbe` kontrollib `/health` (koos andmebaasiga) ja `livenessProbe` `/health/live` (ainult protsess).
    - **Miks:** liveness'i ebaõnnestumine taaskäivitab konteineri ja korduvad taaskäivitused viivad ootesse kuni viis minutit. Readiness'i ebaõnnestumine võtab pod'i ainult liiklusest välja ja pod naaseb kohe, kui andmebaas vastab.

## 8. Ingress: rakendus väljast kättesaadavaks

2\. kohtumisel võttis web01 Nginx kasutaja päringu vastu ja suunas selle app01-le: `server_name` ütles, millisele nimele reegel kehtib, ja `proxy_pass`, kuhu päring edasi läheb. Kubernetesis kirjeldab sama reeglit objekt **Ingress** ja täidab **Ingress-kontroller**, k3s-is Traefik. Traefik kuulab node'idel porti 80 ja valib Service'i HTTP-päringu `Host`-päise järgi.

<figure markdown="span">
  ![Traefik suunab päringud Host-päise järgi õige namespace'i Service'ile; tundmatu hostinime korral vastab 404](assets/k07_ingress.svg)
  <figcaption>Joonis 7.9. Ingress-kontroller valib Service'i Host-päise järgi (Talvik, 2026).</figcaption>
</figure>

Kursusel jagavad kõik õppijad sama IP-aadressi ja porti, seepärast on hostinimes õppija GitHubi nimi, näiteks `labori-seis-maasikas.lab.hkhk.ee`. DNS suunab kõik nimed `*.lab.hkhk.ee` klastrisse ja Traefik otsustab hostinime järgi, millise namespace'i Service'ile päring läheb.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app01
spec:
  ingressClassName: traefik        # milline Ingress-kontroller reeglit täidab
  rules:
    - host: labori-seis-maasikas.lab.hkhk.ee
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app01
                port:
                  name: http
```

Vastuse kood ütleb, kus viga on. `404` tähendab, et Traefik ei leidnud hostinimele reeglit. `503` tähendab, et reegel on olemas, aga Service'il pole ühtegi Ready pod'i. Ilma DNS-ita saab Ingress'i proovida käsuga `curl -H 'Host: labori-seis-maasikas.lab.hkhk.ee' http://k3s.lab.hkhk.ee/`, mis saadab päringu klastrisse ja paneb päisesse õige nime.

??? info "Süvenemiseks: HTTPS ja Gateway API"

    Tootmises kasutab Ingress HTTPS-i. Sertifikaat on Secret'is ja Ingress viitab sellele võtmega `tls`. Sertifikaate tellib ja uuendab sageli automaatselt tööriist cert-manager. Ingress'i järglane on [Gateway API](https://gateway-api.sigs.k8s.io/), mis eraldab klastri halduri ja rakenduse omaniku reeglid. Traefik toetab mõlemat.

**Leia viga.** Õppija kontrollib rakendust käsuga `curl http://k3s.lab.hkhk.ee/health` ja saab vastuse `404 page not found`. Ta otsustab, et app01 on katki, ja hakkab pod'i logisid uurima.

??? success "Vastus"

    - **Mida taheti:** kontrollida, kas rakendus vastab Ingress'i kaudu.
    - **Mis oli:** päringu `Host`-päis oli `k3s.lab.hkhk.ee`, millele ühtegi reeglit pole. Traefik vastas `404` ise ja päring ei jõudnud app01-ni.
    - **Õige:** `curl -H 'Host: labori-seis-maasikas.lab.hkhk.ee' http://k3s.lab.hkhk.ee/health` või brauseris `http://labori-seis-maasikas.lab.hkhk.ee/health`.
    - **Miks:** Traefik valib Service'i hostinime järgi. Kui rakendusel poleks Ready pod'i, oleks vastus `503`, mitte `404`.

## 9. GitOps ja Argo CD

### Triiv

Kui kaks admini teevad samal ajal `kubectl apply` eri kaustadest, on klastris see, mida viimane saatis. Kui keegi parandab intsidendi ajal midagi käsuga `kubectl edit` või `kubectl scale`, on klastris midagi, mida Gitis pole. Erinevust Gitis kirjeldatud soovitud oleku ja klastri tegeliku oleku vahel nimetatakse **triiviks** (drift). Kubernetes ise triivi ei märka, sest ta ei tea Gitist midagi (osa 3).

### GitOpsi põhimõte

**GitOps** tähendab, et soovitud olek on Gitis ja klastris töötav agent loeb selle ise ning viib klastri sellega kooskõlla. Agent on samasugune control loop nagu Kubernetese kontrollerid, ainult soovitud olek tuleb Gitist. Termin tuli kasutusele 2017. aastal ja [OpenGitOps](https://opengitops.dev/) kirjeldab neli põhimõtet: olek on deklaratiivne, versioonitud ja muutumatu, agent tõmbab selle ise ning võrdleb seda pidevalt tegelikuga.

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
<rect class="ok" x="520" y="162" width="145" height="56" rx="6"/><text class="b" x="592.5" y="186.0" text-anchor="middle">is-maasikas</text><text class="s" x="592.5" y="204.0" text-anchor="middle">tegelik olek</text>
<line class="a" x1="263" y1="182" x2="152" y2="182" marker-end="url(#lxa)"/><text class="s" x="208" y="174" text-anchor="middle">loeb</text>
<line class="a" x1="425" y1="182" x2="518" y2="182" marker-end="url(#lxa)"/><text class="s" x="471" y="174" text-anchor="middle">rakendab</text>
<path class="a d" d="M592,220 V244 H345 V222" marker-end="url(#lxa)"/>
<text class="s" x="470" y="258" text-anchor="middle">jälgib triivi, pöörab tagasi</text>
</svg>
<figcaption>Joonis 7.10. Push-mudelis saadab CI muudatuse klastrisse, pull-mudelis loeb klastris töötav agent selle Gitist (Talvik, 2026).</figcaption>
</figure>

Push-mudelis käivitab CI pärast testi `kubectl apply` ja klastri võti on CI runneris. Pull-mudelis ei ole CI-l klastrisse ligipääsu: CI ehitab ja testib image'i ning kirjutab Giti uue tag'i, klastris töötav agent märkab muudatust ja rakendab selle.

??? note "Tabel 7.11. Push- ja pull-mudel"

    | | Push: CI teeb deploy | Pull: GitOpsi agent |
    |---|---|---|
    | Klastri võti | CI runneris | klastri sees |
    | Käsitsi muudatus | jääb märkamata | nähtav triivina, `selfHeal` pöörab tagasi |
    | Tagasipööramine | uus konveieri käivitus | `git revert` |
    | Kus on kirjas, mis töötab | konveieri logis | Giti ajaloos |

### Argo CD Application

[Argo CD](https://argo-cd.readthedocs.io/en/stable/) on üks levinumaid GitOpsi agente. Selle avaldas Intuit 2018. aastal ja see on CNCF-i projekt. Teine levinud agent on Flux. Argo CD töötab klastris ja talle kirjeldatakse, mida jälgida, objektiga **Application**.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: labori-seis
spec:
  project: is-maasikas                 # AppProject: mida see Application tohib
  source:
    repoURL: https://github.com/hkhk-tk/<repo>.git
    targetRevision: main               # haru
    path: k07-k8s                      # kaust repositooriumis
  destination:
    server: https://kubernetes.default.svc   # sama klaster, kus Argo CD töötab
    namespace: is-maasikas
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

`source` ütleb, kust soovitud olek tuleb, ja `destination`, kuhu see rakendatakse. Aadress `https://kubernetes.default.svc` on klastri enda API server klastri seest vaadatuna. **AppProject** (`project`) piirab, milliseid repositooriume ja namespace'e Application tohib kasutada. Kursusel on igal õppijal oma AppProject, nii et Application ei saa midagi teise õppija namespace'i panna.

Argo CD loeb ainult nimetatud kausta, mitte selle alamkaustu. Seepärast hoitakse Application'i faili alamkaustas (näiteks `k07-k8s/argocd/`): kui Application oleks kaustas, mida ta ise jälgib, võiks vale commit kustutada ka Application'i ja koos sellega kogu järelevalve.

### Sync policy

Sync policy koosneb kolmest eraldi otsusest:

- `automated` rakendab iga uue commit'i ise. Ilma selleta näitab Argo CD erinevust ja ootab, kuni inimene vajutab **Sync**.
- `prune` kustutab klastrist objektid, mis Gitist kadusid. Ilma selleta jäävad need klastrisse alles.
- `selfHeal` pöörab klastris käsitsi tehtud muudatused tagasi. Argo CD jälgib klastrit pidevalt ja märkab muudatust mõne sekundiga.

Gitist loeb Argo CD muudatusi korrapäraste vahedega, vaikimisi iga kolme minuti järel. Kohe uuesti lugema paneb Application'i annotatsioon `argocd.argoproj.io/refresh=normal` või Giti webhook.

### Kaks olekut

Argo CD näitab kahte eri olekut. **Sync status** ütleb, kas klaster vastab Gitile: `Synced` või `OutOfSync`. **Health status** ütleb, kas objektid töötavad: `Healthy`, `Progressing` (alles käivitub), `Degraded` (ei tööta) või `Missing` (objekt puudub klastrist).

??? note "Tabel 7.12. Sync status ja health status koos"

    | Olek | Mida tähendab | Kus on viga |
    |---|---|---|
    | Synced, Healthy | klaster vastab Gitile ja rakendus töötab | vigu pole |
    | OutOfSync, Healthy | rakendus töötab, aga klaster ja Git erinevad | triiv või rakendamata commit |
    | Synced, Progressing või Degraded | klaster vastab Gitile, aga rakendus ei tööta | Gitis, näiteks olematu image'i tag |
    | OutOfSync, Missing | Gitis kirjeldatud objekti klastris pole | sync'i pole veel tehtud või see ebaõnnestus |

Olematu image'i tag annab oleku Synced: Argo CD tegi oma töö ja klaster vastab Gitile. Deployment on olekus Progressing ja kui see ei saa vaikimisi kümne minuti jooksul valmis, Degraded. `kubectl rollout undo` siin ei aita, sest Argo CD taastab Gitis kirjeldatud oleku. Tagasipööramine tehakse käsuga `git revert`, nii et igal klastri muudatusel on commit, autor ja põhjus.

??? info "Süvenemiseks: saladused ja Argo CD õigused"

    Argo CD loob klastrisse ainult seda, mis on Gitis. Secret'it Gitis ei ole, nii et seda Argo CD ei halda ja selle loob inimene või saladuste halduri tööriist. Argo CD-l on õigused kõigis namespace'ides, mida ta haldab, nii et selle kaitsmine on sama tähtis kui CI serveri kaitsmine. CI kirjutatav image'i tag, Argo CD kasutajaliides ja erijuhud on kursusel IS2.

**Leia viga.** Meeskond kasutab Gitis image'it `ghcr.io/hkhk-tk/labori-seis-app:latest`. CI ehitas uue versiooni ja laadis selle sama tag'iga registry'sse. Argo CD näitab Synced ja Healthy, aga klastris töötab vana versioon.

??? success "Vastus"

    - **Mida taheti:** uus versioon jõuab klastrisse automaatselt.
    - **Mis oli:** Gitis ei muutunud midagi, sest tag `:latest` jäi samaks. Argo CD võrdleb Giti ja klastrit ning ei näinud erinevust.
    - **Õige:** igal versioonil on oma muutumatu tag, näiteks commit'i SHA (`:3f2a9c1`), ja CI kirjutab uue tag'i Giti.
    - **Miks:** GitOpsis on Git soovitud olek. Kui muudatust Gitis pole, ei ole agendi jaoks ka midagi rakendada, ja olemasolevat pod'i ei looda uuesti ainult sellepärast, et registry's on sama tag'iga uus image.

??? info "Loe juurde"

    [Orkestreerimine ja automatiseerimine](../teemad/orkestreerimine.md) · [Kubernetese klastrihaldus](../teemad/kubernetes-klastrihaldus.md) · [kubectl lühijuhend](https://kubernetes.io/docs/reference/kubectl/quick-reference/) · [Argo CD automaatne sync](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)

??? abstract "Kokkuvõte"

    - **Orkestreerimine:** klaster käitab konteinereid mitmes masinas ja loob rikkis node'i pod'id mujal uuesti.
    - **kubeconfig ja namespace:** kubeconfig ütleb, kuhu ja kellena ühendud, namespace, RBAC ja kvoot eraldavad õppijad jagatud klastris.
    - **Soovitud olek:** muuda kirjeldust, mitte töötavat pod'i. Kontroller loob kustutatud pod'i uuesti.
    - **Objektid ja label'id:** Deployment hoiab pod'e, Service annab neile püsiva nime. Vale selektor annab vaikselt tühja Service'i.
    - **Seadistus ja andmed:** ConfigMap läheb Giti, Secret mitte. Andmed on PVC-l ja jäävad pod'i vahetusel alles.
    - **Probe'id:** andmebaasi kontroll kuulub readiness'i alla, liveness kontrollib ainult protsessi. Init-konteiner ootab sõltuvusi.
    - **Ingress:** Traefik valib Service'i Host-päise järgi, `404` tähendab puuduvat reeglit, `503` Ready pod'ita Service'it.
    - **GitOps:** soovitud olek on Gitis, Argo CD viib klastri sellega kooskõlla ja tagasipööramine on `git revert`. Synced tähendab, et klaster vastab Gitile, Healthy, et rakendus töötab.

## Kontrolli ennast

??? question "Tootmises parandati viga käsuga `kubectl edit deploy/app` ja kõik töötas. Tund hiljem oli viga tagasi. Mis võis juhtuda?"
    Soovitud olekut hoiab keegi teine: GitOpsi agent `selfHeal`-iga või järgmine konveieri deploy. Mõlemad kirjutavad käsitsi muudatuse üle. Parandus tuleb teha sinna, kus soovitud olek on kirjas, tavaliselt Giti.

??? question "Uus app01 pod on mitu minutit olekus `Init:0/1`. Milliste käskudega leiad põhjuse?"
    `kubectl describe pod -l app=app01` näitab, milline init-konteiner töötab, ja `kubectl logs -l app=app01 -c wait-deps` näitab selle väljundit. Kui logis kordub „ootan db01:3306“, kontrolli `kubectl get pods -l app=db01` ja `kubectl get endpoints db01`: Service'i nimi laheneb ka siis, kui sellel pole ühtegi pod'i.

??? question "Argo CD näitab rakendust olekus Synced ja Degraded. Kas Argo CD tegi vea?"
    Ei. Klaster vastab Gitile, aga rakendus ei tööta, näiteks Gitis on olematu image'i tag. Parandus on `git revert` või uus commit.
