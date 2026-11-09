---
tags:
  - veaotsing
---

# Abi: veaotsing

Read on praktikumi osade kaupa. Süvenemise ja lisaülesannete vead on IS2 lehel [Abi](https://hkhk-tk.github.io/is2-automatiseerimine/k04/abi/). Viimane veerg on mehhanism: selle järgi tunned vea ära ka siis, kui teade on teine.

| Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
|---|---|---|---|
| **1. Üks VM koodist** | | | |
| muutujad on pärast uut terminali kadunud | `env \| grep -c '^IS1_'` | `source` kehtib ainult selles shellis: lisa `source ~/.config/is1/proxmox.env` `~/.bashrc`-i lõppu | `proxmox.env` ei ole login-shelli failides |
| `401 authentication failure` | `echo ${PROXMOX_VE_API_TOKEN:+olemas}` | `proxmox.env` laadimata, token aegunud või tühistatud: `source …`, muidu koolitajale | provider saadab igas päringus tokeni; tühi või tühistatud token on Proxmoxi jaoks tundmatu kasutaja |
| `validate`: `Missing required provider` | `ls .terraform/providers` | `init` tegemata või `required_providers` muutus: `tofu init -upgrade` | `validate` vajab provider'i skeemi, et teada, millised argumendid on lubatud; skeem on binaaris, mille `init` alla laadib |
| output on `vms = []` | tag'ide kirjapilt, `echo $PROXMOX_VE_API_TOKEN` | token ei näe malli: `source` tegemata või tokenil puudub mallile `VM.Audit` | Proxmox tagastab ainult objektid, mida token tohib näha; puuduv õigus näeb välja nagu tühi tulemus, mitte viga |
| `validate`: `Incorrect attribute value type` | vea rida | string listi asemel, nt `tags = "test"` | HCL on tüübitud: provider'i skeem ütleb, et `tags` on list, ja `validate` võrdleb sinu väärtust skeemiga |
| `validate`: `Reference to undeclared resource` | viidatud nimi | data source'i või ressurssi sellise nimega koodis pole | viited lahendatakse koodi sees enne ühtki API kutset; nimi peab koodis olemas olema |
| `plan` OK, `apply` ebaõnnestub API veaga | node'i nimi, pool, storage | plaan ei pöördu API poole kõigi väärtuste jaoks, nt olematu `node_name` | plaan võrdleb koodi ja state'i; kas node on olemas, selgub alles kutsel, mis selle node'i peal midagi teeb |
| teine `plan` näitab alati `tags` | `tofu plan \| grep -A3 tags` | tag'id pole tähestiku järjekorras: `sort([...])` | Proxmox salvestab tag'id sorteeritult ja provider loeb need tagasi teises järjekorras kui sinu list |
| apply ootab 3 min agenti ja ebaõnnestub | UI → VM → Console | AlmaLinux + `qemu64`: pane `cpu.type = "x86-64-v2-AES"`; või VM ei käivitu | provider ootab, kuni agent teatab IP; kui masin ei käivitu, ei käivitu agent kunagi |
| ssh ei vasta, Tofu ütleb OK | Cloud-Init vahekaart, `cloud-init status` VM-is | cloud-init muudatus pärast loomist: `tofu apply -replace=…` | cloud-init loeb draivi ainult esimesel käivitusel; Tofu muutis draivi, mitte töötavat masinat |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | `ssh-keygen -F <ip>` | uus VM samal IP-l: `ssh-keygen -R <ip>` (ja nime jaoks) | host key tekib esimesel käivitusel; uus VM on uus masin ja `known_hosts` mäletab vana võtit |
| `file()`: `no such file` võtme juures | `ls ~/.ssh/id_ed25519.pub` | `file()` ei laienda `~`-i: `file(pathexpand(…))` | `~` on shelli laiendus; Tofu saab sõna otseses mõttes tee, mis algab märgiga `~` |
| konsoolis pole `SSH HOST KEY FINGERPRINTS` plokki | UI → Console, keri üles | boot on liiga ammu, konsooli puhver on täis | cloud-init väljastab sõrmejäljed ainult esimesel käivitusel; vaata VM-i sees `/var/log/cloud-init-output.log` |
| **2. Viis VM-i muutujatega** | | | |
| `Reference to undeclared input variable`, `Did you mean …` | `grep -n variable variables.tf` | nimi koodis ja `variables.tf`-is ei klapi: paranda nimi | muutuja peab olema deklareeritud enne, kui sellele viidatakse; Tofu pakub sarnaseima nime |
| `plan`: `vm_id … already exists` | UI pool | vana VM samal ID-l on alles või `test01` jäi kustutamata | `vm_id` on node'il unikaalne; state ei tea vanast VM-ist, Proxmox teab |
| 403 `Permission check failed (/storage/…, Datastore.AllocateSpace)` | veateate tee | tokenil puudub õigus: kopeeri teade koolitajale, ära vaheta storage'it | kloonimine loob uue ketta ja selleks on vaja õigust just sellele storage'ile |
| `git status` näitab `terraform.tfvars`-i või plaanifaili | `git check-ignore -v k04-tofu/terraform.tfvars` | `.gitignore`-is puudub rida; juba lisatud fail: `git rm --cached` | `.gitignore` mõjub ainult jälgimata failidele; kord lisatud faili jälgib Git edasi |
| `Output refers to sensitive values` | output'i `value` | output viitab tundlikule muutujale: lisa `sensitive = true` või eemalda output | `sensitive` levib igale väärtusele, mis sellest tuleb; Tofu ei näita seda kogemata |
| **3. Inventory Tofu väljundist** | | | |
| `ansible all -m ping`: `Host key verification failed` | käsurida, `grep host_key ../k02-ansible/ansible.cfg` | uued VM-id, uued võtmed: käivita `ANSIBLE_HOST_KEY_CHECKING=False`-iga või pane `ansible.cfg`-i `host_key_checking = False` | igal uuel VM-il on uus host key ja Ansible ei saa küsida, kas seda usaldada |
| `[webhosts]` grupp kadus | `head ../k02-ansible/inventory.ini` | ootuspärane: fail on nüüd genereeritud | Tofu kirjutab kogu faili template'ist üle; kõik, mida template'is pole, kaob |
| `local.groups` on tühi või vale | `echo 'local.groups' \| tofu console` | IP-d tulevad `var.vms`-ist, mitte VM-i ressursist, või vale võti | grupid peavad sõltuma VM-idest, et inventory tekiks pärast neid ja muutuks koos nendega |
| **4. Esitamine** | | | |
| automaatse hindaja `validate`: `init` ebaõnnestub `-lockfile=readonly`-ga | `git status`, `git log -1 -- k04-tofu/.terraform.lock.hcl` | lukufail on commit'imata või vananenud: `tofu providers lock -platform=linux_amd64` ja commit | readonly-režiim ei lase `init`-il lukufaili parandada; automaatne hindaja kasutab sama režiimi |
| tag `k04` on vanal commit'il | `git log --oneline -1 k04` | tag tehti enne merge'i või `pull`-i | tag viitab ühele commit'ile ega liigu koos haruga |
