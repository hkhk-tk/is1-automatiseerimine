---
tags:
  - AWS
  - Pilv
  - Turvalisus
---

# Loeng: AWS ja pilve turvalisus

4\. kohtumisel lõi OpenTofu virtuaalmasinad kooli Proxmoxis, mille riistvara ja võrgu eest hoolitseb kool. Täna vaatad, kuidas sama töö käib pilves, kus riistvara on teenusepakkuja oma ja sina maksad kasutatud aja eest. Teine pool loengust on turvalisus: kuidas kaitsta kontot, kust kõik ressursid on kättesaadavad.

??? abstract "Õpiväljundid"

    Pärast loengut ja praktikumi oskad:

    - selgitada, mida pilv annab ja mille eest vastutab teenusepakkuja ning mille eest klient;
    - nimetada AWS-i põhiteenused ja leida neile vaste kooli laboris;
    - selgitada, kuidas pilves kulu tekib ja kuidas seda kontrolli all hoida;
    - selgitada root-kasutaja, IAM-kasutaja, rolli ja ajutise sessiooni erinevust;
    - selgitada, mis on SSO ja miks ettevõtted haldavad kasutajaid ühes kohas;
    - võrrelda konsooli, CLI ja OpenTofu kasutamist AWS-i haldamisel.

## 1. Pilv ja AWS

**Mis see on.** **Pilv** tähendab, et serverid, kettad ja võrk on teenusepakkuja andmekeskuses ja sina tellid neid API kaudu minutitega. Maksad selle eest, mida kasutad, ja kui masinat enam vaja pole, kustutad selle. **AWS** (Amazon Web Services) on suurim pilveteenuse pakkuja, teised suured on Microsoft Azure ja Google Cloud.

**Mis oli enne.** Ettevõte ostis serverid ise, pani need oma serveriruumi ja hoolitses voolu, jahutuse, võrgu ja varuosade eest. Uue serveri saamine võttis nädalaid: tellimus, tarne, paigaldus. Hiljem tulid virtualiseerimine ja Proxmoxi või VMware'i taoline platvorm, kus uus virtuaalmasin tekib minutitega, aga riistvara on endiselt sinu oma.

**Mis on praegu.** AWS alustas 2006. aastal salvestusteenusega S3 ja virtuaalmasinate teenusega EC2. Praegu on AWS-il üle 200 teenuse ja andmekeskused paljudes riikides. Enamik ettevõtteid kasutab segamini oma serveriruumi ja pilve. Kõike saab hallata API kaudu, nii et käsurida ja kood on pilves sama tähtsad kui laboris.

**Kuhu see läheb.** Üha vähem hallatakse virtuaalmasinaid ise. Ettevõtted kasutavad hallatud teenuseid, näiteks andmebaase ja Kubernetest, kus pakkuja hoolitseb uuenduste ja varunduse eest. Infrastruktuuri kirjeldatakse koodina ja muudatused käivad läbi konveieri, nagu kursusel.

Pilves jagatakse vastutus kaheks. AWS vastutab pilve enda eest: hooned, riistvara, võrk ja virtualiseerimine. Klient vastutab selle eest, mis ta pilve paneb: kasutajad ja õigused, tulemüüri reeglid, operatsioonisüsteemi uuendused ja andmed. AWS nimetab seda [jagatud vastutuse mudeliks](https://aws.amazon.com/compliance/shared-responsibility-model/). Enamik pilve turvaintsidente tuleb kliendi poolelt: avatud port, lekkinud võti või avalik andmekaust.

??? question "Kontrolli ennast"

    EC2 masinas on Ubuntu, mida pole pool aastat uuendatud, ja sellest leitakse turvaauk. Kes vastutab?

    ??? success "Vastus"

        Klient. AWS vastutab riistvara ja virtualiseerimise eest, aga masinas töötava operatsioonisüsteemi uuendamine on kliendi töö. Hallatud teenuse, näiteks andmebaasiteenuse RDS puhul uuendab operatsioonisüsteemi AWS.

## 2. Regioonid ja põhiteenused

AWS-i andmekeskused on jagatud **regioonideks**, näiteks `eu-north-1` Stockholmis ja `eu-central-1` Frankfurdis. Iga regioon on eraldi: ühes regioonis loodud masinat teises regioonis ei näe. Regioonis on mitu **käideldavustsooni** (availability zone), mis on eraldi hoonetes ja vooluvõrkudes. Kui rakendus peab töötama ka ühe andmekeskuse rikke ajal, pannakse selle masinad kahte tsooni. Regioonide loetelu on [AWS-i dokumentatsioonis](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html).

Regiooni valikul on kolm põhjust: kaugus kasutajatest, hind ja seadused. Euroopa isikuandmeid hoitakse tavaliselt Euroopa regioonis. Kursusel kasutad Stockholmi regiooni, sest see on lähedal ja seal on kõik vajalikud teenused.

??? note "Tabel 6.1. AWS-i põhiteenused ja vaste laboris"

    | Teenus | Mis see on | Vaste kooli laboris |
    |---|---|---|
    | **EC2** | virtuaalmasinad | Proxmoxi VM |
    | **AMI** | operatsioonisüsteemi mall | Proxmoxi mall, näiteks UbuntuServer |
    | **VPC** | sinu privaatvõrk pilves | laborivõrk 192.168.124.0/23 |
    | **Security group** | masina tulemüür | `ufw` masinas |
    | **S3** | failide hoidla, failid on objektid | võrguketas |
    | **IAM** | kasutajad, rollid ja õigused | Proxmoxi kasutajad ja tokenid |
    | **EKS** | hallatud Kubernetes | k3s control'is |
    | **ECR** | image'ite registry | Harbor |

Iga uus AWS-i konto saab igasse regiooni valmis **vaikimisi VPC**, kus masinad saavad avaliku IP-aadressi. Praktikumis kasutad seda. Tootmises tehakse oma VPC, kus andmebaasid on privaatvõrgus ja internetist ei paista.

## 3. Kulu

Pilves maksad iga tunni või sekundi eest, kui ressurss olemas on, ka siis, kui seda ei kasutata. Unustatud masin töötab nädalaid ja arve kasvab vaikselt. Seepärast on pilves kaks harjumust: iga ressurss saab sildi, mille järgi selle üles leiab, ja töö lõpus kustutatakse kõik, mida enam vaja pole.

??? note "Tabel 6.2. Mis maksab ja kui palju"

    | Ressurss | Umbes tunnis | Märkus |
    |---|---:|---|
    | t3.micro masin | 1,1 senti | maksab ka siis, kui seda ei kasutata |
    | avalik IPv4-aadress | 0,5 senti | iga aadress eraldi |
    | NAT gateway | 4,6 senti ja andmed | kõige sagedasem üllatus arvel |
    | EKS klaster | 10 senti | ainult juhtimise osa, masinad lisaks |

    Hinnad on Stockholmi regioonis. Täpse hinna annab [AWS Pricing Calculator](https://calculator.aws/).

Uus konto saab valida **Free plani**: kuni 200 dollarit krediiti kuueks kuuks. Free planil kaardilt raha ei võeta. Kui krediit või aeg saab otsa, konto suletakse. Tasuline plaan algab alles siis, kui ise **Upgrade plan** valid. Täpsemalt: [AWS-i Free plan](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html) ja kursuse [AWS-i reeglid](../kodutood/aws-reeglid.md).

**Eelarvehäire** (AWS Budgets) saadab e-kirja, kui kulu ületab piiri. Häire ei peata midagi, see ainult teatab. Seepärast on see vajalik ka Free planil: kiri ütleb, et midagi jäi tööle.

## 4. Kasutajad ja õigused

### Root ja IAM

Konto loomisel tekib **root-kasutaja**: e-posti aadress ja parool. Root saab teha kõike, ka konto sulgeda, ja tema õigusi ei saa piirata. AWS soovitab rooti kasutada ainult arvete ja konto seadete jaoks ning kaitsta seda kahe-etapilise sisselogimisega (**MFA**). Vaata [root-kasutaja soovitusi](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html).

Igapäevaseks tööks on **IAM** (Identity and Access Management). IAM-is on kolm põhimõistet:

- **Kasutaja** on inimene või programm, kellel on parool või võti.
- **Poliitika** on JSON-dokument, mis ütleb, milliseid toiminguid tohib teha ja milliste ressurssidega. Näiteks `AdministratorAccess` lubab kõike, `AmazonEC2ReadOnlyAccess` ainult EC2 vaatamist.
- **Roll** on õiguste komplekt, mida keegi saab ajutiselt kasutada. Rollil pole parooli ega püsivat võtit. Näiteks EC2 masin saab rolli kaudu õiguse lugeda S3-st faile, ilma et masinasse peaks võtit kirjutama.

**Vähimate õiguste põhimõte** tähendab, et igal kasutajal ja programmil on ainult need õigused, mida ta oma tööks vajab. Kursusel annad oma IAM-kasutajale `AdministratorAccess`, sest õpid kõiki teenuseid. Tootmises on konveieril ainult nende teenuste õigused, mida see kasutab. AWS-i soovitused on lehel [IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html).

### Püsiv võti ja ajutine sessioon

IAM-kasutajale saab teha **juurdepääsuvõtme** (access key): kaks pikka sõnet, millega programm logib sisse. Võti kehtib, kuni keegi selle kustutab. Kui võti satub GitHubi, leiavad automaatsed otsijad selle minutitega ja käivitavad sinu kontol masinaid. AWS-i turvaintsidendid algavad kõige sagedamini just lekkinud võtmest.

Seepärast kasutatakse võimalusel **ajutisi sessioone**. Käsk `aws login` logib sisse brauseri kaudu ja annab mõneks tunniks kehtiva sessiooni ([AWS CLI sisselogimine](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html)). EC2 masin ja GitHub Actions saavad samuti ajutised võtmed rolli kaudu. Kettal ega Gitis pole midagi, mis lekiks ja kehtiks igavesti.

??? note "Tabel 6.3. Sisselogimise viisid"

    | Viis | Kehtib | Kus kasutatakse |
    |---|---|---|
    | root parool ja MFA | igavesti | ainult konto seaded ja arved |
    | IAM-kasutaja parool ja MFA | igavesti | konsool |
    | juurdepääsuvõti | kuni kustutatakse | vanad skriptid, kui muud võimalust pole |
    | `aws login`, SSO | mõned tunnid | inimene käsureal |
    | roll | kuni tund, uueneb ise | EC2 masin, Lambda, GitHub Actions |

### SSO ja IAM Identity Center

Ettevõttes on sageli kümneid AWS-i kontosid: arendus, test, tootmine ja iga meeskonna oma. Kui igal kontol oleks oma IAM-kasutajad, peaks lahkunud töötaja kustutama igalt kontolt eraldi. **SSO** (single sign-on) tähendab, et inimene logib sisse ühe korra ettevõtte kontoga, näiteks Microsoft Entra ID või Google'i kontoga, ja saab sealt ligi kõikidele kontodele, kuhu tal on õigus. Kui töötaja lahkub, suletakse üks konto.

AWS-is teeb seda **IAM Identity Center** ([dokumentatsioon](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)). Käsureal logitakse sisse käsuga `aws sso login` ja tulemuseks on samuti ajutine sessioon. Identity Center vajab mitme konto haldamiseks AWS Organizationsit. Free plani konto Organizationsiga liituda ei saa, sest liitumine muudab konto tasuliseks. Seepärast kasutad kursusel IAM-kasutajat ja `aws login`-it, mis annab samamoodi ajutise sessiooni.

??? question "Leia viga"

    Arendaja tahab, et GitHub Actions saaks EC2 masinaid luua. Ta teeb oma IAM-kasutajale juurdepääsuvõtme ja kirjutab selle töövoofaili:

    ```yaml
    env:
      AWS_ACCESS_KEY_ID: AKIA...
      AWS_SECRET_ACCESS_KEY: wJalr...
    ```

    Mis on valesti ja kuidas peaks?

    ??? success "Vastus"

        Võti on Gitis ja kõik, kes repositooriumi näevad, saavad selle. Avalikus repositooriumis leiavad automaatsed otsijad selle minutitega. Võti kehtib, kuni see kustutatakse, ja sellel on arendaja kõik õigused. Õige on teha roll ainult EC2 õigustega ja lubada GitHub Actionsil seda rolli kasutada OIDC kaudu. Siis saab töövoog iga käivituse jaoks ajutise sessiooni ja püsivat võtit pole üldse.

## 5. Konsool, CLI ja kood

AWS-i saab hallata kolmel viisil ja kõik kasutavad sama API-t.

- **Konsool** on veebiliides. See sobib õppimiseks ja ülevaate saamiseks, aga klõpse ei saa korrata ega üle vaadata.
- **AWS CLI** on käsk `aws`. Käske saab panna skripti, aga skript ei tea, mis kontol juba olemas on: teine käivitus teeb teise masina.
- **Kood** ehk infrastruktuur koodina. **OpenTofu** ja **Terraform** kirjeldavad soovitud olekut ja võrdlevad seda state'iga, nii et teine `apply` ei tee midagi. AWS-i enda tööriist on **CloudFormation**.

Praktikumis teed sama masina kõigepealt CLI-ga ja siis OpenTofuga. CLI-ga kulub umbes kümme käsku ja masina ID tuleb ise meeles pidada. OpenTofuga on kõik ühes failis ja `tofu destroy` kustutab kõik, mis kood lõi.

Terraform on AWS-is väga levinud ja AWS kirjutab selle kohta ise juhendeid. [AWS-i Terraformi provideri head tavad](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/introduction.html) räägivad, kuidas hoida state'i S3-s, kuidas jagada koodi mooduliteks ja kuidas anda Terraformile ainult vajalikud õigused. AWS-i [5G võrkude CI/CD juhend](https://docs.aws.amazon.com/whitepapers/latest/cicd_for_5g_networks_on_aws/terraform.html) näitab, kuidas sama tööriista kasutatakse telekomifirmade suures taristus. OpenTofu kasutab sama providerit `hashicorp/aws`, nii et need juhendid kehtivad ka OpenTofu kohta. OpenTofu registris on sama provider ka nime all [`opentofu/aws`](https://search.opentofu.org/provider/opentofu/aws/latest). Kursusel kasutad nime `hashicorp/aws`, sest siis töötab sama kood ka Terraformiga.

??? question "Leia viga: näide internetist"

    [Üks OpenTofu sissejuhatus](https://medium.com/@prayag-sangode/opentofu-e21206cedab7) loob EC2 masina nii:

    ```bash
    export AWS_ACCESS_KEY_ID="<replace-me>"
    export AWS_SECRET_ACCESS_KEY="<replace-me>"
    ```

    ```hcl
    provider "aws" {
      region = "us-east-1"
    }

    resource "aws_instance" "my_instance" {
      ami           = "ami-0261755bbcb8c4a84"   # Ubuntu 20 AMI ID (us-east-1)
      instance_type = "t2.micro"
    }
    ```

    Kood töötab. Mida peaksid muutma, enne kui seda oma kontol kasutad?

    ??? success "Vastus"

        - **Püsivad võtmed** keskkonnamuutujates jäävad shelli ajalukku ja kehtivad, kuni need kustutatakse. Kasuta `aws login`-it ja profiili.
        - **AMI number on koodis kirjas.** See kehtib ainult ühes regioonis ja vananeb. Ubuntu 20.04 tavatugi on lõppenud. Võta AMI data source'iga SSM-i parameetrist.
        - **Regioon** on Ameerikas. Euroopa andmete jaoks vali Euroopa regioon.
        - **Silte ja security groupi pole.** Masin saab vaikimisi security groupi ja ilma siltideta on seda hiljem raske leida ja koristada.

??? info "Loe juurde"

    - [AWS-i ülevaade](https://docs.aws.amazon.com/whitepapers/latest/aws-overview/introduction.html): kõik teenused lühidalt.
    - [AWS Well-Architected, turvalisuse sammas](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html): AWS-i soovitused turvalise süsteemi ülesehituseks.
    - [OpenTofu AWS provider](https://search.opentofu.org/provider/hashicorp/aws/latest): kõik ressursid ja nende argumendid.
    - [Veebiserver AWS-is Terraformiga](https://dev.to/naomi_ansah_cloud/deploying-a-web-server-on-aws-using-terraform-beginner-friendly-guide-42c): algajale kirjutatud samm-sammuline näide, sama ülesanne nagu praktikumis.

??? abstract "Kokkuvõte"

    | Mõiste | Lühidalt |
    |---|---|
    | pilv | serverid ja võrk teenusepakkujalt API kaudu, maksad kasutatud aja eest |
    | jagatud vastutus | AWS vastutab pilve eest, klient selle eest, mis ta pilve paneb |
    | regioon, käideldavustsoon | eraldi asukohad ja nende sees eraldi andmekeskused |
    | EC2, AMI, security group | virtuaalmasin, mall ja tulemüür |
    | Free plan, eelarvehäire | krediit kuueks kuuks ja e-kiri, kui kulu ületab piiri |
    | root, IAM-kasutaja | kõikvõimas konto omanik ja igapäevane piiratud kasutaja |
    | roll | ajutiselt kasutatav õiguste komplekt, ilma püsiva võtmeta |
    | SSO, IAM Identity Center | üks sisselogimine kõikidele kontodele |
    | CLI ja OpenTofu | käsud teevad ühe toimingu, kood hoiab soovitud olekut |
