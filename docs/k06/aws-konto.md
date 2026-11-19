---
tags:
  - AWS
  - Juhend
---

# Juhend: AWS-i konto Free planiga

6\. kohtumisel töötad oma AWS-i kontol. Tee konto valmis enne kohtumist, sest kinnitamine võib võtta tunde. **Free plan** on tasuta: alguses saad 100 dollarit krediiti, ülesandeid tehes veel kuni 100 dollarit, ja plaan kehtib kuus kuud. Kaardilt raha ei võeta. Kogu kursuse töö kulutab krediidist mõne sendi.

!!! warning "Kolm reeglit, mis hoiavad konto tasuta"

    1. Ära vajuta kunagi **Upgrade plan**.
    2. Ära vajuta **Activate advanced features** ega **Continue with advanced features**. Need viivad tasulisele plaanile.
    3. Ära liitu AWS Organizationsiga.

    Kui krediit või kuus kuud saab otsa, suletakse konto ise ja arvet ei tule.

Free plani saab ainult uus klient. Kui sul on kunagi olnud AWS-i konto, loe enne alustamist [viimast lõiku](#kui-sul-on-varem-olnud-aws-i-konto).

## 1. Registreeru

AWS-i konto luuakse **AWS Builder ID** kaudu. Builder ID on sinu isiklik profiil ja AWS-i konto on selle all üks projekt.

1. Ava <https://aws.amazon.com/free/> ja vajuta **Create a free account**.
2. Kirjuta lahtrisse **Email** oma e-posti aadress ja vajuta **Continue with email**. Teine võimalus on logida sisse Google'i, GitHubi või Apple'i kontoga.
3. Kinnita e-post koodiga, mis tuleb kirjaga. AWS teatab, et Builder ID on loodud, ja jätkab konto loomisega.
4. Sisesta kontaktandmed: **Country or Region** on Estonia, aadress tuleb kirjutada käsitsi (**Enter address manually**) ja telefoni ette vali `+372`. Kinnita telefoninumber SMS-iga.
5. Kui AWS küsib makseviisi, sisesta kaart. Seda kasutatakse ainult isiku kontrolliks ja Free planil sealt raha ei võeta. Enamikult uutelt kasutajatelt makseviisi ei küsita.

Konto valmimisel avaneb AWS-i konsool. Esimene aken pakub koodiagendi ühendamist (**Get started by connecting your agent**). Seda pole vaja: sulge aken paremal üleval ristiga.

## 2. Kontrolli, et plaan on Free

Konsooli avalehel on kaart **Cost and usage**. Täpsemalt näed seda, kui vajutad paremal üleval konto nimele ja seejärel vasakul all oma nime kõrval kolmele täpile.

??? success "Oodatav tulemus"

    Kirjas on **Credits remaining** dollarites ja **Days remaining** päevades. Kui need on olemas, on konto Free planil.

??? warning "Kui krediiti ja päevi pole näha"

    Ära loo kontol midagi. Kirjuta [Küsimustesse](https://github.com/hkhk-tk/is126-arutelu/discussions), koos leiame lahenduse.

## 3. Kaitse sisselogimine

AWS-i kontoga saab käivitada masinaid, mis maksavad raha. Kui keegi saab sinu parooli kätte, võib ta panna tööle kallid masinad, näiteks krüptoraha kaevandamiseks, ja see on AWS-is tavaline rünnak. Free planil ei teki küll arvet, aga konto võidakse sulgeda ja kogu töö kaob. Teine kinnitusviis (**MFA**) tähendab, et ainult paroolist ei piisa: lisaks küsitakse koodi sinu telefonist.

=== "Logisid sisse Google'i, GitHubi või Apple'i kontoga"

    Sinu AWS-i kontot kaitseb see konto. Kontrolli, et seal on kaheastmeline kinnitamine sees, näiteks Google'is <https://myaccount.google.com/security>, rida **2-Step Verification**. Kui see on sees, on AWS-i sisselogimine kaitstud.

=== "Lõid konto e-posti ja parooliga"

    1. Paigalda telefoni autentimisrakendus, näiteks Google Authenticator või Microsoft Authenticator.
    2. Vajuta konsoolis paremal üleval konto nimele, seejärel vasakul all oma nime kõrval kolmele täpile ja vali **Manage security and sign-in**.
    3. Lisa **Authenticator app**, skaneeri QR-kood telefoniga ja sisesta kood.

## 4. Tee IAM-kasutaja

Igapäevaseks tööks teed eraldi kasutaja. Root'iga logid sisse ainult siis, kui on vaja arveid või konto seadeid vaadata.

1. Ava otsingust **IAM**, vasakult **Users** ja vajuta **Create user**.
2. Nimi `admin`. Märgi **Provide user access to the AWS Management Console** ja vali **I want to create an IAM user**.
3. Vali oma parool ja eemalda märge **Users must create a new password at next sign-in**.
4. Järgmisel lehel vali **Attach policies directly** ja märgi `AdministratorAccess`.
5. Vajuta **Create user**. Kirjuta üles **Console sign-in URL**: selle aadressiga logid edaspidi sisse.
6. Ava kasutaja `admin`, vahekaart **Security credentials**, ja lisa ka sellele MFA nagu 3. sammus.

Juhend piltidega: [IAM-kasutaja loomine](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html).

Logi välja ja logi sisse kasutajana `admin` aadressilt, mille 5. sammus üles kirjutasid.

??? success "Oodatav tulemus"

    Konsooli paremas ülanurgas on `admin @ <konto number>`.

## 5. Eelarvehäired

Eelarvehäire saadab e-kirja, kui midagi hakkab raha kulutama. See ei peata midagi, aga annab teada, kui mõni masin jäi tööle.

1. Ava **Billing and Cost Management**, vasakult **Budgets**, ja vajuta **Create budget**.
2. Vali **Use a template** ja **Zero spend budget**. Lisa oma e-posti aadress ja vajuta **Create budget**.
3. Tee teine eelarve: mall **Monthly cost budget**, summa `10` ja sama e-posti aadress.

??? success "Oodatav tulemus"

    **Budgets** all on kaks eelarvet. Zero spend budget võib saata esimese kirja juba samal päeval. See on oodatud: kiri tähendab, et häire töötab.

## 6. Regioon

Vali konsooli paremast ülanurgast regiooniks **Europe (Stockholm) eu-north-1**. Kõik kursuse tööd käivad selles regioonis.

Konto on valmis. Ülejäänud teed 6. kohtumisel [praktikumi](lab.md) järgi.

## Kui sul on varem olnud AWS-i konto

AWS-i tingimuste järgi ei saa Free plani see, kellel on või on olnud AWS-i konto. Siis on kaks võimalust:

1. **Kasuta oma vana kontot.** Tee sellel samm 3 kuni 5: MFA, IAM-kasutaja ja eelarvehäired. Praktikumis töötab üks väike masin umbes tund ja kulu on mõni sent. Kustuta praktikumi lõpus kõik, nagu juhend ütleb.
2. **Tee praktikum ilma AWS-ita.** Kirjutad koodi valmis ja käivitad ainult `tofu plan`, mis näitab, mida tehtaks, aga ei loo midagi.

Kirjuta enne kohtumist [Küsimustesse](https://github.com/hkhk-tk/is126-arutelu/discussions), kumma valisid.
