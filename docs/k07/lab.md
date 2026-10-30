---
tags:
  - Kubernetes
  - k3s
  - Helm
  - Argo CD
  - GitOps
---

# 7. kohtumine · Praktikum: Labori seis Kubernetese klastris ja GitOps

6. kohtumisel jõudis testitud image registry'sse. Täna viid Labori seisu Kubernetese klastrisse ja annad selle oleku hoidmise Argo CD-le. Kohtumise lõpuks töötab Labori seis koolitaja klastris sinu namespace'is: neli Deployment'i probe'ide ja ressursipiiridega, andmebaas püsikettal ja NetworkPolicy taga ning rakendus Ingress'i kaudu väljast kättesaadav. Uue image'i tag'i kirjutab Giti pipeline ja klastrisse viib selle Argo CD. Vahepeal paigaldad oma ühe node'iga k3s-i klastri, leiad neli koolitaja tehtud riket ja paigaldad Helmiga valmis chart'i.

!!! info "Selle korra töö"
    - **Masin:** control node VPN-i kaudu, repositooriumi kaust `k07-k8s/`, katsefailid `~/k07-katse`
    - **Klastrid:** oma VM `k3s01` Proxmoxis (ainult 1. osas), koolitaja klaster `k3s.lab.hkhk.ee`, sinu namespace `is-<github>`
    - **Koolitajalt:** fail `<github>.kubeconfig`, Argo CD konto ja nelja rikke käivitamine
    - **Varasematest kordadest:** 3. kohtumise `k03-docker/.env` (paroolid), 5. kohtumise workflow `ci` ja app01 image GHCR-is
    - **Esitamine:** haru `k07-k8s` → PR → merge pärast nelja rikke parandamist, siis haru `k07-gitops` → PR → merge → tag `k07`
    - **Edenemine:** [laboritahvel](http://192.168.125.187:8093) (VPN-iga)
    - **Testitud:** k3s `v1.35.9+k3s1` (Traefik 3.7, containerd 2.2), kubectl `v1.35.0`, Helm `v4.2.4`, podinfo chart `6.15.0`, Argo CD ja `argocd` CLI `v3.5.2`

Kui juhendis on **Ennusta:**, ütle vastus enne käsu käivitamist naabrile või mõtle see läbi. Seejärel käivita käsk ja võrdle tulemust oma ennustusega.

Iga osa lõpus on rida **Selle osa tõend**: need väljundid lisad oma repositooriumi K7 issue'sse. Kui oled sama tööd varem teinud, võid rea **Kui teed seda tööl iga päev** järgi etappe vahele jätta, aga tõendi väljundid peavad issue's ikka olemas olema.

## Mis on kohustuslik

| Osa | Mis | Millal |
|---|---|---|
| Kohtumise ajal | [Oma klaster](lab-1-oma-klaster.md), [Namespace ja põhiobjektid](lab-2-namespace.md), [Ressursid ja rikkeotsing](lab-3-ressursid.md), [Labori seis klastris](lab-4-labori-seis.md), [Neli riket](lab-5-neli-riket.md) | kohtumise ajal |
| Võib lõpetada pärast kohtumist | [Helm alused](lab-6-helm.md), [GitOps Argo CD-ga](lab-7-argocd.md), seejärel [esitamine](lab-8-esitamine.md) | VPN-i kaudu; Argo CD Application'i lood alles pärast nelja rikke parandamist, muidu taastaks see rikked |
| Hindamine | tag `k07` haru `main` viimasel commit'il pärast merge'i; automaatse hindaja kuus kontrolli on `OK` ja Labori seisus on rida `lab-07` | esimene tag kohtumise lõpus, parandused uue commit'i ja `git tag -f k07`-ga |

*Tabel 1. Kohustuslikud osad.*

## Osad

1. [Oma klaster](lab-1-oma-klaster.md): k3s01 koolitaja tehtud VM-is, kaks context'i, pod, Service ja PVC node'il, k3s peatatud ja workload töötab edasi.
2. [Namespace ja põhiobjektid](lab-2-namespace.md): `auth can-i`, kvoot, Deployment failist, Service, pod karantiini label'iga, ConfigMap ja Secret.
3. [Ressursid ja rikkeotsing](lab-3-ressursid.md): `exceeded quota`, LimitRange, `FailedScheduling`, OOMKilled, events, `kubectl debug`, kaks katkist pod'i.
4. [Labori seis klastris](lab-4-labori-seis.md): neli teenust, andmed PVC-l üle pod'i vahetuse, init-konteiner, Ingress, NetworkPolicy, rolling update ilma katkestuseta.
5. [Neli riket](lab-5-neli-riket.md): neli koolitaja tehtud riket diagnoositud väljast sisse liikudes, ajajoon ja parandus Gitist.
6. [Helm alused](lab-6-helm.md): `helm template`, values-fail, install, upgrade, rollback, käsitsi muudatus Helmi all ja ebaõnnestunud upgrade, mis võtab end ise tagasi.
7. [GitOps Argo CD-ga](lab-7-argocd.md): Application, CI kirjutab tag'i, selfHeal, prune, katkine YAML, halb commit ja revert, vigane kood main'is ilma katkestuseta tagasi.
8. [Esitamine](lab-8-esitamine.md): kontroll enne tag'i, tag `k07`, automaatse hindaja tulemus, lõputest HK6 ja üks samm oma töökohale.

Veaotsing: [Abi](abi.md).
