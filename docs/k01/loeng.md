---
tags:
  - Bash
  - Ansible
  - Loeng
---

# 1. kohtumine · Linuxi haldusest automatiseerimiseni

??? abstract "Õpiväljundid"

    Pärast kohtumist oskad:

    - selgitada, millal on korduva töö automatiseerimine mõistlik;
    - kirjeldada ülesannet soovitud tulemusena ja määrata, kuidas tulemust kontrollida;
    - selgitada Bashi skripti ja Ansible'i playbook'i erinevat tööpõhimõtet;
    - kasutada mõisteid *control node*, *hallatav masin*, *inventory*, *moodul*, *ülesanne* ja *playbook*;
    - käivitada playbook'i ning tõlgendada tulemusi `ok`, `changed` ja `failed`.

!!! info "Päeva ülesanne"

    Masinas **web01** peab kasutaja `kasutaja` kodukaustas olema kaust `automation-lab` õigustega `0750` ja selles fail `training.conf` õigustega `0640`. Failis on kaks rida:

    ```ini
    environment=training
    enabled=true
    ```

    Need väärtused on harjutuse nõuded, mitte soovitus rakenduse seadistamiseks.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 95" role="img" aria-label="Sama ülesanne kolmel viisil: käsitsi, Bashi skriptiga ja Ansible'iga, iga kord sama kontroll" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:15px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxt" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="20" width="160" height="60" rx="8"/><text class="b" x="90" y="47" text-anchor="middle">Käsitsi</text><text class="s" x="90" y="66" text-anchor="middle">mkdir, printf, chmod</text>
<line class="a" x1="170" y1="50" x2="198" y2="50" marker-end="url(#lxt)"/>
<rect class="box" x="200" y="20" width="160" height="60" rx="8"/><text class="b" x="280" y="47" text-anchor="middle">Bashi skript</text><text class="s" x="280" y="66" text-anchor="middle">sammud failis</text>
<line class="a" x1="360" y1="50" x2="388" y2="50" marker-end="url(#lxt)"/>
<rect class="box" x="390" y="20" width="160" height="60" rx="8"/><text class="b" x="470" y="47" text-anchor="middle">Ansible</text><text class="s" x="470" y="66" text-anchor="middle">soovitud olek</text>
<line class="a" x1="550" y1="50" x2="578" y2="50" marker-end="url(#lxt)"/>
<rect class="hi" x="580" y="20" width="130" height="60" rx="8"/><text class="b" x="645" y="47" text-anchor="middle">Kontroll</text><text class="s" x="645" y="66" text-anchor="middle">cat, stat</text>
</svg>
<figcaption>Joonis 1.1. Päeva lugu: üks ülesanne, kolm teostust, üks kontroll.</figcaption>
</figure>

## 1. Miks automatiseerida?

**Küsimus:** ma oskan Linuxit hallata. Milleks mulle veel üks töötamise viis?

### Miks korduvat tööd automatiseerida?

Kui sama seadistust tehakse käsitsi mitmes serveris, jääb mõnes neist kergesti mõni samm tegemata. Viga ilmneb sageli alles hiljem, näiteks pärast uuendust või taaskäivitust, ja selle põhjust on raske leida, sest serverite soovitud olek on kirjas ainult inimese mälus.

Automatiseerimise eesmärk on muuta korduv töö korratavaks, kontrollitavaks ja teistele arusaadavaks.

### Mida automatiseerida ja mida veel mitte

Kõike ei ole mõtet automatiseerida. Automatiseerimise kandidaati saab hinnata kolme küsimusega:

| Küsimus | Näide |
|---|---|
| Kui sageli seda tehakse? | kuine turvauuendus 40 serveris |
| Kui palju maksab käsitsi tehtud viga? | aasta tagasi tehtud sertifikaadi vahetus, mille sammud on ununenud |
| Kui kaua üks kord aega võtab? | uue töötaja kasutajakontod kuues süsteemis |

*Tabel 1.1. Kolm küsimust automatiseerimise kandidaadile.*

Harva tehtava, lihtsa ja väikese riskiga töö puhul võib piisata juhendist. Automaatikal on oma hind: see tuleb kirjutada, testida ja hooldada. Google'i SRE raamat nimetab käsitsi tehtavat, korduvat ja masinate arvuga kasvavat tööd sõnaga *toil*. Just sellist tööd tasub automatiseerida esimesena.

??? question "Mõtle"

    Millist tööd teed oma töökohal iga nädal samamoodi? Kui sul töökogemust pole, mõtle varasemale Linuxi praktikumile. Kas see vastab kolmele küsimusele tabelis 1.1?

??? info "Loe juurde"

    - [Google SRE: Eliminating Toil](https://sre.google/sre-book/eliminating-toil/)
    - [Google SRE: Lessons Learned from Other Industries](https://sre.google/sre-book/lessons-learned/)

## 2. Kuidas töötamise viis on muutunud

**Küsimus:** miks inimesed käsitsi haldusest kaugemale liikusid?

Lihtsustatult on haldustöö arenenud viie sammuna: käsitsi tehtud töö, kirjalik juhend, skript, konfiguratsioonihaldus ja lõpuks Gitis hoitav kood, mille kolleeg enne käivitamist üle vaatab. Iga järgmise sammuga on rohkem teadmisi kirja pandud ja vähem jääb inimese mällu.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 140" role="img" aria-label="Viis sammu: käsitsi, kirjalik juhend, skript, konfiguratsioonihaldus, versioonihalduses ja üle vaadatud kood" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxp2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="5" y="20" width="126" height="70" rx="8"/><text class="b" x="68" y="48" text-anchor="middle">Käsitsi</text><text class="s" x="68" y="68" text-anchor="middle">mälu, shelli ajalugu</text>
<line class="a" x1="131" y1="55" x2="147" y2="55" marker-end="url(#lxp2)"/>
<rect class="box" x="149" y="20" width="126" height="70" rx="8"/><text class="b" x="212" y="48" text-anchor="middle">Juhend</text><text class="s" x="212" y="68" text-anchor="middle">inimene loeb</text>
<line class="a" x1="275" y1="55" x2="291" y2="55" marker-end="url(#lxp2)"/>
<rect class="box" x="293" y="20" width="126" height="70" rx="8"/><text class="b" x="356" y="48" text-anchor="middle">Skript</text><text class="s" x="356" y="68" text-anchor="middle">arvuti täidab</text>
<line class="a" x1="419" y1="55" x2="435" y2="55" marker-end="url(#lxp2)"/>
<rect class="box" x="437" y="20" width="126" height="70" rx="8"/><text class="b" x="500" y="48" text-anchor="middle">Konfihaldus</text><text class="s" x="500" y="68" text-anchor="middle">soovitud olek</text>
<line class="a" x1="563" y1="55" x2="579" y2="55" marker-end="url(#lxp2)"/>
<rect class="box" x="581" y="20" width="134" height="70" rx="8"/><text class="b" x="648" y="48" text-anchor="middle">Kood Gitis</text><text class="s" x="648" y="68" text-anchor="middle">üle vaadatud</text>
<text class="s" x="360" y="122" text-anchor="middle">Iga samm teeb midagi rohkem kirjalikuks. Eelmine samm ei kao.</text>
</svg>
<figcaption>Joonis 2.1. Lihtsustatud järjekord. Paljud meeskonnad kasutavad kõiki viite korraga.</figcaption>
</figure>

| Samm | Mida kirjeldab | Kes otsustab, kas muuta on vaja | Tüüpiline risk |
|---|---|---|---|
| Käsitsi | ei midagi, teadmine on peas | inimene | keegi ei tea, mis tehti |
| Juhend | samme inimesele | inimene igal sammul | samm jääb vahele |
| Skript | käskude järjekorda | skripti autor, kui ta kontrolli kirjutas | teine käivitus teeb sama töö uuesti |
| Konfiguratsioonihaldus | soovitud olekut | tööriista moodul | toores käsk ilma kontrollita |
| Kood Gitis | kõike ülaltoodut koos ajalooga | ülevaataja enne käivitamist | ülevaatus jääb formaalseks |

*Tabel 2.1. Mida iga samm kirjeldab ja kus on risk.*

Ükski samm ei asenda eelmisi. Näiteks Eesti X-tee avalikus repositooriumis on kõrvuti paigaldusjuhend inimesele ja Ansible'i playbook'id meeskonnale, kes ehitab sama keskkonda kümneid kordi. Järjekord on sama: **tee kõigepealt käsitsi, siis kirjuta üles, siis automatiseeri.**

??? note "Süvenemiseks: snowflake server ja drift"

    Kolm aastat töötanud serveris on keegi kunagi lisanud `/etc/hosts`-i rea, muutnud mõnda seadet ja paigaldanud paketi, mida keegi enam ei mäleta. Martin Fowler nimetab sellist masinat *snowflake server*'iks: see on ainulaadne ja keegi ei julge seda uuesti ehitada.

    Masinate vahelisi väikeseid erinevusi nimetatakse **triiviks** (drift). Triivi ei hoia ära ka suur hoolikus, sest inimesed unustavad. Aitab see, kui masina soovitud olek on kirjas ja seda kirjeldust rakendatakse korduvalt.

??? info "Loe juurde"

    - [Martin Fowler: SnowflakeServer](https://martinfowler.com/bliki/SnowflakeServer.html)
    - [X-tee repo (juhend ja Ansible kõrvuti)](https://github.com/nordic-institute/X-Road)

### Mida automatiseerimine tähendab

**IT-automatiseerimine** tähendab, et korduv töö on kirjas koodina, mida saab **kirjeldada**, **korrata** ja **kontrollida**. Automaatika ei paranda halba protsessi. Programm teeb täpselt seda, mis on kirjas, ka siis, kui kirjas on viga, ja teeb seda kõigis masinates korraga.

??? example "Knight Capital 2012: üks server kaheksast"

    Uus kood pidi käsitsi jõudma kaheksasse serverisse. Ühte jäi see kopeerimata ja seal käivitus vana funktsioon. USA väärtpaberikomisjoni [otsuse](https://www.sec.gov/litigation/admin/2013/34-70694.pdf) järgi kaotas firma 45 minutiga üle 460 miljoni dollari.

??? question "Mõtle: vastutus ja töökohad"

    Kui automaatika teeb kolleegi iganädalase töö, mis temast saab? Kes vastutab, kui automaatika teeb vea? World Economic Forumi [Future of Jobs Report 2025](https://www.weforum.org/publications/the-future-of-jobs-report-2025/) järgi kasvab nõudlus inimeste järele, kes automaatikat kirjutavad, üle vaatavad ja hooldavad.

## 3. Päeva ülesanne ja töökeskkond

**Küsimus:** mis peab tulemuseks olema ja kuidas seda kontrollime?

### Ülesanne ja kontrollnimekiri

Enne esimest käsku pane kirja, milline peab olema tulemus. „Tee kaust“ on tegevus, „kaust on olemas õigustega 0750“ on tulemus. Kontrollida saab ainult tulemust. Päeva ülesande põhjal koostad kontrollnimekirja, mida kasutad kõigi kolme lahenduse järel:

1. Kas kaust `/home/kasutaja/automation-lab` on olemas?
2. Kas failis `training.conf` on täpselt need kaks rida?
3. Kas kausta õigused on `750` ja faili õigused `640`?
4. Kas mõlemad kuuluvad kasutajale `kasutaja`?
5. Kas töö muutis ainult seda kohta, mitte midagi muud?

??? note "Sisend, eeldus, tulemus, viga"

    | Küsimus | Meie ülesandes |
    |---|---|
    | **Sisend:** mis võib muutuda? | kausta asukoht, faili sisu |
    | **Eeldus:** mis peab enne tõsi olema? | oled web01-s kasutajana `kasutaja`, kodukaust on kirjutatav |
    | **Tulemus:** kuidas tunned ära, et on tehtud? | kontrollnimekiri ülal |
    | **Viga:** mis võib valesti minna? | kaust pole kirjutatav, failinimes on viga, töö jääb poole peale |

### Töökeskkond

Töötad kahes masinas. **Control node** on masin, kust juhid tööd ja kuhu ühendud VS Code'iga. **web01** on masin, mida seadistad.

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
<figcaption>Joonis 3.1. Käsitsi ja Bashiga töötad web01-s. Ansible'i käivitad control node'il ja see teeb töö web01-s SSH kaudu.</figcaption>
</figure>

Praktikumis teed ülesande kõigepealt web01-s käsitsi ja kontrollid tulemust käskudega `cat` ja `stat`. Kui käsk ei väljasta midagi, ei tähenda see veel, et ülesanne on tehtud. Tulemust tõendab ainult kontrollnimekirja järgi tehtud kontroll.

## 4. Skript ja selle piir

**Küsimus:** miks ei piisa sellest, et käsud on failis?

Kui paned käsitsi tehtud käsud faili, saad skripti:

```bash
#!/usr/bin/env bash
mkdir -p ~/automation-lab
chmod 0750 ~/automation-lab
printf '%s\n' 'environment=training' 'enabled=true' > ~/automation-lab/training.conf
chmod 0640 ~/automation-lab/training.conf
```

Esimene rida määrab, et skripti käivitab Bash. Skripti käivitad käsuga `bash prepare-training.sh`. Skript teeb sama töö kiiresti ja alati samas järjekorras, kuid see skript ei kontrolli masina tegelikku olekut:

- **Teine käivitus kirjutab faili uuesti üle**, kuigi sisu on juba õige. Sama lõpptulemus ei tähenda, et midagi ei tehtud.
- **Kui üks käsk ebaõnnestub, jätkab skript järgmisega.** Pooleli jäänud töö jääb masinasse.
- **Iga kontrolli pead ise kirjutama.** Kas kaust on olemas, kas sisu on juba õige, kas õigused klapivad: igaüks on eraldi `if`.

Omadust, et korduv käivitus ei muuda midagi, kui soovitud olek on juba saavutatud, nimetatakse **idempotentsuseks**. Skriptis tuleb iga selline kontroll ise kirjutada. Ansible'i moodulites on need kontrollid juba olemas.

??? question "Kontrolli ennast"

    1. Mis juhtub failiga `training.conf`, kui käivitad skripti teist korda?
    2. Mida tähendab idempotentsus?

## 5. Ansible'i tutvustus

**Küsimus:** mis tööriist Ansible on ja kuidas see masinani jõuab?

**Ansible** on avatud lähtekoodiga tööriist serverite seadistamiseks. Tekstifailis kirjeldad, milline peab masin olema: millised paketid on paigaldatud, millised failid on olemas ja millised teenused töötavad. Ansible loeb faili, ühendub SSH kaudu masinatesse ja teeb seal ainult need muudatused, mis on vajalikud.

Seda kasutatakse serverite seadistamiseks, rakenduste paigaldamiseks, uuenduste levitamiseks ning võrguseadmete ja pilveressursside haldamiseks. Põhimõte on igal pool sama: **playbook kirjeldab soovitud olekut ning Ansible rakendab selle saavutamiseks vajalikud muudatused**.

### Lühike ajalugu

Ansible ilmus 2012. aastal. Varasemad konfiguratsioonihalduse tööriistad, näiteks Puppet ja Chef, vajasid igas hallatavas masinas agenti. Ansible kasutab olemasolevat SSH-ühendust, ei vaja agenti ja soovitud olek kirjeldatakse YAML-is. Alates 2015. aastast arendab Ansible'it Red Hat.

Kolm asja eristavad Ansible'it Bashi skriptist:

- **Soovitud olek, mitte käsud.** Kirjutad „kaust on olemas õigustega 0750“, mitte „tee kaust, siis muuda õigusi“. Ansible kontrollib ise, kas muudatus on vajalik.
- **Mitu masinat korraga.** Sama playbook'i saab käivitada nii ühes kui ka sajas masinas.
- **Agenti pole vaja.** Hallatavasse masinasse ei ole vaja paigaldada püsivat Ansible'i agenti, piisab SSH-st ja Pythonist.

Ansible ei ole operatsioonisüsteem, veebiteenus ega asendus Linuxi teadmistele. See on käsurea programm, mis töötab control node'is. Failiteid, kasutajaid ja õigusi tuleb endiselt ise mõista. Muutub see, kuidas tööd kirjeldad.

Meie ülesanne jääb samaks: sama kaust ja sama fail web01-s. Uus on ainult see, kuidas Ansible tööd kirjeldab ja teeb.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 220" role="img" aria-label="Control node'il on inventory, playbook ja ansible-playbook; Ansible saadab mooduli SSH-ga web01-le, kus Python võrdleb soovitud ja tegelikku olekut ning tagastab ok või changed" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.12;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:13.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxw" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="hi" x="10" y="10" width="290" height="200" rx="10"/><text class="t" x="26" y="36">control node</text>
<rect class="box" x="26" y="50" width="258" height="38" rx="6"/><text class="c" x="40" y="74">inventory.ini</text><text class="s" x="272" y="74" text-anchor="end">kus</text>
<rect class="box" x="26" y="98" width="258" height="38" rx="6"/><text class="c" x="40" y="122">training.yml</text><text class="s" x="272" y="122" text-anchor="end">mis</text>
<rect class="box" x="26" y="146" width="258" height="46" rx="6"/><text class="c" x="40" y="174">ansible-playbook</text><text class="s" x="272" y="174" text-anchor="end">käivitab</text>
<line class="a" x1="300" y1="90" x2="418" y2="90" marker-end="url(#lxw)"/><text class="s" x="359" y="80" text-anchor="middle">SSH: moodul</text>
<line class="a" x1="420" y1="140" x2="302" y2="140" marker-end="url(#lxw)"/><text class="s" x="361" y="160" text-anchor="middle">ok / changed</text>
<rect class="box" x="420" y="10" width="290" height="200" rx="10"/><text class="t" x="436" y="36">web01</text>
<text class="b" x="436" y="76">1. Python käivitab mooduli</text>
<text class="b" x="436" y="116">2. võrdleb soovitud ja tegelikku</text>
<text class="b" x="436" y="156">3. muudab ainult erinevuse</text>
<text class="s" x="436" y="190">pärast tööd moodul kustutatakse</text>
</svg>
<figcaption>Joonis 5.1. Ansible jookseb control node'il ja teeb töö hallatavas masinas SSH kaudu.</figcaption>
</figure>

### Kus Ansible jookseb

Ansible on paigaldatud ainult **control node**'i. Masinat, mida Ansible seadistab, nimetatakse **hallatavaks masinaks** (managed node). Meie ülesandes on see web01. Hallatavasse masinasse ei ole vaja Ansible'it paigaldada, piisab SSH-st ja Pythonist.

Iga ülesande jaoks saadab Ansible SSH kaudu web01-le väikese Pythoni programmi, **mooduli**, koos playbook'is määratud väärtustega. Moodul kontrollib hallatava ressursi tegelikku olekut, teeb vajaduse korral muudatuse ja tagastab tulemuse. Seejärel moodul kustutatakse. Hallatavasse masinasse ei ole vaja paigaldada püsivat Ansible'i agenti.

Ansible saab sisse logida ka parooliga (`--ask-pass`), kuid selles laboris kasutame SSH-võtit ja ühendus parooli ei küsi.

### Nõuded: millises masinas mida vaja on

| Masin | Mida vaja | Märkus |
|---|---|---|
| **control node** | Linux või macOS, Python 3, `ansible-core` | Windows otse control node'iks ei sobi; Windowsis töötab Ansible WSL-i kaudu |
| **Linuxi hallatav masin** | SSH ja Python 3 | Ansible'it sinna paigaldada pole vaja |
| **Windowsi hallatav masin** | WinRM või SSH ja PowerShell | moodulid on eraldi kogus `ansible.windows` |
| **võrguseade** (ruuter, kommutaator) | SSH või API | Pythonit seadmes pole: moodul jookseb control node'il ja saadab seadmele käsud |

*Tabel 5.2. Mida Ansible eri masinatelt eeldab.*

### Väikeses ja suures keskkonnas

**Väikeses keskkonnas**, nagu meie labor või väike IT-osakond, on Ansible paigaldatud ühte masinasse, näiteks administraatori control node'i või sülearvutisse. Inventory, `ansible.cfg` ja playbook'id on Gitis ning administraator käivitab `ansible-playbook`-i käsurealt või ajastatult (cron, systemd timer).

**Suuremas keskkonnas** saab samu playbook'e käivitada tsentraalse platvormi kaudu, näiteks AWX-i või Red Hat Ansible Automation Platformi abil. Platvorm lisab muu hulgas kasutajaõigused, ajastamise, saladuste halduse ja käivituste ajaloo.

Playbook on mõlemas keskkonnas sama. Selle kohtumise teadmised kehtivad ka suures ettevõttes.

??? note "Kohalik ühendus ei ole sama mis kaugühendus"

    Ansible võib töötada ka samas masinas, kuhu see on paigaldatud (`connection: local`). See on mugav proovimiseks, kuid siis ei kasutata SSH-d ega kontrollita, kas võti ja kasutaja on õiged. Laboris kasutame alati kaugühendust web01-ga.

??? question "Kontrolli ennast"

    1. Kus Ansible jookseb ja mida on vaja hallataval masinal?
    2. Mis on moodul ja mis juhtub sellega pärast ülesande täitmist?

??? info "Loe juurde"

    - [Getting started with Ansible](https://docs.ansible.com/projects/ansible/latest/getting_started/index.html)
    - [Connection methods and details](https://docs.ansible.com/projects/ansible/latest/inventory_guide/connection_details.html)
    - [Installing Ansible](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html): control node'i ja hallatava masina nõuded
    - [Windowsi haldamine Ansible'iga](https://docs.ansible.com/projects/ansible/latest/os_guide/intro_windows.html) ja [võrguautomaatika põhimõisted](https://docs.ansible.com/projects/ansible/latest/network/getting_started/basic_concepts.html)
    - [Execution environments](https://docs.ansible.com/projects/ansible/latest/getting_started_ee/index.html)
    - [Ansible Automation Platformi süsteeminõuded](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.4/html/red_hat_ansible_automation_platform_installation_guide/platform-system-requirements) (Red Hat)
    - [Red Hat: Ansible Automation Platformi oskuste rada](https://www.redhat.com/en/resources/ansible-automation-platform-skills-path)
    - [Red Hat: Ansible Automation Platform beginner's guide](https://www.redhat.com/en/resources/ansible-automation-platform-beginners-guide-ebook) (e-raamat)
    - Võrguinseneridele: [Red Hat: Network automation guide](https://www.redhat.com/en/resources/network-automation-guide-ebook) (e-raamat)
    - Harjuta brauseris: [Red Hati interaktiivsed laborid](https://www.redhat.com/en/interactive-labs#red-hat-ansible-automation-platform-labs) (tasuta, vajab Red Hati kontot)

## 6. Ansible'i seadistamine

**Küsimus:** kuidas Ansible teab, millised masinad on olemas ja kuidas neid kasutada?

### Paigaldamine

Ansible paigaldatakse ainult control node'ile. Kaks tavalist teed:

=== "Ubuntu, Debian"

    ```bash
    sudo apt update
    sudo apt install -y ansible-core
    ```

=== "AlmaLinux, RHEL"

    ```bash
    sudo dnf install -y ansible-core
    ```

=== "pipx (uusim versioon)"

    ```bash
    pipx install ansible-core
    ```

Paketihaldur paigaldab distributsiooni testitud versiooni, `pipx` uusima versiooni. Laboris kasutame paketihaldurit. Kontrolli paigaldust:

```bash
ansible --version
```

```text
ansible [core 2.16.3]
  config file = /home/kasutaja/kursus/k01/ansible.cfg
  configured module search path = [...]
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 3.12.3 (...)
  jinja version = 3.1.2
```

| Rida | Mida ütleb |
|---|---|
| `ansible [core 2.16.3]` | `ansible-core`'i versioon; sellest sõltub, millised moodulid ja võtmed on olemas |
| `config file` | milline `ansible.cfg` on kasutusel; `None` tähendab, et ühtegi ei leitud |
| `python version` | Python, millega Ansible control node'il jookseb |
| `jinja version` | mallimootor, mida läheb vaja 2. kohtumisel |

*Tabel 6.1. `ansible --version` väljund.*

### Inventory: millised masinad

**Inventory** on fail, kus on kirjas masinad, mida Ansible haldab, ja kuidas nendega ühenduda. Meie laboris:

```ini
[ubuntu]
web01
app01
rmq01

[alma]
mc01
db01

[all:vars]
ansible_user=kasutaja
```

| Osa | Tähendus |
|---|---|
| `[ubuntu]`, `[alma]` | grupid; nende abil saab käivitada ülesandeid korraga kõigis grupi masinates |
| `web01` | masina nimi; IP-aadress tuleb SSH konfiguratsioonifailist `~/.ssh/config` |
| `[all:vars]` | muutujad, mis kehtivad kõigile masinatele |
| `ansible_user` | kasutaja, kellena Ansible sisse logib |

*Tabel 6.2. Inventory osad.*

Kui masina nime ei ole SSH konfiguratsioonifailis ega DNS-is, kirjuta aadress inventory'sse: `web01 ansible_host=192.168.125.11`. Grupp `all` on alati olemas ja sisaldab kõiki masinaid. Salvesta fail nimega `inventory.ini`. Võtmega `-i` määrad, millist inventory't Ansible kasutab: `ansible -i inventory.ini ...`.

### `ansible.cfg`: projekti seaded

Et iga käsu juurde ei peaks kirjutama `-i inventory.ini`, pane projekti kausta fail `ansible.cfg`:

```ini
[defaults]
inventory = inventory.ini
```

Ansible otsib konfiguratsioonifaili kindlas järjekorras ja kasutab **esimest**, mille leiab:

| Järjekord | Kus | Millal kasutada |
|---|---|---|
| 1 | keskkonnamuutuja `ANSIBLE_CONFIG` | ajutiselt teine seadistus |
| 2 | `ansible.cfg` praeguses kaustas | **projekti seaded, meie valik** |
| 3 | `~/.ansible.cfg` | kasutaja isiklikud vaikeväärtused |
| 4 | `/etc/ansible/ansible.cfg` | kogu masina vaikeväärtused |

*Tabel 6.3. Kust Ansible konfiguratsiooni võtab.*

Millist faili Ansible parasjagu kasutab, näed käsu `ansible --version` väljundi realt `config file = ...`. Kui seal on `None`, ei leidnud Ansible ühtegi konfiguratsioonifaili ja võtit `-i` on jälle vaja. Hoia `ansible.cfg` koos inventory ja playbook'idega samas kaustas ja Gitis. Siis töötab projekt kõigi kasutajate masinates ühtemoodi.

### Kasutaja ja õigused

Ansible teeb hallatavas masinas tööd selle kasutajana, kellena ta SSH-ga sisse logib. Meil on see `kasutaja` (inventory's `ansible_user=kasutaja`) ja sisselogimine käib SSH-võtmega. Kõik, mida see kasutaja tohib, tohib ka Ansible. Meie päeva ülesanne käib kasutaja kodukaustas ja administraatori õigusi ei vaja.

Paketi paigaldamiseks, teenuse käivitamiseks või `/etc` all oleva faili muutmiseks on vaja administraatori õigusi. Selleks on **`become`**: Ansible logib sisse tavakasutajana ja käivitab ainult neid ülesandeid, kus see on vajalik, `sudo` kaudu kõrgemate õigustega.

```yaml
- name: Tööriistad on paigaldatud
  hosts: web01
  become: true
  tasks:
    - name: tree on paigaldatud
      ansible.builtin.package:
        name: tree
        state: present
```

```bash
ansible-playbook tools.yml
```

| Võti | Tähendus |
|---|---|
| `become: true` | selle play (või ühe ülesande) ajal tööta `sudo` kaudu |
| `become_user: postgres` | tõsta õigused mõne teise kasutajani, vaikimisi `root` |
| `-K` | küsib käivitamise alguses `sudo` parooli; vajalik, kui `sudo` nõuab parooli |

*Tabel 6.4. Õiguste tõstmine.*

Labori virtuaalmasinates ei küsi `sudo` parooli, seetõttu käivitame playbook'e ilma võtmeta `-K`. Töökohas nõuab `sudo` tavaliselt parooli ja siis lisatakse käsule `-K`.

Pane `become: true` ainult sinna, kus seda vaja on. Mida vähem õigusi, seda väiksem kahju vea korral.

### Kaks käsku: `ansible` ja `ansible-playbook`

| Käsk | Mida teeb | Näide |
|---|---|---|
| `ansible` | käivitab ühe mooduli kohe, ilma failita (ad-hoc) | `ansible web01 -m ansible.builtin.ping` |
| `ansible-playbook` | käivitab playbook'i: mitu ülesannet järjest | `ansible-playbook training.yml` |

*Tabel 6.5. Ansible'i kaks põhikäsku.*

`ansible web01 -m ansible.builtin.ping` on esimene kontroll. Vastus `pong` tähendab, et Ansible jõuab SSH kaudu masinasse ja seal töötab Python. Võrgukäsuga `ping` sellel seost ei ole. Ad-hoc käsk sobib kiireks kontrolliks, näiteks `ansible web01 -m ansible.builtin.command -a uptime`. Seadistus, mida soovid korrata, kirjuta playbook'i.

### Faktid: mida Ansible masinast teab

Moodul `ansible.builtin.setup` kogub masinast **fakte**: operatsioonisüsteemi, selle versiooni, mälu ja võrguliidesed. Fakte kasutatakse otsuste tegemiseks, näiteks selleks, et valida sobiv paketihaldur.

```bash
ansible web01 -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

```text
web01 | SUCCESS => {
    "ansible_facts": {
        "ansible_distribution": "Ubuntu",
        "ansible_distribution_version": "24.04",
        ...
```

AlmaLinuxi masinas on `ansible_distribution` väärtus `AlmaLinux`. Hiljem kasutad neid fakte tingimustes, et valida Ubuntu ja AlmaLinuxi jaoks sobivad ülesanded.

??? question "Kontrolli ennast"

    1. Mida tähendab inventory reas `ansible_host` ja mida `[veeb]`?
    2. Milleks on `ansible.cfg` ja kuidas näed, millist konfiguratsioonifaili Ansible kasutab?
    3. Mis vahe on käskudel `ansible` ja `ansible-playbook`?

??? info "Loe juurde"

    - [Building an inventory](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_inventory.html)
    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
    - [Configuring Ansible](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_configuration.html)
    - [Introduction to ad hoc commands](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)
    - [Discovering variables: facts](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_vars_facts.html)

## 7. Playbook'i kirjutamine ja käivitamine

**Küsimus:** kuidas kirjeldada soovitud olekut, käivitada playbook ja lugeda tulemust?

### Moodulid

Ansible'i **moodulid** täidavad konkreetseid haldusülesandeid. Alustamiseks piisab mõnest:

| Moodul | Mida haldab |
|---|---|
| `ansible.builtin.file` | kaustad, õigused, omanikud, lingid |
| `ansible.builtin.copy` | faili sisu (failist või tekstina) |
| `ansible.builtin.package` | paketid (`apt` või `dnf` vastavalt distributsioonile) |
| `ansible.builtin.service` | teenuse käivitamine, peatamine ja automaatne käivitamine süsteemi käivitumisel |
| `ansible.builtin.user` | kasutajad |
| `ansible.builtin.template` | failid mallist, kuhu tulevad muutujate väärtused (2. kohtumine) |
| `ansible.builtin.command` | toores käsk; Ansible ei tea, milline on soovitud olek |

*Tabel 7.1. Sagedasemad moodulid.*

Pikk nimi `ansible.builtin.file` ütleb, et moodul `file` on Ansible'iga kaasas olevas kogus `ansible.builtin`. Mooduli juhendi näed käsurealt:

```bash
ansible-doc ansible.builtin.file
```

Juhendi lõpus on näited (`EXAMPLES`), millest on kõige lihtsam alustada.

### Playbook: ülesanded järjest

**Playbook** on YAML-fail, milles on üks või mitu **play**'d. Iga play määrab, millistes masinates (`hosts`) millised **ülesanded** (`tasks`) täidetakse. Iga ülesanne kasutab üht moodulit koos parameetritega.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 230" role="img" aria-label="Playbook sisaldab play'd, play sisaldab ülesandeid, iga ülesanne kasutab üht moodulit koos parameetritega" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.12;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:13.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .c{fill:var(--md-default-fg-color);font-size:12.5px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<rect class="box" x="10" y="10" width="700" height="210" rx="10"/><text class="t" x="26" y="34">training.yml · playbook</text>
<rect class="hi" x="26" y="46" width="668" height="160" rx="8"/><text class="b" x="42" y="68">play · name: Koolituse seadistus · hosts: web01</text>
<rect class="box" x="42" y="82" width="310" height="110" rx="6"/><text class="b" x="56" y="104">ülesanne: Kaust on olemas</text><text class="c" x="56" y="132">ansible.builtin.file</text><text class="s" x="56" y="160">path · state: directory · mode</text><text class="s" x="56" y="180">moodul + parameetrid</text>
<rect class="box" x="368" y="82" width="310" height="110" rx="6"/><text class="b" x="382" y="104">ülesanne: Konfiguratsioonifail …</text><text class="c" x="382" y="132">ansible.builtin.copy</text><text class="s" x="382" y="160">dest · content · mode</text><text class="s" x="382" y="180">moodul + parameetrid</text>
</svg>
<figcaption>Joonis 7.1. Playbook'is on play, play'l sihtmasinad ja ülesanded, igal ülesandel üks moodul.</figcaption>
</figure>

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

Pane tähele ülesannete nimesid: „Kaust **on** olemas“, mitte „Tee kaust“. Playbook kirjeldab olekut, mitte tegevust. `state: directory` määrab, et see tee peab olema kaust. `content: |` tähendab, et järgmised taandega read on faili sisu.

### YAML minimaalselt

YAML on lihtne tekstivorming, kus struktuur tuleb **taandest**. Kolm reeglit katavad meie playbook'i:

- võtme ja väärtuse paar kujul `võti: väärtus`, kooloni järel on tühik;
- `-` alustab loendi elementi (iga ülesanne on loendi element);
- taane tehakse tühikutega, mitte tabulaatoriga, ja sama taseme read algavad samast veerust.

Kõige sagedasem viga on vale taane. Sel juhul annab Ansible teate `Syntax Error` koos rea numbriga. Teine levinud viga on õigused ilma jutumärkideta: `mode: 0750` loetakse arvuna ja tulemus võib olla vale. `mode: "0750"` on ohutu.

### Abivahendid

| Tööriist | Mida teeb |
|---|---|
| VS Code'i laiendus **Ansible** (`redhat.ansible`) | värvib YAML-i, näitab vigu kirjutamise ajal, pakub mooduli parameetreid |
| `ansible-doc <moodul>` | mooduli juhend ja näited käsureal |
| `ansible-playbook --syntax-check` | kontrollib, kas YAML ja playbook'i ülesehitus on korrektsed |
| **ansible-lint** | kontrollib playbook'e levinud vigade ja soovitatud stiilireeglite suhtes, näiteks moodul ilma eesliiteta `ansible.builtin.` või `mode` ilma jutumärkideta |

*Tabel 7.2. Abivahendid playbook'i kirjutamisel.*

```bash
ansible-playbook training.yml --syntax-check
ansible-lint training.yml
```

Suuremate projektide jaoks on Red Hatil veel [arendustööriistu](https://www.redhat.com/en/technologies/management/ansible/development-tools): **ansible-navigator** (playbook'i käivitamine ja tulemuse sirvimine), **Molecule** (rollide testimine) ja **ansible-builder** (käivituskeskkonna pakendamine). Neid kasutame hiljem.

### Tingimus, sihtmasinad ja sildid

Meie laboris on kaks distributsiooni. Samal programmil võib neis olla erinev paketinimi: Ubuntus `vim`, AlmaLinuxis `vim-enhanced`. **`when`** määrab tingimuse, mille korral ülesanne käivitatakse. Tingimus põhineb faktil:

```yaml
- name: vim on paigaldatud (AlmaLinux)
  ansible.builtin.package:
    name: vim-enhanced
    state: present
  when: ansible_facts['os_family'] == "RedHat"
  tags: paketid
```

| Vahend | Mida teeb | Näide |
|---|---|---|
| `when` | ülesanne käivitatakse ainult siis, kui tingimus on tõene; muidu on tulemus `skipping` | `when: ansible_facts['os_family'] == "Debian"` |
| `hosts` | millistes masinates play käivitatakse | `hosts: all`, `hosts: alma` |
| `--limit` | piirab käivitamise osaga masinatest, playbook'i muutmata | `ansible-playbook tools.yml --limit web01` |
| `tags` | ülesande silt; `--tags` käivitab ainult valitud siltidega ülesanded | `ansible-playbook tools.yml --tags motd` |

*Tabel 7.3. Tingimus, sihtmasinad ja sildid.*

### Mis juhtub käivitamisel

```bash
ansible-playbook training.yml
```

1. Ansible loeb inventory'st, kus asub `web01` ja kuidas sellega ühenduda.
2. Ansible loeb playbook'ist, milliseid ülesandeid täita.
3. **Gathering Facts:** Ansible kogub masinast fakte (operatsioonisüsteem, versioon, võrk). Väljundis on see esimene ülesanne.
4. Iga ülesande jaoks saadab Ansible SSH kaudu masinasse mooduli. Moodul võrdleb soovitud ja tegelikku olekut ning tagastab tulemuse.
5. **PLAY RECAP:** lõpus on kokkuvõte iga masina kohta.

```text
PLAY RECAP *********************************************************
web01   : ok=3  changed=2  unreachable=0  failed=0  skipped=0
```

| Väli | Tähendus |
|---|---|
| `ok` | ülesanded, mis lõppesid edukalt (ka need, mis muutsid) |
| `changed` | neist need, mis midagi muutsid |
| `unreachable` | masinasse ei saanud ühendust (SSH, võti, IP) |
| `failed` | ülesanne ebaõnnestus ja selles masinas järgmisi ülesandeid ei täideta |
| `skipped` | ülesanne jäeti tingimuse tõttu vahele (2. kohtumine) |

*Tabel 7.4. PLAY RECAP väljad.*

### Soovitud olek ja korduv käivitamine

Kui kausta ja faili veel ei ole, on ülesannete tulemus esimesel käivitusel `changed`. Kui käsitsi või Bashiga tehtud seadistus vastab juba nõuetele, on tulemus kohe `ok`: Ansible ei muuda midagi ainult seetõttu, et playbook käivitati. Kui keskkond vahepeal ei muutu, on järgmise käivituse kokkuvõttes `changed=0`. See näitab, et selles katses käitus playbook idempotentselt.

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
<figcaption>Joonis 7.2. Moodul võrdleb soovitud ja tegelikku sisu ning kirjutab ainult siis, kui need erinevad.</figcaption>
</figure>

Kui muudad web01-s faili käsitsi ja käivitad playbook'i uuesti, on `changed` ainult failiülesandel. Ansible leidis erinevuse ja taastas soovitud sisu. Võtmetega `--check --diff` näed enne käivitamist, mida Ansible muudaks, ilma midagi muutmata.

### Idempotentsus sõltub lahendusest

Enamik mooduleid kontrollib ise, kas muudatus on vajalik. Toore käsu puhul (`ansible.builtin.command`, `ansible.builtin.shell`) Ansible soovitud olekut ei tea. Ilma lisakontrollita võib selline ülesanne anda tulemuse `changed` igal käivitusel.

Seepärast ei ole õige öelda, et Ansible on idempotentne ja Bash mitte. Võrrelda tuleb konkreetseid lahendusi: Bashi skripti saab kirjutada idempotentseks ja playbook'i saab kirjutada nii, et see ei ole idempotentne.

??? question "Kontrolli ennast"

    1. Mis vahe on moodulil, ülesandel ja playbook'il?
    2. Kust leiad mooduli parameetrid ja näited?
    3. Millal on vaja `become: true`?
    4. Mis vahe on `ok` ja `changed` väljal PLAY RECAP reas?
    5. Mida tähendab `changed=0` korduval käivitamisel?

??? info "Loe juurde"

    - [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
    - [`ansible.builtin` moodulite nimekiri](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/index.html)
    - [YAML Syntax](https://docs.ansible.com/projects/ansible/latest/reference_appendices/YAMLSyntax.html)
    - [Understanding privilege escalation: become](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_privilege_escalation.html)
    - [Check mode ja diff](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)

## 8. Kontroll ja ohutu käivitamine

**Küsimus:** kuidas veenduda, et muudatus tehti õiges kohas ja õigesti?

### Aruanne ei ole tulemus

Tööriista aruanne kirjeldab käivitamist. Kontroll peab vaatama, kas soovitud olek on saavutatud. Need on kaks eri küsimust:

> Kas automaatika teatas, et sai valmis?

> Kas masina olek vastab nõuetele?

Ülesanne on tehtud alles siis, kui mõlemale küsimusele saab vastata „jah“. Seepärast kontrollid pärast iga lahendust web01-s tulemust ise:

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
- **Mis siis, kui midagi läheb valesti?** Kas tead, kuidas olekut kontrollida ja parandada?

Ansible'is aitavad kaks võtit: `--check --diff` näitab muudatust enne selle tegemist ja `--limit web01` piirab käivitamise ühe masinaga, isegi kui inventory's on masinaid rohkem.

??? example "CrowdStrike 2024: kontroll ja levitamise ulatus"

    CrowdStrike'i katkestus toimus 19. juulil 2024, kui Falconi vigane sisukonfiguratsiooni uuendus põhjustas ulatusliku Windowsi süsteemide katkestuse ([juurpõhjuse analüüs](https://crowdstrike.com/wp-content/uploads/2024/08/Executive-Summary_Root-Cause-Analysis_Channel-File-291.pdf)). Juhtum näitab, et muudatuse kontrollimine ja selle levitamise ulatuse piiramine on eraldi ülesanded. Laboris teeme sama väikses mahus: alusta ühest masinast (`--limit`), kontrolli tulemust ja alles siis laienda muudatust.

??? question "Kontrolli ennast"

    1. Miks ei piisa sellest, et Ansible teatas `ok`?
    2. Millised neli küsimust esitad endale enne muutva käsu käivitamist?

## 9. Kokkuvõte

- **Tulemus enne käske:** kirjuta enne, mis peab olema ja kuidas seda kontrollid.
- **Käsitsi enne automaatikat:** mõista tööd enne, kui annad selle arvutile.
- **Skriptis tuleb iga kontroll ise kirjutada:** Ansible'i moodulites on need kontrollid olemas.
- **Korduv käivitamine on eraldi nõue:** sama lõpptulemus ei tähenda, et midagi ei tehtud.
- **Playbook kirjeldab soovitud olekut:** inventory määrab masinad, playbook ülesanded ja moodul võrdleb soovitud olekut tegelikuga.
- **Aruanne ei ole tulemus:** kontrolli masina olekut.

Nüüd oskad lugeda ja käivitada väikest playbook'i. Järgmisel kohtumisel laiendame selle mitme masina seadistamiseks: lisanduvad grupid, muutujad, mallid ja rollid.

## Süvenemiseks

??? info "Konfiguratsioonihalduse tööriistade ajalugu"

    Varasemad tööriistad töötasid **agendiga**: igasse hallatavasse masinasse paigaldati eraldi programm, mis küsis serverilt, milline masin peab olema.

    | Aasta | Mis juhtus |
    |---|---|
    | 1993 | **CFEngine**: üks esimesi konfiguratsioonihalduse tööriistu, agent igas masinas |
    | 2005 | **Puppet**: oma keel soovitud oleku kirjeldamiseks, agent ja server |
    | 2009 | **Chef**: seadistus Ruby keeles, agent ja server |
    | 2011 | **Salt**: kiire sõnumside agentide ja serveri vahel |
    | 2012 | **Ansible**: Michael DeHaan teeb tööriista, mis ei vaja agenti ega serverit, kasutab olemasolevat SSH-d ja kirjeldab olekut YAML-is |
    | 2015 | Red Hat ostab Ansible'it arendava firma |
    | 2017 | Red Hat avaldab oma veebiplatvormi (Ansible Tower) lähtekoodi nime all **AWX** |
    | 2020 | Ansible jaguneb: tuum **`ansible-core`** ja eraldi **kogud** (collections) moodulitega |

    *Tabel 5.1. Konfiguratsioonihalduse tööriistade ajalugu.*

    Ansible levis kiiresti, sest alustamiseks ei pidanud hallatavatesse masinatesse midagi paigaldama: kui SSH töötas, töötas ka Ansible.

??? info "Kas teadsid? Nimi Ansible"

    Nimi on pärit Ursula K. Le Guini ulmekirjandusest, kus *ansible* on seade, millega saab sõnumi saata kohe ükskõik kui kaugele.

??? info "Tsentraalne platvorm suures ettevõttes"

    **Suures ettevõttes** käivitatakse sama playbook'i tsentraalsel platvormil, näiteks Red Hat **Ansible Automation Platform** või selle tasuta vaste **AWX**. Platvorm on paigaldatud eraldi serveritesse (Red Hati juhendi järgi RHEL 9, andmebaasiks PostgreSQL) ja lisab:

    - **veebiliidese ja API:** playbook'i saab käivitada nupuvajutusega, ajakava järgi või teise süsteemi kaudu (näiteks ServiceNow);
    - **õigused (RBAC):** kes tohib millist playbook'i millise inventory vastu käivitada;
    - **saladuste hoidmise:** paroolid ja võtmed on platvormis, mitte kasutajate arvutites;
    - **käivituskeskkonnad** (execution environments): konteinerid, kus `ansible-core` ja vajalikud kogud on kindla versiooniga, et sama playbook töötaks igal pool ühtemoodi;
    - **logid ja aruanded:** iga käivitus jääb ajalukku koos käivitaja ja tulemusega.

??? info "Ansible ja Ansible Automation Platform"

    Meie kasutame **Ansible'it** (täpsemalt `ansible-core`): tasuta käsurea tööriista. Red Hat müüb selle ümber ettevõtte platvormi **Ansible Automation Platform**. Platvormi komponendid lahendavad suure organisatsiooni muresid: kes tohib mida käivitada, kus on heakskiidetud kood, kuidas töö jõuab tuhandetesse masinatesse.

    | Komponent | Mida teeb | Tasuta vaste |
    |---|---|---|
    | arendustööriistad | VS Code'i laiendus, ansible-lint, Molecule, ansible-navigator | samad tööriistad |
    | automation controller | veebiliides ja API: playbook'ide käivitamine, ajakava, õigused (RBAC), logid | AWX, Semaphore |
    | automation hub | Red Hati sertifitseeritud kollektsioonid (moodulite kogud) | Ansible Galaxy |
    | private automation hub | ettevõtte enda kollektsioonide ja käivituskeskkondade hoidla | Galaxy NG |
    | automation mesh | töö jagamine eri võrkudes ja asukohtades olevate masinate vahel | |
    | Ansible Lightspeed | AI-abiline, mis pakub VS Code'is playbook'i ridu | |
    | automation analytics, Red Hat Insights | aruanded: mida käivitati, kui palju aega säästeti | |
    | Event-Driven Ansible | käivitab playbook'i sündmuse peale (häire, webhook) | ansible-rulebook |

    *Tabel 5.3. Ansible Automation Platformi komponendid.*

    Kõik need ehitavad sama asja peale, mida sel kohtumisel õpid: inventory, moodul ja playbook. Ilma nendeta pole platvormist kasu.
