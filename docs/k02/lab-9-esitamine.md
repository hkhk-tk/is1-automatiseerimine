---
tags:
  - Git
  - Hindamine
---

# 9. Esitamine

Kood, mis töötab ainult sinu kaustas ja samm-sammult seadistatud masinatel, ebaõnnestub esimesel uuel keskkonnal või kolleegi kloonis. Automaatne hindaja sinu VM-e ei näe: teise käivituse tulemuse annad talle failina `run2.txt` ja stacki seisu näeb koolitaja Labori seisust. Enne seda teed kolm testi, mida iga Ansible'i projekt peaks enne tootmist läbima: kas kood tõstab stacki tühjalt masinalt, kas teine jooks on puhas ja kas keegi teine saab sama koodiga sama tulemuse.

Lõpuks on töö `main`-is, tag `k02` on käivitanud automaatse hindaja ja tulemus on GitHubi Releases all.

**Kui teed seda tööl iga päev:** `run2.txt` on tehtud `enne-stack` seisust üles tõstetud stacki teisest jooksust ja `grep -cE 'changed=0 .*failed=0' k02-ansible/run2.txt` annab `5`; etapi „Sinu töökohal“ teksti kirjuta ikka. Kui see on sul juba korras, mine otse etappi [„Kloon teises kaustas: kas kõik on Gitis“](#kloon-teises-kaustas-kas-koik-on-gitis).

## Puhtalt masinalt ühe käivitusega

Viid kõik viis VM-i tagasi seisu enne stacki ja käivitad `site.yml`-i üks kord. Rollback kustutab ka db01 andmebaasi ja `site.yml` loob selle `seed.sql`-ist uuesti. Kõik moodulid kokku peavad nüüd ühe käsuga töötama.

Samm-sammult ehitatud stack võib sõltuda millestki, mis tehti vahepeal käsitsi või mõne vahepealse sammuga. Ainus viis seda leida on alustada nullist, enne kui seda teeb OpenTofu või keegi öösel uue keskkonna loomisel.

1. Proxmoxis kõigil viiel **Snapshots → `enne-stack` → Rollback**, siis **Start**.
2. Käivita stack üks kord ja kontrolli.

    ```bash
    cd ~/labori-seis/k02-ansible
    ansible-playbook site.yml | tail -7
    ansible-playbook verify.yml | tail -6
    ```

`failed=0` viiel hostil esimesel jooksul tõestab, et rollide järjekord on õige: andmebaas enne rakendust, rakendus enne veebiserverit. Roheline verify ütleb, et ka ühendused hostide vahel töötavad. Kui mõni host ebaõnnestub, otsi esimest ebaõnnestunud ülesannet: see on tavaliselt koht, mis eeldas midagi, mida tühjal masinal pole.

✅ **Edasi saad minna, kui** esimene jooks jõuab viiel hostil lõpuni `failed=0`-ga ja `verify.yml` on roheline.

## Teine käivitus failiks ja Labori seisu

Käivitad stacki teist korda ja salvestad väljundi. Enne saatmist kontrollid, et väljundis pole saladusi, ja teed reboot-testi.

`service: state=started` ilma `enabled: true`-ta läbib iga jooksu roheliselt ja `changed=0`-ga, aga teenus ei tõuse pärast reboot'i. Ka cloud-init kirjutab `/etc/hosts`-i igal bootil uuesti. Kumbagi ei näe Ansible'i jooksust, ainult reboot'ist.

1. Käivita stack teist korda, väljund läheb faili.

    ```bash
    cd ~/labori-seis/k02-ansible
    ansible-playbook site.yml | tee run2.txt | tail -7
    grep -cE 'changed=0 .*failed=0' run2.txt
    ```

2. Vaata, et `run2.txt`-is pole saladusi, siis saada tulemus Labori seisu.

    ```bash
    grep -inE 'password|token' run2.txt || echo puhas
    ../scripts/labseis-report.sh lab-02 idempotent OK "site.yml 2. käivitus changed=0"
    ```

3. Reboot-test: `ssh web01 sudo reboot` ja `ssh app01 sudo reboot`, minuti pärast `curl -s http://web01/health` ja `ansible-playbook verify.yml`.

<!-- EKRAANIPILT: Labori seisu veebileht (LABSEIS_URL), õppija rida; kirje "lab-02 idempotent OK" koos teksti ja ajaga. Tee kohe pärast labseis-report.sh käivitamist. Token ei tohi pildil näha olla.
<figure markdown="span">
  ![Labori seisu leht kirjega lab-02 idempotent OK](assets/k02_labseis_lab02.png)
  <figcaption>Joonis L2.6. Labori seis näitab koolitajale, et teine käivitus oli <code>changed=0</code>.</figcaption>
</figure>
-->

`5` tähendab, et iga host on PLAY RECAP-is ja ükski neist ei muutnud midagi. Kui `grep` leiaks parooli, poleks mõni `no_log` paigas ja sama parool oleks ka `ansible.log`-is. Roheline verify pärast reboot'i tõestab, et teenused käivituvad bootil ise ja `/etc/hosts` plokk jäi alles.

✅ **Edasi saad minna, kui** `grep -c` annab `5`, `run2.txt` on saladustest puhas, Labori seisus on `lab-02 idempotent OK` ja pärast reboot'i on `/health` `UP` ning verify roheline.

## Kloon teises kaustas: kas kõik on Gitis

Kloonid oma haru uude kausta ja käivitad sealt check'i. Kui see annab sama tulemuse, on kõik vajalik Gitis peale saladuste.

Projekt, mis töötab ainult sinu kaustas, sõltub millestki, mida Gitis pole: kohalikust failist, käsitsi paigaldatud kollektsioonist või unustatud `git add`-ist. See selgub tavaliselt siis, kui sind pole kohal.

1. Klooni haru ja paigalda sõltuvused ainult `requirements.yml`-ist.

    ```bash
    git -C ~/labori-seis push
    git clone -q --branch k02-ansible "$(git -C ~/labori-seis remote get-url origin)" ~/k02-kloon
    cd ~/k02-kloon/k02-ansible && ansible-galaxy collection install -r requirements.yml
    ansible-playbook site.yml --check | tail -7
    ```

2. Koristus: `cd ~/labori-seis && rm -rf ~/k02-kloon`.
3. Kirjuta README-sse, mida kloonist puudus (kui midagi) ja mis tuli väljastpoolt Giti.

Check kloonist andis `changed=0`, nii et kood Gitis kirjeldab täpselt sama seisu, mis hostides on. Väljastpoolt Giti tulid ainult Vaulti parool keskkonnamuutujas ja labori CA kaustas `~/.config/is1/pki/`: see on õige, sest mõlemad on saladused, ja 5. kohtumisel annab need pipeline'ile GitHubi secret'id. Kui check oleks ebaõnnestunud puuduva faili peal, oleks see fail jäänud Gitist välja ja automaatne hindaja või kolleeg oleks saanud sama vea.

✅ **Edasi saad minna, kui** kloonist tehtud `--check` annab viiel hostil `changed=0 failed=0`, kloon on kustutatud ja README-s on vastus.

## Sinu töökohal

Kursuse stack on harjutus. Kasu tuleb siis, kui sama mõte jõuab sinu enda serveritesse või võrguseadmetesse. Kirjuta `k02-ansible/README.md`-sse pealkirja "Minu töökohal" alla 3–5 lauset: kus sinu töökohal käib täna käsitsi midagi, mida selles kohtumises automatiseerisid (paigad ja reboot'id, kasutajad ja võtmed, konfifailid, serdid, deploy koos rollback'iga, drift'i otsimine, ruuteri konfi varundus), ja mis oleks esimene samm selle automatiseerimiseks. Nimeta üks konkreetne takistus: õigused, change'i protsess, võrk, see, et masinat haldab teine tiim. Hoste ega sisevõrgu nimesid pole vaja.

```bash
cd ~/labori-seis
grep -A6 '^#* *Minu töökohal' k02-ansible/README.md
```

Hea esimene samm on väike ja tagasi võetav: üks käsitsi runbook'i samm playbook'iks, mis töötab alguses ainult `--check --diff`-iga, mitte "kogu konfihaldus Ansible'isse".

✅ **Edasi saad minna, kui** README-s on pealkiri "Minu töökohal" ja selle all 3–5 lauset koos ühe esimese sammuga.

## Enne esitamist

Käivitad automaatse hindaja kontrollid kohapeal ja vaatad, et ükski saladus ega proovifail pole Gitis.

```bash
cd ~/labori-seis
for t in files inventory structure vault idempotent syntax lint; do bash autograde/check.sh k02 "$t"; done
head -1 k02-ansible/group_vars/all/vault.yml
git grep -nE '^\s*[a-z_]*(password|token)[a-z_]*:\s*[^"{ ]' -- 'k02-ansible/*.yml' | grep -v update_password || echo puhas
git ls-files | grep -E 'vault_pass|ansible\.log|scratch/|\.retry$' || echo puhas
```

> `k02 lint` lint'ib kogu `k02-ansible/` kausta, ka eelmise korra `web.yml`-i ja `verify.yml`-i. Automaatne hindaja ignoreerib sinu `.ansible-lint` faili ja lubab kuni kolm `# noqa`-t.

Seitse `OK`-d tähendavad, et automaatne hindaja annab sama tulemuse, mida näed praegu. Esimene `grep` otsib avatekstis paroole YAML-is, teine faile, mis ei tohi Gitis olla. Kui mõni neist leiab midagi, paranda see enne PR-i.

✅ **Edasi saad minna, kui** kõik seitse kontrolli annavad `OK`, `vault.yml` algab `$ANSIBLE_VAULT;1.1;AES256` ja mõlemad `grep`-id ütlevad `puhas`.

## PR, merge ja tag

Viid töö `main`-i pull request'iga ja paned tag'i. PR on koht, kus commit'id ja issue'd seotakse kokku. Tag on hetk, mida automaatne hindaja hindab.

```bash
git add k02-ansible/run2.txt k02-ansible/README.md && git commit -m "K2.9 run2.txt (closes #N)" && git push
gh pr create --base main --head k02-ansible --title "K2 Ansible" --body "K2: Labori seis Ansible'i rollidega"
gh pr merge --merge
git switch main && git pull
git tag k02 && git push origin k02
```

<!-- EKRAANIPILT: GitHub, PR k02-ansible → main; näha pealkiri, commit'id `K2.1` … `K2.9` ja fix(…) commit'id ning seotud issue'd (closes #N), nupp Merge. Tee enne merge'i.
<figure markdown="span">
  ![GitHubi pull request harust k02-ansible harusse main](assets/k02_github_pr.png)
  <figcaption>Joonis L2.7. PR <code>k02-ansible</code> → <code>main</code> sulgeb selle korra issue'd.</figcaption>
</figure>
-->

> Parandus pärast esitust: uus commit `main`-i, siis `git tag -f k02 && git push -f origin k02`.

Tag `k02` remote'is tähendab, et automaatne hindaja on käivitunud. Tag viitab `main`-i commit'ile pärast merge'i, mitte harule. Seepärast peab merge olema tehtud enne tag'i, muidu hindab automaatne hindaja vana seisu.

✅ **Edasi saad minna, kui** `git ls-remote --tags origin` näitab `k02`.

## Automaatse hindaja tulemus

Tag `k02` käivitab automaatse hindaja. Tulemus on paari minuti pärast: repo → **Releases** → viimane `submit/…`, iga mitteläbinud kontrolli juures on põhjus. Testide nimekiri on `autograde/TESTS.md`-is: failid ja rollid, inventory, struktuur, Vault, `run2.txt`, syntax-check (`site.yml`, `deploy.yml`) ja ansible-lint.

Automaatne hindaja kontrollib struktuuri ja vormi, Labori seis kontrollib töötavat stacki. Kumbki üksi ei ütle kõike. Kui Releases on roheline, aga Labori seis punane, on kood korras ja hostid mitte. Kui vastupidi, töötab stack, aga kood ei vasta kokkuleppele, mida järgmised kohtumised eeldavad.

✅ **Edasi saad minna, kui** Releases näitab tulemust 100 lähedal ja Labori seisus on sinu `lab-02` read rohelised.

## Tõendid moodulite kaupa

Nimekiri on sama, mida koolitaja PR-i ülevaatusel vaatab. Iga punkt on README-s või Gitis ja iga linnuke tähendab, et oskad selle kohta ka suuliselt vastata.

- [ ] 1. Algseis: commit `K2.1`, README-s `ansible --version`, `UNREACHABLE` katse, mc01 grupid, Rocky muutuja koht
- [ ] 2. Andmebaas ühe playbook'iga: commit `K2.2`, krüpteeritud `vault.yml`, check-ebaõnnestumise põhjus, andmete kustutamise katse, `--check --diff` rida
- [ ] 3. Rollid ja muutujad: commit `K2.3`, `blockinfile` marker, prioriteedi tabel kuue tasemega, valvekasutajad, custom fact `labseis`
- [ ] 4. Kogu stack: commit `K2.4`, `/health` → `UP`, RabbitMQ rikke vastused, snapshot `k02-stack`, osalise käivituse käsk
- [ ] 5. Kontroll enne muudatust: commit `K2.5`, lint puhas, `check_mode: false` loetelu, drift'i vastused, `verify.yml` roheline
- [ ] 6. Deploy ja rolling: commit `K2.6`, kahe rikke tabel, fact'ita deploy, `deploy.fact`, rolling'u vastused, `patch.yml` ja patch'imise laine tabel
- [ ] 7. Tsüklid, mallid ja TLS: commit `K2.7`, pordid grupi muutujast, eelkontroll, `validate`, HTTPS labori CA-ga, import/include tabel, RabbitMQ API kontroll, `logs.yml`, `memcached-docker.yml`
- [ ] 8. Intsident: `fix(…)` commit'id, README "Intsident" tabel, postmortem, verify kontrollib tühja gruppi
- [ ] 9. Esitamine: `run2.txt`, kloonist check, "Minu töökohal" README-s, Labori seis `lab-02 idempotent OK`, tag `k02`

✅ **Edasi saad minna, kui** kõik linnukesed on tehtud ja README on viimases commit'is.

📎 **Selle mooduli tõend:** tag `k02` `main`-i peal, `run2.txt` repos, README-s kloonitesti vastus ja "Minu töökohal", automaatse hindaja tulemus GitHubi Releases all.

## Pärast esitamist: kolm VM-i välja

Kooli Proxmoxis jagavad kõik õppijad sama mälu. 3. kohtumisel töötab stack control node'is Dockeris ja Podmani moodul kasutab ainult mc01 ja db01. web01, app01 ja rmq01 võtavad seni mälu, mida teised vajavad.

Kui Releases on roheline ja Labori seisus on `lab-02` read rohelised, lülita Proxmoxis välja web01, app01 ja rmq01: **VM → Shutdown**. mc01 ja db01 jäävad tööle. Kui teed hiljem lisaülesannet, mis neid vajab, käivita need, ja kui oled valmis, lülita uuesti välja.

✅ **Edasi saad minna, kui** Proxmoxis on sinu pool'is web01, app01 ja rmq01 olekus *stopped*.

## Miks see nii töötab

**`run2.txt` tõendina.** `run2.txt` on lihtne, aga aus tõend. Koolitaja võrdleb seda Labori seisuga, mida VM-id ise saadavad.

**Check värskest kloonist.** Värskest kloonist tehtud check on sama mõttega nagu pipeline: kood peab töötama kohas, kus pole midagi peale Giti ja saladuste. Kui see töötab, on GitHub Actionsi pipeline'i ehitamine peamiselt käskude järjestamine.

Kui jõudsid kiiremini: [Lisaülesanded → Kodutöö](lisa.md#kodutoo), käivitad sama `site.yml`-i viiel AWS-i EC2-l ja näed, et muutub ainult inventory allikas.
