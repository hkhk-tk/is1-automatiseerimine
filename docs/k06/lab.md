---
tags:
  - AWS
  - OpenTofu
  - Ansible
  - Praktikum
---

# Praktikum: AWS käsurealt

4\. kohtumisel lõi OpenTofu masinad kooli Proxmoxis. Täna teed sama AWS-is. Kõigepealt lood ühe virtuaalmasina AWS CLI käskudega ja kustutad selle käsitsi. Seejärel kirjutad sama masina OpenTofu koodi, seadistad selle Ansible'iga veebiserveriks ja kustutad lõpuks ühe käsuga kõik, mis kood lõi.

Iga osa alguses on eesmärk ja kontroll. Kui oskad, tee osa eesmärgi järgi ise ja ava lahendused ainult kontrolliks. Töö tulemus on harus `k06-aws` olevad failid ja automaatkontroll kontrollib neid GitHubis.

**Edenemine:** laboritahvel <http://is126.kaaren.lab.hkhk.lan> (VPN-iga).

Küsimused: [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions). Lisa küsimusele käsk ja kogu veateade tekstina. Enne saatmist eemalda konto ID, võtmed ja paroolid.

!!! warning "Konto tee enne tundi"

    Osa 1 tee kodus enne kohtumist [AWS-i konto juhendi](aws-konto.md) järgi. Konto kinnitamine võib võtta tunde ja kahe-etapiline sisselogimine vajab telefoni. Kui sul on varem olnud AWS-i konto, loe juhendi viimast lõiku.

??? tip "Algseis: mida saad valmis kujul ja mida teed ise"

    **Saad valmis kujul:** control'i, repositooriumi `~/kursus` ja selles koristuse kontrolli `cloud/aws-leftovers.sh`. Control'is on OpenTofu 4. kohtumisest. Kui seda pole, paigalda see [4. kohtumise praktikumi sammu 1.2](../k04/lab.md#12-paigalda-opentofu) järgi.

    **Teed ise:** lood AWS-i konto, seadistad control'is AWS CLI, lood EC2 masina käsitsi ja OpenTofuga, seadistad selle Ansible'iga, kustutad kõik ja esitad töö tag'iga `k06`.

    **Kulu:** üks t3.micro masin koos avaliku IP-aadressiga maksab umbes 2 senti tunnis ja see võetakse Free plani krediidist. Free planil kaardilt raha ei võeta. Reeglid ja hinnad on lehel [AWS-i reeglid](../kodutood/aws-reeglid.md).

??? abstract "Õpiväljundid"

    1. Seadistad AWS-i konto nii, et igapäevane töö ei käi root-kasutajaga ja kulu on jälgitav.
    2. Logid AWS CLI-ga sisse ajutise sessiooniga, ilma et võtmed jääksid kettale.
    3. Lood ja kustutad EC2 masina AWS CLI käskudega.
    4. Kirjutad sama masina OpenTofu koodi ja seadistad selle Ansible'iga.
    5. Kustutad kõik loodud ressursid ja kontrollid, et midagi tasulist ei jäänud.

??? info "Testitud versioonid"

    AWS CLI 2.32, OpenTofu 1.13, `hashicorp/aws` 6.x, ansible-core 2.16, Ubuntu 24.04 AMI, regioon eu-north-1 (Stockholm).

    Dokumentatsioon: [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/), [EC2](https://docs.aws.amazon.com/ec2/), [OpenTofu AWS provider](https://search.opentofu.org/provider/hashicorp/aws/latest).

## Osa 1 · Konto ja kulude kontroll

AWS-i konto loomisel tekib **root-kasutaja**: sinu e-posti aadress ja parool. Root saab kontoga teha kõike, sealhulgas konto kustutada, ja tema õigusi ei saa piirata. Seepärast kaitsed rooti kahe-etapilise sisselogimisega (MFA) ja teed igapäevaseks tööks eraldi **IAM-kasutaja**. Eelarvehäired saadavad e-kirja, kui midagi hakkab raha maksma.

**Eesmärk:** kontol on Free plan, root on MFA-ga kaitstud ja töötad IAM-kasutajana.  
**Kontroll:** CloudShellis näitab `aws sts get-caller-identity` Arn'i, mis lõpeb `:user/admin`.  
**Kus:** sinu arvuti brauser, AWS-i konsool.

### 1.1 Konto Free planiga

Registreeru lehel [aws.amazon.com/free](https://aws.amazon.com/free/) ja vali plaanide võrdlusest **Free plan**. Enamik uusi kasutajaid ei pea makseviisi andma. Kui AWS seda kontrolliks küsib, ei võeta Free planil kaardilt raha.

??? success "Oodatav tulemus"

    Konsooli avalehel ja lehel **Billing and Cost Management** on kaart **Free plan** krediidi ja päevade jäägiga.

!!! warning "Ära vajuta Upgrade plan"

    Free plan lõpeb kuue kuu pärast või kui krediit saab otsa ja konto suletakse ise. **Upgrade plan** ja AWS Organizationsiga liitumine muudavad konto tasuliseks.

### 1.2 Root-kasutaja kaitse ja IAM-kasutaja

1. Lisa root-kasutajale MFA: paremast ülanurgast konto nimi, **Security credentials**, **Assign MFA device**. Sobib telefoni autentimisrakendus.
2. Root-kasutajale juurdepääsuvõtmeid (access key) ära loo.
3. Ava **IAM**, **Users**, **Create user**. Nimi `admin`, märgi **Provide user access to the AWS Management Console**, õiguste juures **Attach policies directly** ja vali `AdministratorAccess`. Lisa ka sellele kasutajale MFA.
4. Logi välja ja logi sisse IAM-kasutajana: konto ID, kasutajanimi `admin` ja parool.

Juhend piltidega on AWS-i dokumentatsioonis: [IAM-kasutaja loomine](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html).

??? success "Oodatav tulemus"

    Konsooli paremas ülanurgas on `admin @ <konto ID>`.

??? question "Kontrolli ennast"

    IAM-kasutajal on samuti `AdministratorAccess`. Miks on see siis parem kui root?

    ??? success "Vastus"

        IAM-kasutaja õigusi saab hiljem piirata, kasutaja saab blokeerida või kustutada ja tema tegevus on logis eraldi nimega. Root-kasutajaga seda teha ei saa. Kui IAM-kasutaja parool lekib, kustutad kasutaja. Kui root'i parool lekib, on kogu konto ohus.

### 1.3 Eelarvehäired

Ava **Billing and Cost Management**, **Budgets**, **Create budget**.

1. Vali mall **Zero spend budget** ja lisa oma e-posti aadress.
2. Tee teine eelarve: **Monthly cost budget**, summa **10** dollarit.

??? success "Oodatav tulemus"

    Budgetsi loendis on kaks eelarvet. Zero spend budget teatab esimesest tasulisest kasutusest ka siis, kui krediit selle katab. Esimene kiri võib tulla juba samal päeval.

### 1.4 Regioon ja CloudShell

AWS-il on andmekeskused mitmes regioonis ja iga regiooni ressursid on eraldi. Kursusel kasutad regiooni **Europe (Stockholm) eu-north-1**. Vali see konsooli paremast ülanurgast. **CloudShell** on brauseris töötav terminal, kus `aws` käsk on juba sinu kasutajaga sisse logitud. Ava see ülariba ikoonist.

```bash
aws sts get-caller-identity
aws configure get region
```

??? success "Oodatav tulemus"

    `Arn` lõpeb `:user/admin` ja regioon on `eu-north-1`.

## Osa 2 · AWS CLI control'is

CloudShell sobib proovimiseks, aga OpenTofu ja Ansible töötavad control'is. Seal on vaja AWS CLI-d ja sisselogimist. Käsk `aws login` logib sisse brauseri kaudu ja annab ajutise sessiooni, mis aegub ise. Võtmeid kettale ei jää ja kui control'i ketas lekib, ei saa keegi sinu kontole.

**Eesmärk:** control'is töötab `aws` sinu IAM-kasutajana.  
**Kontroll:** `aws sts get-caller-identity` näitab sama Arn'i mis CloudShellis ja faili `~/.aws/credentials` pole.  
**Kus:** control, kaust `~/kursus`.

### 2.1 Haru ja kaust

```bash
cd ~/kursus && git switch main && git pull
git switch -c k06-aws
mkdir -p k06-aws/logid
```

### 2.2 Paigalda AWS CLI

Käsk `aws login` on AWS CLI versioonis 2.32 ja uuemates. Ubuntu `apt` pakett on vanem, seepärast paigaldad CLI [AWS-i juhendi](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) järgi zip-failist.

```bash
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install --update
aws --version
cd ~/kursus
```

??? success "Oodatav tulemus"

    `aws-cli/2.32` või uuem.

??? warning "Kui `unzip: command not found`"

    Paigalda see: `sudo apt-get install -y unzip`.

### 2.3 Logi sisse

Control'is pole brauserit. Võti `--remote` trükib aadressi, mille avad oma arvuti brauseris, ja küsib seejärel koodi, mille brauser annab.

```bash
aws login --remote --profile labseis-login
```

OpenTofu ja Ansible ei oska `aws login` sessiooni ise lugeda. Teine profiil `labseis` küsib ajutised võtmed sessioonist iga kord, kui neid vaja on. Lisa see faili `~/.aws/config`.

??? example "Ülesanne: profiil failis `~/.aws/config`"

    Lisa faili lõppu:

    ```ini
    [profile labseis]
    region = eu-north-1
    credential_process = aws configure export-credentials --profile labseis-login --format process
    ```

```bash
echo 'export AWS_PROFILE=labseis' >> ~/.bashrc
export AWS_PROFILE=labseis
aws sts get-caller-identity
ls ~/.aws/
```

??? success "Oodatav tulemus"

    Sama `Arn` mis CloudShellis. Kaustas `~/.aws/` on `config` ja sessiooni vahemälu, aga faili `credentials` ei ole.

??? warning "Kui `Unknown options: --remote` või `Invalid choice: 'login'`"

    Käivitub vana CLI. `which -a aws` näitab, kus need on. Uus on `/usr/local/bin/aws`.

??? warning "Kui hiljem tuleb `ExpiredToken` või `Unable to locate credentials`"

    Sessioon aegus. Käivita uuesti `aws login --remote --profile labseis-login`.

## Osa 3 · EC2 masin käsitsi

**EC2** on AWS-i virtuaalmasinate teenus ja üks masin on **instance**. Masina loomiseks on vaja nelja asja: tulemüüri reegleid (**security group**), SSH-võtit, operatsioonisüsteemi malli (**AMI**) ja masina suurust (**instance type**). Kõigepealt teed seda käsitsi, et näha, mis on vaja ja kui palju käske see võtab.

**Eesmärk:** EC2 masin töötab, sinna saab SSH-ga sisse ja pärast kontrolli on see kustutatud.  
**Kontroll:** `ssh ubuntu@<avalik IP> hostname` vastab ja lõpus näitab `aws ec2 describe-instances` olekut `terminated`.  
**Kus:** control.

### 3.1 Security group

Security group on masina tulemüür. Vaikimisi on kõik sissetulev liiklus keelatud. Lubad pordi 22 ainult oma avalikult IP-aadressilt, sest kui port on avatud kogu internetile, algavad võõrad sisselogimiskatsed juba mõne minuti pärast. Kõik kooli masinad on internetis ühe aadressi taga, `checkip` näitab seda.

```bash
MYIP=$(curl -s https://checkip.amazonaws.com)/32
echo $MYIP
aws ec2 create-security-group --group-name k06-kasitsi --description "K6 kasitsi"
aws ec2 authorize-security-group-ingress --group-name k06-kasitsi --protocol tcp --port 22 --cidr "$MYIP"
```

??? success "Oodatav tulemus"

    `create-security-group` väljastab `GroupId`, näiteks `sg-0abc...`. Teine käsk väljastab reegli, kus `FromPort` on 22 ja `CidrIpv4` on sinu aadress.

### 3.2 Võti ja masin

AWS-ile annad ainult avaliku võtme. Privaatvõti jääb control'i. AMI-i numbrid on igas regioonis erinevad ja muutuvad iga uuendusega, seepärast küsid Ubuntu uusima AMI-i AWS-i parameetrite teenusest (SSM).

```bash
aws ec2 import-key-pair --key-name control --public-key-material fileb://~/.ssh/id_ed25519.pub
AMI=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text)
echo $AMI
aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --key-name control --security-groups k06-kasitsi \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=k06-kasitsi},{Key=Project,Value=labseis}]' \
  --query 'Instances[0].InstanceId' --output text
```

??? success "Oodatav tulemus"

    AMI on kujul `ami-0...` ja viimane käsk väljastab masina ID, näiteks `i-0abc...`. Kirjuta see üles.

### 3.3 Kontrolli ja kustuta

Masin käivitub umbes minutiga. Võti `--query` valib väljundist ainult vajalikud väljad.

```bash
aws ec2 describe-instances --filters Name=tag:Name,Values=k06-kasitsi \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table
ssh -o StrictHostKeyChecking=accept-new ubuntu@<avalik IP> hostname
```

??? success "Oodatav tulemus"

    Tabelis on olek `running` ja avalik IP. `ssh` vastab hostinimega kujul `ip-172-31-...`. EC2 Ubuntu kasutaja on `ubuntu`, mitte `kasutaja`.

Kustuta kõigepealt security group ja seejärel masin. Enne käsku mõtle läbi: kas AWS lubab kustutada tulemüüri, mida töötav masin kasutab?

```bash
aws ec2 delete-security-group --group-name k06-kasitsi
```

??? question "Leia põhjus"

    Mida ütleb veateade ja mida see tähendab?

    ??? success "Vastus"

        `An error occurred (DependencyViolation) ... resource sg-... has a dependent object`. Security groupi kasutab masin ja AWS ei kustuta ressurssi, millest midagi sõltub. Käsitsi pead ise teadma, mis millest sõltub, ja kustutama vastupidises järjekorras: kõigepealt masin, siis security group.

Kustuta õiges järjekorras. Käsk `wait` ootab, kuni masin on täielikult kustunud:

```bash
aws ec2 terminate-instances --instance-ids <masina ID>
aws ec2 wait instance-terminated --instance-ids <masina ID>
aws ec2 delete-security-group --group-name k06-kasitsi
```

??? question "Kontrolli ennast"

    Mitu käsku kulus ühe masina loomiseks ja kustutamiseks? Mis juhtub, kui unustad masina ID või kustutamise?

    ??? success "Vastus"

        Umbes kümme käsku ja ID-d tuli käsitsi meeles pidada. Unustatud masin töötab edasi ja kulutab krediiti. Järgmises osas kirjutad sama koodina: OpenTofu mäletab state'is, mida ta lõi, ja `tofu destroy` kustutab kõik.

## Osa 4 · Sama masin OpenTofuga

OpenTofu kood on sama ülesehitusega nagu 4. kohtumisel. Vahetub ainult provider: `bpg/proxmox` asemel `hashicorp/aws`. Provider loeb sisselogimise muutujast `AWS_PROFILE`, nii et koodis ei ole ühtegi võtit.

**Eesmärk:** `tofu apply` loob security groupi, võtme ja masina ning annab välja masina IP.  
**Kontroll:** teine `tofu plan` ütleb `No changes` ja `ssh ubuntu@$(tofu output -raw ip) hostname` vastab.  
**Kus:** control, kaust `~/kursus/k06-aws`.

### 4.1 Provider ja muutuja

`default_tags` lisab sildid igale ressursile, mille kood loob. Silt `Project = "labseis"` aitab koristusskriptil kõik üles leida. Muutuja `my_ip` hoiab sinu IP-aadressi, mis läheb tulemüüri reeglisse. Muutuja `ssh_public_key` ütleb, kus on control'i avalik võti.

??? example "Ülesanne: fail `k06-aws/main.tf`, provider ja muutuja"

    ```hcl
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.0"
        }
      }
    }

    provider "aws" {
      region = "eu-north-1"
      default_tags {
        tags = {
          Project = "labseis"
        }
      }
    }

    variable "my_ip" {
      description = "Sinu avalik IP-aadress kujul 1.2.3.4/32"
      type        = string
    }

    variable "ssh_public_key" {
      description = "Control'i avaliku SSH-võtme fail"
      type        = string
      default     = "~/.ssh/id_ed25519.pub"
    }
    ```

Väärtus läheb faili `terraform.tfvars`, mis on `.gitignore`-is, sest IP-aadress ei pea Giti minema.

```bash
cd ~/kursus/k06-aws
echo "my_ip = \"$(curl -s https://checkip.amazonaws.com)/32\"" > terraform.tfvars
tofu init
tofu validate
```

??? success "Oodatav tulemus"

    `init` laadib provider'i `hashicorp/aws` ja `validate` ütleb `Success!`.

### 4.2 Security group, võti ja masin

Iga osa käsitsi tehtud tööst on nüüd üks plokk. Security group'i reeglid on eraldi ressursid: üks lubab SSH, teine HTTP sinu aadressilt ja kolmas lubab masinal internetti minna. Kui security group luuakse konsoolis, lisab AWS väljamineva reegli ise. OpenTofu provider selle reegli eemaldab, nii et koodis peab kõik lubatu kirjas olema. Ressursi argumendid leiad [provider'i dokumentatsioonist](https://search.opentofu.org/provider/hashicorp/aws/latest/docs/resources/instance).

??? example "Ülesanne: security group ja reeglid `main.tf`-i lõppu"

    ```hcl
    resource "aws_security_group" "web" {
      name        = "k06-web"
      description = "K6 veebiserver"
    }

    resource "aws_vpc_security_group_ingress_rule" "ssh" {
      security_group_id = aws_security_group.web.id
      cidr_ipv4         = var.my_ip
      ip_protocol       = "tcp"
      from_port         = 22
      to_port           = 22
    }

    resource "aws_vpc_security_group_ingress_rule" "http" {
      security_group_id = aws_security_group.web.id
      cidr_ipv4         = var.my_ip
      ip_protocol       = "tcp"
      from_port         = 80
      to_port           = 80
    }

    resource "aws_vpc_security_group_egress_rule" "valja" {
      security_group_id = aws_security_group.web.id
      cidr_ipv4         = "0.0.0.0/0"
      ip_protocol       = "-1"
    }
    ```

AMI-i leiab data source samast SSM-i parameetrist nagu käsk 3.2-s.

??? example "Ülesanne: AMI, võti ja masin `main.tf`-i lõppu"

    ```hcl
    data "aws_ssm_parameter" "ubuntu" {
      name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
    }

    resource "aws_key_pair" "control" {
      key_name   = "k06-control"
      public_key = file(pathexpand(var.ssh_public_key))
    }

    resource "aws_instance" "web" {
      ami                    = data.aws_ssm_parameter.ubuntu.value
      instance_type          = "t3.mirco"
      key_name               = aws_key_pair.control.key_name
      vpc_security_group_ids = [aws_security_group.web.id]

      tags = {
        Name = "k06-web"
      }
    }

    output "ip" {
      value = aws_instance.web.public_ip
    }
    ```

Enne käsku mõtle läbi: mitu ressurssi plaan lisab?

```bash
tofu fmt
tofu plan
tofu apply
```

Plaan ütleb `Plan: 6 to add, 0 to change, 0 to destroy.`: security group, kolm reeglit, võti ja masin. Data source ei ole ressurss. `apply` aga ebaõnnestub. Loe veateadet.

??? question "Leia põhjus"

    Mida ütleb veateade? Mitu ressurssi jõuti luua?

    ??? success "Vastus"

        `InvalidParameterValue: Invalid value 't3.mirco' for InstanceType`: masina tüübi nimes on kirjaviga, õige on `t3.micro`. `plan` ei leidnud viga, sest provider ei tea kõiki AWS-i masinatüüpe ette. Viga tuli AWS-ist alles loomise ajal. Security group, reeglid ja võti jõuti luua ja need on state'is.

Paranda failis `t3.mirco` kujule `t3.micro` ja käivita uuesti. Enne käsku mõtle läbi: mitu ressurssi plaan nüüd lisab?

```bash
tofu apply
```

??? success "Oodatav tulemus"

    `Plan: 1 to add, 0 to change, 0 to destroy.`: ainult masin, sest teised ressursid on juba olemas. Pärast `apply`-d näitab output `ip` masina avalikku IP-aadressi.

??? warning "Kui tuleb `InvalidKeyPair.Duplicate`"

    Sama nimega võti on juba olemas. Kustuta see: `aws ec2 delete-key-pair --key-name k06-control`.

### 4.3 Teine plaan ja SSH

```bash
tofu plan
ssh -o StrictHostKeyChecking=accept-new ubuntu@$(tofu output -raw ip) hostname
```

??? success "Oodatav tulemus"

    `No changes. Your infrastructure matches the configuration.` ja `ssh` vastab hostinimega `ip-172-31-...`.

??? warning "Kui `ssh` aegub"

    Masin alles käivitub, oota minut. Kui ikka aegub, on sinu IP muutunud: tee `terraform.tfvars` uuesti ja `tofu apply`.

## Osa 5 · Ansible seadistab masina

Masin on olemas, aga tühi. Nagu 4. kohtumisel, annab OpenTofu masina aadressi Ansible'ile inventory failina ja Ansible paigaldab veebiserveri. Inventory fail tehakse OpenTofu väljundist, nii et IP-aadressi ei pea käsitsi kopeerima.

**Eesmärk:** masinas töötab Nginx ja leht vastab brauseris.  
**Kontroll:** `curl http://$(tofu output -raw ip)` näitab teksti `Tere AWS-ist`. Playbook'i teine käivitus annab `changed=0`.  
**Kus:** control, kaust `~/kursus/k06-aws`.

### 5.1 Inventory OpenTofust

Ressurss `local_file` kirjutab faili control'i kettale. See tuleb teisest providerist, `hashicorp/local`.

??? example "Ülesanne: inventory fail `main.tf`-i lõppu"

    ```hcl
    resource "local_file" "inventory" {
      filename = "${path.module}/inventory.ini"
      content  = <<-EOT
        [aws]
        k06-web ansible_host=${aws_instance.web.public_ip} ansible_user=ubuntu
      EOT
    }
    ```

```bash
tofu apply
```

??? question "Leia põhjus"

    Mida ütleb veateade ja millise käsuga see parandada?

    ??? success "Vastus"

        `Inconsistent dependency lock file` ja `provider registry.opentofu.org/hashicorp/local: required by this configuration but no version is selected`. Kood vajab uut providerit, aga see on alla laadimata ja lukufailis puudub. Veateate lõpus on lahendus: `tofu init`. Iga kord, kui lisad uue provider'i või mooduli, tuleb `init` uuesti teha.

```bash
tofu init
tofu apply
cat inventory.ini
ansible -i inventory.ini aws -m ansible.builtin.ping
```

??? success "Oodatav tulemus"

    `inventory.ini`-s on üks rida masina IP-ga ja `ping` vastab `pong`. EC2-l on kasutajal `ubuntu` paroolita `sudo` nagu labori masinates.

### 5.2 Playbook

Playbook on sama ülesehitusega nagu 2. kohtumisel: paigalda pakett, kirjuta fail ja käivita teenus.

??? example "Ülesanne: fail `k06-aws/web.yml`"

    ```yaml
    - name: Veebiserver AWS-is
      hosts: aws
      become: true
      tasks:
        - name: Nginx on paigaldatud
          ansible.builtin.apt:
            name: nginx
            state: present
            update_cache: true

        - name: Avaleht
          ansible.builtin.copy:
            dest: /var/www/html/index.html
            content: "Tere AWS-ist, masin {{ inventory_hostname }}\n"
            mode: "0644"

        - name: Nginx töötab
          ansible.builtin.service:
            name: nginx
            state: started
            enabled: true
    ```

```bash
ansible-playbook -i inventory.ini web.yml
ansible-playbook -i inventory.ini web.yml | tee logid/ansible-teine.txt
curl http://$(tofu output -raw ip)
```

??? success "Oodatav tulemus"

    Esimene käivitus muudab kolme ülesannet. Teise käivituse kokkuvõttes on `changed=0`. `curl` vastab `Tere AWS-ist, masin k06-web`. Sama aadress töötab ka sinu arvuti brauseris, kui sinu arvuti on samas võrgus nagu control. Kodus on sinu avalik IP teine ja brauser ei pääse ligi: security group lubab ainult control'i aadressi.

Salvesta töö Giti. Fail `inventory.ini` sisaldab ajutist IP-aadressi ja Giti see ei lähe.

```bash
echo "inventory.ini" > .gitignore
cd ~/kursus
git add k06-aws
git status
git commit -m "k06: EC2 OpenTofuga ja Nginx Ansible'iga"
```

??? success "Oodatav tulemus"

    `git status` näitab `main.tf`, `web.yml`, `.terraform.lock.hcl`, `.gitignore` ja `logid/ansible-teine.txt`. Faile `terraform.tfvars`, `terraform.tfstate` ja kausta `.terraform/` seal ei ole.

## Osa 6 · Koristus

Kõik, mille OpenTofu lõi, on tema state'is. `tofu destroy` kustutab need vastupidises järjekorras: kõigepealt masina, siis reeglid ja security groupi. Koristusskript kontrollib seejärel kogu kontot, sest käsitsi tehtud või unustatud ressurssi OpenTofu ei tea.

**Eesmärk:** kontol ei ole midagi, mis kulutab krediiti.  
**Kontroll:** `aws-leftovers.sh` lõpeb reaga `TULEMUS: tasulisi jääke pole`.  
**Kus:** control, kaust `~/kursus`.

Enne käsku mõtle läbi: mitu ressurssi kustutatakse?

```bash
tofu -chdir=k06-aws destroy
aws ec2 delete-key-pair --key-name control
bash cloud/aws-leftovers.sh | tee k06-aws/logid/koristus.txt
```

??? success "Oodatav tulemus"

    `Destroy complete! Resources: 7 destroyed.`: kuus AWS-i ressurssi ja inventory fail. 3. osa võti `control` kustutatakse eraldi, sest selle lõid käsitsi. Koristusskripti viimane rida on `TULEMUS: tasulisi jääke pole`.

??? warning "Kui koristusskript näitab `KULU` rida"

    Midagi jäi alles, tõenäoliselt 3. osa masin või security group. Rida ütleb ressursi tüübi, ID ja regiooni. Kustuta see konsoolist või CLI-ga ja käivita skript uuesti.

## Osa 7 · Esitamine

Automaatkontroll näeb ainult repositooriumi. See kontrollib failide olemasolu, OpenTofu vormingut ja `validate`-i, et Gitis pole saladusi ega state'i, ning logifaile.

**Eesmärk:** töö on `main`-is ja tag `k06` on käivitanud automaatkontrolli.  
**Kontroll:** kuus kontrolli annavad `OK`.  
**Kus:** control, kaust `~/kursus`.

```bash
for t in files fmt validate secrets resources logid; do bash autograde/check.sh k06 "$t"; done
git add k06-aws autograde/check.sh
git commit -m "k06: koristuse tulemus"
git push -u origin k06-aws
gh pr create --base main --head k06-aws --title "K6 AWS" --body "K6: AWS käsurealt"
gh pr merge --merge
git switch main && git pull
git tag k06 && git push origin k06
```

??? warning "Kui `check.sh` ütleb `tundmatu kohtumine k06`"

    Sinu repositooriumi kontrollskript on vana. Uuenda see: `curl -fsSL https://raw.githubusercontent.com/hkhk-tk/is1-starter/main/autograde/check.sh -o autograde/check.sh`.

Tulemuse näed paari minuti pärast GitHubis: repositoorium → **Releases**.

## Lisaülesanded

??? example "1 · Kaks masinat for_each'iga"

    Tee 4. kohtumise eeskujul muutuja `vms` ja ressurss `aws_instance` `for_each`-iga, nii et sama kood loob kaks masinat: `web01` ja `app01`. Inventory mall saab mõlemad masinad. Pärast proovimist tee `tofu destroy`.

??? example "2 · Võrk koodiga ja triiv"

    Kood kasutas AWS-i vaikimisi võrku. IS2 [4. kohtumise kodutöö](https://hkhk-tk.github.io/is2-automatiseerimine/kodutood/k04-aws/) loob võrgu mooduliga, teeb viis masinat ja näitab, mida `tofu plan` käsitsi tehtud muudatustest näeb ja mida ei näe.

??? example "3 · State S3-s"

    State on praegu control'i kettal. Kui control kaob, ei tea OpenTofu enam, mida ta lõi. Tee S3 bucket ja vii state sinna: [OpenTofu S3 backend](https://opentofu.org/docs/language/settings/backends/s3/). Bucket'i hoidmine on peaaegu tasuta.

??? example "4 · Kubernetes AWS-is"

    5. kohtumise YAML-failid töötavad ka AWS-i Kubernetese teenuses EKS: [HashiCorpi EKS-i õpetus](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks). EKS-i juhtimise osa maksab umbes 10 senti tunnis ka tühjana ja õpetuse võrk teeb tasulise NAT gateway. Kustuta kõik kohe pärast proovimist ja käivita koristusskript.
