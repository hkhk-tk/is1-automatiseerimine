---
tags:
  - Jenkins
  - CI/CD
---

# 2. Triggerid

Build, mille keegi peab nupust käivitama, jääb tegemata just siis, kui seda kõige rohkem vaja on. Praegu käivitad buildi nupuga **Build Now**. Selles moodulis käivitab commit buildi ise.

Kõige kiirem viis oleks webhook: GitHub teatab Jenkinsile igast push'ist. Klassi Jenkins on VPN-i taga ja GitHubi serverid ei jõua selleni, seepärast kasutad pollimist.

## Lase commit'il buildi käivitada

Kui GitHub ei saa Jenkinsit kutsuda, küsib Jenkins ise. `pollSCM` kontrollib ajakava järgi, kas harul on uus commit, ja käivitab buildi ainult siis, kui on. `H/2` tähendab "iga kahe minuti järel, minut valitakse jobi nimest", nii et 15 õppija pollimised ei tule samal sekundil.

Ilma `H`-ta teeksid kõik jobid oma `git ls-remote`-i samal sekundil: sada jobi teevad Giti serverile iga kahe minuti järel samal hetkel sada päringut.

1. Lisa Jenkinsfile'i `pipeline {}` sisse pärast `tools` plokki:

    ```groovy
        triggers {
            pollSCM('H/2 * * * *')
        }
    ```

2. Push, siis **Build Now** üks kord käsitsi. `triggers` on osa Jenkinsfile'ist ja Jenkins loeb selle alles käivitamisel.
3. Tee väike commit (näiteks kommentaar Jenkinsfile'is), push ja oota järgmist pollimist.
4. Ava jobi menüüs **Git Polling Log**.

<!-- EKRAANIPILT: job mari-tamm/labori-seis → Git Polling Log pärast väikest commit'i: rida "Changes found" ja commit'i räsi; soovi korral kõrvale buildi leht tekstiga "Started by an SCM change". Sammu 27.2 lõpus.
<figure markdown="span">
  ![Git Polling Log: Jenkins leidis uue commit'i](assets/k06_polling_log.png)
  <figcaption>Joonis L6.6. Polling logis on näha, millise commit'i Jenkins leidis.</figcaption>
</figure>
-->

Kontrolli faili automaatse hindaja testiga:

```bash
bash autograde/check.sh k06 triggers
```

??? success "Oodatav tulemus"

    Uus build algas ise ja buildi lehel on "Started by an SCM change". Polling logis on viimane räsi, mida Jenkins nägi, ja otsus "Changes found" või "No changes". Kontroll annab `OK`.

??? warning "Kui build ei käivitu ise"

    `triggers` jõustub alles pärast esimest käsitsi käivitatud buildi, sest Jenkins loeb Jenkinsfile'i alles buildis. Kui logis on vale räsi, vaatab job teist haru või teist repositooriumi. Kui logis on "No changes", ei ole commit GitHubis: kontrolli `git log origin/k06-jenkins -1`.

**Edasi saad minna, kui** uus build algas ise, buildi lehel on "Started by an SCM change", polling logis on sinu commit ja kontroll annab `OK`.
