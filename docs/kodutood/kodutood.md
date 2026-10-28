---
tags:
  - AWS
  - Kodutöö
---

# Pilve kodutööd (AWS) · üldjuhend

Valikuline, neile, kes tahavad sama asja pilves proovida. Klassis töötad Proxmoxis, kodutöös viid **sama koodi** AWS-i oma kontole: samad
Ansible'i playbook'id ja rollid, sama Dockerfile, sama OpenTofu struktuur, sama pipeline, samad manifestid. Küsimus on igas kodutöös
sama: *mis osa minu koodist eeldas Proxmoxi ja kuidas ma selle eelduse parameetriks teen?*

Eeldus on sama kohtumise Proxmoxi labor. Kui labor jäi pooleli, lõpeta see enne (VPN-iga kodust).
Konto, regioon, kulu, võtmed ja koristus: **[AWS-i reeglid](aws-reeglid.md)**.

| Kohtumine | Kodutöö | Tulemus | Juhend |
|---|---|---|---|
| 1 | konto ja ohutus, sama playbook EC2-l | IAM-kasutaja, eelarvehäired, `training.yml` EC2-l `changed=0` | [k01-aws.md](k01-aws.md) |
| 2 | Labori seis viiel EC2-l Ansible'iga, dünaamiline inventory | `/health` `UP` viiel EC2-l | [k02-aws.md](k02-aws.md) |
| 3 | image ECR-i, Compose EC2-l | Compose EC2-l, app01 image ECR-ist | [k03-aws.md](k03-aws.md) |
| 4 | VPC + SG + EC2 OpenTofuga, väljund → Ansible | üks `apply` + playbook → `UP` | [k04-aws.md](k04-aws.md) |
| 5 | GitHub Actions: ECR push ja deploy kinnitusega | kinnitatud deploy, `/version` = SHA | [k05-aws.md](k05-aws.md) |
| 6 | Jenkins: image ECR-i ja deploy EC2-le | `input`-iga deploy, võti agendil | [k06-aws.md](k06-aws.md) |
| 7 | k3s EC2-l, samad manifestid | Labori seis k3s-is, rollback töötab | [k07-aws.md](k07-aws.md) |

*Tabel 1. Kodutööd kohtumiste kaupa.*


## Kuhu kood läheb

Sinu kursuse repos on kaust `cloud/`:

```text
cloud/
  aws-leftovers.sh      # koristuse kontroll (starteris olemas, ära muuda)
  k01-aws/              # K1 kodutöö failid
  k02-aws/ … k07-aws/
```

Sulge kodutöö issue commit'iga (`closes #N`) ja lisa issue'sse kommentaar: `aws-leftovers.sh` väljundi viimane
rida ja tõend, mida juhend küsib (screenshot või käsu väljund). Tag'i ei pane, automaatne hindaja pilve ei kontrolli.
