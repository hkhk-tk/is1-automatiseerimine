---
tags:
  - AWS
  - Kubernetes
  - k3s
---

# 7. kohtumise kodutöö · k3s EC2-l, samad manifestid

**Eeldus:** 7. kohtumise labor (`k07-k8s/` manifestid ilma namespace'ita, Secret luuakse käsuga, Ingress Traefikuga, rolling update + rollback), [1. kohtumise kodutöö](k01-aws.md) · **Esita:** `cloud/k07-aws/user-data.sh`

Klassis deploy'd `k07-k8s/` koolitaja klastrisse oma namespace'i kitsaste õigustega. Siin on klaster sinu oma,
ühel EC2-l, ja sina oled cluster-admin. Manifestid jäävad samaks, muutuvad ainult keskkonna osad.

**Enne alustamist:**

- `aws configure get region` → `eu-north-1`; tunnipõhine kulu: 1 × t3.small + avalik IPv4 (~$0.10), EKS-i ei looda.
- Eelarvehäired (zero spend, $10) on alles.
- `aws sts get-caller-identity` → Arn lõpeb `:user/…`, mitte `:root`.
- Lõpus koristus, PAT kustutatakse ja `bash cloud/aws-leftovers.sh`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Paigaldab ühe node'iga k3s klastri EC2-le ja haldab seda control node'ilt.
2. Deploy'b samad manifestid muutmata ja eristab, mis on keskkonna osa (namespace, Secret, pull secret, Ingressi host).
3. Teeb rolling update'i ja rollback'i teises klastris.

---

## Osa 1 · Klaster

EC2 nagu 1. kohtumise kodutöös: Ubuntu 24.04, **t3.small** (2 GB), silt `Name=k3s-k07`. SG: 22 ja 6443 sinu IP-st, 80 kõigile.

User-data (`cloud/k07-aws/user-data.sh`): k3s [ametliku install-skriptiga](https://docs.k3s.io/quick-start). Lisa
`INSTALL_K3S_EXEC` valik [`--tls-san <avalik IP>`](https://docs.k3s.io/cli/server), muidu ei klapi API sertifikaat,
kui control node'ist ühendud. Avaliku IP saad user-datas metaandmete teenusest
([IMDSv2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html): kõigepealt
token `PUT /latest/api/token`, siis `GET /latest/meta-data/public-ipv4`).

**Oodatav tulemus:** `ssh ubuntu@<ip> sudo k3s kubectl get nodes` → `Ready`.
**Kui node jääb `NotReady` või pod'id `Pending` mälu tõttu:** t3.micro (1 GB) on liiga väike. Kontrolli `free -m`.

??? info "Miks nii"
    k3s, mitte EKS: EKS-i control plane maksab $0.10/h ehk ~$73 kuus ka ilma ühegi node'ita, lisaks node'id ja
    tavaliselt NAT ning load balancer. Kodutöö õpiväljund (samad manifestid teises klastris) ei vaja hallatud control
    plane'i.

### 1.1 kubeconfig control node'ile

Kopeeri `/etc/rancher/k3s/k3s.yaml` control node'ile `~/.kube/k3s-aws.yaml`, asenda `127.0.0.1` avaliku IP-ga.

```bash
export KUBECONFIG=~/.kube/k3s-aws.yaml
kubectl get nodes
```

**Miks eraldi fail:** klassi kubeconfig (koolitaja klaster, sinu namespace) jääb puutumata. `KUBECONFIG` valib, millist
klastrit käsud puudutavad. Selles failis on **admin** võti: `chmod 600`, Giti ei pane (`.gitignore`: `k3s.yaml`, `kubeconfig*`).

**Mõtle:** klassis andis koolitaja sulle namespace'i ja kitsad õigused. Siin oled cluster-admin. Mida see muudab
selles, kuidas sa järgmise sammu teed?

## Osa 2 · Sama kood, uus keskkond

Klassi klastris tuli namespace kubeconfig'ist. Siin lood selle ise ja paned kontekstile vaikimisi:

```bash
kubectl create namespace labseis
kubectl config set-context --current --namespace labseis
```

Keskkonna osad, mida manifestides **ei ole**:

| Mis | Klassis | Siin |
|---|---|---|
| namespace | kubeconfig'is | `set-context --namespace` |
| Secret (paroolid) | `kubectl create secret` | sama käsk |
| image pull | klassi registry / public | ghcr pakett on privaatne → pull secret |
| Ingressi host | `labori-seis-<github>.lab.hkhk.ee` | `labori-seis.<avalik-ip>.sslip.io` ([sslip.io](https://sslip.io/)) |

*Tabel 1. Mis erineb klassi klastri ja EC2 k3s-i vahel.*

[Pull secret ServiceAccount'ile](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account),
ilma manifeste muutmata:

```bash
kubectl create secret docker-registry ghcr --docker-server=ghcr.io \
    --docker-username=<github> --docker-password=<PAT, õigus read:packages>
kubectl patch serviceaccount default -p '{"imagePullSecrets":[{"name":"ghcr"}]}'
```

Siis `kubectl apply -f k07-k8s/` ja Ingressi host: `kubectl patch ingress …` (või kustomize overlay `cloud/k07-aws/`, kui tahad seda Gitis hoida).

**Oodatav tulemus:** `kubectl get pods` kõik `Running`, brauseris `http://labori-seis.<ip>.sslip.io/` → Labori seis.
**Tõend:** `kubectl get all` väljund + brauseri screenshot.

**Kui pod on `ImagePullBackOff`:** `kubectl describe pod` → `401 Unauthorized` = pull secret puudub või PAT-il pole `read:packages`.
**Kui Traefik annab 404:** Ingressi host ei klapi brauseri aadressiga, `kubectl get ingress` näitab hosti.

**Mõtle:** tabelis on neli asja, mis klassis ja pilves erinevad. IS2-s tuleb kolmas keskkond. Kuhu paneksid need neli
väärtust, et `k07-k8s/` jääks ühiseks? (Vihje: kustomize overlay, Helm values.)

## Osa 3 · Rolling update ja rollback

1. `kubectl set image deployment/app01 labori-seis=<uus tag>` (näiteks 5. kohtumise kodutöö SHA tag või uus tag).
2. `kubectl rollout status deployment/app01`, `/version` brauseris.
3. Tee meelega vigane tag (`:olematu`). Vaata `kubectl get pods` ja `rollout status`.
4. `kubectl rollout undo deployment/app01`, `kubectl rollout history deployment/app01`.

**Oodatav tulemus:** vigase sildi ajal teenindab vana pod edasi (readinessProbe), pärast `undo` on kõik `Running`.
**Miks:** kui replicas on 1, hoiab rolling update vana pod'i seni, kuni uus on Ready. Vigane image ei saa kunagi Ready'ks.
**Tõend:** `rollout history` väljund.

---

## Koristus

```bash
unset KUBECONFIG
aws ec2 terminate-instances --instance-ids <id>
rm ~/.kube/k3s-aws.yaml
bash cloud/aws-leftovers.sh
```

Kustuta GitHubis PAT, mida pull secret kasutas (Settings → Developer settings → Tokens).

## Valmis, kui

- `git diff --stat k07-k8s/` on tühi, keskkonna erinevused on käskudes või `cloud/k07-aws/`-s
- `curl -s -o /dev/null -w '%{http_code}' http://labori-seis.<ip>.sslip.io/` andis `200`
- vigase tag'i ajal vastas `/version` edasi ja `kubectl rollout history deployment/app01` näitab `undo` järel uut revisjoni
- `git ls-files | grep -E 'kubeconfig|k3s.yaml'` on tühi ja PAT on GitHubis kustutatud
- `aws-leftovers.sh`: `TULEMUS: tasulisi jääke pole`

## Lisaülesanne

Pane Argo CD samasse k3s-i (`kubectl create namespace argocd` + ametlik install manifest) ja lase tal sünkroniseerida
`k07-k8s/` sinu repost. t3.small mälu jääb kitsaks: jälgi `kubectl top nodes`. Mis juhtub, kui muudad
replicas'e käsitsi `kubectl scale`-iga?

## Veaotsing

Ühised vead (SG port sinu IP-le, sessioon): [AWS-i reeglid](aws-reeglid.md#veaotsing).

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `x509: certificate is valid for 127.0.0.1, … not <ip>` | `--tls-san` puudus | `/etc/rancher/k3s/config.yaml`-i `tls-san: [<ip>]`, `systemctl restart k3s` |
| `connection refused :6443` | SG-s pole 6443 sinu IP-le | lisa reegel |
| pod'id `Pending`, `Insufficient memory` | t3.small piir | vähenda `resources.requests` overlay'ga või kasuta t3.small asemel kaht masinat (agent join) |
| pärast EC2 restarti ei tööta kubeconfig | avalik IP muutus | uuenda kubeconfig'i (Elastic IP maksab ka seisvana) |
