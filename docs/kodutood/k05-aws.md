---
tags:
  - AWS
  - GitHub Actions
  - ECR
---

# 5. kohtumise kodutöö · GitHub Actions: ECR push ja deploy kinnitusega

**Eeldus:** 5. kohtumise labor (`ci.yml`: jobid, `needs`, secrets, `environment`), [3. kohtumise kodutöö](k03-aws.md) (ECR repo `labori-seis`, IAM roll `labseis-ec2-ecr`, Compose EC2-l) · **Esita:** `.github/workflows/deploy-aws.yml`, `cloud/k05-aws/ecr-push.json`

3. kohtumise kodutöös lükkasid image'i ECR-i käsitsi ja käivitasid Compose'i EC2-l ise. Nüüd teeb sama pipeline, mis vajab AWS-i
võtit väljaspool sinu masinat. Võti peab olema nii kitsas, et selle lekkimine ei maksa midagi, ja deploy ootab sinu
kinnitust.

**Enne alustamist:**

- `aws configure get region` → `eu-north-1`; tunnipõhine kulu: 1 × t3.small + avalik IPv4 (~$0.10), Actions minutid GitHubis.
- Eelarvehäired (zero spend, $10) on alles.
- `aws sts get-caller-identity` → Arn lõpeb `:user/…`, mitte `:root`. Pikaajaline võti tekib ainult CI kasutajale `gha-labseis`.
- Lõpus võti kustutatakse, koristus ja `bash cloud/aws-leftovers.sh`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Loob IAM kasutaja, kelle võti lubab ainult image'i lükkamist ühte repo'sse.
2. Kirjutab workflow, mis lükkab image'i ECR-i commit'i sildiga ja deploy'b selle alles pärast käsitsi kinnitust (`environment`).
3. Kontrollib deploy tulemust masinast (`/version` = commit).

---

## Osa 1 · Võti, mis lekkides ei maksa midagi

Paljud juhendid annavad CI kasutajale `AmazonEC2ContainerRegistryFullAccess`. Sellega saab kustutada kõik repod. Teeme kitsama.

1. IAM → Users → `gha-labseis`, **ilma** konsooli ligipääsuta.
2. Inline policy `cloud/k05-aws/ecr-push.json` ([ECR policy näited](https://docs.aws.amazon.com/AmazonECR/latest/userguide/security_iam_id-based-policy-examples.html)):
   `ecr:GetAuthorizationToken` ressursil `*`, push'i tegevused
   (`BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`, `PutImage`)
   ainult sinu repo ARN-il.
3. Access key → kopeeri otse GitHubi (Settings → Secrets and variables → Actions):
   secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`; variables `AWS_REGION`, `ECR_REPOSITORY` (repositoryUri).

**Oodatav tulemus:** `aws iam simulate-principal-policy` (või IAM → Policy simulator) näitab, et `ecr:DeleteRepository` on `denied`.
**Miks `GetAuthorizationToken` on `*`:** see tegevus ei toeta ressursi piirangut, token kehtib kogu registry'le, mitte ühele repole.
**Tõend:** policy JSON Gitis (konto ID asemel võib olla kohatäide), simulaatori screenshot.

<!-- EKRAANIPILT: AWS konsool, IAM → Policy simulator (https://policysim.aws.amazon.com/), vasakul valitud kasutaja gha-labseis ja tema inline policy, teenus Amazon ECR, valitud tegevused PutImage, InitiateLayerUpload ja DeleteRepository, pärast "Run Simulation". Tulemuste tabelis PutImage/InitiateLayerUpload "allowed" ja DeleteRepository "denied". Konto ID hägustada.
<figure markdown="span">
  ![IAM Policy simulator: gha-labseis kasutajale PutImage lubatud, DeleteRepository keelatud](assets/kKT_k05-policy-simulator.png)
  <figcaption>Joonis 1. Policy simulaator: push lubatud, repo kustutamine keelatud.</figcaption>
</figure>
-->

**Ära laadi** faili `gha-labseis_accessKeys.csv` repo kausta. Kui laadisid, kustuta see ja kontrolli `git status`.

## Osa 2 · Image ECR-i

Loo `.github/workflows/deploy-aws.yml`: trigger `workflow_dispatch` ja tag'id `v*`, `permissions: contents: read`.

Job `image`:

1. `actions/checkout@v5`
2. [`aws-actions/configure-aws-credentials@v6`](https://github.com/aws-actions/configure-aws-credentials) secrets'ide ja `vars.AWS_REGION`-iga
3. `aws ecr get-login-password` → `docker login` (sama mis 3. kohtumisel käsitsi)
4. `docker build` + `docker push` sildiga `${GITHUB_SHA::7}`
5. image nimi job'i `outputs`-i, et deploy job teaks, mida tõmmata

```bash
actionlint .github/workflows/deploy-aws.yml
gh workflow run deploy-aws.yml
```

**Oodatav tulemus:** ECR-is on uus tag = commit'i lühike SHA. Job summary's on image nimi.
**Kui näed** `AccessDeniedException … ecr:InitiateLayerUpload`: repo ARN-is on vale region või konto ID.

**Mõtle:** see võti on GitHubis seni, kuni sa selle kustutad. Mis on OIDC eelis (IS2) just selle koha pealt?

## Osa 3 · Deploy, mis ootab sind

1. Settings → [Environments](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment)
   → `aws`, **Required reviewers**: sina ise. Variable `EC2_HOST`, secret `EC2_SSH_KEY`
   (eraldi deploy-võti, mitte sinu isiklik: `ssh-keygen -t ed25519 -f ~/.ssh/gha-deploy -N ''`, avalik pool EC2 `authorized_keys`-i).
2. Job `deploy`: `needs: image`, `environment: aws`. Sammud: SSH võti faili (`chmod 600`), `ssh-keyscan` → `known_hosts`,
   `ssh ubuntu@$EC2_HOST "cd … && APP_IMAGE=… docker compose pull app01 && docker compose up -d --no-build app01"`.
3. Viimane samm: oota tsüklis, kuni `ssh … curl -s http://localhost:8080/version` sisaldab `${GITHUB_SHA::7}`, muidu `exit 1`.

EC2 SG: port 22 peab olema GitHubi runner'ile kättesaadav. Kodutöö jaoks on lihtsaim 22 `0.0.0.0/0` **ainult deploy-võtmega**
ja ainult kodutöö ajaks, siis tagasi `/32`. Parem variant on lisaülesandes.

**Oodatav tulemus:** workflow peatub kollase "Waiting for review" juures. Pärast "Approve" uueneb app01, `/version` näitab uut commit'i.
**Miks:** `environment` lisab kinnitussammu, mille taga on ka selle keskkonna saladused. Ilma kinnituseta ei näe job `EC2_SSH_KEY`-d.
**Tõend:** Actions jooksu screenshot (image ✓, deploy ootab → ✓) + `/version` vastus.

**Kui `ssh` annab** `Host key verification failed`: `ssh-keyscan` töötas vale hosti vastu või IP muutus (EC2 restart annab uue avaliku IP).

---

## Koristus

1. IAM → `gha-labseis` → Access key → **Deactivate**, siis **Delete**. Või `aws iam delete-access-key --user-name gha-labseis --access-key-id …`.
2. Eemalda GitHubist secrets `AWS_*` ja `EC2_SSH_KEY`.
3. EC2 terminate, SG tagasi `/32` või kustuta. `bash cloud/aws-leftovers.sh` (INFO: ECR repo).

## Valmis, kui

- policy simulaator: `PutImage` lubatud, `ecr:DeleteRepository` `denied`
- `aws ecr list-images --repository-name labori-seis` näitab tag'e, mis on commit'i lühikesed SHA-d
- deploy job käivitus alles pärast "Approve" ja `curl -s http://<EC2>:8080/version` sisaldab sama SHA-d
- `grep -nE 'AKIA|[0-9]{12}' .github/workflows/deploy-aws.yml` on tühi (ainult `secrets.*` ja `vars.*`)
- `aws iam list-access-keys --user-name gha-labseis` on tühi, `aws-leftovers.sh`: `TULEMUS: tasulisi jääke pole`

## Lisaülesanne

Asenda SSH deploy **self-hosted runner'iga EC2-l** (label `aws`): `deploy` job töötab masinas endas ja port 22 pole
GitHubile vaja. Runner'i registreerimise token aegub tunniga, runner ise jääb. Mis muutub turvamudelis: kes saab nüüd
sinu EC2-l käske käivitada?

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `Credentials could not be loaded` | secretite nimed ei klapi workflow'iga | paranda nimed |
| deploy ei oota kinnitust | environment'i nimi workflow'is ≠ nimi Settings → Environments all | pane nimed samaks |
| `pull access denied` EC2-l | 3. kohtumise credential helper või instance profile puudub | vt 3. kohtumise kodutöö osa 2 |
| `/version` vana SHA | `up` ei loonud konteinerit uuesti: `APP_IMAGE` ei jõudnud `ssh` käsku | kontrolli jutumärke |

Ühised vead: [AWS-i reeglid](aws-reeglid.md#veaotsing).
