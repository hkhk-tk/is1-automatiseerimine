---
tags:
  - Kokkuvõte
  - Loeng
---

# Loeng: kursuse kokkuvõte

1\. kohtumisel tegid web01-le kausta ja faili nelja käsuga. Täna muutis web01 lehte konveier, kui sina tegid push'i. Vahepeal oli iga kohtumine üks samm sinnapoole, et masinaid ei seadistata käsitsi.

??? abstract "Õpiväljundid"
    Pärast kokkuvõtet oskad:

    - selgitada iga kohtumise kohta, mida see muutis masinate seadistamise viisis;
    - selgitada, miks käsitsi tehtud muudatus serveris järgmisel käivitusel kaob;
    - eristada konveierit, mis viib muudatuse serverisse, ja tööriista, mis tõmbab selle Gitist ise.

<figure markdown="span">
  ![Mõttekaart: keskel automatiseerimine, seitse kohtumist. Ümber: 1 Bash ja Ansible, sama fail käsitsi, skriptiga ja playbook'iga; 2 rollid, üks käsk seadistab kogu labori; 3 Docker, uus versioon on uus konteiner; 4 OpenTofu, VM-id koodist, enne plaan; 5 Kubernetes, kustutatud pod tuleb tagasi; 6 AWS ja Actions, masin tekib ja kaob koodiga; 7 GitLab CI, web01 muutub push'iga](assets/k07_kursuse_pilt.svg)
  <figcaption>Joonis 7.3. Seitse kohtumist sama laboriga (Talvik, 2026).</figcaption>
</figure>

## 1. Seitse kohtumist

| Kohtumine | Mida automatiseerimise kohta õpid | Tööriist on ainult vahend |
|---|---|---|
| 1 | Korduv käsitsi töö muutub skriptiks. Skript kordab käske, aga soovitud olekut kirjeldav tööriist muudab ainult seda, mis on vaja. | Bash, Ansible |
| 2 | Seadistus on kood: seda saab taaskasutada, saladused hoitakse koodist eraldi ja muudatus käib järjekorras: kontroll, eelvaade, üks masin, siis kõik. | Ansible |
| 3 | Rakendus pakitakse muutumatuks artefaktiks. Viga ei parandata töötavas konteineris, vaid see asendatakse uuega. Andmed ja seadistus hoitakse eraldi. | Docker |
| 4 | Taristu on kood. Enne muudatust vaadatakse plaani ja state teab, mis on loodud. | OpenTofu |
| 5 | Kirjeldatakse soovitud olek ja süsteem hoiab seda ise: kustutatud osa tuleb ise tagasi. | Kubernetes |
| 6 | Pilv on API: masin tekib koodist ja kaob koodiga. Koristus kuulub automaatika juurde, sest tööle jäänud masin maksab. CI kontrollib iga muudatust. | AWS, GitHub Actions |
| 7 | Server muutub ainult Giti kaudu: konveier on värav, mis peatab vea, ja muudatus vaadatakse merge request'is üle. Push- ja pull-mudel. | GitLab CI, Argo CD |

*Tabel 7.1. Mida iga kohtumine automatiseerimise kohta õpetas.*

??? question "Kontrolli ennast"
    1. Mis juhtus 1. kohtumise skripti ja playbook'i teisel käivitusel?
    2. Miks ei paigaldata uut versiooni töötavasse konteinerisse?

    ??? success "Vastused"
        1. Skript käivitas kõik käsud uuesti. Playbook võrdles faili soovitud olekuga ja ei muutnud midagi: `changed=0`.
        2. Konteiner tehakse image'ist. Konteineris tehtud muudatus kaob järgmisel asendamisel ja keegi ei tea, mis seal muudeti. Uus versioon on uus image ja uus konteiner.

## 2. Käsitsi muudatus

Kõigil kohtumistel oli sama muster: kood Gitis kirjeldab, milline masin peab olema, ja tööriist teeb masina selliseks. Käsitsi tehtud muudatust koodis ei ole. Seepärast kaob see järgmisel käivitusel: Ansible kirjutab faili üle, Kubernetes asendab pod'i ja OpenTofu plaan näitab erinevust.

??? question "Kontrolli ennast"
    Keegi logib web01-sse sisse ja muudab K7 lehe teksti käsitsi, sest nii on kiirem. Mis juhtub järgmise konveieri käivitusega?

    ??? success "Vastus"
        Deploy käivitab Ansible'i, mis kirjutab lehe malli järgi uuesti. Käsitsi muudatus kaob. Kui tekst peab muutuma, tuleb muuta koodi või GitLabi muutujat `TEADE`.

## 3. Konveier viib, Argo CD tõmbab

7\. kohtumise konveier ühendub web01-ga SSH-ga ja käivitab Ansible'i. Muudatuse viib serverisse konveier ja selleks on runneril serveri võti.

Kubernetese klastrites kasutatakse sageli teist viisi. [Argo CD](https://argo-cd.readthedocs.io/en/stable/) töötab klastri sees, vaatab Giti repositooriumi ja tõmbab muudatused ise. Kui keegi muudab klastris midagi käsitsi, taastab Argo CD selle, mis on Gitis. Seda nimetatakse **GitOps**'iks. Konveier ei vaja klastri võtit, sest klaster küsib Gitilt ise.

??? note "Tabel 7.2. Konveier ja Argo CD"
    | | Konveier (GitLab CI, GitHub Actions) | Argo CD |
    |---|---|---|
    | Kes muudatuse teeb | runner ühendub serveriga | Argo CD klastris tõmbab Gitist |
    | Mida konveier vajab | serveri SSH-võtit või tokenit | ainult ligipääsu Gitile |
    | Käsitsi muudatus serveris | jääb alles järgmise käivituseni | taastatakse kohe |
    | Kus kasutatakse | serverid, VM-id, pilveressursid | Kubernetese klastrid |

5\. kohtumise lisaülesandes saad Argo CD oma k3s klastrisse paigaldada.
