---
tags:
  - AWS
  - EC2
  - Ansible
---

# 2. kohtumise kodutöö (valikuline) · Samad rollid EC2-l

**Eeldus:** 2. kohtumise labor (`site.yml`, rollid, Vault), [1. kohtumise kodutöö](k01-aws.md) (konto, `aws login`, võtmepaar `control`) · **Esita:** `k02/aws.md`

Laboris seadistas `site.yml` Proxmoxi masinaid. Siin lisad AWS-i virtuaalmasina gruppi `veeb` ja seadistad selle samade rollidega. Rolle ega playbook'i ei muuda: kõik erinevused lähevad inventory'sse ja muutujatesse.

**Enne alustamist:**

- `aws configure get region` → `eu-north-1`; tunnipõhine kulu: 1 × t3.micro + avalik IPv4, kokku alla $0.05.
- Eelarvehäired on alles.
- Lõpus koristus ja `bash cloud/aws-leftovers.sh`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Lisab pilvemasina olemasolevasse gruppi ja seadistab selle samade rollidega.
2. Kirjutab grupi väärtuse ühe masina jaoks üle (`ansible_user`) ja selgitab, miks see võidab.
3. Kontrollib, et teine käivitus annab ka pilves `changed=0`, ja koristab ressursid.

---

## Osa 1 · Masin

Käivita control node'il (SG reegel peab lubama control node'i avaliku IP):

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

Mõne minuti pärast: `aws ec2 describe-instances` näitab `running` ja avalikku IP-d. Kontrolli: `ssh ubuntu@<avalik-ip> hostname`.

## Osa 2 · Masin gruppi

Lisa `k02/inventory.ini`-s grupi `[veeb]` alla rida:

```ini
ec2 ansible_host=<avalik-ip> ansible_user=ubuntu
```

`[all:vars]` ütleb kõigile `ansible_user=kasutaja`, aga masina real antud väärtus on täpsem ja võidab. Sama reegel nagu `host_vars` ja `group_vars` puhul.

```bash
ansible ec2 -m ansible.builtin.ping
ansible-playbook site.yml -K --ask-vault-pass --limit ec2
curl -s http://<avalik-ip>/ | grep Masin
```

EC2-l on kasutajal `ubuntu` paroolita `sudo`: kui `-K` küsib, vajuta Enter.

**Oodatav tulemus:** play'd `Kõik masinad` ja `Veebiserverid` teevad EC2-l muudatused, `Andmebaas` jääb vahele, sest ec2 pole selles grupis. Lehel on `Masin: ec2 (Ubuntu 24.04)`.

Käivita teist korda: `changed=0`.

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
