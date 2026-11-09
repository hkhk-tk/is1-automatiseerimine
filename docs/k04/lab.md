---
tags:
  - OpenTofu
  - Proxmox
  - IaC
  - Ansible
---

# Praktikum: OpenTofu (Terraform) Proxmoxis

Kolmel eelmisel kohtumisel seadistasid masinaid, mille loomine polnud kuskil kirjas. Täna kirjeldad koodina ka masinate loomise. Koolitaja kustutas enne seda kohtumist sinu web01…db01, control node jäi alles. Kohtumise lõpuks loob OpenTofu muutujate põhjal viis VM-i ja kirjutab neist Ansible'i inventory, mille järgi Ansible jõuab kõigi viie masinani.

**Edenemine:** laboritahvel <http://is126.kaaren.lab.hkhk.lan> (VPN-iga).

Küsimused: [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions). Lisa küsimusele käsk ja kogu veateade tekstina. Enne saatmist eemalda paroolid ja tokenid.

??? tip "Algseis: mida saad valmis kujul ja mida teed ise"

    **Saad valmis kujul:** starteris tühja kausta `k04-tofu/` ja kausta `k02-ansible/`, kuhu Tofu kirjutab inventory. Starteri `.gitignore` hoiab state'i, `terraform.tfvars`-i, plaanifailid ja `.terraform/` kausta Gitist väljas. Koolitaja pani control node'ile faili `~/.config/is1/proxmox.env`, kus on ajutine API token ja sinu `IS1_*` väärtused. Token kehtib 5. kohtumise eelõhtuni. Proxmoxis on Ubuntu 24.04 ja AlmaLinux 9 mallid tag'iga `template`. Eelmiste kohtumiste tööd see praktikum ei vaja: alustad harust `main`.

    **Teed ise:** kirjutad kaustas `~/kursus/k04-tofu` OpenTofu koodi, mis loob kõigepealt ühe VM-i ja siis muutujate põhjal viis, kirjutad Tofu väljundist Ansible'i inventory ja esitad töö harust `k04-tofu` PR-i ja tag'iga `k04`. Proxmoxi UI-s (`https://<koolitaja antud aadress>:8006`, kasutaja `<github>@pve`) näed, mida kood lõi. Ülesanded on repositooriumi issue's `K4`.

    **Kui midagi läks katki:** `git restore <fail>` toob faili tagasi viimase commit'i kujul. `tofu destroy` kustutab kõik VM-id, mille kood lõi, ja järgmine `tofu apply` loob need uuesti. Kui `apply` ütleb `vm_id ... already exists`, on samal ID-l vana VM alles: vaata Proxmoxi UI-s oma pool'i.

??? abstract "Õpiväljundid"

    1. Kirjutad OpenTofu koodi, mis leiab malli data source'iga ja loob sellest VM-i koos cloud-init'i võrgu ja SSH-võtmega.
    2. Loed enne `apply`-d plaanist, kas VM muudetakse kohapeal (`~`) või tehakse uuesti (`-/+`).
    3. Kirjeldad viit VM-i muutujate ja `for_each`-iga ning annad nende IP-d output'iga välja.
    4. Genereerid Tofu väljundist Ansible'i inventory ja kontrollid Ansible'iga, et kõik viis masinat vastavad.
    5. Kontrollid töö automaatkontrolli testidega ja esitad selle.

??? info "Testitud versioonid ja dokumentatsioon"

    OpenTofu 1.12.6, `bpg/proxmox` 0.115.x, `hashicorp/local` 2.5.x, Proxmox VE 8.x / 9.x, mallid Ubuntu 24.04 ja AlmaLinux 9 GenericCloud Base.

    [OpenTofu](https://opentofu.org/docs/) · [bpg/proxmox provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) · [Terraform](https://developer.hashicorp.com/terraform/docs) · [Proxmox VE](https://pve.proxmox.com/pve-docs/)

Iga osa käib sama rütmiga: kirjutad koodi, **ennustad**, mida plaan näitab, loed plaani, teed `apply` ja kontrollid tulemust mujalt kui Tofust (Proxmoxi UI, `ssh`, Ansible). Kui juhendis on **Ennusta:**, mõtle vastus enne käsu käivitamist läbi ja võrdle siis tulemusega.

## Osad

1. [Üks VM koodist](lab-1-uks-vm.md): provider, data source, `test01` mallist, `~` ja `-/+`, cloud-init, `-replace` ja host key kontroll.
2. [Viis VM-i muutujatega](lab-2-viis-vmi.md): failid ja muutujad, `for_each`, output'id ja `sensitive`.
3. [Inventory Tofu väljundist](lab-4-uks-kask.md): `templatefile()`, `local_file` ja Ansible'i `ping` viiele masinale.
4. [Esitamine](lab-9-esitamine.md): kontrollid, PR, tag `k04` ja automaatkontrolli tulemus.

Veaotsing: [Abi](abi.md).

Kursusel IS2 jätkub sama kood: [süvenemine](https://hkhk-tk.github.io/is2-automatiseerimine/k04/syvenemine/) (`validation`, `tofu test`, skript `up.sh`), [moodul ja state S3-s](https://hkhk-tk.github.io/is2-automatiseerimine/k04/lab-3-moodul-state/), [elutsükkel ja kaitsed](https://hkhk-tk.github.io/is2-automatiseerimine/k04/lab-5-elutsukkel/), [import ja drift](https://hkhk-tk.github.io/is2-automatiseerimine/k04/lab-6-import-drift/), [golden image Packeriga](https://hkhk-tk.github.io/is2-automatiseerimine/k04/lab-7-kuldne-mall/), [intsident](https://hkhk-tk.github.io/is2-automatiseerimine/k04/lab-8-intsident/), [lisaülesanded](https://hkhk-tk.github.io/is2-automatiseerimine/k04/lisa/) ja [AWS-i kodutöö](https://hkhk-tk.github.io/is2-automatiseerimine/kodutood/k04-aws/).
