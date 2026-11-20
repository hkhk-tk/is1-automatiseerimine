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

**1. kohtumine.** Tegid web01-le kausta ja faili kõigepealt käsitsi, siis Bashi skriptiga ja lõpuks Ansible'i playbook'iga. Skript tegi teisel käivitusel kõik uuesti. Playbook vaatas, mis on juba õige, ja teisel käivitusel oli `changed=0`.

**2. kohtumine.** Playbook kasvas rollideks ja üks käsk seadistas viis masinat: andmebaasi, vahemälu, järjekorra, rakenduse ja veebiserveri. Paroolid läksid Vaulti ja Gitis olid need krüpteeritud kujul.

**3. kohtumine.** Pakkisid sama rakenduse image'iks, mille silt on commit'i SHA. Uut versiooni ei paigaldatud töötavasse konteinerisse: tehti uus image ja vana konteiner asendati.

**4. kohtumine.** Viis virtuaalmasinat tekkisid OpenTofu koodist. Enne iga muudatust näitas `tofu plan`, mis luuakse, muudetakse või kustutatakse. OpenTofu kirjutas masinate IP-d 2. kohtumise inventory'sse.

**5. kohtumine.** Kirjutasid Kubernetesele, et töötama peab kolm pod'i. Kui pod'i kustutasid, tegi Kubernetes uue, sest tegelik olek ei vastanud enam kirjeldatule.

**6. kohtumine.** AWS-i masin tekkis OpenTofu koodist ja kadus käsuga `tofu destroy`, enne kui see jõudis krediiti kulutada. GitHub Actions kontrollis iga push'i järel, et OpenTofu kood on vormindatud ja korrektne.

**7. kohtumine.** Web01 lehe muutis konveier. Katkine YAML ei jõudnud serverisse, sest lint peatas konveieri. Muudatus läks `main`-i alles pärast merge request'i.

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
