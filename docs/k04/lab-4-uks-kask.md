---
tags:
  - OpenTofu
  - Ansible
  - Bash
---

# 3. Inventory Tofu väljundist

Tofu teab, millised masinad on olemas, Ansible teab, mis on nende sees, ja nende vahel oled praegu sina: kopeerid IP-d käsitsi Ansible'i inventory'sse. Nüüd ühendab need fail: Tofu kirjutab Ansible'i inventory oma väljundist. Lõpuks jõuab Ansible kõigi viie masinani faili järgi, mida keegi käsitsi ei kirjutanud.

**Kui teed seda tööl iga päev:** kaustas `k02-ansible` vastab `ansible all -m ansible.builtin.ping -o` viiest hostist Tofu genereeritud `inventory.ini`-ga. Kui see on sul juba korras, mine otse etappi „[Commit](#commit)“.

## Genereeri inventory Tofu väljundist

Esimesena kaob käsitsi hallatav IP-de nimekiri. IP-d on nüüd kirjas ainult `terraform.tfvars`-is. 1. kohtumise `hosts` ja 2. kohtumise `inventory.ini` olid sama info käsitsi koopiad. Tofu kirjutab inventory ise VM-ide andmetest.

Nõuded:

- `inventory.tftpl` Tofu template'i süntaksiga (`%{ for … }`, mitte Jinja): esimene rida on kommentaar, et fail on genereeritud ja käsitsi ei muudeta; iga grupi all read `nimi ansible_host=IP`
- grupid `db`, `cache`, `queue`, `app`, `web` ja distro järgi `ubuntu`, `alma`; `local.groups` (grupp → { nimi → IP }) arvutatakse `locals.tf`-is **VM-i ressursist** (`proxmox_virtual_environment_vm.lab`), sama avaldisega, mida kasutab output `hosts`
- muutuja `inventory_path` vaikeväärtusega `"../k02-ansible/inventory.ini"` (IS2 dev-keskkond vajab oma faili)
- `inventory.tf`-is `local_file`, mis kirjutab `templatefile()` tulemuse sellele teele

```hcl
resource "local_file" "inventory" {
  filename = "${path.module}/${var.inventory_path}"
  content  = templatefile("${path.module}/inventory.tftpl", { groups = local.groups })
}
```

1. Proovi `local.groups` enne `apply`-d konsoolis, siis kirjuta fail.

    ```bash
    echo 'local.groups' | tofu console
    tofu apply
    git diff ../k02-ansible/inventory.ini
    ```

2. Vaata, kas Ansible jõuab kõigini.

    ```bash
    cd ../k02-ansible
    ANSIBLE_HOST_KEY_CHECKING=False ansible all -i inventory.ini -u kasutaja -m ansible.builtin.ping -o
    ansible-inventory -i inventory.ini --graph
    ```

Kui kaustas oli 2. kohtumise käsitsi kirjutatud `inventory.ini`, kirjutab Tofu selle üle. 1. kohtumise grupp `[webhosts]` kadus failist: see on ootuspärane, `web.yml`-i käivitad vajadusel `-i`-ga eraldi. `ANSIBLE_HOST_KEY_CHECKING=False` lubab ühenduse uute masinatega, mille host key'd pole veel `known_hosts`-is.

Kuna `local.groups` tuleb VM-i ressursist, sõltub `local_file` kõigist viiest VM-ist. Tofu kirjutab inventory alles siis, kui masinad on olemas, ja kirjutab selle uuesti, kui mõni IP muutub. `git diff` näitab, kui palju käsitsi faili ja genereeritud faili vahel tegelikult erines.

> `Host key verification failed`: uued masinad, uued võtmed. Käivita käsk `ANSIBLE_HOST_KEY_CHECKING=False`-iga või pane `k02-ansible/ansible.cfg`-i `host_key_checking = False`.

**Edasi saad minna, kui** `inventory.ini` esimene rida ütleb, et fail on genereeritud, puus on seitse gruppi ja viis hosti vastavad `SUCCESS`.

## Commit

Commit'i läheb ka `k02-ansible/` kausta genereeritud inventory. Nii on Gitis näha, et inventory on Tofu toode.

Genereeritud fail Gitis tundub üleliigne, aga see näitab PR-is täpselt, milline IP muutus. Kui fail on Gitist väljas, näeb ülevaataja ainult `tfvars`-i muutust, mida ta ei saa kontrollida.

```bash
cd ~/kursus
tofu -chdir=k04-tofu fmt -recursive
git add k04-tofu k02-ansible/inventory.ini
git commit -m "k04: inventory Tofu väljundist"
git push
```

`resources` kontroll otsib muu hulgas `local_file`-i, `templatefile()`-i ja teed `k02-ansible/inventory.ini`. `files` kontroll vaatab, et `inventory.tftpl` ja lukufail on olemas ning state ja `tfvars` on Gitist väljas.

**Edasi saad minna, kui** `bash autograde/check.sh k04 resources` ja `bash autograde/check.sh k04 files` annavad `OK`.

Kui jõudsid kiiremini: IS2 [süvenemise osa 3](https://hkhk-tk.github.io/is2-automatiseerimine/k04/syvenemine/#osa-3-uks-kask-inventory-ansible-ja-upsh) kirjutab skripti `up.sh`, mis loob Tofu ja Ansible'iga kogu Labori seisu tühjast pool'ist. [Lisaülesanne 10. Plaani kokkuvõte pipeline'i jaoks](https://hkhk-tk.github.io/is2-automatiseerimine/k04/lisa/#10-plaani-kokkuvote-pipelinei-jaoks) näitab ülevaatajale ühe vaatega, mida plaan kustutab.
