---
tags:
  - AWS
  - Kodutöö
---

# Pilve kodutööd (AWS) · üldjuhend

Kodutööd on valikulised ja mõeldud neile, kes tahavad sama lahendust pilves proovida. Klassis töötad Proxmoxis, kodutöös viid **sama koodi** oma AWS-i kontole: samad
Ansible'i playbook'id ja rollid, sama Dockerfile, sama OpenTofu struktuur, sama pipeline, samad manifestid. Igas kodutöös
on sama küsimus: *milline osa minu koodist eeldab Proxmoxi ja kuidas selle eelduse muutujaks muuta?*

Kodutöö eeldab sama kohtumise praktikumi. Kui praktikum jäi pooleli, lõpeta see enne kodutööd (kodust pääsed laborisse VPN-iga).
Konto, regioon, kulu, võtmed ja koristus: **[AWS-i reeglid](aws-reeglid.md)**.

| Kohtumine | Kodutöö | Tulemus | Juhend |
|---|---|---|---|
| 1 | konto ja ohutus, sama playbook EC2-l | IAM-kasutaja, eelarvehäired, `training.yml` EC2-l `changed=0` | [k01-aws.md](k01-aws.md) |
| 2 | samad rollid EC2-l | EC2 grupis `veeb`, `site.yml` teine käivitus `changed=0` | [k02-aws.md](k02-aws.md) |
| 3 | image ECR-i, Compose EC2-l | Compose EC2-l, app01 image ECR-ist | [k03-aws.md](k03-aws.md) |
| 4 | VPC + SG + EC2 OpenTofuga, väljund → Ansible | üks `apply` + playbook → `UP` | [k04-aws.md](k04-aws.md) |
| 5 | GitHub Actions: ECR push ja deploy kinnitusega | kinnitatud deploy, `/version` = SHA | [k05-aws.md](k05-aws.md) |
| 6 | Jenkins: image ECR-i ja deploy EC2-le | `input`-iga deploy, võti agendil | [k06-aws.md](k06-aws.md) |
| 7 | k3s EC2-l, samad manifestid | Labori seis k3s-is, rollback töötab | [k07-aws.md](k07-aws.md) |

*Tabel 1. Kodutööd kohtumiste kaupa.*


## Kuhu kood läheb

Kursuse repositooriumis on kaust `cloud/`:

```text
cloud/
  aws-leftovers.sh      # koristuse kontroll (starteris olemas, ära muuda)
  k01-aws/              # K1 kodutöö failid
  k02-aws/ … k07-aws/
```

Sulge kodutöö issue commit'iga (`closes #N`) ja lisa issue'sse kommentaar, milles on `aws-leftovers.sh` väljundi viimane
rida ja juhendis nõutud tõend (kuvatõmmis või käsu väljund). Kodutööle tag'i ei panda, sest automaatne hindaja pilveressursse ei kontrolli.
