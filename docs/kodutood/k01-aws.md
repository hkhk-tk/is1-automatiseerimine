---
tags:
  - AWS
  - EC2
  - Bash
---

# 1. kohtumise kodutöö · AWS konto ja sama `websetup.sh` EC2-l

**Eeldus:** 1. kohtumise labor (`websetup.sh` distro tuvastuse ja argumendiga, `check.sh`, `labseis-report.sh`) · **Esita:** `cloud/k01-aws/check-aws.sh`

Sinu `websetup.sh` töötab Proxmoxis, kui käivitad selle SSH-ga. Pilves pole sinu terminali: masina loob API ja skripti
käivitab cloud-init root'ina esimesel boodil. Enne seda on vaja kontot, mis ei tee rahalisi üllatusi.

**Enne alustamist:**

- Osa 1 loob konto, IAM-kasutaja, kaks eelarvehäiret ja regiooni **eu-north-1**.
- Tunnipõhine kulu: 1 × t3.micro + avalik IPv4, kokku alla $0.05.
- Lõpus koristus ja `bash cloud/aws-leftovers.sh` → `TULEMUS: tasulisi jääke pole`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Seadistab AWS konto nii, et igapäevane töö ei käi root-kasutajaga ja kulu on jälgitav.
2. Käivitab sama Bashi skripti EC2 user-datana, leiab selle logist üles ja võrdleb Proxmoxi cloud-initiga.
3. Kontrollib ja koristab pilveressursid skriptiga.

---

## Osa 1 · Konto, mis ei tee üllatusi

Selle osa teed **üks kord**, kõik järgmised kodutööd eeldavad seda.

### 1.1 Konto Free planiga

Registreeru [aws.amazon.com](https://aws.amazon.com/) kaudu. Plaani valikul vali **Free plan** (miks: [AWS-i reeglid](aws-reeglid.md#konto-ja-kulu)).

**Oodatav tulemus:** konsoolis Billing → avalehel on kaart "Free plan" krediidi ja päevade jäägiga.
**Tõend:** screenshot krediidi kaardist (ilma kaardi andmeteta).

<!-- EKRAANIPILT: AWS konsool, Billing and Cost Management avaleht (https://console.aws.amazon.com/costmanagement/home), kohe pärast registreerimist. Pildil kaart "Free plan": krediidi jääk ($) ja päevade jääk. Konto ID ja e-post hägustada.
<figure markdown="span">
  ![Billing avalehe kaart Free plan krediidi ja päevade jäägiga](assets/kKT_k01-free-plan.png)
  <figcaption>Joonis 1. Free plani kaart Billingu avalehel.</figcaption>
</figure>
-->

### 1.2 Root lukku

1. Root-kasutajale MFA (Security credentials → Assign MFA, autentimisrakendus või võti).
2. Root-kasutajale access key'd **ei** loo.
3. IAM → Users → uus kasutaja (nt `admin`), konsooli ligipääs, policy `AdministratorAccess`, sellele kasutajale samuti MFA.
4. Logi välja ja logi sisse IAM-kasutajana (konto ID või alias + kasutajanimi).

**Oodatav tulemus:** paremal üleval on `admin @ <konto>`, mitte konto nimi.
**Tõend:** CloudShellis `aws sts get-caller-identity` väljund (Arn lõpeb `:user/admin`).

**Mõtle:** IAM-kasutajal on `AdministratorAccess`. Mille poolest on see siis root-kasutajast parem?
Mida saad IAM-kasutajaga teha, mida rootiga ei saa?

### 1.3 Kulude valve

Billing → [Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html) → Create budget:

1. Mall **Zero spend budget**, e-post sinu aadressile.
2. Teine budget: Monthly cost budget **$10**.

**Oodatav tulemus:** kaks budgetit, mõlemal e-posti teavitus. Esimene zero-spend kiri tuleb tõenäoliselt juba mõne
tunni jooksul. See on oodatud ja näitab, et valve töötab.
**Tõend:** Budgets nimekirja screenshot.

??? info "Miks nii"
    Zero-spend budget ei arvesta krediiti: ta teavitab esimesest tasulisest kasutusest, ka siis, kui krediit selle
    katab. $10 kuueelarve annab märku, kui midagi jäi tööle ja kulu kasvab.

<!-- EKRAANIPILT: AWS konsool, Billing and Cost Management → Budgets, pärast mõlema budgeti loomist. Nimekirjas kaks rida: zero-spend budget ja "Monthly cost budget" $10, mõlemal alert/teavitus seadistatud.
<figure markdown="span">
  ![Budgets nimekiri kahe eelarvega: zero spend ja kuu eelarve 10 dollarit](assets/kKT_k01-budgets.png)
  <figcaption>Joonis 2. Kaks eelarvet Budgets nimekirjas.</figcaption>
</figure>
-->

### 1.4 Region ja CloudShell

Vali paremalt ülevalt **Europe (Stockholm) eu-north-1**. Ava CloudShell (ikoon ülaribal).

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
**Miks:** CloudShell on terminal brauseris, kus `aws` on juba sisse logitud. Võtmeid pole vaja.

### 1.5 AWS CLI control node'il

Control node'il on vaja `aws` versiooni **2.32 või uuemat** (käsk `aws login`). Paigalda see AWS-i juhendi järgi
(`curl … awscli-exe-linux-x86_64.zip`, `sudo ./aws/install`). Ubuntu `apt` pakett on liiga vana.

```bash
aws --version
aws login --remote --profile labseis-login
```

`--remote` väljastab URL-i, mille avad oma arvuti brauseris, ja küsib koodi. Control node'il brauserit pole.

Lisa `~/.aws/config`-i profiil, millest saavad aru ka OpenTofu ja Ansible (need ei oska `aws login` sessiooni ise lugeda):

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

## Osa 2 · Sama skript, käivitab cloud-init

Proxmoxis käivitasid `websetup.sh`-i SSH-ga. EC2-l annad selle masina loomisel kaasa
**[user-data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)**na: cloud-init käivitab selle
esimesel boodil root'ina. Mehhanism on sama mis Proxmoxi mallides, ainult andmeallikas on teine.

### 2.1 SG ainult sinu IP-le

```bash
MYIP=$(curl -s https://checkip.amazonaws.com)/32
aws ec2 create-security-group --group-name labseis-k01 --description "K1 kodutoo"
```

Lisa reeglid 22 ja 80 ainult `$MYIP`-st (`aws ec2 authorize-security-group-ingress … --cidr "$MYIP"`). Käsu
argumendid leiad `aws ec2 authorize-security-group-ingress help`-ist.

**Miks:** `0.0.0.0/0` pordil 22 saab mõne minutiga esimesed sisselogimiskatsed. Kui tahad neid näha, vaata hiljem
EC2-l `journalctl -u ssh`.

### 2.2 Võtmepaar

Impordi oma olemasolev avalik võti (`aws ec2 import-key-pair --key-name labseis --public-key-material fileb://~/.ssh/id_ed25519.pub`).
Privaatvõti jääb control node'ile, AWS-ist `.pem` faili alla ei laadita.

### 2.3 EC2 Ubuntu 24.04 + user-data

Küsi Ubuntu AMI ID [SSM-ist](https://documentation.ubuntu.com/aws/aws-how-to/instances/find-ubuntu-images/), siis on see alati värske:

```bash
AMI=$(aws ssm get-parameter \
    --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
    --query Parameter.Value --output text)
```

Käivita `aws ec2 run-instances` nii, et:

- `--image-id "$AMI"`, `--instance-type t3.micro`, sinu võti ja SG;
- `--user-data file://k01-bash/websetup.sh`;
- `--tag-specifications` annab sildid `Name=web-k01` ja `Project=labseis`.

**Oodatav tulemus:** käsk tagastab `InstanceId`. Mõne minuti pärast näitab `aws ec2 describe-instances`
olekut `running` ja avalikku IP-d.

**Kui valisid vaike-AMI (Amazon Linux):** `websetup.sh` lõpetab veaga `Tundmatu distro: amzn`. See on õige käitumine,
skript ei arva. Vaata lisaülesannet. (Koolitaja lahenduses `lahendus/k01` on `amzn` haru juba olemas.)

### 2.4 Kas skript käivitus?

```bash
ssh ubuntu@<avalik-ip> 'cloud-init status --long; sudo tail -20 /var/log/cloud-init-output.log'
```

Ava brauseris `http://<avalik-ip>/`.

**Oodatav tulemus:** `status: done`, logi lõpus on sinu skripti viimane rida (`… töötab, mall …`), brauseris mall.
**Tõend:** brauseri screenshot + logi viimane rida issue kommentaaris.

**Kui [`cloud-init status`](https://cloudinit.readthedocs.io/en/latest/reference/cli.html#status) jääb olekusse
`running` ja leht ei avane:** kui sinu `websetup.sh` ootab alguses `cloud-init status --wait`, ootab skript iseennast
(user-data on cloud-initi osa). Lisa ootele tingimus: oota ainult siis, kui skripti ei käivita cloud-init ise
(nt `[[ "$(readlink -f "$0")" == /var/lib/cloud/* ]]`).

**Mõtle:** Proxmoxis käivitas skripti kasutaja `kasutaja` `sudo`-ga, siin käivitab root ilma terminalita. Mis sinu
skriptis eeldab interaktiivset terminali või kasutaja kodukausta? Mis juhtuks, kui `apt` midagi küsiks?

---

## Osa 3 · Kontroll control node'ist

Labori seis töötab sinu Proxmoxi web01-l, VPN-i taga. EC2 sinna ei näe, aga control node näeb mõlemat.

Kirjuta `cloud/k01-aws/check-aws.sh`: argument on EC2 avalik IP, skript kontrollib `curl`-iga HTTP koodi pordil 80
ja saadab tulemuse `labseis-report.sh`-iga laborisse `aws-k01` (check `web`, OK või FAIL).

**Oodatav tulemus:** Labori seisus on sinu lehel rida `aws-k01 web OK`.
**Miks:** sama `labseis-report.sh` töötab mis tahes masina kohta. Kontrollija ja kontrollitav ei pea olema samas võrgus.
**Tõend:** ShellCheck puhas, Labori seisu screenshot.

**Mõtle:** see on *pull*-kontroll (control node küsib). Kuidas teeksid *push*-kontrolli, kus EC2 ise teatab, et
on valmis? Mis seda praegu takistab?

---

## Koristus

```bash
aws ec2 terminate-instances --instance-ids <id>
aws ec2 wait instance-terminated --instance-ids <id>
aws ec2 delete-security-group --group-name labseis-k01
bash cloud/aws-leftovers.sh
```

Võtmepaar (`labseis`) võib jääda: see on tasuta ja läheb 2. kohtumisel vaja.

## Valmis, kui

- `aws sts get-caller-identity` näitab IAM-kasutajat, root-il on MFA ja Budgets'is kaks eelarvet kinnitatud e-postiga
- control node'il töötab `aws login`, `~/.aws/credentials` faili pole
- `curl -s -o /dev/null -w '%{http_code}' http://<avalik-ip>/` andis `200` ja `cloud-init-output.log`-is on sinu skripti väljund
- Labori seisus on `aws-k01 web OK`, `shellcheck cloud/k01-aws/check-aws.sh` on puhas
- `aws-leftovers.sh`: `TULEMUS: tasulisi jääke pole`

## Lisaülesanne

Lisa `websetup.sh`-i haru `amzn)` (Amazon Linux 2023: `dnf`, teenus `httpd`). Käivita sama user-data AL2023 AMI-ga
(`/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`). Klassi Proxmoxi labor peab endiselt
töötama: ShellCheck ja `k01` automaatne hindaja rohelised.

## Veaotsing

Ühised vead (sessioon, profiil, SG vana IP, vale region): [AWS-i reeglid](aws-reeglid.md#veaotsing).

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `aws login` puudub | CLI < 2.32 | paigalda AWS-i zip-ist, mitte apt-ist |
| brauser timeout, SSH töötab | SG-s pole 80 või skript pole veel lõpetanud | lisa 80; kontrolli `cloud-init status` |
| `Tundmatu distro: amzn` | vale AMI | kasuta Ubuntu SSM parameetrit |
