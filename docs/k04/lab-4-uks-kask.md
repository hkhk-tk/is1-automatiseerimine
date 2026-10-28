---
tags:
  - OpenTofu
  - Ansible
  - Bash
---

# 4. Üks käsk

Tofu teab, millised masinad on olemas, Ansible teab, mis on nende sees, ja nende vahel oled praegu sina: kopeerid IP-d, ootad boodi ära, sisestad Vault'i parooli. Nüüd ühendab need fail: Tofu kirjutab Ansible'i inventory oma väljundist. Lõpuks tõstab skript `up.sh` Labori seisu tühjast pool'ist üles nii, et vahepeal ei pea midagi käsitsi tegema, ja kogu Labori seis on koodis.

Enne alustamist peab `jq -r .backend.type .terraform/terraform.tfstate` andma `s3`.

**Kui teed seda tööl iga päev:** kaustas `k02-ansible` vastab `ansible all -m ansible.builtin.ping -o` viiest hostist Tofu genereeritud `inventory.ini`-ga, `tofu test` sisaldab inventory kontrolli ja `ansible-vault view` ei küsi parooli. Kui see on sul juba korras, mine otse etappi „[Kirjuta up.sh](#kirjuta-upsh)“.

## Genereeri inventory Tofu väljundist

Esimesena kaob käsitsi hallatav IP-de nimekiri. IP-d on nüüd kirjas ainult `terraform.tfvars`-is. 1. kohtumise `hosts` ja 2. kohtumise `inventory.ini` olid sama info käsitsi koopiad. Tofu kirjutab inventory ise mooduli väljunditest.

Nõuded:

- `inventory.tftpl` Tofu template'i süntaksiga (`%{ for … }`, mitte Jinja): esimene rida on kommentaar, et fail on genereeritud ja käsitsi ei muudeta; iga grupi all read `nimi ansible_host=IP`
- grupid `db`, `cache`, `queue`, `app`, `web` ja distro järgi `ubuntu`, `rocky`; `local.groups` (grupp → { nimi → IP }) arvutatakse `locals.tf`-is **mooduli väljunditest**
- muutuja `inventory_path` vaikeväärtusega `"../k02-ansible/inventory.ini"` (dev-keskkond vajab hiljem oma faili)
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
    cd ../k02-ansible && ansible all -m ansible.builtin.ping -o
    ansible-inventory --graph
    ```

1. kohtumise grupp `[webhosts]` kadus failist: see on ootuspärane, `web.yml`-i käivitad vajadusel `-i`-ga eraldi.

Kuna `local.groups` tuleb mooduli väljunditest, sõltub `local_file` kõigist viiest VM-ist. Tofu kirjutab inventory alles siis, kui masinad on olemas, ja kirjutab selle uuesti, kui mõni IP muutub. `git diff` näitab, kui palju käsitsi faili ja genereeritud faili vahel tegelikult erines.

> `Host key verification failed`: uued masinad, uued võtmed. `k02-ansible/ansible.cfg`-is peab olema `host_key_checking = False`.

✅ **Edasi saad minna, kui** `inventory.ini` esimene rida ütleb, et fail on genereeritud, puus on seitse gruppi ja viis hosti vastavad `SUCCESS`.

## Muuda inventory't käsitsi ja vaata, mis juhtub

Faili esimene rida ütleb, et seda ei muudeta käsitsi. Siin teed seda ikkagi ja vaatad, kas Tofu märkab. Nii tead, mis juhtub, kui kolleeg "kiiresti parandab" ühe IP.

Käsitsi parandus genereeritud failis elab ainult järgmise `apply`-ni. Kui keegi seda ei tea, tuleb viga tagasi täpselt siis, kui keegi midagi muud muudab.

1. Lisa `../k02-ansible/inventory.ini` lõppu rida `[proov]` ja `proov01 ansible_host=10.10.<nr>.99`, siis vaata plaani.

    ```bash
    tofu plan | grep -E '^\s+#|Plan:'
    ```

2. Kirjuta `NOTES.md`-sse, mida plaan tahab teha, siis `tofu apply` ja `tail -3 ../k02-ansible/inventory.ini`.

Provider võrdleb faili sisu state'is oleva kontrollsummaga. Kui need ei klapi, peab ta faili kadunuks ja plaanib selle uuesti luua. Pärast `apply`-d on sinu rida läinud. See on õige käitumine: source of truth on `terraform.tfvars`, mitte fail.

✅ **Edasi saad minna, kui** plaan tahtis `local_file.inventory` uuesti luua, pärast `apply`-d pole failis `proov01` rida ja `NOTES.md`-s on selgitus.

## Lisa testi inventory kontroll

`tofu test` teab nüüd ka inventory't. Siin lisad testi, mis kontrollib template'i väljundit ilma ühtki faili kirjutamata.

Template'is on kõige lihtsam teha viga, mida keegi ei näe: puuduv reavahetus, vale grupi nimi või tühi grupp. Ansible jätab sellised hostid vaikselt vahele.

Lisa `tests/vms.tftest.hcl`-i:

- faili tasemel `variables`-isse `inventory_path = "build/inventory-test.ini"`, et test ei puutuks Ansible'i inventory't
- `run "inventory_grupid"` (`command = plan`): `assert`, et `local_file.inventory.content` sisaldab `"[db]\ndb01 ansible_host=…"` ja sama `[rocky]` grupi all

```bash
cd ~/labori-seis/k04-tofu
tofu test
```

Test kontrollib täpset teksti koos reavahetusega, mitte ainult seda, et kuskil on sõna `db01`. Nii ebaõnnestub test ka siis, kui host on vale grupi all. `command = plan` tähendab, et `local_file` ei kirjutanud midagi kettale: sisu arvutati, aga faili ei tekkinud.

✅ **Edasi saad minna, kui** `tofu test` näitab ka `inventory_grupid… pass`.

## Valmista Ansible ette jooksuks ilma inimeseta

Skript ei saa vastata küsimustele ega oodata, kuni sa näed, et masin on üleval. Kontrollid, et Ansible ootab cloud-init'i ise ja et Vault avaneb ilma parooli küsimata.

Värske VM, kus cloud-init veel paigaldab pakette, hoiab apt-i lukku. Ansible'i esimene `apt` ebaõnnestub siis lukuvea peale ja jätab poolikult seadistatud masina.

1. Leia, kus Ansible'i kood ootab cloud-init'i ja SSH-d.

    ```bash
    grep -n 'cloud-init status' ../k02-ansible/roles/common/tasks/main.yml
    grep -n 'wait_for_connection' ../k02-ansible/site.yml
    ```

2. Pane Vault'i parool faili `~/.vault_pass` (õigused 600, väljaspool repot) ja lisa `ansible.cfg`-i `[defaults]` alla `vault_password_file = ~/.vault_pass`.
3. Proovi, et Vault avaneb küsimata: `ansible-vault view ../k02-ansible/group_vars/all/vault.yml | head -2`

`wait_for_connection` ootab, kuni SSH vastab. `cloud-init status --wait` ootab, kuni masin on ise valmis. Need on kaks eri asja: SSH võib vastata minuteid enne, kui cloud-init on lõpetanud. Paroolifail väljaspool repot tähendab, et Gitis on ainult krüpteeritud Vault ja võtit seal pole.

> Kui `site.yml`-is pole `wait_for_connection`-i, lisa esimesele play'le `gather_facts: false`, `pre_tasks`-i `ansible.builtin.wait_for_connection` ja siis `ansible.builtin.setup`.

✅ **Edasi saad minna, kui** mõlemad `grep`-id leiavad rea ja `ansible-vault view` ei küsi parooli.

## Kirjuta up.sh

Nüüd kirjutad skripti, mis ühendab Tofu, Ansible'i ja `/health` health check'i üheks käsuks. Skripti sisuline osa on see, millal skript keeldub. `tofu apply -auto-approve && ansible-playbook site.yml` töötab, kuni keegi muudab `terraform.tfvars`-is malli ja skript kustutab kõik viis VM-i küsimata.

Kontroll plaanifailis on sama, mida sina teed silmaga: loed enne `destroy` read.

Kirjuta `k04-tofu/up.sh`, mis:

- töötab `set -euo pipefail`-iga, läheb ise oma kausta ja keeldub, kui `tofu workspace show` pole `default`
- teeb plaani faili (`-out`, `-detailed-exitcode`: 0 muudatusi pole, 2 on muudatusi, 1 viga) ja kustutab selle `trap`-iga
- loeb `tofu show -json <plaan>`-ist `jq`-ga, mitu Proxmoxi ressurssi (`type` algab `proxmox_`) kustutatakse, ja lõpetab koodiga 1, kui neid on üle nulli ja `ALLOW_DESTROY=1` pole antud; `local_file` jääb loendist välja, sest inventory asendub iga sisu muutusega
- teeb `apply` **samast** plaanifailist, käivitab `ansible-playbook site.yml` kaustas `k02-ansible` ja ootab, kuni `http://<web01>/health` vastab (IP `tofu output -json hosts`-ist)
- läbib `shellcheck -S warning`

```bash
chmod +x up.sh && shellcheck -S warning up.sh
./up.sh; echo "kood $?"
```

Teine käivitus peab ütlema, et taristu klapib, ja Ansible peab andma `changed=0`.

Teine käivitus kontrollib kahel tasemel korraga, kas kõik on idempotentne. Tofu ütleb, et masinad klapivad koodiga, Ansible ütleb, et masinate sisu klapib rollidega. Kui üks neist annab muudatuse, on kuskil samm, mis teeb midagi iga kord, ja see tuleb leida enne, kui skript läheb pipeline'i.

✅ **Edasi saad minna, kui** ShellCheck vaikib, `./up.sh` lõpeb koodiga 0 ja väljastab `/health` JSON-i.

## Proovi up.sh kaitset

Siin teed muudatuse, mis asendaks ühe VM-i, ja vaatad, kas `up.sh` keeldub. `ALLOW_DESTROY`-d ei anna.

Kõige tavalisem põhjus ootamatuks asenduseks on muudatus, mis näeb välja süütu: teine mall, teine ketta liides, teine `vm_id`. Kui skript keeldub, saab inimene enne otsustada.

1. Pane `terraform.tfvars`-is mc01-le `distro = "ubuntu"` ja käivita skript.

    ```bash
    ./up.sh; echo "kood $?"
    tofu plan | grep -E 'forces replacement|Plan:'
    ```

2. Pane `distro = "rocky"` tagasi ja kontrolli, et `./up.sh` ütleb jälle, et taristu klapib.

Skript väljastas, et plaanis on üks kustutamine, ja lõpetas koodiga 1, enne kui `apply` või Ansible käivitus. Teine käsk näitab põhjust: mall on `clone` plokis ja selle muutus nõuab asendust. Proxmoxis ei muutunud midagi, plaanifail kustutati `trap`-iga.

✅ **Edasi saad minna, kui** `up.sh` lõpetas koodiga 1 ja teatega kustutamisest, Proxmoxis jäi mc01 samaks ja pärast tagasivõtmist lõpeb `./up.sh` koodiga 0.

## Tõsta stack nullist

Kustutad kõik ja lased skriptil stacki tagasi tõsta.

Siin mõõdad ka aega: see on selle stacki taastamisaja alampiir, andmete taastamine tuleb sellele lisaks.

1. Kustuta kõik viis VM-i. `destroy` küsib kinnitust, loe enne plaani. Koos VM-idega kaob db01 andmebaas; laboris on see tühi ja Ansible loob selle uuesti.

    ```bash
    tofu destroy
    ```

2. Mõõda kogu tee nullist töötava stackini.

    ```bash
    time ./up.sh
    curl -s http://<web01 IP>/health; echo
    ```

`/health` UP tähendab, et kõik kolm sammu töötasid järjest: Tofu lõi masinad, cloud-init andis võrgu ja võtme, Ansible seadistas teenused. `time` tulemusest näed, kui suur osa ajast läks kloonimisele ja boodile ning kui suur Ansible'ile. See jaotus ütleb, kust taastamist kiirendada.

✅ **Edasi saad minna, kui** `/health` vastab `"status":"UP"` ja `NOTES.md`-s on `time` tulemus.

## Commit

Commit'i läheb nüüd ka `k02-ansible/` kausta muudatus: genereeritud inventory ja `ansible.cfg`. Nii on Gitis näha, et inventory on Tofu toode.

Genereeritud fail Gitis tundub üleliigne, aga see näitab PR-is täpselt, milline IP muutus. Kui fail on Gitist väljas, näeb ülevaataja ainult `tfvars`-i muutust, mida ta ei saa kontrollida.

```bash
cd ~/labori-seis
git add k04-tofu k02-ansible/inventory.ini k02-ansible/ansible.cfg
git commit -m "k04: inventory Tofu väljundist, up.sh"
git push
```

`resources` kontroll otsib muu hulgas `local_file`-i, `templatefile()`-i ja teed `k02-ansible/inventory.ini`. `files` kontroll vaatab, et `inventory.tftpl` ja lukufail on olemas ning state ja `tfvars` on Gitist väljas.

✅ **Edasi saad minna, kui** `bash autograde/check.sh k04 resources` ja `bash autograde/check.sh k04 files` annavad `OK`.

📎 **Selle mooduli tõend:** commit `k04: inventory…` koos `inventory.tftpl`, `inventory.tf`, `up.sh` ja genereeritud `inventory.ini`-ga; `NOTES.md`-s käsitsi muudetud inventory plaan ja `up.sh` keeldumise väljund; issue `K4.4` kommentaaris `time ./up.sh` ja `/health` vastus.

## Miks see nii töötab

**Cloud-init'i ootamine.** `cloud-init status --wait` ootab, kuni cloud-init on töö lõpetanud ja kirjutanud faili `/run/cloud-init/result.json`.

**Apt-i lukud.** apt-i lukufailid on `/var/lib/dpkg/lock-frontend` ja `/var/lib/apt/lists/lock`. `sudo fuser -v /var/lib/dpkg/lock-frontend` näitab, milline protsess lukku hoiab.

**Lukk pärast cloud-init'i.** Ubuntu 24.04 pilvemallis on `unattended-upgrades` vaikimisi sees ja võib esimesel käivitusel tööle hakata. Seega on lukuootus vajalik ka siis, kui cloud-init ise enam pakette ei uuenda. Teade „cloud-init on valmis" ei tähenda, et masinas ei tööta ühtki taustatööd, mis sama ressurssi kasutab.

**`tofu graph`.** `tofu graph | dot -Tsvg > graph.svg` joonistab sõltuvusgraafi: `local_file.inventory` on ühendatud kõigi viie VM-iga.

**Salvestatud plaan.** `up.sh` teeb `apply` salvestatud plaanist, mitte ei koosta uut. Nii läheb käiku täpselt see plaan, mille skript üle kontrollis.

**`local_file`-i asendus.** `local_file` asendatakse iga sisumuudatuse korral, sest provider ei muuda faili kohapeal. Seepärast arvestab `up.sh` kustutamisena ainult Proxmoxi objektide kustutamist: inventory faili asendus on ohutu, VM-i asendus mitte.

Kui jõudsid kiiremini: [Lisaülesanded → 10. Plaani kokkuvõte pipeline'i jaoks](lisa.md#10-plaani-kokkuvote-pipelinei-jaoks), kirjutad `up.sh` plaanikontrollist skripti, mis näitab ülevaatajale ühe vaatega, mida kustutatakse.
