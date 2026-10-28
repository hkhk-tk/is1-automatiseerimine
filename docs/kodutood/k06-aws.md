---
tags:
  - AWS
  - Jenkins
  - ECR
---

# 6. kohtumise kodutöö · Jenkins: image ECR-i ja deploy EC2-le

**Eeldus:** 6. kohtumise labor (`k06-jenkins/Jenkinsfile`, sinu control node on Jenkinsi agent label'iga = GitHubi kasutajanimi), [3.](k03-aws.md) ja [5. kohtumise kodutöö](k05-aws.md) (ECR repo, push-only IAM kasutaja, EC2 Compose'iga) · **Esita:** `k06-jenkins/Jenkinsfile` (uued etapid), `cloud/k06-aws/`

5. kohtumisel tegi GitHub Actions push'i ja deploy'd. Nüüd teeb sama koolitaja jagatud Jenkins, mille kettale ei tohi sinu
AWS-i võti sattuda.

**Enne alustamist:**

- `aws configure get region` → `eu-north-1`; tunnipõhine kulu: 1 × t3.small + avalik IPv4 (~$0.10), Fargate osaga + 1 task (~$0.025/h).
- Eelarvehäired (zero spend, $10) on alles.
- `aws sts get-caller-identity` → Arn lõpeb `:user/…`, mitte `:root`. Pikaajaline võti ainult `gha-labseis`-ile, ainult ECR push.
- Lõpus võti kustutatakse, koristus ja `bash cloud/aws-leftovers.sh`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Lisab Jenkinsfile'i etapid, mis lükkavad image'i ECR-i build numbri ja commit'i sildiga, ja hoiab AWS-i võtit agendi masinas, mitte jagatud Jenkinsis.
2. Deploy'b image'i EC2-le kinnitusega ja kontrollib tulemust pipeline'is.
3. Võrdleb Jenkinsi ja GitHub Actionsi lahendust samale ülesandele.

---

## Osa 1 · Kus võti asub

Koolitaja Jenkins on jagatud. Kui paned AWS-i võtme Jenkinsi credential'iks, on see Jenkinsi kettal ja administraatori
käes. Sinu pipeline töötab aga **sinu control node'il** (agent), seega võib võti olla seal.

Control node'il, agendi kasutaja all:

```bash
aws configure --profile labseis-ecr     # gha-labseis kasutaja UUS võti (K5 oma kustutasid)
aws --profile labseis-ecr ecr describe-repositories   # AccessDenied on õige: policy lubab ainult push'i
```

**Oodatav tulemus:** `~/.aws/credentials`-is on profiil `labseis-ecr`, Jenkinsis pole AWS-i credential'it.
**Miks:** kui jagatud Jenkins kompromiteeritakse, ei saa ründaja sinu AWS-i võtit. Hind: pipeline töötab ainult sinu agendil.

**Mõtle:** levinud lahendus kasutab `docker.withRegistry(…, 'ecr:region:credId')` ja Jenkinsi pluginat. Millal
on see parem kui agendi profiil? (Vihje: mitu agenti, autoskaleeruvad agendid.)

## Osa 2 · Etapp "Push ECR"

Lisa Jenkinsfile'i pärast olemasolevat Docker image'i etappi uus `stage('Push ECR')`:

- `environment` plokis `AWS_PROFILE = 'labseis-ecr'`, `ECR = '<repositoryUri>'`;
- `sh` sammus: login ([`aws ecr get-login-password`](https://docs.aws.amazon.com/cli/latest/reference/ecr/get-login-password.html)
  → `docker login`), `docker tag` Docker etapi image'ist `labori-seis:$ART_VERSION` kaks ECR-i tag'i (`$ART_VERSION` ja
  `${GIT_COMMIT:0:7}`), `docker push` mõlemale;
- `post { always { … } }`: `docker rmi` kohalikud sildid, et agendi ketas ei täituks (muidu tuleb "no space left on device").

Vihje: `${GIT_COMMIT:0:7}` on Bashi süntaks. Jenkinsi `sh '...'` töötab `/bin/sh`-iga. Lisa `sh` sammu algusesse
`#!/bin/bash` või kasuta `sh(script: …, label: …)` koos `bash -c`-ga.

**Oodatav tulemus:** ECR-is on kaks uut tag'i: build number ja SHA. Jenkinsfile'is pole konto ID-d mujal kui muutujas `ECR`.
**Tõend:** Jenkinsi stage view screenshot + `aws ecr list-images --repository-name labori-seis` väljund.

## Osa 3 · Etapp "Deploy AWS"

1. [`input`](https://www.jenkins.io/doc/book/pipeline/syntax/) samm: "Deploy EC2-le?" (sama mõte mis 5. kohtumise `environment`), `timeout` 10 min.
2. `sshagent` või lihtsalt `ssh` agendi enda võtmega: `docker compose pull app01 && docker compose up -d --no-build app01`
   EC2-l, `APP_IMAGE` = SHA tag.
3. Kontroll: tsükkel, kuni `/version` sisaldab commit'i, muidu `error()`.

Deploy etapp käivitub ainult `main` harul (`when { branch 'main' }`).

**Oodatav tulemus:** build peatub `input` juures. Pärast "Proceed" on `/version` uus.
**Tõend:** konsoolilogi viimased read.

**Mõtle:** sama töö on nüüd tehtud kahes kohas (5. kohtumisel Actions, 6. kohtumisel Jenkins). Kirjuta issue'sse 3 rida: mida Jenkins
tegi paremini, mida Actions, kumma valiksid oma tööl ja miks.

---

## Edasijõudnu · ECS Fargate ilma ALB-ta

1. ECS → klaster `labseis` (Fargate, ilma EC2-ta).
2. Task definition: 0.5 vCPU / 1 GB, image ECR-ist SHA sildiga, keskkonnamuutujad nagu README-s (`DB_HOST` = 3. kohtumise EC2
   privaatne IP; db, mq ja cache jäävad EC2-le), port 8080.
3. Service: desired 1, avalik IP sees, **Load balancing: None**.
4. Jenkinsi deploy: uus task definition'i revisjon uue image'iga (`aws ecs register-task-definition`) +
   [`aws ecs update-service`](https://docs.aws.amazon.com/cli/latest/reference/ecs/update-service.html) `--task-definition <uus>`.
   Võti vajab selleks lisaõigusi (eraldi policy, `ecs:RegisterTaskDefinition`, `ecs:UpdateService`, `iam:PassRole` task rollile).

**Miks uus revisjon, mitte `--force-new-deployment` `latest` sildiga:** revisjoni järgi näed, mis image töötab, ja saad
minna tagasi eelmisele revisjonile.

**ECS konsooli wizard pakub vaikimisi ALB-d** (~$0.024/h + LCU). Vali "None". Kui ALB tekkis, kustuta ALB **ja** target group.

<!-- EKRAANIPILT: AWS konsool, ECS → Clusters → labseis → Services → Create, jaotis "Load balancing" lahti, valitud "None" (noolega märgitud); ülal näha Compute "Fargate" ja Desired tasks 1.
<figure markdown="span">
  ![ECS teenuse loomise vorm: Fargate, desired tasks 1, Load balancing valikuks None](assets/kKT_k06-ecs-no-alb.png)
  <figcaption>Joonis 1. ECS teenus ilma load balancerita.</figcaption>
</figure>
-->

**Koristus:** service desired 0 → delete service → delete cluster. Task definition'i revisjonid võivad jääda (tasuta).

## Koristus

1. EC2 terminate, SG kustuta.
2. Control node'il eemalda `labseis-ecr` võti (profiil `~/.aws/credentials`-ist välja), IAM-is kustuta võti.
3. `bash cloud/aws-leftovers.sh` (ECS teenust, ALB-d ega target group'i ei tohi olla).

## Valmis, kui

- Jenkinsi credential'ite seas pole AWS-i võtit ja `grep -nE 'AKIA|aws_secret' k06-jenkins/Jenkinsfile` on tühi
- `aws ecr list-images --repository-name labori-seis` näitab build numbri ja SHA tag'i
- deploy käivitus pärast `input` kinnitust ja `/version` sisaldab sama SHA-d
- `docker images | wc -l` agendil on pärast build'i sama mis enne
- `aws iam list-access-keys --user-name gha-labseis` on tühi, `aws-leftovers.sh`: `TULEMUS: tasulisi jääke pole`

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `Unable to locate credentials` pipeline'is | agent töötab teise kasutajana kui see, kellel on `~/.aws` | `sh 'id; echo $HOME'` |
| `Bad substitution` | `/bin/sh`, mitte bash | vt osa 2 vihje |
| `permission denied … docker.sock` agendil | agendi kasutaja pole `docker` grupis | lisa gruppi, taaskäivita agent |
| ECS task kohe `STOPPED` | tavaliselt DB_HOST või SG | CloudWatchi logid; EC2 SG peab lubama 3306/5672/11211 task'i SG-st |

Ühised vead: [AWS-i reeglid](aws-reeglid.md#veaotsing).
