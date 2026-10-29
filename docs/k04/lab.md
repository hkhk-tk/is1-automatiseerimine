---
tags:
  - OpenTofu
  - Proxmox
  - IaC
  - Ansible
---

# 4. kohtumine, labor: OpenTofu (Terraform) Proxmoxis

!!! info "Selle korra töö"
    - **Masin:** control node `ssh kasutaja@10.10.<nr>.10`, töökaust `~/labori-seis/k04-tofu`, märkmed `k04-tofu/NOTES.md`
    - **Sihtmasinad:** web01, app01, rmq01, mc01, db01 (lood ise koodist), Proxmoxi UI `https://<koolitaja antud aadress>:8006` (`<github>@pve`)
    - **Esitamine:** haru `k04-tofu` → PR → merge → tag `k04`
    - **Eelmisest korrast vaja:** `main`-is 2. kohtumise kaust `k02-ansible/` (`site.yml`, `ansible.cfg`, rollid, roll `common` ootab cloud-init'i), Vault'i parool
    - **Vaja koolitajalt:** `~/.config/is1/proxmox.env` (ajutine API token, kehtib 5. kohtumise eelõhtuni) ja `~/.config/is1/s3.env` control node'il, intsidendiülesande käivitamine
    - **Packer:** paigaldad golden image'i ülesandes control node'ile (HashiCorpi apt-repo), pluginad `hashicorp/proxmox` ja `hashicorp/ansible`
    - **Testitud:** OpenTofu 1.12.6 (S3 lukk `use_lockfile` vajab 1.10+), `bpg/proxmox` 0.115.x, `hashicorp/local` 2.5.x, Proxmox VE 8.x / 9.x, mallid Ubuntu 24.04 ja AlmaLinux 9 GenericCloud Base, S3 backend Garage; lisaülesannetes `kreuzwerker/docker` `~> 3.6`, `hashicorp/helm` `~> 3.0` (vanemates on `kubernetes` plokk), Terraform 1.7+ (`terraform test` koos `mock_provider`-iga), Conftest 0.62 (OPA 1.6); Packer koos pluginatega, Garage ja `hashicorp/kubernetes` kursuse VM-i versioonis
    - **Dokumentatsioon:** [OpenTofu](https://opentofu.org/docs/) · [bpg/proxmox provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) · [Packer](https://developer.hashicorp.com/packer/docs) · [Terraform](https://developer.hashicorp.com/terraform/docs) · [Proxmox VE](https://pve.proxmox.com/pve-docs/)

Koolitaja kustutas enne seda kohtumist sinu web01…db01, control node jäi alles. Kohtumise lõpuks on viis VM-i koodis, moodulis ja testitud, state on bucketis lukuga ning `./up.sh` tõstab Labori seisu nullist üles koos Ansible'i rollidega. Ubuntu masinad tulevad Packeriga ehitatud golden image'ist, kus roll `common` on juba sees. db01 on kustutamise eest kaitstud, käsitsi loodud VM on koodi alla toodud, drift on leitud ja otsustatud ning sa oled taastanud stacki, mille state ja tegelikkus läksid lahku.

Töö käib igas moodulis sama rütmiga: kirjutad ennustuse `NOTES.md`-sse, loed plaani, teed `apply` ja kontrollid tulemust teisest kohast kui Tofu ise (UI, VM-i sees, Ansible, `/health`). Mitu etappi on katsed, mille plaani ainult loed. Need näitavad, mida Tofu teeks, ilma et midagi katki läheks.

Iga moodul lõpeb commit'iga. Kui moodulil on GitHubis issue (milestone `K4`), lisa sõnumisse `closes #N`.

## Mis on kohustuslik

| Osa | Mis | Millal |
|---|---|---|
| Kohtumise ajal | [Üks VM koodist](lab-1-uks-vm.md), [Viis VM-i muutujatega](lab-2-viis-vmi.md), [Moodul, moved ja state](lab-3-moodul-state.md), [Üks käsk](lab-4-uks-kask.md) | laboris 11:30–15:00 |
| Võib lõpetada pärast kohtumist | [Elutsükkel ja kaitsed](lab-5-elutsukkel.md), [Import, drift ja keskkonnad](lab-6-import-drift.md), [Golden image Packeriga](lab-7-kuldne-mall.md), [Intsident: state ja tegelikkus](lab-8-intsident.md); `NOTES.md` ennustused ja otsused; [Esitamise](lab-9-esitamine.md) kontrollid uuesti pärast viimast commit'i | pärast kohtumist VPN-i kaudu, aga enne 5. kohtumist, sest siis token aegub; intsidendi muudatused teeb koolitaja sinu pool'is, nii et anna talle enne märku |
| Hindamise eeltingimus | tag `k04` `main`-i commit'il pärast merge'i ja GitHubis näha (`git ls-remote --tags origin`); automaatse hindaja kuus kontrolli on ka värskes kloonis `OK` ([Esitamine](lab-9-esitamine.md)) | esimene tag kohtumise lõpus; hilisem töö uue commit'iga ja `git tag -f k04` |

## Moodulid

1. [Üks VM koodist](lab-1-uks-vm.md): provider, data source, `test01` mallist, Task History, `~` vs `-/+`, cloud-init, `-replace` ja host key kontroll.
2. [Viis VM-i muutujatega](lab-2-viis-vmi.md): `variables`, `validation`, `for_each` ja VM-i identiteet, `count`-i lõks, avaldised `tofu console`-is, salvestatud plaan, output'id ja `sensitive`, `tofu test`.
3. [Moodul, moved ja state](lab-3-moodul-state.md): `modules/vm` ilma uuesti loomata, state S3-s, lukk ja mahajäänud luku vabastamine.
4. [Üks käsk](lab-4-uks-kask.md): inventory Tofu väljundist, `up.sh` ja selle kaitse proov, stack nullist ja `/health` UP.
5. [Elutsükkel ja kaitsed](lab-5-elutsukkel.md): `protection` ja kes seda näeb, `prevent_destroy`, `ignore_changes`, `create_before_destroy`, `check` ja `precondition`.
6. [Import, drift ja keskkonnad](lab-6-import-drift.md): käsitsi VM koodi alla, `-refresh-only` ja otsus, dev-workspace eraldi state'iga.
7. [Golden image Packeriga](lab-7-kuldne-mall.md): `labseis-base-<kuupäev>` koodist, proov dev-is, rmq01 uuel mallil enne teisi, Ubuntu masinad uuel mallil, malli ja cloud-init'i kaalumine.
8. [Intsident: state ja tegelikkus](lab-8-intsident.md): kolm lahknevust leitud, otsused ja kokkuvõte kirjas, plaan tühi.
9. [Esitamine](lab-9-esitamine.md): kontrollid, värske kloon, PR, tag `k04`, automaatse hindaja tulemus.

Veaotsing: [Abi](abi.md).
