---
tags:
  - AWS
  - EC2
  - Ansible
---

# 2. kohtumise kodutöö · Labori seis viiel EC2-l Ansible'iga

**Eeldus:** 2. kohtumise labor (`site.yml`, rollid, Vault), [1. kohtumise kodutöö](k01-aws.md) (konto, `aws login`, võtmepaar `labseis`) · **Esita:** `cloud/k02-aws/aws_ec2.yml`

Sinu `site.yml` töötab Proxmoxis staatilise `inventory.ini`-ga ja ühe võrguga. AWS-is muutuvad IP-d iga uue masinaga
ja igal masinal on kaks aadressi, avalik ja privaatne. Playbook läheb läbi, aga rakendus ei saa andmebaasiga ühendust.

**Enne alustamist:**

- `aws configure get region` → `eu-north-1`; tunnipõhine kulu: 5 × EC2 (4 × t3.micro, app01 t3.small) + 5 avalikku IPv4, kokku ~$0.10–0.20.
- Eelarvehäired (zero spend, $10) on alles.
- `aws sts get-caller-identity` → Arn lõpeb `:user/…`, mitte `:root`.
- Lõpus koristus ja `bash cloud/aws-leftovers.sh`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Seadistab Ansible'i dünaamilise inventory, mis loeb hostid AWS API-st siltide järgi.
2. Leiab oma rollidest keskkonnaeelduse (IP aadress `/etc/hosts`-is) ja teeb selle muutujaks.
3. Selgitab, miks avaliku ja privaatse IP vahe mõjutab SG reegleid, ja kontrollib idempotentsust teises keskkonnas.

---

## Osa 1 · Masinad

Kui 4. kohtumise kodutöö on juba tehtud, loo masinad sellega (`cloud/k04-aws`) ja jätka osast 2.

Muidu loo viis masinat käsitsi `aws ec2 run-instances`-iga nagu 1. kohtumise kodutöös, aga:

| Name | AMI | Tüüp | Silt Group | Silt Distro |
|---|---|---|---|---|
| db01 | Rocky 9 | t3.micro | db | rocky |
| mc01 | Rocky 9 | t3.micro | cache | rocky |
| rmq01 | Ubuntu 24.04 | t3.micro | queue | ubuntu |
| app01 | Ubuntu 24.04 | t3.small | app | ubuntu |
| web01 | Ubuntu 24.04 | t3.micro | web | ubuntu |

*Tabel 1. Masinad, tüübid ja sildid.*

Kõigile lisaks silt `Project=labseis`. Rocky AMI:

```bash
aws ec2 describe-images --owners 792107900819 \
    --filters 'Name=name,Values=Rocky-9-EC2-Base-9.*x86_64' \
    --query 'sort_by(Images,&CreationDate)[-1].[ImageId,Name]' --output text
```

SG: üks grupp `labseis-k02`, kus 22 on lubatud ainult sinu IP-st, 80 kõigile ja **kogu liiklus samast SG-st** (reegel,
mille allikas on SG ise). Viimane reegel laseb masinatel omavahel rääkida.

<!-- EKRAANIPILT: AWS konsool, EC2 → Security Groups → labseis-k02 → vahekaart "Inbound rules", pärast kõigi reeglite lisamist. Kolm rida: SSH 22 allikaga <sinu-ip>/32, HTTP 80 allikaga 0.0.0.0/0, "All traffic" allikaga sg-… (sama grupi enda ID, noolega märgitud). Sinu IP hägustada.
<figure markdown="span">
  ![Security group labseis-k02 sissetulevad reeglid: SSH sinu IP-st, HTTP kõigile ja kogu liiklus samast grupist](assets/kKT_k02-sg-self-rule.png)
  <figcaption>Joonis 1. SG reegel, mille allikas on SG ise.</figcaption>
</figure>
-->

**Oodatav tulemus:** `aws ec2 describe-instances --filters Name=tag:Project,Values=labseis` näitab viit `running` masinat.
**Kui `describe-images` on tühi:** Rocky konto ID või nimemuster on muutunud. Otsi konsoolis EC2 → AMI Catalog →
Community AMIs → "Rocky-9". Marketplace'i variandi puhul vajuta enne "Subscribe" (tasuta).

---

## Osa 2 · Inventory API-st

Proxmoxis oli `inventory.ini` (4. kohtumisel genereerib selle OpenTofu). Dünaamiline
inventory küsib hostid igal käivitusel API-st.

### 2.1 Eeldused control node'il

```bash
sudo apt install -y python3-boto3      # või: pipx inject ansible-core boto3 botocore
ansible-galaxy collection install amazon.aws
aws sts get-caller-identity             # AWS_PROFILE=labseis töötab (K1)
```

Lisa `amazon.aws` ka `k02-ansible/requirements.yml`-i.

### 2.2 Väikseim töötav inventory

Loo [`amazon.aws.aws_ec2`](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
pluginale fail `cloud/k02-aws/aws_ec2.yml` (failinimi **peab** lõppema `aws_ec2.yml`):

```yaml
plugin: amazon.aws.aws_ec2
regions: [eu-north-1]
filters:
  tag:Project: labseis
```

```bash
ansible-inventory -i cloud/k02-aws/aws_ec2.yml --graph
```

**Oodatav tulemus:** viis hosti grupis `@aws_ec2`, nimed on avalikud DNS nimed.
**Kui näed** `Failed to import the required Python library (botocore or boto3)`: boto3 on teise Pythoni all kui
Ansible. `ansible --version` näitab, millist Pythonit Ansible kasutab.

### 2.3 Nimed ja grupid siltidest

Lisa samasse faili:

- `hostnames` → silt `Name` (siis on hostid `db01`, `web01` …);
- [`keyed_groups`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/constructed_inventory.html) →
  silt `Group`, ilma prefiksi ja eraldajata (siis tekivad grupid `db`, `app` …, samad, mida `site.yml` ootab);
- `compose` → `ansible_host` avalik IP, `private_ip` privaatne IP, `ansible_user` `rocky` või `ubuntu` sildi `Distro` järgi.

Vihje: `compose` väärtused on Jinja2 avaldised, string käib ülakomadesse jutumärkide sees.

**Oodatav tulemus:** `--graph` näitab gruppe `db`, `cache`, `queue`, `app`, `web`. `ansible all -i cloud/k02-aws/aws_ec2.yml -m ping` → 5 × `pong`.
**Tõend:** `--graph` väljund issue kommentaaris.

**Mõtle:** `ansible.cfg`-s on `remote_user = kasutaja`. Miks võidab `compose`-i `ansible_user`? Kus oled tööl veel
näinud, et sama playbook peab eri keskkonnas teise kasutajaga sisse logima?

---

## Osa 3 · Mis eeldus AWS-is ei kehti

Käivita playbook muutmata kujul:

```bash
cd k02-ansible
ansible-playbook -i ../cloud/k02-aws/aws_ec2.yml site.yml --ask-vault-pass
```

Ava `http://<web01 avalik IP>/health`.

**Oodatav tulemus:** playbook läheb läbi, aga `/health` annab `502` või `"db":"DOWN"`.

Uuri põhjust: `ssh ubuntu@<app01> cat /etc/hosts`. Mis IP on seal `db01` taga? Kas SG lubab sellelt aadressilt liiklust?

Paranda rolli `common` mall nii, et `/etc/hosts`-i läheb `private_ip`, kui see on olemas, muidu `ansible_host`
(Jinja2 filter `default`). Proxmoxi inventory's `private_ip`-d pole, seega klassi labor peab edasi töötama.
Sama eeldus on rakenduse `env.j2`-s (`DB_HOST` jt) ja Nginxi upstream'is: paranda kõik kolm.

Kui su rollid on koolitaja lahendusest (`lahendus/k02`), on filter juba kolmes mallis ja `/health` on kohe `UP`.
Siis leia need read (`grep -rn private_ip roles/`) ja kirjuta TOEND-i, mis juhtuks ilma nendeta.

**Oodatav tulemus:** `/health` → `{"status":"UP",…}`. Teine käivitus: `changed=0`.
**Tõend:** `/health` vastus + teise käivituse `PLAY RECAP`.

??? info "Miks nii"
    [SG reegel "samast SG-st"](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html) kehtib
    ainult VPC sisese (privaatse) liikluse kohta. Avaliku IP kaudu tuleb pakett väljast ja reegel ei kehti.

**Mõtle:** Proxmoxis oli igal masinal üks IP. Kus on sinu rollides veel peidus eeldus "üks võrk"?
(Vihje: MariaDB `bind-address`, RabbitMQ kasutaja lubatud hostid.)

---

## Koristus

```bash
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances \
    --filters Name=tag:Project,Values=labseis Name=instance-state-name,Values=running,stopped \
    --query 'Reservations[].Instances[].InstanceId' --output text)
```

Oota olekut `terminated`, kustuta SG, siis `bash cloud/aws-leftovers.sh`.

## Valmis, kui

- `ansible-inventory -i cloud/k02-aws/aws_ec2.yml --graph` näitab gruppe `db`, `cache`, `queue`, `app`, `web`
- `curl -s http://<web01>/health` EC2-l annab `"status":"UP"`, teine `ansible-playbook` → `changed=0`
- klassi Proxmoxi `site.yml` töötab sama `common` rolliga edasi (`/health` → `UP`)
- `grep -E '[0-9]{12}|AKIA' cloud/k02-aws/aws_ec2.yml` ei leia midagi (võtmeid ega konto ID-d pole)
- `aws-leftovers.sh`: `TULEMUS: tasulisi jääke pole`

## Lisaülesanne

Pane `ansible_host` privaatseks IP-ks ja logi sisse läbi web01 (`ansible_ssh_common_args: -J ubuntu@<web01>`).
Eemalda SG-st port 22 kõigilt peale web01. Mis muutub turvalisuses, mis kiiruses?

## Veaotsing

Ühised vead (sessioon aegus, SG vana IP, vale profiil): [AWS-i reeglid](aws-reeglid.md#veaotsing).

| Probleem | Põhjus | Lahendus |
|---|---|---|
| inventory tühi | vale region või silt | `aws ec2 describe-instances --filters Name=tag:Project,Values=labseis` |
| `Permission denied (publickey)` Rocky masinal | vale kasutaja | kasutaja on `rocky`, mitte `ubuntu` |
| `/health` db DOWN | `/etc/hosts`-is avalik IP | vt osa 3 |
