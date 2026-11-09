---
tags:
  - veaotsing
---

# Abi: veaotsing

Read on praktikumi moodulite kaupa. Süvenemise, sandbox-Jenkinsi, halduse ja intsidendi read on kursuse IS2 [abilehel](https://hkhk-tk.github.io/is2-automatiseerimine/k06/abi/). Neljas veerg on mehhanism, mille järgi tunned vea ära ka teistsuguse teate korral.

| Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
|---|---|---|---|
| **1. Agent ja esimene pipeline** | | | |
| `curl -sI …/login` ei anna `200` | `ip a`, VPN klient | VPN-ühendus puudub | `jenkins.lab.hkhk.ee` laheneb ja on marsruuditav ainult VPN-i kaudu |
| `docker ps` näitab Labori seisu konteinereid ka pärast `stop`-i | `docker ps --format '{{.Names}} {{.Label "com.docker.compose.project"}}'` | GitHub Actionsi deploy käivitas stacki teise projektinimega: peata see nimega | Compose leiab oma konteinerid projekti nime järgi; teise nimega stack on tema jaoks võõras |
| agent: `Failed to connect` või 403 | Nodes → `<gh>` saladus, `sudo cat /opt/jenkins/secret` | saladus vale või node'i nimi ei kattu (`<gh>` väiketähtedega) | controller arvutab saladuse node'i nimest; teine nimi või teine saladus on tema jaoks võõras agent |
| agent: `Connection refused` | `curl -sI http://jenkins.lab.hkhk.ee:8080/login` | VPN-ühendus puudub | TCP ühendus ei jõua serverini, Jenkinsi tasemele ei jõuta üldse |
| build "Waiting for next available executor on '<gh>'" | `systemctl status jenkins-agent`, Build Executor Status | agent offline või executorid hõivatud | label lubab ainult sinu agenti; kui see on maas, pole buildil kuhugi minna |
| freestyle: `sudo: a terminal is required` / `sudo apt update` ebaõnnestub | `id` buildi konsoolis | ootuspärane: kasutajal `jenkins` pole sudo-t | build töötab tavakasutajana; sudo puudumine on turvapiir, mitte viga |
| `Couldn't find any revision to build` | GitHubis haru `k06-jenkins`, folderi credential `github` | haru puudub GitHubis või token vale: `git push -u origin k06-jenkins`, token *Contents: Read* | Jenkins loeb GitHubist, mitte sinu kohalikust repositooriumist; push'imata haru tema jaoks ei eksisteeri |
| `Could not find credentials entry with ID …` või 401, kuigi parool pole muutunud | folderi Credentials, `credentialsId` Jenkinsfile'is | credential'i ID Jenkinsfile'is ei klapi folderis olevaga | Jenkins otsib credential'it ID järgi job'i folderist ja ülemistest tasemetest; teise nimega credential'it ta ei leia |
| `Tool type "maven" does not have an install of "MAVEN3.9"` | `tools` plokk | vale tööriista nimi: `maven3`, `jdk21` | `tools` otsib administraatori antud nime, mitte versiooni |
| `Scripts not permitted to use method …` | buildi konsool, Jenkinsfile'i Groovy osa | meetod pole Groovy sandboxis lubatud: kasuta sammu `sh` või lubatud sammu | Jenkinsfile'i Groovy osa töötab controlleris piiratud režiimis; see on turvapiir, mitte viga sinu koodis |
| `k06 agent` FAIL: `tools { maven / jdk } puudub` | `grep -nE '^\s*(maven\|jdk)' k06-jenkins/Jenkinsfile` | `maven` ja `jdk` peavad olema eraldi ridadel | automaatne hindaja loeb faili ridade kaupa, ühele reale kokku pandud plokki ta ei tunne |
| jobi lehel testiraportit pole | `ls target/surefire-reports` buildi ajal | `junit` puudub või muster vale | Jenkins ei loe teste ise; ta näitab ainult seda, mille `junit` samm talle XML-ist annab |
| **2. Triggerid** | | | |
| pollSCM või cron ei käivita | buildi ajalugu | `triggers` jõustub pärast esimest käsitsi buildi: Build Now üks kord | `triggers` on Jenkinsfile'is; Jenkins teab sellest alles pärast faili lugemist buildis |
| Git Polling Log: "No changes" | `git log origin/k06-jenkins -1` | commit pole push'itud või läks teisele harule | pollimine võrdleb GitHubi haru otsa viimati ehitatuga; kohalik commit seda ei muuda |
| workspace ei tühjene | `sudo du -sh /opt/jenkins/workspace/*` | `cleanWs()` puudub või build ebaõnnestus enne `post`-i (vt konsooli lõppu) | süntaksiviga Jenkinsfile'is peatab kõik, ka `post` ploki |
| ketas täis agendil | `df -h /opt/jenkins`, `docker system df` | workspace'id, `tools/`, image'id: `cleanWs()`, image'ite koristus, `buildDiscarder` | iga build jätab midagi maha; ilma koristuseta kasvab ketas iga commit'iga |
| **3. Quality gate ja Nexus** | | | |
| Sonar 502 Bad Gateway | `curl -s http://sonar.lab.hkhk.ee:9000/api/system/status` | Sonar alles käivitub (`STARTING`) | Sonari ees olev proksi vastab juba siis, kui Sonar ise alles käivitub |
| `withSonarQubeEnv`: `No SonarQube installation` | `installationName` | nimi peab olema `sonar` | nimi tuleb administraatori seadistusest (`klass-jenkins.yaml`), mitte serveri aadressist |
| Sonar: `Not authorized` / 401 | folderi credential `sonar` | token on teise projekti oma või aegunud | projektitoken kehtib ainult ühe projekti võtmega |
| katvus 0 % | `sh 'ls target/site/jacoco'` | Sonar käivitus enne `verify`-d või workspace tühjendati vahepeal | Sonar ei käivita teste, ta loeb ainult olemasolevat JaCoCo XML-i |
| Quality Gate ootab timeout'ini | koolitaja: Sonar → Webhooks → Recent deliveries | webhook ei jõua Jenkinsini | Jenkins ei küsi tulemust, vaid ootab, et Sonar selle saadaks |
| `k06 quality` FAIL: projectKey | `grep -n projectKey k06-jenkins/Jenkinsfile` | võti on `labori-seis`, peab olema `labori-seis-<gh>` | ühise võtmega kirjutaksid kõik õppijad sama projekti üle |
| Maven ei kasuta Nexust | logis pole `kooli-nexus` | `-s k06-jenkins/settings.xml` puudub mõnest `mvn` käsust | iga `mvn` käsk loeb settings-faili eraldi; üks käsk ilma `-s`-ta läheb otse Centralisse |
| Nexus 400 Bad Request | buildi nimi, Nexus Browse | versioon juba olemas: versioonis peavad olema `BUILD_NUMBER` ja commit | hosted repositoorium ei luba sama versiooni üle kirjutada (*Disable redeploy*) |
| Nexus 403 | Nexuse tee konsoolis | groupId pole `ee.hkhk.<gh>` või credential vale | Nexuse õigused on seotud teega; võõras groupId on võõras kaust |
| Nexus 401 | folderi credential `nexus` | parool vale | Nexus ei tundnud kasutajat ära |
| **4. Image samast WAR-ist** | | | |
| `permission denied ... /var/run/docker.sock` | `id jenkins`, `ls -l /var/run/docker.sock` | `jenkins` pole `docker` grupis või agenti pole taaskäivitatud: `sudo systemctl restart jenkins-agent` | grupid loetakse protsessi käivitamisel; töötav protsess uut gruppi ei näe |
| `docker build`: `COPY failed: file not found` | build context | kontekst peab olema `target`, mitte `.` | `COPY` otsib faili konteksti suhtes; repositooriumi juurkaustas pole `labori-seis.war` |
| `k06 docker` FAIL: build once | `grep -n '^COPY' k06-jenkins/Dockerfile` | Dockerfile ei kopeeri valmis WAR-i | automaatne hindaja otsib `COPY … .war` rida; mitmeastmeline fail kompileerib uuesti |
| **5. Esitamine** | | | |
| automaatne hindaja FAIL, kohalikult OK | `diff <(git ls-files k06-jenkins \| sort) <(find k06-jenkins -type f \| sort)` | fail on kettal, aga commit'imata | automaatne hindaja näeb ainult Gitis olevaid faile |
| Releases all tulemust pole | `git ls-remote --tags origin` | tag on ainult kohalikus repositooriumis | vaja on `git push origin k06` |
| tulemus vastab vanale versioonile | `git log --oneline -1 k06` ja `git log --oneline -1 main` | tag pandi enne merge'i | tag jäi haru commit'ile, mida `main`-is pole |
