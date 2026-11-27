---
tags:
  - Kubernetes
  - k3s
---

# Loeng: Kubernetes

3\. kohtumisel käivitasid Dockeri ja Compose'iga konteinerid ühes masinas ning 4. kohtumisel lõid OpenTofuga masinad koodist. Täna vaatad, kuidas konteinereid hallatakse siis, kui masinaid on mitu ja rakendus peab töötama ka rikke ajal. Selleks on Kubernetes: sina kirjeldad soovitud olekut ja Kubernetes hoiab klastrit pidevalt selles olekus.

??? abstract "Õpiväljundid"

    Pärast loengut ja praktikumi oskad:

    - otsustada kahe põhjendusega, kas teenuse jaoks sobib Compose või Kubernetes;
    - selgitada soovitud ja tegeliku oleku abil, mida kontroller teeb, kui pod kustutatakse;
    - järjestada joonise abil klastri osade sammud, mis järgnevad käsule `kubectl apply`;
    - märkida Deployment'i ja Service'i YAML-failis read, mis seovad need siltide kaudu;
    - kirjeldada joonise abil, mis teed pidi jõuab päring brauserist või teisest pod'ist pod'ini;
    - arvutada, mitu vana pod'i jääb rolling update'i ajal tööle, kui uus versioon ei käivitu;
    - leida käskudega `kubectl get`, `describe` ja `logs`, miks pod ei käivitu;
    - eristada käskude `kubectl apply`, `helm upgrade` ja Argo CD ülesannet rakenduse paigaldamisel;
    - valida olukorra järgi õige komponent: Deployment või StatefulSet, ClusterIP või NodePort või Ingress, ConfigMap või Secret, Volume.

## 1. Mis on Kubernetes ja miks

**Mis see on.** Kubernetes on avatud lähtekoodiga konteinerite orkestreerimise tööriist, mille tegi algselt Google. See haldab rakendusi, mis koosnevad sadadest või tuhandetest konteineritest, ja seda eri keskkondades: füüsilistes masinates, virtuaalmasinates, pilves või nende segus.

Varem oli rakendus sageli üks suur programm ehk monoliit. Siis jagati rakendused väikesteks iseseisvateks osadeks ehk mikroteenusteks ja igaüks pandi konteinerisse. Konteinereid sai nii palju, et nende haldamine skriptide ja käsitsi muutus keeruliseks. Orkestreerija tagab kolm asja:

- **kõrgkäideldavus**: rakendusel ei ole seisakut;
- **skaleeritavus**: koopiaid saab koormuse järgi kiiresti juurde lisada ja vähendada;
- **taastamine**: kui serverid või andmed kaovad, taastatakse klastri olek varukoopiast.

<figure markdown="span">
  [![Image, konteiner, Docker ja Kubernetes järjest, ülal orkestreerimine, paremal virtuaalmasin ja konteiner kõrvuti](assets/k05_ylevaade.svg)](assets/k05_ylevaade.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.1. Tõmmisest orkestreerimiseni (Talvik, 2026).</figcaption>
</figure>

Compose'iga töötasid kõik konteinerid ühes masinas. Taaskäivitusreegel `restart: unless-stopped` käivitab seiskunud konteineri uuesti, aga ainult samas masinas. Kui masin ise läheb rikki või vajab hooldust, ei vii keegi konteinereid teise masinasse ja rakendus seisab.

Seda probleemi lahendab **orkestreerimine**. Orkestreerija on tarkvara, mis otsustab, millises masinas konteiner töötab, asendab rikkis koopiad uutega ja vahetab versioonid järk-järgult välja. Administraator kirjeldab, mis peab töötama ja mitu koopiat. Masina valib orkestreerija.

Kubernetese klastris on kolm põhimõistet, mida kohtad juba järgmisel joonisel. **Node** on klastri masin, kus konteinerid töötavad. **Pod** on üks konteiner või mitu konteinerit koos, väikseim üksus, mida Kubernetes käivitab. **Control plane** on klastri juhtimise osa, mis otsustab, millisel node'il pod töötab. Täpsemalt tulevad need jaotistes 3 ja 4.

<figure markdown="span">
  [![Kaks node'i, node 1 kaob, rakendus ja andmebaas töötavad node 2-l edasi](assets/k05_f_d_nodex.svg)](assets/k05_f_d_nodex.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.2. Kui node kaob, töötab rakendus teisel node'il edasi (Talvik, 2026).</figcaption>
</figure>

Virtuaalmasinatega töötanud administraator tunneb sama mõtet Proxmoxi kõrgkäideldavusest (HA): kui server kaob, käivitatakse VM teises serveris. Kubernetes teeb sama üksiku rakenduse tasemel ja palju kiiremini, sest konteineri käivitamiseks ei pea operatsioonisüsteemi laadima.

Kustutatud pod luuakse uuesti mõne sekundiga. Kui kaob terve node, läheb kauem: Kubernetes märgib node'i olekusse `NotReady` ja ootab vaikimisi umbes viis minutit, enne kui selle pod'id teistele node'idele viib. Nii ei käivitata pod'e üle lühikese võrgukatkestuse tõttu.

??? note "Tabel 5.1. Compose ja Kubernetes"

    | | Docker Compose | Kubernetes |
    |---|---|---|
    | Masinad | üks | mitu node'i |
    | Kui masin kaob | konteinerid seisavad, kuni masin on tagasi | pod'id luuakse teistel node'idel uuesti |
    | Koopiate arv | tavaliselt üks konteiner teenuse kohta | `replicas` ütleb, mitu koopiat töötab |
    | Kirjeldus | `compose.yaml` | YAML-failid, igas üks või mitu objekti |
    | Väljast ligipääs | masina port | Service ja Ingress |

**Millal Kubernetest ei ole vaja.** Klaster lisab tööd: seda tuleb uuendada, jälgida ja varundada ning meeskond peab õppima uue sõnavara. Kubernetesest ilmub [kolm versiooni aastas](https://kubernetes.io/releases/) ja iga versiooni toetatakse umbes aasta, nii et klastrit tuleb uuendada vähemalt kord aastas. Üks väike rakendus ühes serveris töötab hästi ka Compose'i või systemd teenusena. Kubernetes tasub ära siis, kui teenuseid ja masinaid on palju või kui rakendus peab rikke ajal töötama.

??? question "Kontrolli ennast"

    Väike meeskond haldab ühte veebirakendust ja andmebaasi ühes serveris. Hoolduse ajal on lubatud kuni 10 minutit seisakut. Kas valida Compose või Kubernetes?

    ??? success "Vastus"

        Compose. Teenuseid ja masinaid on vähe ning seisak on lubatud. Kubernetes lisaks klastri uuendamise, jälgimise ja varundamise töö, aga ei annaks siin midagi juurde.

        Otsus muutuks, kui teenuseid ja servereid oleks palju või kui rakendus ei tohiks hoolduse ajal seista. Siis kaalub automaatne pod'ide asendamine teisel node'il üles klastri haldamise lisatöö.

## 2. Kust Kubernetes tuli ja mis on k3s

Kubernetes on avatud lähtekoodiga orkestreerija, mille tegi Google ja mis kuulub nüüd sihtasutusele CNCF. Nimi tuleb kreeka keelest ja tähendab tüürimeest, lühend K8s tähendab, et K ja s vahel on kaheksa tähte.

??? info "Ajalugu ja kuhu Kubernetes läheb"

    **Mis see on.** Kubernetes on avatud lähtekoodiga orkestreerija. Nimi tuleb kreeka keelest ja tähendab tüürimeest. Lühend K8s tähendab, et K ja s vahel on kaheksa tähte.

    **Mis oli enne.** Google käitas oma teenuseid konteinerites juba 2000. aastate keskel ja haldas neid sisemise süsteemiga Borg. Teised ettevõtted haldasid servereid ja nende teenuseid skriptidega ja käsitsi.

    **Mis on praegu.** 2014. aastal avaldas Google Borgi kogemuse põhjal Kubernetese ja 2015. aastal anti see Cloud Native Computing Foundationile ([CNCF](https://www.cncf.io/)), nii et Kubernetes ei kuulu ühele ettevõttele. Kubernetes on konteinerite haldamise tegelik standard ja kõigil suurtel pilveteenuse pakkujatel on hallatud Kubernetese teenus: Amazon EKS, Azure AKS ja Google GKE.

    **Kuhu see läheb.** Kubernetes muutub platvormiks, mille peale ehitatakse teisi tööriistu: paketihaldur Helm, GitOpsi tööriistad nagu Argo CD ja ettevõtete sisemised arendusplatvormid. Paljud meeskonnad ei halda klastrit ise, vaid kasutavad pilve hallatud klastrit ja tegelevad ainult rakendustega. Kubernetes hakkab haldama ka virtuaalmasinaid: [KubeVirt](https://kubevirt.io/) käivitab VM-i pod'i sees, nii et konteinerid ja VM-id töötavad samades masinates ühe API kaudu. Näiteks Saksa ettevõte encircle360 [asendas k3s-i ja KubeVirtiga eraldi Proxmoxi ja libvirt'i hostid](https://encircle360.com/en/blog/k3s-kubevirt-converged-infrastructure).

Kubernetes on avatud projekt, mille põhjal teevad mitu tootjat oma **jaotuse** ehk distributsiooni, nagu Linuxi tuumast tehakse Ubuntu ja AlmaLinux. Käsud ja YAML-failid on kõigis samad, erinevad paigaldus ja kaasa pandud lisad.

??? note "Tabel 5.2. Kubernetese jaotused"

    | Jaotus | Kellele | Märkus |
    |---|---|---|
    | **k3s** | väike klaster, servamasinad, õppimine | Rancher, 2019. Ühes programmis, kaasas Traefik, ServiceLB ja kohalik kettaruum (local-path). Kursusel kasutad seda |
    | **k0s** | väike klaster | Mirantis. Samuti üks programm, lisad paigaldad ise |
    | **[minikube](https://github.com/kubernetes/minikube)**, **kind**, **MicroK8s** | arendaja arvuti, MicroK8s ka väike server | ühe node'iga klaster virtuaalmasinas või Dockeris |
    | **EKS**, **AKS**, **GKE** | pilv | control plane'i haldab pilveteenuse pakkuja |
    | **Talos Linux** | oma serverid ja Proxmox | [Sidero Labs](https://www.siderolabs.com/). Operatsioonisüsteem ainult Kubernetese jaoks: SSH-d ei ole, masinat hallatakse API kaudu käsuga `talosctl` |
    | **OpenShift** | suured asutused | Red Hati Kubernetes koos lisatööriistade ja tasulise toega |

**k3s** paigaldub ühe käsuga ja vajab vähe mälu, sest kogu juhtimise osa on ühes programmis. Ühe masinaga klastris hoiab k3s andmeid SQLite'i andmebaasis. Täpsemalt: [k3s dokumentatsioon](https://docs.k3s.io/).

Kubernetes ei ole ainus orkestreerija. Väiksemaid süsteeme hallatakse sageli lihtsamate tööriistadega.

??? note "Tabel 5.3. Kubernetese alternatiivid"

    | Tööriist | Mis see on | Millal valitakse |
    |---|---|---|
    | **Docker Compose** | mitu konteinerit ühes masinas | üks server, väike rakendus |
    | **Podman ja systemd** | konteiner systemd teenusena (Quadlet) | üksikud teenused Red Hati põhistes serverites |
    | **Docker Swarm** | Dockeri sisseehitatud klaster, failid sarnased Compose'iga | väike klaster ilma uue sõnavarata |
    | **HashiCorp Nomad** | üks programm, käivitab konteinereid ja tavalisi programme | segakeskkond, HashiCorpi tööriistade kasutajad |
    | **Coolify**, **Dokku**, **CapRover** | oma serverisse paigaldatav platvorm: `git push` või veebiliides ehitab ja käivitab rakenduse, all on Docker või Swarm | väike meeskond tahab automaatset paigaldust ilma klastrita |
    | **AWS ECS**, **Google Cloud Run** | pilve enda konteineriteenus | ainult ühes pilves, klastrit ei halda keegi ise |

    Swarmi ja Nomadi kasutajaid on vähem ja töökuulutustes küsitakse peaaegu alati Kubernetest.

Nimi k3s tuli mõttest teha Kubernetes, mis vajab poole vähem mälu. K8s on kümnetäheline sõna, seega poole väiksem on viietäheline K3s.

## 3. Arhitektuur

Kubernetese klaster koosneb vähemalt ühest **control plane**'ist ja selle külge ühendatud **worker node**'idest. Node on virtuaalne või füüsiline masin.

**Worker node**'idel töötavad sinu rakendused. Igal node'il on kolm Kubernetese protsessi: **kubelet** saab API serverilt pod'i kirjelduse ja käivitab selle, **konteineri käivitaja** (k3s-is containerd) laadib image'i ja käivitab konteineri ning **kube-proxy** seab Service'i võrgureeglid. Worker node'idel on kõige suurem koormus, seepärast on need suured.

**Control plane**'is töötab neli protsessi:

- **API server** on ainus sissepääs klastrisse. Sellega räägivad veebiliides, skriptid ja `kubectl`.
- **Controller Manager** jälgib, mis klastris toimub, ja loob näiteks surnud pod'i asemele uue.
- **Scheduler** otsustab, millisele node'ile uus pod läheb, vabade ressursside järgi.
- **etcd** on võti-väärtus andmebaas, kus on kogu klastri olek. Klastri varundamine tähendab etcd varundamist.

**Virtuaalvõrk** ühendab kõik node'id, nii et klaster on nagu üks suur masin. k3s-is teeb seda Flannel. Control plane on tähtsam kui üksik worker node: kui see kaob, ei saa klastrit hallata. Seepärast on tootmises vähemalt kaks, tavaliselt kolm control plane'i.

<figure markdown="span">
  [![Control plane, virtuaalvõrk ja kolm worker node'i](assets/k05_f_a_vn.svg)](assets/k05_f_a_vn.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.3. Klastri arhitektuur (Talvik, 2026).</figcaption>
</figure>

Praktikumis on kõik ühes masinas, mille nimi on `control`. See masin on korraga control plane ja worker node. Ära aja segi masina nime `control` ja mõistet control plane. k3s paneb kõik osad ühte programmi ja kasutab etcd asemel SQLite'i.

Allolev loetelu kordab osi lühidalt, joonis 5.4 näitab, kuidas need ühe käsu juures koos töötavad.

<figure markdown="span">
  [![Seitse nummerdatud sammu: kubectl saadab faili API serverile, see salvestab etcd-sse, kontroller loob pod'i, scheduler valib node'i, kubelet näeb pod'i, containerd käivitab konteineri, kube-proxy seab Service'i reeglid](assets/k05_juhttasand.svg)](assets/k05_juhttasand.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.4. Mis juhtub pärast käsku kubectl apply. Kontrollerid, scheduler ja kubelet suhtlevad API serveri kaudu (Talvik, 2026).</figcaption>
</figure>

- **API server** võtab vastu kõik päringud ja kontrollib õigusi. Ta kuulab porti 6443.
- **etcd** (k3s-is ühe masina puhul SQLite) on andmebaas, kus on kogu soovitud olek.
- **Scheduler** valib igale uuele pod'ile node'i, kus on piisavalt vaba protsessorit ja mälu. Kui palju pod vajab, kirjutatakse Deployment'i konteineri juurde väljale `resources`: `requests` on see, mille scheduler pod'ile kinni paneb, ja `limits` on ülempiir, millest rohkem konteiner kasutada ei saa. Vaata lähemalt [dokumentatsioonist](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
- **Kontrollerid** hoiavad soovitud olekut, näiteks pod'ide arvu.
- **kubelet** töötab igal node'il ja käivitab sellele node'ile määratud pod'id.
- **containerd** laadib image'i ja käivitab konteineri, nagu Docker.
- **Flannel** ühendab k3s-is pod'ide võrgu node'ide vahel, nii et kõik node'id on nagu üks suur masin.
- **kube-proxy** töötab igal node'il ja seab võrgureeglid, mille abil Service'i aadressile saadetud päring jõuab mõne pod'ini.

k3s paigaldab kõik need osad ühe käsuga. Kui tahad näha, kuidas klaster osade kaupa kokku pannakse, vaata juhendit [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way). Selles paigaldatakse iga osa käsitsi, koos sertifikaatidega, ja töö võtab mitu tundi.

Joonise 5.4 numbrid näitavad, mis juhtub pärast käsku `kubectl apply -f tere.yaml`:

1. kubectl saadab Deployment'i kirjelduse API serverile. API server kontrollib õigusi ja faili kuju.
2. API server salvestab soovitud oleku andmebaasi etcd.
3. Deployment'i kontroller näeb uut Deployment'i ja loob ReplicaSet'i. ReplicaSet'i kontroller loob pod'ide kirjed. Neil pod'idel ei ole veel node'i.
4. Scheduler näeb node'ita pod'i ja määrab sellele node'i.
5. Selle node'i kubelet näeb, et talle on määratud uus pod.
6. kubelet annab containerd'le käsu image alla laadida ja konteiner käivitada. Seejärel teatab kubelet pod'i oleku API serverile ja `kubectl get pods` näitab olekut `Running`.
7. Kui pod'i ees on Service, seab kube-proxy võrgureeglid, mis saadavad Service'i päringud uuele pod'ile.

Kontrollerid, scheduler ja kubelet ei anna üksteisele käske. Igaüks jälgib API serverit ja teeb oma osa, kui näeb muudatust.

??? question "Kontrolli ennast"

    Pod on olekus `Pending` ja `kubectl describe pod` näitab sündmust `Insufficient memory`. Millise joonise 5.4 sammu juures töö seisab?

    ??? success "Vastus"

        Sammu 4 juures. Scheduler ei leidnud node'i, kus on piisavalt vaba mälu. Pod'il ei ole node'i, seega ükski kubelet seda ei käivita.

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
    | `kubectl exec -it <pod> -- sh` | avab shelli konteineri sees | `docker exec -it` |
    | `kubectl explain deployment.spec` | näitab objekti väljade kirjeldust | `ansible-doc` |

    Käskude kõrval kasutatakse terminali kasutajaliidest [k9s](https://k9scli.io/), mis näitab klastri objekte tabelina ja värskendab vaadet pidevalt.

## 4. Põhikomponendid

Põhikomponente on mugav selgitada ühe näite peal: veebirakendus ja andmebaas. Iga komponent lahendab ühe probleemi, mis eelmisest sammust jäi.

### Node ja pod

**Pod** on Kubernetese väikseim üksus, kiht konteineri ümber. Kubernetes peidab konteineri tehnoloogia ära, nii et sa räägid ainult Kubernetesega, mitte Dockeriga. Pod'is on tavaliselt üks rakendus. Igal pod'il on oma sisemine IP-aadress, mitte igal konteineril.

Pod on **ajutine** (inglise keeles *ephemeral*). Kui rakendus kukub või node'il saab mälu otsa, sureb pod ja asemele tuleb uus pod uue IP-aadressiga. Kui veebirakendus räägib andmebaasiga IP järgi, tuleks iga kord seadistust muuta.

<figure markdown="span">
  [![Andmebaasi pod luuakse uuesti ja see saab uue IP-aadressi](assets/k05_f_c_newip.svg)](assets/k05_f_c_newip.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.5. Uus pod saab uue IP-aadressi (Talvik, 2026).</figcaption>
</figure>

### Service

**Service** on püsiv IP-aadress ja nimi pod'i ees. Service'i ja pod'i elutsükkel ei ole seotud: pod sureb, Service jääb. Service on ka koormusjaotur, mis saadab päringu ühele oma pod'idest.

Rakendus peab olema brauseris kättesaadav, andmebaas mitte. Seepärast on kaks tüüpi: **väline** Service (tüüp `NodePort`) avab pordi node'i IP-l ja **sisemine** Service (tüüp `ClusterIP`) on nähtav ainult klastri sees. Tüüp antakse loomisel, vaikimisi on Service sisemine.

<figure markdown="span">
  [![Väline Service on brauserist kättesaadav, sisemine Service mitte](assets/k05_f_c_int.svg)](assets/k05_f_c_int.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.6. Väline ja sisemine Service (Talvik, 2026).</figcaption>
</figure>

### Ingress

Välise Service'i aadress on node'i IP ja port, näiteks `http://192.168.125.81:30080`. Testimiseks sobib, kasutajale mitte. **Ingress** võtab vastu päringu nimega, näiteks `tere.firma.ee`, ja saadab selle õigele Service'ile. k3s-is täidab Ingressi reegleid Traefik.

<figure markdown="span">
  [![Brauser saadab päringu Ingressile, Ingress Service'ile](assets/k05_f_c_ing.svg)](assets/k05_f_c_ing.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.7. Ingress on klastri sissepääs nime järgi (Talvik, 2026).</figcaption>
</figure>

### ConfigMap ja Secret

Andmebaasi aadress on tavaliselt rakenduse sees. Kui see muutub, tuleb image uuesti ehitada, registrisse lükata ja pod'i tõmmata. **ConfigMap** hoiab seadistust väljaspool image'it: muudad ConfigMap'i ja image jääb samaks. Kui ConfigMap antakse keskkonnamuutujatena, näeb pod uut väärtust alles pärast taaskäivitust. Kui see on ühendatud failina, uueneb fail töötavas pod'is mõne aja pärast ise.

Paroolid lähevad **Secret**'i. Secret on nagu ConfigMap, aga väärtused on base64-kujul ja lugemisõigusi saab anda eraldi. Base64 ei ole krüpteering: Kubernetes ei krüpteeri Secret'eid ise. Pod loeb mõlemat keskkonnamuutujatena või failina.

<figure markdown="span">
  [![ConfigMap ja Secret annavad rakendusele andmebaasi aadressi, kasutaja ja parooli](assets/k05_f_c_sec.svg)](assets/k05_f_c_sec.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.8. ConfigMap ja Secret pod'i küljes (Talvik, 2026).</figcaption>
</figure>

### Volume

Kui andmebaasi pod taaskäivitub, kaovad andmed koos sellega. **Volume** ühendab pod'iga ketta, mis on pod'ist väljas: samal node'il või väljaspool klastrit. Kubernetes ise andmeid ei varunda, see on administraatori töö. [Praktikumi osas 10](lab.md#osa-10-andmebaas-secret-configmap-ja-volume) näed mõlemat: ilma Volume'ita andmed kaovad, Volume'iga jäävad alles. Rakendus küsib ketast **PersistentVolumeClaim**'iga (PVC): mitu gigabaiti ja kas üks või mitu kirjutajat. Klaster annab selle StorageClass'i järgi, k3s-is local-path.

<figure markdown="span">
  [![Andmebaasi pod'i külge on ühendatud kohalik ja väline ketas](assets/k05_f_c_vol2.svg)](assets/k05_f_c_vol2.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.9. Volume: kohalik või väline ketas (Talvik, 2026).</figcaption>
</figure>

### Deployment ja StatefulSet

Kui ainus rakenduse pod kukub, ei ole rakendus kättesaadav. Seepärast töötavad koopiad mitmes node'is ja on seotud sama Service'iga. Koopiaid ei looda käsitsi: **Deployment** on pod'i mall, kus on kirjas, mitu koopiat peab töötama. Praktikas lood Deployment'e, mitte pod'e.

Andmebaasi koopiaid Deployment'iga ei tehta, sest koopiad ei ole võrdsed: igaüks vajab oma andmeid ja püsivat nime. Selleks on **StatefulSet**: igal pod'il on püsiv nimi (`postgres-0`, `postgres-1`), püsiv DNS-nimi ja oma ketas. Andmete kopeerimist koopiate vahel StatefulSet ei tee, seda korraldab andmebaas ise või andmebaasi operator. Seepärast hoitakse andmebaasi sageli klastrist väljas. Lisaks on **DaemonSet** (üks pod igal node'il, näiteks logikoguja), **Job** (ühekordne töö) ja **CronJob** (ajastatud töö nagu `cron`).

<figure markdown="span">
  [![Kaks node'i, kummaski rakenduse ja andmebaasi koopia](assets/k05_f_d_sts.svg)](assets/k05_f_d_sts.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.10. Deployment rakendusele, StatefulSet andmebaasile (Talvik, 2026).</figcaption>
</figure>

### Nimeruum

**Nimeruum** (namespace) jagab klastri osadeks, nagu kaust või Proxmoxi pool. Klastri enda osad on nimeruumis `kube-system`, sinu rakendus nimeruumis `default`. Sama nimi võib olla mitmes nimeruumis. `kubectl` vaatab vaikimisi nimeruumi `default`, võti `-n test` vaatab teist ja `-A` kõiki.

??? question "Kontrolli ennast"

    Millise komponendi valid? 1) Veebileht peab vastama, kui üks server kaob. 2) Andmebaas peab olema nähtav ainult klastri sees. 3) Andmebaasi parool. 4) Andmed peavad pod'i taaskäivitusel alles jääma.

    ??? success "Vastus"

        1) Deployment, vähemalt kaks koopiat. 2) Sisemine Service ehk ClusterIP. 3) Secret. 4) Volume ehk PersistentVolumeClaim, mitme koopia korral StatefulSet.

## 5. Konfiguratsioon: soovitud olek ja YAML

`docker run` on **imperatiivne** käsk: see ütleb, mida teha. Kubernetese YAML-fail on **deklaratiivne** kirjeldus: see ütleb, milline olek peab olema, ja süsteem leiab ise, mida selleks teha. Sama mõtet kasutasid Ansible'is ja OpenTofus: `state: present` või `resource` kirjeldab tulemust.

Lihtne näide: **Deployment** on objekt, mis hoiab soovitud arvu ühesuguseid pod'e (täpsemalt jaotises 4). Deployment `tere` ütleb, et image'ist `traefik/whoami` peab töötama kolm pod'i. Kui klastris on kaks pod'i, luuakse kolmas. Kui neli, kustutatakse üks. Kui kolm, ei tehta midagi.

Kirjelduse täitmise eest vastutavad **kontrollerid**. Iga [kontroller](https://kubernetes.io/docs/concepts/architecture/controller/) töötab lõputus tsüklis: loeb soovitud olekut, vaatab tegelikku olekut ja teeb sammu, et vahe kaoks.

<figure markdown="span">
  [![Kontrolltsükkel: kubectl apply muudab soovitud olekut, kubectl delete pod muudab tegelikku olekut; kontroller loeb mõlemat ja loob puuduva pod'i](assets/k05_f_k_ctrl.svg)](assets/k05_f_k_ctrl.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.11. Kontroller võrdleb soovitud ja tegelikku olekut ning kõrvaldab vahe (Talvik, 2026).</figcaption>
</figure>

Kui pod kustutatakse, näeb kontroller vahet „soovitud 3, tegelik 2“ ja loob uue pod'i. Uus pod saab uue nime ja uue IP-aadressi. Pod on **ajutine** (inglise keeles *ephemeral*): see võib igal hetkel kaduda ja asemele tuleb uus. Seepärast ei tohi miski sõltuda pod'i nimest ega aadressist.

??? note "Tabel 5.5. Ansible ja Kubernetes"

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


Deployment ja Service ei tea pod'ide nimesid. Need leiavad pod'id **siltide** (labels) järgi. Silt on võti ja väärtus, näiteks `app: tere`. Deployment paneb sildi igale pod'ile, mille ta loob, ja Service saadab liikluse kõigile pod'idele, millel see silt on. Sama mõtet kasutasid Ansible'i inventory grupid.

<figure markdown="span">
  [![Deployment loob ReplicaSet'i, ReplicaSet loob pod'id, Service leiab pod'id sildi järgi](assets/k05_labelid.svg)](assets/k05_labelid.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.12. Deployment, ReplicaSet, pod ja Service on seotud ainult siltide kaudu (Talvik, 2026).</figcaption>
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

Service'i fail on lühem. Selle `selector` peab olema sama silt, mis Deployment'i mallis.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tere
spec:
  type: NodePort
  selector:
    app: tere                 # leiab pod'id, millel on see silt
  ports:
    - port: 80                # Service'i port klastri sees
      targetPort: 80          # konteineri port
      nodePort: 30080         # port igal node'il
```

??? question "Kontrolli ennast"

    Vaata ülal Deployment'i ja Service'i faili. Millised kolm rida peavad olema sama väärtusega, et päring jõuaks Service'ist pod'ini? Mida iga rida teeb?

    ??? success "Vastus"

        - Deployment'is `template.metadata.labels`: `app: tere` paneb sildi igale uuele pod'ile.
        - Deployment'is `selector.matchLabels`: `app: tere` ütleb, millised pod'id Deployment'ile kuuluvad. Kui see erineb mallist, keeldub API server Deployment'i vastu võtmast.
        - Service'is `selector`: `app: tere` ütleb, millistele pod'idele Service päringud saadab. Kui see erineb, võetakse fail vastu, aga Service'il ei ole ühtegi pod'i.

Kust Service on kättesaadav, ütleb selle tüüp `type`. Tüüpidest ja päringu teest tuleb juttu jaotises 8.

??? question "Kontrolli ennast"

    Service'i failis on `selector: app: tere`, aga Deployment'is on silt `app: Tere` nii `selector`-is kui ka mallis. Mis juhtub, kui teed mõlemale `kubectl apply`?

    ??? success "Vastus"

        Mõlemad failid võetakse vastu ja pod'id töötavad, aga Service ei leia ühtegi pod'i, sest sildid on tõstutundlikud. `kubectl get endpointslices` näitab, et Service'il pole aadresse, ja päringud ei jõua kuhugi.

## 6. Käsust failiks

Kubernetesele saab anda korraldusi kahel viisil. **Imperatiivne** käsk ütleb, mida teha: `kubectl create deployment`, `kubectl scale`, `kubectl delete pod`. **Deklaratiivne** fail kirjeldab soovitud olekut ja `kubectl apply` viib klastri sellega kooskõlla. Käsk sobib katsetamiseks, aga sellest ei jää kirja, milline olek on soovitud. Kui klaster kaob, ei tea keegi, mis seal töötas.

YAML-faili ei pea kirjutama tühjalt lehelt. Võti `--dry-run=client` ütleb, et `kubectl` ei saada midagi klastrisse. Võti `-o yaml` trükib objekti, mille käsk oleks loonud. Nii saad õige kujuga faili, mida muudad edasi ja hoiad Gitis.

```bash
kubectl create deployment tere --image=traefik/whoami:v1.11.0 --replicas=3 \
  --dry-run=client -o yaml > deployment.yaml
```

??? note "Tabel 5.6. Sama muudatus käsuga ja failiga"

    | Muudatus | Käsuga | Failiga |
    |---|---|---|
    | loo Deployment | `kubectl create deployment tere --image=…` | `kubectl apply -f deployment.yaml` |
    | muuda koopiate arvu | `kubectl scale deployment tere --replicas=4` | muuda failis `replicas`, siis `apply` |
    | muuda image'i | `kubectl set image deployment/tere whoami=…` | muuda failis `image`, siis `apply` |
    | kus soovitud olek on kirjas | ainult klastris | failis ja Gitis |

`kubectl apply` on idempotentne. Kui fail ja klaster on juba samad, vastab teine käivitus `unchanged`, nagu Ansible'i `changed=0` ja OpenTofu `No changes`. `kubectl diff -f deployment.yaml` näitab enne muudatust, mis klastris muutuks, nagu `tofu plan`.

Kui keegi muudab klastrit käsuga, erinevad fail ja klaster. Seda erinevust nimetatakse **triiviks** (drift). Järgmine `kubectl apply` viib klastri tagasi faili olekusse ja käsitsi tehtud muudatus kaob. Seepärast tehakse muudatus failis ja failist tuleb see klastrisse.

??? question "Kontrolli ennast"

    Failis on `replicas: 3`. Administraator teeb käsu `kubectl scale deployment tere --replicas=5`. Hiljem muudetakse failis image'i versiooni ja tehakse `kubectl apply`. Mitu pod'i on pärast seda?

    ??? success "Vastus"

        Kolm. `apply` viib klastri faili olekusse ja failis on `replicas: 3`. Kui viis koopiat oli vaja, pidi muudatus minema faili. Kui faili muudetakse, tuleb muudatus Giti, ja nii jääb kirja, kes ja miks muutis.

## 7. k3s paigaldus ja klastri enda osad

Praktikumis paigaldad k3s-i masinasse `control`. [Ametlik paigaldusskript](https://docs.k3s.io/quick-start) laadib alla ühe programmi `k3s`, teeb sellest systemd teenuse ja käivitab selle. Selles ühes programmis on API server, scheduler, kontrollerid, kubelet, containerd ja käsk `kubectl`. Suures klastris on need eraldi programmid ja sageli eraldi masinates.

Skript käivitatakse `sudo` õigustes. Seepärast laadid selle enne alla ja loed läbi. Muutuja `INSTALL_K3S_VERSION` määrab versiooni, et kõigil õppijatel oleks sama klaster. Sama põhimõte kehtis OpenTofu provider'i versiooni puhul.

```bash
curl -sfL https://get.k3s.io -o install-k3s.sh
less install-k3s.sh
INSTALL_K3S_VERSION=v1.36.6+k3s1 sh install-k3s.sh
```

??? note "Tabel 5.7. k3s-i failid ja kaustad"

    | Fail või kaust | Mis seal on |
    |---|---|
    | teenus `k3s` | haldad käsuga `systemctl`, logi näed käsuga `journalctl -u k3s` |
    | `/etc/rancher/k3s/k3s.yaml` | administraatori kubeconfig, loetav ainult root'ile |
    | `/etc/rancher/k3s/registries.yaml` | kust k3s image'id tõmbab, selle faili teed ise |
    | `/var/lib/rancher/k3s/` | klastri andmebaas, image'id ja pod'ide andmed |

**kubeconfig.** k3s kirjutab administraatori kubeconfig'i faili, mida saab lugeda ainult root. Praktikumis kopeerid selle oma kodukausta `~/.kube/config` õigustega `600`, et `kubectl` töötaks ilma `sudo`-ta. Selle failiga on klastrile täielik juurdepääs, seepärast ei panda seda Giti. Töökohas saab iga inimene oma kubeconfig'i piiratud õigustega. Õigusi jagab Kubernetes rollide kaupa (**RBAC**, role-based access control), näiteks „võib lugeda pod'e nimeruumis `test`“. Sama mõte oli Proxmoxi piiratud tokenil.

**Image'id Harborist.** Docker Hub lubab ühelt IP-aadressilt piiratud arvu tõmbeid tunnis. Kogu kool on interneti jaoks üks aadress, nii et 20 õppija klastrid ületaksid piiri kiiresti. Kooli Harbor töötab vahemäluna: tõmbab image'i Docker Hubist üks kord ja annab selle siis kõigile. Fail `registries.yaml` ütleb containerd'le, et Docker Hubi image'id tuleb küsida Harborist. Kui Harbor ei vasta, tõmbab k3s image'i otse Docker Hubist. Ettevõtted hoiavad oma registrit samal põhjusel ja ka selleks, et image'id enne kasutamist turvavigade suhtes kontrollida.

**Klastri enda osad.** Kohe pärast paigaldust näitab `kubectl get pods -A` mitut pod'i, kuigi sa ei ole veel midagi käivitanud. Need on klastri enda osad nimeruumis `kube-system`. Klastri lisad on samuti pod'id ja neid hallatakse samamoodi nagu sinu rakendust.

??? note "Tabel 5.8. Pod'id nimeruumis kube-system"

    | Pod | Mida teeb |
    |---|---|
    | `coredns` | annab Service'itele nimed, nii et pod leiab teise pod'i nime järgi |
    | `traefik` | võtab pordil 80 ja 443 vastu veebiliikluse ja suunab selle Ingressi reeglite järgi |
    | `svclb-traefik` | ServiceLB: avab Traefiku pordid node'i IP-aadressil |
    | `local-path-provisioner` | annab pod'idele kettaruumi node'i kaustast |
    | `metrics-server` | kogub pod'ide protsessori ja mälu kasutust käsule `kubectl top` |
    | `helm-install-traefik`, `helm-install-traefik-crd` | ühekordsed tööd, mis paigaldasid Traefiku Helmiga, olek `Completed` |

??? question "Kontrolli ennast"

    `kubectl get pods` vastab `No resources found in default namespace`, aga `kubectl get pods -A` näitab seitset pod'i. Miks?

    ??? success "Vastus"

        Ilma võtmeta `-n` näitab `kubectl` ainult nimeruumi `default`, kus sinu rakendusi veel ei ole. Võti `-A` näitab kõiki nimeruume ja seal on klastri enda osad nimeruumis `kube-system`.

## 8. Kuidas päring pod'ini jõuab

Pod'i IP-aadress, näiteks `10.42.0.9`, on nähtav ainult klastri sees ja muutub iga uue pod'iga. Service saab püsiva aadressi teisest vahemikust, näiteks `10.43.0.15`, ja püsiva nime. Joonis 5.13 näitab kolme teed Service'ini.

<figure markdown="span">
  [![Kolm teed Service'ini: brauser node'i pordile 30080 kube-proxy kaudu, brauser nimega tere.local Traefiku kaudu ja teine pod nimega tere CoreDNS-i kaudu. Service saadab päringu ühele kolmest pod'ist.](assets/k05_service_tee.svg)](assets/k05_service_tee.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.13. Päring jõuab pod'ini alati Service'i kaudu (Talvik, 2026).</figcaption>
</figure>

**Klastri seest.** Teine pod kasutab aadressi `http://tere`. CoreDNS annab nimele `tere` Service'i aadressi. Sama tegi Compose'i võrgus Dockeri DNS: konteiner leidis teise teenuse nime järgi. Täisnimi on `tere.default.svc.cluster.local`, kus `default` on nimeruum. Teise nimeruumi Service'i poole pöördutakse nimega `tere.<nimeruum>`.

**NodePort.** Service'i tüüp `NodePort` avab pordi vahemikus 30000–32767 igal node'il. kube-proxy seab node'il võrgureeglid, mis saadavad sellele pordile tulnud päringu Service'ile. Port on avatud igal node'il, nii et brauseris sobib ükskõik millise node'i IP-aadress. Praktikumis kasutad porti `30080`.

**Ingress.** Traefik kuulab porte 80 ja 443 ning vaatab päringu päist `Host`. Ingressi reegel ütleb, et nimi `tere.local` läheb Service'ile `tere`. Nii saab ühe IP-aadressi ja pordi taga olla palju rakendusi, nagu nginx'i virtuaalhostid. Ingress ei ole Service'i tüüp, vaid eraldi objekt, mis viitab Service'ile. Ingressi järglane on [Gateway API](https://gateway-api.sigs.k8s.io/), mis jagab sama töö mitme objekti vahel ja oskab rohkem, näiteks jagada liiklust kahe versiooni vahel. Kubernetese projekt [lõpetas 2026. aasta märtsis](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) levinud Ingressi kontrolleri ingress-nginx hoolduse, seepärast liiguvad paljud klastrid Gateway API peale. Traefik toetab mõlemat.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tere
spec:
  rules:
    - host: tere.local            # päise Host väärtus
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: tere        # Service, kuhu päring läheb
                port:
                  number: 80
```

??? note "Tabel 5.9. Kuidas Service'i välja näidata"

    | Viis | Kust kättesaadav | Kus kasutatakse |
    |---|---|---|
    | `ClusterIP` | ainult klastri sees, nimega | andmebaas, sisemine teenus |
    | `NodePort` | iga node'i IP ja port 30000–32767 | katsetamine, praktikum |
    | `LoadBalancer` | eraldi väline IP-aadress | pilves loob pakkuja koormusjaoturi, k3s-is avab ServiceLB pordi node'il, oma serverites jagab IP-aadresse [MetalLB](https://metallb.io/) |
    | Ingress | nimi ja tee, pordid 80 ja 443 | veebirakendused |

Service jagab päringud oma pod'ide vahel. Praktikumis näed seda nii, et rakenduse vastuses muutub `Hostname` päringust päringusse.

??? question "Kontrolli ennast"

    Brauseris on avatud `http://<control'i IP>:30080`. Administraator kustutab korraga kõik kolm pod'i. Mis muutub ja mis jääb samaks?

    ??? success "Vastus"

        Deployment loob kolm uut pod'i uute nimede ja IP-aadressidega. Service'i aadress, nimi ja port `30080` jäävad samaks. Mõne sekundi jooksul võib brauser anda vea, siis vastab leht uute pod'ide nimedega.

## 9. Uus versioon ja tagasivõtt

Image'i tag määrab rakenduse versiooni. Kui failis muutub tag, teeb Deployment uue ReplicaSet'i ja vahetab pod'id järk-järgult välja. Seda nimetatakse **rolling update**'iks. Valmis pod'ide arv ei lange kunagi alla väärtuse `replicas − maxUnavailable`, nii et rakendus vastab kogu uuenduse ajal.

Kaks seadet ütlevad, kui kiiresti vahetus käib. `maxSurge` ütleb, mitu pod'i võib olla soovitud arvust rohkem. `maxUnavailable` ütleb, mitu pod'i võib soovitud arvust puududa. Mõlema vaikeväärtus on 25%. `maxSurge` ümardatakse üles ja `maxUnavailable` alla.

??? note "Tabel 5.10. Rolling update vaikeväärtustega"

    | `replicas` | `maxSurge` | `maxUnavailable` | Mis juhtub, kui uus versioon ei käivitu |
    |---|---|---|---|
    | 3 | 1 | 0 | 3 vana töötavad, 1 uus ei käivitu |
    | 4 | 1 | 1 | 3 vana töötavad, 2 uut ei käivitu |
    | 10 | 3 | 2 | 8 vana töötavad, 5 uut ei käivitu |

Uuendust jälgitakse käsuga `kubectl rollout`:

??? note "Tabel 5.11. Käsud uuenduse jälgimiseks"

    | Käsk | Mida teeb |
    |---|---|
    | `kubectl rollout status deployment tere` | ootab, kuni uuendus lõpeb, või näitab, et see seisab |
    | `kubectl rollout history deployment tere` | näitab varasemaid versioone |
    | `kubectl rollout undo deployment tere` | viib klastri eelmise versiooni juurde |
    | `kubectl get replicasets` | näitab vana ja uut ReplicaSet'i ning nende pod'ide arvu |

`kubectl rollout undo` muudab klastrit, aga mitte faili. Järgmine `apply` toob vigase versiooni tagasi. `undo` sobib hädaolukorraks, kui rakendus on katki ja parandus võtab aega. Seejärel parandatakse ka fail.

Kubernetes peab pod'i valmis olevaks siis, kui konteiner käivitus. Rakendus võib aga vajada käivitumiseks aega. **readinessProbe** ütleb, kuidas valmidust kontrollida, näiteks HTTP-päringuga aadressile `/health`. Kuni kontroll ei õnnestu, ei saada Service pod'ile päringuid ja rolling update ei kustuta järgmist vana pod'i. **livenessProbe** kontrollib samamoodi, kas töötav konteiner on veel terve. Kui see kontroll ebaõnnestub, käivitab kubelet konteineri uuesti. Mõlemad on kirjas [dokumentatsioonis](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/).

```yaml
# konteineri juurde Deployment'is: spec.template.spec.containers[]
readinessProbe:          # kas pod võib päringuid saada
  httpGet:
    path: /health
    port: 80
  periodSeconds: 5
resources:
  requests:              # scheduler paneb selle kinni
    cpu: 50m             # 50 millituuma = 5% ühest tuumast
    memory: 32Mi         # 32 mebibaiti
  limits:                # rohkem mälu: OOMKilled
    memory: 64Mi
```

<figure markdown="span">
  [![kubelet kontrollib iga pod'i aadressi /health, mittevalmis pod jääb Service'ist välja](assets/k05_readiness.svg)](assets/k05_readiness.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.14. readinessProbe eemaldab mittevalmis pod'i Service'ist (Talvik, 2026).</figcaption>
</figure>

**Ära kasuta tag'i `latest`.** Sama tag võib eri päevadel tähendada eri image'it. Siis ei tea keegi, milline versioon töötab, ja `rollout undo` ei pruugi viia tagasi eelmise versiooni juurde. Kasuta kindlat versiooni, näiteks `v1.12.0`.

??? question "Kontrolli ennast"

    Deployment'is on `replicas: 4`. Uues versioonis on image'i tag vale. Mitu pod'i on `Running` ja mitu `ImagePullBackOff`? Mida näitab `kubectl get deployment`?

    ??? success "Vastus"

        Kolm vana pod'i on `Running` ja kaks uut on `ImagePullBackOff`. Nelja koopia puhul lubab `maxUnavailable` ühel pod'il puududa, seepärast kustutati üks vana pod. `maxSurge` lubab viit pod'i korraga, seega tehti kaks uut. `kubectl get deployment` näitab `READY 3/4` ja `UP-TO-DATE 2`.

## 10. Compose'i stack Kubernetesesse

Compose'i failis on iga teenuse kohta image, pordid, muutujad, paroolid ja andmekaustad. Kubernetesis on igaühe jaoks oma objekt. Seepärast on Kubernetese failid pikemad, aga iga osa saab eraldi muuta ja õigusi jagada.

??? note "Tabel 5.12. Compose'i osad Kubernetesis"

    | Compose | Kubernetes |
    |---|---|
    | teenus, `image` | Deployment |
    | teenuse nimi võrgus | Service tüübiga `ClusterIP` |
    | `ports: "8080:80"` | Service tüübiga `NodePort` või Ingress |
    | `environment` | **ConfigMap**: seadistus võtme ja väärtusena |
    | paroolid failis `.env` | **Secret**: nagu ConfigMap, aga eraldi õigustega |
    | `volumes` andmete jaoks | **PersistentVolumeClaim**: kettaruumi taotlus, k3s-is annab selle local-path ühe node'i kettalt, mitme node'i vahel kopeerib andmeid näiteks [Longhorn](https://longhorn.io/) |
    | andmebaas | **StatefulSet**: igal pod'il püsiv nimi ja oma ketas |
    | `healthcheck`, `depends_on` | readinessProbe, käivitamise järjekorda Kubernetes ei taga |
    | `restart: unless-stopped` | Deployment'i kontroller teeb seda alati |

<figure markdown="span">
  [![ConfigMap annab väärtused konteinerile keskkonnamuutujatena](assets/k05_configmap.svg)](assets/k05_configmap.svg){ target="_blank" title="Ava suurelt" }
  <figcaption>Joonis 5.15. ConfigMap'i väärtus jõuab konteinerisse käivitumisel (Talvik, 2026).</figcaption>
</figure>

Secret ei ole krüpteeritud. Väärtus on base64-kujul ja selle saab tagasi lugeda igaüks, kellel on õigus Secret'eid lugeda. Seepärast ei panda Secret'i faili Giti. Töökohas hoitakse paroole välises saladuste halduris, näiteks OpenBao või HashiCorp Vault. Klastrisse tuuakse need eraldi tööriistaga.

Andmebaasi hoitakse sageli klastrist väljas, näiteks pilve hallatud andmebaasina. Klastris on lihtsam hoida rakendusi, mis ei hoia andmeid. Andmebaasi varundamine, uuendamine ja taastamine klastris vajab lisateadmisi. Selleks kasutatakse **Operator**'eid: kontrollereid, mis teavad, kuidas üht kindlat rakendust, näiteks PostgreSQL-i, hallata.

??? question "Kontrolli ennast"

    Compose'is oli andmebaasi parool failis `.env`, mis ei läinud Giti. Kuhu läheb parool Kubernetesis ja kas see on seal krüpteeritud?

    ??? success "Vastus"

        Parool läheb Secret'i. Vaikimisi ei ole see krüpteeritud, vaid ainult base64-kujul. Selle näeb igaüks, kellel on õigus Secret'eid lugeda. Secret'i fail ei lähe Giti, sama nagu `.env`.

## 11. Helm ja GitOps

Kui rakenduses on kümneid YAML-faile ja neid on vaja paigaldada mitmesse keskkonda, muutub failide käsitsi haldamine raskeks. Selleks on kaks tööriista, mida praktikumi lisaülesannetes proovid.

**Helm** on Kubernetese paketihaldur, nagu `apt` Ubuntus. Pakett on **chart**: YAML-failide mallid koos vaikeväärtustega. Käsk `helm install` teeb mallidest failid ja saadab need klastrisse, `helm upgrade` uuendab ja `helm rollback` viib eelmise versiooni juurde. k3s paigaldab Traefiku ise Helmi chart'ina. Enamik valmis tarkvara, näiteks Argo CD, Prometheus ja andmebaasid, paigaldatakse Kubernetesesse Helmiga. Teine levinud tööriist on [Kustomize](https://kustomize.io/), mis on `kubectl`-i sisse ehitatud (`kubectl apply -k`). See ei kasuta malle, vaid lisab tavalistele YAML-failidele keskkonna kaupa muudatusi, näiteks test- ja toodangukeskkonnas erineva koopiate arvu.

??? question "Kontrolli ennast"

    Mis vahe on käskudel `helm upgrade` ja `kubectl apply`?

    ??? success "Vastus"

        `kubectl apply` saadab klastrisse failid nii, nagu need on. `helm upgrade` teeb chart'i mallidest ja väärtustest failid ning salvestab paigalduse versiooni. Seepärast saab Helmiga minna käsuga `helm rollback` eelmise versiooni juurde.

??? info "GitOps ja Argo CD"

    **GitOps** tähendab, et soovitud olek on Gitis ja klastris töötav tööriist viib klastri sellega kooskõlla. **Argo CD** on selline tööriist, teine levinud on [Flux](https://fluxcd.io/). See on samasugune kontroller nagu Kubernetese enda omad, ainult soovitud olek tuleb Gitist. Kui keegi muudab klastris midagi käsitsi, märkab Argo CD erinevust Gitiga ehk **triivi** (drift) ja muudab klastri tagasi. Seda teeb Argo CD ainult siis, kui rakenduse seadistuses on sisse lülitatud `selfHeal`. Vaikimisi näitab Argo CD triivi, aga ei paranda seda.

    <figure markdown="span">
      [![Push-mudelis saadab CI runner muudatuse klastrisse, pull-mudelis loeb Argo CD klastri seest Gitist](assets/k05_gitops.svg)](assets/k05_gitops.svg){ target="_blank" title="Ava suurelt" }
      <figcaption>Joonis 5.16. Push-mudelis saadab CI muudatuse klastrisse, pull-mudelis loeb klastris töötav agent selle Gitist (Talvik, 2026).</figcaption>
    </figure>

    Tavaline ahel töökohas on selline: konveier, näiteks GitHub Actions, ehitab ja testib image'i ning kirjutab selle uue tag'i Gitis olevasse YAML-faili. Argo CD näeb Gitis muudatust ja uuendab klastrit. Argo CD kontrollib Giti vaikimisi iga kolme minuti tagant, nii et muudatus ei jõua klastrisse kohe. Konveier ei vaja klastri võtit, klastrisse kirjutab ainult Argo CD. Nii töötavad ka Eesti ettevõtted. Näiteks on Entigo kirjutanud tag'i uuendamise sammu jaoks oma tööriista [entigo-k8s-gitops](https://github.com/entigolabs/entigo-k8s-gitops).

    ??? info "OpenTofu ja Helm"

        Helmi ja OpenTofut võrreldakse sageli, aga need töötavad eri tasemel. OpenTofu loob infrastruktuuri: võrgu, masinad ja klastri. Helm ja Argo CD paigaldavad rakendused juba olemasolevasse klastrisse. OpenTofus on olemas ka Helmi provider, aga klastri loomine ja rakenduste paigaldamine samas `apply`-s tekitab probleeme, sest provider vajab klastri aadressi juba enne, kui klaster on olemas. Seepärast hoitakse need tavaliselt eraldi.

    ??? question "Kontrolli ennast"

        Klastris on Argo CD, mille rakendusel on `selfHeal` sisse lülitatud. Gitis on `replicas: 3`. Administraator muudab käsuga `kubectl scale` koopiate arvu viieks. Mis juhtub?

        ??? success "Vastus"

            Argo CD märkab, et klaster erineb Gitist, ja viib koopiate arvu tagasi kolmele. Püsiv muudatus tuleb teha Gitis: muuda faili, tee commit ja push. Kui `selfHeal` on välja lülitatud, jääb klastrisse viis koopiat ja Argo CD näitab rakendust olekus `OutOfSync`.

## 12. Kokkuvõte

Kuus mõtet, mis jäävad alles ka siis, kui tööriist vahetub:

1. **Kirjelda tulemust, mitte samme.** `replicas: 3` ütleb, mis peab olema. Kubernetes leiab ise, mida teha.
2. **Kontroller võrdleb kogu aeg.** Kustutatud pod tuleb tagasi, sest soovitud olek ei muutunud.
3. **Ära sõltu pod'i IP-st.** Pod on ajutine, Service'i nimi ja IP jäävad.
4. **Seadistus ja paroolid on image'ist eraldi.** ConfigMap seadistusele, Secret paroolidele.
5. **Andmed on pod'ist eraldi.** Volume hoiab andmeid, kui pod kaob, varundamine on sinu töö.
6. **Soovitud olek on failis ja Gitis.** Käsitsi muudatus kaob järgmisel `apply`-l.

Kubernetese mõisted on uued, aga enamik mõtteid on sulle tuttavad:

| Kubernetes | Sa tunned seda kui |
|---|---|
| node | serverit või Proxmoxi hosti |
| pod | protsessi, mis võib kaduda |
| Deployment | systemd teenust, mis töötab mitmes masinas |
| Service | koormusjaoturit või virtuaalset IP-d |
| Ingress | nginx'i virtuaalhoste |
| ConfigMap, Secret | faili kaustas `/etc` ja faili `.env` |
| Volume | võrguketast |
| label | Ansible'i inventory gruppi |
| kubectl | käske `ssh` ja `pvesh` |
| Helm | käsku `apt` |

??? info "Loe juurde ja harjuta"

    - [TechWorld with Nana: Kubernetes Crash Course](https://www.youtube.com/watch?v=s_o8dwzRlu4): sama sisu ühe tunniga, ingliskeelne video. Demo kood: [gitlab.com/nanuchi/k8s-in-1-hour](https://gitlab.com/nanuchi/k8s-in-1-hour).
    - [Learn Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/): ametlik algajate õpetus.
    - [Killercoda](https://killercoda.com/): tasuta Kubernetese ülesanded brauseris, klastrit pole vaja paigaldada.
    - Oma arvutis saab klastri teha mõne minutiga: [kind](https://kind.sigs.k8s.io/), [k3d](https://k3d.io/) (k3s Dockeris) või minikube.
    - Hea esimene harjutus: pane rakendus tööle Deployment'i, Service'i, ConfigMap'i ja Ingressiga, siis riku see meelega (vale image, vale port, liiga väike mälupiir) ja leia põhjus käskudega `describe` ja `logs`.



--8<-- "includes/k05-sonastik.md"
