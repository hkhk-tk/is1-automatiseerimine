---
tags:
  - Docker
  - Compose
  - Harbor
  - Praktikum
---

# Praktikum: Labori seis konteinerites

Kahel esimesel kohtumisel seadistasid Ansible'iga teenused otse virtuaalmasinatesse. Täna pakid sama rakenduse, Labori seisu, konteineritesse. Paigaldad Dockeri, ehitad image'id oma Dockerfile'idest, käivitad viis teenust ühe `compose.yaml`-iga, lükkad image'id kursuse registry'sse Harbor ja esitad töö.

Iga osa alguses on eesmärk ja kontroll. Kui oskad, tee osa eesmärgi järgi ise ja ava lahendused ainult kontrolliks. Töö tulemus on sinu harus `k03-docker` olev kood ja automaatkontroll kontrollib seda GitHubis.

**Edenemine:** laboritahvel <http://is126.kaaren.lab.hkhk.lan> (VPN-iga).

Küsimused: [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions). Lisa küsimusele käsk ja kogu veateade tekstina. Enne saatmist eemalda paroolid ja tokenid.

??? tip "Algseis: mida saad valmis kujul ja mida teed ise"

    **Saad valmis kujul:** starteris kaust `k03-docker` rakenduse koodi, Nginxi konfiguratsioonifaili, `.env.example`-i, Harbori CA ja mallidega, kuhu kirjutad Dockerfile'id ja `compose.yaml`-i. Harbori vahemälu tõmbab image'id Docker Hubist. 2. kohtumise tööd see praktikum ei vaja: alustad harust `main`.

    **Teed ise:** paigaldad Dockeri, kirjutad kolm Dockerfile'i ja `compose.yaml`-i, lükkad image'id Harborisse ning esitad töö tag'iga `k03`. Kodutöö on boonus.

    **Kui midagi läks katki:** `git restore <fail>` toob faili tagasi viimase commit'i kujul. `docker compose down` ja `docker compose up -d` loovad konteinerid uuesti. `docker compose down -v` kustutab ka andmebaasi andmed.

??? abstract "Õpiväljundid"

    1. Paigaldad Dockeri, tõmbad image'id Docker Hubist ja Harbori kaudu ning selgitad, kus konteiner hostis paistab: protsess, port ja andmed.
    2. Kirjutad ametlike image'ite põhjal Dockerfile'id ja mitmeastmelise app-image'i.
    3. Kirjeldad viie teenusega stacki `compose.yaml`-is healthcheck'ide ja sõltuvustega.
    4. Lükkad image'id Harborisse ja käivitad stacki registry image'itest.
    5. Kontrollid töö automaatkontrolli testidega ja esitad selle.

??? info "Testitud versioonid"

    Docker Engine 29 (vähemalt 28), Compose v5 (vähemalt v2.24.4), ansible-core 2.16, Harbor 2.15, `mariadb:11.4`, `rabbitmq:4.1-management-alpine`, `memcached:1.6-alpine`, `nginx:1.30-alpine`, `tomcat:10.1-jre21-temurin`, `maven:3-eclipse-temurin-21`, `alpine:3.22`, Podman 5 (AlmaLinux 9.8), Trivy 0.76. Vanem Compose ei toeta silte nagu `!override`. Prod-faili lugemisel annab see süntaksivea, mille teade ei viita versioonile.

    Dokumentatsioon: [Dockerfile](https://docs.docker.com/reference/dockerfile/), [Compose'i fail](https://docs.docker.com/reference/compose-file/), [Harbor](https://goharbor.io/docs/2.14.0/), [Podman](https://docs.podman.io/), [Trivy](https://trivy.dev/docs/latest/).

## Osa 1 · Docker ja esimesed konteinerid

Paigaldad Dockeri käsitsi, käivitad esimese konteineri ja tutvud Docker Hubi ning kursuse registry Harboriga. Seejärel käivitad konteinerid ilma Compose'ita ja vaatad hostist, kus on konteineri protsess, piirangud, port ja andmed. Docker ei too uusi tuuma mehhanisme: konteiner on hostis tavaline protsess, mida piiravad cgroup'id ja nftables'i reeglid.

**Eesmärk:** Docker töötab control'is, image'id tulevad Harbori kaudu ja oskad konteinereid käivitada, peatada ja eemaldada.  
**Kontroll:** `docker run --rm $HUB/hello-world` prindib `Hello from Docker!`: Docker töötab ja image tuli Harbori vahemälu kaudu.  
**Kus:** control, kaust `~/kursus/k03-docker`, konteinerid käsitsi ilma Compose'ita.

### 1.1 Haru ja failid

Iga kohtumise töö käib eraldi harus. Käsk `git pull` toob repositooriumi uued failid, ka kausta `k03-docker` algfailid.

```bash
cd ~/kursus
git switch main
git pull
git switch -c k03-docker
cd k03-docker
ls -AR
git check-ignore -v .env
```

??? success "Oodatav tulemus"

    Kaustas on mallid `compose.yaml`, `db/Dockerfile`, `web/Dockerfile` ja `app/Dockerfile` ning failid `.env.example` ja `web/nginx.conf`. Kaustas `roles/` on Harbori sertifikaat, mida vajad 1.5-s. `docker.yml` on kodutöö jaoks. Mallid täidad selle praktikumi käigus. `git check-ignore` näitab rida `.gitignore:…:k03-docker/.env`: paroolidega fail `.env` jääb Gitist välja.

??? warning "Kui failid puuduvad"

    Kui `git pull` ei toonud kausta `k03-docker` faile, kirjuta koolitajale. Koolitaja saadab need sinu repositooriumisse.

??? warning "Kui tuleb viga `a branch named 'k03-docker' already exists`"

    Haru on sul juba olemas, näiteks eelmisest katsest. Uut haru pole vaja teha. Vaheta olemasolevale harule käsuga `git switch k03-docker` ja jätka käsust `cd k03-docker`.

### 1.2 Paigalda Docker

Konteinerite käivitamiseks on control'is vaja Dockerit. Seda seal veel pole, nii et paigaldad selle kõigepealt.

Paigaldus käib nagu iga teise programmi puhul `apt`-iga, aga Dockeri enda paketihoidlast. Ubuntu oma pakett `docker.io` on vanem ja selles pole Compose'i, mida vajad 4. osas. Käsud on Dockeri [ametlikust juhendist](https://docs.docker.com/engine/install/ubuntu/). Need eemaldavad vanad paketid, lisavad Dockeri paketihoidla ja paigaldavad Dockeri.

```bash
sudo apt-get remove -y docker.io docker-compose docker-compose-v2 podman-docker containerd runc
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Nüüd lisa paketihoidla. Fail `docker.sources` ütleb `apt`-ile, kust Dockeri pakette võtta, ja lubab ainult Dockeri võtmega allkirjastatud pakette.

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Docker on nüüd paigaldatud, aga `docker` käsk töötab ainult `sudo`-ga. Ilma selleta tuleb viga `permission denied … docker.sock`. Et ei peaks iga käsu ette `sudo` kirjutama, lisa oma kasutaja gruppi `docker`:

```bash
sudo usermod -aG docker "$USER"
```

Uus grupp hakkab kehtima alles siis, kui logid uuesti sisse. VS Code'is vajuta ++f1++, vali **Remote-SSH: Kill VS Code Server on Host** ja ühenda control'iga uuesti.

Kontrolli, et kõik töötab:

```bash
id                                      # grupp docker on nimekirjas
docker version --format 'klient {{.Client.Version}}, server {{.Server.Version}}'
docker compose version                  # Compose on olemas
systemctl is-active docker containerd   # mõlemad teenused töötavad
```

??? success "Oodatav tulemus"

    `id` real on grupp `docker`. `docker version` näitab kliendi ja serveri versiooni, mõlemad 28 või uuemad. `docker compose version` näitab Compose'i versiooni. `systemctl` vastab kaks korda `active`.

??? warning "Kui tuleb ikka `permission denied … docker.sock`"

    Uus grupp ei hakanud veel kehtima. Kontrolli käsuga `id`, kas grupp `docker` on olemas. Kui see puudub, logi uuesti sisse nagu ülal kirjas. Kui see puudub ka siis, käivita `usermod` käsk uuesti.

!!! warning "Grupp `docker` annab root'i õigused"

    Grupi `docker` liige saab Dockeri kaudu muuta kõiki hosti faile ilma parooli küsimata, nagu root. Kursuse masinas on see lubatud. Jagatud serveris lisa gruppi `docker` ainult neid, kellel on niikuinii root'i õigus.

### 1.3 Esimene konteiner

Nüüd käivitad esimese konteineri. Selleks on vaja kahte mõistet. **Image** on nagu programmi paigalduspakett. Selles on programmi failid ja seaded, millega programm käivitub. **Konteiner** on image'ist käivitatud programm. Ühest image'ist saab käivitada mitu konteinerit.

Proovi image'iga `hello-world`. Selles on üks väike programm, mis prindib tervituse ja lõpetab.

**Küsimus enne käsku:** image'it `hello-world` sinu masinas veel ei ole. Kust Docker selle võtab?

```bash
docker run hello-world
```

??? success "Oodatav tulemus"

    Esimene rida `Unable to find image 'hello-world:latest' locally` tähendab, et image'it masinas polnud. Rida `Pulling from library/hello-world` tähendab, et Docker laadis image'i alla **Docker Hubist**. Docker Hub on Dockeri avalik image'ite hoidla (registry). Lõpuks prindib programm `Hello from Docker!` ja selgitab neljas punktis, mis juhtus.

Teate neli punkti vastavad joonisele 3.1. Käsk `docker` saadab sinu soovi taustteenusele `dockerd`. `dockerd` laadib image'i alla, käivitab sellest konteineri ja saadab programmi väljundi sinu terminali.

<figure markdown="span">
  ![docker CLI saadab socket'i kaudu päringu dockerd-le, dockerd annab töö containerd-le, containerd käivitab runc-iga konteineri, mis on hostis tavaline protsess; dockerd tõmbab ja lükkab image'id registry'sse Harbor](assets/k03_docker_ahel.svg)
  <figcaption>Joonis 3.1. Docker Engine'i osad: klient, daemon, containerd ja runc (Talvik, 2026).</figcaption>
</figure>

Käivita sama käsk teist korda ja vaata seejärel konteinerid ja image'id üle. Nii näed, kas image laaditakse uuesti alla, kas töö lõpetanud konteiner jääb masinasse alles ja mitu image'it masinas on.

```bash
docker run hello-world | head -3
docker ps          # töötavad konteinerid
docker ps -a       # kõik konteinerid, ka lõpetanud
docker image ls    # image'id
```

??? success "Oodatav tulemus"

    Teisel korral allalaadimist ei olnud, sest image oli juba masinas. `docker ps` on tühi, sest ükski konteiner ei tööta. `docker ps -a` näitab kahte konteinerit olekus `Exited (0)`. See tähendab, et programm lõpetas töö edukalt ja konteiner peatus koos sellega. Peatatud konteinerid jäävad masinasse, kuni need kustutad. `docker image ls` näitab ühte image'it `hello-world`, sest mõlemad konteinerid tehti samast image'ist.

### 1.4 Docker Hub

Eelmises sammus tuli image `hello-world` Docker Hubist. **Docker Hub** (<https://hub.docker.com>) on Dockeri avalik registry ehk image'ite hoidla. Kui image'i nimes pole registry aadressi, võtab Docker image'i sealt.

Lühike nimi `nginx` tähendab tegelikult täisnime `docker.io/library/nginx:latest`. Selles on neli osa.

- `docker.io` on registry aadress.
- `library` on ametlike image'ite kaust.
- `nginx` on image'i nimi.
- `latest` on tag ehk versioon.

Ava brauseris Docker Hub ja otsi `nginx`. Tulemuste juures on märk, mis näitab, kes image'i teeb.

- **Docker Official Image** on Dockeri hallatud image. Selle Dockerfile on avalik ja seda uuendatakse turvaparandustega. Nimes pole kasutajanime, näiteks `nginx` või `mariadb`.
- **Verified Publisher** on tarkvara tootja enda image, näiteks `grafana/grafana`.
- Märgita image'i võib üles laadida igaüks. Enne kasutamist vaata, kas lehel on link lähtekoodile ja millal image'it viimati uuendati.

Ava image'i `nginx` leht ja vaheleht **Tags**. Tag `latest` näitab alati uusimat versiooni, nii et sama käsk annab kuu aja pärast teise image'i. Seepärast on selles praktikumis igal image'il versioon nimes, näiteks `nginx:1.30-alpine`. Osa `alpine` tähendab, et image on tehtud väikese Alpine Linuxi peale.

Tõmba sama image lühikese nimega ja täisnimega. Siis vaata, mida image sisaldab.

```bash
docker pull nginx:1.30-alpine
docker pull docker.io/library/nginx:1.30-alpine
docker image ls nginx
docker image inspect nginx:1.30-alpine --format '{{.Config.ExposedPorts}} {{.Config.Cmd}}'   # port ja käivituskäsk
```

??? success "Oodatav tulemus"

    Teine `pull` vastab `Image is up to date`. See tähendab, et lühike nimi ja täisnimi on sama image. `inspect` näitab porti `80/tcp` ja käsku, millega Nginx käivitub.

Image'i lehel on kirjas ka see, mida image käivitamiseks vajab. Ava image'i [`mariadb`](https://hub.docker.com/_/mariadb) leht ja leia vastused allolevatele küsimustele. Neid läheb vaja 1.8-s, kui käivitad andmebaasi konteinerina.

??? question "Mida vajab MariaDB image?"

    1. Milline keskkonnamuutuja peab olema määratud, et konteiner käivituks?
    2. Millised muutujad loovad andmebaasi ja kasutaja?
    3. Millises kataloogis hoiab MariaDB andmeid?
    4. Millist porti server kuulab?

    ??? success "Vastus"

        1. Üks kolmest muutujast `MARIADB_ROOT_PASSWORD`, `MARIADB_ALLOW_EMPTY_ROOT_PASSWORD` või `MARIADB_RANDOM_ROOT_PASSWORD`. Ilma nendeta konteiner lõpetab töö kohe. Logi nimetab ka neljanda võimaluse, parooli räsi.
        2. `MARIADB_DATABASE`, `MARIADB_USER` ja `MARIADB_PASSWORD`.
        3. `/var/lib/mysql`.
        4. `3306`.

### 1.5 Harbor: kursuse registry

Kogu klass läheb internetti ühe kooli IP-aadressi kaudu. Docker Hub piirab, mitu image'it saab ühelt aadressilt tunnis tõmmata ([piirangud](https://docs.docker.com/docker-hub/usage/)), ja klassi peale saab see piir kiiresti täis. Seepärast on kursusel oma registry **Harbor**. See hoiab Docker Hubi image'ide koopiaid ja sinna saad panna ka oma image'id.

??? note "Tabel 3.1. Docker Hub ja Harbor"

    | | Docker Hub | Harbor |
    |---|---|---|
    | Asukoht | internetis, haldab Docker Inc. | laborivõrgus, kursuse VM |
    | Kes näeb | kõik | ainult kursus (VPN-iga) |
    | Sisu | ametlikud ja kasutajate image'id | sinu image'id ja Docker Hubi image'ite koopiad |
    | Tõmmete piir | piiratud tõmmete arv IP-aadressi kohta | piirangut pole |
    | Haavatavuste skänn | ainult tasulises paketis | Trivy skannib iga image'i |

**Usalda Harborit.** Harbori sertifikaadi on teinud kursuse oma sertifitseerimiskeskus (CA), mida Ubuntu ei tunne. Kopeeri CA fail Dockerile ja süsteemile ning kontrolli ühendust.

```bash
sudo mkdir -p /etc/docker/certs.d/harbor.lab.hkhk.lan
sudo cp roles/docker/files/harbor-ca.crt /etc/docker/certs.d/harbor.lab.hkhk.lan/ca.crt
sudo cp roles/docker/files/harbor-ca.crt /usr/local/share/ca-certificates/labori-ca.crt
sudo update-ca-certificates
curl -s https://harbor.lab.hkhk.lan/api/v2.0/ping; echo
```

**Tõmba image Harborist.** Docker Hubi image'id on Harboris projektis `dockerhub`. Nende nime ees on pikk eesliide, mille paned muutujasse `HUB`. Selle praktikumi käsud kasutavad seda muutujat.

```bash
echo 'export HUB=harbor.lab.hkhk.lan/dockerhub/library' >> ~/.bashrc
source ~/.bashrc
docker pull $HUB/nginx:1.30-alpine
docker image ls
```

**Logi sisse.** Sul on Harboris konto ja oma privaatne projekt. Mõlema nimi on sinu GitHubi kasutajanimi väikeste tähtedega ja parool on `Passw0rd`. Docker küsib parooli eraldi.

```bash
docker login harbor.lab.hkhk.lan -u <github-kasutaja>
```

Ava brauseris <https://harbor.lab.hkhk.lan> ja logi samade andmetega sisse. Lehel **Projects** on projekt `dockerhub`, kus on äsja tõmmatud `library/nginx`, ja sinu oma projekt. Oma projekti näevad ainult selle liikmed ja sinna paned 5. osas oma image'id.

??? success "Oodatav tulemus"

    `curl` vastab `Pong`. `docker image ls` näitab Nginxi kahe nimega, `nginx` ja `harbor.lab.hkhk.lan/dockerhub/library/nginx`, ja ID on mõlemal sama. `docker login` vastab `Login Succeeded`. Veebiliideses on projekt `dockerhub` koos image'iga `library/nginx` ja sinu tühi projekt.

??? warning "Kui `x509: certificate signed by unknown authority`"

    CA puudub kaustas `/etc/docker/certs.d/harbor.lab.hkhk.lan/` või kausta nimi ei ole täpselt registry nimi. Korda selle sammu kahte esimest käsku.

??? warning "Kui brauser hoiatab sertifikaadi eest"

    Brauser ei tunne kursuse CA-d. Brauseris võid hoiatuse kõrvale jätta või importida faili `roles/docker/files/harbor-ca.crt` oma arvutis usaldatud juursertifikaatide hulka (Windowsis topeltklõps, **Install Certificate**, **Local Machine**, **Trusted Root Certification Authorities**). Kui nimi `harbor.lab.hkhk.lan` sinu arvutis ei avane, kasuta aadressi <https://192.168.125.42>.

### 1.6 Käivita ja peata konteiner

1.3-s lõpetas konteiner `hello-world` kohe, sest selle programm prindib teate ja lõpetab. Veebiserver Nginx peab aga töötama pidevalt. Selles sammus käivitad Nginxi konteineri, peatad selle ja käivitad uuesti. Neid käske vajad iga konteineriga.

Konteiner töötab seni, kuni töötab selle peaprogramm. Linuxis on selle protsessi number 1 (PID 1). Kui programm lõpetab, peatub ka konteiner.

**Esiplaanil ja taustal.** Käivita Nginx esiplaanil. Terminal jääb siis Nginxi logi näitama. Lõpeta see klahvidega Ctrl+C.

```bash
docker run --name fg $HUB/nginx:1.30-alpine
```

Käivita teine Nginx taustal. Võti `-d` jätab terminali vabaks ja `-p 8081:80` suunab control'i pordi 8081 konteineri porti 80.

```bash
docker run -d --name veeb -p 8081:80 $HUB/nginx:1.30-alpine
docker ps -a
```

Peata konteiner ja käivita see uuesti.

```bash
docker stop veeb
docker start veeb
docker ps
```

??? success "Oodatav tulemus"

    `fg` on olekus `Exited`, sest Ctrl+C lõpetas Nginxi. `veeb` on pärast `start`-i jälle `Up` ja konteineri ID on sama. `stop` peatab programmi, aga konteiner ja selle failid jäävad alles.

**Konteiner, mis lõpetab kohe.** Käivita Ubuntu image ilma käsuta.

```bash
docker run $HUB/ubuntu:24.04
docker ps -a
```

Käivita sama image nüüd nii, et saad selle sees käske anda. Võti `-it` ühendab sinu terminali konteineriga.

```bash
docker run -it --rm $HUB/ubuntu:24.04 bash
```

Konteineris käivita `cat /proc/1/comm` ja `ps`, seejärel `exit`.

??? success "Oodatav tulemus"

    Esimene Ubuntu lõpetas kohe koodiga 0. Selle peaprogramm on käsurida `bash`, mis loeb käske terminalist. Ilma terminalita sisendit polnud, nii et `bash` lõpetas kohe. `-it`-ga on PID 1 `bash` ja konteiner töötab, kuni kirjutad `exit`.

### 1.7 Avaldatud port

Konteineril on oma võrguaadress, aga seda näeb ainult control. Sinu arvutist jõuad konteinerini ainult avaldatud pordi kaudu. `-p 8081:80` tähendab, et control'i port 8081 viib konteineri porti 80.

Proovi hostiporti kõigepealt control'is.

```bash
curl -sI http://localhost:8081 | head -1
```

Ava oma arvuti brauseris (VPN-iga) `http://<control IP>:8081`.

<figure markdown="span">
  ![Sülearvuti jõuab konteinerini veeb ainult control'i hostipordi 8081 kaudu; konteineri IP 172.17.0.x on nähtav ainult control'ist](assets/k03_l_pordid.svg)
  <figcaption>Joonis 3.2. Kust konteiner veeb vastab: hostiport on nähtav väljast, konteineri IP ainult hostist (Talvik, 2026).</figcaption>
</figure>

??? success "Oodatav tulemus"

    `curl` saab vastuseks `200 OK` ja brauser näitab Nginxi tervituslehte.

!!! warning "Avaldatud port on avatud kõigile"

    `-p 8081:80` avab pordi kõigile, kes control'ini jõuavad. Ubuntu tulemüür UFW seda ei peata, sest Docker lisab oma võrgureeglid UFW reeglitest mööda. Serveris avalda ainult need pordid, mida on tõesti vaja, ja kontrolli neid teisest masinast.

Eemalda katse konteinerid.

```bash
docker rm -f veeb fg
docker container prune -f
docker ps -a
```

### 1.8 Kolm teenust ühes võrgus

Rakendus Labori seis vajab kolme teenust: andmebaasi `db01`, vahemälu `mc01` ja sõnumijärjekorda `rmq01`. Rakendus leiab need nime järgi, sest konteineri IP-aadress muutub iga kord, kui konteiner uuesti luuakse. Docker leiab konteineri nime järgi ainult sinu enda loodud võrgus, mitte vaikevõrgus. Seepärast teed kõigepealt oma võrgu.

Tee võrk `labnet` ja käivita sinna MariaDB. Käsus on meelega üks viga.

```bash
docker network create labnet
docker run -d --name db01 --network labnet $HUB/mariadb:11.4
```

Vaata, kas konteiner töötab. Kui ei tööta, loe logist, miks.

```bash
docker ps -a
docker logs db01
```

??? success "Oodatav tulemus"

    `db01` on olekus `Exited (1)`. Logi viimastel ridadel on kirjas, et root'i parool puudub. See on kõige tavalisem käivitusviga, sest image vajab muutujat, mida käsus polnud. Kui konteiner ei tööta, vaata alati kõigepealt `docker ps -a` ja siis `docker logs`.

**Ülesanne.** Kustuta `db01` ja käivita see uuesti nii, et nõuded on täidetud. Muutujate nimed leidsid 1.4-s [image'i lehelt](https://hub.docker.com/_/mariadb).

- võrk `labnet`;
- `-e` võtmetega root'i parool, andmebaas `labseis`, kasutaja `labseis` ja tema parool;
- andmed nimega volume'is `dbtest` kataloogis `/var/lib/mysql`.

Lisa samasse võrku veel kaks teenust.

- `mc01` image'ist `memcached:1.6-alpine`;
- `rmq01` image'ist `rabbitmq:4.1-management-alpine`, hostinimi `rmq01` (`--hostname`), kasutaja ja parool muutujatest `RABBITMQ_DEFAULT_USER` ja `RABBITMQ_DEFAULT_PASS`.

??? example "Lahendus"

    ```bash
    docker rm -f db01
    docker run -d --name db01 --network labnet -v dbtest:/var/lib/mysql \
      -e MARIADB_ROOT_PASSWORD=Juur123 -e MARIADB_DATABASE=labseis \
      -e MARIADB_USER=labseis -e MARIADB_PASSWORD=Labseis123 $HUB/mariadb:11.4
    docker run -d --name mc01 --network labnet $HUB/memcached:1.6-alpine
    docker run -d --name rmq01 --network labnet --hostname rmq01 \
      -e RABBITMQ_DEFAULT_USER=labseis -e RABBITMQ_DEFAULT_PASS=Labseis123 $HUB/rabbitmq:4.1-management-alpine
    docker ps
    ```

Kontrolli, kas nimi `db01` leitakse. Esimene käsk küsib võrgust `labnet`, teine vaikevõrgust.

```bash
docker run --rm --network labnet $HUB/alpine:3.22 sh -c 'getent hosts db01; grep nameserver /etc/resolv.conf'
docker run --rm $HUB/alpine:3.22 getent hosts db01; echo "kood $?"
```

??? success "Oodatav tulemus"

    Kolm konteinerit on `Up`. Võrgus `labnet` annab `getent` nimele `db01` IP-aadressi ja nimeserver on `127.0.0.11`. See on Dockeri sisseehitatud nimeserver, mis töötab ainult ise loodud võrkudes. Vaikevõrgus nime ei leita ja kood on 2. Compose loob igale projektile oma võrgu, nii et 4. osas leiavad teenused üksteist nime järgi ilma lisatööta.

### 1.9 Andmed volume'is

Konteineri enda failid kaovad `docker rm`-iga. Andmebaas, mille andmed on konteineri sees, kaotab kõik andmed esimesel image'i uuendusel, sest uuendus tähendab alati uut konteinerit. Volume ja bind mount jäävad alles, aga käituvad õiguste poolest erinevalt.

**Volume.** Kirjuta `db01` andmebaasi tabel ühe reaga. MariaDB käivitub umbes 15 sekundit, nii et käsk ootab enne. Parool on `Labseis123`.

```bash
sleep 15
docker exec -it db01 mariadb -ulabseis -p labseis -e "CREATE TABLE proov (id INT); INSERT INTO proov VALUES (42);"
```

Kustuta konteiner ja käivita see uuesti sama käsuga nagu 1.8 lahenduses, sama volume'iga `dbtest`:

```bash
docker rm -f db01
docker run -d --name db01 --network labnet -v dbtest:/var/lib/mysql \
  -e MARIADB_ROOT_PASSWORD=Juur123 -e MARIADB_DATABASE=labseis \
  -e MARIADB_USER=labseis -e MARIADB_PASSWORD=Labseis123 $HUB/mariadb:11.4
```

Kontrolli, kas rida on alles, ja vaata, kus andmed hostis asuvad:

```bash
docker exec -it db01 mariadb -ulabseis -p labseis -e "SELECT * FROM proov;"
docker inspect -f '{{json .Mounts}}' db01 | jq
```

??? success "Oodatav tulemus"

    Rida `42` on alles. `Mounts` näitab tüüpi `volume` ja allikat `/var/lib/docker/volumes/dbtest/_data`: andmed on hostis Dockeri kataloogis, mitte konteineris.

??? warning "Kui tuleb `ERROR 2002` või `Access denied`"

    MariaDB käivitub umbes 15 sekundit. `ERROR 2002 … mysqld.sock` tähendab, et server pole veel valmis. Oota 15 sekundit ja proovi uuesti. Kui tuleb `Access denied`, kustutati konteiner enne, kui MariaDB jõudis andmebaasi luua. Siis alusta 1.8-st uuesti: `docker rm -f db01; docker volume rm dbtest`.

<figure markdown="span">
  ![Konteineri db01 kataloog /var/lib/mysql võib olla kirjutatavas kihis, nimega volume'is või bind mount'is; kirjutatav kiht kaob docker rm-iga, ülejäänud jäävad alles](assets/k03_l_andmed.svg)
  <figcaption>Joonis 3.3. Kolm kohta, kuhu konteineri andmed võivad sattuda (Talvik, 2026).</figcaption>
</figure>

Eemalda enne järgmist osa kõik katse konteinerid, volume ja võrgud:

```bash
docker rm -f db01 mc01 rmq01
docker volume rm dbtest
docker network rm labnet
docker ps -a
```

??? success "Oodatav tulemus"

    `docker ps -a` on tühi.

### 1.10 Commit

```bash
cd ~/kursus
git status --short
git push -u origin k03-docker
cd k03-docker
```

Selles osas tegid katseid käsurealt ja faile tavaliselt ei muutnud. Siis on `git status` tühi ja commit'i pole vaja. `git push` saadab haru `k03-docker` GitHubi.

??? note "Kui midagi ei tööta: osa 1"

    | Mida näed | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `permission denied … docker.sock` | `id`, `ls -l /var/run/docker.sock` | kasutaja pole grupis `docker` või sessioon on vana: logi välja ja sisse, VS Code'is käivita server uuesti | grupiliikmesus loetakse sisselogimisel; vana shell ja VS Code'i server töötavad vanade gruppidega edasi |
    | `docker: command not found` või `docker compose` puudub | `dpkg -l \| grep -E 'docker-ce\|compose'` | Docker pole paigaldatud ametlikust repositooriumist; paigalda `docker-ce … docker-compose-plugin`, mitte `docker.io` ega eraldi `docker-compose` | Ubuntu `docker.io` on vanem ja Compose'i plugin tuleb ainult Dockeri repositooriumist; vana `docker-compose` (v1) on eraldi programm |
    | apt: `Could not get lock` Dockerit paigaldades | `cloud-init status` | cloud-init paigaldab veel uuendusi: `cloud-init status --wait`, apt'ile `-o DPkg::Lock::Timeout=120` | uue VM-i esimestel minutitel käivitab cloud-init apt'i ja hoiab dpkg lukus |
    | `toomanyrequests: … pull rate limit` | `echo $HUB`, `grep HUB .env` | image tõmmati otse Docker Hubist: nimes peab olema `$HUB/` (Harbori vahemälu) | Docker Hub loeb anonüümseid tõmbeid IP kaupa ja kogu klass on ühe NAT-aadressi taga |
    | konteiner on kohe `Exited (0)` | `docker inspect -f '{{.Config.Cmd}}' <konteiner>` | PID 1 lõpetas: bash ilma terminalita (`-it` puudub) või teenus läks taustale | konteiner töötab täpselt nii kaua kui PID 1; kui teenus läheb taustale, lõpetab PID 1 |
    | `getent hosts db01` ei anna midagi, kood 2 | `docker inspect -f '{{json .NetworkSettings.Networks}}' db01 \| jq 'keys'` | konteiner on vaikevõrgus `bridge`, `--network labnet` jäi puudu | sisseehitatud DNS (`127.0.0.11`) töötab ainult kasutaja loodud võrkudes |
    | MariaDB `Exited (1)` kohe | `docker logs db01 \| tail -5` | root-parooli muutuja puudub (`MARIADB_ROOT_PASSWORD`) | entrypoint keeldub initsialiseerimast baasi, millel pole root-parooli määratud |
    | konteineri IP ei vasta sülearvutist | `docker port <konteiner>` | konteineri IP on ainult hostis: kasuta avaldatud porti | `docker0` sild on hosti sisevõrk ja väljast sinna marsruuti pole |

## Osa 2 · db ja web image

Nüüd teed rakenduse jaoks oma image'id. Alustad kahest lihtsamast, andmebaasist `db01` ja veebiserverist `web01`. Mõlemal juhul võtad aluseks ametliku image'i ja lisad sellele ainult rakenduse failid.

**Eesmärk:** image'id `labseis-db` ja `labseis-web` ehituvad sinu Dockerfile'idest.  
**Kontroll:** `docker image ls 'labseis-*'` näitab mõlemat image'it.  
**Kus:** control, kaust `~/kursus/k03-docker`.

Rakenduse failid `pom.xml`, `src/` ja `db/` on repositooriumi juures. Neid sa ei muuda, Dockerfile'id ainult kopeerivad neid.

```text
~/kursus/
├── .dockerignore                      ← 2.3
├── pom.xml  src/  db/                 ← rakendus, ei muuda
└── k03-docker/
    ├── db/Dockerfile                  ← 2.1
    ├── web/Dockerfile  web/nginx.conf ← 2.2
    ├── app/Dockerfile                 ← 3. osa
    └── compose.yaml  .env.example     ← 4. osa
```

### 2.1 Andmebaasi image

Selles sammus teed andmebaasi image'i. See on ametlik MariaDB, millesse lisad rakenduse tabelid ja näidisandmed. Kui sellest image'ist konteiner käivitada, on andmebaas kohe tabelitega valmis.

Tabelid ja andmed on repositooriumis kahes failis, `db/schema.sql` (tabelid) ja `db/seed.sql` (andmed). MariaDB image käivitab esimesel käivitusel ise kõik SQL-failid, mis on kaustas `/docker-entrypoint-initdb.d/`. Sinu Dockerfile peab need kaks faili sinna kopeerima.

Ava starteri fail `db/Dockerfile` ja täida TODO-read. Dockerfile'is on vaja kolme asja.

1. Aluseks võta image `mariadb:11.4`. Nime eesliide tuleb argumendist `HUB`, mille vaikeväärtus on `docker.io/library`.
2. Kopeeri `db/schema.sql` kausta `/docker-entrypoint-initdb.d/`.
3. Kopeeri sinna ka `db/seed.sql`. Tabelid peavad tekkima enne andmeid. MariaDB käivitab failid tähestiku järjekorras, nii et pane failinimede ette numbrid `01-` ja `02-`.

Dockerfile'i juhiste kohta loe [Dockerfile'i juhendist](https://docs.docker.com/reference/dockerfile/).

??? example "Lahendus: `k03-docker/db/Dockerfile`"

    ```dockerfile
    ARG HUB=docker.io/library
    FROM ${HUB}/mariadb:11.4
    COPY db/schema.sql /docker-entrypoint-initdb.d/01-schema.sql
    COPY db/seed.sql /docker-entrypoint-initdb.d/02-seed.sql
    ```

    `ARG` määrab muutuja, mida saab ehitamisel muuta. `FROM` ütleb, millise image'i peale ehitatakse. `COPY` kopeerib faili repositooriumist image'isse.

Ehita image ja proovi see käivitada. Käsu lõpus olev `..` on **ehituskontekst**, kaust, mille failid Docker ehitusele kaasa annab. Siin on see repositooriumi juur, sest Dockerfile kopeerib sealt kausta `db/`. `--build-arg HUB` võtab baasimage'i eesliite sinu muutujast `HUB`.

```bash
docker build --build-arg HUB -f db/Dockerfile -t labseis-db:test ..
docker run -d --name dbt -e MARIADB_ROOT_PASSWORD=x -e MARIADB_DATABASE=labseis labseis-db:test
sleep 20; docker exec dbt mariadb -uroot -px labseis -e "SHOW TABLES;"
docker rm -f dbt
```

Viimane käsk kustutab testkonteineri, sest seda edaspidi vaja pole.

??? success "Oodatav tulemus"

    `SHOW TABLES` näitab nelja tabelit `course`, `lab`, `result` ja `student`. See tähendab, et MariaDB käivitas mõlemad SQL-failid õiges järjekorras. Kui järjekord oleks vale, lõpetaks konteiner veaga `Table doesn't exist`, sest andmeid prooviti kirjutada tabelitesse, mida veel polnud.

??? warning "Kui tuleb viga `\"/db/schema.sql\": not found`"

    Docker ei leidnud faili, sest ehituskontekst oli vale. Kontrolli, et käsu viimane argument on `..` ja et käivitad käsu kaustas `~/kursus/k03-docker`.

### 2.2 Veebiserveri image

Selles sammus teed veebiserveri image'i. Veebiserver `web01` on rakenduse ees. Brauser pöördub `web01` poole ja Nginx saadab päringu edasi rakendusele `app01`. Sellist veebiserverit nimetatakse pöördproksiks (reverse proxy).

Nginxi konfiguratsioonifail `web/nginx.conf` on starteris valmis ja seda sa ei muuda. Sinu Dockerfile kopeerib selle Nginxi image'isse.

??? example "Fail `k03-docker/web/nginx.conf` (starteris)"

    ```nginx
    resolver ${NGINX_LOCAL_RESOLVERS} valid=10s ipv6=off;

    server {
        listen 80;

        location / {
            set $app_upstream http://app01:8080;
            proxy_pass $app_upstream;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    ```

Konfiguratsioonis on üks eripära. `app01` IP-aadress muutub iga kord, kui `app01` konteiner uuesti luuakse. Et Nginx leiaks rakenduse ka siis, küsib ta aadressi iga päringu juures uuesti Dockeri nimeserverilt. Nimeserveri aadressi kirjutab Nginxi image ise reale `resolver`, kui fail on kaustas `/etc/nginx/templates/` ja muutuja `NGINX_ENTRYPOINT_LOCAL_RESOLVERS` on `1`.

Ava starteri fail `web/Dockerfile` ja täida TODO-read. Dockerfile'is on vaja nelja asja.

1. Aluseks võta image `nginx:1.30-alpine`. Eesliide tuleb argumendist `HUB` nagu andmebaasi image'il.
2. Määra muutuja `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` juhisega `ENV`.
3. Kopeeri `nginx.conf` image'isse nimega `/etc/nginx/templates/default.conf.template`.
4. Lisa tervisekontroll juhisega `HEALTHCHECK`, mis küsib aadressi `http://127.0.0.1/health`. Alpine'i image'is pole `curl`-i, nii et kasuta `wget`-i.

??? example "Lahendus: `k03-docker/web/Dockerfile`"

    ```dockerfile
    ARG HUB=docker.io/library
    FROM ${HUB}/nginx:1.30-alpine
    ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1
    COPY nginx.conf /etc/nginx/templates/default.conf.template
    HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
      CMD wget -qO- http://127.0.0.1/health || exit 1
    ```

    `ENV` määrab muutuja, mis on konteineris olemas. `HEALTHCHECK` käivitab iga 10 sekundi järel kontrollkäsu. Kui see ebaõnnestub kolm korda järjest, märgib Docker konteineri olekuks `unhealthy`.

Ehita image. Siin on ehituskontekst kaust `web`, sest Dockerfile vajab ainult faili `web/nginx.conf`. Seejärel vaata, millise konfiguratsiooni Nginx failist tegi.

```bash
docker build --build-arg HUB -t labseis-web:test web
docker run --rm labseis-web:test nginx -T 2>/dev/null | grep -E '^ *(resolver|proxy_pass)'
```

??? success "Oodatav tulemus"

    Real `resolver` on `${NGINX_LOCAL_RESOLVERS}` asemel IP-aadress, näiteks kooli nimeserverite aadressid. See tähendab, et Nginxi image kirjutas nimeserveri aadressi faili. Rida `proxy_pass $app_upstream;` on alles. Kas veebiserver rakenduseni jõuab, näed 4. osas, kui `app01` töötab.

??? warning "Kui `resolver` real on endiselt `${NGINX_LOCAL_RESOLVERS}`"

    Rida `ENV` puudub või fail ei ole kaustas `/etc/nginx/templates/`. Kontrolli Dockerfile'i ja ehita image uuesti.

### 2.3 Hoia saladused image'ist väljas

Ehitamisel annab Docker ehituskonteksti failid, ehk kogu repositooriumi juure, builderile kaasa. Kui Dockerfile'is on kunagi rida `COPY . .`, satub image'isse kõik, ka paroolidega fail `.env`. Image'i võivad tõmmata teised ja nii jõuaks parool nendeni.

Selle vastu on fail [`.dockerignore`](https://docs.docker.com/build/concepts/context/). See ütleb, milliseid faile Docker ehitusele ei anna. Kõige kindlam on keelata kõik ja lubada ainult vajalikud failid. Loo repositooriumi juurde (`~/kursus/.dockerignore`) fail, mille esimene rida `*` keelab kõik ja järgmised `!` read lubavad tagasi `pom.xml`-i, `src`-i ja `db`.

??? example "Lahendus: `~/kursus/.dockerignore`"

    ```text
    *
    !pom.xml
    !src
    !db
    ```

    Docker loeb ridu ülevalt alla ja hilisem rida kirjutab varasema üle.

Kontrolli, et andmebaasi image ehitub endiselt, ja käivita automaatkontrolli failitest.

```bash
docker build -q --build-arg HUB -f db/Dockerfile -t labseis-db:test ..
(cd .. && bash autograde/check.sh k03 files)
```

??? success "Oodatav tulemus"

    Image ehitub. `k03 files` annab `OK` või kurdab ainult `app/Dockerfile`-i ja `compose.yaml`-i üle, mida sa pole veel teinud.

### 2.4 Salvesta GitHubi

```bash
(cd ~/kursus && git add .dockerignore k03-docker && git commit -m "k03: db ja web Dockerfile, .dockerignore" && git push)
git ls-files
```

`git ls-files` näitab, millised failid on Gitis. Automaatkontroll näeb ainult neid. Kui fail on ainult sinu kaustas, ei leia GitHub seda.

??? success "Oodatav tulemus"

    `git ls-files` näitab faile `db/Dockerfile`, `web/Dockerfile` ja `web/nginx.conf`.

??? note "Kui midagi ei tööta: osa 2"

    | Mida näed | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `"/db/schema.sql": not found` | build'i viimane argument, `.dockerignore` | kontekst pole repositooriumi juurkaust või lubamisnimekirjast puudub `!db` | `COPY` teed on alati konteksti suhtes, mitte Dockerfile'i asukoha suhtes |
    | `"/src": not found` | `cat .dockerignore` | lubamisnimekirjast puudub `!src` | `*` jätab kõik välja ja builder ei näe faile, mida pole tagasi lubatud |
    | muudetud `seed.sql` ei jõua baasi | `docker volume ls` | init-skriptid käivituvad ainult tühja volume'iga: katseandmetega `docker volume rm` või `docker compose down -v` (kustutab andmed; tootmisbaasis varukoopia enne või migratsioon) | entrypoint jätab `/docker-entrypoint-initdb.d/` vahele, kui `/var/lib/mysql` on juba initsialiseeritud |
    | `nginx -T` näitab `${NGINX_LOCAL_RESOLVERS}` muutmata kujul | `docker run --rm labseis-web:test ls /etc/nginx/templates` | `ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` puudub või fail pole `templates/` all | envsubst käsitleb ainult `templates/*.template` faile ja asendab ainult defineeritud muutujad |
    | web annab 502 ja logis `could not be resolved` | `docker network inspect <võrk>` | app01 pole samas võrgus või pole veel käivitunud | muutujaga `proxy_pass` lahendab nginx nime päringu ajal ja vastab 502-ga, kui nimi ei lahendu |
    | `k03 files`: `.dockerignore ei jäta .env faili välja` | `grep -n env .dockerignore` | denylist'is puudub `**/.env`; allowlist'iga (`*`) seda viga ei tule | ilma `**/` eesliiteta kehtib muster ainult konteksti juures, mitte `k03-docker/.env`-ile |

## Osa 3 · Rakenduse image

Rakendus on Java veebirakendus. Selle lähtekoodist teeb tööriist Maven faili `labori-seis.war` ja selle käivitab veebiserver Tomcat. Maveni on vaja ainult ehitamiseks, töötavasse image'isse seda vaja pole. Seepärast teed image'i kahes astmes.

**Eesmärk:** rakenduse image ehitub kahes astmes ja lõppimage'is pole Maveni ega lähtekoodi.  
**Kontroll:** `bash ../autograde/check.sh k03 multistage` annab `OK`.  
**Kus:** control, kaust `~/kursus/k03-docker`.

### 3.1 Kahes astmes Dockerfile

Esimene aste ehitab Maveniga WAR-faili. Teine aste võtab aluseks Tomcati ja kopeerib sinna esimesest astmest ainult WAR-faili. Kõik muu esimesest astmest jääb lõppimage'ist välja.

<figure markdown="span">
  ![Ehitusaste maven-image'iga teeb WAR-faili; käitusaste tomcat-image'iga saab ainult WAR-i COPY --from abil; lõppimage'is pole Maveni ega lähtekoodi](assets/k03_multistage.svg)
  <figcaption>Joonis 3.4. Mitmeastmeline ehitus: lõppimage'isse jõuab ainult WAR (Talvik, 2026).</figcaption>
</figure>

Ava starteri fail `app/Dockerfile`. TODO-read ütlevad, mis igasse kohta kirjutada. Abiks on [mitmeastmelise ehituse juhend](https://docs.docker.com/build/building/multi-stage/) ja lahendus, kus iga rida on lahti seletatud.

??? example "Lahendus: `app/Dockerfile`"

    ```dockerfile
    ARG HUB=docker.io/library

    # Esimene aste: Maven ehitab WAR-faili
    FROM ${HUB}/maven:3-eclipse-temurin-21 AS build
    WORKDIR /src
    COPY pom.xml .
    RUN mvn -B -q dependency:go-offline     # sõltuvused alla, enne koodi
    COPY src ./src
    RUN mvn -B -q package -DskipTests      # valmib target/labori-seis.war

    # Teine aste: Tomcat käivitab WAR-i
    FROM ${HUB}/tomcat:10.1-jre21-temurin
    COPY --from=build /src/target/labori-seis.war /usr/local/tomcat/webapps/ROOT.war
    EXPOSE 8080
    HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=3 \
      CMD curl -fsS http://localhost:8080/health || exit 1
    ARG GIT_SHA=unknown
    ENV GIT_SHA=${GIT_SHA}
    LABEL org.opencontainers.image.revision="${GIT_SHA}"
    CMD ["catalina.sh", "run"]
    ```

    `COPY --from=build` toob esimesest astmest ainult WAR-faili. `pom.xml` kopeeritakse enne koodi, et järgmisel ehitusel ei peaks sõltuvusi uuesti alla laadima, kui muutus ainult kood. Tomcat käivitub umbes minuti, seepärast on tervisekontrollil `--start-period=60s`. `GIT_SHA` jääb image'i sildiks ja näitab hiljem, millisest commit'ist image tehti.

Ehita image. Esimesel korral laadib Maven sõltuvused alla ja see võtab mõne minuti.

```bash
docker build --build-arg HUB -f app/Dockerfile --build-arg GIT_SHA=$(git rev-parse --short HEAD) -t labseis-app:multi ..
docker history labseis-app:multi | head -8
docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' labseis-app:multi
```

??? success "Oodatav tulemus"

    Ehitus lõpeb ilma veata. `history` ülemistes ridades on WAR-fail (umbes 30 MB) ja Maveni ridu pole. Sildis on sinu commit'i lühike SHA.

### 3.2 Salvesta GitHubi

Enne salvestamist käivita automaatkontrolli test, mis vaatab, kas Dockerfile on kahes astmes.

```bash
(cd .. && bash autograde/check.sh k03 multistage)
(cd ~/kursus && git add k03-docker && git commit -m "k03: mitmeastmeline app-image" && git push)
```

??? success "Oodatav tulemus"

    `multistage` annab `OK`. Test vaatab ainult Dockerfile'i ülesehitust. Kas rakendus töötab, näed 4. osas.

??? note "Kui midagi ei tööta: osa 3"

    | Mida näed | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `k03 tags` FAIL app-image'i järel | `ls k03-docker/compose.yaml` | test vajab ka `compose.yaml`-i, mis tekib Compose'i lehel | test loeb ametlike image'ite tag'id Compose'i failist |

## Osa 4 · Kogu stack Compose'iga

Selles osas paned kogu rakenduse tööle. Rakendusel on viis teenust ja need kirjeldad ühes failis `compose.yaml`. Siis käivitab üks käsk `docker compose up -d` kõik teenused korraga. 1. osas tegid sama pikkade `docker run` käskudega, nüüd on kõik failis kirjas ja Gitis alles.

**Eesmärk:** viis teenust käivituvad ühe käsuga ja rakendus vastab brauseris.  
**Kontroll:** `curl -s localhost:8080/health` näitab nelja `UP`-i ning testid `compose` ja `deps` annavad `OK`.  
**Kus:** control, kaust `~/kursus/k03-docker`.

<figure markdown="span">
  ![Brauser pöördub pordil 8080 web01 poole, web01 app01 poole, app01 db01, mc01 ja rmq01 poole; kõik on projekti võrgus labori-seis_default](assets/k03_compose_stack.svg)
  <figcaption>Joonis 3.5. Labori seis Compose'i stackina (Talvik, 2026).</figcaption>
</figure>

Brauser pöördub veebiserveri `web01` poole, see saadab päringu rakendusele `app01` ja rakendus kasutab andmebaasi, vahemälu ja sõnumijärjekorda. Teenuste andmed on tabelis 3.2, seda vajad järgmistes sammudes.

??? note "Tabel 3.2. Stacki teenused"

    | Teenus | Image | Hostis avatud | Healthcheck |
    |---|---|---|---|
    | db01 | sinu `db/Dockerfile`, kontekst `..` | ei | `healthcheck.sh --connect --innodb_initialized` |
    | mc01 | `memcached:1.6-alpine` | ei | `echo stats \| nc -w 1 127.0.0.1 11211 \| grep -q uptime` |
    | rmq01 | `rabbitmq:4.1-management-alpine` | 15672 (halduse UI) | `rabbitmq-diagnostics -q ping` |
    | app01 | sinu `app/Dockerfile`, kontekst `..` | ei | Dockerfile'ist |
    | web01 | sinu `web/`, kontekst `./web` | `${WEB_PORT:-8080}:80` | Dockerfile'ist |

Starteri `compose.yaml`-is on teenused ette antud TODO-ridade ja kommentaaridena. Täidad need ühe kaupa ja käivitad iga teenuse kohe, et näha, kas see töötab ([Compose'i faili juhend](https://docs.docker.com/reference/compose-file/services/)).

### 4.1 Paroolid failis `.env`

Andmebaas vajab paroole. Neid ei kirjutata `compose.yaml`-i, sest see fail on Gitis ja paroole näeks igaüks. Paroolid lähevad faili `.env`, mida Git ei salvesta.

Starteris on näidisfail `.env.example`. Tee sellest oma koopia ja ava see redaktoris.

```bash
cp .env.example .env
chmod 600 .env
nano .env
```

Muuda failis kolme asja. Salvesta klahvidega Ctrl+O ja Enter ning sulge Ctrl+X-ga.

1. Igal real, kus on `muuda-mind`, kirjuta selle asemele oma parool. Näiteks `DB_PASSWORD=muuda-mind` asemel `DB_PASSWORD=Labseis123`.
2. Rida `HUB=docker.io/library` muuda kujule `HUB=harbor.lab.hkhk.lan/dockerhub/library`. Siis tulevad image'id Harborist nagu 1. osas.
3. Rida `OWNER=sinu-github-kasutaja` muuda nii, et seal on sinu GitHubi kasutajanimi väikeste tähtedega, näiteks `OWNER=maasikas`.

??? example "Lahendus: valmis `.env`"

    ```bash
    DB_PASSWORD=Labseis123
    DB_ROOT_PASSWORD=Juur123
    RABBITMQ_PASSWORD=Jarjekord123
    TEACHER_TOKEN=opetaja123
    HUB=harbor.lab.hkhk.lan/dockerhub/library
    REGISTRY=harbor.lab.hkhk.lan
    OWNER=maasikas
    TAG=dev
    WEB_PORT=8080
    ```

    `maasikas` asemel on sinu GitHubi kasutajanimi. Paroolid võivad olla sinu omad, aga sama parooli peab hiljem kasutama ka sisselogimisel.

Kontrolli, et Git jätab faili välja.

```bash
git check-ignore -v .env
```

??? success "Oodatav tulemus"

    `git check-ignore` näitab rida failist `.gitignore`, mis jätab `.env`-i välja. `git status` seda faili ei näita.

??? info "Mis on `.env` ja miks mitte Vault?"

    `.env` on lihtne tekstifail, kus igal real on üks muutuja kujul `NIMI=väärtus`. Compose loeb selle ise, kui fail on samas kaustas kui `compose.yaml`. Failis `compose.yaml` on parooli asemel `${DB_PASSWORD}` ja Compose paneb käivitamisel sinna `.env`-is oleva väärtuse. Nii on `compose.yaml` Gitis ilma paroolideta.

    `.env.example` on Gitis ja näitab teistele, milliseid muutujaid on vaja. Automaatkontroll kasutab just seda faili. Seal on `HUB=docker.io/library`, sest GitHubi automaatkontroll Harborini ei ulatu.

    Kui sama muutuja on määratud ka shellis, kehtib shelli väärtus ja `.env`-i rida ei mõju. Kontrolli seda käsuga `printenv HUB`.

    Teisel kohtumisel hoidsid samu paroole Ansible Vaultis. Vault on krüpteeritud ja selle võib Gitti panna, `.env` on tavaline tekst ja peab Gitist välja jääma. Compose Ansible Vaulti lugeda ei oska. Kodutöös teeb Ansible `.env`-i Vaulti paroolidest.

??? tip "Tootmises: paroolid OpenBaost"

    `.env` sobib arenduseks ja laboriks, aga parool on seal avatekstina kettal. Tootmises hoitakse paroolid saladuste hoidlas, näiteks HashiCorp Vaultis või selle vabas harus OpenBao. Paroolid tuuakse sealt alles käivitamise ajal ja kettale neid ei jää. Kursusel on OpenBao aadressil <https://openbao.lab.hkhk.lan:8200> ja sul on seal konto. Kasutajanimi on sinu GitHubi kasutajanimi ja parool `Passw0rd`. Sa näed seal ainult oma teed `kv/<kasutaja>/`.

    Paigalda OpenBao käsurea tööriist `bao`, kui seda veel pole, ja logi sisse.

    ```bash
    command -v bao || (cd /tmp && curl -fsSLO https://github.com/openbao/openbao/releases/download/v2.7.1/openbao_2.7.1_linux_amd64.deb && sudo apt install -y ./openbao_2.7.1_linux_amd64.deb)
    export BAO_ADDR=https://openbao.lab.hkhk.lan:8200
    bao login -method=userpass username=<github-kasutaja>
    ```

    Pane paroolid OpenBaosse. Kasuta samu paroole, mis on sinu `.env`-is, muidu ei pääse rakendus olemasolevasse andmebaasi.

    ```bash
    bao kv put -mount=kv <github-kasutaja>/k03 DB_PASSWORD=… DB_ROOT_PASSWORD=… RABBITMQ_PASSWORD=… TEACHER_TOKEN=…
    ```

    Käivitamisel loe paroolid OpenBaost ajutisse faili, anna see Compose'ile ja kustuta fail kohe. Teine `--env-file` kirjutab `.env`-i paroolid üle.

    ```bash
    (umask 077; bao kv get -mount=kv -format=json <github-kasutaja>/k03 | jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"' > /tmp/paroolid.env)
    docker compose --env-file .env --env-file /tmp/paroolid.env up -d
    rm /tmp/paroolid.env
    ```

    OpenBao veebiliideses näed oma saladust teel `kv/<github-kasutaja>/k03`. OpenBao kirjutab iga päringu auditilogisse, nii et on näha, kes millal parooli luges.

### 4.2 Andmebaas Compose'iga

Selles sammus kirjeldad andmebaasi `db01` failis `compose.yaml`. See on sama andmebaas, mille käivitasid 1.8-s käsuga `docker run`. Nüüd on iga seade failis oma real.

Ava fail redaktoris.

```bash
nano compose.yaml
```

Failis on rida `db01:` ja selle all `# TODO 4.2: …`. Kustuta TODO-rida ja kirjuta `db01:` alla järgmised osad. Iga rida algab kaks tühikut paremal kui `db01:`, rea algusest seega neli tühikut. YAML-is näitavad taanded, mis kuhu kuulub, ja koodinäidetes on taanded juba õiged.

1. **Kust image tuleb.** Compose ehitab image'i sinu 2.1 Dockerfile'ist. `context: ..` on sama ehituskontekst, mis 2.1-s.

    ??? example "Näita koodi"

        ```yaml
            build:
              context: ..
              dockerfile: k03-docker/db/Dockerfile
              args:
                HUB: ${HUB:-docker.io/library}
        ```

2. **Image'i nimi.** Selle nimega läheb image 5. osas Harborisse. Väärtused tulevad `.env`-ist.

    ??? example "Näita koodi"

        ```yaml
            image: ${REGISTRY:?}/${OWNER:?}/labori-seis-db:${TAG:-dev}
        ```

3. **Muutujad.** Samad, mis 1.8-s võtmega `-e`, aga paroolid tulevad `.env`-ist.

    ??? example "Näita koodi"

        ```yaml
            environment:
              MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:?}
              MARIADB_DATABASE: labseis
              MARIADB_USER: labseis
              MARIADB_PASSWORD: ${DB_PASSWORD:?}
        ```

4. **Andmed volume'is.** Sama, mis 1.8-s võti `-v`. Volume `dbdata` on faili lõpus juba olemas.

    ??? example "Näita koodi"

        ```yaml
            volumes:
              - dbdata:/var/lib/mysql
        ```

5. **Tervisekontroll.** Compose kontrollib iga 10 sekundi järel, kas andmebaas vastab. Teised teenused ootavad seda.

    ??? example "Näita koodi"

        ```yaml
            healthcheck:
              test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
              interval: 10s
              retries: 10
        ```

Salvesta klahvidega Ctrl+O ja Enter ning sulge Ctrl+X-ga. Kontrolli, kas fail on korras.

```bash
docker compose config -q && echo OK
```

Kui tuleb viga, on tõenäoliselt mõni taane vale. Võrdle oma faili tervikuga.

??? example "Lahendus: `db01` tervikuna"

    ```yaml
    services:
      db01:
        build:
          context: ..
          dockerfile: k03-docker/db/Dockerfile
          args:
            HUB: ${HUB:-docker.io/library}
        image: ${REGISTRY:?}/${OWNER:?}/labori-seis-db:${TAG:-dev}
        environment:
          MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:?}
          MARIADB_DATABASE: labseis
          MARIADB_USER: labseis
          MARIADB_PASSWORD: ${DB_PASSWORD:?}
        volumes:
          - dbdata:/var/lib/mysql
        healthcheck:
          test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
          interval: 10s
          retries: 10
    ```

Käivita andmebaas ja vaata selle olekut.

```bash
docker compose up -d --build db01
sleep 25; docker compose ps
```

??? success "Oodatav tulemus"

    `db01` on olekus `Up (healthy)`. `Up` tähendab, et konteiner töötab. `(healthy)` tähendab lisaks, et tervisekontroll õnnestus ja MariaDB võtab ühendusi vastu. Teised teenused ootavad just seda olekut.

??? warning "Kui tuleb viga `required variable DB_ROOT_PASSWORD is missing`"

    Fail `.env` puudub või käivitasid käsu vales kaustas. Käsk peab olema kaustas `~/kursus/k03-docker`.

### 4.3 Vahemälu ja sõnumijärjekord

Selles sammus lisad vahemälu `mc01` ja sõnumijärjekorra `rmq01`. Need on samad teenused, mille käivitasid 1.8-s. Mõlemad tulevad otse ametlikest image'itest, nii et Dockerfile'i pole vaja.

Ava `compose.yaml`. Teenused `mc01` ja `rmq01` on seal praegu kommentaarina, iga rea alguses on märk `#`. Kustuta need neli rida ja kirjuta nende asemele järgmised osad. Taane on sama nagu `db01`-l.

1. **Vahemälu `mc01`.** Image tuleb Harbori vahemälust. Porti välja ei avata, sest teenust kasutab ainult rakendus.

    ??? example "Näita koodi"

        ```yaml
          mc01:
            image: ${HUB:-docker.io/library}/memcached:1.6-alpine
            healthcheck:
              test: ["CMD-SHELL", "echo stats | nc -w 1 127.0.0.1 11211 | grep -q uptime"]
              interval: 10s
              retries: 5
        ```

    Tervisekontrollis on toru `|`. Sellise käsu jaoks on vaja kuju `CMD-SHELL`.

2. **Sõnumijärjekord `rmq01`, image ja nimi.** Hostinimi `rmq01` on vajalik, sest RabbitMQ seob oma andmed hostinimega.

    ??? example "Näita koodi"

        ```yaml
          rmq01:
            image: ${HUB:-docker.io/library}/rabbitmq:4.1-management-alpine
            hostname: rmq01
        ```

3. **Kasutaja ja parool.** Samad muutujad nagu 1.8-s, parool tuleb `.env`-ist.

    ??? example "Näita koodi"

        ```yaml
            environment:
              RABBITMQ_DEFAULT_USER: labseis
              RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:?}
        ```

4. **Halduse leht ja andmed.** Port `15672` avab RabbitMQ halduse lehe brauseris. Andmed lähevad volume'isse `rmqdata`, mis on faili lõpus juba olemas.

    ??? example "Näita koodi"

        ```yaml
            ports:
              - "15672:15672"
            volumes:
              - rmqdata:/var/lib/rabbitmq
        ```

5. **Tervisekontroll.**

    ??? example "Näita koodi"

        ```yaml
            healthcheck:
              test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
              interval: 10s
              retries: 10
        ```

Salvesta, kontrolli faili käsuga `docker compose config -q && echo OK` ja käivita mõlemad teenused.

```bash
docker compose up -d mc01 rmq01
sleep 30; docker compose ps
```

Ava brauseris `http://<control IP>:15672` ja logi sisse kasutajaga `labseis`. Parool on see, mille panid `.env`-is reale `RABBITMQ_PASSWORD`.

<figure markdown="span">
  ![RabbitMQ halduse UI Overview leht, node rabbit@rmq01 töötab](assets/k03_rabbitmq_overview.png)
  <figcaption>Joonis 3.6. RabbitMQ haldus: node'i nimi on `rabbit@rmq01`, sest hostinimi on fikseeritud (Talvik, 2026).</figcaption>
</figure>

??? success "Oodatav tulemus"

    Kolm teenust on `(healthy)` ja halduse leht näitab nime `rabbit@rmq01`. Nimi tuleb hostinimest `rmq01`. Ilma selleta saaks iga uus konteiner juhusliku nime ja RabbitMQ ei kasutaks enam volume'is olevaid andmeid.

### 4.4 Rakendus

Nüüd lisad rakenduse `app01`. Rakendus vajab kõiki kolme teenust, nii et see tohib käivituda alles siis, kui need on valmis.

Ava `compose.yaml`. Kustuta kommentaariread `# app01:` ja selle all olev TODO-rida ning kirjuta nende asemele järgmised osad.

1. **Kust image tuleb.** Compose ehitab image'i sinu 3.1 Dockerfile'ist. `GIT_SHA` paneb image'i sildiks versiooni `.env`-ist.

    ??? example "Näita koodi"

        ```yaml
          app01:
            build:
              context: ..
              dockerfile: k03-docker/app/Dockerfile
              args:
                HUB: ${HUB:-docker.io/library}
                GIT_SHA: ${TAG:-dev}
        ```

2. **Image'i nimi.** Sama kuju nagu andmebaasil.

    ??? example "Näita koodi"

        ```yaml
            image: ${APP_IMAGE:-${REGISTRY:?}/${OWNER:?}/labori-seis-app:${TAG:-dev}}
        ```

3. **Paroolid.** Rakendus vajab andmebaasi ja järjekorra paroole ning õpetaja vaate tokenit. Teenuste nimed `db01`, `mc01` ja `rmq01` teab rakendus ise.

    ??? example "Näita koodi"

        ```yaml
            environment:
              DB_PASSWORD: ${DB_PASSWORD:?}
              RABBITMQ_PASSWORD: ${RABBITMQ_PASSWORD:?}
              TEACHER_TOKEN: ${TEACHER_TOKEN:?}
        ```

4. **Oota teisi teenuseid.** `depends_on` ütleb, et `app01` käivitub alles siis, kui kõik kolm teenust on olekus `healthy`.

    ??? example "Näita koodi"

        ```yaml
            depends_on:
              db01:
                condition: service_healthy
              mc01:
                condition: service_healthy
              rmq01:
                condition: service_healthy
        ```

Salvesta ja kontrolli faili käsuga `docker compose config -q && echo OK`.

Käivita rakendus. `--wait` ootab kuni 3 minutit, et rakendus jõuaks olekusse `healthy`.

```bash
docker compose up -d --build --wait --wait-timeout 180 app01
docker compose exec app01 curl -s localhost:8080/health; echo
```

??? success "Oodatav tulemus"

    `/health` vastab `{"status":"UP","db":"UP","queue":"UP","cache":"UP"}`. Neli `UP`-i tähendavad, et rakendus jõudis andmebaasi, sõnumijärjekorra ja vahemäluni. Kui `--wait` lõpetab veaga, vaata logi käsuga `docker compose logs app01`.

??? warning "Kui `db` on `DOWN` ja logis on `Access denied`"

    Andmebaas loodi varem teise parooliga. MariaDB võtab parooli `.env`-ist ainult esimesel käivitusel, kui andmekataloog on tühi. Siin on andmebaasis ainult näidisandmed, nii et võid selle kustutada ja uuesti luua käsuga `docker compose down -v`. See kustutab ka andmed. Tõelise andmebaasi puhul muudetakse parool andmebaasis endas.

### 4.5 Veebiserver ja automaatne taaskäivitus

Viimasena lisad veebiserveri `web01`. See on ainus teenus, mille poole brauser pöördub.

Ava `compose.yaml`. Kustuta kommentaariread `# web01:` ja selle all olev TODO-rida ning kirjuta nende asemele järgmised osad.

1. **Kust image tuleb.** Compose ehitab image'i sinu 2.2 Dockerfile'ist. Ehituskontekst on kaust `web`.

    ??? example "Näita koodi"

        ```yaml
          web01:
            build:
              context: ./web
              args:
                HUB: ${HUB:-docker.io/library}
            image: ${REGISTRY:?}/${OWNER:?}/labori-seis-web:${TAG:-dev}
        ```

2. **Port ja ootamine.** Control'i port 8080 viib veebiserverisse. Veebiserver käivitub alles siis, kui rakendus on valmis.

    ??? example "Näita koodi"

        ```yaml
            ports:
              - "${WEB_PORT:-8080}:80"
            depends_on:
              app01:
                condition: service_healthy
        ```

3. **Automaatne taaskäivitus.** Kui server taaskäivitub, peavad kõik teenused ise uuesti käivituma. Lisa **igale viiele teenusele** teenuse nime alla rida `restart: unless-stopped`.

    ??? example "Näita koodi"

        ```yaml
          db01:
            restart: unless-stopped
            build:
              ...
        ```

Salvesta ja käivita kõik viis teenust. `docker compose ps` näitab teenuste olekut. `curl` küsib rakenduselt veebiserveri kaudu tervist ja versiooni.

```bash
docker compose up -d --build --wait
docker compose ps
curl -s http://localhost:8080/health; echo
curl -s http://localhost:8080/version; echo
```

Ava brauseris `http://<control IP>:8080/s/demo-kati-token`. See on näidisõppija vaade. Õpetaja vaade on `/?token=<TEACHER_TOKEN>`, kus token on sinu `.env`-ist.

<figure markdown="span">
  ![Labori seisu avaleht brauseris pordil 8080](assets/k03_labori_seis_avaleht.png)
  <figcaption>Joonis 3.7. Labori seis Compose'i stackist web01 kaudu (Talvik, 2026).</figcaption>
</figure>

??? success "Oodatav tulemus"

    Viis teenust on `(healthy)`, `/health` näitab nelja `UP`-i ja `/version` näitab sinu `TAG`-i. Brauseris avaneb Labori seis.

??? warning "Kui tuleb viga `port is already allocated`"

    Port 8080 on juba kasutusel. Vaata käsuga `ss -tlnp | grep 8080`, mis seda kasutab, või vali `.env`-is teine `WEB_PORT`.

### 4.6 Salvesta GitHubi

Enne salvestamist käivita kolm automaatkontrolli testi, mis vaatavad faili `compose.yaml`. Testid kasutavad paroolide asemel `.env.example`-i, sest sinu `.env` GitHubi ei jõua.

```bash
cd ~/kursus
bash autograde/check.sh k03 compose
bash autograde/check.sh k03 deps
bash autograde/check.sh k03 tags
```

??? success "Oodatav tulemus"

    Iga test prindib `OK`. Kui test annab vea, ütleb see, mis puudu on, näiteks `restart-poliitika puudub` või `teenus web01 puudub`. Paranda `compose.yaml` ja käivita test uuesti.

Salvesta muudatused GitHubi ja mine tagasi kausta `k03-docker`.

```bash
git status --short
git add k03-docker
git commit -m "k03: kogu stack Compose'iga"
git push
cd k03-docker
```

??? success "Oodatav tulemus"

    `git status` näitab muudetud faili `k03-docker/compose.yaml`, aga mitte `.env`-i, sest see jääb Gitist välja. `git push` saadab muudatuse GitHubi.

??? note "Kui midagi ei tööta: osa 4"

    | Mida näed | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `required variable DB_ROOT_PASSWORD is missing` | `pwd`, `ls -la .env` | `.env` puudub või käsk ei tööta kaustas `k03-docker/` | Compose otsib `.env`-i projekti kaustast ja `${VAR:?}` katkestab, kui väärtust pole |
    | `port is already allocated` | `ss -tlnp \| grep 8080` | port on kasutusel (vana konteiner, varem paigaldatud teenus): muuda `WEB_PORT`-i või peata porti kasutav teenus | üks hostiport saab olla seotud ainult ühe kuulajaga |
    | app01 jääb olekusse `starting` või `unhealthy` | `docker compose exec app01 curl -s localhost:8080/health`, `docker compose logs app01` | db või rmq ei vasta, vale parool | `/health` on DOWN, kui ükski sõltuvus ei vasta, ja healthcheck kordab seda |
    | db `Access denied` pärast parooli muutmist | `docker volume ls \| grep dbdata` | volume initsialiseeriti vana parooliga: katseandmetega `docker compose down -v` (kaotab andmed; tootmisbaasis varukoopia enne või parooli muutmine baasis) | parool kirjutati baasi esimesel käivitusel; muutuja muutmine hiljem kasutajat ei muuda |
    | web01 annab 502 | `docker compose ps`, `nginx -T \| grep -E 'resolver\|proxy_pass'` | app01 pole valmis või nginx kasutab vana IP-d (`resolver` ja `proxy_pass $app_upstream`) | staatiline upstream jääb vanale IP-le, kui app01 luuakse uuesti |
    | RabbitMQ halduses on järjekorrad pärast konteineri uuesti loomist tühjad | `docker compose exec rmq01 hostname` | `hostname: rmq01` puudub: node'i nimi muutus | RabbitMQ andmekataloog on node'i nime järgi ja uus nimi tähendab uut, tühja node'i |
    | `k03 deps`: `restart-poliitika puudub` | `docker compose config \| grep restart` | `restart: unless-stopped` puudub mõnel teenusel | restart-poliitika on iga teenuse oma seade |
    | `k03 deps`: `port on hostis avatud` | `docker compose config \| grep -B3 published` | app01, db01 või mc01 all on `ports:` | test nõuab, et väljast oleks nähtav ainult web01 |
    | healthcheck toruga ei tööta | `docker inspect -f '{{json .State.Health.Log}}' <k>` | `CMD` kuju ei käivita shelli: kasuta `CMD-SHELL` | `CMD` käivitab programmi otse ja `\|` läheb talle argumendina |

## Osa 5 · Harbor

Siiani olid sinu image'id ainult control'is. Selles osas paned need Harborisse. Siis saab sama image'i tõmmata iga masin, mis Harborini jõuab, ja seda ei pea igal pool uuesti ehitama. Harbor kontrollib iga image'i ka turvaaukude suhtes.

**Eesmärk:** kolm image'it on sinu Harbori projektis ja stack käivitub Harborist tõmmatud image'itest.  
**Kontroll:** Harbori veebiliideses on sinu projektis kolm repositooriumi.  
**Kus:** control, kaust `~/kursus/k03-docker`.

<figure markdown="span">
  ![Control tõmbab Docker Hubi image'id Harbori proxy cache'i kaudu, lükkab oma image'id Harbori projekti, kus Trivy need skannib; sealt tõmbavad mc01 ja db01 Podmaniga, 5. kohtumise konveier ja 7. kohtumise k3s](assets/k03_image_teekond.svg)
  <figcaption>Joonis 3.8. Image'i teekond: Docker Hub, Harbori vahemälu, sinu projekt ja kasutajad (Talvik, 2026).</figcaption>
</figure>

### 5.1 Lükka image'id Harborisse

Image'i nime lõpus on tag ehk silt, näiteks `labori-seis-app:dev`. Silt `dev` ei ütle, mis kood image'is on. Seepärast paned sildiks commit'i lühikese SHA. Siis on iga image'i juures näha, millisest koodist see tehti.

Kontrolli kõigepealt, et kõik failid on commit'itud. Kui `git status` näitab muudatusi, tee enne commit. Seejärel pane SHA `.env`-i, ehita image'id ja lükka need Harborisse.

```bash
git status --short
TAG=$(git rev-parse --short HEAD) && sed -i "s/^TAG=.*/TAG=$TAG/" .env
grep -E '^(REGISTRY|OWNER|TAG)=' .env
docker compose build
docker compose push
```

Ava Harboris oma projekt ja vali **Repositories**. Klõpsa repositooriumil `labori-seis-app` ja seejärel image'i real. Veerg **Vulnerabilities** näitab, mitu turvaauku Trivy image'ist leidis.

<figure markdown="span">
  ![Harbori projekti Repositories vaade kolme repositooriumiga labori-seis-app, labori-seis-db ja labori-seis-web](assets/k03_harbor_repositories.png)
  <figcaption>Joonis 3.9. Kolm image'it sinu Harbori projektis (Talvik, 2026).</figcaption>
</figure>

??? success "Oodatav tulemus"

    `grep` näitab sinu Harbori aadressi, kasutajanime ja SHA-d. `push` lõpeb ilma veata. Harboris on kolm repositooriumi `labori-seis-app`, `labori-seis-db` ja `labori-seis-web`, igaühel silt sinu SHA-ga.

??? warning "Kui tuleb viga `denied: requested access to the resource is denied`"

    `.env`-is on `OWNER` vale või logisid 1.5-s sisse teise kasutajana. Mõlemad peavad olema sinu GitHubi kasutajanimi väikeste tähtedega.

??? warning "Kui tuleb viga `x509: certificate signed by unknown authority`"

    Docker ei usalda Harbori sertifikaati. Korda 1.5 sertifikaadi käske.

??? note "Kui Harbor ei vasta: GHCR"

    GitHubi registry GHCR sobib samaks tööks. Loo GitHubis **Settings → Developer settings → Personal access tokens → Tokens (classic)** token õigusega `write:packages` ([juhend](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)).

    ```bash
    sed -i -e 's/^REGISTRY=.*/REGISTRY=ghcr.io/' .env
    docker login ghcr.io -u <github-kasutaja>        # parooliks token
    docker compose build && docker compose push
    ```

    Pakett on vaikimisi privaatne. GitHubis näed seda profiili all **Packages**. Trivy skannimise saad siis teha käsurealt ([IS2, osa 3](https://hkhk-tk.github.io/is2-automatiseerimine/k03/syvenemine/)).

### 5.2 Käivita stack Harborist

Kontrolli, et stack töötab ka siis, kui image'id tulevad Harborist, mitte sinu masinast. Kustuta oma image'id control'ist, tõmba need Harborist ja käivita stack uuesti.

```bash
docker compose down
docker image rm $(docker compose config --images | grep labori-seis-)
docker compose pull
docker compose up -d --no-build --wait
curl -s http://localhost:8080/version; echo
```

??? success "Oodatav tulemus"

    `pull` tõmbab kõik viis image'it Harborist, sinu kolm ja kaks ametlikku. Stack käivitub ilma ehitamata. `/version` näitab sama SHA-d, mis on image'i sildis. Andmebaasi andmed on alles, sest `down` ilma `-v`-ta neid ei kustuta.

??? warning "Kui tuleb viga `current image with … vulnerabilities cannot be pulled`"

    Sinu projekti seadetes on haavatavate image'ide tõmbamise keeld sees. Lülita see projekti **Configuration** all välja.

### 5.3 Kontrolli haru

Selles osas muutus ainult `.env`, mis jääb Gitist välja. Uut commit'i pole vaja.

```bash
git status --short
git push
```

??? success "Oodatav tulemus"

    `git status` on tühi ja `git push` vastab `Everything up-to-date`.

## Osa 6 · Kontrolli ja esita

Enne esitamist käivita kõik kuus automaatkontrolli testi korraga. Neid samu teste käivitab GitHub pärast esitamist. Test `build` ehitab kõik kolm image'it ja võtab kõige rohkem aega.

```bash
cd ~/kursus
for t in files compose deps multistage tags build; do bash autograde/check.sh k03 $t; done
```

??? success "Oodatav tulemus"

    Kuus rida `OK`. Kui mõni test annab vea, ütleb see, mis puudu on. Paranda fail ja käivita testid uuesti.

Saada töö GitHubi ja pane sellele silt (tag) `k03`. Kui silt jõuab GitHubi, käivitab automaatkontroll testid ja tulemuse näed mõne minuti pärast Classroom 50-s.

```bash
git status --short
git push
git tag k03
git push origin k03
```

Kui `git status` näitab veel muudatusi, salvesta need enne käskudega `git add .dockerignore k03-docker` ja `git commit -m "k03: valmis"`. `git status` ei tohi näidata faili `.env`.

??? warning "Kui parandad tööd pärast esitamist"

    Silt osutab endiselt vanale commit'ile. Pärast parandust ja `git push`-i tõsta silt uuele commit'ile:

    ```bash
    git tag -f k03
    git push -f origin k03
    ```

??? info "Pull request harusse `main`"

    Töökohas ei lähe muudatus otse põhiharusse. Kõigepealt tehakse pull request, keegi vaatab muudatused üle ja alles siis ühendatakse need harusse `main`. Kui tahad seda proovida, ava oma repositoorium GitHubis, vajuta **Compare & pull request** ja seejärel **Merge pull request**. Hindamiseks seda vaja ei ole.

??? note "Kui midagi ei tööta: osa 6"

    | Mida näed | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | tag pole GitHubis | `git ls-remote --tags origin` | tavaline `git push` tag'e ei lükka: `git push origin k03` | Git lükkab vaikimisi ainult harud |
    | parandus pärast esitamist | `git log --oneline -1 k03` | tag viitab vanale commit'ile: `git tag -f k03 && git push -f origin k03` | tag on fikseeritud viide ühele commit'ile ega liigu koos haruga |
    | `k03 build` ebaõnnestub kloonis või automaatses hindajas, lokaalselt töötab | `git status`, `git ls-files k03-docker` | Dockerfile, `.dockerignore` või kopeeritav fail on commit'imata | värske kloon sisaldab ainult Gitis olevat |
    | `k03 files`: `k03-docker/.env on Gitis` | `git ls-files k03-docker/.env` | fail lisati varem: `git rm --cached k03-docker/.env` | `.gitignore` ei puuduta faile, mida Git juba jälgib |

Võid jätta stacki control'is tööle. Järgmisel kohtumisel saad kasutada oma lahendust, aga alustamiseks on olemas ka koolitaja valmis starter.

Dockeri paigalduse kirjutad rolliks [kodutöös](kodutoo.md). Docker Engine hostis, restart-poliitika, mitte-root kasutaja, tootmise seaded, Trivy ja Harbori poliitikad, Podman ning [18 lisaülesannet](https://hkhk-tk.github.io/is2-automatiseerimine/k03/lisa/) on kursusel [IT-infrastruktuuri automatiseerimine II](https://hkhk-tk.github.io/is2-automatiseerimine/k03/syvenemine/).
