---
tags:
  - GitHub Actions
  - secrets
---

# 5. Käsitsi käivitus ja saladused

Deploy töötab, aga seda ei saa veel hallata: sa ei saa seda käivitada ilma commit'ita ja paroolid on failis `~/k03.env`. Need on küsimused, mida küsib iga audit ja iga intsidendi järelanalüüs.

Lõpus käivitub pipeline ka nupust, paroolid on environment'i secret'ites ja `~/k03.env` on control node'ilt kadunud.

**Kui teed seda tööl iga päev:** workflow'l on `workflow_dispatch` sisendiga `deploy`, `gh secret list --env proxmox` näitab nelja nime, environment lubab ainult main'i ja `~/k03.env` on kustutatud. Kui see on sul juba korras, mine edasi [esitamise](lab-8-esitamine.md) juurde. Ajakava, environment'i piiri katse, käsitsi kinnitus ja üks deploy korraga on IS2 süvenemises [Deploy haldus](https://hkhk-tk.github.io/is2-automatiseerimine/k05/syvenemine/#osa-5-deploy-haldus).

## Käsitsi käivitus sisendiga

Lisad workflow'le nupu, millega saab deploy käivitada ilma commit'ita. Sisend `deploy` on meie käsitsi kinnitus privaatses repos. Kinnituse teised viisid on IS2 süvenemise etapis [Käsitsi kinnitus](https://hkhk-tk.github.io/is2-automatiseerimine/k05/syvenemine/#kasitsi-kinnitus-sinu-repo-jargi).

Ilma nuputa tähendab "deploy uuesti" tühja commit'i, mis risustab ajalugu ja käivitab kõik kontrollid. Sisendi kontroll takistab ka juhuslikku klikki: deploy toimub ainult siis, kui keegi kirjutab sõna välja.

1. Lisa `on:` alla [`workflow_dispatch:`](https://docs.github.com/actions/reference/workflows-and-actions/events-that-trigger-workflows) sisendiga `deploy` (`type: string`, `default: ""`).
2. Muuda deploy job'i `if:` nii, et see käivitub kas push'il main'i või siis, kui `inputs.deploy == 'deploy'`.

    ??? example "Lahendus: trigger ja tingimus"

        ```yaml
        on:
          push:
            branches: [main, k05-actions]
          pull_request:
            branches: [main]
          workflow_dispatch:
            inputs:
              deploy:
                description: "Kirjuta deploy, et paigaldada"
                type: string
                default: ""
        ```

        Job'is `deploy`:

        ```yaml
            if: (github.event_name == 'push' && github.ref == 'refs/heads/main') || inputs.deploy == 'deploy'
        ```

3. Vii muudatus main'i, siis käivita workflow kaks korda: tühja sisendiga ja sõnaga `deploy`.

    ```bash
    gh pr create --fill --base main && gh pr checks --watch && gh pr merge --merge
    gh workflow run ci --ref main
    gh workflow run ci --ref main -f deploy=deploy
    gh run list -w ci -L 3
    ```

<!-- EKRAANIPILT: Actions → ci → nupp "Run workflow" avatud; näha haru valik ja sisendväli deploy, kuhu on kirjutatud "deploy". Käsitsi käivituse ajal.
<figure markdown="span">
  ![Run workflow dialoog sisendiga deploy](assets/k05_run_workflow.png)
  <figcaption>Joonis L5.9. Käsitsi käivitus: sisend <code>deploy</code> on meie kinnitus.</figcaption>
</figure>
-->

Tühja sisendiga käivitus tegi kõik peale deploy, mis tähendab, et nupp sobib ka lihtsalt "ehita uuesti" jaoks. Sõnaga käivitus paigaldas sama commit'i uuesti, ja see on kasulik siis, kui keegi muutis serveris midagi käsitsi ja tahad minna tagasi teadaolevasse olekusse. Nupp on näha ainult siis, kui `workflow_dispatch` on vaikeharul: seepärast pidi muudatus enne main'i jõudma.

**Edasi saad minna, kui** tühja sisendiga käivituses on `deploy` hall (*skipped*) ja sõnaga `deploy` töötas see roheliselt.

## Environment, secret'id ja muutujad

Kolid paroolid failist GitHubi environment'i ja annad need deploy job'ile ainult siis, kui ta töötab main'ilt. Secret on logis `***`, muutuja (`vars`) pole saladus.

Fail `~/k03.env` on täna kolmes kohas: control node'i kodukaustas, runner'i töökaustas ja kõigis varukoopiates. Environment'i secret on ühes kohas, krüpteeritud, ja selle kasutamist näeb deployment'ide ajaloost.

1. Ava *Settings → Environments → New environment* ja loo [environment](https://docs.github.com/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments) `proxmox`: *Deployment branches and tags* → *Selected branches* → `main`.
2. Pane secret'id control node'il failist ([`gh secret set`](https://cli.github.com/manual/gh_secret_set)), mitte brauserisse kleepides.

    ```bash
    for k in DB_ROOT_PASSWORD DB_PASSWORD RABBITMQ_PASSWORD TEACHER_TOKEN; do
      grep "^$k=" ~/k03.env | cut -d= -f2- | gh secret set "$k" --env proxmox
    done
    gh secret list --env proxmox
    ```

3. Pane muutujad.

    ```bash
    for k in REGISTRY OWNER; do gh variable set "$k" --body "$(grep "^$k=" ~/k03.env | cut -d= -f2-)"; done
    gh variable set DEPLOY_ENABLED --body true
    gh variable list
    ```

4. Muuda deploy job'i:
    - `environment: proxmox`
    - `if:` push-tingimusse lisaks `&& vars.DEPLOY_ENABLED == 'true'`
    - `cp ~/k03.env .env` asemel samm, mis kirjutab `.env`-i (`umask 077`, `printf`); väärtused saab samm `env:` kaudu: neli secret'it ja `vars.REGISTRY`, `vars.OWNER`
    - lõppu samm `if: always()`, mis kustutab `.env`

    ??? example "Lahendus: job `deploy` environment'iga"

        ```yaml
          deploy:
            needs: image
            if: (github.event_name == 'push' && github.ref == 'refs/heads/main' && vars.DEPLOY_ENABLED == 'true') || inputs.deploy == 'deploy'
            runs-on: [self-hosted, linux, labseis]
            environment: proxmox
            timeout-minutes: 10
            permissions:
              contents: read
              packages: read
            defaults:
              run:
                working-directory: k03-docker
            steps:
              - uses: actions/checkout@v5
              - uses: docker/login-action@v4
                with:
                  registry: ghcr.io
                  username: ${{ github.actor }}
                  password: ${{ secrets.GITHUB_TOKEN }}
              - name: .env secret'itest
                env:
                  DB_ROOT_PASSWORD: ${{ secrets.DB_ROOT_PASSWORD }}
                  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
                  RABBITMQ_PASSWORD: ${{ secrets.RABBITMQ_PASSWORD }}
                  TEACHER_TOKEN: ${{ secrets.TEACHER_TOKEN }}
                  REGISTRY: ${{ vars.REGISTRY }}
                  OWNER: ${{ vars.OWNER }}
                run: |
                  umask 077
                  printf '%s=%s\n' \
                    DB_ROOT_PASSWORD "$DB_ROOT_PASSWORD" DB_PASSWORD "$DB_PASSWORD" \
                    RABBITMQ_PASSWORD "$RABBITMQ_PASSWORD" TEACHER_TOKEN "$TEACHER_TOKEN" \
                    REGISTRY "$REGISTRY" OWNER "$OWNER" > .env
              - name: Deploy
                env:
                  APP_IMAGE: ${{ needs.image.outputs.ref }}
                run: |
                  docker compose pull app01
                  docker compose up -d --no-build --wait --wait-timeout 180 app01
                  docker compose restart web01
              - name: Kontroll /version
                run: |
                  docker compose exec -T app01 curl -fsS http://localhost:8080/version | tee version.json
                  grep -q "\"commit\":\"$GITHUB_SHA\"" version.json || { echo "::error::vale versioon"; exit 1; }
              - name: Koristus
                if: always()
                run: rm -f .env
        ```

5. Vii muudatus main'i ja kui deploy on roheline, kustuta koopia: `rm ~/k03.env`

<!-- EKRAANIPILT: repo Settings → Environments → proxmox; näha Deployment branches and tags: Selected branches → main ja Environment secrets nimekiri (4 nime, väärtusi ei näe). Pärast environment'i seadistamist.
<figure markdown="span">
  ![Environment proxmox: haru piirang ja secret'ite nimekiri](assets/k05_environment_proxmox.png)
  <figcaption>Joonis L5.10. Environment <code>proxmox</code>: ainult haru main ja neli secret'it.</figcaption>
</figure>
-->

> `compose.yaml` nõuab ka `REGISTRY` ja `OWNER`: ilma nendeta ebaõnnestub `docker compose up` ka siis, kui käivitad ainult app01.

Paroolid jõuavad sammu `env:` kaudu, mitte `run:` teksti sisse, seepärast on logis näha käsk ilma väärtusteta. Kui kirjutaksid `${{ secrets.DB_PASSWORD }}` otse `run:`-i, paneks GitHub väärtuse skripti teksti ja see jääks runner'i ajutisse skriptifaili. `if: always()` koristus eemaldab `.env`-i ka ebaõnnestunud deploy järel. Ilma koristuseta jääks fail runner'i töökausta järgmise job'ini.

**Edasi saad minna, kui** `gh secret list --env proxmox` näitab nelja nime ilma väärtusteta, deploy käivitub nagu enne, repo lehel on paremal *Deployments → proxmox*, logis on `.env` sammu käsurida ilma paroolideta ja `bash autograde/check.sh k05 deploy` annab `OK`.

## Miks see nii töötab

??? info "Ava selgitused"

    **`gh secret set`.** Kui `gh secret set` küsib väärtust ise või loeb selle failist (`< fail`), ei jää väärtus shelli ajalukku ega lõikelauale. Rida `printf 'väärtus' | gh secret set …` jätab väärtuse shelli ajalukku.

    **Compose'i interpoleerimine.** Compose asendab muutujad (`${REGISTRY:?}`, `${OWNER:?}`) kogu failis enne, kui valib käivitatava teenuse.

    **Environment.** Environment on GitHubi objekt, millel on oma secret'id, muutujad ja protection rule'id: haru piirang, kuni 6 ülevaatajat ja ooteaeg kuni 30 päeva. Secret võib olla kuni 48 KB ja environment'is on neid kuni 100.

    **Repo tasemel secret.** Repo tasemel secret on seevastu kättesaadav igale workflow'le igas harus. Erand on forgist tulnud PR-id ja Dependaboti käivitused, mis tavalisi secret'eid ei saa. Seetõttu on tootmiskeskkonna paroolid environment'is ja repo tasemel on ainult need secret'id, mida vajab iga job.

    **Muutujad `vars`.** Muutujad (`vars`) sobivad seadetele, mida tahad muuta ilma commit'ita, näiteks `DEPLOY_ENABLED`. Organisatsiooni repos salvestub nende muutmine organisatsiooni auditilogisse.

Kui jõudsid kiiremini: [Lisaülesanded → 14. Sama WAR app01 VM-ile](https://hkhk-tk.github.io/is2-automatiseerimine/k05/lisa/#14-sama-war-app01-vm-ile), viid sama WAR-i app01 VM-ile Ansible'iga, parool secret'ist ajutises failis.
