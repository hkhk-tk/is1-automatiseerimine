---
tags:
  - Git
  - Hindamine
---

# 5. Esitamine

Töö jõuab `main`-i ja tag `k06` käivitab automaatse hindaja. Automaatne hindaja näeb ainult seda, mis on Gitis commit'itud, mitte sinu masinat, Jenkinsit ega Nexust.

## Enne esitamist

Käivita kõik kohtumise kontrollid ja vaata, et töökaust on puhas.

```bash
for t in files stages agent quality nexus secrets triggers docker; do bash autograde/check.sh k06 $t; done
git status --short k06-jenkins
```

??? success "Oodatav tulemus"

    Kõik kaheksa kontrolli annavad `OK` ja `git status` on tühi. Viimane build Jenkinsis on roheline: Build → Test → SonarQube → Quality Gate → Nexus → Docker image. Failis on ainult credential'ite ID-d, mitte saladused.

## PR, merge ja tag

Automaatne hindaja otsib tag'i `k06` `main`-i commit'il pärast merge'i, mitte haru commit'il.

```bash
git push
gh pr create --base main --head k06-jenkins --title "K6 Jenkins" --body "Jenkinsfile, settings.xml ja Dockerfile"
gh pr merge --merge
git switch main && git pull
git tag k06 && git push origin k06
```

Automaatne hindaja käivitub tag'i push'i peale, nii et ainult kohalik tag ei käivita midagi. Job ehitab ainult haru `k06-jenkins`. Kui tahad pärast merge'i ehitada ka `main`-i, muuda jobi *Branch Specifier*.

**Edasi saad minna, kui** `git ls-remote --tags origin` näitab `k06`.

## Automaatse hindaja tulemus

Tulemus ilmub paari minuti pärast Classroom 50-s. Üksikasjad on repositooriumi lehel **Releases** → viimane `submit/…`: iga mitteläbinud kontrolli juures on põhjus.

??? warning "Kui tulemus erineb sinu kohalikust kontrollist"

    Põhjus on peaaegu alati see, et tag viitab teisele commit'ile kui sinu töökaust või fail on kettal, aga commit'imata. Vaata `git log --oneline -1 k06` ja võrdle `main`-iga. Parandus on uus commit `main`-i ja seejärel `git tag -f k06 && git push -f origin k06`.

## Pärast esitamist: agent maha

7\. kohtumine Jenkinsit ei kasuta ja agent võtab control node'i mälu, mida 7. kohtumisel vajad. Kui Releases on roheline, peata agent.

```bash
sudo systemctl disable --now jenkins-agent
systemctl is-active jenkins-agent
```

??? success "Oodatav tulemus"

    `systemctl is-active jenkins-agent` vastab `inactive`.
