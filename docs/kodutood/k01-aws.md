---
tags:
  - AWS
  - EC2
  - Ansible
---

# 1. kohtumise kodutöö (valikuline) · AWS konto ja sama playbook EC2-l

**Eeldus:** 1. kohtumise labor (`training.yml`, `tools.yml`, `inventory.ini`) · **Esita:** `k01/aws.md` ja muudetud `training.yml`

Praktikumis seadistas playbook Proxmoxi masinaid. Kodutöös käivitad sama playbook'i AWS-i virtuaalmasinas (EC2) ja leiad, milline osa sellest eeldas meie laborit. Enne seda seadistad konto nii, et kulud oleksid kontrolli all.

**Enne alustamist:**

- Osas 1 lood konto, IAM-kasutaja ja kaks eelarvehäiret ning valid regiooniks **eu-north-1**.
- Üks t3.micro masin ja avalik IPv4-aadress maksavad kokku alla $0.05 tunnis.
- Lõpus kustutad ressursid ja käivitad `bash cloud/aws-leftovers.sh`, mis peab väljastama `TULEMUS: tasulisi jääke pole`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Seadistab AWS konto nii, et igapäevane töö ei käi root-kasutajaga ja kulu on jälgitav.
2. Lisab pilvemasina inventory'sse ja käivitab selle vastu sama playbook'i.
3. Leiab playbook'ist laborile omase eelduse ja teeb selle üldiseks.
4. Koristab pilveressursid ja kontrollib, et midagi tasulist ei jäänud.

---

## Osa 1 · Konto ja kulude kontroll

Selle osa teed **üks kord**, kõik järgmised kodutööd eeldavad seda.

### 1.1 Konto Free planiga

Registreeru [aws.amazon.com](https://aws.amazon.com/) kaudu. Plaani valikul vali **Free plan** (miks: [AWS-i reeglid](aws-reeglid.md#konto-ja-kulu)).

**Oodatav tulemus:** konsooli Billingu avalehel on kaart "Free plan" krediidi ja päevade jäägiga.
**Tõend:** kuvatõmmis krediidi kaardist (ilma maksekaardi andmeteta).

<!-- EKRAANIPILT: AWS konsool, Billing and Cost Management avaleht (https://console.aws.amazon.com/costmanagement/home), kohe pärast registreerimist. Pildil kaart "Free plan": krediidi jääk ($) ja päevade jääk. Konto ID ja e-post hägustada.
<figure markdown="span">
  ![Billing avalehe kaart Free plan krediidi ja päevade jäägiga](assets/kKT_k01-free-plan.png)
  <figcaption>Joonis 1. Free plani kaart Billingu avalehel.</figcaption>
</figure>
-->

### 1.2 Root-kasutaja kaitsmine

1. Lisa root-kasutajale MFA (Security credentials → Assign MFA, autentimisrakendus või turvavõti).
2. Ära loo root-kasutajale juurdepääsuvõtmeid (access key).
3. Loo IAM-is (IAM → Users) uus kasutaja, näiteks `admin`, anna talle konsooli ligipääs ja poliitika `AdministratorAccess` ning lisa ka sellele kasutajale MFA.
4. Logi välja ja logi sisse IAM-kasutajana (konto ID või alias ja kasutajanimi).

**Oodatav tulemus:** konsooli paremas ülanurgas on `admin @ <konto>`, mitte konto nimi.
**Tõend:** CloudShellis `aws sts get-caller-identity` väljund (Arn lõpeb `:user/admin`).

**Mõtle:** IAM-kasutajal on `AdministratorAccess`. Mille poolest on see siis root-kasutajast parem?
Mida saad IAM-kasutajaga teha, mida rootiga ei saa?

### 1.3 Eelarvehäired

Billing → [Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html) → Create budget:

1. Vali mall **Zero spend budget** ja lisa teavituseks oma e-posti aadress.
2. Loo teine eelarve: Monthly cost budget **$10**.

**Oodatav tulemus:** loodud on kaks eelarvet, mõlemal e-posti teavitus. Esimene zero-spend kiri tuleb tõenäoliselt juba mõne
tunni jooksul. See on oodatud ja näitab, et teavitus töötab.
**Tõend:** kuvatõmmis Budgetsi loendist.

??? info "Miks nii"
    Zero-spend budget ei arvesta krediiti: see teavitab esimesest tasulisest kasutusest, ka siis, kui krediit selle
    katab. $10 kuueelarve annab märku, kui midagi jäi tööle ja kulu kasvab.

<!-- EKRAANIPILT: AWS konsool, Billing and Cost Management → Budgets, pärast mõlema budgeti loomist. Nimekirjas kaks rida: zero-spend budget ja "Monthly cost budget" $10, mõlemal alert/teavitus seadistatud.
<figure markdown="span">
  ![Budgets nimekiri kahe eelarvega: zero spend ja kuu eelarve 10 dollarit](assets/kKT_k01-budgets.png)
  <figcaption>Joonis 2. Kaks eelarvet Budgets nimekirjas.</figcaption>
</figure>
-->

### 1.4 Region ja CloudShell

Vali paremast ülanurgast regiooniks **Europe (Stockholm) eu-north-1**. Ava CloudShell (ikoon ülaribal).

<!-- EKRAANIPILT: AWS konsooli ülariba ükskõik millisel teenuse lehel (nt EC2), regioonimenüü avatud ja valitud "Europe (Stockholm) eu-north-1"; CloudShelli ikoon ülaribal noolega märgitud.
<figure markdown="span">
  ![Konsooli ülariba: regioonimenüüs valitud Europe Stockholm ja CloudShelli ikoon](assets/kKT_k01-region-cloudshell.png)
  <figcaption>Joonis 3. Regiooni valik ja CloudShelli ikoon konsooli ülaribal.</figcaption>
</figure>
-->

```bash
aws configure get region
aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true \
    --query 'InstanceTypes[].InstanceType' --output text
```

**Oodatav tulemus:** `eu-north-1`; nimekirjas on `t3.micro` ja `t3.small`.
**Miks:** CloudShell on brauseris töötav terminal, kus `aws` on juba autenditud. Võtmeid pole vaja.

### 1.5 AWS CLI control node'il

Control node'il on vaja `aws` versiooni **2.32 või uuemat** (käsk `aws login`). Paigalda see AWS-i juhendi järgi
(`curl … awscli-exe-linux-x86_64.zip`, `sudo ./aws/install`). Ubuntu `apt` pakett on liiga vana.

```bash
aws --version
aws login --remote --profile labseis-login
```

`--remote` väljastab URL-i, mille avad oma arvuti brauseris, ja küsib koodi. Control node'il brauserit pole.

Lisa `~/.aws/config`-i profiil, millest saavad aru ka OpenTofu ja Ansible (need ei loe `aws login` sessiooni ise):

```ini
[profile labseis]
region = eu-north-1
credential_process = aws configure export-credentials --profile labseis-login --format process
```

```bash
export AWS_PROFILE=labseis       # pane ka ~/.bashrc-sse
aws sts get-caller-identity
```

**Oodatav tulemus:** sama Arn mis CloudShellis, `~/.aws/credentials` faili ei teki.
**Kui näed** `Unknown options: --remote` **või** `Invalid choice: 'login'`: CLI on vana, `which -a aws` näitab, kumb käivitub.

---

## Osa 2 · EC2 masin

### 2.1 Turvagrupp ainult sinu IP-aadressile

```bash
MYIP=$(curl -s https://checkip.amazonaws.com)/32
aws ec2 create-security-group --group-name ansible-k01 --description "K1 kodutoo"
aws ec2 authorize-security-group-ingress --group-name ansible-k01 --protocol tcp --port 22 --cidr "$MYIP"
```

**Miks:** kui port 22 on avatud kõigile (`0.0.0.0/0`), algavad võõrad sisselogimiskatsed juba mõne minuti jooksul.

### 2.2 Võtmepaar

Impordi control node'i avalik võti, privaatvõti jääb control node'ile:

```bash
aws ec2 import-key-pair --key-name control --public-key-material fileb://~/.ssh/id_ed25519.pub
```

### 2.3 EC2 Ubuntu 24.04

```bash
AMI=$(aws ssm get-parameter \
    --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
    --query Parameter.Value --output text)
aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
    --key-name control --security-groups ansible-k01 \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ansible-k01}]'
```

Mõne minuti pärast näitab `aws ec2 describe-instances` olekut `running` ja avalikku IP-d. Kontrolli: `ssh ubuntu@<avalik-ip> hostname`.

---

## Osa 3 · Sama playbook pilves

Lisa `inventory.ini`-sse uus grupp:

```ini
[aws]
ec2 ansible_host=<avalik-ip> ansible_user=ubuntu
```

Pilvemasinas on kasutaja `ubuntu`, mitte `kasutaja`, ja aadress on avalik IP, mitte nimi `~/.ssh/config`-ist. EC2-l on kasutajal `ubuntu` paroolita `sudo`, nagu ka labori masinates.

```bash
ansible aws -m ansible.builtin.ping
ansible-playbook tools.yml --limit aws
ansible-playbook training.yml --limit aws
```

**Ennusta enne käivitamist:** `tools.yml` töötab (Ubuntu ülesanded käivituvad, AlmaLinuxi omad jäetakse vahele). `training.yml` aga ebaõnnestub, sest EC2-l pole kasutajat `kasutaja` ja kausta `/home/kasutaja/automation-lab` ei saa luua.

See on eeldus, mis oli playbook'is peidus: **tee sõltus meie labori kasutajanimest**. Paranda `training.yml`-is mõlemad teed nii, et kodukaust võetakse masina faktist:

```yaml
path: "{{ ansible_facts['env']['HOME'] }}/automation-lab"
```

Käivita uuesti mõlema keskkonna vastu:

```bash
ansible-playbook training.yml --limit 'web01,aws'
ansible-playbook training.yml --limit 'web01,aws'
```

**Oodatav tulemus:** esimesel käivitusel on EC2 ülesannete olek `changed` ja web01 oma `ok`. Teisel käivitusel on mõlemal `changed=0`.

Kirjuta faili `k01/aws.md` kolm lauset: mis eeldus playbook'is oli, kuidas selle leidsid ja kuidas parandasid.

`{{ ... }}` on muutuja; neist räägime 2. kohtumisel.

---

## Koristus

```bash
aws ec2 terminate-instances --instance-ids <id>
aws ec2 wait instance-terminated --instance-ids <id>
aws ec2 delete-security-group --group-name ansible-k01
bash cloud/aws-leftovers.sh
```

Eemalda `inventory.ini`-st grupp `[aws]`. Võtmepaar (`control`) võib AWS-i jääda, see on tasuta.

## Valmis, kui

- `aws sts get-caller-identity` näitab IAM-kasutajat, root-kasutajal on MFA ja Budgetsis on kaks eelarvet kinnitatud e-posti teavitusega
- control node'il töötab `aws login`, `~/.aws/credentials` faili pole
- `training.yml` teine käivitus annab nii web01-l kui EC2-l `changed=0`
- `k01/aws.md` on repos
- `aws-leftovers.sh`: `TULEMUS: tasulisi jääke pole`

## Veaotsing

Ühised vead (sessioon, profiil, SG vana IP, vale region): [AWS-i reeglid](aws-reeglid.md#veaotsing).

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `aws login` puudub | CLI < 2.32 | paigalda AWS-i zip-ist, mitte apt-ist |
| `UNREACHABLE` EC2-le | SG-s pole sinu praegust IP-d või vale kasutaja | uuenda SG reeglit, `ansible_user=ubuntu` |
| `Permission denied` teel `/home/kasutaja` | tee sõltub labori kasutajast | vt Osa 3, kasuta fakti |
