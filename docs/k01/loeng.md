---
tags:
  - Bash
  - Ansible
  - Loeng
---

# 1. kohtumine · Linuxi haldusest automatiseerimiseni

??? abstract "Õpiväljundid"

    Pärast seda kohtumist oskad:

    - selgitada, miks ja millal tööd automatiseerida ning millal see ei tasu end veel ära;
    - kirjeldada ülesannet tulemusena ja koostada sellele kontrollnimekirja enne, kui kirjutad käske;
    - kirjutada ja selgitada lühikest Bashi skripti (shebang, muutujad, jutumärgid, väljumiskood, `if`);
    - ennustada ja kontrollida, mis juhtub teisel käivitusel ning pärast kontrollitud muudatust või viga;
    - selgitada mõisteid control node, hallatav masin, inventory, moodul, ülesanne ja playbook ning käivitada playbook'i;
    - lugeda Ansible'i tulemust (`ok`, `changed`, `failed`) ning kontrollida ja selgitada näite korduva käivitamise käitumist;
    - kontrollida tulemust masinast endast, mitte ainult tööriista aruandest.

!!! info "Päeva ülesanne"

    Masinas **web01** peab kasutaja `kasutaja` kodukaustas olema kaust `automation-lab` õigustega `0750` ja selles fail `training.conf` õigustega `0640`. Failis on kaks rida:

    ```ini
    environment=training
    enabled=true
    ```

    Need väärtused on harjutuse nõuded, mitte soovitus päris rakendusele.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 95" role="img" aria-label="Sama ülesanne kolmel viisil: käsitsi, Bashi skriptiga ja Ansible'iga, iga kord sama kontroll" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:15px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxt" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="20" width="160" height="60" rx="8"/><text class="b" x="90" y="47" text-anchor="middle">Käsitsi</text><text class="s" x="90" y="66" text-anchor="middle">mkdir, printf, chmod</text>
<line class="a" x1="170" y1="50" x2="198" y2="50" marker-end="url(#lxt)"/>
<rect class="box" x="200" y="20" width="160" height="60" rx="8"/><text class="b" x="280" y="47" text-anchor="middle">Bashi skript</text><text class="s" x="280" y="66" text-anchor="middle">sammud failis</text>
<line class="a" x1="360" y1="50" x2="388" y2="50" marker-end="url(#lxt)"/>
<rect class="box" x="390" y="20" width="160" height="60" rx="8"/><text class="b" x="470" y="47" text-anchor="middle">Ansible</text><text class="s" x="470" y="66" text-anchor="middle">soovitud seis</text>
<line class="a" x1="550" y1="50" x2="578" y2="50" marker-end="url(#lxt)"/>
<rect class="hi" x="580" y="20" width="130" height="60" rx="8"/><text class="b" x="645" y="47" text-anchor="middle">Kontroll</text><text class="s" x="645" y="66" text-anchor="middle">cat, stat</text>
</svg>
<figcaption>Joonis 1.1. Päeva lugu: üks ülesanne, kolm teostust, üks kontroll.</figcaption>
</figure>

## 1. Miks automatiseerida?

**Küsimus:** ma oskan Linuxit hallata. Milleks mulle veel üks töötamise viis?

### Üks kord on lihtne

Kujutle, et seadistasid serveri. Tegid kausta, lisasid sinna konfiguratsioonifaili, panid õigused ja vaatasid üle, et kõik on korras. Töö oli lihtne, sest sa teadsid käske ja nägid tulemust oma silmaga.

Järgmisel päeval on vaja sama teha teises serveris. Nädal hiljem küsib kolleeg, kuidas sa esimese ette valmistasid. Kuu aja pärast tuleb see server uuesti üles ehitada.

Nüüd on küsimus teine. Enam ei küsita „kas sa oskad seda masinat seadistada?“, vaid:

> Kas sa suudad töö korrata, teisele selgitada ja tõestada, et tulemus on õige?

Sellest küsimusest automatiseerimine algab.

### Mis käsitsi töös katki läheb

Käsitsi töötamises pole midagi valet. Võõra süsteemiga tutvudes, rikke põhjust otsides või uut asja proovides töötad alati käsitsi. Selle kohtumise ülesande teeme esmalt käsitsi.

Raskus tekib siis, kui sama tööd on vaja usaldusväärselt korrata. Juhend võib olla poolik. Keegi jätab sammu vahele, sest telefon helises. Kaks masinat on alguses erinevas seisus. Käsk, mis eile töötas, ei tööta täna, sest ümbrus on muutunud.

Väike näide. Valla IT-spetsialist seadistab registreerimissüsteemi jaoks kolm ühesugust veebiserverit. Esimese teeb ta hoolikalt, teise kiiremini, sest käsud on shelli ajaloos. Kolmanda juures tuleb kõne ja üks samm jääb tegemata. Kõik kolm töötavad. Kuu aja pärast tulevad turvauuendused, serverid taaskäivitatakse ja kolmas ei tule üles. Põhjuse otsimine võtab tunni, sest „kõik serverid on ju samamoodi seadistatud“.

Probleem polnud oskustes. Probleem oli selles, et masina õige seis oli kirjas ainult inimese mälus.

### Mida automatiseerida ja mida veel mitte

Kõike pole mõtet automatiseerida. Kandidaati hinnatakse kolme küsimusega:

| Küsimus | Näide |
|---|---|
| Kui sageli seda tehakse? | kuine turvauuendus 40 serveris |
| Kui palju maksab käsitsi tehtud viga? | aasta tagasi tehtud sertifikaadi vahetus, mille sammud on ununenud |
| Kui kaua üks kord aega võtab? | uue töötaja kasutajakontod kuues süsteemis |

*Tabel 1.1. Kolm küsimust automatiseerimise kandidaadile.*

Harva tehtava, lihtsa ja väikese riskiga töö puhul võib piisata kontrollnimekirjast või juhendist. Ka ühekordse töö automatiseerimine võib olla põhjendatud, kui see on mahukas, keeruline või eksimise hind on suur. Automaatika maksab: see tuleb kirjutada, testida ja hiljem ka hooldada, kui süsteem muutub.

Google'i SRE (Site Reliability Engineering) raamat nimetab sellist käsitsi, korduvat ja hostide arvuga kasvavat tööd sõnaga *toil*. Raamatu mõte pole „automatiseeri kõik“. Selle mõte on, et korduva töö vähendamine jätab inseneridele aega süsteemi parandamiseks ja et otsus, mida ja kuidas automatiseerida, on inseneriotsus.

??? question "Mõtle"

    Millist tööd teed oma töökohal iga nädal samamoodi? Kui sul töökogemust pole, mõtle varasemale Linuxi praktikumile. Kas see vastab kolmele küsimusele tabelis 1.1?

??? info "Loe juurde"

    - [Google SRE: Eliminating Toil](https://sre.google/sre-book/eliminating-toil/)
    - [Google SRE: Lessons Learned from Other Industries](https://sre.google/sre-book/lessons-learned/)

## 2. Kuidas töötamise viis on muutunud

**Küsimus:** miks inimesed käsitsi haldusest kaugemale liikusid?

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 140" role="img" aria-label="Viis sammu: käsitsi, kirjalik juhend, skript, konfihaldus, versioonihalduses ja üle vaadatud kood" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxp2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="5" y="20" width="126" height="70" rx="8"/><text class="b" x="68" y="48" text-anchor="middle">Käsitsi</text><text class="s" x="68" y="68" text-anchor="middle">mälu, shelli ajalugu</text>
<line class="a" x1="131" y1="55" x2="147" y2="55" marker-end="url(#lxp2)"/>
<rect class="box" x="149" y="20" width="126" height="70" rx="8"/><text class="b" x="212" y="48" text-anchor="middle">Juhend</text><text class="s" x="212" y="68" text-anchor="middle">inimene loeb</text>
<line class="a" x1="275" y1="55" x2="291" y2="55" marker-end="url(#lxp2)"/>
<rect class="box" x="293" y="20" width="126" height="70" rx="8"/><text class="b" x="356" y="48" text-anchor="middle">Skript</text><text class="s" x="356" y="68" text-anchor="middle">arvuti täidab</text>
<line class="a" x1="419" y1="55" x2="435" y2="55" marker-end="url(#lxp2)"/>
<rect class="box" x="437" y="20" width="126" height="70" rx="8"/><text class="b" x="500" y="48" text-anchor="middle">Konfihaldus</text><text class="s" x="500" y="68" text-anchor="middle">soovitud seis</text>
<line class="a" x1="563" y1="55" x2="579" y2="55" marker-end="url(#lxp2)"/>
<rect class="box" x="581" y="20" width="134" height="70" rx="8"/><text class="b" x="648" y="48" text-anchor="middle">Kood Gitis</text><text class="s" x="648" y="68" text-anchor="middle">üle vaadatud</text>
<text class="s" x="360" y="122" text-anchor="middle">Iga samm teeb midagi rohkem kirjalikuks. Eelmine samm ei kao.</text>
</svg>
<figcaption>Joonis 2.1. Lihtsustatud järjekord. Paljud meeskonnad kasutavad kõiki viite korraga.</figcaption>
</figure>

### Käsitsi

Administraator teeb töö ise. Teadmine on tema peas ja shelli ajaloos. Kui ta on puhkusel, ei tea keegi täpselt, mis serveris tehti.

### Kirjalik juhend

Kui keegi teine peab tööd kordama, kirjutatakse juhend (runbook). Juhend salvestab teadmise, aga inimene loeb seda ja otsustab igal sammul ise. Kaks inimest teevad sama juhendi järgi sageli veidi erinevalt.

### Skript

Kui juhend on tuttav ja korduv, salvestatakse osa sammudest skripti. Nüüd täidab sammud arvuti, alati samas järjekorras. Skript kirjeldab aga käske, mitte tulemust. Kas teine käivitus on ohutu, pead ise läbi mõtlema.

### Konfihaldus

Kui masinaid on palju, tuleb tööriist, mis kirjeldab soovitud seisu: „siin peab olema see kaust, need õigused, see fail“. Tööriist kontrollib ise, kas midagi on vaja muuta. Selliseid tööriistu on mitu (Ansible, Puppet, Salt). Meie kasutame Ansible'it.

### Kood versioonihalduses

Kui automaatika on kood, saab seda hoida Gitis. Siis on näha, kes mida muutis ja miks, ning muudatuse saab enne käivitamist kolleegiga üle vaadata.

| Samm | Mida kirjeldab | Kes otsustab, kas muuta on vaja | Tüüpiline risk |
|---|---|---|---|
| Juhend | samme inimesele | inimene igal sammul | samm jääb vahele |
| Skript | käskude järjekorda | skripti autor, kui ta kontrolli kirjutas | teine käivitus teeb sama töö uuesti |
| Konfihaldus | soovitud seisu | tööriista moodul | toores käsk ilma kontrollita |

*Tabel 2.1. Mida iga samm kirjeldab ja kus on risk.*

Ükski samm ei asenda eelmisi täielikult. Bash pole vananenud ja Ansible ei asenda iga skripti. Ka Eesti X-tee avalikus repos on kõrvuti paigaldusjuhend inimesele ja Ansible'i playbook'id meeskonnale, kes ehitab sama keskkonda kümneid kordi. Järjekord on sama: **tee kõigepealt käsitsi, siis kirjuta üles, siis automatiseeri.**

??? note "Süvenemiseks: snowflake server ja drift"

    Kolm aastat töötanud serveris on keegi kunagi lisanud `/etc/hosts`-i rea, muutnud mõnda seadet ja paigaldanud paketi, mida keegi enam ei mäleta. Martin Fowler nimetab sellist masinat *snowflake server*'iks: see on ainulaadne ja keegi ei julge seda uuesti ehitada.

    Masinate vahelisi väikeseid erinevusi nimetatakse **triiviks** (drift). Triivi ei hoia ära eriline hoolikus, sest inimesed unustavad. Aitab see, kui masina seis on kirjas kohas, mis ei unusta, ja seda kirjeldust rakendatakse ikka ja jälle.

??? question "Mõtle"

    Kus on sinu töökohal (või varasemas Linuxi praktikumis) kirjas, kuidas mõni server on seadistatud: juhendis, skriptis, kellegi peas?

??? info "Loe juurde"

    - [Martin Fowler: SnowflakeServer](https://martinfowler.com/bliki/SnowflakeServer.html)
    - [X-tee repo (juhend ja Ansible kõrvuti)](https://github.com/nordic-institute/X-Road)

## 3. Mida automatiseerimine tähendab

**Küsimus:** mida saame kirjeldada, korrata ja kontrollida?

**IT-automatiseerimine** tähendab, et korduv töö (paigaldus, seadistus, uuendused, kasutajad, varundus) on kirjas koodina, mida saab üle vaadata, uuesti käivitada ja mille tulemust saab kontrollida.

Kolm märksõna:

- **kirjeldada**: töö on üles kirjutatud nii täpselt, et teine inimene või arvuti saab sellest aru;
- **korrata**: sama kirjeldus annab teisel masinal ja teisel päeval sama tulemuse;
- **kontrollida**: on olemas viis näha, kas tulemus vastab nõuetele.

Automaatika ei tee halba protsessi heaks. Kui keegi ei tea, mida töö peab saavutama, teeb automaatika vea lihtsalt kiiremini ja kõigis masinates korraga.

Automaatika ei taga ka iseenesest, et tulemus on õige. Programm teeb täpselt seda, mis on kirjas. Kui kirjas on vale kaust, tehakse vale kaust, kiiresti ja usaldusväärselt.

??? example "Knight Capital 2012: üks server kaheksast"

    Uus kood pidi käsitsi jõudma kaheksasse serverisse. Ühte jäi see kopeerimata ja seal käivitus vana funktsioon. USA väärtpaberikomisjoni [otsuse](https://www.sec.gov/litigation/admin/2013/34-70694.pdf) järgi kaotas firma 45 minutiga üle 460 miljoni dollari. Käsitsi tehtud samm jäi vahele ja keegi ei kontrollinud, kas kõik kaheksa olid samas seisus.

??? question "Mõtle"

    Kui automaatika teeb kolleegi iganädalase töö, mis temast saab? Kes vastutab, kui automaatika teeb vea? World Economic Forumi [Future of Jobs Report 2025](https://www.weforum.org/publications/the-future-of-jobs-report-2025/) järgi kasvab nõudlus inimeste järele, kes automaatikat kirjutavad, üle vaatavad ja hooldavad.

## 4. Mõtle enne, kui kirjutad

**Küsimus:** mis on sisend, mida me eeldame, mis peab tulema ja mis võib valesti minna?

### Tulemus enne käske

„Käivita käsk, mis teeb kausta“ kirjeldab tegevust. „Kaust on olemas kokkulepitud kohas ja kokkulepitud õigustega“ kirjeldab tulemust. Mõlemat on vaja: käske, et tööd teha, ja tulemust, et teada, millal töö on tehtud.

Meie ülesande tulemus on kastis „Päeva ülesanne“. Sellest tuleb kontrollnimekiri, mida kasutame kogu päeva:

1. Kas kaust `/home/kasutaja/automation-lab` on olemas?
2. Kas failis `training.conf` on täpselt need kaks rida?
3. Kas kausta õigused on `750` ja faili õigused `640`?
4. Kas mõlemad kuuluvad kasutajale `kasutaja`?
5. Kas töö muutis ainult seda kohta, mitte midagi muud?

### Neli küsimust enne esimest käsku

| Küsimus | Meie ülesandes |
|---|---|
| **Sisend:** mis võib muutuda? | kausta asukoht, faili sisu |
| **Eeldus:** mis peab enne tõsi olema? | oled web01-s kasutajana `kasutaja`, kodukaust on kirjutatav |
| **Tulemus:** kuidas tunned ära, et on tehtud? | kontrollnimekiri ülal |
| **Viga:** mis võib valesti minna? | kaust pole kirjutatav, failinimes on viga, töö jääb poole peale |

*Tabel 4.1. Ülesande kirjeldus enne käske.*

### Sinu keskkond

Töötad kahes masinas. **Control node** on masin, kust juhid tööd ja kuhu ühendud VS Code'iga. **web01** on masin, mida seadistad. Käsitsi ja Bashi osas logid web01-sse ise sisse. Ansible'i osas jääd control node'ile ja Ansible teeb SSH kaudu töö web01-s.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 150" role="img" aria-label="Sinu arvuti ühendub VPN-i ja SSH-ga control node'ile, control node SSH-ga web01-le" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:15px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxe" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="35" width="190" height="70" rx="8"/><text class="b" x="105" y="65" text-anchor="middle">Sinu arvuti</text><text class="s" x="105" y="85" text-anchor="middle">VS Code, VPN</text>
<line class="a" x1="200" y1="70" x2="263" y2="70" marker-end="url(#lxe)"/><text class="s" x="232" y="60" text-anchor="middle">SSH</text>
<rect class="hi" x="265" y="35" width="190" height="70" rx="8"/><text class="b" x="360" y="65" text-anchor="middle">control node</text><text class="s" x="360" y="85" text-anchor="middle">Bash, Ansible, Git</text>
<line class="a" x1="455" y1="70" x2="518" y2="70" marker-end="url(#lxe)"/><text class="s" x="487" y="60" text-anchor="middle">SSH</text>
<rect class="box" x="520" y="35" width="190" height="70" rx="8"/><text class="b" x="615" y="65" text-anchor="middle">web01</text><text class="s" x="615" y="85" text-anchor="middle">~/automation-lab</text>
<text class="s" x="360" y="135" text-anchor="middle">Kasutaja mõlemas masinas: kasutaja</text>
</svg>
<figcaption>Joonis 4.1. Käsitsi ja Bashiga töötad web01-s. Ansible'i käivitad control node'il ja see teeb töö web01-s SSH kaudu.</figcaption>
</figure>

### Kõigepealt käsitsi

Enne automatiseerimist teed ülesande web01-s käsitsi. See pole raisatud aeg. Nii näed, mida iga käsk teeb, ja leiad eeldused, mis valmis skripti lugedes märkamata jäävad. Kas tee on suhteline praeguse kausta suhtes või täielik? Mis kasutajana sa töötad? Mis juhtub, kui fail on juba olemas?

Iga käsu eel ütle välja, mida ootad. Iga käsu järel vaata tulemust. Ära oota lõpuni, et avastada, et esimene käsk tegi kausta valesse kohta.

Pea meeles ka seda: kui käsk ei trüki midagi, ei tähenda see veel, et kogu ülesanne on õigesti tehtud. Tõend on see, mida kontrollnimekiri küsib: tee, sisu, omanik ja õigused.

??? question "Kontrolli ennast"

    1. Mis vahe on lausetel „tee kaust“ ja „kaust on olemas õigustega 0750“?
    2. Miks tasub ülesanne enne automatiseerimist käsitsi läbi teha?

## 5. Bash kui esimene samm

**Küsimus:** kuidas tuttavatest käskudest saab väike programm?

Skript ei ole lihtsalt koht, kuhu käsud salvestada. Selle kirjutamisel pead otsustama, millised väärtused võivad muutuda, mida eeldad, kuidas vastad veale ja kuidas tunned ära edu.

### Shell on ka programmeerimiskeel

Kui kirjutad terminali käsu, loeb ja täidab selle **shell**. GNU Bashi juhend kirjeldab shelli kahe asjana: käskude tõlgendaja ja programmeerimiskeel. Sama Bash, mis täidab sinu käske terminalis, oskab neid täita ka failist. Sul on juba tuttavad käsud; nüüd lisad nende ümber programmeerimise võtted.

### Käsud faili

Skript on tekstifail. Esimene rida ütleb, millise programmiga faili käivitada:

```bash
#!/usr/bin/env bash
```

Seda rida nimetatakse **shebang**'iks. Skripti saab käivitada kahel viisil: `bash prepare-training.sh` (valid ise Bashi) või `./prepare-training.sh` (fail peab olema käivitatav, `chmod u+x`, ja shebang ütleb, mis programm seda loeb). Meie skript kasutab Bashi võimalusi, seega ära käivita seda käsuga `sh`.

### Muutuja: väärtusele nimi

**Muutuja** hoiab väärtust nime all. Nii eraldad töö käigu väärtustest, mis võivad muutuda:

```bash
lab_dir="$HOME/automation-lab"
```

`$HOME` on sinu kodukaust ja `$lab_dir` annab muutuja väärtuse tagasi. Võrdusmärgi ümber ei tohi olla tühikuid. `lab_dir = "..."` ei ole muutuja omistamine, Bash proovib siis käivitada käsku nimega `lab_dir`.

Muutuja on kasulik, kui ta annab väärtusele mõistliku nime või kui väärtust on vaja muuta ühes kohas. Iga sõna pole vaja muutujaks teha.

### Jutumärgid

Jutumärgid ütlevad Bashile, kuidas teksti lugeda. Topeltjutumärkides (`"$lab_dir"`) asendatakse muutuja väärtusega ja tühikuga tee jääb üheks argumendiks. Ühekordsetes jutumärkides (`'$HOME'`) jääb tekst täpselt selliseks, nagu see on kirjas.

Praktiline harjumus: **pane muutuja alati topeltjutumärkidesse**, kui see läheb käsule argumendiks. Erand ainult siis, kui tead täpselt, miks.

### `>` kirjutab üle, `>>` lisab lõppu

```bash
printf '%s\n' 'environment=training' 'enabled=true' > "$lab_dir/training.conf"
```

`printf` trükib read ja `>` suunab väljundi faili. `>` loob faili, kui seda pole, ja **tühjendab olemasoleva faili** enne kirjutamist. `>>` lisab olemasoleva faili lõppu.

Meie ülesandes on ülekirjutamine õige, sest fail on täielikult skripti hallata. Kui kasutaksid `>>`-i, lisanduks igal käivitusel kaks rida juurde. Ära kunagi kasuta `>`-i tähtsa faili peal, kui sa ei tea, mida see üle kirjutab.

### Väljumiskood

Iga käsk lõpetab **väljumiskoodiga** (exit status). `0` tähendab õnnestumist, muu number ebaõnnestumist. Viimase käsu koodi näed muutujast `$?`. Ekraanil olev tekst on inimesele, väljumiskood on teisele programmile, ka sinu skriptile.

### `if`: otsus käsu tulemuse järgi

`if` vaatab käsu väljumiskoodi ja valib haru:

```bash
if ! mkdir -p "$lab_dir"; then
    printf 'Viga: ei saa kausta teha: %s\n' "$lab_dir" >&2
    exit 1
fi
```

Loe nii: „kui kausta tegemine **ei** õnnestu, kirjuta viga ja lõpeta“. `!` pöörab tulemuse ümber, `>&2` saadab teate veaväljundisse ja `exit 1` lõpetab skripti mitte-nulli koodiga, et ka teine programm saaks aru, et tekkis viga.

Skripti mõte on lihtne: iga tähtis samm on `if`-i sees ja vea korral skript peatub ning ütleb, mis juhtus. Praktikumis käivitad selle web01-s.

??? example "Terviknäide: kuidas osad kokku sobivad"

    ```bash
    #!/usr/bin/env bash
    # Valmistab ette koolituse kausta ja konfiguratsioonifaili.

    lab_dir="$HOME/automation-lab"                       # 1: sisendid
    config_file="$lab_dir/training.conf"

    if ! mkdir -p "$lab_dir"; then                       # 2: kaust
        printf 'Viga: ei saa kausta teha: %s\n' "$lab_dir" >&2
        exit 1
    fi
    if ! chmod 0750 "$lab_dir"; then
        printf 'Viga: ei saa kausta õigusi muuta: %s\n' "$lab_dir" >&2
        exit 1
    fi

    if ! printf '%s\n' 'environment=training' 'enabled=true' > "$config_file"; then   # 3: fail
        printf 'Viga: ei saa faili kirjutada: %s\n' "$config_file" >&2
        exit 1
    fi
    if ! chmod 0640 "$config_file"; then
        printf 'Viga: ei saa faili õigusi muuta: %s\n' "$config_file" >&2
        exit 1
    fi

    printf 'Valmis: %s\n' "$config_file"                # 4: tulemus
    ```

    1. **Sisendid:** kaust ja fail on muutujates, nii saab neid muuta ühes kohas.
    2. **Kaust:** tehakse ja saab õigused `0750`.
    3. **Fail:** kirjutatakse üle soovitud sisuga ja saab õigused `0640`.
    4. **Kontroll:** iga tähtsa sammu järel vaatab `if` väljumiskoodi; vea korral skript peatub koodiga `1`, muidu ütleb lõpus `Valmis`.

??? note "Süvenemiseks: miks mitte lihtsalt `set -e`"

    `set -e` paneb Bashi lõpetama, kui mõni käsk ebaõnnestub. See on kasulik, aga mitte täielik veakäsitlus: `if`-i tingimuses, `&&` ja `||` ahelas ning mõnes muus kohas Bash ei peatu. Algaja skriptis on selgem kontrollida tähtsaid samme otse `if`-iga, nii et on näha, mis vea korral juhtub.

    Kuulus näide tühjast muutujast: Steam for Linuxi skript kustutas 2015. aastal kasutajate faile, sest kustutuskäsu tee algas muutujaga, mis jäi tühjaks ([PCWorld](https://www.pcworld.com/article/431317/scary-steam-for-linux-bug-erases-all-the-personal-files-on-your-pc.html)).

    `set -u` peatab skripti, kui kasutad muutujat, mida pole üldse määratud, aga mitte siis, kui muutuja on määratud ja tühi. Kuju `${MUUTUJA:?}` peatab mõlemal juhul. Ka sellest üksi ei piisa: enne kustutamist kontrolli, et tee on just see, mida kavatsed kustutada.

??? question "Kontrolli ennast"

    1. Mis vahe on käskudel `bash prepare-training.sh` ja `./prepare-training.sh`?
    2. Miks on `"$lab_dir"` jutumärkides?
    3. Mida teeb `>`, kui fail on juba olemas?

??? info "Loe juurde"

    - [GNU Bash: What is a shell?](https://www.gnu.org/software/bash/manual/html_node/What-is-a-shell_003f.html)
    - [GNU Bash: Exit Status](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html)
    - [GNU Bash: Conditional Constructs](https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html)
    - [Software Carpentry: The Unix Shell](https://swcarpentry.github.io/shell-novice/)
    - [ShellCheck](https://www.shellcheck.net/): kontrollib skripti levinud vigade suhtes

## 6. Rohkem kui käskude jada

**Küsimus:** mis juhtub, kui olukord on teine või käivitame töö uuesti?

Esimene õnnestunud käivitus vastab ainult ühele küsimusele: kas skript töötab nendes tingimustes, mida just proovisid. Usaldusväärsuse kohta ütleb see vähe.

### Kui midagi läheb valesti

Kaust võib olla kirjutamiseks lukus. Tees võib olla trükiviga. Kausta kohal võib olla samanimeline fail. Esimene samm võib ebaõnnestuda ja järgmised siiski õnnestuda.

Praktikumis tekitad kontrollitud vea ja ennustad enne:

- Kus skript peaks peatuma?
- Mida ta peaks sulle ütlema?
- Kas midagi jääb poolikuks?
- Kuidas seda kontrollid?
- Mis juhtub pärast vea parandamist?

Meie skript peatub vea juures, aga ei võta juba tehtud samme tagasi. Kui fail kirjutati, aga õiguste muutmine ebaõnnestus, jääb fail alles valede õigustega. **Peatumine ja tagasivõtmine on kaks eri nõuet.** Eesmärk ei ole, et esimene skript lahendaks iga võimaliku olukorra. Eesmärk on, et viga oleks osa kavandist, mitte üllatus.

### Teine käivitus

Käivita skript teist korda ilma midagi koristamata. Enne pane kirja, mida ootad: kas see õnnestub, kas fail kirjutatakse üle, kas ta kaebab, et kaust on juba olemas? Need on eri küsimused.

Meie skript kirjutab faili igal käivitusel uuesti. Tulemus on sama, aga töö tehakse ikkagi ära. **Sama lõpptulemus ei tähenda, et midagi ei tehtud.** Päris teenuse puhul võib iga ülekirjutus tähendada teenuse taaskäivitust ja katkenud ühendusi.

### Triiv: keegi muutis faili

Seejärel muudad faili käsitsi, näiteks paned `enabled=false`, ja käivitad skripti uuesti. Skript taastab õige sisu, sest me otsustasime, et fail on täielikult automaatika hallata.

See on kavandi otsus, mitte iga skripti omadus. Mõne faili puhul oleks ülekirjutamine vale, sest seal on teiste inimeste seadeid. Enne kui hindad, kas teostus on õige, pead teadma, mis käitumist sa tahad.

### Idempotentsus

Omadust, et korduv käivitus ei muuda enam midagi, kui soovitud seis on juba olemas, nimetatakse **idempotentsuseks**. Bashis saad selle ise kirjutada: enne muutmist kontrolli, kas muutmine on vaja. Iga sellise kontrolli pead aga ise välja mõtlema ja kirjutama. Meie kasutatavad Ansible'i `file`- ja `copy`-moodulid sisaldavad vajalikke seisukontrolle juba valmis kujul.

??? note "Süvenemiseks: kirjuta ainult siis, kui sisu erineb"

    ```bash
    if ! printf '%s\n' 'environment=training' 'enabled=true' | cmp -s - "$config_file"; then
        printf '%s\n' 'environment=training' 'enabled=true' > "$config_file"
        printf 'Muudetud: %s\n' "$config_file"
    fi
    ```

    Toru `|` saadab esimese käsu väljundi teise käsu sisendiks. `printf` toodab soovitud sisu ja `cmp` võrdleb seda failiga. `-` tähendab „loe võrreldavat sisu torust“ ja `-s` paneb `cmp`-i vaikima: vastuse annab ainult väljumiskood (`0` = sama). Fail kirjutatakse ainult siis, kui sisu erineb.

??? question "Kontrolli ennast"

    1. Miks ei tõesta üks õnnestunud käivitus, et skript on usaldusväärne?
    2. Mis vahe on „skript peatub vea juures“ ja „skript võtab vea korral muudatuse tagasi“?
    3. Mida tähendab idempotentsus ja kas Bashi skript võib olla idempotentne?

## 7. Sissejuhatus Ansible'isse

**Küsimus:** kuidas kirjeldada ja hallata seadistust, mida tahame?

### Mis on Ansible

**Ansible** on avatud lähtekoodiga programm serverite seadistamiseks. Sa kirjutad tekstifaili, milline peab masin olema: millised paketid on paigaldatud, millised failid on olemas, millised teenused töötavad. Ansible loeb selle faili, ühendub SSH-ga masinatesse ja teeb seal ainult need muudatused, mis on puudu.

Ansible'i lõi Michael DeHaan 2012. aastal ja alates 2015. aastast arendab seda Red Hat koos kogukonnaga. Seda kasutatakse serverite seadistamiseks, rakenduste paigaldamiseks, uuenduste levitamiseks ning võrguseadmete ja pilveressursside haldamiseks. Põhimõte on igal pool sama: **kirjeldad soovitud seisu, Ansible viib masina sinna**.

Kolm asja eristavad Ansible'it Bashi skriptist:

- **Soovitud seis, mitte käsud.** Kirjutad „kaust on olemas õigustega 0750“, mitte „tee kaust, siis muuda õigusi“. Kontrolli, kas muutmine on vaja, teeb Ansible.
- **Mitu masinat korraga.** Sama faili saab käivitada ühe või saja masina vastu.
- **Agenti pole vaja.** Hallatavasse masinasse ei paigaldata midagi lisaks, piisab SSH-st ja Pythonist.

Ansible ei ole operatsioonisüsteem, veebiteenus ega asendus Linuxi teadmistele. See on käsurea programm, mis käivitub control node'il. Teed, kasutajad ja õigused tuleb endiselt ise mõista; muutub see, kuidas tööd kirjeldad.

Meie ülesanne jääb samaks: sama kaust ja sama fail web01-s. Uus on ainult see, kuidas Ansible tööd kirjeldab ja teeb.

### Kus Ansible jookseb

Ansible on paigaldatud ainult **control node**'ile. Masinat, mida ta seadistab, nimetatakse **hallatavaks masinaks** (managed node), meil on see web01. Hallatavas masinas ei pea Ansible'it olema, piisab SSH-st ja Pythonist. Ansible ühendub SSH-ga, teeb töö ja võtab tulemuse tagasi.

Ansible oskab kasutada ka parooli (`--ask-pass`), aga selles laboris kasutame SSH-võtit: praktikumis teed control node'il võtmepaari ja viid avaliku võtme web01-le, nii et ühendus ei küsi parooli.

??? note "Kohalik ühendus ei ole sama mis kaugühendus"

    Ansible võib töötada ka samas masinas, kus ta on paigaldatud (`connection: local`). See on mugav proovimiseks, aga siis ei kasutata SSH-d ega kontrollita, kas võti ja kasutaja on õiged. Meie kasutame kogu aeg päris kaugühendust web01-le.

### Inventory: millised masinad

**Inventory** on fail, kus on kirjas masinad, mida Ansible haldab, ja kuidas nendega ühenduda:

```ini
[veeb]
web01 ansible_host=<web01-ip> ansible_user=kasutaja
```

`[veeb]` on grupp, `web01` on nimi, mida kasutad käskudes, ja `ansible_host` on aadress. Salvesta see faili `inventory.ini`. Võti `-i` ütleb Ansible'ile, millist inventory't kasutada:

```bash
ansible -i inventory.ini web01 -m ansible.builtin.ping
```

Vastus `pong` tähendab, et Ansible jõuab masinani ja seal töötab Python. Võrguühenduse `ping`-iga sellel pole pistmist.

### Moodul, ülesanne, playbook

**Moodul** on Ansible'i valmis tööriist ühe asja jaoks: `ansible.builtin.file` haldab kaustu ja õigusi, `ansible.builtin.copy` faili sisu. **Ülesanne** (task) on üks mooduli kasutus koos väärtustega. **Playbook** on YAML-fail, kus on kirjas, millistes masinates millised ülesanded täita.

```yaml
- name: Koolituse seadistus
  hosts: web01
  tasks:
    - name: Kaust on olemas
      ansible.builtin.file:
        path: /home/kasutaja/automation-lab
        state: directory
        mode: "0750"

    - name: Konfiguratsioonifail on olemas
      ansible.builtin.copy:
        dest: /home/kasutaja/automation-lab/training.conf
        content: |
          environment=training
          enabled=true
        mode: "0640"
```

Pane tähele ülesannete nimesid: „Kaust **on** olemas“, mitte „Tee kaust“. Playbook kirjeldab seisu, mitte tegevust.

### YAML minimaalselt

YAML on lihtne tekstivorming, kus struktuur tuleb **taandest**. Kolm reeglit katavad meie playbook'i:

- `võti: väärtus` paar, koolon ja tühik pärast koolonit;
- `-` alustab loendi elementi (iga ülesanne on loendi element);
- taane on tühikutega, mitte tabulaatoriga, ja sama taseme read on sama kaugel.

Kõige sagedasem algaja viga on vale taane. Ansible ütleb siis `Syntax Error` ja rea numbri. Teine levinud viga on õigused ilma jutumärkideta: `mode: 0750` loetakse arvuna ja tulemus võib olla vale, `mode: "0750"` on ohutu.

### Soovitud seis ja tulemuse lugemine

Iga ülesande järel ütleb Ansible ühe sõna:

| Tulemus | Tähendus |
|---|---|
| `ok` | seis oli juba õige, midagi ei muudetud |
| `changed` | Ansible muutis midagi, et seis saaks õigeks |
| `failed` | ülesanne ebaõnnestus, sellel masinal edasi ei minda |

*Tabel 7.1. Ansible'i ülesande tulemus.*

Kui kausta ja faili veel pole, teatavad ülesanded esimesel käivitusel `changed`. Kui käsitsi või Bashiga tehtud seadistus vastab juba nõuetele, on tulemus kohe `ok`: Ansible ei muuda midagi ainult sellepärast, et teda käivitati. Muutmata keskkonnas annab järgmine käivitus kokkuvõttes `changed=0`. See näitab, et selles katses käitus playbook idempotentselt.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 150" role="img" aria-label="Soovitud ja tegelik faili sisu võrreldakse; kui erineb, kirjutatakse ja tulemus on changed, kui sama, ei kirjutata ja tulemus on ok" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxi" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="10" width="200" height="56" rx="8"/><text class="b" x="110" y="33" text-anchor="middle">Soovitud sisu</text><text class="s" x="110" y="52" text-anchor="middle">playbook'is</text>
<rect class="box" x="10" y="84" width="200" height="56" rx="8"/><text class="b" x="110" y="107" text-anchor="middle">Tegelik sisu</text><text class="s" x="110" y="126" text-anchor="middle">web01 training.conf</text>
<line class="a" x1="210" y1="38" x2="268" y2="68" marker-end="url(#lxi)"/><line class="a" x1="210" y1="112" x2="268" y2="82" marker-end="url(#lxi)"/>
<rect class="hi" x="270" y="50" width="130" height="50" rx="8"/><text class="b" x="335" y="80" text-anchor="middle">Võrdlus</text>
<line class="a" x1="400" y1="68" x2="458" y2="38" marker-end="url(#lxi)"/><line class="a" x1="400" y1="82" x2="458" y2="112" marker-end="url(#lxi)"/>
<rect class="box" x="460" y="10" width="250" height="56" rx="8"/><text class="b" x="585" y="33" text-anchor="middle">Erineb → kirjuta</text><text class="c" x="585" y="53" text-anchor="middle">changed</text>
<rect class="box" x="460" y="84" width="250" height="56" rx="8"/><text class="b" x="585" y="107" text-anchor="middle">Sama → ära kirjuta</text><text class="c" x="585" y="127" text-anchor="middle">ok</text>
</svg>
<figcaption>Joonis 7.1. Moodul võrdleb soovitud ja tegelikku sisu ning kirjutab ainult siis, kui need erinevad.</figcaption>
</figure>

Kui muudad web01-s faili käsitsi ja käivitad playbook'i uuesti, näed `changed` ainult failiülesandel. Ansible leidis erinevuse ja taastas õige sisu. Võti `--check --diff` näitab enne, mida Ansible muudaks, ilma midagi muutmata.

??? warning "Kõik ei ole automaatselt idempotentne"

    Enamik mooduleid kontrollib ise, kas muudatust on vaja. Toore käsu puhul (`ansible.builtin.command`, `ansible.builtin.shell`) ei tea Ansible, mis on soovitud lõppseis. Ilma lisakontrollita võib selline ülesanne teatada `changed` igal käivitusel. Ära ütle „Ansible on idempotentne ja Bash mitte“. Võrdleme konkreetseid teostusi: skriptis saab kontrolli kirjutada ja playbook'is saab selle ära rikkuda.

??? question "Kontrolli ennast"

    1. Kus Ansible jookseb ja mida on vaja hallataval masinal?
    2. Mida tähendab `changed=0` teisel käivitusel?
    3. Miks on playbook'is `mode: "0750"` jutumärkides?

??? info "Loe juurde (Ansible'i ametlik dokumentatsioon)"

    - [Getting started with Ansible](https://docs.ansible.com/projects/ansible/latest/getting_started/index.html)
    - [Building an inventory](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_inventory.html)
    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
    - [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
    - [Check mode ja diff](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)
    - Järgmisel kohtumisel: [Conditionals (`when`)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_conditionals.html) ja [Tags](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_tags.html)

## 8. Kontroll ja vastutustundlik käivitamine

**Küsimus:** kust tead, et muutsid õiget asja õigesti?

### Aruanne ei ole tulemus

Tööriista aruanne räägib käivitusest. Kontroll peab vaatama seisu, mida tahtsid saavutada. Need on kaks eri küsimust:

> Kas automaatika teatas, et sai valmis?

> Kas masina seis vastab nõuetele?

Ülesanne on tehtud alles siis, kui mõlemale saab vastata „jah“. Seepärast vaatad pärast iga teostust web01-s ise järele:

```bash
cat ~/automation-lab/training.conf
stat -c '%a %U %n' ~/automation-lab ~/automation-lab/training.conf
```

Õige fail vales kohas ei ole nõutud tulemus. Õige sisu valede õigustega ei ole veel valmis. Õnnestunud käivitus vale masina vastu ei täida ülesannet.

### Enne käivitamist: kus, mida, kelle õigustega

Enne kui käivitad midagi, mis muudab masinat, vasta endale:

- **Kus?** Millises masinas see töö tehakse? Kas inventory's on õige masin?
- **Mida?** Millist teed see muudab?
- **Kellena?** Mis kasutajana ja kas `sudo`-t on vaja? Meie ülesanne ei vaja `sudo`-t.
- **Mis siis, kui läheb valesti?** Kas tead, kuidas seisu kontrollida ja parandada?

Ansible'is aitavad kaks võtit: `--check --diff` näitab muudatust enne tegemist ja `--limit web01` piirab töö ühe masinaga, isegi kui inventory's on neid rohkem.

??? example "CrowdStrike 2024: kontroll ja levitamise ulatus"

    CrowdStrike'i katkestus toimus 19. juulil 2024, kui Falconi vigane sisukonfiguratsiooni uuendus põhjustas ulatusliku Windowsi süsteemide katkestuse ([juurpõhjuse analüüs](https://crowdstrike.com/wp-content/uploads/2024/08/Executive-Summary_Root-Cause-Analysis_Channel-File-291.pdf)). Juhtum näitab, et muudatuse kontrollimine ja selle levitamise ulatuse piiramine on eraldi ülesanded. Laboris teeme sama väikses mahus: alusta ühest masinast (`--limit`), kontrolli tulemust ja alles siis laienda muudatust.

??? question "Kontrolli ennast"

    1. Miks ei piisa sellest, et Ansible teatas `ok`?
    2. Millised neli küsimust esitad endale enne muutva käsu käivitamist?

## 9. Kokkuvõte

- **Tulemus enne käske:** kirjuta enne, mis peab olema ja kuidas seda kontrollid.
- **Käsitsi enne automaatikat:** mõista tööd enne, kui annad selle arvutile.
- **Skript on otsused:** muutujad, jutumärgid, väljumiskood ja `if` ütlevad, mis juhtub, kui olukord on teine.
- **Teine käivitus on eraldi nõue:** sama tulemus ei tähenda, et midagi ei tehtud.
- **Ansible kirjeldab seisu:** inventory ütleb kus, playbook ütleb mis, moodul võrdleb ise.
- **Aruanne ei ole tulemus:** kontrolli masinat ennast.

Oskad nüüd lugeda ja käivitada väikest playbook'i. Järgmisel kohtumisel ehitame sellest mitme masina seadistamise lahenduse: grupid, muutujad, mallid ja rollid.
