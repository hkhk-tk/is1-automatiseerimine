---
tags:
  - AWS
  - OpenTofu
  - Ansible
---

# 4. kohtumise kodutöö · sama struktuur, `aws` provider

**Eeldus:** 4. kohtumise labor (`k04-tofu/`: provider, `for_each` üle `vms` map'i, moodul, `inventory.tftpl`), [2. kohtumise kodutöö](k02-aws.md) osa 3 (`private_ip` rollis `common`) · **Esita:** `cloud/k04-aws/`

Klassis kasutab sinu OpenTofu kood valmis võrku ja annab VM-idele IP-d ise. AWS-is lood võrgu ja SG-d koodiga,
aadressid annab AWS ja avalik moodul võib vaikimisi luua tasulisi ressursse. `vms` map'i struktuur ja ahel OpenTofu →
Ansible jäävad samaks.

**Enne alustamist:**

- `aws configure get region` → `eu-north-1`; tunnipõhine kulu: 5 × EC2 + 5 avalikku IPv4 (~$0.15), NAT gateway'd ei looda.
- Eelarvehäired (zero spend, $10) on alles.
- `aws sts get-caller-identity` → Arn lõpeb `:user/…`, mitte `:root`.
- Lõpus `tofu destroy` ja `bash cloud/aws-leftovers.sh`.
- Reeglid ja ühine veaotsing: [AWS-i reeglid](aws-reeglid.md).

## Õpiväljundid

1. Kirjutab OpenTofu konfiguratsiooni teisele providerile sama struktuuriga ja leiab avaliku mooduli muutujatest valiku, mis tekitab kulu.
2. Kirjutab SG reeglid, mis viitavad teistele SG-dele, ja genereerib Ansible'i inventory OpenTofu väljundist.
3. Tuvastab drift'i `plan`-iga ja selgitab, millist drift'i `plan` ei näe.

---

## Osa 1 · Provider ja tühi plaan

Loo `cloud/k04-aws/versions.tf`: providerid [`hashicorp/aws`](https://search.opentofu.org/provider/hashicorp/aws/latest)
(`~> 6.0`) ja `hashicorp/local`. `provider "aws"` plokis region muutujast ja `default_tags`
(`Project = "labseis"`, `Owner = var.owner`).

```bash
cd cloud/k04-aws
tofu init
tofu plan
```

**Oodatav tulemus:** `No changes`. Provider loeb volitused `AWS_PROFILE=labseis` kaudu (1. kohtumise kodutöö).
**Miks `default_tags`:** iga ressurss saab sildid, ilma et peaksid neid igale poole kirjutama. Koristus ja kulude
vaade leiavad kõik üles.
**Kui näed** `No valid credential sources found`: `echo $AWS_PROFILE` ja `aws sts get-caller-identity` samas shellis.

## Osa 2 · Võrk mooduliga

Lisa `main.tf`-i moodul [`terraform-aws-modules/vpc/aws`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
(`~> 6.7`): kaks AZ-d, **ainult** `public_subnets`, `map_public_ip_on_launch = true`.

Enne `apply`'d ava mooduli dokumentatsioonis muutuja `enable_nat_gateway`. Mis on vaikeväärtus? Mis juhtuks, kui
lisaksid `private_subnets`?

```bash
tofu plan | grep -E 'will be created|nat'
tofu apply
```

**Oodatav tulemus:** VPC, 2 alamvõrku, IGW, route table. **Plaanis ei ole** `aws_nat_gateway` ega `aws_eip`.
**Miks:** NAT gateway (~$1.1 päevas + andmed) on kõige tavalisem põhjus, miks kodutöö maksab oodatust rohkem.
**Tõend:** `tofu state list` väljund.

<!-- EKRAANIPILT: AWS konsool, VPC → Your VPCs → moodulist loodud VPC → vahekaart "Resource map", kohe pärast osa 2 `tofu apply`'d. Näha: VPC, kaks public subnet'i kahes AZ-s, üks route table, Internet gateway; NAT gateway veerg tühi.
<figure markdown="span">
  ![VPC Resource map: kaks avalikku alamvõrku, üks route table ja internet gateway, NAT gateway puudub](assets/kKT_k04-vpc-resource-map.png)
  <figcaption>Joonis 1. Moodulist loodud VPC ilma NAT gateway'ta.</figcaption>
</figure>
-->

**Mõtle:** Proxmoxis oli võrk (bridge, gateway) valmis ja sinu kood ainult kasutas seda. Siin lood võrgu ise.
Kumb on IS2-s (dev/staging/prod) mugavam ja miks?

## Osa 3 · SG-d rollide järgi

Lisa SG-d:

| SG | Sisse | Allikas |
|---|---|---|
| `ssh` (kõigil) | 22 | `var.my_ip` (`/32`) |
| `web` | 80 | `0.0.0.0/0` |
| `app` | 8080 | SG `web` |
| `db` / `cache` / `queue` | 3306 / 11211 / 5672 | SG `app` |

*Tabel 1. Security group'id ja nende sissetulevad reeglid.*

Kasuta ressurssi [`aws_vpc_security_group_ingress_rule`](https://search.opentofu.org/provider/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule)
(üks reegel = üks ressurss), mitte `ingress {}` plokke SG sees. Backendi kolm reeglit tee **ühe** `for_each`-iga
map'i `{ db = 3306, cache = 11211, queue = 5672 }` üle.

Lisa muutujale `my_ip` `validation`, mis keelab kõik peale `/32`.

**Oodatav tulemus:** `tofu plan` näitab 3 backendi reeglit ühest ressursiblokist. `my_ip = "0.0.0.0/0"` → plaan ebaõnnestub sinu veateatega.
**Miks SG-viited:** IP-d muutuvad iga uue masinaga, rollid mitte. Reegel "db01 lubab ainult app01" jääb õigeks ka siis, kui app01 on homme teine masin.

**Kui `apply` annab** `InvalidPermission.Duplicate`: samas SG-s on ka vana `ingress {}` plokk või käsitsi lisatud reegel. Vali üks viis.

## Osa 4 · Masinad sama map'iga

Proxmoxis oli `vms` map: `ip`, `distro`, `cores`, `memory`, `group`. AWS-is jäävad alles `distro` ja `group`. `ip`
asemel annab aadressi AWS ja `cores`/`memory` asemel on `instance_type`.

1. `variable "vms"`: samad võtmed (`db01` … `web01`), väärtustes `distro`, `group`, `instance_type`. Lisa `validation`, mis lubab ainult `t3.micro` ja `t3.small`.
2. AMI distro järgi: Ubuntu SSM parameetrist (`data "aws_ssm_parameter"`, vt 1. kohtumise kodutöö), Rocky `data "aws_ami"`-ga (vt 2. kohtumise kodutöö).
3. `aws_key_pair` sinu avalikust võtmest.
4. `aws_instance` `for_each = var.vms`: AMI ja SG grupi järgi, `root_block_device` gp3 10 GB, sildid `Name`, `Group`, `Distro`.

```bash
tofu apply
tofu output
```

**Oodatav tulemus:** viis masinat, `tofu output` näitab nime → avalik IP.
**Tõend:** `tofu output` + `aws ec2 describe-instances --filters Name=tag:Project,Values=labseis --query 'Reservations[].Instances[].Tags'`.

**Mõtle:** Proxmoxi koodis oli `user_account { username = "kasutaja" }`. AWS-is on kasutaja AMI-s (`ubuntu`, `rocky`).
Kus peab see erinevus nüüd sinu koodis olema?

## Osa 5 · Väljund → Ansible

Tee `inventory-aws.tftpl` 4. kohtumise labori `inventory.tftpl` põhjal, aga anna igale hostile `ansible_host` (avalik IP),
`ansible_user` (distro järgi) ja `private_ip`. `local_file` kirjutab selle faili `cloud/k04-aws/inventory-aws.ini`.
Lisa `inventory-aws.ini` `.gitignore`-i (selles on IP-d, need on ajutised).

```bash
tofu apply
cd ../../k02-ansible
ansible-playbook -i ../cloud/k04-aws/inventory-aws.ini site.yml --ask-vault-pass
curl -s "$(tofu -chdir=../cloud/k04-aws output -raw url)health"
```

**Oodatav tulemus:** `/health` → `UP`. Teine `ansible-playbook` → `changed=0`.
**Miks:** ahel on sama mis klassis: OpenTofu teeb masinad ja ütleb, kus need on; Ansible seadistab.

## Osa 6 · Drift

**6.1 Muudetud ressurss.** Muuda konsoolis web01 silti `Name` (nt `web01-kasitsi`).

```bash
tofu plan -detailed-exitcode; echo "exit=$?"
```

**Oodatav tulemus:** plaan tahab sildi tagasi muuta (`~ update in-place`), `exit=2`.

**6.2 Lisatud ressurss.** Lisa konsoolis SG-sse `web` uus reegel (443 kõigile) ja käivita sama käsk.

**Oodatav tulemus:** `No changes`, `exit=0`. Reegel jääb alles.
**Tõend:** mõlema `plan`-i viimane rida ja üks lause järeldust issue'sse.

??? info "Miks nii"
    OpenTofu võrdleb ainult ressursse, mis on tema state'is. Iga `aws_vpc_security_group_ingress_rule` on eraldi
    ressurss ja võõrast reeglit state'is pole. SG sees olev `ingress {}` plokk haldaks kogu reeglite nimekirja ja
    näeks lisandust.

**Mõtle:** kumba käitumist tahad tootmises: tööriista, mis kustutab kõik võõra, või tööriista, mis võõrast ei näe?
Kuidas leiaksid 6.2 tüüpi drift'i (vihje: `aws ec2 describe-security-group-rules` vs `tofu state list`)?

---

## State S3-s

Loo käsitsi bucket `labseis-tfstate-<sinu-github>` (versioning sees, avalik ligipääs blokeeritud), lisa
[`backend "s3"`](https://opentofu.org/docs/language/settings/backends/s3/) plokk ja `tofu init -migrate-state`.

## Koristus

```bash
tofu destroy
bash ../aws-leftovers.sh
```

**Oodatav tulemus:** `Destroy complete! Resources: N destroyed.` Leftovers: tasulisi jääke pole.
State bucket (kui tegid) võib jääda.

## Valmis, kui

- `tofu plan` pärast `apply`'d: `No changes`, `tofu state list | grep nat_gateway` on tühi
- `my_ip = "0.0.0.0/0"` → `tofu plan` ebaõnnestub sinu validatsiooni veateatega; backendi reeglid on ühest `for_each` ressursist
- pärast üht `tofu apply` + üht `ansible-playbook` annab `/health` → `UP`
- `tofu fmt -check` puhas, `git ls-files | grep -E 'tfvars$|tfstate'` on tühi
- `tofu destroy` tehtud, `aws-leftovers.sh`: `TULEMUS: tasulisi jääke pole`

## Lisaülesanne

Tee Proxmoxi ja AWS-i koodist üks moodul `modules/labseis-hosts` sisendiga `vms` ja väljundiga `hosts`
(`name → { public, private, user }`). Kaks juurkausta (`k04-tofu`, `cloud/k04-aws`) kasutavad sama inventory malli.
Kus on piir: mis on mooduli sees, mis on provideri-spetsiifiline?

## Veaotsing

Ühised vead (`UnauthorizedOperation`, aegunud `aws login`): [AWS-i reeglid](aws-reeglid.md#veaotsing).

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `tofu init` ei leia `hashicorp/aws` | klassi provider-mirror (`TF_CLI_CONFIG_FILE`) on sees | kodus `unset TF_CLI_CONFIG_FILE` |
| Rocky AMI `describe-images` tühi | konto ID või nimemuster muutunud | vt 2. kohtumise kodutöö osa 1 |
| `ansible` ei saa kohe pärast `apply`'d ühendust | masin bootib veel | `ansible all -m wait_for_connection` |
| `destroy` jääb SG kustutamisel ootama | käsitsi lisatud ENI või masin teises SG-s | vaata konsoolist, kes SG-d kasutab |
