---
tags:
  - Kursuse ülevaade
hide:
  - navigation
---

# IT-infrastruktuuri automatiseerimine I

Linuxi käsitsi haldusest korratava, kontrollitava ja Gitis hoitava automaatikani.

!!! tip "Alusta siit"

    1. **[Töökeskkonna ettevalmistus](00-ulevaade/keskkond.md):** VPN ja VS Code (Windows, macOS, Linux).
    2. **GitHub:** võta vastu e-postiga tulnud kutse orgi `hkhk-tk`. Kui sul GitHubi kontot pole, loo see kooli e-postiga.
    3. **Esimene kohtumine:** [loeng](k01/loeng.md) · [praktikum](k01/lab.md) · [kodutöö](k01/kodutoo.md)

| | |
|---|---|
| **Aeg** | 7 laupäeva, 10:00–15:00 |
| **Eeldused** | Linuxi käsurida, failid ja õigused, SSH. Programmeerimist ei eeldata |
| **Keskkond** | kooli Proxmoxis sinu control node ja viis labori VM-i, kasutaja `kasutaja`; ühendus VS Code'iga, kodust VPN-iga |
| **Küsimused ja teated** | [is126-arutelu](https://github.com/hkhk-tk/is126-arutelu/discussions) |
| **Koolitajad** | Maria Talvik, Rain Koor |

## Kohtumised

| | Teema | Materjal |
|---|---|---|
| **1** | Linuxi haldusest automatiseerimiseni: käsitsi → Bash → Ansible | [loeng](k01/loeng.md) · [praktikum](k01/lab.md) · [kodutöö](k01/kodutoo.md) |
| **2** | Ansible: mitu masinat, muutujad, rollid | tuleb |
| **3** | Konteinerid: Docker ja Podman | tuleb |
| **4** | Taristu koodina: OpenTofu (Terraform) | tuleb |
| **5** | CI/CD: GitHub Actions | tuleb |
| **6** | Jenkins, SonarQube ja Nexus | tuleb |
| **7** | Kubernetes ja GitOps | tuleb |

## Kuidas töö käib

Iga kohtumine on loeng, praktikum ja lühike kodutöö. Töö on sinu GitHubi repos, automaatne hindaja kontrollib seda iga `git push`-i järel. Täpsemalt: [Töö repos ja hindamine](00-ulevaade/too-ja-hindamine.md).

Paroole, võtmeid ega tokeneid Giti ei panda.
