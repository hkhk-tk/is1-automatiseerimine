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
    - selgitada, mida skript teeb ja mida mitte, ning miks Ansible'i moodul kontrollib seisu ise;
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

### Üks kord on lihtne, kolm korda mitte

Valla IT-spetsialist seadistab kolm ühesugust veebiserverit. Esimese teeb ta hoolikalt, teise kiiremini, sest käsud on shelli ajaloos. Kolmanda juures tuleb kõne ja üks samm jääb tegemata. Kõik kolm töötavad. Kuu aja pärast tulevad turvauuendused, serverid taaskäivitatakse ja kolmas ei tule üles. Põhjuse otsimine võtab tunni, sest „kõik serverid on ju samamoodi seadistatud“.

Probleem polnud oskustes. Masina õige seis oli kirjas ainult inimese mälus. Automatiseerimine vastab küsimusele:

> Kas suudad töö korrata, teisele selgitada ja tõestada, et tulemus on õige?

### Mida automatiseerida ja mida veel mitte

Kõike pole mõtet automatiseerida. Kandidaati hinnatakse kolme küsimusega:

| Küsimus | Näide |
|---|---|
| Kui sageli seda tehakse? | kuine turvauuendus 40 serveris |
| Kui palju maksab käsitsi tehtud viga? | aasta tagasi tehtud sertifikaadi vahetus, mille sammud on ununenud |
| Kui kaua üks kord aega võtab? | uue töötaja kasutajakontod kuues süsteemis |

*Tabel 1.1. Kolm küsimust automatiseerimise kandidaadile.*

Harva tehtava, lihtsa ja väikese riskiga töö puhul võib piisata juhendist. Automaatika maksab: see tuleb kirjutada, testida ja hooldada. Google'i SRE raamat nimetab käsitsi tehtavat, korduvat ja masinate arvuga kasvavat tööd sõnaga *toil*: just see on esimene kandidaat.

??? question "Mõtle"

    Millist tööd teed oma töökohal iga nädal samamoodi? Kui sul töökogemust pole, mõtle varasemale Linuxi praktikumile. Kas see vastab kolmele küsimusele tabelis 1.1?

??? info "Loe juurde"

    - [Google SRE: Eliminating Toil](https://sre.google/sre-book/eliminating-toil/)
    - [Google SRE: Lessons Learned from Other Industries](https://sre.google/sre-book/lessons-learned/)

## 2. Kuidas töötamise viis on muutunud

**Küsimus:** miks inimesed käsitsi haldusest kaugemale liikusid?

Lihtsustatult on töö liikunud viie sammuna: käsitsi, kirjalik juhend, skript, konfihaldus ja lõpuks kood Gitis, mida kolleeg enne käivitamist üle vaatab. Iga samm paneb midagi rohkem kirja ja jätab vähem inimese mällu.

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

| Samm | Mida kirjeldab | Kes otsustab, kas muuta on vaja | Tüüpiline risk |
|---|---|---|---|
| Käsitsi | ei midagi, teadmine on peas | inimene | keegi ei tea, mis tehti |
| Juhend | samme inimesele | inimene igal sammul | samm jääb vahele |
| Skript | käskude järjekorda | skripti autor, kui ta kontrolli kirjutas | teine käivitus teeb sama töö uuesti |
| Konfihaldus | soovitud seisu | tööriista moodul | toores käsk ilma kontrollita |
| Kood Gitis | kõike ülaltoodut koos ajalooga | ülevaataja enne käivitamist | ülevaatus jääb formaalseks |

*Tabel 2.1. Mida iga samm kirjeldab ja kus on risk.*

Ükski samm ei asenda eelmisi. Ka Eesti X-tee avalikus repos on kõrvuti paigaldusjuhend inimesele ja Ansible'i playbook'id meeskonnale, kes ehitab sama keskkonda kümneid kordi. Järjekord on sama: **tee kõigepealt käsitsi, siis kirjuta üles, siis automatiseeri.**

??? note "Süvenemiseks: snowflake server ja drift"

    Kolm aastat töötanud serveris on keegi kunagi lisanud `/etc/hosts`-i rea, muutnud mõnda seadet ja paigaldanud paketi, mida keegi enam ei mäleta. Martin Fowler nimetab sellist masinat *snowflake server*'iks: see on ainulaadne ja keegi ei julge seda uuesti ehitada.

    Masinate vahelisi väikeseid erinevusi nimetatakse **triiviks** (drift). Triivi ei hoia ära eriline hoolikus, sest inimesed unustavad. Aitab see, kui masina seis on kirjas kohas, mis ei unusta, ja seda kirjeldust rakendatakse ikka ja jälle.

??? info "Loe juurde"

    - [Martin Fowler: SnowflakeServer](https://martinfowler.com/bliki/SnowflakeServer.html)
    - [X-tee repo (juhend ja Ansible kõrvuti)](https://github.com/nordic-institute/X-Road)

### Mida automatiseerimine tähendab

**IT-automatiseerimine** tähendab, et korduv töö on kirjas koodina, mida saab **kirjeldada**, **korrata** ja **kontrollida**. Automaatika ei tee halba protsessi heaks: programm teeb täpselt seda, mis on kirjas, ka siis, kui kirjas on viga, ja teeb seda kõigis masinates korraga.

??? example "Knight Capital 2012: üks server kaheksast"

    Uus kood pidi käsitsi jõudma kaheksasse serverisse. Ühte jäi see kopeerimata ja seal käivitus vana funktsioon. USA väärtpaberikomisjoni [otsuse](https://www.sec.gov/litigation/admin/2013/34-70694.pdf) järgi kaotas firma 45 minutiga üle 460 miljoni dollari.

??? question "Mõtle: vastutus ja töökohad"

    Kui automaatika teeb kolleegi iganädalase töö, mis temast saab? Kes vastutab, kui automaatika teeb vea? World Economic Forumi [Future of Jobs Report 2025](https://www.weforum.org/publications/the-future-of-jobs-report-2025/) järgi kasvab nõudlus inimeste järele, kes automaatikat kirjutavad, üle vaatavad ja hooldavad.

## 3. Päeva ülesanne ja töökeskkond

**Küsimus:** mis peab tulemuseks olema ja kuidas seda kontrollime?

### Ülesanne ja kontrollnimekiri

Enne esimest käsku pane kirja, mis peab olema tulemus. „Tee kaust“ on tegevus, „kaust on olemas õigustega 0750“ on tulemus, ja ainult tulemust saab kontrollida. Päeva ülesandest tuleb kontrollnimekiri, mida kasutad kõigi kolme teostuse järel:

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

### Sinu keskkond

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

Praktikumis teed ülesande kõigepealt web01-s käsitsi käsk-käsult ja kontrollid tulemust käskudega `cat` ja `stat`. Kui käsk ei trüki midagi, ei tähenda see veel, et ülesanne on tehtud: tõend on see, mida kontrollnimekiri küsib.

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

Esimene rida ütleb, et faili loeb Bash. Käivitad `bash prepare-training.sh`. Skript teeb sama töö kiiresti ja alati samas järjekorras. Aga ta ei tea midagi masina seisust:

- **Teine käivitus kirjutab faili uuesti üle**, kuigi sisu on juba õige. Sama lõpptulemus ei tähenda, et midagi ei tehtud.
- **Kui üks käsk ebaõnnestub, jätkab skript järgmisega.** Pooleli jäänud töö jääb masinasse.
- **Iga kontrolli pead ise kirjutama.** Kas kaust on olemas, kas sisu on juba õige, kas õigused klapivad: igaüks on eraldi `if`.

Omadust, et korduv käivitus ei muuda midagi, kui soovitud seis on juba olemas, nimetatakse **idempotentsuseks**. Skriptis on iga selline kontroll sinu töö. Ansible'i moodulites on need valmis.

??? question "Kontrolli ennast"

    1. Mis juhtub failiga `training.conf`, kui käivitad skripti teist korda?
    2. Mida tähendab idempotentsus?

## 5. Ansible'i tutvustus

**Küsimus:** mis tööriist Ansible on ja kuidas see masinani jõuab?

**Ansible** on avatud lähtekoodiga programm serverite seadistamiseks. Sa kirjutad tekstifaili, milline peab masin olema: millised paketid on paigaldatud, millised failid on olemas, millised teenused töötavad. Ansible loeb selle faili, ühendub SSH-ga masinatesse ja teeb seal ainult need muudatused, mis on puudu.

Seda kasutatakse serverite seadistamiseks, rakenduste paigaldamiseks, uuenduste levitamiseks ning võrguseadmete ja pilveressursside haldamiseks. Põhimõte on igal pool sama: **kirjeldad soovitud seisu, Ansible viib masina sinna**.

### Ajalugu

Ansible ei olnud esimene konfihalduse tööriist. Varasemad töötasid **agendiga**: igasse hallatavasse masinasse paigaldati eraldi programm, mis küsis serverilt, milline masin peab olema.

| Aasta | Mis juhtus |
|---|---|
| 1993 | **CFEngine**: üks esimesi konfihalduse tööriistu, agent igas masinas |
| 2005 | **Puppet**: oma keel soovitud seisu kirjeldamiseks, agent ja server |
| 2009 | **Chef**: seadistus Ruby keeles, agent ja server |
| 2011 | **Salt**: kiire sõnumside agentide ja serveri vahel |
| 2012 | **Ansible**: Michael DeHaan teeb tööriista, mis ei vaja agenti ega serverit, kasutab olemasolevat SSH-d ja kirjeldab seisu YAML-is |
| 2015 | Red Hat ostab Ansible'it arendava firma |
| 2017 | Red Hat avaldab oma veebiplatvormi (Ansible Tower) lähtekoodi nime all **AWX** |
| 2020 | Ansible jaguneb: tuum **`ansible-core`** ja eraldi **kogud** (collections) moodulitega |

*Tabel 5.1. Konfihalduse tööriistade ajalugu.*

Ansible levis kiiresti, sest alustamiseks ei pidanud midagi hallatavatesse masinatesse paigaldama: kui SSH töötas, töötas ka Ansible. Nimi on pärit Ursula K. Le Guini ulmekirjandusest, kus *ansible* on seade, millega saab sõnumi saata kohe ükskõik kui kaugele.

Kolm asja eristavad Ansible'it Bashi skriptist:

- **Soovitud seis, mitte käsud.** Kirjutad „kaust on olemas õigustega 0750“, mitte „tee kaust, siis muuda õigusi“. Kontrolli, kas muutmine on vaja, teeb Ansible.
- **Mitu masinat korraga.** Sama faili saab käivitada ühe või saja masina vastu.
- **Agenti pole vaja.** Hallatavasse masinasse ei paigaldata midagi lisaks, piisab SSH-st ja Pythonist.

Ansible ei ole operatsioonisüsteem, veebiteenus ega asendus Linuxi teadmistele. See on käsurea programm, mis käivitub control node'il. Teed, kasutajad ja õigused tuleb endiselt ise mõista; muutub see, kuidas tööd kirjeldad.

Meie ülesanne jääb samaks: sama kaust ja sama fail web01-s. Uus on ainult see, kuidas Ansible tööd kirjeldab ja teeb.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 220" role="img" aria-label="Control node'il on inventory, playbook ja ansible-playbook; Ansible saadab mooduli SSH-ga web01-le, kus Python võrdleb soovitud ja tegelikku seisu ning tagastab ok või changed" xmlns="http://www.w3.org/2000/svg">
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

Ansible on paigaldatud ainult **control node**'ile. Masinat, mida ta seadistab, nimetatakse **hallatavaks masinaks** (managed node), meil on see web01. Hallatavas masinas ei pea Ansible'it olema, piisab SSH-st ja Pythonist.

Iga ülesande jaoks saadab Ansible SSH-ga web01-le väikese Pythoni programmi, **mooduli**, koos väärtustega, mida playbook'is kirjutasid. Moodul vaatab masinas tegelikku seisu, muudab vajadusel ja saadab tagasi tulemuse. Siis moodul kustutatakse; masinasse ei jää midagi Ansible'ist.

Ansible oskab kasutada ka parooli (`--ask-pass`), aga selles laboris kasutame SSH-võtit, nii et ühendus ei küsi parooli.

### Nõuded: millises masinas mida vaja on

| Masin | Mida vaja | Märkus |
|---|---|---|
| **control node** | Linux või macOS, Python 3, `ansible-core` | Windows otse control node'iks ei sobi; Windowsis töötab Ansible WSL-i kaudu |
| **Linuxi hallatav masin** | SSH ja Python 3 | Ansible'it sinna paigaldada pole vaja |
| **Windowsi hallatav masin** | WinRM või SSH ja PowerShell | moodulid on eraldi kogus `ansible.windows` |
| **võrguseade** (ruuter, kommutaator) | SSH või API | Pythonit seadmes pole: moodul jookseb control node'il ja saadab seadmele käsud |

*Tabel 5.2. Mida Ansible eri masinatelt eeldab.*

### Väikeses ja suures keskkonnas

**Väikeses keskkonnas**, nagu meie labor või väike IT-osakond, on Ansible paigaldatud ühte masinasse: administraatori control node'i või sülearvutisse. Inventory, `ansible.cfg` ja playbook'id on Gitis ja inimene käivitab `ansible-playbook`-i käsurealt, vajadusel ajastatult (cron, systemd timer).

**Suures ettevõttes** jookseb sama playbook tsentraalsel platvormil, näiteks Red Hat **Ansible Automation Platform** või selle tasuta vaste **AWX**. Platvorm on paigaldatud eraldi serveritesse (Red Hati juhendi järgi RHEL 9, andmebaasiks PostgreSQL) ja lisab:

- **veebiliidese ja API:** playbook'i käivitab nupuvajutus, ajakava või teine süsteem (näiteks ServiceNow);
- **õigused (RBAC):** kes tohib millist playbook'i millise inventory vastu käivitada;
- **saladuste hoidmise:** paroolid ja võtmed on platvormis, mitte kasutajate arvutites;
- **käivituskeskkonnad** (execution environments): konteinerid, kus `ansible-core` ja vajalikud kogud on kindla versiooniga, et sama playbook töötaks igal pool ühtemoodi;
- **logid ja aruanded:** iga käivitus jääb ajalukku koos käivitaja ja tulemusega.

Playbook ise on mõlemas keskkonnas sama. See, mida sel kohtumisel õpid, kehtib ka suures ettevõttes.

??? note "Kohalik ühendus ei ole sama mis kaugühendus"

    Ansible võib töötada ka samas masinas, kus ta on paigaldatud (`connection: local`). See on mugav proovimiseks, aga siis ei kasutata SSH-d ega kontrollita, kas võti ja kasutaja on õiged. Meie kasutame kogu aeg päris kaugühendust web01-le.

??? note "Ansible ja Ansible Automation Platform"

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

??? question "Kontrolli ennast"

    1. Kus Ansible jookseb ja mida on vaja hallataval masinal?
    2. Mis on moodul ja kuhu see pärast tööd jääb?

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

=== "AlmaLinux, AlmaLinux, RHEL"

    ```bash
    sudo dnf install -y ansible-core
    ```

=== "pipx (uusim versioon)"

    ```bash
    pipx install ansible-core
    ```

Paketihaldur annab distro testitud versiooni, `pipx` uusima. Laboris kasutame paketihaldurit. Kontrolli:

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
| `[ubuntu]`, `[alma]` | grupid; nii saab käivitada töö ühe grupi kõigi masinate vastu korraga |
| `web01` | masina nimi; IP tuleb failist `~/.ssh/config` |
| `[all:vars]` | muutujad, mis kehtivad kõigile masinatele |
| `ansible_user` | kasutaja, kellena Ansible sisse logib |

*Tabel 6.2. Inventory osad.*

Kui masina nime pole `~/.ssh/config`-is ega DNS-is, kirjuta aadress inventory'sse: `web01 ansible_host=192.168.125.11`. Grupp `all` on alati olemas ja sisaldab kõiki masinaid. Salvesta fail nimega `inventory.ini`. Võti `-i` ütleb Ansible'ile, millist inventory't kasutada: `ansible -i inventory.ini ...`.

### `ansible.cfg`: projekti seaded

Et iga käsu juurde ei peaks kirjutama `-i inventory.ini`, pane projekti kausta fail `ansible.cfg`:

```ini
[defaults]
inventory = inventory.ini
```

Ansible otsib seadistusfaili kindlas järjekorras ja kasutab **esimest**, mille leiab:

| Järjekord | Kus | Millal kasutada |
|---|---|---|
| 1 | keskkonnamuutuja `ANSIBLE_CONFIG` | ajutiselt teine seadistus |
| 2 | `ansible.cfg` praeguses kaustas | **projekti seaded, meie valik** |
| 3 | `~/.ansible.cfg` | sinu isiklikud vaikeväärtused |
| 4 | `/etc/ansible/ansible.cfg` | kogu masina vaikeväärtused |

*Tabel 6.3. Kust Ansible seadistuse võtab.*

Millist faili Ansible parasjagu kasutab, näed käsust `ansible --version`, real `config file = ...`. Kui seal on `None`, ei leidnud Ansible ühtegi ja `-i` on jälle vaja. Hoia `ansible.cfg` koos inventory ja playbook'idega samas kaustas ja Gitis: siis töötab projekt igaühe masinas ühtemoodi.

### Kasutaja ja õigused

Ansible teeb hallatavas masinas tööd selle kasutajana, kellena ta SSH-ga sisse logib. Meil on see `kasutaja` (inventory's `ansible_user=kasutaja`) ja sisselogimine käib SSH-võtmega. Kõik, mida see kasutaja tohib, tohib ka Ansible. Meie päeva ülesanne käib kasutaja kodukaustas ja administraatori õigusi ei vaja.

Paketi paigaldamiseks, teenuse käivitamiseks või `/etc` all oleva faili muutmiseks on vaja administraatori õigusi. Selleks on **`become`**: Ansible logib sisse tavakasutajana ja tõstab õigused `sudo` kaudu ainult nende ülesannete jaoks, kus seda vaja on.

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
ansible-playbook tools.yml -K
```

| Võti | Tähendus |
|---|---|
| `become: true` | selle play (või ühe ülesande) ajal tööta `sudo` kaudu |
| `become_user: postgres` | tõsta õigused mõne teise kasutajani, vaikimisi `root` |
| `-K` | küsi `sudo` parooli üks kord käivitamise alguses |

*Tabel 6.4. Õiguste tõstmine.*

Pane `become: true` ainult sinna, kus seda vaja on. Mida vähem õigusi, seda väiksem kahju vea korral.

### Kaks käsku: `ansible` ja `ansible-playbook`

| Käsk | Mida teeb | Näide |
|---|---|---|
| `ansible` | käivitab ühe mooduli kohe, ilma failita (ad-hoc) | `ansible web01 -m ansible.builtin.ping` |
| `ansible-playbook` | käivitab playbook'i: mitu ülesannet järjest | `ansible-playbook training.yml` |

*Tabel 6.5. Ansible'i kaks põhikäsku.*

`ansible web01 -m ansible.builtin.ping` on esimene kontroll. Vastus `pong` tähendab, et Ansible jõuab SSH-ga masinasse ja seal töötab Python. Võrguühenduse `ping`-iga sellel pole pistmist. Ad-hoc käsk sobib kiireks kontrolliks, näiteks `ansible web01 -m ansible.builtin.command -a uptime`. Seadistus, mida tahad korrata, käib playbook'i.

### Faktid: mida Ansible masinast teab

Moodul `ansible.builtin.setup` kogub masinast **fakte**: OS, versioon, mälu, võrguliidesed. Neid kasutab Ansible otsusteks, näiteks millise paketihalduriga paigaldada.

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

AlmaLinuxi masinas oleks `ansible_distribution` väärtus `AlmaLinux`. 2. kohtumisel kasutad seda, et sama playbook teeks Ubuntul ja AlmaLinuxil õiget asja.

??? question "Kontrolli ennast"

    1. Mida tähendab inventory reas `ansible_host` ja mida `[veeb]`?
    2. Milleks on `ansible.cfg` ja kuidas näed, millist neist Ansible kasutab?
    3. Mis vahe on käskudel `ansible` ja `ansible-playbook`?

??? info "Loe juurde"

    - [Building an inventory](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_inventory.html)
    - [How to build your inventory](https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html)
    - [Configuring Ansible](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_configuration.html)
    - [Introduction to ad hoc commands](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)
    - [Discovering variables: facts](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_vars_facts.html)

## 7. Playbook'i kirjutamine ja käivitamine

**Küsimus:** kuidas kirjeldada soovitud seisu, käivitada see ja lugeda tulemust?

### Moodulid

**Moodul** on Ansible'i valmis tööriist ühe asja jaoks. Mooduleid on sadu, alustamiseks piisab mõnest:

| Moodul | Mida haldab |
|---|---|
| `ansible.builtin.file` | kaustad, õigused, omanikud, lingid |
| `ansible.builtin.copy` | faili sisu (failist või tekstina) |
| `ansible.builtin.package` | paketid (`apt`, `dnf` vastavalt distrole) |
| `ansible.builtin.service` | teenused: käib, käivitub boodil |
| `ansible.builtin.user` | kasutajad |
| `ansible.builtin.template` | failid mallist, kuhu tulevad muutujate väärtused (2. kohtumine) |
| `ansible.builtin.command` | toores käsk; Ansible ei tea, mis on soovitud seis |

*Tabel 7.1. Sagedasemad moodulid.*

Pikk nimi `ansible.builtin.file` ütleb, et moodul `file` on Ansible'iga kaasas olevas kogus `ansible.builtin`. Mooduli juhendi näed käsurealt:

```bash
ansible-doc ansible.builtin.file
```

Juhendi lõpus on alati näited (`EXAMPLES`). Sealt on kõige lihtsam alustada.

### Playbook: ülesanded järjest

**Playbook** on YAML-fail. Selles on üks või mitu **play**'d: iga play ütleb, millistes masinates (`hosts`) millised **ülesanded** (`tasks`) täita. Iga ülesanne kasutab üht moodulit koos parameetritega.

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

Pane tähele ülesannete nimesid: „Kaust **on** olemas“, mitte „Tee kaust“. Playbook kirjeldab seisu, mitte tegevust. `state: directory` ütleb, et see tee peab olema kaust; `content: |` tähendab, et järgmised taandega read on faili sisu.

### YAML minimaalselt

YAML on lihtne tekstivorming, kus struktuur tuleb **taandest**. Kolm reeglit katavad meie playbook'i:

- `võti: väärtus` paar, koolon ja tühik pärast koolonit;
- `-` alustab loendi elementi (iga ülesanne on loendi element);
- taane on tühikutega, mitte tabulaatoriga, ja sama taseme read on sama kaugel.

Kõige sagedasem algaja viga on vale taane. Ansible ütleb siis `Syntax Error` ja rea numbri. Teine levinud viga on õigused ilma jutumärkideta: `mode: 0750` loetakse arvuna ja tulemus võib olla vale, `mode: "0750"` on ohutu.

### Abivahendid

| Tööriist | Mida teeb |
|---|---|
| VS Code'i laiendus **Ansible** (`redhat.ansible`) | värvib YAML-i, näitab vigu kirjutamise ajal, pakub mooduli parameetreid |
| `ansible-doc <moodul>` | mooduli juhend ja näited käsureal |
| `ansible-playbook --syntax-check` | kontrollib, kas YAML ja playbook'i ülesehitus on korrektsed |
| **ansible-lint** | leiab levinud vigu ja halbu tavasid, näiteks moodul ilma `ansible.builtin.` eesliiteta või `mode` ilma jutumärkideta |

*Tabel 7.2. Abivahendid playbook'i kirjutamisel.*

```bash
ansible-playbook training.yml --syntax-check
ansible-lint training.yml
```

Suuremate projektide jaoks on Red Hatil veel [arendustööriistu](https://www.redhat.com/en/technologies/management/ansible/development-tools): **ansible-navigator** (playbook'i käivitamine ja tulemuse sirvimine), **Molecule** (rollide testimine) ja **ansible-builder** (käivituskeskkonna pakendamine). Neid läheb vaja hiljem.

### Tingimus, sihtmasinad ja sildid

Meie laboris on kaks distrot. Sama programm võib neil olla eri paketinimega: Ubuntul `vim`, AlmaLinuxil `vim-enhanced`. Tingimus **`when`** paneb ülesande käima ainult siis, kui see on tõene. Otsus tuleb faktist:

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
| `when` | ülesanne käib ainult siis, kui tingimus on tõene; muidu `skipping` | `when: ansible_facts['os_family'] == "Debian"` |
| `hosts` | millistes masinates play käib | `hosts: all`, `hosts: alma` |
| `--limit` | piirab käivituse osaga masinatest playbook'i muutmata | `ansible-playbook tools.yml --limit web01` |
| `tags` | ülesande silt; `--tags` käivitab ainult need | `ansible-playbook tools.yml --tags motd` |

*Tabel 7.3. Tingimus, sihtmasinad ja sildid.*

### Mis juhtub käivitamisel

```bash
ansible-playbook training.yml
```

1. Ansible loeb inventory'st, kus on `web01` ja kuidas sinna ühenduda.
2. Ansible loeb playbook'ist, mida seal teha.
3. **Gathering Facts:** Ansible kogub masinast fakte (OS, versioon, võrk). Seda näed väljundis esimese ülesandena.
4. Iga ülesande jaoks: SSH, moodul, võrdlus, tulemus.
5. **PLAY RECAP:** lõpus kokkuvõte iga masina kohta.

```text
PLAY RECAP *********************************************************
web01   : ok=3  changed=2  unreachable=0  failed=0  skipped=0
```

| Väli | Tähendus |
|---|---|
| `ok` | ülesanded, mis lõppesid edukalt (ka need, mis muutsid) |
| `changed` | neist need, mis midagi muutsid |
| `unreachable` | masinasse ei saanud ühendust (SSH, võti, IP) |
| `failed` | ülesanne ebaõnnestus, sellel masinal edasi ei minda |
| `skipped` | ülesanne jäeti tingimuse tõttu vahele (2. kohtumine) |

*Tabel 7.4. PLAY RECAP väljad.*

### Soovitud seis ja teine käivitus

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
<figcaption>Joonis 7.2. Moodul võrdleb soovitud ja tegelikku sisu ning kirjutab ainult siis, kui need erinevad.</figcaption>
</figure>

Kui muudad web01-s faili käsitsi ja käivitad playbook'i uuesti, näed `changed` ainult failiülesandel. Ansible leidis erinevuse ja taastas õige sisu. Võti `--check --diff` näitab enne, mida Ansible muudaks, ilma midagi muutmata.

??? warning "Kõik ei ole automaatselt idempotentne"

    Enamik mooduleid kontrollib ise, kas muudatust on vaja. Toore käsu puhul (`ansible.builtin.command`, `ansible.builtin.shell`) ei tea Ansible, mis on soovitud lõppseis. Ilma lisakontrollita võib selline ülesanne teatada `changed` igal käivitusel. Ära ütle „Ansible on idempotentne ja Bash mitte“. Võrdleme konkreetseid teostusi: skriptis saab kontrolli kirjutada ja playbook'is saab selle ära rikkuda.

??? question "Kontrolli ennast"

    1. Mis vahe on moodulil, ülesandel ja playbook'il?
    2. Kust leiad mooduli parameetrid ja näited?
    3. Millal on vaja `become: true`?
    4. Mis vahe on `ok` ja `changed` väljal PLAY RECAP reas?
    5. Mida tähendab `changed=0` teisel käivitusel?

??? info "Loe juurde"

    - [Ansible playbooks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_intro.html)
    - [`ansible.builtin` moodulite nimekiri](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/index.html)
    - [YAML Syntax](https://docs.ansible.com/projects/ansible/latest/reference_appendices/YAMLSyntax.html)
    - [Understanding privilege escalation: become](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_privilege_escalation.html)
    - [Check mode ja diff](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html)

## 8. Kontroll ja ohutu käivitamine

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
- **Skriptis on iga kontroll sinu töö:** Ansible'i moodulites on need valmis.
- **Teine käivitus on eraldi nõue:** sama tulemus ei tähenda, et midagi ei tehtud.
- **Ansible kirjeldab seisu:** inventory ütleb kus, playbook ütleb mis, moodul võrdleb ise.
- **Aruanne ei ole tulemus:** kontrolli masinat ennast.

Oskad nüüd lugeda ja käivitada väikest playbook'i. Järgmisel kohtumisel ehitame sellest mitme masina seadistamise lahenduse: grupid, muutujad, mallid ja rollid.
