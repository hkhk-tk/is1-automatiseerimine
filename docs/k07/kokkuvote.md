---
tags:
  - Kokkuvõte
  - Loeng
---

# Loeng: kursuse kokkuvõte

Seitsmel kohtumisel tegid sama laboriga järjest rohkem automaatikat: kõigepealt kirjutasid käsud skripti, lõpuks muutis serverit ainult konveier. Tööriistad vahetusid, aga nende taga on viis põhimõtet, mis kehtivad ka järgmise tööriista kohta.

??? abstract "Õpiväljundid"
    Pärast kokkuvõtet oskad:

    - selgitada iga kohtumise kohta, mida see automatiseerimise juures muutis;
    - nimetada viis põhimõtet, mis on kõigi kursuse tööriistade taga;
    - eristada konveierit, mis surub muudatuse serverisse, ja tööriista, mis tõmbab selle Gitist ise;
    - hinnata oma töökoha mõne käsitsi tehtava ülesande kohta, millise põhimõtte järgi seda automatiseerida.

## 1. Mida iga kohtumine muutis

Iga kohtumine võttis ühe käsitsi tehtud töö ja tegi sellest koodi. Kaardil on kohtumise number, mida see automatiseerimise juures muutis, ja kaldkirjas tööriist, millega seda tegid. Tööriist on vahend: sama mõte kehtib ka järgmise tööriista kohta, mida töökohas kasutad.

<figure markdown="span">
  ![Mõttekaart: keskel Automatiseerimine, kood Gitis, kontroll enne. Ümber seitse kohtumist: 1 skript, käsitsi töö muutub koodiks, Bash ja Ansible; 2 seadistus, soovitud olek ja paroolid eraldi, rollid ja Vault; 3 pakend, asenda, ära paranda, Docker; 4 taristu, plaan enne muudatust, OpenTofu; 5 klaster, süsteem hoiab olekut ise, Kubernetes; 6 pilv ja CI, loo, kontrolli, korista, AWS ja Actions; 7 konveier, server muutub ainult Gitist, GitLab CI](assets/k07_kursuse_pilt.svg)
  <figcaption>Joonis 7.3. Seitse kohtumist ja mida igaüks automatiseerimise juures muutis (Talvik, 2026).</figcaption>
</figure>

??? question "Kontrolli ennast"
    1. Mis vahe on 1. kohtumise Bashi skriptil ja Ansible'i playbook'il, kui mõlemad paigaldavad nginxi?
    2. Miks ei parandata vigast konteinerit selle sees?

    ??? success "Vastused"
        1. Skript käivitab käsud iga kord uuesti. Playbook kirjeldab soovitud olekut ja teine käivitus annab `changed=0`.
        2. Konteiner tehakse image'ist. Käsitsi parandus kaob järgmisel asendamisel ja keegi ei tea, mis seal muudeti. Parandus läheb Dockerfile'i ja tehakse uus image.

## 2. Viis põhimõtet

**Git on tõe allikas.** Kõik, mida masinatega tehakse, on kirjas repositooriumis: rollid, Dockerfile, OpenTofu kood, töövoog ja konveier. Kui server kaob, tehakse see koodist uuesti. Giti ajaloost näeb, kes ja millal muutis.

**Kirjelda olekut, mitte käske.** Ansible, OpenTofu ja Kubernetes saavad teada, milline olek peab olema, ja võrdlevad seda tegelikuga. Sama kood teist korda ei muuda midagi.

**Kontrolli enne serverit.** Lint, `tofu plan`, `fmt -check` ja merge request leiavad vea enne, kui see serverisse jõuab. 7. kohtumisel peatas lint katkise YAML-i ja leht jäi puutumata.

**Asenda, ära paranda käsitsi.** Image, pod ja pilvemasin tehakse uuesti, mitte ei parandata töötavas masinas. Käsitsi muudatus on see, mida koodis ei ole ja mis järgmisel korral kaob.

**Korista ja jälgi.** Automaatika ei lõpe loomisega. Tööle jäänud pilvemasin maksab, unustatud token on oht. `tofu destroy`, koristusskript ja konveieri logi on töö osa.

??? question "Kontrolli ennast"
    Keegi logib serverisse sisse ja muudab nginxi seadistust käsitsi, sest „nii on kiirem“. Mis juhtub järgmise konveieri käivitusega ja millist põhimõtet see rikub?

    ??? success "Vastus"
        Konveier käivitab Ansible'i, mis kirjutab faili koodis oleva sisuga üle. Käsitsi muudatus kaob. See rikub põhimõtet „Git on tõe allikas“: muudatus peab minema koodi ja läbi konveieri.

## 3. Push ja pull

7\. kohtumise konveier **surub** muudatuse serverisse: GitLabi runner ühendub SSH-ga web01-ga ja käivitab Ansible'i. Selleks peab konveieril olema ligipääs serverile.

Kubernetese juures kasutatakse sageli vastupidist mudelit. [Argo CD](https://argo-cd.readthedocs.io/) töötab klastris, jälgib Giti repositooriumi ja **tõmbab** muudatused ise. Kui keegi muudab klastris midagi käsitsi, taastab Argo CD Gitis kirjas oleva oleku. Seda nimetatakse **GitOps**'iks. Klastri võtmeid ei pea CI-le andma, sest klaster küsib Gitilt ise.

??? note "Tabel 7.2. Push ja pull"
    | | Push (GitLab CI, GitHub Actions) | Pull (Argo CD) |
    |---|---|---|
    | Kes muudatuse teeb | konveier ühendub serveriga | tööriist klastris tõmbab Gitist |
    | Mida konveier vajab | ligipääs serverile (SSH-võti, token) | ainult Giti |
    | Käsitsi muudatus serveris | jääb alles kuni järgmise käivituseni | parandatakse kohe |
    | Sobib | serverid, VM-id, pilveressursid | Kubernetese klastrid |

Kubernetese osa (5. kohtumine) lisaülesandes saad Argo CD oma k3s klastrisse paigaldada.

## 4. Sinu töökohal

Automatiseerida tasub tööd, mis kordub, mida tehakse mitmes kohas samamoodi ja mille vea hind on suur. Alusta väikesest: üks käsitsi tehtav samm skriptiks, siis soovitud olekuks, siis konveierisse.

??? question "Kontrolli ennast"
    Igal esmaspäeval loob administraator uuele töötajale kasutaja kolmes süsteemis. Millise põhimõtte järgi alustaksid ja mis oleks esimene samm?

    ??? success "Üks võimalik vastus"
        Kõigepealt kirjuta sammud skripti (1. kohtumine). Siis kirjelda kasutajad failis, mille järgi tööriist teeb soovitud oleku (2. kohtumine). Lõpuks pane fail Giti ja konveier, mis kontrollib ja rakendab muudatuse (7. kohtumine). Uue töötaja lisamine on siis üks rida koodis ja merge request.

??? abstract "Kokkuvõte"
    | Põhimõte | Kus kursusel |
    |---|---|
    | Git on tõe allikas | rollid, Dockerfile, OpenTofu, töövoog, konveier |
    | Kirjelda olekut | Ansible, OpenTofu, Kubernetes |
    | Kontrolli enne serverit | lint, plan, fmt, merge request |
    | Asenda, ära paranda | image, pod, pilvemasin |
    | Korista ja jälgi | destroy, koristusskript, logid |

??? info "Loe juurde"
    - [Argo CD](https://argo-cd.readthedocs.io/en/stable/): GitOps tööriista dokumentatsioon.
    - Kursuse [teemade lehed](../teemad/it-automatiseerimine.md): automatiseerimise strateegia, mida ja millises järjekorras automatiseerida.
