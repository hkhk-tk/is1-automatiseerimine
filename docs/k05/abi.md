---
tags:
  - Kubernetes
  - k3s
---

# Abi: Kubernetes k3s-is

Kui midagi ei tööta, alusta kolmest käsust: `kubectl get pods` näitab olekut, `kubectl describe pod <nimi>` näitab lõpus sündmusi ja `kubectl logs <nimi>` näitab konteineri väljundit. Küsimusele lisa käsk ja kogu veateade tekstina.

??? note "Pod'i olekud ja kust põhjust otsida"

    | Olek | Mida tähendab | Kust otsida |
    |---|---|---|
    | `Pending` | pod'ile ei leitud node'i | `describe pod`: sündmused, näiteks `Insufficient memory` |
    | `ContainerCreating` | image laaditakse alla | oota, siis `describe pod` |
    | `ErrImagePull`, `ImagePullBackOff` | image'i ei saanud alla laadida | `describe pod`: `not found` tähendab vale nime või tag'i |
    | `CrashLoopBackOff` | konteineri protsess lõpetab kohe töö ja käivitatakse üha pikema ootega uuesti | `logs <pod> --previous` |
    | `OOMKilled` | konteiner kasutas rohkem mälu, kui `limits` lubab, ja kernel lõpetas selle | `describe pod`: `Last State`, suurenda `limits.memory` |
    | `Running`, aga `READY 0/1` | konteiner töötab, aga ei ole valmis päringuid vastu võtma | `describe pod`: `Readiness probe failed` |

Rolling update kaitseb vigase versiooni eest. Kui uus pod ei käivitu, jääb enamik vanu pod'e tööle ja rakendus vastab edasi. `kubectl get deployment` näitab siis, et `READY` on väiksem kui soovitud arv.

??? warning "`The connection to the server localhost:8080 was refused`"

    kubectl ei leia kubeconfig'i. Selles terminalis pole muutujat `KUBECONFIG`. Käivita `export KUBECONFIG=~/.kube/config` ja kontrolli, et rida on ka failis `~/.bashrc`.

??? warning "`error loading config file "/etc/rancher/k3s/k3s.yaml": permission denied`"

    kubectl loeb k3s-i enda faili, mida saab lugeda ainult root. Tee praktikumi samm 1.4: kopeeri fail `~/.kube/config`-iks ja sea `KUBECONFIG`.

??? warning "Node on `NotReady` või k3s ei käivitu"

    Vaata teenuse olekut ja logi:

    ```bash
    sudo systemctl status k3s
    sudo journalctl -u k3s -n 50 --no-pager
    ```

    Kui logis on viga failis `registries.yaml`, kontrolli YAML-i taandeid. Pärast parandust käivita `sudo systemctl restart k3s`.

??? warning "Pod on `ErrImagePull` või `ImagePullBackOff`"

    `kubectl describe pod <nimi>` näitab sündmuste all põhjust. `not found` tähendab vale image'i nime või tag'i. `x509: certificate signed by unknown authority` tähendab, et k3s ei usalda Harborit: kontrolli, et fail `/usr/local/share/ca-certificates/labori-ca.crt` on olemas ja `registries.yaml` viitab sellele. `toomanyrequests` tähendab, et Docker Hubi tõmbelimiit sai täis ja image ei tulnud Harborist: kontrolli `registries.yaml` faili ja taaskäivita k3s.

??? warning "Pod on `Pending`"

    `kubectl describe pod <nimi>` näitab sündmust. `Insufficient memory` või `Insufficient cpu` tähendab, et control'is pole piisavalt vaba mälu. Vähenda `replicas` väärtust või peata control'is teised teenused, näiteks 3. kohtumise Compose'i stack: `docker compose down`.

??? warning "`curl localhost:30080` ei vasta"

    Kontrolli kolme asja järjest: kas pod'id on `Running` (`kubectl get pods`), kas Service on olemas pordiga `80:30080` (`kubectl get service tere`) ja kas Service leidis pod'id (`kubectl get endpointslices -l kubernetes.io/service-name=tere`). Kui viimases pole aadresse, ei klapi Service'i `selector` pod'ide siltidega.

??? warning "`The Deployment "tere" is invalid: spec.template.metadata.labels: Invalid value`"

    `selector.matchLabels` ja `template.metadata.labels` ei klapi. Mõlemas peab olema sama silt, näiteks `app: tere`.

??? warning "`error: error parsing ...yaml: error converting YAML to JSON`"

    YAML-failis on vale taane või tabulaator. Kasuta ainult tühikuid. `kubectl apply --dry-run=client -f <fail>` kontrollib faili ilma klastrit muutmata.

??? info "Kõik uuesti algusest"

    ```bash
    kubectl delete -f ~/kursus/k05-k8s/ --ignore-not-found
    /usr/local/bin/k3s-uninstall.sh
    ```

    Esimene käsk kustutab failidest loodud objektid, teine eemaldab k3s-i koos kõigi pod'idega. Seejärel alusta praktikumi sammust 1.3. Failid kaustas `~/kursus/k05-k8s` jäävad alles.
