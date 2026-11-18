---
tags:
  - AWS
  - Juhend
---

# Juhend: AWS-i konto Free planiga

6\. kohtumisel töötad oma AWS-i kontol. Tee konto valmis enne kohtumist, sest kinnitamine võib võtta tunde. **Free plan** on tasuta: saad kuni 200 dollarit krediiti kuueks kuuks ja kaardilt raha ei võeta. Kogu kursuse töö kulutab krediidist mõne sendi.

!!! warning "Kolm reeglit, mis hoiavad konto tasuta"

    1. Vali registreerimisel **Free plan**, mitte **Paid plan**.
    2. Ära vajuta kunagi **Upgrade plan**.
    3. Ära liitu AWS Organizationsiga.

    Kui krediit või kuus kuud saab otsa, suletakse konto ise ja arvet ei tule.

Free plani saab ainult uus klient. Kui sul on kunagi olnud AWS-i konto, loe enne alustamist [viimast lõiku](#kui-sul-on-varem-olnud-aws-i-konto).

## 1. Registreeru

1. Ava <https://aws.amazon.com/free/> ja vajuta **Create a free account**.
2. Sisesta e-posti aadress ja konto nimi, näiteks `labseis`. Kinnita e-post koodiga, mis tuleb kirjaga.
3. Vali parool. See on **root-kasutaja** parool: root saab kontoga teha kõike. Pane parool paroolihaldurisse.
4. Plaani valikul vali **Free plan**.
5. Sisesta kontaktandmed ja kinnita telefoninumber SMS-i või kõnega.
6. Kui AWS küsib makseviisi, sisesta kaart. Seda kasutatakse ainult isiku kontrolliks ja Free planil sealt raha ei võeta. Enamikult uutelt kasutajatelt makseviisi ei küsita.

Konto aktiveerimine võtab tavaliselt mõne minuti, vahel mõne tunni. Kui konto on valmis, tuleb e-kiri.

## 2. Kontrolli, et plaan on Free

Logi sisse aadressil <https://console.aws.amazon.com/> ja ava ülevalt otsingust **Billing and Cost Management**.

??? success "Oodatav tulemus"

    Lehel on kaart **Free plan**, kus on krediidi jääk dollarites ja päevade arv. Kui see kaart on olemas, on kõik korras.

??? warning "Kui seal on Paid plan"

    Ära loo kontol midagi. Kirjuta [Küsimustesse](https://github.com/hkhk-tk/is126-arutelu/discussions), kui oled konto juba teinud. Koos leiame lahenduse.

## 3. Kaitse root-kasutaja

Kui root'i parool lekib, saab võõras kontoga teha kõike. Kahe-etapiline sisselogimine (**MFA**) küsib parooli kõrval koodi sinu telefonist.

1. Paigalda telefoni autentimisrakendus, näiteks Google Authenticator või Microsoft Authenticator.
2. Vajuta konsooli paremas ülanurgas konto nimele ja vali **Security credentials**.
3. Vajuta **Assign MFA device**, vali **Authenticator app** ja skaneeri QR-kood telefoniga.
4. Sisesta kaks järjestikust koodi rakendusest.

Juhend piltidega: [MFA lisamine root-kasutajale](https://docs.aws.amazon.com/IAM/latest/UserGuide/enable-virt-mfa-for-root.html).

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
