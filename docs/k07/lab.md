---
tags:
  - Kubernetes
  - k3s
  - Helm
  - Argo CD
  - GitOps
---

# 7. kohtumine · Praktikum: Labori seis Kubernetese klastris ja GitOps

!!! info "Selle korra töö"
    - **Masin:** control node VPN-i kaudu, repo kaust `k07-k8s/`, katsefailid `~/k07-katse`
    - **Sihtmasinad:** oma VM `k3s01` Proxmoxis (ainult lehel [Oma klaster](lab-1-oma-klaster.md)), koolitaja klaster `k3s.lab.hkhk.ee`, namespace `is-<github>`
    - **Esitamine:** haru `k07-k8s` → PR → merge pärast nelja rikke parandamist, siis haru `k07-gitops` → PR → merge → tag `k07`
    - **Varasematest kordadest vaja:** 3. kohtumisest `k03-docker/.env` (paroolid), 5. kohtumisest workflow `ci` ja app01 image GHCR-is
    - **Vaja koolitajalt:** `<github>.kubeconfig`, Argo CD konto, nelja rikke käivitamine
    - **Testitud:** k3s `v1.35.9+k3s1` (Traefik 3.7, containerd 2.2), kubectl `v1.35.0`, Helm `v4.2.4`, podinfo chart `6.15.0`, Argo CD ja `argocd` CLI `v3.5.2`, OpenTofu kursuse VM-i versioon, image'id `mariadb:11.4`, `nginx:1.30-alpine`, `busybox:1.37`, Ubuntu 24.04
    - **Dokumentatsioon:** [Kubernetes](https://kubernetes.io/docs/) · [kubectl](https://kubernetes.io/docs/reference/kubectl/) · [k3s](https://docs.k3s.io/) · [Helm](https://helm.sh/docs/) · [Argo CD](https://argo-cd.readthedocs.io/)

Kohtumise lõpuks töötab Labori seis koolitaja klastris sinu namespace'is: neli Deployment'i probe'ide ja ressursipiiridega, andmebaas PVC-l ja NetworkPolicy taga, rakendus Ingress'i kaudu väljast kättesaadav. Klastri olekut hoiab Argo CD sinu repositooriumi järgi ja uue image'i tag'i kirjutab Giti pipeline. Vahepeal paigaldad oma ühe node'iga k3s-i klastri, leiad neli koolitaja tehtud riket ja paigaldad Helmiga valmis chart'i.

Iga moodul lõpeb tõendiga issue's (milestone `K7`). Kui commit sulgeb mooduli issue, lisa sõnumisse `closes #N`.

Kui jätad etappe vahele rea **Kui teed seda tööl iga päev** järgi, peavad 📎 rea väljundid issue's ikka olemas olema.

## Mis on kohustuslik

| Osa | Mis | Millal |
|---|---|---|
| Kohtumise ajal | [Oma klaster](lab-1-oma-klaster.md), [Namespace ja põhiobjektid](lab-2-namespace.md), [Ressursid ja rikkeotsing](lab-3-ressursid.md), [Labori seis klastris](lab-4-labori-seis.md), [Neli riket](lab-5-neli-riket.md) | laboris 11:30–15:00 |
| Võib lõpetada pärast kohtumist | [Helm alused](lab-6-helm.md), [GitOps Argo CD-ga](lab-7-argocd.md); [Esitamise](lab-8-esitamine.md) kontrollid uuesti pärast viimast commit'i | pärast kohtumist VPN-i kaudu; Argo CD Application alles pärast nelja rikke parandamist, muidu keeraks see rikked tagasi |
| Hindamise eeltingimus | tag `k07` `main`-i viimasel commit'il (ka boti commit) pärast merge'i ja GitHubis näha (`git ls-remote --tags origin`); automaatse hindaja kuus kontrolli on ka värskes kloonis `OK` ja Labori seisus on rida `lab-07` ([Esitamine](lab-8-esitamine.md)) | esimene tag kohtumise lõpus, lõputest HK6 samuti; hilisem töö uue commit'iga ja `git tag -f k07` |

## Moodulid

1. [Oma klaster](lab-1-oma-klaster.md): k3s01 koolitaja tehtud VM-is, kaks context'i, pod, Service ja PVC node'il, k3s peatatud ja workload töötab edasi.
2. [Namespace ja põhiobjektid](lab-2-namespace.md): `auth can-i`, kvoot, Deployment failist, Service, pod karantiini label'iga, ConfigMap ja Secret.
3. [Ressursid ja rikkeotsing](lab-3-ressursid.md): `exceeded quota`, LimitRange, `FailedScheduling`, OOMKilled, events, `kubectl debug`, kaks katkist pod'i.
4. [Labori seis klastris](lab-4-labori-seis.md): neli teenust, andmed PVC-l üle pod'i vahetuse, init-konteiner, Ingress, NetworkPolicy, rolling update ilma katkestuseta.
5. [Neli riket](lab-5-neli-riket.md): neli koolitaja tehtud riket diagnoositud väljast sisse liikudes, ajajoon ja parandus Gitist.
6. [Helm alused](lab-6-helm.md): `helm template`, values-fail, install, upgrade, rollback, käsitsi muudatus Helmi all ja ebaõnnestunud upgrade, mis võtab end ise tagasi.
7. [GitOps Argo CD-ga](lab-7-argocd.md): Application, CI kirjutab tag'i, selfHeal, prune, katkine YAML, halb commit ja revert, vigane kood main'is ilma katkestuseta tagasi.
8. [Esitamine](lab-8-esitamine.md): kuus testi ka värskes kloonis, tag `k07`, automaatse hindaja tulemus, lõputest HK6 ja üks samm oma töökohale.

Veaotsing: [Abi](abi.md).
