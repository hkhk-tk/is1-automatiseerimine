---
tags:
  - GitHub Actions
  - Trivy
  - turve
---

# 3. Trivy ja õigused

Roheline build ütleb ainult, et build õnnestub. See ei ütle, kas sõltuvustes on teadaolev CVE, kas build töötab ka järgmise Java'ga ja kas pipeline ise on rünnatav. Viimane puudutab adminit otse, sest pipeline'il on ligipääs registry'le ja hiljem ka sinu serverile.

Osa lõpuks skännib teine job sõltuvusi build'iga samal ajal, Trivy action on SHA-ga fikseeritud ja igal job'il on ainult talle vajalikud tokeni õigused.

**Kui teed seda tööl iga päev:** job `security` on olemas, igal job'il on oma `permissions:` ja `bash autograde/check.sh k05 hygiene` annab `OK`. Kui see on sul juba korras, mine edasi [image'i ja deploy](lab-4-deploy.md) juurde. Compat-matrix, vahemälu, kõik action'id SHA-ga ja Dependabot on IS2 süvenemises [Turvaskänn ja sõltuvused lähemalt](https://hkhk-tk.github.io/is2-automatiseerimine/k05/syvenemine/#osa-3-turvaskann-ja-soltuvused-lahemalt).

## Turvaskänn eraldi job'ina

Lisad job'i `security`, mis töötab build'iga kõrvuti ja kirjutab Trivy tulemuse käivituse kokkuvõttesse. `aquasecurity/trivy-action` vanad tag'id suunati pahatahtlikele commit'idele ([GHSA-69fq-xp46-6x23](https://github.com/aquasecurity/trivy-action/security/advisories)). Seepärast kasutad täis-SHA-d.

See intsident on hea näide, miks tag'i usaldamine on risk: sama nimi, mis eile osutas korralikule koodile, osutas järgmisel päeval koodile, mis luges runner'ilt saladusi. Kõik, kes kasutasid tag'i, käivitasid seda koodi ilma ühtki faili muutmata.

1. Lisa job `security` (`runs-on: ubuntu-latest`, checkout ja Trivy), ilma `needs`-ita:
    - `uses:` rida `aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25  # v0.36.0`: see on versiooni v0.36.0 commit'i täis-SHA
    - sisendid `scan-type: fs`, `scan-ref: .`, `scanners: vuln`, `severity: CRITICAL,HIGH`
    - `format: table`, `output: trivy.txt`, `exit-code: "0"`
    - kaks sammu `if: always()`: üks kirjutab `trivy.txt` sisu `$GITHUB_STEP_SUMMARY`-sse, teine laadib selle artefaktina üles nimega `trivy-raport`

    ??? example "Lahendus: job `security`"

        ```yaml
          security:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v5
              - uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25  # v0.36.0
                with:
                  scan-type: fs
                  scan-ref: .
                  scanners: vuln
                  severity: CRITICAL,HIGH
                  format: table
                  output: trivy.txt
                  exit-code: "0"
              - name: Kokkuvõte
                if: always()
                run: cat trivy.txt >> "$GITHUB_STEP_SUMMARY"
              - if: always()
                uses: actions/upload-artifact@v7
                with:
                  name: trivy-raport
                  path: trivy.txt
        ```

        Job `security` on sama taandega kui `build`, mõlemad ploki `jobs:` all.

2. Tee push ja ava käivituse *Summary*.
3. Leia HIGH ja CRITICAL leidude arv ja teek, mis andis kõige rohkem leide.

<!-- EKRAANIPILT: Actions → käivitus → Summary leht, kerida security job'i kokkuvõtteni; näha Trivy tabel (Library, Vulnerability, Severity veerud) ja allosas Artifacts plokk. Pärast security job'i esimest käivitust.
<figure markdown="span">
  ![Käivituse kokkuvõte Trivy leidude tabeliga](assets/k05_trivy_kokkuvote.png)
  <figcaption>Joonis L5.3. Trivy tabel käivituse kokkuvõttes.</figcaption>
</figure>
-->

<!-- EKRAANIPILT: Actions → käivitus pärast security job'i lisamist → Summary ülaosa graaf; näha build ja security kõrvuti (paralleelselt), mõlemad rohelised, all Artifacts: labori-seis-war ja Trivy raport.
<figure markdown="span">
  ![Käivituse graaf, kus build ja security töötavad kõrvuti](assets/k05_actions_graaf.png)
  <figcaption>Joonis L5.4. Build ja security töötavad paralleelselt.</figcaption>
</figure>
-->

> `Unable to resolve action` tähendab tavaliselt vale SHA-d: see peab olema täpselt 40 kuueteistkümnendmärki, lühike SHA ei tööta. Kopeeri rida lahendusest.

Kõrvuti töötavad job'id tähendavad, et skänn ei lisa käivitusele aega, kui ta pole build'ist aeglasem. `exit-code: "0"` jätab job'i roheliseks ka leidude korral: täna sa kogud infot, otsus "kas leid peatab pipeline'i" on lisaülesandes [10. Trivy poliitika](https://hkhk-tk.github.io/is2-automatiseerimine/k05/lisa/#10-trivy-poliitika). `if: always()` on vajalik, sest muidu kaoks raport just siis, kui Trivy ise ebaõnnestub. Kui leide on null, kontrolli, kas `scan-ref` osutab repo juurele, kus on `pom.xml`.

**Edasi saad minna, kui** graafis on `build` ja `security` kõrvuti, kokkuvõttes on Trivy tabel ja *Artifacts* all on WAR ja Trivy raport.

## Iga job oma õigustega

Võtad kõik tokeni õigused workflow tasemel ära ja annad iga job'ile tagasi ainult lugemisõiguse. `GITHUB_TOKEN` antakse igale sammule, ka kolmanda osapoole action'ile.

Trivy intsidendi pahatahtlik kood kasutas just seda tokenit. Kui tokenil on kirjutusõigus, võib kompromiteeritud action muuta sinu koodi, release'e või pakette. Lugemisõigusega token saab ainult lugeda seda, mida runner niikuinii näeb.

1. Ava viimase käivituse build job'i *Set up job* ja vaata plokki *GITHUB_TOKEN Permissions*.
2. Lisa faili ülaossa (mitte job'i alla) `permissions: {}` ja mõlemale job'ile `permissions:` plokk `contents: read`.

    ??? example "Lahendus: õigused failis `ci.yml`"

        ```yaml
        name: ci
        on:
          # … nagu enne
        permissions: {}
        jobs:
          build:
            runs-on: ubuntu-latest
            permissions:
              contents: read
            steps:
              # … nagu enne
          security:
            runs-on: ubuntu-latest
            permissions:
              contents: read
            steps:
              # … nagu enne
        ```

3. Tee push ja kontrolli.

    ```bash
    bash autograde/check.sh k05 hygiene
    bash autograde/check.sh k05 actionlint
    ```

<!-- EKRAANIPILT: Actions → käivitus pärast permissions muudatust → job build → Set up job laiendatud; näha plokk "GITHUB_TOKEN Permissions" ridadega Contents: read ja Metadata: read.
<figure markdown="span">
  ![Set up job sammu plokk GITHUB_TOKEN Permissions](assets/k05_token_oigused.png)
  <figcaption>Joonis L5.5. Pärast job'i plokki <code>contents: read</code> on tokenil ainult lugemisõigus.</figcaption>
</figure>
-->

Workflow tasemel `{}` ei anna ühtegi õigust, nii et ilma job'i plokita ebaõnnestuks privaatse repo checkout. `Metadata: read` on alati olemas ja seda ei saa ära võtta. Kui pärast muudatust näed plokis endiselt `Contents: write`, on `permissions:` vales taandes ja GitHub ei loe seda job'i omaks.

**Edasi saad minna, kui** enne muudatust oli plokis mitu õigust ja pärast ainult `Contents: read` ja `Metadata: read` ning mõlemad kontrollid annavad `OK`.

## Miks see nii töötab

??? info "Ava selgitused"

    **Job'i `permissions:`.** Job'i `permissions:`-plokk asendab workflow tasemel määratud õigused täielikult. Kui job'i plokist jääb välja `contents: read`, ei saa checkout privaatset repot lugeda. `GITHUB_TOKEN` kehtib job'i lõpuni, kuid mitte üle 24 tunni. Repo vaikeõigus (*Settings → Actions → Workflow permissions*) on 2023. aasta veebruarist alates uutes repodes lugemine, vanemates sageli kirjutamine.

    **Trivy failisüsteemi skännimine.** Failisüsteemi skännimisel loeb Trivy faili `pom.xml` ja lahendab sõltuvuspuu. Seetõttu leiab Trivy ka transitiivsed sõltuvused, mida pom'is otse kirjas ei ole. Sõltuvuspuu lahendamiseks vajab Trivy võrguühendust Maven Centralisse. Kui kaustas on juba ehitatud WAR või JAR, skännib Trivy ka neid.

    **Haavatavuste andmebaas.** Trivy haavatavuste andmebaasi uuendatakse mitu korda päevas ja Trivy laadib uue versiooni, kui kohalik koopia on aegunud. Seetõttu võib sama kood anda homme teise tulemuse kui täna. Sel põhjusel on ajastatud skännimine vajalik ja turvaraporteid saab võrrelda ainult koos kuupäeva ja andmebaasi versiooniga. JSON-väljundis on leiu ID, teek ja parandatud versioon eraldi väljadena; neid on vaja, kui tahad iga leiu kohta automaatselt pileti avada.

Kui jõudsid kiiremini: [Lisaülesanded → 6. Trivy masinloetavalt](https://hkhk-tk.github.io/is2-automatiseerimine/k05/lisa/#6-trivy-masinloetavalt), loed Trivy leiud JSON-ist kokku.
