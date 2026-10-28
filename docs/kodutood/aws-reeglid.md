---
tags:
  - AWS
  - Kodutöö
---

# AWS-i reeglid

## Konto ja kulu

| Reegel | Miks |
|---|---|
| Oma konto, **[Free plan](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html)** | Free planil kaardilt raha ei võeta. Kui krediit ($100 + kuni $100) või 6 kuud saab otsa, konto suletakse. Paid planil hakatakse pärast krediiti kaarti debiteerima. |
| Ära liitu AWS Organizationsiga ega vajuta "Upgrade plan" | Mõlemad muudavad konto tasuliseks. Kodutöödes kasutatavad teenused on Free planil olemas. |
| Ainult **eu-north-1** | Unustatud masinad on siis ühes regioonis, mitte viies. Koristusskript vaatab eu-north-1 ja us-east-1. |
| Ainult t3.micro ja t3.small | [Free Tier eligible](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html), x86 (Labori seisu image on amd64). |
| Kaks eelarvehäiret: zero spend ja $10 kuus | Zero spend teavitab esimesest tasulisest kasutusest, $10 annab märku, kui midagi jäi tööle. Seadistad 1. kohtumise kodutöö osas 1.3. |
| Igal masinal silt `Project=labseis` | Koristus ja `aws-leftovers.sh` leiavad masinad sildi järgi. |

*Tabel 1. Konto ja kulu reeglid.*

Koolitaja ei vastuta sinu AWS-i arvete eest. Kui kahtled, tee kodutööst dry run: kirjuta kood, käivita `tofu plan`
või `--check`, aga ära loo ressursse.

| Ressurss | ~ $/h | Märkus |
|---|---:|---|
| t3.micro / t3.small | 0.011 / 0.022 | töötab ka siis, kui sa ei kasuta; peatatud masina ketas maksab edasi |
| avalik IPv4 | 0.005 | iga avaliku IP eest, ka vaba Elastic IP |
| NAT gateway | 0.046 + andmed | kodutöödes **mitte luua** |
| Load balancer (ALB) | 0.024 + LCU | kodutöödes **mitte luua** |
| EKS | 0.10 | kodutöödes **mitte luua**, kasutame k3s-i |

*Tabel 2. Ligikaudsed tunnihinnad eu-north-1-s. Täpse hinna annab [AWS Pricing Calculator](https://calculator.aws/).*

Kõik seitse kodutööd kokku jäävad alla $2, kui koristad samal õhtul. Viis unustatud t3.micro masinat maksavad
nädalaga ~$13.

## Kasutajad, võtmed ja saladused

| Reegel | Miks |
|---|---|
| Igapäevane töö IAM-kasutajana, root-il MFA ja access key'd puuduvad | Rooti ei saa õigustega piirata ega auditeerida. Root on ainult arvete ja konto sulgemise jaoks. |
| Control node'il `aws login` (CLI ≥ 2.32), mitte `~/.aws/credentials` | Sessioon aegub ise ja kettal pole midagi, mis lekiks. Seadistad 1. kohtumise kodutöö osas 1.5. |
| Pikaajalisi võtmeid ainult 5. ja 6. kohtumise kodutöös, ainult ECR push | Kui võti lekib, peab see olema väärtusetu. Kodutöö lõpus võti kustutatakse. |
| EC2 saab õigused IAM rollist, mitte võtmest | Ajutised võtmed tulevad metaandmete teenusest, kettal pole midagi. |
| Saladused ei lähe Giti | Automaatse hindaja kontroll `cloud/secrets` annab hoiatuse. |

*Tabel 3. Kasutajate ja võtmete reeglid.*

Lisa `.gitignore`-i (kui starteris pole):

```gitignore
*.pem
*_accessKeys.csv
*.tfstate
*.tfstate.*
.terraform/
terraform.tfvars
kubeconfig*
k3s.yaml
```

## Iga kodutöö alguses

```bash
aws sts get-caller-identity          # Arn lõpeb :user/<sinu-iam-kasutaja>, mitte :root
aws configure get region             # eu-north-1
```

## Iga kodutöö lõpus

1. Kustuta selle kodutöö ressursid (kodutöö osa "Koristus").
2. Käivita kontroll:

   ```bash
   bash cloud/aws-leftovers.sh
   ```

   **Oodatav tulemus:** viimane rida `TULEMUS: tasulisi jääke pole`. `INFO` read (ECR repo, S3 bucket, VPC ilma
   masinateta) võivad jääda.
   **Kui exit on 2:** mõni päring ebaõnnestus (õigused, võrk). Siis pole tulemus usaldusväärne, vaata `VIGA` rida.
3. Billing → **Free plan** kaart: krediidi jääk. Märgi see üles, siis näed järgmisel korral, palju kodutöö maksis.

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| `Unable to locate credentials` või `ExpiredToken` | `aws login` sessioon aegus (ka poole käsu pealt) | [`aws login --remote --profile labseis-login`](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html) |
| `UnauthorizedOperation` | vale profiil või aegunud sessioon | `echo $AWS_PROFILE`, `aws sts get-caller-identity` samas shellis |
| SSH timeout või Ansible `UNREACHABLE` kõigil | SG 22 on vanale IP-le (kodu IP muutub) | `curl -s https://checkip.amazonaws.com`, uuenda SG reeglit |
| brauser või `curl` timeout, SSH töötab | SG-s pole teenuse porti sinu IP-le | lisa reegel |
| masin või muu ressurss on `us-east-1`-s | konsooli region oli vale | kustuta seal, `aws-leftovers.sh` vaatab ka seda regiooni |
| `aws-leftovers.sh` exit 2 | päring ebaõnnestus (õigused, võrk) | vaata `VIGA` rida, käivita uuesti |

*Tabel 4. Kõigi kodutööde ühine veaotsing.*
