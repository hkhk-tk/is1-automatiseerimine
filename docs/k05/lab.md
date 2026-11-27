---
tags:
  - Kubernetes
  - k3s
  - Praktikum
---

# Praktikum: Kubernetes k3s-is

Eelmisel korral lõid OpenTofuga koodist viis virtuaalmasinat. Masinad tekivad nüüd ühe käsuga, aga rakendusi hoiad töös endiselt ise. K3-s käivitasid Dockeriga konteinereid ühes masinas: kui konteiner kustutati või masin kadus, jäi rakendus seisma, kuni keegi selle taastas.

Täna paigaldad control'isse k3s-i, käivitad rakenduse kolme koopiana ja vaatad, kuidas Kubernetes kustutatud koopia ise asendab.

Seejärel kirjeldad rakenduse YAML-failides, teed selle brauseris kättesaadavaks ja parandad vea, mis takistab uue versiooni käivitumist.

Iga osa alguses on eesmärk ja kontroll. Proovi esmalt ise, lahenduse ava vajaduse korral.

**Edenemine:** laboritahvel <http://is126.kaaren.lab.hkhk.lan> (VPN-iga).

## Algseis ja tulemus

Olemas on control ja repositoorium `~/kursus`. Alustad harust `main`, varasemaid töid pole vaja.

Kooli Harborist saad Docker Hubi image'ite koopiad. Harbori CA-sertifikaat on failis `k03-docker/roles/docker/files/harbor-ca.crt`.

Sinu ülesanne:

- paigaldada k3s;
- luua harus `k05-k8s` failid `k05-k8s/deployment.yaml` ja `k05-k8s/service.yaml`;
- salvestada klastri olek kausta `k05-k8s/logid`;
- esitada töö tag'iga `k05`.

Faile kontrollib GitHubis automaatkontroll.

??? abstract "Õpiväljundid"

    1. Paigaldad ühe masinaga Kubernetese klastri ja kontrollid, et see töötab.
    2. Käivitad Deployment'iga rakenduse kolm koopiat ja kontrollid, et Kubernetes asendab kustutatud koopia.
    3. Rakendad Deployment'i ja Service'i YAML-failid käsuga `kubectl apply`.
    4. Avad rakenduse Service'i kaudu brauseris ja kontrollid, kuidas päringud pod'ide vahel jagunevad.
    5. Leiad käivitusvea põhjuse käskudega `kubectl get` ja `kubectl describe` ning parandad vea failis.

Iga osa käib samamoodi: mõtle enne käsku läbi, mis juhtub, käivita käsk ja kontrolli tulemust käsuga `kubectl get`.

## Abi ja taastamine

Küsimused: [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions). Lisa kasutatud käsk ja kogu veateade tekstina.

Failides kirjeldatud ressursid kustutad ja lood uuesti nii:

```bash
kubectl delete -f k05-k8s/
kubectl apply -f k05-k8s/
```

Kogu k3s-i eemaldad nii:

```bash
/usr/local/bin/k3s-uninstall.sh
```

??? info "Testitud versioonid"

    k3s `v1.36.6+k3s1`, `traefik/whoami:v1.11.0`, Ubuntu 24.04.

    Dokumentatsioon: [k3s](https://docs.k3s.io/), [Kubernetes](https://kubernetes.io/docs/home/), [kubectl](https://kubernetes.io/docs/reference/kubectl/quick-reference/).

## Osa 1 · k3s control'isse

**Kubernetes** on süsteem, mis käivitab konteinereid mitmes masinas ja hoiab neid töös. Sina kirjeldad soovitud olekut, näiteks „rakendusest töötab kolm koopiat“, ja Kubernetes võrdleb seda pidevalt tegeliku olekuga. **k3s** on Kubernetes, mis on pakitud ühte programmi ja paigaldub ühe käsuga. Käsud ja failid on samad mis suures klastris, nii et kõik siin õpitu kehtib ka pilves.

**Eesmärk:** control'is töötab k3s ja `kubectl` töötab ilma `sudo`-ta.  
**Kontroll:** `kubectl get nodes` näitab node'i `control` olekus `Ready`.  
**Kus:** control, kaust `~/kursus`.

### 1.1 Haru ja kaust

```bash
cd ~/kursus && git switch main && git pull
git switch -c k05-k8s
mkdir -p k05-k8s/logid
git branch --show-current
```

??? success "Oodatav tulemus"

    Viimane käsk näitab `k05-k8s`.

??? warning "Kui tuleb viga `a branch named 'k05-k8s' already exists`"

    Haru on sul juba olemas. Vaheta sellele käsuga `git switch k05-k8s`.

### 1.2 Image'id Harborist

Klastri enda osad, näiteks DNS ja Traefik, on samuti konteinerid ja nende image'id tulevad Docker Hubist. Docker Hub lubab ühelt IP-aadressilt piiratud arvu tõmbeid tunnis ja kogu kool on interneti jaoks üks aadress. Fail `/etc/rancher/k3s/registries.yaml` ütleb k3s-ile, et Docker Hubi image'id tuleb küsida kooli Harborist. Harbor tõmbab image'i Docker Hubist üks kord ja annab selle siis kõigile.

Harboril on kooli enda CA sertifikaat. k3s usaldab Harborit, kui CA-fail on masinas olemas ja `registries.yaml` viitab sellele.

```bash
sudo cp ~/kursus/k03-docker/roles/docker/files/harbor-ca.crt /usr/local/share/ca-certificates/labori-ca.crt
sudo update-ca-certificates
sudo mkdir -p /etc/rancher/k3s
```

Tee fail `/etc/rancher/k3s/registries.yaml`, näiteks käsuga `sudo nano /etc/rancher/k3s/registries.yaml`. Rida `rewrite` lisab image'i nime ette Harbori projekti `dockerhub`: `traefik/whoami` muutub kujule `dockerhub/traefik/whoami`.

??? example "Ülesanne: fail `/etc/rancher/k3s/registries.yaml`"

    ```yaml
    mirrors:
      docker.io:
        endpoint:
          - "https://harbor.lab.hkhk.lan"
        rewrite:
          "^(.*)$": "dockerhub/$1"
    configs:
      "harbor.lab.hkhk.lan":
        tls:
          ca_file: /usr/local/share/ca-certificates/labori-ca.crt
    ```

??? info "Kui Harbor ei vasta"

    k3s proovib kõigepealt Harborit ja kui see ei vasta, tõmbab image'i otse Docker Hubist. Fail ei tee seega midagi katki, ainult hoiab Docker Hubi tõmbed väiksemad. Vaata lähemalt [k3s-i dokumentatsioonist](https://docs.k3s.io/installation/private-registry).

### 1.3 Paigalda k3s

k3s-i paigaldab [ametlik skript](https://docs.k3s.io/quick-start). Skript laadib alla ühe programmi, teeb sellest systemd teenuse ja käivitab selle. Loe skript enne käivitamist läbi, sest see kasutab `sudo`-t. Muutuja `INSTALL_K3S_VERSION` hoiab versiooni sama, mis juhendis.

```bash
curl -sfL https://get.k3s.io -o install-k3s.sh
less install-k3s.sh
INSTALL_K3S_VERSION=v1.36.6+k3s1 sh install-k3s.sh
sudo k3s kubectl get nodes
```

??? success "Oodatav tulemus"

    Skript lõpeb reaga `[INFO]  systemd: Starting k3s`. Umbes poole minuti pärast näitab viimane käsk:

    ```text
    NAME      STATUS   ROLES           AGE   VERSION
    control   Ready    control-plane   40s   v1.36.6+k3s1
    ```

    Klastris on üks **node** ehk masin, kus konteinerid töötavad. See on sinu control. Suures klastris on node'e kümneid ja juhtimise osa, **control plane**, on eraldi masinates.

??? warning "Kui olek on `NotReady`"

    k3s käivitab veel oma osi. Oota minut ja käivita käsk uuesti. Kui olek ei muutu, vaata teenuse logi: `sudo journalctl -u k3s -n 50`.

### 1.4 kubectl ilma sudo-ta

**kubectl** on käsk, millega räägid klastriga. Klastri aadress ja sinu sertifikaat on failis, mille nimi on **kubeconfig**. k3s kirjutab selle faili `/etc/rancher/k3s/k3s.yaml`, mida saab lugeda ainult root. Kopeerid faili oma kodukausta, et `kubectl` töötaks ilma `sudo`-ta.

```bash
mkdir -p ~/.kube
sudo k3s kubectl config view --raw > ~/.kube/config
chmod 600 ~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
export KUBECONFIG=~/.kube/config
kubectl get nodes
```

??? success "Oodatav tulemus"

    Sama väljund mis 1.3-s, aga ilma `sudo`-ta. Failis on klastri administraatori sertifikaat, seepärast õigused `600`. See fail ei lähe Giti.

Vaata, mis klastris juba töötab. Enne käsku mõtle läbi: kas klastris on midagi, kuigi sa pole veel midagi käivitanud?

```bash
kubectl get pods -A
```

??? success "Oodatav tulemus"

    Nimeruumis `kube-system` töötavad klastri enda osad: `coredns` annab nimed, `local-path-provisioner` annab kettaruumi, `metrics-server` kogub mõõdikuid ja `traefik` võtab vastu veebiliikluse. Kaks pod'i `helm-install-traefik` on olekus `Completed`: k3s paigaldas Traefiku Helmiga ja see töö on lõppenud. Helmist on juttu lisaülesannetes.

    **Nimeruum** (namespace) jagab klastri osadeks. Sinu rakendus läheb nimeruumi `default`, mida `kubectl` kasutab, kui nimeruumi pole antud. Võti `-A` näitab kõiki nimeruume.

## Osa 2 · Esimene rakendus käsuga

**Pod** on Kubernetese väikseim üksus: üks või mitu konteinerit, millel on ühine IP-aadress. Pod'e otse ei looda. **Deployment** kirjeldab, mitu ühesugust pod'i peab töötama ja millisest image'ist, ning loob ja asendab need ise. Rakendus `traefik/whoami` on väike veebiserver, mis vastab pod'i nime ja IP-aadressiga. Nii näed, milline pod päringule vastas.

**Eesmärk:** Deployment `tere` töötab ja selle pod vastab.  
**Kontroll:** `kubectl get deployment tere` näitab `READY 1/1`.  
**Kus:** control.

### 2.1 Deployment

```bash
kubectl create deployment tere --image=traefik/whoami:v1.11.0
kubectl get deployment tere
kubectl get pods -o wide
```

??? success "Oodatav tulemus"

    Mõne sekundi pärast on Deployment'i real `READY 1/1`. Pod'i nimi algab `tere-` ja lõpeb juhusliku osaga, näiteks `tere-6d8c5b7f9c-x2kq4`. Veerus `IP` on pod'i aadress, näiteks `10.42.0.9`, ja veerus `NODE` on `control`.

??? warning "Kui olek jääb `ContainerCreating`"

    Image tuleb alla laadida. Oota pool minutit. Kui olek muutub `ErrImagePull`-iks, vaata 6. osa: seal on sama viga lahti seletatud.

### 2.2 Vaata pod'i sisse

`kubectl describe` näitab kõike, mida Kubernetes pod'i kohta teab, ja lõpus sündmusi (Events) loomise järjekorras. `kubectl logs` näitab konteineri väljundit nagu `docker logs`. Asenda `<pod>` oma pod'i nimega.

```bash
kubectl describe pod <pod> | tail -n 15
kubectl logs <pod>
curl http://<pod-ip>
```

??? success "Oodatav tulemus"

    Sündmuste all on järjest `Scheduled`, `Pulling`, `Pulled`, `Created` ja `Started`. `logs` näitab rida `Starting up on port 80`. `curl` vastab mitme reaga, mille esimene on `Hostname: tere-...`, sama nimi nagu pod'il.

??? tip "Pod'i nimi ilma kopeerimiseta"

    `kubectl get pods -l app=tere -o name` annab nime kujul `pod/tere-...`. Seda saab kasutada otse: `kubectl logs $(kubectl get pods -l app=tere -o name | head -1)`.

## Osa 3 · Kubernetes taastab soovitud oleku

Siin on Kubernetese põhimõte. Deployment'is on kirjas soovitud olek: mitu pod'i peab töötama. Kontroller võrdleb seda pidevalt tegeliku olekuga ja kui need erinevad, teeb vahe tasa. Sama mõtet nägid Ansible'is ja OpenTofus, aga seal käivitasid võrdluse sina. Kubernetes võrdleb kogu aeg ise.

**Eesmärk:** näed, et kustutatud pod asendatakse uuega.  
**Kontroll:** pärast kustutamist on jälle kolm pod'i ja üks neist on uue nimega.  
**Kus:** control.

### 3.1 Kolm koopiat

```bash
kubectl scale deployment tere --replicas=3
kubectl get pods -o wide
```

??? success "Oodatav tulemus"

    Kolm pod'i, kõigil olek `Running` ja igaühel oma IP.

### 3.2 Kustuta üks pod

Ava teine terminal ja jälgi seal pod'e. Võti `-w` jääb ootama ja näitab iga muutust.

```bash
kubectl get pods -w
```

Kustuta esimeses terminalis üks pod. Enne käsku mõtle läbi: mitu pod'i on minuti pärast ja kas kustutatud pod tuleb tagasi sama nimega?

```bash
kubectl delete pod <üks-pod>
kubectl get pods
```

??? success "Oodatav tulemus"

    Teises terminalis läheb kustutatud pod olekusse `Terminating` ja peaaegu samal ajal tekib uus pod uue nimega ja uue IP-ga. Minuti pärast töötab jälle kolm pod'i. Vana pod'i tagasi ei tule: Deployment ei taasta konkreetset pod'i, vaid hoiab õiget arvu.

    Dockeris jääks kustutatud konteiner kustunuks. Konteiner, mis ise kukub, käivitub Dockeris uuesti ainult siis, kui tal on `restart`-reegel, ja ainult samas masinas.

Sulge teises terminalis jälgimine klahvidega ++ctrl+c++.

??? question "Kontrolli ennast"

    Uuel pod'il on uus IP-aadress. Miks on see probleem, kui teine rakendus tahab selle pod'iga ühendust võtta?

    ??? success "Vastus"

        Teine rakendus ei tea uut aadressi. Iga kustutamise, uuenduse või node'i rikke järel muutuvad pod'ide aadressid. 5. osas lahendab selle Service, millel on püsiv nimi ja aadress.

## Osa 4 · Sama YAML-failina

Käsud `create` ja `scale` muutsid klastrit, aga kuskile kirja ei jäänud, milline olek on soovitud. Kui klaster homme kaob, ei tea keegi, mis seal töötas. Nii nagu playbook ja `.tf`-fail, läheb ka Kubernetese soovitud olek faili ja faili Giti. Fail tuleb klastrisse käsuga `kubectl apply`.

**Eesmärk:** Deployment `tere` on loodud failist `k05-k8s/deployment.yaml`.  
**Kontroll:** teine `kubectl apply` ütleb `unchanged`.  
**Kus:** control, kaust `~/kursus`.

### 4.1 Fail käsust

YAML-faili ei pea tühjalt lehelt kirjutama. Võti `--dry-run=client` ütleb, et `kubectl` ei saada midagi klastrisse, ja `-o yaml` trükib objekti, mille käsk oleks loonud. Nii saad õige kujuga faili, mida muudad edasi.

```bash
kubectl create deployment tere --image=traefik/whoami:v1.11.0 --replicas=3 \
  --dry-run=client -o yaml > k05-k8s/deployment.yaml
cat k05-k8s/deployment.yaml
```

??? success "Oodatav tulemus"

    Failis on umbes 25 rida. Read `creationTimestamp: null`, `resources: {}`, `strategy: {}` ja `status: {}` on tühjad väärtused. Need võivad jääda või võid need kustutada.

Fail koosneb neljast osast, mis on igal Kubernetese objektil.

??? note "Tabel L5.1. Kubernetese objekti osad"

    | Väli | Tähendus |
    |---|---|
    | `apiVersion`, `kind` | Mis tüüpi objekt see on: `apps/v1` ja `Deployment` |
    | `metadata` | Nimi ja sildid (labels), mille järgi objekti leitakse |
    | `spec` | Soovitud olek: `replicas`, milliseid pod'e otsida (`selector`) ja millisest mallist (`template`) need teha |
    | `status` | Tegelik olek. Selle kirjutab Kubernetes, sina seda ei täida |

Kõige olulisem on siltide seos. `selector.matchLabels` ütleb, et Deployment'ile kuuluvad pod'id sildiga `app: tere`. `template.metadata.labels` annab sama sildi igale uuele pod'ile. Kui need ei klapi, ei leia Deployment oma pod'e üles ja Kubernetes keeldub faili vastu võtmast.

### 4.2 Kustuta käsuga tehtu ja loo failist

Kustutad käsuga loodud Deployment'i, et kogu soovitud olek tuleks nüüd failist.

```bash
kubectl delete deployment tere
kubectl apply -f k05-k8s/deployment.yaml
kubectl get deployment tere
```

??? success "Oodatav tulemus"

    `delete` kustutab Deployment'i ja koos sellega kõik kolm pod'i. `apply` vastab `deployment.apps/tere created` ja minuti pärast on `READY 3/3`.

Käivita `apply` teist korda. Enne käsku mõtle läbi: mida Kubernetes teeb, kui fail ja klaster on juba samad?

```bash
kubectl apply -f k05-k8s/deployment.yaml
```

??? success "Oodatav tulemus"

    `deployment.apps/tere unchanged`. See on sama mis Ansible'i `changed=0` ja OpenTofu `No changes`: kui soovitud ja tegelik olek on samad, ei muudeta midagi.

### 4.3 Muuda faili

Muuda failis `replicas: 3` väärtuseks `4`. Käsk `kubectl diff` näitab enne muutmist, mis klastris muutuks, nagu `tofu plan`.

```bash
kubectl diff -f k05-k8s/deployment.yaml
kubectl apply -f k05-k8s/deployment.yaml
kubectl get pods
```

??? success "Oodatav tulemus"

    `diff` näitab rida `-  replicas: 3` ja `+  replicas: 4`. `apply` vastab `configured` ja pod'e on neli.

Salvesta töö Giti:

```bash
git add k05-k8s/deployment.yaml
git commit -m "k05: Deployment tere failist"
```

## Osa 5 · Service

Pod'ide aadressid muutuvad. **Service** annab pod'ide grupile püsiva nime ja aadressi ning jagab päringud nende pod'ide vahel. Service leiab pod'id sama sildi järgi nagu Deployment: `app: tere`. Vaikimisi tüüpi Service, **ClusterIP**, on nähtav ainult klastri sees. Tüüp **NodePort** avab lisaks pordi node'il, nii et rakendust saab vaadata ka oma arvuti brauserist.

**Eesmärk:** rakendus on brauseris nähtav ja päringutele vastavad erinevad pod'id.  
**Kontroll:** `curl http://localhost:30080` vastab ja `Hostname` muutub päringust päringusse.  
**Kus:** control ja sinu arvuti brauser.

### 5.1 service.yaml

Pordid on Service'is kolmes kohas. `targetPort` on port konteineris, kus `whoami` kuulab. `port` on Service'i port klastri sees. `nodePort` on port node'il, mille kaudu tuleb liiklus väljast. NodePort peab olema vahemikus 30000–32767.

??? example "Ülesanne: fail `k05-k8s/service.yaml`"

    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: tere
    spec:
      type: NodePort
      selector:
        app: whoami
      ports:
        - port: 80
          targetPort: 80
          nodePort: 30080
    ```

```bash
kubectl apply -f k05-k8s/service.yaml
kubectl get service tere
kubectl get endpointslices -l kubernetes.io/service-name=tere
```

??? success "Oodatav tulemus"

    Service'i real on `TYPE NodePort` ja `PORT(S) 80:30080/TCP`.

Proovi, kas rakendus vastab:

```bash
curl -s -m 5 http://localhost:30080; echo "kood $?"
```

Vastust ei tule. Pod'id töötavad ja Service on olemas. Leia põhjus.

??? tip "Vihje"

    Vaata EndpointSlice'i väljundit eelmisest käsust: millised pod'id Service leidis? Seejärel vaata pod'ide silte: `kubectl get pods --show-labels`.

??? question "Leia põhjus"

    Miks Service ei saada päringuid pod'idele?

    ??? success "Vastus"

        EndpointSlice'is ei ole ühtegi aadressi: Service ei leidnud ühtegi pod'i. Service'i `selector` otsib silti `app: whoami`, aga pod'idel on silt `app: tere`. `whoami` on konteineri nimi, mitte silt. Service leiab pod'id ainult siltide järgi ja kui ükski pod ei klapi, ei lähe päring kuhugi.

Paranda failis `selector` väärtuseks `app: tere` ja rakenda uuesti:

```bash
kubectl apply -f k05-k8s/service.yaml
kubectl get endpointslices -l kubernetes.io/service-name=tere
```

??? success "Oodatav tulemus"

    `service/tere configured`. EndpointSlice näitab nüüd nelja pod'i IP-aadressi.

### 5.2 Päringud jagunevad

```bash
for i in 1 2 3 4 5 6; do curl -s http://localhost:30080 | grep Hostname; done
hostname -I
```

??? success "Oodatav tulemus"

    Kuus rida, kus `Hostname` on erinevate pod'ide nimed. Service jagab päringud pod'ide vahel. `hostname -I` näitab control'i IP-aadressi, näiteks `192.168.125.81`.

Ava oma arvuti brauseris `http://<control'i IP>:30080` ja värskenda lehte mitu korda.

??? success "Oodatav tulemus"

    Lehel on tekst, mis algab `Hostname: tere-...`, ja nimi muutub värskendamisel.

??? warning "Kui brauser ei vasta"

    Kontrolli, et VPN on ühendatud ja `curl` töötab control'is. Kui control'is on tulemüür sees (`sudo ufw status` näitab `active`), luba port: `sudo ufw allow 30080/tcp`.

Kustuta korraga kõik pod'id ja jälgi samal ajal brauserit. Enne käsku mõtle läbi: kas leht jääb pikaks ajaks kättesaamatuks?

```bash
kubectl delete pods -l app=tere
kubectl get pods
```

??? success "Oodatav tulemus"

    Mõne sekundi jooksul võib brauser veateate anda, siis vastab leht uuesti uute pod'ide nimedega. Service'i aadress ja port jäid samaks, muutusid ainult pod'id selle taga.

Salvesta töö Giti:

```bash
git add k05-k8s/service.yaml
git commit -m "k05: NodePort Service tere"
```

## Osa 6 · Leia viga: uus versioon ei käivitu

Rakendusest on ilmunud uus versioon. Uuendad Deployment'is image'i ja vaatad, kas uuendus õnnestus. Kubernetes vahetab pod'e järk-järgult: uus pod peab enne töötama, kui vana kustutatakse. Seda nimetatakse **rolling update**'iks.

**Eesmärk:** leiad, miks uus pod ei käivitu, ja parandad selle failis.  
**Kontroll:** `kubectl get deployment tere` näitab `READY 4/4` ja `UP-TO-DATE 4`.  
**Kus:** control, kaust `~/kursus`.

??? example "Ülesanne: uus image failis `k05-k8s/deployment.yaml`"

    Asenda rida `image:` järgmisega:

    ```yaml
            image: traefik/whoami:1.12.0
    ```

Enne käsku mõtle läbi: kas rakendus jääb brauseris kättesaadavaks, kui uus versioon ei käivitu?

```bash
kubectl apply -f k05-k8s/deployment.yaml
kubectl get pods
```

Oota minut ja vaata uuesti `kubectl get pods`. Leia põhjus järgmiste käskudega. Asenda `<pod>` pod'iga, mis ei ole `Running`.

```bash
kubectl get deployment tere
kubectl describe pod <pod> | tail -n 10
```

??? question "Leia põhjus"

    Mis olekus on uus pod? Mida ütleb `describe` sündmuste all rida `Failed`?

    ??? success "Vastus"

        Uus pod on olekus `ErrImagePull` ja seejärel `ImagePullBackOff`: image'i ei saa alla laadida ja Kubernetes proovib uuesti üha pikemate vahedega. Sündmus ütleb `failed to resolve reference "docker.io/traefik/whoami:1.12.0": ... not found`. Sellist tag'i ei ole: versiooni ees puudub `v`. Docker Hubis on tag'id kujul `v1.12.0`.

        Kolm vana pod'i töötavad edasi ja brauseris vastab leht endiselt. Nelja koopia puhul lubab rolling update ühel pod'il puududa, seepärast kustutati üks vana pod ja tehti kaks uut. Deployment'i real näed `READY 3/4` ja `UP-TO-DATE 2`: kaks pod'i on uue malli järgi tehtud, aga need ei tööta.

Paranda failis image'i rida kujule `traefik/whoami:v1.12.0` ja rakenda uuesti:

```bash
kubectl apply -f k05-k8s/deployment.yaml
kubectl rollout status deployment tere
kubectl get pods
```

??? success "Oodatav tulemus"

    `rollout status` ootab ja lõpeb reaga `deployment "tere" successfully rolled out`. Kõik neli pod'i on uute nimedega ja `Running`. `curl http://localhost:30080` vastab endiselt.

??? info "Käsk `kubectl rollout undo`"

    Teine võimalus on käsk `kubectl rollout undo deployment tere`, mis viib Deployment'i eelmise versiooni juurde. Siis aga erinevad fail ja klaster ning järgmine `apply` toob vea tagasi. Kui soovitud olek on failis, parandad vea failis.

```bash
git add k05-k8s/deployment.yaml
git commit -m "k05: tere image v1.12.0"
```

## Osa 7 · Esitamine

Automaatkontroll näeb ainult repositooriumi, sinu klastrit see ei näe. Seepärast salvestad klastri oleku faili kausta `k05-k8s/logid`. Automaatkontroll kontrollib failide olemasolu, Deployment'i ja Service'i sisu ning logifaili.

**Eesmärk:** töö on `main`-is ja tag `k05` on käivitanud automaatkontrolli.  
**Kontroll:** kolm kontrolli annavad `OK`.  
**Kus:** control, kaust `~/kursus`.

### 7.1 Klastri olek faili

```bash
kubectl get nodes,deployments,pods,services -o wide > k05-k8s/logid/klaster.txt
cat k05-k8s/logid/klaster.txt
for t in files manifest logid; do bash autograde/check.sh k05 "$t"; done
```

??? success "Oodatav tulemus"

    Failis on node `control` olekus `Ready`, Deployment `tere` kujul `4/4`, neli `Running` pod'i ja Service `tere` pordiga `80:30080`. Kõik kolm kontrolli annavad `OK`.

??? warning "Kui `check.sh` ütleb `tundmatu kohtumine k05`"

    Sinu repositooriumi kontrollskript on vana. Uuenda see: `curl -fsSL https://raw.githubusercontent.com/hkhk-tk/is1-starter/main/autograde/check.sh -o autograde/check.sh`.

### 7.2 Commit, main ja tag

```bash
git add k05-k8s autograde/check.sh
git commit -m "k05: klastri olek logis"
git push -u origin k05-k8s
git switch main
git merge k05-k8s
git push
git tag k05 && git push origin k05
```

Tulemuse näed mõne minuti pärast Classroom 50-s.

??? warning "Kui pead pärast esitamist parandama"

    Tee uus commit `main`-i ja liiguta tag: `git tag -f k05 && git push -f origin k05`.

## Lisaülesanded

??? example "1 · Ingress: nimi pordi asemel"

    NodePort'i number on kasutajale ebamugav. **Ingress** suunab päringu nime järgi õigesse Service'isse ja k3s-is teeb seda Traefik, mis klastris juba töötab. Tee fail `k05-k8s/ingress.yaml`:

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: tere
    spec:
      rules:
        - host: tere.local
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: tere
                    port:
                      number: 80
    ```

    ```bash
    kubectl apply -f k05-k8s/ingress.yaml
    curl -s -H 'Host: tere.local' http://localhost/ | grep Hostname
    ```

    Vastus tuleb pordilt 80 ilma pordi numbrita. Päise `Host` järgi leidis Traefik õige Service'i. Vaata lähemalt [Kubernetese Ingressi dokumentatsioonist](https://kubernetes.io/docs/concepts/services-networking/ingress/).

??? example "2 · Rolling update ja ajalugu"

    Muuda image'iks `traefik/whoami:v1.11.0`, rakenda ja vaata samal ajal teises terminalis `kubectl get pods -w`. Vaata seejärel ajalugu:

    ```bash
    kubectl rollout history deployment tere
    kubectl rollout undo deployment tere
    kubectl get deployment tere -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
    ```

    Pod'id vahetuvad ükshaaval ja `undo` viib tagasi `v1.12.0` juurde. Pärast `undo`-d erinevad fail ja klaster: muuda fail samaks ja tee `kubectl diff -f k05-k8s/deployment.yaml`, mis peab olema tühi.

??? example "3 · Helm: k3s paigaldas Traefiku chart'ina"

    **Helm** on Kubernetese paketihaldur nagu `apt` Ubuntus. Pakett on **chart**: mallide kogum, millest Helm teeb YAML-failid. k3s paigaldas Traefiku Helmiga ise:

    ```bash
    kubectl get helmcharts -n kube-system
    kubectl get pods -n kube-system | grep helm-install
    ```

    Paigalda Helmi käsk ja vaata, mis release'id klastris on:

    ```bash
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get-helm.sh
    less get-helm.sh
    bash get-helm.sh
    helm list -A
    ```

    `helm list -A` näitab release'e `traefik` ja `traefik-crd`. Vaata lähemalt [k3s-i Helmi lehelt](https://docs.k3s.io/add-ons/helm).

??? example "4 · Argo CD hoiab klastrit Gitiga samas olekus"

    **Argo CD** loeb soovitud olekut Gitist ja viib klastri sellega kooskõlla. Käsitsi tehtud muudatuse muudab see tagasi. Paigalda Argo CD Helmiga (vajab lisaülesannet 3):

    ```bash
    helm repo add argo https://argoproj.github.io/argo-helm
    helm install argocd argo/argo-cd -n argocd --create-namespace
    kubectl get pods -n argocd
    ```

    Tee fail `k05-k8s/argocd/application.yaml`, mis jälgib sinu repositooriumi haru `main` kausta `k05-k8s`. Repositoorium peab olema Argo CD jaoks loetav: kui see on privaatne, tuleb lisada token ([Argo CD dokumentatsioon](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/)).

    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: tere
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/<org>/<sinu-repo>.git
        targetRevision: main
        path: k05-k8s
        directory:
          exclude: 'argocd/*'
      destination:
        server: https://kubernetes.default.svc
        namespace: default
      syncPolicy:
        automated:
          selfHeal: true
    ```

    ```bash
    kubectl apply -f k05-k8s/argocd/application.yaml
    kubectl scale deployment tere --replicas=1
    kubectl get pods -w
    ```

    Mõne sekundi pärast teeb Argo CD pod'e jälle neli, sest Gitis on kirjas `replicas: 4`.

??? example "5 · GitHub Actions uuendab image'i Gitis"

    Tööl ei muuda keegi image'i rida käsitsi. Konveier ehitab uue image'i, kirjutab selle tag'i YAML-faili ja teeb commit'i. Argo CD näeb Gitis muudatust ja uuendab klastrit. Nii ei vaja konveier klastri parooli: klastrisse kirjutab ainult Argo CD. Selle ahela saad läbi teha [IS2 süvenemise lehel](https://hkhk-tk.github.io/is2-automatiseerimine/k07/syvenemine/#42-ci-kirjutab-tagi-argo-viib-klastrisse).

??? example "6 · Kubernetes pilves"

    Samad failid töötavad ka pilves, näiteks AWS-i Kubernetese teenuses EKS. Erinevus on paigalduses: k3s-i paigaldasid ise, EKS-is haldab control plane'i AWS. Vaata [HashiCorpi EKS-i õpetust](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks). EKS maksab ka tühjana tunnitasu, nii et kustuta klaster kohe pärast proovimist.

Veaotsing: [Abi](abi.md).
