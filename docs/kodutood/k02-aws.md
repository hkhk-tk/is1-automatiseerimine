---
tags:
  - AWS
  - EC2
  - Ansible
---

# 2. kohtumise kodutöö (valikuline) · Samad rollid EC2-l

**Eeldus:** 2. kohtumise labor (`site.yml`, rollid, Vault), [1. kohtumise kodutöö](k01-aws.md) (konto, `aws login`, võtmepaar `control`) · **Esita:** `k02/aws.md`

Praktikumis seadistas `site.yml` Proxmoxi masinaid. Kodutöös lisad AWS-i virtuaalmasina gruppi `veeb` ja seadistad selle samade rollidega. Rolle ega playbook'i ei muuda: kõik erinevused kirjutad inventory'sse ja muutujatesse.

**Enne alustamist:**

- Käsk `aws configure get region` väljastab `eu-north-1`. Üks t3.micro masin ja avalik IPv4-aadress maksavad kokku alla $0.05 tunnis.
- Eelarvehäired on alles.
- Lõpus kustutad ressursid ja käivitad `bash cloud/aws-leftovers.sh`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Lisab pilvemasina olemasolevasse gruppi ja seadistab selle samade rollidega.
2. Kirjutab grupi väärtuse ühe masina jaoks üle (`ansible_user`) ja selgitab, miks see väärtus kehtib.
3. Kontrollib, et teine käivitus annab ka pilves `changed=0`, ja koristab ressursid.

---

## Osa 1 · Masin

Käivita control node'il (turvagrupi reegel peab lubama control node'i avalikku IP-aadressi):

```bash
MYIP=$(curl -s https://checkip.amazonaws.com)/32
aws ec2 create-security-group --group-name ansible-k02 --description "K2 kodutoo"
aws ec2 authorize-security-group-ingress --group-name ansible-k02 --protocol tcp --port 22 --cidr "$MYIP"
aws ec2 authorize-security-group-ingress --group-name ansible-k02 --protocol tcp --port 80 --cidr "$MYIP"

AMI=$(aws ssm get-parameter \
    --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
    --query Parameter.Value --output text)
aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
    --key-name control --security-groups ansible-k02 \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ansible-k02}]'
```

Mõne minuti pärast näitab `aws ec2 describe-instances` olekut `running` ja avalikku IP-aadressi. Kontrolli: `ssh ubuntu@<avalik-ip> hostname`.

## Osa 2 · Masin gruppi `veeb`

Lisa `k02/inventory.ini`-s grupi `[veeb]` alla rida:

```ini
ec2 ansible_host=<avalik-ip> ansible_user=ubuntu
```

`[all:vars]` määrab kõigile masinatele `ansible_user=kasutaja`, kuid masina real antud väärtus on täpsem ja kehtib selle masina puhul. Sama reegel kehtib `host_vars`-i ja `group_vars`-i puhul.

```bash
ansible ec2 -m ansible.builtin.ping
ansible-playbook site.yml --ask-vault-pass --limit ec2
curl -s http://<avalik-ip>/ | grep Masin
```

EC2-l on kasutajal `ubuntu` paroolita `sudo`, nagu ka labori masinates.

**Oodatav tulemus:** play'd `Kõik masinad` ja `Veebiserverid` teevad EC2-s muudatused. Play `Andmebaas` jäetakse vahele, sest ec2 ei kuulu sellesse gruppi. Lehel on `Masin: ec2 (Ubuntu 24.04)`.

Käivita playbook teist korda. Kokkuvõttes peab olema `changed=0`.

Kirjuta faili `k02/aws.md` kolm lauset: mis erines pilvemasinas, kuhu selle erinevuse kirjutasid ja miks rolle polnud vaja muuta.

## Koristus

```bash
aws ec2 terminate-instances --instance-ids <id>
aws ec2 wait instance-terminated --instance-ids <id>
aws ec2 delete-security-group --group-name ansible-k02
bash cloud/aws-leftovers.sh
```

Eemalda `inventory.ini`-st rida `ec2 ...`.

## Valmis, kui

- `site.yml` teine käivitus annab EC2-l `changed=0`
- `curl` EC2 avalikule IP-le näitas lehte
- `k02/aws.md` on repos
- `aws-leftovers.sh`: `TULEMUS: tasulisi jääke pole`

## Veaotsing

Ühised vead (sessioon, profiil, SG vana IP, vale region): [AWS-i reeglid](aws-reeglid.md#veaotsing).

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `UNREACHABLE` | SG-s pole control node'i praegust IP-d | uuenda reeglit `MYIP`-ga control node'ilt |
| `Permission denied (publickey)` | vale kasutaja | `ansible_user=ubuntu` masina real |
| `curl` aegub | SG-s pole porti 80 | lisa reegel pordile 80 |
