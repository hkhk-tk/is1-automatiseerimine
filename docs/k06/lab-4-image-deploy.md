---
tags:
  - Jenkins
  - Docker
  - CI/CD
---

# 4. Image samast WAR-ist

Kui testkeskkonda läheb teine fail kui see, mis läbis kontrollid, ei saa testkeskkonna tulemusi usaldada. Sama WAR, mis läbis quality gate'i ja on Nexuses, läheb nüüd ka Docker image'isse. Image'i ehitab pipeline, mitte sina.

## Kirjuta build once Dockerfile

3\. kohtumise mitmeastmeline Dockerfile kompileerib WAR-i uuesti ja see pole enam sama WAR, mis läbis quality gate'i. Teine kompileerimine võib saada teise sõltuvuse versiooni või teise JDK ja siis testisid üht faili, aga paigaldad teist. Loo `k06-jenkins/Dockerfile`, mis ise midagi ei kompileeri. Nõuded:

- alus `tomcat:10.1-jre21-temurin`, `curl` HEALTHCHECK'i jaoks
- `COPY labori-seis.war /usr/local/tomcat/webapps/ROOT.war`
- HEALTHCHECK `/health` peale
- viimastena `ARG GIT_SHA` ja `ENV GIT_SHA`, et eelmised kihid tuleksid cache'ist

??? example "Fail k06-jenkins/Dockerfile"

    ```dockerfile
    FROM tomcat:10.1-jre21-temurin
    RUN apt-get update \
        && apt-get install -y --no-install-recommends curl \
        && rm -rf /var/lib/apt/lists/* /usr/local/tomcat/webapps/*
    COPY labori-seis.war /usr/local/tomcat/webapps/ROOT.war
    HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
        CMD curl -fsS http://localhost:8080/health || exit 1
    ARG GIT_SHA
    ENV GIT_SHA=$GIT_SHA
    ```

Kontrolli faili:

```bash
grep -c mvn k06-jenkins/Dockerfile
bash autograde/check.sh k06 files
```

`ARG GIT_SHA` on viimane, sest `ARG`-i väärtuse muutus tühistab cache'i alates esimesest reast, mis seda kasutab. Faili alguses ehitaks see iga commit'iga ka `apt-get` kihi uuesti.

??? success "Oodatav tulemus"

    `grep -c mvn` annab `0`: Dockerfile'is pole Maveni etappi. Kontroll `files` annab `OK`, sest `Jenkinsfile`, `settings.xml` ja `Dockerfile` on olemas.

## Ehita image pipeline'is

`docker build` töötab agendil kasutajana `jenkins`, nii et see kasutaja peab saama Docker daemoniga suhelda. Build context on `target/`, mis sisaldab juba kontrollitud WAR-i, nii et Docker saadab daemonile ainult WAR-i.

`docker` grupp võrdub sellel masinal root-õigusega ja Jenkinsfile'i muutja saab selle õiguse endale. Seepärast on see lubatud ühe õppija agendil, aga mitte jagatud controlleris.

1. Kontrolli, et kasutaja `jenkins` on agendil grupis `docker`: `id jenkins | grep -o docker`.
2. Lisa pärast Nexuse etappi etapp Docker image.

    ```groovy
            stage('Docker image') {
                steps { sh 'docker build -f k06-jenkins/Dockerfile --build-arg GIT_SHA=$GIT_COMMIT -t labori-seis:$ART_VERSION target' }
            }
    ```

3. Iga build jätab agendile workspace'i ja Dockeri vahekihid. Lisa `pipeline {}` lõppu, pärast plokki `stages`, koristus. `post` plokk `cleanup` käivitub buildi lõpus alati, ka siis, kui build ebaõnnestus.

    ```groovy
        post {
            cleanup {
                sh 'docker image prune -f'
                cleanWs()
            }
        }
    ```

4. Push ja oota buildi.

```bash
docker image ls labori-seis
docker inspect --format '{{.Config.Env}}' labori-seis:<tag> | tr ' ' '\n' | grep GIT_SHA
bash autograde/check.sh k06 docker
```

??? success "Oodatav tulemus"

    `docker image ls labori-seis` näitab tag'i, mis on sama mis versioon Nexuses ja buildi nimi Jenkinsis. `GIT_SHA` image'i keskkonnas on sama commit, millest build tehti. Kontroll `docker` annab `OK`.

??? warning "Kui `docker build` annab `permission denied ... /var/run/docker.sock`"

    Kasutaja `jenkins` ei ole `docker` grupis või agenti pole pärast seda taaskäivitatud. Grupi muutus jõustub alles uues protsessis: `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins-agent`.

Image'i tag ja Nexuse versioon on sama string, nii et ühest leiad alati teise. Salvesta töö GitHubi:

```bash
git add k06-jenkins/ && git commit -m "k06: Docker image samast WAR-ist" && git push
```

**Edasi saad minna, kui** etapp Docker image on roheline, image'i tag on sama mis Nexuses ja kontroll annab `OK`.
