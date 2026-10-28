---
tags:
  - Ansible
  - veaotsing
  - intsident
---

# 8. Intsident

Kolleeg tegi öösel sinu harule kiire paranduse: rohkem mälu app01-le, ajavöönd kõigile hostidele, mc01 test ja "inventory korrastus". Hommikul on `site.yml` punane, `check.sh` hoiatab ja ometi vastab leht kasutajale, kuigi iga muudatus oli eraldi võttes mõistlik mõte. Rikkeid on mitu ja osa neist tuleb välja alles siis, kui eelmine on parandatud.

Lõpuks on iga rike leitud sümptomist, parandatud koodis, mitte masinas, ja kontrollitud kitsalt ainult selles osas, mida parandus puudutab, ning README-s on kirjas, miks rike kohe näha polnud ja milline kontroll oleks selle varem peatanud.

**Kui teed seda tööl iga päev:** käivitad pärast `k02-intsident.sh`-i `ansible-lint`-i, `site.yml`-i ja `verify.yml`-i ning paned sümptomid README tabelisse ilma veaotsingu tabelita. Kui see on sul juba korras, mine otse etappi [„Paranda ükshaaval, kontrolli kitsalt“](#paranda-ukshaaval-kontrolli-kitsalt).

Veaotsingu tabel näitab, kust otsima hakata, see pole vastuste nimekiri. Sümptom ja põhjus on harva samas failis. Tabeli ridade järjekord pole parandamise järjekord.

| Sümptom | Vaata esimesena | Tõenäoline koht |
|---|---|---|
| `ansible-lint` annab leiu, mida eile polnud | lint'i väljundis faili nimi ja rida | roll `common` |
| teine `site.yml` jooks on igal hostil `changed=1` | `ansible-playbook site.yml -v`, ülesanded, mis on `changed` | sama ülesanne |
| play "Rakendus" ütleb `skipping: no hosts matched` | `ansible-inventory --graph`, `ansible-playbook site.yml --list-hosts` | `inventory.ini` |
| web01 ebaõnnestub ülesandes `Saidi seadistus` (`failed to validate`), leht vastab ikka | `ansible-playbook site.yml --limit web01 -v`, `nginx`-i teade väljundis | mall ja selle sisend |
| `/health` → `"cache":"DOWN"`, mc01 jooks on roheline | `ansible-inventory --host mc01`, `ssh mc01 sudo ss -tlnp` | muutuja, mis võidab rolli vaikeväärtuse |
| app01: `handler … was not found` | `grep -rn 'Restart' roles/tomcat` | rolli handlerid |

*Tabel L2.2. Veaotsingu tabel.*

> ⚠️ Tootmise intsidendis vaatad ka `git log -p`. Siin harjutad diagnoosi Ansible'i väljundist ja masinast: ära loe skripti ega kolleegi commit'i enne, kui iga rike on leitud. Diff näitaks muudatust, aga mitte seda, mida see lõhkus. Kui segi läheb: `git reset --hard enne-intsidenti`, siis `ansible-playbook site.yml`.

## Kolleegi hotfix sinu harule

Paned kolleegi commit'i oma harule. Enne seda kontrollid, et stack on roheline ja töökaust puhas: ainult siis tead, et iga järgmine punane rida tuli sellest commit'ist.

1. Stack peab enne olema roheline ja töökaust puhas.

    ```bash
    cd ~/labori-seis/k02-ansible
    ansible-playbook verify.yml | tail -6
    git status --short
    ```

2. Käivita skript. See teeb sinu harule ühe commit'i autoriga "Kolleeg" ja haru `enne-intsidenti` praeguse seisu peale.

    ```bash
    bash ../scripts/k02-intsident.sh
    git log --oneline -2
    ```

Haru `enne-intsidenti` on sinu teadaolev hea seis. Iga hetk saad sinna tagasi minna ja võrrelda. Kolleegi commit on nüüd sinu harul ühe commit'ina ja selle sõnum ütleb vähem, kui commit teeb.

✅ **Edasi saad minna, kui** `git log` näitab kolleegi commit'i ja `git branch` näitab haru `enne-intsidenti`.

## Esimene pilt: mis on punane

Enne ühtki parandust kogud kokku, mida süsteem ütleb. Liigud odavamast kallimani: kõigepealt kontrollid, mis ei puuduta hoste, siis `site.yml` jooks, siis kasutaja vaade.

Ansible jätab ebaõnnestunud hosti play ülejäänud ülesannetest välja, nii et esimene punane rida peidab kõik sama hosti järgmised vead. Kogu pilt eri allikatest näitab, mida jooks ei jõudnudki kontrollida.

1. Staatilised kontrollid ja inventory.

    ```bash
    ansible-lint 2>&1 | tail -8
    ansible-playbook site.yml --syntax-check
    ansible-inventory --graph
    ```

2. `site.yml` jooks, siis verify ja monitooring.

    ```bash
    ansible-playbook site.yml 2>&1 | tee scratch/intsident-1.txt | grep -E 'fatal|skipping: no hosts|RUNNING HANDLER|changed='
    ansible-playbook verify.yml 2>&1 | grep -E 'fatal|failed:|msg'
    (cd ../k01-bash && ./check.sh); echo "kood $?"
    curl -s -o /dev/null -w '%{http_code}\n' http://web01/
    ```

3. Kogu logid enne, kui midagi taaskäivitad: `ansible-playbook logs.yml`, siis `grep -ril error scratch/logs --include='*.log'`.
4. Kirjuta README-sse pealkirja "Intsident" alla tabel: sümptom, käsk, mis selle näitas, oletatav koht. Ära paranda veel midagi.

Sul on nüüd neli eri allikat: lint, Ansible'i jooks, verify ja monitooring. Need ei ütle sama asja ja just erinevused on informatiivsed. Kui jooks on punane, aga kasutaja saab 200, ei ole rike veel kasutajani jõudnud: midagi hoiab vana seisu elus. Kui verify on roheline, aga jooks punane, ei kontrolli verify kõike, mida jooks puudutab.

✅ **Edasi saad minna, kui** tabelis on vähemalt neli sümptomit, igaühe juures käsk, ja oskad öelda, miks leht vastab, kuigi web01 jooks ebaõnnestus.

## Paranda ükshaaval, kontrolli kitsalt

Võtad tabelist ühe sümptomi, leiad põhjuse, parandad selle koodis ja kontrollid ainult seda osa. Siis järgmine. Iga parandus on eraldi commit, et hiljem oleks näha, mis mida parandas.

Kitsas kontroll iga paranduse järel näitab kohe, kas parandus töötas, ja ei sega seda teiste rikete väljundiga.

Kolleegi mõte võib olla õige ja lahendus vale: siis jäta mõte alles ja paranda lahendus.

1. Leia põhjus veaotsingu tabeli "Vaata esimesena" käsuga ja vajadusel `-v`, `--check --diff` või masina enda käskudega (`ss -tlnp`, `journalctl -u <teenus>`, `nginx -t`).
2. Paranda põhjus failis. Ära paranda masinat käsitsi: järgmine jooks kirjutaks selle üle või jätaks samaks.
3. Kontrolli ainult seda osa, mida parandus puudutab, näiteks:

    ```bash
    ansible-lint roles/common
    ansible-inventory --graph app
    ansible-playbook site.yml --limit web01
    ansible-playbook site.yml --limit mc01 && ansible-inventory --host mc01
    ```

4. Commit'i iga parandus eraldi, sõnumis põhjus: `fix(<koht>): <miks see kukkus>`.
5. Lisa README tabelisse veerud "põhjus" ja "parandus". Kui uus sümptom tuli välja alles pärast eelmist parandust, kirjuta, mis seda varjas.

Kui uus sümptom tuli välja alles pärast parandust, ei tekitanud parandus seda. Eelmine rike peitis seda, sest Ansible ei jõudnud selle ülesandeni või play jäi üldse vahele. Pärast iga parandust jõuab jooks hostis ühe ülesande või play võrra kaugemale. Seepärast pead pärast iga parandust uuesti vaatama, mitte eeldama, et tabeli järgmine rida on viimane.

✅ **Edasi saad minna, kui** `git log --oneline enne-intsidenti..` näitab kolleegi commit'i ja vähemalt nelja `fix(…)` commit'i ning iga commit'i järel käivitus kitsas kontroll.

## Kogu stack uuesti roheline

Kui tabeli kõik read on läbi käidud, käivitad kõik kontrollid uuesti samas järjekorras nagu alguses. Alles see ütleb, et intsident on läbi, mitte üksikute paranduste rohelised read.

Iga parandus kontrollis ainult oma osa. Kaks õiget parandust võivad koos ikka midagi lõhkuda, ja seda näed ainult täisjooksus.

```bash
ansible-lint && ansible-playbook site.yml --syntax-check
ansible-playbook site.yml > /dev/null; ansible-playbook site.yml | tail -7
ansible-playbook verify.yml | tail -6
(cd ../k01-bash && ./check.sh); echo "kood $?"
bash ../autograde/check.sh k02 inventory
```

Kirjuta README-sse kaks lauset: mis oleks juhtunud, kui mallil poleks olnud `validate`-i ega handlerit `Test nginx` enne `Reload nginx`-i, ja mis kontroll oleks kolleegi commit'i enne merge'i peatanud.

Teine jooks `changed=0` tähendab, et kõik parandused on idempotentsed ja kolleegi muudatused, mis jäid alles, on nüüd õigesti tehtud. Roheline verify ja `check.sh` kood 0 tähendavad, et kasutaja ja monitooring näevad sama, mida Ansible. Automaatse hindaja `inventory` kontroll tõestab, et inventory vastab jälle kokkuleppele, mida järgib ka OpenTofu.

✅ **Edasi saad minna, kui** lint on puhas, teine jooks annab viiel hostil `changed=0`, verify on roheline, `check.sh` kood on 0 ja automaatse hindaja `inventory` kontroll annab `OK`.

## Regressioonikontroll ja lühike postmortem

Lisad `verify.yml`-i kontrolli, mis oleks ühe selle intsidendi rikke kohe leidnud, ja kirjutad lühikese postmortem'i.

Sinu `verify.yml` jäi selle intsidendi ajal osaliselt roheliseks, sest tühja grupi play'd jäävad vaikselt vahele.

1. Lisa `verify.yml`-i esimeseks play, mis kontrollib inventory't. Nõuded:
    - `hosts: localhost`, `gather_facts: false`, `become: false`
    - `ansible.builtin.assert` tsükliga üle gruppide `db`, `cache`, `queue`, `app`, `web`
    - tingimus: grupis on vähemalt üks host, ka siis, kui gruppi pole üldse (`default([])`)
    - `fail_msg` nimetab tühja grupi ja ütleb, mis sellest juhtuks
2. Proovi: nimeta inventory's üks grupp ajutiselt ümber, käivita verify ja taasta fail.

    ```bash
    sed -i 's/^\[cache\]$/[caches]/' inventory.ini
    ansible-playbook verify.yml 2>&1 | grep -E 'failed:|msg|cache'
    git checkout inventory.ini && ansible-playbook verify.yml | tail -6
    ansible-lint verify.yml
    ```

3. Kirjuta README-sse "Intsident" tabeli alla postmortem viie reaga: mis juhtus, mis oli mõju kasutajale, põhjused, mis varjas teist riket ja millised kaks kontrolli on nüüd olemas, mis selle varem peataksid.
4. Commit: `fix(verify): tühi grupp kukutab verify`.

Ümbernimetatud grupiga ebaõnnestus verify kohe esimeses play's ja ütles, milline grupp on tühi. Ilma selleta oleks Memcached'i play vahele jäänud ja viga oleks tulnud alles hiljem mallis või pordikontrollis, kus `groups['cache']` on määramata: kaugel põhjusest ja segase teatega. Postmortem'i väljund on kontroll, mis puudus: nii on järgmine kolleegi hotfix kas kohe punane või ohutu.

✅ **Edasi saad minna, kui** ümbernimetatud grupiga ebaõnnestub verify esimeses play's sõnumiga, mis nimetab `cache` gruppi, taastatud failiga on verify roheline, lint on puhas ja README-s on postmortem viie reaga.

📎 **Selle mooduli tõend:** kolleegi commit ja `fix(…)` commit'id põhjusega sõnumis, sh `fix(verify)`; README "Intsident" tabel (sümptom, käsk, põhjus, parandus, mis varjas), kaks lauset ja postmortem; `scratch/intsident-1.txt` (ei lähe Giti).

## Miks see nii töötab

**Gruppide prioriteet.** Sama sügavusega gruppidest on vaikimisi eelistatud tähestikus hilisem. Grupi muutuja `ansible_group_priority` muudab seda järjekorda, aga laboris pole seda vaja. Seepärast ei tasu sama muutujat panna kahte sama taseme gruppi: tulemus sõltub grupi nimest, mitte sinu kavatsusest.

**Tühi grupp.** Tühi grupp ei ole viga. Play `hosts: app` jäetakse vahele ja mall, mis käib tsükliga läbi `groups['app']`, renderdub tühjana.

**Peatumine esimesel veal.** Pooleldi seadistatud host on halvem kui seadistamata host, seepärast peatab Ansible vaikimisi hosti töötlemise esimese vea juures, kui ülesandel pole `ignore_errors`-it või `rescue`-plokki.

**Postmortem.** Siin olid puuduvad kontrollid tühja grupi kontroll ja lint enne merge'i.

Kui jõudsid kiiremini: [Lisaülesanded → 10. Vana playbook kaasaegseks](lisa.md#10-vana-playbook-kaasaegseks), otsid võõrast vanast playbook'ist samu vigu, mida kolleegi commit'is, ja teed sellest kahe distro rolli.
