---
tags:
  - Docker
  - Compose
  - Podman
  - Praktikum
---

# Praktikum: Labori seis konteinerites

Kahel esimesel kohtumisel seadistasid Ansible'iga teenused otse virtuaalmasinatesse. Täna pakid sama rakenduse, Labori seisu, konteineritesse. Kõigepealt paigaldad Dockeri käsitsi ja käivitad esimesed konteinerid Docker Hubi image'itest. Viis teenust käivituvad ühe `compose.yaml`-iga, image'id ehitad oma Dockerfile'idest ja lükkad kursuse registry'sse Harbor. Kaks teenust käivitad AlmaLinuxi masinates Podmaniga. Lõpus kirjutad käsitsi tehtud Dockeri paigalduse Ansible'i rolliks ja leiad vigasest stackist kolm riket.

**Edenemine:** laboritahvel <http://is126.kaaren.lab.hkhk.lan> (VPN-iga).

Küsimused: [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions). Lisa küsimusele käsk ja kogu veateade tekstina. Enne saatmist eemalda paroolid ja tokenid.

??? abstract "Õpiväljundid"

    1. Paigaldad Dockeri, tõmbad image'id Docker Hubist ja kursuse registry Harbori kaudu ning selgitad, kus konteiner hostis paistab: protsess, cgroup, port ja andmed.
    2. Kirjutad ametlike image'ite põhjal Dockerfile'id ja mitmeastmelise app-image'i, mis töötab mitte-root kasutajana.
    3. Kirjeldad viie teenusega stacki `compose.yaml`-is healthcheck'ide ja sõltuvustega ning tõestad, et `up -d` on idempotentne.
    4. Lisad tootmise erisused eraldi failina: ressursipiirangud, saladused failidest, sisemine võrk, kirjutuskaitse, logid ja varundus.
    5. Lükkad image'id Harborisse, loed Trivy raportit ja SBOM-i ning eristad tag'i ja digest'i.
    6. Käivitad sama teenuse rootless Podmaniga systemd teenusena SELinuxi all.
    7. Kirjutad käsitsi tehtud Dockeri paigalduse rolliks, mis annab teisel käivitusel `changed=0`.
    8. Leiad stackist rikked sammudega sümptom, hüpotees, tõend, parandus ja korduskontroll.

??? info "Testitud versioonid"

    Docker Engine 29 (vähemalt 28), Compose v5 (vähemalt v2.24.4), ansible-core 2.16, Harbor 2.15, `mariadb:11.4`, `rabbitmq:4.1-management-alpine`, `memcached:1.6-alpine`, `nginx:1.30-alpine`, `tomcat:10.1-jre21-temurin`, `maven:3-eclipse-temurin-21`, `alpine:3.22`, Podman 5 (AlmaLinux 9.8), Trivy 0.76. Vanem Compose ei toeta silte nagu `!override`. Prod-faili lugemisel annab see süntaksivea, mille teade ei viita versioonile.

    Dokumentatsioon: [Dockerfile](https://docs.docker.com/reference/dockerfile/), [Compose'i fail](https://docs.docker.com/reference/compose-file/), [Harbor](https://goharbor.io/docs/2.14.0/), [Podman](https://docs.podman.io/), [Trivy](https://trivy.dev/docs/latest/).

## Osa 1 · Docker ja esimesed konteinerid

Paigaldad Dockeri käsitsi, käivitad esimese konteineri ja tutvud Docker Hubi ning kursuse registry Harboriga. Seejärel käivitad konteinerid ilma Compose'ita ja vaatad hostist, kus on konteineri protsess, piirangud, port ja andmed. Docker ei too uusi tuuma mehhanisme: konteiner on hostis tavaline protsess, mida piiravad cgroup'id ja nftables'i reeglid.

### 1.1 Haru ja failid

Iga kohtumise töö käib eraldi harus. Käsk `git pull` toob repositooriumi uued failid, ka kausta `k03-docker` algfailid.

```bash
cd ~/kursus
git switch main
git pull
git switch -c k03-docker
cd k03-docker
ls -R
git check-ignore -v .env
```

??? success "Oodatav tulemus"

    Kaustas on `docker.yml`, `roles/docker/files/harbor-ca.crt` ja `intsident/compose.yaml`. `git check-ignore` näitab rida `.gitignore:…:k03-docker/.env`: fail `.env`, kuhu tulevad paroolid, jääb Gitist välja juba enne, kui sa selle lood. Kõik selle kohtumise käsud käivitad kaustas `~/kursus/k03-docker`, kui juures pole kirjas teisiti.

??? warning "Kui failid puuduvad"

    Laadi need starterist (käivita kaustas `~/kursus/k03-docker`):

    ```bash
    B=https://raw.githubusercontent.com/hkhk-tk/is1-starter/main/k03-docker
    mkdir -p roles/docker/files intsident
    curl -fsSLo docker.yml "$B/docker.yml"
    curl -fsSLo roles/docker/files/harbor-ca.crt "$B/roles/docker/files/harbor-ca.crt"
    curl -fsSLo intsident/compose.yaml "$B/intsident/compose.yaml"
    ```

### 1.2 Docker käsitsi

Docker Engine paigaldatakse Dockeri enda apt-repositooriumist. Ubuntu pakett `docker.io` on vanem ja Compose'i pluginat seal pole. Paigalda Docker [ametliku juhendi](https://docs.docker.com/engine/install/ubuntu/) järgi: eemalda vanad paketid, lisa repositooriumi võti ja repositoorium ning paigalda paketid.

```bash
sudo apt-get remove -y docker.io docker-compose docker-compose-v2 podman-docker containerd runc
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Fail `docker.sources` seob repositooriumi võtmega: sellest repositooriumist võetakse pakette ainult selle võtme allkirjaga.

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

Ilma `sudo`-ta saab Dockerit kasutada grupi `docker` liige. Grupiliikmesus rakendub alles uues sisselogimisseansis, seega logi pärast järgmist käsku välja ja uuesti sisse (VS Code'is **Remote-SSH: Kill VS Code Server on Host** ja ühendu uuesti).

```bash
sudo usermod -aG docker "$USER"
```

Pärast uut sisselogimist kontrolli versioone ja teenust:

```bash
id
docker version --format 'klient {{.Client.Version}}, server {{.Server.Version}}'
docker compose version
systemctl is-active docker containerd
```

??? success "Oodatav tulemus"

    `id` näitab gruppi `docker`. Klient ja server on 28 või uuemad, `docker compose` vastab ja mõlemad teenused on `active`. `docker` käsud töötavad ilma `sudo`-ta.

??? warning "Kui `permission denied … docker.sock`"

    Kasutaja pole grupis `docker` või sessioon on vana. Kontrolli `id`. Vana shell ja VS Code'i server töötavad vanade gruppidega edasi, seepärast logi välja ja sisse.

!!! warning "Grupp `docker` on root'i õigus"

    [Grupi `docker`](https://docs.docker.com/engine/install/linux-postinstall/) liige saab käivitada konteineri, mis mount'ib hosti `/`. Näiteks `docker run -v /:/host alpine chroot /host` annab root-shelli hostis ilma paroolita ja `sudo` logisse sellest midagi ei jää. Kursuse VM-is on see teadlik valik, jagatud serveris mitte.

### 1.3 Esimene konteiner

Image on pakitud failisüsteem koos käivitamise seadetega. Konteiner on image'ist käivitatud protsess. Image'i `hello-world` ainus programm prindib teate ja lõpetab.

**Küsimus enne käsku:** image'it `hello-world` masinas ei ole. Kust Docker selle saab?

```bash
docker run hello-world
```

??? success "Oodatav tulemus"

    Esimesed read on `Unable to find image 'hello-world:latest' locally` ja `Pulling from library/hello-world`. Docker tõmbas image'i registry'st **Docker Hub**, sest nime ees polnud muud registry't. Seejärel tuleb `Hello from Docker!` ja nelja sammu loetelu.

Loe teate nelja sammu ja võrdle neid joonisega. Klient `docker` on käsurea programm, mis saadab päringu daemonile `dockerd`. Daemon tõmbab image'i, loob sellest konteineri ja saadab programmi väljundi kliendile tagasi.

<figure markdown="span">
  ![docker CLI saadab socket'i kaudu päringu dockerd-le, dockerd annab töö containerd-le, containerd käivitab runc-iga konteineri, mis on hostis tavaline protsess; dockerd tõmbab ja lükkab image'id registry'sse Harbor](assets/k03_docker_ahel.svg)
  <figcaption>Joonis 3.1. Docker Engine'i osad: klient, daemon, containerd ja runc (Talvik, 2026).</figcaption>
</figure>

Käivita sama image teist korda ja vaata, mis masinasse jäi:

```bash
docker run hello-world | head -3
docker ps
docker ps -a
docker image ls
```

??? success "Oodatav tulemus"

    Teisel korral tõmmet ei olnud, sest image oli juba masinas. `docker ps` on tühi, `docker ps -a` näitab kaht konteinerit olekus `Exited (0)` ja `docker image ls` näitab ühte image'it `hello-world`. Konteiner lõpetas koos oma programmiga, aga jäi masinasse alles, kuni selle kustutad.

### 1.4 Docker Hub

**Docker Hub** (<https://hub.docker.com>) on Dockeri avalik registry. Kui image'i nimes pole registry aadressi, tõmbab Docker selle Docker Hubist. Lühike nimi `nginx` tähendab täisnime `docker.io/library/nginx:latest`: registry `docker.io`, ametlike image'ite nimeruum `library`, repositoorium `nginx` ja tag `latest`.

Ava brauseris <https://hub.docker.com> ja otsi `nginx`. Tulemuste juures on märk, kes image'i teeb:

- **Docker Official Image**: Dockeri hallatud image, mille Dockerfile on avalik ja mida uuendatakse turvaparandustega. Nimes pole kasutajanime (`nginx`, `mariadb`).
- **Verified Publisher**: tarkvara tootja enda image, näiteks `grafana/grafana`.
- Märgita image'i võib laadida üles igaüks. Enne kasutamist vaata, kas lehel on link lähtekoodile ja Dockerfile'ile ning millal image'it viimati uuendati.

Ava ametliku image'i `nginx` leht ja vaheleht **Tags**. Tag `latest` liigub iga uue versiooniga edasi, seega sama käsk annab kuu aja pärast teise image'i. Selles praktikumis on igal image'il versioon nimes, näiteks `nginx:1.30-alpine`. `alpine` tähendab, et image on tehtud väikese Alpine Linuxi peale.

Tõmba image lühinimega ja täisnimega:

```bash
docker pull nginx:1.30-alpine
docker pull docker.io/library/nginx:1.30-alpine
docker image ls nginx
docker image inspect nginx:1.30-alpine --format '{{.Config.ExposedPorts}} {{.Config.Cmd}}'
```

??? success "Oodatav tulemus"

    Teine `pull` ütleb `Image is up to date`: lühinimi ja täisnimi on sama image. `inspect` näitab porti `80/tcp` ja käsku, millega Nginx käivitub.

Image'i lehe ülevaates on kirjas, mida image käivitamiseks vajab. Ava ametliku image'i [`mariadb`](https://hub.docker.com/_/mariadb) leht ja leia sealt vastused. Neid läheb vaja 1.13-s, kui käivitad andmebaasi konteinerina.

??? question "Mida vajab MariaDB image?"

    1. Milline keskkonnamuutuja peab olema määratud, et konteiner käivituks?
    2. Millised muutujad loovad andmebaasi ja kasutaja?
    3. Millises kataloogis hoiab MariaDB andmeid?
    4. Millist porti server kuulab?

    ??? success "Vastus"

        1. Üks kolmest: `MARIADB_ROOT_PASSWORD`, `MARIADB_ALLOW_EMPTY_ROOT_PASSWORD` või `MARIADB_RANDOM_ROOT_PASSWORD`. Ilma nendeta konteiner lõpetab.
        2. `MARIADB_DATABASE`, `MARIADB_USER` ja `MARIADB_PASSWORD`.
        3. `/var/lib/mysql`.
        4. `3306`.

### 1.5 Harbor: kursuse registry

Docker Hub lubab ühelt IP-aadressilt 100 anonüümset tõmmet kuue tunni jooksul. Kogu klass on kooli ühe NAT-aadressi taga ja ühe stacki ehitus tõmbab kümmekond image'it, nii et piir saab täis juba esimese tunni jooksul. Siis ebaõnnestuvad kõigi tõmbed korraga veaga `toomanyrequests`. Seepärast on kursusel oma registry **Harbor**.

??? note "Tabel 3.1. Docker Hub ja Harbor"

    | | Docker Hub | Harbor |
    |---|---|---|
    | Asukoht | internetis, haldab Docker Inc. | laborivõrgus, kursuse VM |
    | Kes näeb | kõik | ainult kursus (VPN-iga) |
    | Sisu | ametlikud ja kasutajate image'id | sinu image'id ja Docker Hubi image'ite koopiad |
    | Tõmmete piir | 100 anonüümset tõmmet IP kohta 6 tunni jooksul | piirangut pole |
    | Haavatavuste skänn | ainult tasulises paketis | Trivy skannib iga image'i |

Harboris on kahte liiki projekte:

- **`dockerhub`** on avalik **pull-through cache** (vahemälu). Esimene tõmme laeb image'i Docker Hubist ja hoiab seda alles, järgmised tõmbed tulevad Harborist. Image'i nimi on siis `harbor.lab.hkhk.lan/dockerhub/library/nginx:1.30-alpine`.
- **Sinu projekt** kannab sinu GitHubi kasutajanime ja on privaatne. Sinna lükkad 6. osas oma image'id.

Harbori sertifikaadi on allkirjastanud kursuse oma CA, mida Ubuntu ei tunne. Docker usaldab registry't, kui CA on kaustas `/etc/docker/certs.d/<registry nimi>/`. Süsteemi usaldatud sertifikaatide hulka läheb sama fail, et ka `curl` ja Trivy Harborit usaldaksid. CA on starteris failina `roles/docker/files/harbor-ca.crt`.

```bash
sudo mkdir -p /etc/docker/certs.d/harbor.lab.hkhk.lan
sudo cp roles/docker/files/harbor-ca.crt /etc/docker/certs.d/harbor.lab.hkhk.lan/ca.crt
sudo cp roles/docker/files/harbor-ca.crt /usr/local/share/ca-certificates/labori-ca.crt
sudo update-ca-certificates
curl -s https://harbor.lab.hkhk.lan/api/v2.0/ping; echo
```

Et vahemälu pikka nime ei peaks iga kord kirjutama, pane eesliide muutujasse `HUB`. Kõik selle praktikumi käsud kasutavad seda muutujat.

```bash
echo 'export HUB=harbor.lab.hkhk.lan/dockerhub/library' >> ~/.bashrc
source ~/.bashrc
docker pull $HUB/nginx:1.30-alpine
docker image ls
```

Harbori konto on sul olemas. Kasutajanimi on sinu GitHubi kasutajanimi väikeste tähtedega, parool `Passw0rd`. Logi sisse käsurealt ja ava brauseris <https://harbor.lab.hkhk.lan>.

```bash
docker login harbor.lab.hkhk.lan -u <github-kasutaja>
```

??? success "Oodatav tulemus"

    `curl` vastab `Pong` ilma sertifikaadi veata. `docker image ls` näitab sama Nginxi kahe nimega: `nginx` ja `harbor.lab.hkhk.lan/dockerhub/library/nginx`. IMAGE ID on mõlemal sama, sest vahemälu andis edasi sama image'i. `docker login` ütleb `Login Succeeded`. Harboris näed projekte `dockerhub` ja oma projekti, mis on veel tühi.

??? warning "Kui `x509: certificate signed by unknown authority`"

    CA puudub kaustas `/etc/docker/certs.d/harbor.lab.hkhk.lan/` või kausta nimi ei ole täpselt registry nimi. Korda selle sammu kahte esimest käsku.

??? warning "Kui brauser hoiatab sertifikaadi eest"

    Brauser ei tunne kursuse CA-d. Brauseris võid hoiatuse kõrvale jätta või importida faili `roles/docker/files/harbor-ca.crt` oma arvutis usaldatud juursertifikaatide hulka (Windowsis topeltklõps, **Install Certificate**, **Local Machine**, **Trusted Root Certification Authorities**). Kui nimi `harbor.lab.hkhk.lan` sinu arvutis ei avane, kasuta aadressi <https://192.168.125.42>.

??? info "Miks mitte `registry-mirrors`?"

    Dockeri `daemon.json` võti `registry-mirrors` suunab Docker Hubi tõmbed teise serverisse, aga ainult sellisesse, kus image'id on juurtasemel (`/v2/library/nginx`). Harbori vahemälu on projekti all (`/dockerhub/library/nginx`), ja seda Docker ei toeta. Podman toetab, seda näed 7. osas. Seepärast on Dockeri image'ite nimes eesliide `$HUB`. GitHubi automaatkontroll Harborit ei näe (see on VPN-i taga) ja kasutab vaikimisi `docker.io/library`.

### 1.6 Engine hostis: teenus, kataloog ja konfiguratsioonifail

Docker on tavaline systemd teenus oma kataloogi, konfiguratsioonifaili ja logiga, täpselt nagu Nginx või MariaDB, mida 2. kohtumisel seadistasid. Kui tead, kus need asuvad, parandad Dockerit samamoodi nagu iga teist teenust.

Vaata, millised üksused Dockeri moodustavad ja kes socket'it kuulab:

```bash
systemctl is-active docker containerd docker.socket
systemctl cat docker | grep -E '^(ExecStart|Requires|After)='
sudo ss -xlp | grep docker.sock
```

Vaata daemoni seadeid ja seda, mis tema andmekataloogis ruumi võtab:

```bash
docker info --format '{{.Driver}} {{.DockerRootDir}} {{.CgroupDriver}} {{.LoggingDriver}}'
docker info | grep -iE 'storage driver|driver-type|live restore'
sudo du -sh /var/lib/docker/* 2>/dev/null | sort -h | tail -6
```

Daemoni konfiguratsioonifail on `/etc/docker/daemon.json`. Paigaldus seda faili ei loo ja Docker töötab vaikeseadetega. Kõige sagedasem põhjus, miks `dockerd` ei käivitu, on käsitsi muudetud `daemon.json`. Vaikimisi on `live-restore` välja lülitatud, seega iga `systemctl restart docker` peatab kõik hosti konteinerid ja vigase konfiguratsiooniga need enam ei käivitu.

Loo fail ühe seadega ja kontrolli seda daemonit peatamata. Seejärel tee meelega vigane koopia ja kontrolli seda. Alles siis taaskäivita daemon:

```bash
echo '{ "log-driver": "json-file" }' | sudo tee /etc/docker/daemon.json
sudo dockerd --validate --config-file /etc/docker/daemon.json
printf '{ "log-driver": "json-file", }\n' > /tmp/vigane.json
sudo dockerd --validate --config-file /tmp/vigane.json; echo "kood $?"
sudo systemctl restart docker
sudo journalctl -u docker --since '30 min ago' --no-pager | grep -iE 'starting up|daemon has completed' | tail -3
```

??? success "Oodatav tulemus"

    Kolm üksust on `active`. Kehtiv konfiguratsioon annab `configuration OK`, vigane koopia annab veateate ja koodi, mis pole 0. Journal'is on daemoni viimane käivitus.

    `docker.socket` kuulab socket'it ka siis, kui `dockerd` seisab: esimene `docker` käsk käivitab daemoni. `containerd` on eraldi teenus, mis konteinereid tegelikult käitab, ja `dockerd` suhtleb temaga. `DockerRootDir` on kataloog, mida jälgid kettaruumi monitooringus, sest seal on konteinerite logid, volume'id ja build cache. `--validate` leidis vea ilma teenust peatamata, nagu `nginx -t` või `sshd -t`.

    `Driver` väärtus `overlay2` tähendab klassikalist kihisalvestust `/var/lib/docker/overlay2` all. `overlayfs` tähendab containerd'i image store'i, kus kihid on `/var/lib/containerd` all. Kursuse käsud töötavad mõlemaga.

### 1.7 Elutsükkel ja PID 1

Sama Nginx paistab hostis tavalise protsessina, konteineris on ta PID 1. Elutsükli käsud `run`, `stop`, `start` ja `rm` muudavad eri asju: protsessi, kirjutatavat kihti või mõlemat. Konteiner lõpeb koos PID 1-ga. Kui sa seda ei tea, otsid valest kohast: teenus „ebaõnnestub“, aga tegelikult lõpetas entrypoint'i skript oma töö ja konteiner tegi täpselt seda, mida pidi.

Vaata 1.3 lõpetanud konteinereid, siis käivita Nginx esiplaanil (lõpeta Ctrl+C-ga), taustal, peatatuna ja uuesti käivitatuna:

```bash
docker ps -a --format '{{.Names}} {{.Status}}'
docker run --name fg $HUB/nginx:1.30-alpine
docker run -d --name w -p 8081:80 $HUB/nginx:1.30-alpine
docker stop w && docker start w && docker ps --filter name=w
```

Võrdle sama protsessi hostis ja konteineris ning leia tema namespace'id ja cgroup:

```bash
ps -ef | grep '[n]ginx: master'
docker exec w ps; docker exec w id
sudo lsns -p "$(docker inspect -f '{{.State.Pid}}' w)"
cat /proc/"$(docker inspect -f '{{.State.Pid}}' w)"/cgroup
```

**Küsimus enne käsku:** kas image'i saab kustutada, kui seda kasutab peatatud konteiner?

```bash
docker rmi $HUB/nginx:1.30-alpine
docker run $HUB/ubuntu:24.04
docker run -it --rm $HUB/ubuntu:24.04 bash
```

Viimase käsuga avanenud konteineris käivita `cat /proc/1/comm` ja `ps`, siis `exit`.

??? success "Oodatav tulemus"

    `fg` on pärast Ctrl+C olekus `Exited`, `w` tuli `start`-iga tagasi sama ID-ga. Hostis on Nginx'il tavaline PID, konteineris PID 1. `rmi` annab vea `conflict` konteineri ID-ga. Ubuntu ilma `-it`-ita lõpetas kohe koodiga 0.

    `lsns` näitas, et konteiner on hulk namespace'e ühe hostiprotsessi ümber, mitte eraldi masin. `rmi` viga tõestab, et konteiner kasutab image'i kihte otse ka peatatuna. Ubuntu ilma `-it`-ita lõpetas, sest bash ilma terminalita sai stdin'ist kohe faililõpu ja väljus koodiga 0. Ubuntu image'is pole `ps`-i: image'is on ainult see, mida peaprotsess vajab.

### 1.8 Pordid ja konteineri IP

Konteiner saab IP-aadressi sisemises sillas `docker0`. Selle aadressi poole saab pöörduda ainult hostist. Väljast jõuab konteinerini ainult avaldatud pordi kaudu, mille jaoks Docker kirjutab NAT-reegli.

Tootmisserveris tähendab see, et `-p 8081:80` avab pordi kõigile, kes hostini jõuavad. Tavapärase UFW seadistusega hosti tulemüür seda ei peata, sest Dockeri DNAT-reegel rakendub enne UFW reegleid. Täpne käitumine sõltub tulemüüri taustaprogrammist ja Dockeri versioonist, seetõttu kontrolli pordi ligipääsetavust teisest masinast (`nc -zv <host> 8081`).

```bash
IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' w)
curl -sI "http://$IP" | head -1; curl -sI localhost:8081 | head -1
docker run -d --name w2 -P $HUB/nginx:1.30-alpine && docker port w2
sudo nft list ruleset | grep -i dnat | head -3
```

Ava oma arvuti brauseris (VPN-iga) `http://<control IP>:8081` ja proovi ka `http://<konteineri IP>`. Seejärel eemalda katse konteinerid:

```bash
docker rm -f w w2 fg && docker container prune -f
```

<figure markdown="span">
  ![Sülearvuti jõuab konteinerini w ainult control'i hostipordi 8081 kaudu; konteineri IP 172.17.0.x on nähtav ainult control'ist](assets/k03_l_pordid.svg)
  <figcaption>Joonis 3.2. Kust konteiner w vastab: hostiport on nähtav väljast, konteineri IP ainult hostist (Talvik, 2026).</figcaption>
</figure>

??? success "Oodatav tulemus"

    Konteineri IP (`172.17.x.x`) vastab control'ist, aga mitte sinu arvutist. Hostiport vastab mõlemast. nft-reeglites on DNAT pordile 80.

    Kui konteineri IP vastaks sinu arvutist, oleks võrgus marsruut hosti sisemisse silda ja see oleks võrgu seadistuse viga, mitte Dockeri omadus. `-P` valis juhusliku kõrge pordi. See sobib testiks, aga mitte teenusele, sest port muutub iga uue konteineriga.

### 1.9 Võrgudraiverid: bridge, host ja none

Siiani olid kõik konteinerid vaikevõrgus `bridge`. Dockeril on veel kaks sisseehitatud draiverit: `host`, kus konteiner kasutab otse hosti võrgupinu, ja `none`, kus võrku pole üldse. Tootmisserveris küsib `--network host`-i tavaliselt monitooringuagent või VPN-tööriist. Kui seda lubada mõtlemata, kaob konteineri võrguisolatsioon: konteiner näeb kõiki hosti liideseid ja võib kuulata mis tahes porti, ka seda, mida hosti enda teenus vajab.

```bash
docker network ls
docker network inspect bridge -f '{{range .IPAM.Config}}{{.Subnet}} gw {{.Gateway}}{{end}}'
ip -br addr show docker0
```

Kontrolli, kas port 80 on hostis vaba, ja käivita Nginx hosti võrgus koos pordivõtmega:

```bash
sudo ss -tlnp | grep -E ':80 ' || echo "80 vaba"
docker run -d --name hostnet --network host -p 9999:80 $HUB/nginx:1.30-alpine
sleep 2; sudo ss -tlnp | grep -E ':(80|9999) '; docker port hostnet
docker exec hostnet ip addr | grep -E '^[0-9]+:|inet '
```

Käivita konteiner ilma võrguta ja proovi sellest internetti jõuda. Seejärel eemalda konteiner `hostnet`:

```bash
docker run --rm --network none $HUB/alpine:3.22 ip addr
docker run --rm --network none $HUB/alpine:3.22 wget -qO- -T 3 http://example.com; echo "kood $?"
docker rm -f hostnet
```

??? success "Oodatav tulemus"

    `bridge` alamvõrk on `172.17.0.0/16` ja lüüs on sama aadress, mis `docker0` liidesel: sild on hosti liides ja konteinerid on selle taga. Host-võrgus kuulab pordil 80 `nginx` ise, mitte `docker-proxy`. `docker port` on tühi, pordil 9999 ei kuula keegi ja CLI hoiatas, et `-p` jäetakse kõrvale. Kuna DNAT-i pole, kehtib siin hosti tulemüür tavapäraselt. `none` jättis ainult `lo` ja `wget` ebaõnnestus. See sobib tööle, mis ei tohi kunagi võrku puutuda, näiteks võtmete genereerimine.

??? warning "Kui `hostnet` lõpetab kohe"

    `docker logs hostnet` näitab `Address in use`: port 80 oli hõivatud. Host-võrgus tekib pordikonflikt, kui sama porti kasutab hosti teenus.

### 1.10 Mälu, CPU ja protsessid

Piiranguid vaikimisi pole. Konteiner ilma piiranguta näeb kogu hosti mälu ja CPU-d nagu iga teine protsess. Mälulekkega teenus ilma piiranguta käivitab hosti OOM killeri, mis võib tappa hoopis `sshd` või andmebaasi.

Käivita konteiner 64 MB mälupiiriga ja ilma swap'ita. Konteineri programm võtab järjest rohkem mälu, kuni tuum protsessi lõpetab:

```bash
docker run --name oom -m 64m --memory-swap 64m $HUB/alpine:3.22 sh -c 'tail /dev/zero'
echo "kood $?"
docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' oom
sudo dmesg | grep -i 'killed process' | tail -1
```

Käivita CPU-koormus poole tuuma piiranguga ja vaata `docker stats`-i:

```bash
docker run -d --name cpu --cpus 0.5 --pids-limit 50 $HUB/alpine:3.22 sh -c 'yes > /dev/null'
docker stats --no-stream cpu
docker exec cpu cat /sys/fs/cgroup/cpu.max /sys/fs/cgroup/pids.max
```

Muuda töötava konteineri piirangut ja vaata cgroup'i faili:

```bash
docker update --memory 128m --memory-swap 128m cpu
docker exec cpu cat /sys/fs/cgroup/memory.max
docker rm -f oom cpu
```

??? success "Oodatav tulemus"

    `oom` lõpetas koodiga 137 ja `OOMKilled` on `true`. `docker stats` näitab `cpu` konteineril umbes 50% CPU-d, `cpu.max` on `50000 100000` ja `memory.max` pärast `update`-i `134217728`.

    Kood 137 on 128 + 9: protsess sai SIGKILL-i. `OOMKilled: true` ütleb, et tappis tuum mälupiiri tõttu, mitte keegi `docker kill`-iga. `docker update` muutis faili töötaval konteineril protsessi taaskäivitamata: piir on lihtsalt cgroup'i fail. `docker exec` näeb konteineri enda cgroup'i juurena (cgroup namespace). Hostis on sama fail kaustas `/sys/fs/cgroup/system.slice/docker-<id>.scope/`.

### 1.11 Restart-poliitika: kes konteineri uuesti käivitab

Konteineris pole systemd'd, aga pärast tõrget või masina taaskäivitust peab konteineri keegi uuesti käivitama. Seda teeb `dockerd` restart-poliitika järgi. Vale poliitika annab kaks klassikalist viga: teenus ei käivitu pärast hooldusjärgset taaskäivitust või käivitub teenus, mille sa meelega peatasid.

Käivita Nginx poliitikaga `unless-stopped` ja tapa tema PID 1 hostist:

```bash
docker run -d --name rs --restart unless-stopped $HUB/nginx:1.30-alpine
sudo kill -9 "$(docker inspect -f '{{.State.Pid}}' rs)"
sleep 3; docker inspect -f '{{.RestartCount}} {{.State.Status}}' rs
```

Käivita teine konteiner poliitikaga `always`, peata mõlemad käsitsi ja taaskäivita daemon.

**Küsimus enne käsku:** kumb konteiner on pärast daemoni taaskäivitust `Up`, `rs` või `ra`?

```bash
docker run -d --name ra --restart always $HUB/nginx:1.30-alpine
docker stop rs ra && sudo systemctl restart docker
docker ps -a --filter name=rs --filter name=ra --format '{{.Names}} {{.Status}}'
docker rm -f rs ra
```

Proovi kolmandat poliitikat konteineriga, mis ebaõnnestub alati:

```bash
docker run -d --name rf --restart on-failure:3 $HUB/alpine:3.22 sh -c 'sleep 2; exit 1'
sleep 30; docker inspect -f '{{.RestartCount}} {{.State.Status}} {{.State.ExitCode}}' rf
docker rm rf
```

??? success "Oodatav tulemus"

    `rs` käivitus pärast `kill -9`-i ise uuesti: `RestartCount` 1 ja olek `running`. Daemon märkas PID 1 lõppemist ja käivitas sama konteineri uuesti, sama ID ja kirjutatava kihiga. Pärast daemoni taaskäivitust on `ra` üleval ja `rs` `Exited`: `always` ei arvesta sinu käsitsi peatamist, `unless-stopped` arvestab. Seepärast kasutab sinu `compose.yaml` `unless-stopped`-i. `rf` näitab `3 exited 1`: `on-failure:3` proovis kolm korda ja jättis siis konteineri seisma. Nii ei taaskäivitu katkine konteiner lõputult ning logi ja väljumiskood jäävad uurimiseks alles.

### 1.12 Käivitusvõtmed, mida admin vajab

`docker run`-il on sadu võtmeid, aga igapäevatöös kordub umbes kuus. Samad võtmed on Compose'i failis teiste nimedega: `env_file`, `user`, `init`, `volumes`, `entrypoint`. Iga katse näitab üht lõksu: mis jääb alles, kust tuleb keskkond, kellena protsess töötab, kuidas signaal protsessini jõuab, mis juhtub vale teega ja kuidas vaadata sisse konteinerisse, mis ebaõnnestub kohe.

`--rm`, `--env-file` ja `-e`: tee keskkonnafail ja vaata, mida konteiner saab.

```bash
printf 'A=yks\nB="kaks"\n' > /tmp/k03.env
D=neli docker run --rm --env-file /tmp/k03.env -e D -e E=viis $HUB/alpine:3.22 env | grep -E '^[A-E]='
docker ps -aq --filter ancestor=$HUB/alpine:3.22 | wc -l
```

`--user`: kirjuta bind mount'i root'ina ja oma UID-ga.

```bash
mkdir -p /tmp/k03-user && cd /tmp/k03-user
docker run --rm -v "$PWD:/w" $HUB/alpine:3.22 touch /w/root.txt
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/w" $HUB/alpine:3.22 touch /w/mina.txt
ls -ln; cd - && sudo rm -rf /tmp/k03-user
```

`--init`: mõõda, kui kaua `stop` kestab ilma selleta ja koos sellega.

```bash
docker run -d --name noinit $HUB/alpine:3.22 sleep 300
docker run -d --name init --init $HUB/alpine:3.22 sleep 300 && docker top init
time docker stop noinit; time docker stop init
docker rm noinit init
```

`-v` ja `--mount` olematu hostiteega:

```bash
docker run --rm -v /tmp/k03-puudub:/data $HUB/alpine:3.22 ls -la /data
ls -ld /tmp/k03-puudub && sudo rmdir /tmp/k03-puudub
docker run --rm --mount type=bind,src=/tmp/k03-puudub,dst=/data $HUB/alpine:3.22 ls /data
```

`--entrypoint`: käivita Nginx vigase konfiguratsiooniga, mis lõpeb kohe, ja uuri konteinerit seestpoolt.

```bash
printf 'server { listen 80 }\n' > /tmp/k03-ngx.conf
docker run -d --name ngx -v /tmp/k03-ngx.conf:/etc/nginx/conf.d/default.conf:ro $HUB/nginx:1.30-alpine
sleep 2; docker exec ngx true; docker logs ngx 2>&1 | tail -1
docker run --rm --entrypoint sh -v /tmp/k03-ngx.conf:/etc/nginx/conf.d/default.conf:ro $HUB/nginx:1.30-alpine -c 'nginx -t; ls /etc/nginx/conf.d'
docker rm ngx
```

??? success "Oodatav tulemus"

    `env` näitab `A=yks`, `B="kaks"`, `D=neli`, `E=viis` ja alles jäänud konteinereid on 0. `B` sai väärtuseks `"kaks"` koos jutumärkidega: `--env-file` ei tõlgenda jutumärke, Compose'i `.env` tõlgendab. `-e D` ilma väärtuseta võttis väärtuse sinu shellist.

    `root.txt` kuulub UID 0-le ja `mina.txt` sulle. Seepärast käivitad tööriista-konteineri, mis kirjutab sinu kausta, alati `--user`-iga.

    `docker top init` näitab kaht protsessi, `docker-init` ja selle all `sleep`. `noinit` peatus umbes 10 sekundiga, sest `sleep` PID 1-na ei käsitle SIGTERM-i ja tuum ei rakenda PID 1-le vaikekäitumist. `--init` pani PID 1-ks väikese init'i, mis andis signaali edasi ja korjab ka zombie-protsessid. `init` peatus alla sekundi.

    `-v` lõi puuduva kausta vaikselt root'i omanikuna, `--mount` keeldus veaga `bind source path does not exist`: vale tee jääb nii kohe silma, mitte siis, kui teenus käivitub tühja konfiguratsiooniga.

    `docker exec ngx` ütles `is not running` ja `nginx -t` näitas vigast rida. Ebaõnnestunud konteinerisse `exec` ei pääse, aga sama image sama mount'iga ja teise ENTRYPOINT-iga näitab viga otse. `--rm` kustutab koos konteineriga ka tema logi: kui konteiner ebaõnnestub ja tahad teada, miks, käivita see ilma `--rm`-ita.

### 1.13 Oma võrk ja kolm backend'i teenust

Labori seis otsib teenuseid nimede järgi `db01`, `mc01` ja `rmq01`. Vaikimisi bridge-võrgus nimelahendust pole, seega teed oma võrgu. Teenuste IP-d muutuvad iga uue konteineriga: rakendus, mis viitab IP-le, läheb katki esimesel uuesti loomisel, nimi jääb samaks. Samal ajal näed kõige tavalisemat käivitusviga: andmebaas lõpetab kohe, sest kohustuslik muutuja puudub.

```bash
docker network create labnet
docker run -d --name db01 --network labnet $HUB/mariadb:11.4
docker ps -a --filter name=db01; docker logs db01 | tail -5
```

Rikke otsimise järjekord on alati sama: `docker ps -a` (väljumiskood), `docker logs`, `docker inspect`.

Kustuta `db01` ja käivita see uuesti nii, et nõuded on täidetud: root-parool, andmebaas `labseis`, kasutaja `labseis` ja tema parool `-e` võtmetega (nimed on logis ja [image'i lehel](https://hub.docker.com/_/mariadb)), andmed nimega volume'is `dbtest` kataloogis `/var/lib/mysql`, võrk `labnet`. Lisa samasse võrku `mc01` (`memcached:1.6-alpine`) ja `rmq01` (`rabbitmq:4.1-management-alpine`, `--hostname rmq01`, kasutaja ja parool muutujatest `RABBITMQ_DEFAULT_USER` ja `RABBITMQ_DEFAULT_PASS`).

??? example "Lahendus"

    ```bash
    docker rm -f db01
    docker run -d --name db01 --network labnet -v dbtest:/var/lib/mysql \
      -e MARIADB_ROOT_PASSWORD=Juur123 -e MARIADB_DATABASE=labseis \
      -e MARIADB_USER=labseis -e MARIADB_PASSWORD=Labseis123 $HUB/mariadb:11.4
    docker run -d --name mc01 --network labnet $HUB/memcached:1.6-alpine
    docker run -d --name rmq01 --network labnet --hostname rmq01 \
      -e RABBITMQ_DEFAULT_USER=labseis -e RABBITMQ_DEFAULT_PASS=Labseis123 $HUB/rabbitmq:4.1-management-alpine
    docker ps --format '{{.Names}} {{.Status}}'
    ```

Kontrolli nimelahendust samast võrgust ja vaikevõrgust:

```bash
docker run --rm --network labnet $HUB/busybox:1.37 nslookup db01
docker run --rm $HUB/busybox:1.37 nslookup db01
```

??? success "Oodatav tulemus"

    Esimene `db01` oli `Exited (1)` ja logis oli puuduva muutuja nimi. Nüüd on kolm konteinerit `Up` võrgus `labnet`. `nslookup` vastab `labnet`-is serveriga `127.0.0.11` ja vaikevõrgus ei vasta.

    Server `127.0.0.11` tähendab, et nime lahendas Dockeri sisseehitatud DNS, mitte hosti resolver. Vaikevõrgus seda DNS-i pole. Seepärast töötab Labori seisu rakendus Compose'is muutmata: Compose loob igale projektile oma võrgu.

### 1.14 Sisemine võrk

Võrk `--internal` laseb konteineritel teineteist näha, aga väljapääsu ei anna. Seda kasutad 5. osas andmebaasi ja rakenduse võrgu jaoks. Kui andmebaasi konteineris on haavatavus, ei saa ründaja sisemisest võrgust ise koodi alla laadida ega andmeid otse välja saata.

Tee sisemine võrk, ühenda sinna töötav `mc01` ja proovi jõuda internetti ja teise konteinerini:

```bash
docker network create --internal sisemine
docker run --rm --network sisemine $HUB/alpine:3.22 wget -qO- -T 3 http://example.com
docker network connect sisemine mc01
docker run --rm --network sisemine $HUB/busybox:1.37 sh -c 'echo stats | nc -w 1 mc01 11211 | head -2'
docker inspect -f '{{json .NetworkSettings.Networks}}' mc01 | jq 'keys'
docker network inspect -f '{{.Internal}}' sisemine
```

??? success "Oodatav tulemus"

    `wget` internetti ebaõnnestub, `mc01` vastab sisemises võrgus `STAT pid`-iga ja `mc01`-l on kaks võrku. Kaks võrku ühel konteineril tähendab kaht liidest ja kaht IP-d. Samamoodi on prod-failis teenusel web01 kaks liidest: üks välimises võrgus, teine sisemises. `wget` ebaõnnestus, sest sisemises võrgus pole vaikemarsruuti, mitte sellepärast, et DNS oleks katki.

### 1.15 Andmed volume'is ja bind mount'is

Konteineri kirjutatav kiht kaob `rm`-iga. Andmebaas kirjutatavas kihis kaotab kõik andmed esimesel image'i uuendusel, sest uuendus tähendab alati uut konteinerit. Volume ja bind mount jäävad alles, aga käituvad õiguste poolest erinevalt.

Kirjuta tabelisse rida, kustuta konteiner ja käivita see uuesti 1.13 lahenduse käsuga (sama volume `dbtest`):

```bash
docker exec -it db01 mariadb -ulabseis -p labseis -e "CREATE TABLE proov (id INT); INSERT INTO proov VALUES (42);"
docker rm -f db01
```

Pärast uuesti käivitamist kontrolli, kas rida on alles ja kus andmed hostis on:

```bash
docker exec -it db01 mariadb -ulabseis -p labseis -e "SELECT * FROM proov;"
docker inspect -f '{{json .Mounts}}' db01 | jq '.[] | {Type, Name, Source}'
```

Käivita sama image nii, et andmekataloog on [bind mount'iga](https://docs.docker.com/engine/storage/bind-mounts/) sinu kodukataloogis. Seejärel kustuta konteiner ja proovi kausta kustutada:

```bash
mkdir -p "$HOME/k03-bind"
docker run -d --name dbbind -e MARIADB_ROOT_PASSWORD=x -v "$HOME/k03-bind:/var/lib/mysql" $HUB/mariadb:11.4
sleep 15; ls -ln "$HOME/k03-bind" | head -3
docker rm -f dbbind; rm -rf "$HOME/k03-bind"
```

<figure markdown="span">
  ![Konteineri db01 kataloog /var/lib/mysql võib olla kirjutatavas kihis, nimega volume'is või bind mount'is; kirjutatav kiht kaob docker rm-iga, ülejäänud jäävad alles](assets/k03_l_andmed.svg)
  <figcaption>Joonis 3.3. Kolm kohta, kuhu konteineri andmed võivad sattuda (Talvik, 2026).</figcaption>
</figure>

Loe joonist kahe küsimusega: mis jääb alles, kui konteiner kustutada, ja kelle õigustega on failid hostis.

Koristus enne järgmist osa:

```bash
docker rm -f db01 mc01 rmq01 && docker volume rm dbtest
docker network rm labnet sisemine && sudo rm -rf "$HOME/k03-bind"
docker ps -aq | wc -l
```

??? success "Oodatav tulemus"

    Rida `42` jäi pärast `docker rm -f`-i alles. `Mounts` näitab tüüpi `volume` ja allikat `/var/lib/docker/volumes/dbtest/_data`. Bind mount'i failide omanik on UID 999, tavaline `rm -rf` andis `Permission denied` ja viimane käsk näitab `0`.

    UID 999 on konteineri `mysql` kasutaja. Hostis ei pruugi sellel numbril nime olla, aga tuum kontrollib õigusi numbri järgi. Seepärast ei saanud sinu tavakasutaja faile kustutada.

### 1.16 Commit

```bash
(cd ~/kursus && git add k03-docker && git commit -m "k03: Docker käsitsi ja konteinerid" && git push -u origin k03-docker)
```

??? info "Miks see nii töötab"

    **Konteineri elutsükkel.** Konteiner on olekus `running` täpselt seni, kuni tema PID 1 töötab. Kui PID 1 lõpetab, salvestab `containerd-shim` väljumiskoodi, `dockerd` märgib konteineri `Exited (<kood>)` ja rakendab restart-poliitikat. Ilma `-d`-ta on CLI ühendatud konteineri stdio-ga ja Ctrl+C saadab signaali PID 1-le.

    **Peatamine ja kustutamine.** Peatatud konteineri kirjutatav kiht jääb alles. Konteineri kustutamisel (`docker rm`) eemaldatakse ka selle kirjutatav kiht. Konteiner kasutab image'i kihte otse overlay mount'i alumiste kihtidena, seetõttu tuleb enne image'i eemaldamist kustutada kõik seda kasutavad konteinerid, ka peatatud.

    **Taaskäivituspoliitika.** Konteineri taaskäivitamise eest vastutab daemon. `dockerd` jälgib, millal PID 1 töö lõpetab, ja käivitab sama konteineri uuesti. Väärtusega `unless-stopped` jätab daemon meelde, et konteiner peatati käsitsi, ega käivita seda ka pärast daemoni taaskäivitamist.

    **Konteineri võrk.** Vaikimisi bridge-võrgu korral saab konteiner IP-aadressi hosti sisemises sillas `docker0`. Compose loob igale projektile oma silla (`br-…`). Väljast pääseb konteinerini ainult avaldatud pordi kaudu.

    **Konteineri kataloog.** Konteineri enda kataloog `/var/lib/docker/containers/<id>` on vaid kümneid kilobaite, sest failisüsteem tuleb image'i kihtidest. Kus need kihid asuvad, sõltub salvestusdraiverist: `overlay2` korral kataloogis `/var/lib/docker/overlay2`, Docker 29 uues paigalduses containerd'i image store'is (vt 3. osa „Miks see nii töötab“, lõik „Image store“).

    **Mälupiir cgroup'is.** Mälupiir on cgroup'i fail `memory.max`. Docker määrab cgroup'is mälupiiri, piirangut jõustab tuum. Kubernetes teeb sama `resources.limits` kaudu.

    **Bind mount ja volume.** Bind mount ühendab konteinerisse hosti kataloogi koos hosti õigustega ja sobib konfiguratsioonifailile või koodile arendaja masinas. Andmebaasi andmed lähevad nimega volume'isse, mille esimesel ühendamisel kopeerib Docker image'i sihtkataloogi sisu koos omaniku ja õigustega.

    **Linuxi tuum.** Linuxi konteiner vajab Linuxi tuuma. Docker Desktop käivitab Windowsis ja macOS-is taustal väikese Linuxi virtuaalmasina.

    **Namespace'id.** `lsns` näitab konteineri namespace'e: eraldi protsessipuu, võrgu, failisüsteemi ühendused ja hostinime. Samu namespace'e kasutab ka systemd, kui teenusele on määratud näiteks `PrivateNetwork=` või `PrivateTmp=`. Docker kasutab neid lihtsalt rohkem korraga.

    **Docker Engine taustal.** Docker Engine koosneb mitmest protsessist. `dockerd` võtab vastu API-päringud ning haldab võrke, volume'eid ja image'eid. `containerd` haldab konteineri elutsüklit. `runc` loob namespace'id ja cgroup'id ning käivitab konteineri protsessi. Pärast käivitamist lõpetab `runc` töö.

    **`containerd-shim`.** Iga konteineri jaoks käivitab containerd väikese `containerd-shim`-protsessi, mis jääb konteineri protsessi vanemprotsessiks. Seetõttu ei ole konteineri protsess `dockerd` alamprotsess ja daemoni saab taaskäivitada konteinereid peatamata (vt järgmist lõiku).

    **Daemoni taaskäivitamine.** Vaikeseadega peatab `systemctl restart docker` kõik konteinerid. Kui `daemon.json`-is on `"live-restore": true`, jäävad konteinerid daemoni taaskäivitamise ajaks tööle. Swarmi režiimis see seade ei toimi.

    **`daemon.json` ja käsurida.** `daemon.json`-i võtmed on samad mis `dockerd` käsurea võtmed. Kui sama seadistusparameeter on nii failis kui ka systemd unit'i `ExecStart` real, keeldub daemon käivitumast. Tüüpiline näide on `hosts`.

    **Seadistuse uuesti laadimine.** Mõne seadistusvõtme, näiteks `debug` ja `registry-mirrors`, väärtuse loeb daemon uuesti käsu `systemctl reload docker` käivitamisel, ilma et konteinerid peatuksid. Ülejäänud võtmete muutmine nõuab daemoni taaskäivitamist.

    **Võrgudraiverid.** Praktikumis kasutasid draivereid `bridge`, `host` ja `none`. Sisseehitatud draivereid on veel: `macvlan` ja `ipvlan` annavad konteinerile oma aadressi otse kohtvõrgus, nagu oleks see eraldi masin, ja `overlay` ühendab konteinereid mitme hosti vahel. `overlay`-võrku kasutab Swarm.

    **`--init`.** Võti `--init` seab PID 1-ks `docker-init`-protsessi (`tini`), mis edastab signaalid põhiprotsessile ja koristab zombie-protsessid. Seda vajab image, mille põhiprotsess ei ole kirjutatud PID 1 rolli jaoks, näiteks shelliskript, mis käivitab alamprotsesse.

    **`--env-file`.** `docker run --env-file` loeb read sõna-sõnalt: jutumärgid jäävad väärtuse osaks ja `${…}` viiteid ei asendata. Compose'i `.env` ja `env_file` tõlgendavad jutumärke ja viiteid. Näiteks rida `DB_HOST="db01"` annab `docker run --env-file` korral väärtuse `"db01"` koos jutumärkidega, Compose'is aga väärtuse `db01`.

    **`--mount` ja `-v`.** `--mount` kasutab selgesõnalist võti=väärtus-süntaksit ja annab puuduva allikakataloogi korral vea. `-v` on vanem lühivorm, mis loob puuduva kataloogi hostis vaikselt.

    **`--user`.** `--user` töötab ka numbrilise UID-ga, mida image'i failis `/etc/passwd` ei leidu.

## Osa 2 · db ja web image

Ehitad db01 ja web01 image'id ametlike image'ite põhjal. Ametlik image teeb juba suure osa tööst, seega kirjutad Dockerfile'i ainult puuduva osa jaoks ja baasimage'i turvaparandused tulevad uuendusega kaasa.

Rakenduse failid on repositooriumi juures (`pom.xml`, `src/`, `db/`) ja jäävad puutumata, Dockerfile'id ainult loevad neid. db ja app vajavad neid faile, seega on nende **ehituskontekst** repositooriumi juur `..`. web'i kontekst on tema oma kaust.

```text
~/kursus/
├── .dockerignore                      ← 2.6
├── pom.xml  src/  db/                 ← rakendus, ei muuda
└── k03-docker/
    ├── db/Dockerfile                  ← 2.2
    ├── web/Dockerfile  web/nginx.conf ← 2.4
    ├── app/Dockerfile  kontroll/      ← 3. osa
    └── compose.yaml  .env.example     ← 4. osa
```

### 2.1 Mis on ametliku image'i sees

Ametlikus image'is on käivitusloogika juba olemas: entrypoint, vaikekasutaja, avatud pordid ja volume'id. Need on image'i metaandmetes ja `docker image inspect` näitab neid ilma konteinerit käivitamata. Kui sa ei tea, et MariaDB image kuulutab `/var/lib/mysql` volume'iks, tekib iga testkonteineriga hosti uus nimeta volume. Need kogunevad kausta `/var/lib/docker/volumes` ja hiljem pole näha, millise katse jaoks need tehti.

```bash
docker pull -q $HUB/mariadb:11.4
docker image inspect $HUB/mariadb:11.4 --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}'
docker image inspect $HUB/mariadb:11.4 --format '{{json .Config.Volumes}} {{json .Config.ExposedPorts}} {{.Config.User}}'
docker image inspect $HUB/nginx:1.30-alpine --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}'
docker run --rm --entrypoint ls $HUB/nginx:1.30-alpine /docker-entrypoint.d
```

??? success "Oodatav tulemus"

    MariaDB ENTRYPOINT on skript `docker-entrypoint.sh`, mis algseadistab tühja `/var/lib/mysql` ja loeb kausta `/docker-entrypoint-initdb.d/`. Nginx'i entrypoint käivitab enne Nginx'it skriptid kaustast `/docker-entrypoint.d/`, nende seas `20-envsubst-on-templates.sh`, mis teeb mallist lõpliku konfiguratsiooni.

    Tühi `User` tähendab, et image käivitub root'ina ja entrypoint vahetab kasutaja ise, kui ettevalmistus on tehtud. `Volumes` väljal olev kataloog saab iga konteineriga anonüümse volume'i, kui sa ise nime ei anna. Nginx'i kaust `/docker-entrypoint.d` on hook: iga sinna pandud skript käivitub enne Nginx'it.

### 2.2 db/Dockerfile

Andmebaasi image põhineb ametlikul MariaDB image'il ja sisaldab lisaks Labori seisu skeemi ja näidisandmeid. Dockerfile'is kirjutad ainult failide kopeerimise. Algseadistuse teeb entrypoint. Kui skeem on image'is, on andmebaasi struktuur versioonitud koos rakendusega ja iga uus keskkond saab sama alguse.

Nõuded ([juhiste viide](https://docs.docker.com/reference/dockerfile/)):

- baas `mariadb:11.4`, eesliide tuleb ehituse argumendist `HUB` vaikeväärtusega `docker.io/library`;
- `db/schema.sql` ja `db/seed.sql` lähevad kausta `/docker-entrypoint-initdb.d/` nii, et skeem käivitub enne andmeid (failid käivitatakse failinimede tähestikulises järjekorras);
- `COPY`, mitte `ADD`: `ADD` pakib arhiive lahti ja laeb faile URL-ilt, mida siin vaja pole.

??? example "Lahendus: `k03-docker/db/Dockerfile`"

    ```dockerfile
    ARG HUB=docker.io/library
    FROM ${HUB}/mariadb:11.4
    COPY db/schema.sql /docker-entrypoint-initdb.d/01-schema.sql
    COPY db/seed.sql /docker-entrypoint-initdb.d/02-seed.sql
    ```

    `ARG` enne `FROM`-i on ainuke juhis, mis tohib olla `FROM`-ist eespool. Argument kehtib ainult `FROM` real. Numbrid failinimede ees panevad paika järjekorra.

Ehita ja kontrolli. `--build-arg HUB` ilma väärtuseta võtab väärtuse sinu shelli muutujast:

```bash
docker build --build-arg HUB -f db/Dockerfile -t labseis-db:test ..
docker run -d --name dbt -e MARIADB_ROOT_PASSWORD=x -e MARIADB_DATABASE=labseis labseis-db:test
sleep 20; docker exec dbt mariadb -uroot -px labseis -e "SHOW TABLES;"
```

??? success "Oodatav tulemus"

    `SHOW TABLES` näitab nelja tabelit: course, lab, result, student. Mõlemad SQL-failid käivitusid ja õiges järjekorras: seed kirjutab tabelitesse, mille skeem lõi. Vale järjekorra korral lõpeks konteineri esimene käivitus veaga `Table doesn't exist`. Volume jääks siis pooleldi algseadistatuks ja järgmine käivitus jätaks init-skriptid vahele.

??? warning "Kui `\"/db/schema.sql\": not found`"

    Kontekst pole repositooriumi juur: viimane argument `..` peab osutama kaustale `~/kursus`.

### 2.3 Init-skripti lõks

Init-skriptid käivituvad ainult tühja andmekataloogiga. Tõestad selle ise: muudad seed-faili, ehitad image'i uuesti ja vaatad, kas muudatus jõuab baasi. Tootmises tähendab see, et skeemi muudatus ei saa tugineda init-skriptile. Olemasolev baas vajab migratsiooni (Flyway, Liquibase või käsitsi SQL), mitte uut image'it.

Lisa faili `../db/seed.sql` lõppu ajutiselt rida, mis lisab tabelisse `course` kursuse `('TEST', 'proov')`. Vaata faili algusest, kuidas teised read on kirjutatud. Ehita image uuesti ja käivita `dbt` uue volume'iga:

```bash
docker rm -f dbt
docker build -q --build-arg HUB -f db/Dockerfile -t labseis-db:test ..
docker run -d --name dbt -v dbt:/var/lib/mysql -e MARIADB_ROOT_PASSWORD=x -e MARIADB_DATABASE=labseis labseis-db:test
sleep 20; docker exec dbt mariadb -uroot -px labseis -e "SELECT * FROM course"
```

Muuda lisatud real `'TEST'` väärtuseks `'TEST2'`, ehita uuesti ja käivita `dbt` **sama volume'iga** `dbt`.

**Küsimus enne käsku:** kas `TEST2` jõuab baasi?

```bash
docker rm -f dbt
docker build -q --build-arg HUB -f db/Dockerfile -t labseis-db:test ..
docker run -d --name dbt -v dbt:/var/lib/mysql -e MARIADB_ROOT_PASSWORD=x -e MARIADB_DATABASE=labseis labseis-db:test
sleep 20; docker exec dbt mariadb -uroot -px labseis -e "SELECT * FROM course"
git restore ../db/seed.sql
docker rm -f dbt && docker volume rm dbt
```

??? success "Oodatav tulemus"

    Esimesel käivitusel oli `TEST` tabelis, teisel `TEST2` ei olnud. Teine käivitus leidis volume'ist valmis andmekataloogi ja jättis kogu `/docker-entrypoint-initdb.d/` vahele. Image oli uus, andmed vanad. Sama juhtub parooliga: muudetud `MARIADB_PASSWORD` ei muuda olemasoleva kasutaja parooli. Compose'i stackis on see kõige sagedasem `Access denied` põhjus.

### 2.4 web/Dockerfile ja Nginx'i mall

web01 on app01 ees pöördproksi. Nginx lahendab `upstream` nime ainult käivitusel. Kui app01 konteiner luuakse uuesti uue IP-ga, vastab web01 502-ga, ja 5. kohtumise GitHub Actionsi konveier uuendab app01 iga commit'iga. [Ametlik Nginx'i image](https://hub.docker.com/_/nginx) oskab konfiguratsioonifaili mallist genereerida ja konteineri DNS-serveri sinna kirjutada.

Nõuded:

- üks `server`-plokk pordil 80, `location /` suunab `http://app01:8080` poole ja edastab päised `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`;
- faili algus `resolver ${NGINX_LOCAL_RESOLVERS} valid=10s ipv6=off;`, `server`-plokis `set $app_upstream http://app01:8080;` ja `proxy_pass $app_upstream;`;
- Dockerfile: `nginx:1.30-alpine` (eesliide `HUB` nagu db-s), konfiguratsioonifail kopeeritakse `/etc/nginx/templates/default.conf.template`, `ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1`;
- `HEALTHCHECK`, mis küsib `wget`-iga `http://127.0.0.1/health` (Alpine'is curl'i pole).

??? example "Lahendus: `k03-docker/web/nginx.conf`"

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

??? example "Lahendus: `k03-docker/web/Dockerfile`"

    ```dockerfile
    ARG HUB=docker.io/library
    FROM ${HUB}/nginx:1.30-alpine
    ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1
    COPY nginx.conf /etc/nginx/templates/default.conf.template
    HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
      CMD wget -qO- http://127.0.0.1/health || exit 1
    ```

```bash
docker build --build-arg HUB -t labseis-web:test web
docker run --rm labseis-web:test nginx -T 2>/dev/null | grep -E 'resolver|proxy_pass'
```

??? success "Oodatav tulemus"

    `resolver` real on IP-aadress ja `proxy_pass $app_upstream;` on alles. `nginx -T` näitab lõplikku konfiguratsiooni, mille entrypoint mallist tegi. IP-aadress tähendab, et `envsubst` sai muutuja kätte. `proxy_pass $app_upstream` tähendab, et Nginx lahendab nime iga päringu ajal, mitte ainult käivitusel.

??? warning "Kui näed `${NGINX_LOCAL_RESOLVERS}` muutmata kujul"

    `ENV` jäi puudu või fail pole kaustas `templates/`.

### 2.5 Mis juhtub, kui app01 puudub

Sinu web-image peab käivituma ka siis, kui app01 veel pole. Staatilise upstream'iga Nginx keeldub käivitumast, kui nimi ei lahendu. Compose'is tähendaks see, et web01 ebaõnnestub iga kord, kui app01 alles käivitub, ja restart-poliitika taaskäivitab seda tsüklis. Proovid seda testvõrgus ilma app01-ta ja võrdled tavalise staatilise `proxy_pass`-iga, mida enamik veebinäiteid kasutab.

```bash
docker network create k03web
docker run -d --name webt --network k03web labseis-web:test
sleep 3; docker exec webt wget -qO- -T 3 http://127.0.0.1/; echo "kood $?"
docker logs webt 2>&1 | grep -m1 'could not be resolved'
docker run --rm --network k03web $HUB/nginx:1.30-alpine sh -c \
  'echo "server { listen 80; location / { proxy_pass http://app01:8080; } }" > /etc/nginx/conf.d/default.conf && nginx -t'
docker rm -f webt && docker network rm k03web
```

??? success "Oodatav tulemus"

    `webt` oli `Up` ja `wget` sai 502 (kood pole 0), logis oli `could not be resolved`. Staatiline konfiguratsioon andis `host not found in upstream`. Sinu image käivitus ja vastas 502-ga: konfiguratsioon on korras, puudu on ainult backend. Staatilise konfiguratsiooniga Nginx ei jõudnudki porti kuulama: `nginx -t` ebaõnnestus juba nime lahendamisel. 502 tähendab, et Nginx töötab, aga upstream ei vasta. `Exited (1)` tähendab, et konfiguratsioon ei läbi kontrolli.

### 2.6 .dockerignore

Ehituskontekst on kõik, mis saadetakse builderile enne esimest juhist. Docker ei vaata, mida Dockerfile tegelikult kasutab. Kõik, mis on kontekstis, võib `COPY . .` abil image'isse jõuda, ka `.env` paroolidega ja OpenTofu `tfstate`. Saladus image'is jõuab igasse koopiasse: registry'sse, iga masina kettale ja igaühele, kes image'i tõmbab. Kustutamine hilisemas kihis ei aita, sest varasem kiht on alles.

Mõõda praegust ehituskonteksti:

```bash
docker build --no-cache --build-arg HUB -f db/Dockerfile .. 2>&1 | grep -i 'transferring context'
```

Loo repositooriumi juurde [`.dockerignore`](https://docs.docker.com/build/concepts/context/) lubamisnimekirjana (allowlist): esimene rida `*`, siis `!` ridadega tagasi ainult see, mida Dockerfile'id kopeerivad.

??? example "Lahendus: `~/kursus/.dockerignore`"

    ```text
    *
    !pom.xml
    !src
    !db
    ```

    Reeglid loetakse ülevalt alla ja hilisem reegel kirjutab varasema üle. `*` jätab välja kõik, `!` read toovad tagasi ainult vajaliku.

```bash
docker build --no-cache --build-arg HUB -f db/Dockerfile .. 2>&1 | grep -i 'transferring context'
(cd .. && bash autograde/check.sh k03 files)
```

??? success "Oodatav tulemus"

    Kontekst langes megabaitidelt mõnesaja kilobaidini, db-image ehitub endiselt ja `k03 files` annab `OK` või kurdab ainult app-image'i ja Compose'i failide üle, mida sul veel pole. Väiksem kontekst tähendab kiiremat ehitust, aga peamine võit on turvalisus. Lubamisnimekirjaga ei jõua uus fail image'isse enne, kui sa selle ise lubad. Keelunimekirja (`.env`, `.git`) tuleb iga uue saladusefailiga täiendada, ja see ununeb.

### 2.7 Commit

```bash
(cd ~/kursus && git add .dockerignore k03-docker && git commit -m "k03: db ja web Dockerfile, .dockerignore" && git push)
git ls-files
```

`git ls-files` näitab, mida automaatkontroll näeb. Fail, mis on töökaustas, aga mitte Gitis, puudub ka GitHubi ehituses, ja see viga tuleb välja alles esitamisel.

??? success "Oodatav tulemus"

    `git status` on puhas ja `git ls-files` näitab faile `db/Dockerfile`, `web/Dockerfile` ja `web/nginx.conf`.

??? info "Miks see nii töötab"

    **MariaDB init-skriptid.** MariaDB image'i entrypoint-skript `docker-entrypoint.sh` algseadistab tühja andmekataloogi ja käivitab seejärel kaustas `/docker-entrypoint-initdb.d/` olevad failid tähestikulises järjekorras. Kui andmekataloogis on juba andmebaas, jäetakse need skriptid vahele. See on teadlik disain: image ei tea, kas olemasolevas baasis on tootmisandmed, ega riski nende ülekirjutamisega.

    **Skeemi muudatus.** Kui algskript ebaõnnestub poole käivituse pealt, võib andmekataloog jääda osaliselt algseadistatuks ja järgmine käivitus peab seda valmis baasiks. Ära kustuta volume'it enne, kui oled veendunud, et selle andmed võib kaotada või need on varundatud. Praktikumis saab vajaduse korral andmekataloogi uuesti luua, tootmisbaasis tuleb olukord enne parandada või varukoopiast taastada.

    **Nginx'i mallid.** Ametlik Nginx'i image genereerib kaustas `/etc/nginx/templates/` olevatest `*.template` failidest `envsubst`'iga konfiguratsioonifailid. `envsubst` asendab ainult keskkonnas defineeritud muutujad, seetõttu jäävad Nginx'i enda muutujad `$host` ja `$app_upstream` puutumata.

    **Resolver ja muutuja `proxy_pass`-is.** `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` salvestab muutujasse `NGINX_LOCAL_RESOLVERS` konteineri `/etc/resolv.conf`-is oleva DNS-serveri aadressi, Dockeri kasutaja loodud võrgus `127.0.0.11`. Millal Nginx nime lahendab, sõltub sellest, kuidas `proxy_pass` on kirjutatud:

    - `proxy_pass http://app01:8080;` lahendab nime `app01` ainult Nginx'i käivitamisel. Kui app01 konteinerit sel hetkel pole, keeldub Nginx käivitumast (`host not found in upstream`).
    - `set $app_upstream http://app01:8080;` ja `proxy_pass $app_upstream;` lahendab nime iga päringu ajal `resolver`-real määratud DNS-serverist. Nginx käivitub ka ilma app01-ta ja vastab 502-ga, kuni app01 on üleval. Kui app01 saab uue IP-aadressi, leiab Nginx selle ise.

    **`.dockerignore` lubamisnimekirjana.** `.dockerignore` reeglid loetakse ülevalt alla ja hilisem reegel kirjutab varasema üle. Lubamisnimekiri algab reaga `*`, mis jätab ehituskontekstist välja kõik, ja `!`-ga algavad read toovad tagasi ainult selle, mida Dockerfile'id kopeerivad (`!pom.xml`, `!src`, `!db`).

    **`ARG` enne `FROM`-i.** Argument, mis on enne esimest `FROM`-i, kehtib ainult `FROM` ridadel. Kui sama väärtust on vaja ka astme sees, korratakse astmes `ARG HUB` ilma väärtuseta.

## Osa 3 · App image

Ehitad rakenduse image'i kahes astmes, nii et see on väike, ei tööta root'ina ja peatub korrektselt. Sama image'i ehitab 5. kohtumisel konveier ja 7. kohtumisel käivitab Kubernetes, seega iga siin tehtud viga kordub igal ehitusel. Lisaks teed väikese kontroll-image'i, millega küsid stacki olekut seestpoolt.

### 3.1 Naiivne variant ja selle suurus

Võrdluseks teed kõigepealt image'i nii, nagu enamik veebinäiteid: ühes astmes, kuhu kopeeritakse kogu repositoorium ja kus Maven ehitab rakenduse. See töötab, aga image kannab kaasas JDK, Maveni ja kogu sõltuvuste vahemälu.

Kirjuta ajutine `app/Dockerfile.naive` (Giti see ei lähe): üks aste `maven:3-eclipse-temurin-21` peal, `COPY . .` ja `mvn -B -q package -DskipTests`, käivitus `java -jar target/labori-seis.war` (WAR on käivitatav, Tomcat on selle sees).

??? example "Lahendus: `app/Dockerfile.naive`"

    ```dockerfile
    ARG HUB=docker.io/library
    FROM ${HUB}/maven:3-eclipse-temurin-21
    WORKDIR /src
    COPY . .
    RUN mvn -B -q package -DskipTests
    CMD ["java", "-jar", "target/labori-seis.war"]
    ```

```bash
time docker build --build-arg HUB -f app/Dockerfile.naive -t labseis-app:naive ..
docker image ls labseis-app
```

??? success "Oodatav tulemus"

    Image on suurusjärgus 800 MB või rohkem ja esimene ehitus oli aeglane. Aega võttis peamiselt sõltuvuste allalaadimine, mahtu ehitustööriistad.

??? warning "Kui `COPY . .` ei too lähtekoodi kaasa"

    Lubamisnimekiri töötab: kontrolli, et `pom.xml` ja `src` on `.dockerignore`-is lubatud.

### 3.2 Mitmeastmeline Dockerfile

Kirjutad Dockerfile'i kahes astmes. Esimene aste ehitab WAR-i, teine käivitab selle. Lõppimage'isse jõuab ainult see, mille sa `COPY --from` abil teisest astmest üle tood.

<figure markdown="span">
  ![Ehitusaste maven-image'iga teeb WAR-faili; käitusaste tomcat-image'iga saab ainult WAR-i COPY --from abil; lõppimage'is pole Maveni ega lähtekoodi](assets/k03_multistage.svg)
  <figcaption>Joonis 3.4. Mitmeastmeline ehitus: lõppimage'isse jõuab ainult WAR (Talvik, 2026).</figcaption>
</figure>

Tabel 3.2 on plaan astmete kaupa: esimene aste on ehitusmasin, mis pärast ehitust kustutatakse; teine läheb tootmisse; lõpu read on metaandmed, mis muutuvad iga commit'iga ja peavad seepärast olema viimased.

??? note "Tabel 3.2. App-Dockerfile'i plaan"

    | Aste | Mida teeb |
    |---|---|
    | `FROM ${HUB}/maven:3-eclipse-temurin-21 AS build` | töökataloog `/src`; **ainult** `pom.xml`; `mvn -B -q dependency:go-offline`; siis `src/`; `mvn -B -q package -DskipTests` |
    | `FROM ${HUB}/tomcat:10.1-jre21-temurin` | ühes `RUN`-is: `apt-get update`, `curl` (`--no-install-recommends`), apt nimekirjade ja `webapps/*` kustutamine; `COPY --from=build` WAR → `webapps/ROOT.war`; `EXPOSE 8080`; `HEALTHCHECK` `curl -fsS http://localhost:8080/health` (`--start-period=60s`) |
    | lõpp | `ARG GIT_SHA=unknown`, `ENV GIT_SHA=${GIT_SHA}`, `LABEL org.opencontainers.image.revision="${GIT_SHA}"`, `CMD ["catalina.sh", "run"]` |

Kirjuta `app/Dockerfile` [kahes astmes](https://docs.docker.com/build/building/multi-stage/) tabeli järgi. Kirjuta see ise, ühe astmega näidet ära kopeeri.

??? example "Lahendus: `app/Dockerfile` (esimene versioon)"

    ```dockerfile
    ARG HUB=docker.io/library
    FROM ${HUB}/maven:3-eclipse-temurin-21 AS build
    WORKDIR /src
    COPY pom.xml .
    RUN mvn -B -q dependency:go-offline
    COPY src ./src
    RUN mvn -B -q package -DskipTests

    FROM ${HUB}/tomcat:10.1-jre21-temurin
    RUN apt-get update \
     && apt-get install -y --no-install-recommends curl \
     && rm -rf /var/lib/apt/lists/* /usr/local/tomcat/webapps/*
    COPY --from=build /src/target/labori-seis.war /usr/local/tomcat/webapps/ROOT.war
    EXPOSE 8080
    HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=3 \
      CMD curl -fsS http://localhost:8080/health || exit 1
    ARG GIT_SHA=unknown
    ENV GIT_SHA=${GIT_SHA}
    LABEL org.opencontainers.image.revision="${GIT_SHA}"
    CMD ["catalina.sh", "run"]
    ```

    `pom.xml` eraldi ja enne `src`-i: sõltuvuste kiht muutub ainult siis, kui `pom.xml` muutub. `apt-get update`, paigaldus ja nimekirjade kustutamine on ühes `RUN`-is, sest iga `RUN` on eraldi kiht ja hilisem kustutamine kihti ei vähenda.

```bash
docker build --build-arg HUB -f app/Dockerfile --build-arg GIT_SHA=$(git rev-parse --short HEAD) -t labseis-app:multi ..
docker image ls labseis-app
docker history labseis-app:multi | head -8
docker image inspect -f '{{json .Config.Labels}}' labseis-app:multi
```

??? success "Oodatav tulemus"

    `multi` on mitusada MB väiksem kui `naive`. `history` ülemistes ridades on WAR (umbes 50–60 MB) ja curl'i kiht, Maveni kihte pole, ja label'is on sinu SHA. Suuruse vahe tuleb JDK-st, Mavenist ja kaustast `~/.m2`. Kui näed `history` ülemistes ridades Maveni kihte, kopeerib käitusaste valest kohast. Label SHA-ga ütleb hiljem registry's, millisest commit'ist image tehti, ilma Giti vaatamata.

### 3.3 Mis lõppimage'isse jõudis

Lisaks suurusele vaata image'i sisu: mis programmid on image'is olemas ja mida ründaja konteineris kasutada saaks. Kompilaator ja ehitustööriistad tootmise image'is on ründajale tööriistakast: nendega saab konteineris koodi ehitada, sõltuvusi alla laadida ja oma tööriistu kokku panna.

```bash
docker run --rm --entrypoint sh labseis-app:naive -c 'command -v java mvn javac'
docker run --rm --entrypoint sh labseis-app:multi -c 'command -v java mvn javac; java -version 2>&1 | head -1'
docker run --rm --entrypoint ls labseis-app:multi -l /usr/local/tomcat/webapps
docker run --rm --entrypoint sh labseis-app:multi -c 'ls /src 2>&1; find / -name "*.java" 2>/dev/null | head -3'
```

??? success "Oodatav tulemus"

    `naive` näitab kolme teed, `multi` ainult `java` teed (JRE). `webapps` all on ainult `ROOT.war`, Tomcati näiterakendusi pole. `/src` puudub: lähtekood jäi ehitusastmesse, mida registry'sse ei lükata.

### 3.4 Cache töötab ja läheb katki

Cache lühendab korduva ehituse sekunditeni, aga ainult siis, kui juhiste järjekord seda lubab. Esimene muutunud kiht tühistab kõik järgnevad. CI-s tähendab purunenud cache iga commit'iga minuteid lisaaega ja uut apt-kihti, mis tuleb igale masinale uuesti tõmmata.

Muuda üht rida mõnes Java-failis (näiteks kommentaar failis `../src/main/java/…/VersionController.java`) ja ehita uuesti sama käsuga nagu 3.2-s. Seejärel tõsta ajutiselt `ARG GIT_SHA` ja `ENV GIT_SHA` käitusastme algusesse (kohe `FROM …tomcat…` järele) ja ehita kaks korda erineva väärtusega.

**Küsimus enne käsku:** kas `apt-get` kiht ehitatakse teisel korral uuesti?

```bash
docker build --build-arg HUB -f app/Dockerfile --build-arg GIT_SHA=aaa -t labseis-app:multi .. 2>&1 | grep -E 'CACHED|apt-get' | head -5
docker build --build-arg HUB -f app/Dockerfile --build-arg GIT_SHA=bbb -t labseis-app:multi .. 2>&1 | grep -E 'CACHED|apt-get' | head -5
```

Pane read tagasi lõppu ja võta Java-faili muudatus tagasi: `git restore ../src`.

??? success "Oodatav tulemus"

    Esimesel katsel oli `dependency:go-offline` samm `CACHED` ja uuesti käivitusid ainult `COPY src` ja järgmised: `pom.xml`-i eraldi kopeerimine töötab. Teisel katsel töötas `apt-get` iga SHA-ga uuesti, kuigi midagi ei muutunud: ka üks `ARG` vales kohas ehitab kõik järgnevad kihid uuesti, sest muutuja väärtus on kihi sisendi osa. Mida sagedamini juhis muutub, seda lähemal faili lõpule see peab olema.

### 3.5 Kihid kettal: history, GraphDriver ja kirjutatav kiht

Kui saladus või suur fail satub ühte kihti ja järgmine `RUN rm` selle „eemaldab“, jääb see registry'sse ja igale masinale alles. Igaüks, kes image'i tõmbab, saab kihi lahti pakkida ja faili kätte ilma konteinerit käivitamata.

Vaata app-image'i kihte koos suuruse ja juhisega, kihtide arvu ja salvestusdraiverit:

```bash
docker history --format '{{.Size}}\t{{.CreatedBy}}' labseis-app:multi | head -8 | cut -c1-100
docker image inspect -f '{{len .RootFS.Layers}} kihti' labseis-app:multi; docker info -f '{{.Driver}}'
docker image inspect labseis-app:multi | jq '.[0].GraphDriver // "GraphDriver puudub: containerd store"'
```

Ehita proov-image, kus fail luuakse ühes kihis ja kustutatakse järgmises:

```bash
printf 'FROM %s/alpine:3.22\nRUN head -c 50000000 /dev/urandom > /suur\nRUN rm /suur\n' "$HUB" | docker build -q -t kihtproov -
docker image ls kihtproov; docker history kihtproov | head -4
```

Käivita app konteinerina, kirjuta konteineris fail ja vaata kirjutatavat kihti `docker diff`-iga ja hostist:

```bash
docker run -d --name kiht labseis-app:multi && sleep 20
docker exec kiht sh -c 'echo proov > /tmp/minu.txt'; docker diff kiht | head -8
U=$(sudo grep -o 'upperdir=[^,]*' /proc/"$(docker inspect -f '{{.State.Pid}}' kiht)"/mountinfo | head -1 | cut -d= -f2)
echo "$U"; sudo ls -l "$U/tmp"; docker rm -f kiht
```

??? success "Oodatav tulemus"

    `history` näitas, et suured on ainult apt'i ja WAR-i kihid. `ENV`, `LABEL` ja `CMD` on 0 B, sest need muudavad ainult metaandmeid. `kihtproov` on üle 50 MB, kuigi Alpine ise on alla 10 MB ja `/suur` on kustutatud: 50 MB kiht on alles ja `rm` lisas paari KB suuruse kihi, mis ainult peidab faili. `docker diff` näitas `A` (lisatud) ja `C` (muudetud) ridu, ka Tomcati `work` ja `logs` muudatusi, ning rida `A /tmp/minu.txt`. Sama fail paistis hostis kirjutatava kihi kaustas. Konteineri kirjutatav kiht on lihtsalt kataloog hosti kettal ja kaob `docker rm`-iga.

    `overlay2` draiveriga näitab `GraphDriver.Data` kihtide kaustu (`LowerDir`, `UpperDir`) otse. containerd'i image store'iga (`overlayfs`) välja `GraphDriver` pole ja kausta leiad konteineri mount'ide andmetest, nagu viimases plokis. See töötab mõlemaga.

### 3.6 Kes on PID 1

`docker stop` saadab PID 1-le SIGTERM-i ja ootab 10 sekundit. Kas Tomcat selle kätte saab, sõltub CMD vormist. Tomcat, mis ei saa SIGTERM-i, ei lõpeta pooleliolevaid päringuid ega sulge andmebaasi ühendusi. Iga uuendus katkestab siis kasutajate päringuid ja lisab 10 sekundit seisakut.

```bash
docker run -d --name appt labseis-app:multi
docker exec appt cat /proc/1/cmdline | tr '\0' ' '; echo
time docker stop appt
docker rm appt
```

Muuda viimane rida ajutiselt shell-vormi `CMD catalina.sh run`, ehita, käivita uue konteinerina ja korda samu käske. Seejärel pane exec-vorm tagasi ja ehita uuesti.

??? success "Oodatav tulemus"

    Exec-vormiga on PID 1 `java` ja `stop` võtab paar sekundit. Shell-vormiga on PID 1 `/bin/sh -c …` ja `stop` kestab umbes 10 s. Shell ei andnud signaali edasi ja 10 sekundi pärast lõpetas Docker protsessi SIGKILL-iga. Exec-vormis sai Java signaali ja lõpetas paari sekundiga. Kui `docker logs appt` näitab pärast peatamist `Stopping service [Catalina]`, jõudis signaal kohale.

    Olek `unhealthy` on siin ootuspärane: andmebaasi pole ja `/health` annab 503. Rakendus ise vastab: `docker exec appt curl -s localhost:8080/health/live`.

### 3.7 Mitte-root kasutaja

Ametlik Tomcati image töötab root'ina, ja konteineri root on hosti root, kui user namespace'i pole (vaikimisi pole). Kui rakenduses on kaugkäivituse haavatavus, saab root'ina töötav protsess üle kirjutada Tomcati binaarid ja konfiguratsiooni. UID 10001-na saab ründaja kirjutada ainult logidesse ja ajutistesse kaustadesse.

Nõuded:

- käitusastmes luuakse süsteemikasutaja UID-ga 10001 ilma kodukataloogi ja shellita (`useradd --system`);
- kasutajale kuuluvad ainult `logs`, `temp`, `work`, `webapps` ja `conf/Catalina` kaust `/usr/local/tomcat` all, ülejäänu jääb root'ile;
- WAR kopeeritakse `COPY --from=build --chown=10001:10001`;
- `USER 10001` numbrina, enne `CMD`-i;
- kasutaja loomine on samas `RUN`-is mis apt, et kihte juurde ei tuleks.

??? example "Lahendus: käitusaste"

    ```dockerfile
    FROM ${HUB}/tomcat:10.1-jre21-temurin
    RUN apt-get update \
     && apt-get install -y --no-install-recommends curl \
     && rm -rf /var/lib/apt/lists/* /usr/local/tomcat/webapps/* \
     && useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin labseis \
     && mkdir -p /usr/local/tomcat/conf/Catalina \
     && chown -R 10001:10001 /usr/local/tomcat/logs /usr/local/tomcat/temp /usr/local/tomcat/work \
          /usr/local/tomcat/webapps /usr/local/tomcat/conf/Catalina
    COPY --from=build --chown=10001:10001 /src/target/labori-seis.war /usr/local/tomcat/webapps/ROOT.war
    EXPOSE 8080
    HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=3 \
      CMD curl -fsS http://localhost:8080/health || exit 1
    ARG GIT_SHA=unknown
    ENV GIT_SHA=${GIT_SHA}
    LABEL org.opencontainers.image.revision="${GIT_SHA}"
    USER 10001
    CMD ["catalina.sh", "run"]
    ```

```bash
docker rm -f appt; docker build -q --build-arg HUB -f app/Dockerfile -t labseis-app:multi ..
docker run -d --name appt labseis-app:multi && sleep 40
docker exec appt id; docker exec appt curl -s localhost:8080/health/live; echo
docker exec appt touch /usr/local/tomcat/conf/x
docker image inspect -f '{{.Config.User}}' labseis-app:multi
```

??? success "Oodatav tulemus"

    `id` näitab `uid=10001`, `/health/live` vastab `{"status":"UP"}`, `touch` annab `Permission denied` ja image'i `User` on `10001`. Konfiguratsioon on kirjutuskaitstud ka töötavale rakendusele. `/health/live` vastas, seega said kõik kirjutatavad kaustad õige omaniku. Numbrilist `User`-it kontrollivad Trivy `config` ja hiljem Kubernetes.

??? warning "Kui Tomcat ei käivitu ja logis on `Permission denied`"

    Mõni kirjutatav kaust kuulub veel root'ile.

### 3.8 ENTRYPOINT ja CMD: kontroll-image

Kontroll-image on tööriist, mis teeb ühe asja ja lõpetab: küsib Labori seisult olekut. Compose'i stackis kontrollid sellega stacki seestpoolt. `ENTRYPOINT` määrab programmi ja `CMD` selle vaikeargumendid, ja mõlemat saab käsureal asendada. Sama muster on Trivy, kubectl'i ja CI image'itel. Kui sa ei tea, mis on ENTRYPOINT, ei saa sa neid konveieris õigesti kasutada ja saad vea `unknown command`.

Nõuded failile `kontroll/Dockerfile` (kontekst on see kaust): baas `alpine:3.22` (eesliide `HUB`), `apk add --no-cache curl`, `LABEL org.opencontainers.image.description="Labori seisu kontroll"`, `USER nobody`, `ENTRYPOINT ["curl", "-fsS", "--max-time", "5"]` ja `CMD ["http://web01/health"]`.

??? example "Lahendus: `kontroll/Dockerfile`"

    ```dockerfile
    ARG HUB=docker.io/library
    FROM ${HUB}/alpine:3.22
    RUN apk add --no-cache curl
    LABEL org.opencontainers.image.description="Labori seisu kontroll"
    USER nobody
    ENTRYPOINT ["curl", "-fsS", "--max-time", "5"]
    CMD ["http://web01/health"]
    ```

Ehita ja käivita app testvõrgus. Seejärel käivita kontroll-image kolmel viisil: ilma argumendita, argumendiga ja asendatud ENTRYPOINT-iga.

```bash
docker build --build-arg HUB -t labseis-kontroll:test kontroll
docker network create k03test
docker rm -f appt; docker run -d --name appt --network k03test labseis-app:multi
docker run --rm --network k03test labseis-kontroll:test; echo "exit=$?"
sleep 30; docker run --rm --network k03test labseis-kontroll:test http://appt:8080/health/live; echo
docker run --rm --entrypoint sh labseis-kontroll:test -c 'id; head -2 /etc/os-release'
docker rm -f appt && docker network rm k03test
```

??? success "Oodatav tulemus"

    Esimene annab `Could not resolve host: web01` ja `exit=6`: töötas vaike-CMD. Teine annab `{"status":"UP"}`: argument asendas CMD-i. Kolmas annab `uid=65534(nobody)`: asendati programm ise. Kood 6 on curl'i kood „nime ei lahendatud“, nii et skript saab eristada nimeviga ühendusveast (7) või HTTP veast (22).

### 3.9 Commit

Enne commit'i käivita automaatkontrolli test, mis kontrollib app-Dockerfile'i ülesehitust.

```bash
rm -f app/Dockerfile.naive
(cd .. && bash autograde/check.sh k03 multistage)
(cd ~/kursus && git add k03-docker && git commit -m "k03: mitmeastmeline app, mitte-root, kontroll-image" && git push)
```

??? success "Oodatav tulemus"

    `multistage` annab `OK` ja `Dockerfile.naive` pole Gitis. `multistage` vaatab ainult faili kuju: kaks `FROM`-i ja `COPY --from`. Kas image töötab, nägid ise. Automaatkontrolli `build` ehitab selle esitamisel puhtast kloonist.

??? info "Miks see nii töötab"

    **Kihid ja kettaruum.** `docker history` loetleb kihid koos suurusega. `docker system df` näitab, kui palju ruumi võtavad image'id, konteinerid, volume'id ja ehituse vahemälu (build cache).

    **Mitmeastmeline ehitus.** Mitmeastmelise ehituse (multi-stage build) vaheaste ei jõua registry'sse. See jääb ainult ehituse vahemällu ja eemaldatakse käsuga `docker builder prune`. Seetõttu pole lõppimage'is lähtekoodi ega kompilaatorit.

    **Numbriline UID.** Mitte-root kasutaja numbriline UID on vajalik Kubernetese `runAsNonRoot` jaoks. Kubernetes peab suutma kindlaks teha, et kasutaja ei ole UID 0. Ainult kasutajanime (`USER labseis`) põhjal ei pruugi see image'i metaandmetest selguda.

    **Shell- ja exec-vorm.** Exec-vormis (`CMD ["java", "-jar", "app.jar"]`) on rakendus ise PID 1 ja saab käsu `docker stop` saadetud signaali `SIGTERM` otse kätte. Shell-vormis (`CMD java -jar app.jar`) käivitab Docker `/bin/sh -c …` ja PID 1 on shell, mis signaali rakendusele edasi ei anna. Siis ootab `docker stop` 10 sekundit ja lõpetab konteineri signaaliga `SIGKILL`. Kui enne rakendust on vaja käivitada skript, lõpeta see käsuga `exec "$@"`, nagu ametlikud entrypoint'id teevad: rakendus asendab shelli ja saab ise PID 1-ks.

    **Kontroll-image ja tööriista-image'id.** Kontroll-image'is on image'i põhiprotsess (`ENTRYPOINT`) tööriist ise, nii et `docker run` argumendid lähevad tööriistale, mitte shellile. Samamoodi on ehitatud tööriista-image'id, näiteks Trivy ja GitHub Actionsi CI konteinerid. Tööriista asemel muu käsu käivitamiseks tuleb `ENTRYPOINT` üle kirjutada (`docker run --entrypoint sh …`).

    **Image store.** Image'i kihtide salvestus sõltub Docker Engine'i seadistusest. Vanemates ja uuendatud paigaldustes on salvestusdraiver `overlay2` ja kihid asuvad kataloogis `/var/lib/docker/overlay2`. Docker 29 uutes paigaldustes on vaikimisi containerd'i image store: `docker info` näitab draiverit `overlayfs` ja kihid asuvad kataloogis `/var/lib/containerd`. Kumb variant sinu masinas on, näitab `docker info -f '{{.Driver}}'`.

    **Overlay-ühendus.** Konteineri juurfailisüsteem on mõlemal juhul overlay-ühendus (overlay mount): kirjutuskaitstud alumised kihid (`lowerdir`) ja üks kirjutatav ülemine kiht (`upperdir`). Kui hilisem kiht faili kustutab, lisatakse ülemisse kihti whiteout-kirje, aga alumises kihis jääb fail alles. Kui konteiner muudab alumises kihis olevat faili, kopeerib overlayfs enne esimest kirjutust terve faili `upperdir`-i (copy-up). Seepärast on suur ja sageli muutuv fail, näiteks andmebaasi tabelifail, kirjutatavas kihis aeglane ja täidab `/var/lib/docker` partitsiooni.

    **Pakitud ja lahtipakitud suurus.** Registry's hoitakse kihte pakitud tar-arhiividena, `docker image ls` näitab lahtipakitud suurust.

## Osa 4 · Kogu stack Compose'iga

Kirjeldad kogu Labori seisu ühes failis `compose.yaml`. Viis pikka `docker run` käsku shelli ajaloos ei näita, kuidas teenused käivitati. Compose'i fail on Gitis ja `docker compose up -d` viib süsteemi failis kirjeldatud olekusse, nagu playbook Ansible'is. Kirjutad faili ühe teenuse kaupa ([failivormingu viide](https://docs.docker.com/reference/compose-file/services/)) ja kontrollid iga teenuse järel tulemust.

<figure markdown="span">
  ![Brauser pöördub pordil 8080 web01 poole, web01 app01 poole, app01 db01, mc01 ja rmq01 poole; kõik on projekti võrgus labori-seis_default](assets/k03_compose_stack.svg)
  <figcaption>Joonis 3.5. Labori seis Compose'i stackina (Talvik, 2026).</figcaption>
</figure>

Tabel 3.3 kirjeldab valmis stacki. Read on käivitusjärjekorras. Veerg „Hostis avatud“ näitab, millised teenused on väljast nähtavad. Kõik teised suhtlevad ainult projekti võrgus. Ehitataval teenusel on image'i nimi `${REGISTRY:?}/${OWNER:?}/labori-seis-<db|app|web>:${TAG:-dev}`, ametlikul image'il on ees `${HUB:-docker.io/library}/`.

??? note "Tabel 3.3. Stacki teenused"

    | Teenus | Image | Hostis avatud | Healthcheck |
    |---|---|---|---|
    | db01 | sinu `db/Dockerfile`, kontekst `..` | ei | `healthcheck.sh --connect --innodb_initialized` |
    | mc01 | `memcached:1.6-alpine` | ei | `echo stats \| nc -w 1 127.0.0.1 11211 \| grep -q uptime` |
    | rmq01 | `rabbitmq:4.1-management-alpine` | 15672 (halduse UI) | `rabbitmq-diagnostics -q ping` |
    | app01 | sinu `app/Dockerfile`, kontekst `..` | ei | Dockerfile'ist |
    | web01 | sinu `web/`, kontekst `./web` | `${WEB_PORT:-8080}:80` | Dockerfile'ist |

### 4.1 .env ja db01

Alustad saladustest ja andmebaasist, sest kõik teised sõltuvad neist. `.env` hoiab paroole ja jääb Gitist välja. `.env.example` näitab, milliseid muutujaid on vaja, ja läheb Giti; automaatkontroll kasutab just seda faili. Compose loeb `.env`-i projekti kaustast ja asendab `${VAR}` viited enne, kui fail üldse valideeritakse.

??? example "Ülesanne: `.env.example`"

    ```bash
    DB_PASSWORD=muuda-mind
    DB_ROOT_PASSWORD=muuda-mind
    RABBITMQ_PASSWORD=muuda-mind
    TEACHER_TOKEN=muuda-mind
    HUB=docker.io/library
    REGISTRY=harbor.lab.hkhk.lan
    OWNER=sinu-github-kasutaja
    TAG=dev
    WEB_PORT=8080
    ```

    `HUB=docker.io/library` on näidisfailis meelega: GitHubi automaatkontroll Harborit ei näe ja tõmbab Docker Hubist.

Loo selle põhjal fail `.env` oma väärtustega. `OWNER` on sinu GitHubi kasutajanimi väikeste tähtedega, `HUB` sama mis shellis:

```bash
cp .env.example .env && chmod 600 .env
sed -i -e "s|^HUB=.*|HUB=$HUB|" -e "s|^OWNER=.*|OWNER=<github-kasutaja>|" .env
nano .env          # paroolid
git check-ignore -v .env
```

??? example "Ülesanne: `compose.yaml` algus ja db01"

    Nõuded: `name: labori-seis`; teenusel `db01` on `build.context: ..`, `build.dockerfile: k03-docker/db/Dockerfile` ja argument `HUB`; image'i nimi tabeli 3.2 järgi; `environment`-is root-parool, andmebaas ja kasutaja `labseis` ja kasutaja parool; nimega volume `dbdata` kataloogis `/var/lib/mysql`; healthcheck intervalliga 10 s ja 10 kordusega.

    ```yaml
    name: labori-seis

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

    volumes:
      dbdata:
    ```

    `${VAR:?}` katkestab, kui muutujat pole. `${VAR:-x}` annab vaikeväärtuse.

```bash
docker compose up -d --build db01
sleep 25; docker compose ps
```

??? success "Oodatav tulemus"

    db01 on `Up (healthy)`. `(healthy)` tähendab rohkem kui `Up`: MariaDB healthcheck kontrollis, et InnoDB on algseadistatud ja ühendusi võetakse vastu. Ainult seda olekut saavad teised teenused `depends_on`-iga oodata.

??? warning "Kui `required variable DB_ROOT_PASSWORD is missing`"

    `.env` puudub või oled vales kaustas. `${VAR:?}` teebki täpselt seda.

### 4.2 mc01 ja rmq01

Kaks backend'i teenust käivitad otse ametlikest image'itest, oma Dockerfile'i pole vaja. Avatud Memcachedi port on tuntud ründevektor: vahemälust saab lugeda kõike, mis sinna pandi, ja UDP kaudu on seda kasutatud võimendusrünnakuteks. Porti, mida väljast ei vajata, ei avaldata.

Nõuded: rmq01-l `hostname: rmq01`, kasutaja `labseis` ja parool `.env`-ist (muutujad nagu `docker run -e`-ga), andmed volume'is `rmqdata` (`/var/lib/rabbitmq`); hostis on avatud ainult RabbitMQ halduse UI port `15672`, mc01-l `ports:` pole; healthcheck tabelist, toruga käsk vajab `CMD-SHELL` kuju; lisa uus volume ka faili lõpus olevasse jaotisse `volumes:`.

??? example "Lahendus: mc01 ja rmq01"

    ```yaml
      mc01:
        image: ${HUB:-docker.io/library}/memcached:1.6-alpine
        healthcheck:
          test: ["CMD-SHELL", "echo stats | nc -w 1 127.0.0.1 11211 | grep -q uptime"]
          interval: 10s
          retries: 5

      rmq01:
        image: ${HUB:-docker.io/library}/rabbitmq:4.1-management-alpine
        hostname: rmq01
        environment:
          RABBITMQ_DEFAULT_USER: labseis
          RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:?}
        ports:
          - "15672:15672"
        volumes:
          - rmqdata:/var/lib/rabbitmq
        healthcheck:
          test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
          interval: 10s
          retries: 10
    ```

    Faili lõppu:

    ```yaml
    volumes:
      dbdata:
      rmqdata:
    ```

```bash
docker compose up -d mc01 rmq01
sleep 30; docker compose ps
```

Ava brauseris `http://<control IP>:15672` ja logi sisse kasutajaga `labseis`.

<figure markdown="span">
  ![RabbitMQ halduse UI Overview leht, node rabbit@rmq01 töötab](assets/k03_rabbitmq_overview.png)
  <figcaption>Joonis 3.6. RabbitMQ haldus: node'i nimi on `rabbit@rmq01`, sest hostinimi on fikseeritud (Talvik, 2026).</figcaption>
</figure>

??? success "Oodatav tulemus"

    Kolm teenust on `(healthy)` ja halduse UI näitab node'i `rabbit@rmq01`. Nimi tuleb võtmest `hostname`. Ilma selleta oleks nimi konteineri juhuslik ID ja iga uus konteiner leiaks volume'ist võõra node'i andmed: järjekorrad oleksid tühjad, kuigi andmed on kettal alles.

### 4.3 app01

Rakendus käivitub backend'i teenuste järel, sest vajab kõiki kolme. Ilma tingimuseta `service_healthy` ebaõnnestub app01 esimesel käivitusel, sest MariaDB alles algseadistab. Logides on siis hulk ühendusvigu, mis peidavad tegeliku vea, kui see peaks tekkima.

Nõuded: build nagu db01, aga oma Dockerfile ja argumendid `HUB` ja `GIT_SHA: ${TAG:-dev}`; image `${APP_IMAGE:-${REGISTRY:?}/${OWNER:?}/labori-seis-app:${TAG:-dev}}` (5. kohtumise konveier annab `APP_IMAGE`-iga valmis image'i); `environment`-is ainult kolm saladust (`DB_PASSWORD`, `RABBITMQ_PASSWORD`, `TEACHER_TOKEN`), hostinimed on rakenduses vaikeväärtustena olemas; `depends_on` kolmele teenusele, igaühel `condition: service_healthy`.

??? example "Lahendus: app01"

    ```yaml
      app01:
        build:
          context: ..
          dockerfile: k03-docker/app/Dockerfile
          args:
            HUB: ${HUB:-docker.io/library}
            GIT_SHA: ${TAG:-dev}
        image: ${APP_IMAGE:-${REGISTRY:?}/${OWNER:?}/labori-seis-app:${TAG:-dev}}
        environment:
          DB_PASSWORD: ${DB_PASSWORD:?}
          RABBITMQ_PASSWORD: ${RABBITMQ_PASSWORD:?}
          TEACHER_TOKEN: ${TEACHER_TOKEN:?}
        depends_on:
          db01:
            condition: service_healthy
          mc01:
            condition: service_healthy
          rmq01:
            condition: service_healthy
    ```

```bash
docker compose up -d --build app01
until docker compose exec app01 curl -fs localhost:8080/health/live; do sleep 5; done; echo
docker compose logs app01 | grep -m1 'Server startup'
docker compose exec app01 curl -s localhost:8080/health; echo
```

??? success "Oodatav tulemus"

    `/health` annab `{"status":"UP","db":"UP","queue":"UP","cache":"UP"}` ja app01 on `(healthy)`. Neli `UP`-i tähendavad, et app01 jõudis iga backend'i teenuseni nime ja parooliga. `Server startup` logis ütleb, kui kaua Tomcat käivitus. See aeg on põhjus, miks healthcheck'il on `start-period`: selle aja jooksul ebaõnnestunud kontrolle ei loeta.

??? warning "Kui `db` on DOWN ja logis `Access denied`"

    Volume algseadistati varem teise parooliga. Praktikumis on baas veel tühi, nii et käivita `docker compose down -v` ja loo stack uuesti. Tootmises kustutaks see andmed: tee enne varukoopia ja kontrolli taastamist või muuda parool baasis endas.

### 4.4 web01 ja ühised seaded

Viimase teenuse kaudu pääseb stackile ligi väljast. Kõigil teenustel on samad restart- ja logiseaded, seega kirjutad need üks kord ja viitad neile YAML-ankruga. Ilma logide rotatsioonita täidab üks palju logi kirjutav konteiner `/var/lib/docker` partitsiooni ja siis seiskub kogu Docker koos kõigi teenustega.

Nõuded: `web01` kontekstiga `./web` ja argumendiga `HUB`, image tabeli 3.2 järgi, port `"${WEB_PORT:-8080}:80"`, `depends_on: app01` tingimusega `service_healthy`. Kõigile teenustele kehtivad seaded üks kord faili algusesse [laiendusvälja](https://docs.docker.com/reference/compose-file/extension/) `x-common: &common` alla ja igale teenusele `<<: *common`: `restart: unless-stopped` ning `logging` draiveriga `json-file`, `max-size: "10m"`, `max-file: "3"`.

??? example "Lahendus: ühised seaded (faili algusesse pärast `name:`)"

    ```yaml
    x-common: &common
      restart: unless-stopped
      logging:
        driver: json-file
        options:
          max-size: "10m"
          max-file: "3"
    ```

    Lisa iga teenuse esimeseks reaks:

    ```yaml
      db01:
        <<: *common
    ```

    `&common` paneb plokile nime, `*common` viitab sellele ja `<<:` liidab ploki võtmed teenuse võtmetega.

??? example "Lahendus: web01"

    ```yaml
      web01:
        <<: *common
        build:
          context: ./web
          args:
            HUB: ${HUB:-docker.io/library}
        image: ${REGISTRY:?}/${OWNER:?}/labori-seis-web:${TAG:-dev}
        ports:
          - "${WEB_PORT:-8080}:80"
        depends_on:
          app01:
            condition: service_healthy
    ```

```bash
docker compose up -d --build
docker compose ps
curl -s http://localhost:8080/health; echo; curl -s http://localhost:8080/version; echo
docker compose top app01
```

Ava brauseris `http://<control IP>:8080/s/demo-kati-token`. See on näidisõppija vaade: token tuleb failist `db/seed.sql`. Õpetaja vaade on `/?token=<TEACHER_TOKEN>`.

<figure markdown="span">
  ![Labori seisu avaleht brauseris pordil 8080](assets/k03_labori_seis_avaleht.png)
  <figcaption>Joonis 3.7. Labori seis Compose'i stackist web01 kaudu (Talvik, 2026).</figcaption>
</figure>

??? success "Oodatav tulemus"

    Viis teenust on `(healthy)`, `/version` näitab sinu `TAG`-i, `top` näitab app01 `java` protsessi hosti PID-iga ja brauseris avaneb Labori seis. `top` näitas hosti PID-i: Compose'i teenus on endiselt hostiprotsess nagu `docker run`-iga käivitatud konteiner. Ühised seaded ühes kohas tähendavad, et kuues teenus saab need ühe reaga ja automaatkontrolli `deps` leiab restart-poliitika igalt teenuselt.

??? warning "Kui `port is already allocated`"

    Port 8080 on juba kasutusel. Vaata, milline protsess seda kasutab: `ss -tlnp | grep 8080`. Muuda `.env`-is `WEB_PORT`.

### 4.5 Töötava teenuse uurimine

Töötavat stacki uurid samade küsimustega nagu iga teist teenust, kui kasutaja ütleb „läks aeglaseks“ või „annab vahel vea“. Iga käsk vastab ühele küsimusele: mis juhtub praegu (`logs -f`), mis juhtus viimasel ajal (`--since`), milline on seadistus (`inspect --format`), kui palju ressurssi kulub (`stats`), mis protsessid töötavad (`top`) ja milline fail konteineris on (`cp`). `docker restart` säilitab konteineri ja tema logi, aga `up -d --force-recreate` loob uue konteineri ja `json-file` logi kaob koos vanaga. Enne konteineri uuesti loomist salvesta vajalikud väljad ja logiread.

Jälgi teises terminalis web01 logi (`docker compose logs -f --since 1m web01`) ja tee esimeses päringuid:

```bash
for i in 1 2 3; do curl -s -o /dev/null localhost:8080/; done
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/olematu
```

Küsi app01 kohta ainult neid välju, mida vajad:

```bash
C=labori-seis-app01-1
docker inspect -f '{{.State.Health.Status}} restart={{.RestartCount}} start={{.State.StartedAt}}' $C
docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}} {{.Config.Image}}' $C
docker inspect -f '{{range $n, $v := .NetworkSettings.Networks}}{{$n}}={{$v.IPAddress}} {{end}}' $C
docker inspect -f '{{range .State.Health.Log}}{{.ExitCode}} {{end}}' $C
```

Vaata ressursse, protsesse ja viimase kümne minuti vigu:

```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}'
docker top $C -eo pid,user,rss,args | cut -c1-110
docker compose logs --since 10m --timestamps app01 | grep -ciE 'error|exception'
```

Kopeeri web01-st välja konfiguratsioon, mille entrypoint mallist tegi, ja võrdle seda oma malliga:

```bash
docker compose cp web01:/etc/nginx/conf.d/default.conf /tmp/web01-default.conf
diff web/nginx.conf /tmp/web01-default.conf
```

??? success "Oodatav tulemus"

    Logis tekkisid read samal hetkel, kui tegid päringu, ja päring `/olematu` andis logisse 404 rea, mida saad otsida ilma kogu logi kerimata. Inspect-päringud andsid `healthy`, teenuse nime, võrgu ja IP. `Health.Log` hoiab viie viimase kontrolli väljumiskoode: nullid tähendavad, et healthcheck on järjest õnnestunud, üks teine number vahel näitab ajutist tõrget. `stats` näitab, et kõige rohkem mälu kasutavad app01 ja db01. `top` näitab Java protsessi hosti PID-iga ja kasutajaga `10001`, sest hostis sellel UID-l nime pole. `diff` näitab erinevust ainult `resolver` real: entrypoint asendas `${NGINX_LOCAL_RESOLVERS}` DNS-serveri aadressiga ja kõik muu on sinu fail.

    `docker cp` töötab ka teises suunas, hostist konteinerisse. See sobib silumiseks, aga mitte parandamiseks: järgmine `up -d` loob konteineri uuesti ja sinu fail kaob.

### 4.6 Muudatus ja idempotentsus

Ansible'i playbook andis teisel käivitusel `changed=0`. Compose'i `up -d` võrdleb iga teenuse seadistuse räsi konteineri sildiga `com.docker.compose.config-hash` ja loob uuesti ainult selle, mis erineb. Kui sa ei tea, mida `up -d` puudutab, kardad seda tootmises käivitada ja hakkad konteinereid käsitsi parandama. Nii tekib erinevus faili ja tegeliku oleku vahel (triiv), ja järgmine `up -d` kirjutab sinu käsitsi parandused üle.

**Küsimus enne käsku:** kas muutmata failiga `up -d` loob mõne konteineri uuesti?

```bash
docker compose up -d
```

Muuda `.env`-is `WEB_PORT` väärtuseks `8088` ja uuenda stacki.

**Küsimus enne käsku:** millised teenused luuakse pordi muutmise järel uuesti?

```bash
sed -i 's/^WEB_PORT=.*/WEB_PORT=8088/' .env && docker compose up -d
docker compose ps --format '{{.Service}} {{.RunningFor}} {{.Ports}}'
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8088/health
sed -i 's/^WEB_PORT=.*/WEB_PORT=8080/' .env && docker compose up -d
```

??? success "Oodatav tulemus"

    Esimene `up -d` ütles kõigi kohta `Running`: midagi ei muutunud ja midagi ei loodud. Pordi muutmise järel loodi uuesti ainult web01, sest ainult selle seadistus erines. `RunningFor` näitab, et teised jäid alles. `/health` vastas pordil 8088. Kui `up -d` loob ilma muudatuseta midagi uuesti, on failis väärtus, mis muutub iga käivitusega.

### 4.7 Tulemus web01-st db01-ni

`/health` ütleb, et ühendused on olemas. Roheline `/health` ei tõesta, et kasutaja andmed jõuavad kohale: sõnum võib järjekorda kinni jääda, kui consumer ei tööta, ja API vastab ikka `accepted`. Nüüd saadad ühe tulemuse läbi ahela web01 → app01 → rmq01 → consumer → db01 (consumer on app01 sees töötav RabbitMQ listener, mis kirjutab sõnumi baasi) ja loed koondtabelit mc01 kaudu. Demotoken `demo-kati-token` on failis `db/seed.sql`.

<figure markdown="span">
  ![POST läheb web01 ja app01 kaudu RabbitMQ järjekorda, consumer kirjutab selle db01-sse; korduv GET saab koondtabeli mc01-st](assets/k03_l_tulemuse_teekond.svg)
  <figcaption>Joonis 3.8. Ühe tulemuse teekond läbi stacki (Talvik, 2026).</figcaption>
</figure>

Joonis näitab, et POST- ja GET-päringud käivad eri teid. Kirjutamine on asünkroonne: app01 vastab kohe ja tulemus jõuab baasi alles siis, kui consumer sõnumi järjekorrast võtab. Lugemine käib vahemälu kaudu.

```bash
docker run --rm --network labori-seis_default labseis-kontroll:test; echo
curl -s -X POST http://localhost:8080/api/results \
  -H 'Authorization: Bearer demo-kati-token' -H 'Content-Type: application/json' \
  -d '{"lab":"lab-03","check":"compose","status":"OK","host":"'"$(hostname)"'"}'; echo
sleep 2; docker compose exec rmq01 rabbitmqctl list_queues name messages consumers
curl -s -H 'Authorization: Bearer demo-kati-token' http://localhost:8080/api/results | jq '.[] | {lab, check, status}'
for i in 1 2 3; do curl -s -o /dev/null http://localhost:8080/; done
docker compose exec mc01 sh -c 'echo stats | nc -w 1 127.0.0.1 11211' | grep -E 'get_(hits|misses)'
```

??? success "Oodatav tulemus"

    Kontroll-image annab `/health` JSON-i, POST vastab `{"status":"accepted"}`, järjekorras `results` on 0 sõnumit ja 1 consumer, GET näitab `lab-03 / compose / OK` ja `get_hits` on suurem kui 0. 0 sõnumit ja 1 consumer tähendab, et sõnum läbis järjekorra: consumer võttis selle ja kirjutas baasi. Kui sõnumeid oleks 1 ja consumer'eid 0, töötaks API, aga andmed oleksid järjekorras kinni. `get_hits` üle nulli näitab, et korduv GET tuli vahemälust ega koormanud andmebaasi.

### 4.8 Riku ja vaata

Peatad ühe sõltuvuse, lood rakenduse uuesti ja taaskäivitad terve masina. Need kolm juhtuvad tootmises: järjekorraserver läheb hooldusse, konveier uuendab rakendust, host saab tuumauuenduse.

```bash
docker compose stop rmq01
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/health
sleep 45; docker compose ps app01 web01
docker compose start rmq01
docker compose up -d --force-recreate --no-deps app01
until curl -fs -o /dev/null http://localhost:8080/health; do sleep 3; done; echo ok
```

Taaskäivita control (`sudo reboot`) ja vaata pärast sisselogimist `docker compose ps`.

??? success "Oodatav tulemus"

    `/health` andis 503 ja app01 läks `unhealthy`, aga keegi seda ei taaskäivitanud. Kui rmq01 uuesti käivitus, taastas rakendus ühenduse ise. Uuesti loomise järel vastas web01 ilma 502-ta: `nginx.conf`-i `resolver` leidis app01 uue IP 10 sekundi jooksul. Pärast taaskäivitust käivitas stacki `restart: unless-stopped`, mitte sina.

### 4.9 Commit

Enne commit'i käivitad kolm automaatkontrolli testi, mis loevad sama `compose.yaml`-i. Testid kasutavad `.env.example` väärtusi, mitte sinu `.env`-i. Seepärast peab näidisfail sisaldama kõiki muutujaid, mida `${VAR:?}` nõuab, muidu ebaõnnestub `compose` GitHubis, kuigi sinu masinas töötab.

```bash
(cd .. && for t in compose deps tags; do bash autograde/check.sh k03 "$t"; done)
git status --short
(cd ~/kursus && git add k03-docker && git commit -m "k03: kogu stack Compose'iga" && git push)
```

??? success "Oodatav tulemus"

    `compose`, `deps` ja `tags` annavad `OK` ja `git status` ei näita `.env`-i.

??? info "Miks see nii töötab"

    **Avaldamata pordid.** Teenustel `db01` ja `mc01` pole `ports`-seadistust, sest neid vajab ainult `app01`, mis on nendega samas võrgus.

    **Healthcheck ja Kubernetes.** Healthcheck märgib teenuse oleku, kuid ei käivita teenust ise uuesti: app01 ei taaskäivitu, kui rmq01 kaob. Kubernetes tegutseb oleku põhjal ise ja eristab seetõttu kahte kontrolli: `/health/live` (kas protsess töötab, kui ei, taaskäivita) ja `/health` (kas teenus on valmis päringuid vastu võtma).

    **`restart: always` healthcheck'i asemel.** Vanemates juhendites asendab healthcheck'i `restart: always`: rakendus lõpetab vea tõttu töö ja Docker käivitab selle uuesti, kuni andmebaas on valmis. Need kaks seadistust lahendavad eri probleemi. `restart` reageerib ainult sellele, et protsess lõpetas töö. Healthcheck kontrollib, kas töötav protsess teenindab päringuid, ja koos tingimusega `condition: service_healthy` ootab sõltuv teenus enne käivitamist, kuni sõltuvus on valmis. Ainult `restart: always` korral on logid vigu täis ja vigast seadistust ei saa eristada ajutisest tõrkest, sest mõlemal juhul käivitub konteiner üha uuesti.

    **Volume koodi peal.** Veebis leiduvates Tomcati näidetes on sageli kataloog `webapps` volume'is. Tulemus sõltub image'i entrypoint'ist ja mount'i sihtkataloogist. Nimega volume'i korral kopeerib Docker esimesel ühendamisel image'i sihtkataloogi sisu (WAR-faili) tühja volume'isse ja hilisem uus image ei jõua enam konteinerisse, sest volume katab image'i kataloogi. Bind mount'i korral katab hosti kataloog image'i sisu kohe ja rakendust pole konteineris üldse. Sama lõks on igal kataloogil, kuhu image toob koodi ja millele ühendatakse volume.

    **`depends_on`.** Lihtne `depends_on` määrab ainult käivitusjärjekorra: Compose käivitab sõltuvuse enne, kuid ei oota, kas see on valmis. `condition: service_healthy` ootab, kuni sõltuvuse healthcheck annab oleku `healthy`. Mõlemad mõjuvad käsu `docker compose up` ajal. Kui db01 hiljem ise taaskäivitub, ei tee Compose app01-ga midagi ja rakendus peab ühenduse ise taastama. Labori seis teeb seda, nagu nägid rmq01 peatamisel.

    **`docker inspect --format`.** `docker inspect --format` kasutab Go `text/template` süntaksit konteineri JSON-objekti peal. `{{.State.Health.Status}}` võtab ühe välja ja `{{json .Mounts}}` annab alampuu JSON-ina `jq` jaoks. `{{index .Config.Labels "nimi"}}` loeb võtme, milles on punkt, ja `{{range}}` käib läbi loendi või võtme-väärtuse paarid. Sama mall töötab image'ite, võrkude ja volume'ite peal ning käskudes `docker ps --format` ja `docker stats --format`.

    **Logide ajavahemik.** Logide ajavahemiku piiramiseks on valikud `--since` ja `--until` (suhteline aeg, näiteks `10m`, või ajatempel). Valik `--timestamps` lisab igale reale Dockeri enda ajatempli. Kui rakendus kirjutab oma ajatempli teises ajavööndis, on erinevus kohe näha.

    **Compose ja orkestraator.** Compose haldab üht hosti. Kui host läheb rikki, on stack maas. Kui tahad kahte app01 koopiat, uuendust ilma 502-ta või teenuse kolimist teisele masinale, Compose ei aita. Seda tööd teeb orkestraator. Dockeril on oma sisseehitatud orkestraator Swarm (lisaülesanne 1). Orkestraatoris ei käivita sa konteinerit ise. Ütled, et koopiaid peab olema kolm, ja manager hoiab seda olekut: kustutatud koopia asemele tuleb uus, ilma et keegi oleks käsu andnud. Sama juhtimistsüklit (control loop) kasutab Kubernetes. Swarmi uuendus vahetab koopiad ükshaaval ja teenus vastab kogu aja, sest avaldatud port on Swarmi ingress-võrgus ja suunab liikluse ainult töötavatele koopiatele.

    **Miks Kubernetes, mitte Swarm.** Swarm on lihtne ja loeb sama Compose'i vormingut (`docker stack deploy -c`). Meie `compose.yaml` töötaks seal peaaegu muutmata, välja arvatud kaks asja: `build:` ei toimi, image peab olema registry's, ja `depends_on` jäetakse kõrvale. Orkestraator eeldab, et rakendus talub puuduvat sõltuvust ja ühendub ise uuesti, nagu Labori seis rikketestis tegi. Swarmi ökosüsteem on aga väike ja areneb aeglaselt. Kubernetest toetavad pilvede hallatud teenused, monitooringu- ja turvatööriistad, ja selle oskust küsitakse tööpakkumistes.

    Sisuline vahe on mudelis. Kubernetes eristab liveness'i ja readiness'i kontrolli (`livenessProbe` ja `readinessProbe`), Swarmil on üks healthcheck. Kubernetesel on namespace'id, RBAC, NetworkPolicy, püsikettad CSI kaudu ja laiendused (operaatorid, Helm), mis teevad sellest platvormi, mitte ainult konteinerite käivitamise vahendi. Hind on keerukus, ja seepärast kasutame 7. kohtumisel k3s-i, mis paneb sama API ühe binaarina kokku.

    **Compose'ist Kubernetesesse.** Tabel näitab, kuidas tänane töö Kubernetesesse üle läheb. Mõisted jäävad samaks, muutub ainult see, kes soovitud olekut hoiab.

    | Compose'is | Kubernetesis |
    |---|---|
    | teenus `app01` ja tema `image` | Deployment ja pod template |
    | `restart: unless-stopped` | kontroller hoiab koopiate arvu |
    | healthcheck `/health` | `livenessProbe` `/health/live` ja `readinessProbe` `/health` |
    | `deploy.resources.limits` | `resources.limits` ja `requests` |
    | `secrets:` failid `/run/secrets/` all | Secret, mount'itud volume'ina |
    | võrgud `front` ja `back` | Service ja NetworkPolicy |
    | nimega volume `dbdata` | PersistentVolumeClaim |
    | `ports: "8080:80"` | Service (NodePort) või Ingress |

    Image'id, healthcheck'i otspunktid, mitte-root kasutaja, ressursipiirid ja saladused failidena lähevad Kubernetesesse muutmata.

## Osa 5 · Tootmiskeskkonda sobiv stack

Lisad stackile tootmise seaded eraldi failis `compose.prod.yaml`: mälupiirid, paroolid failidest, sisemise võrgu, kirjutuskaitse ja logide piirid. Põhifail `compose.yaml` jääb muutmata, sest seda kasutavad automaatkontroll ja 5. kohtumise konveier. Lõpus varundad ja taastad andmebaasi volume'i ning paned paika koristuse.

Tabel 3.4 näitab prod-faili sisu ühes kohas. Iga rida vastab küsimustele: kui palju ressursse teenus tohib kasutada, millistesse võrkudesse see kuulub ja mis on selles kirjutuskaitstud. Mälupiiride summa on umbes 2 GB ja on valitud control'i mälu järgi. Tootmisserveris mõõdad need `docker stats`-iga koormuse all.

??? note "Tabel 3.4. Prod-faili sisu teenuste kaupa"

    | Teenus | Mälu | CPU | PID-id | Võrgud | Muu |
    |---|---|---|---|---|---|
    | db01 | 512m | 1.0 | 200 | back | saladused failidest |
    | mc01 | 128m | 0.5 | 100 | back | `read_only`, `command: ["memcached", "-m", "64"]` |
    | rmq01 | 512m | 1.0 | 300 | back, front | UI ainult `127.0.0.1:15672` |
    | app01 | 768m | 1.5 | 300 | back | saladused failidest, `CATALINA_OPTS`, journald |
    | web01 | 64m | 0.5 | 100 | front, back | `read_only` + `tmpfs` |

### 5.1 Prod-fail ja ressursipiirangud

Prod-fail on teine Compose'i fail, mis liidetakse põhifaili peale. Alustad ressursipiirangutest, sest need on kõige lihtsamad ja nende mõju näed kohe `docker stats`-is. Ilma piiranguteta võib üks teenus teistelt ressursid ära võtta: Java võtab mälu, mida MariaDB vajaks puhvriteks, ja hosti OOM killer valib ohvri kogu masina seast.

Tee kaustas `k03-docker/` fail `.gitignore` ridadega `secrets/`, `backup/`, `trivy.txt`, `sbom-*.json`, `intsident/data/`.

??? example "Ülesanne: `compose.prod.yaml` algus"

    Igale teenusele `deploy.resources.limits` tabeli 3.3 järgi ja mc01-le `command`. Faili `name:` ega `build:` ei kordu, need tulevad `compose.yaml`-ist.

    ```yaml
    # Tootmise erisused: docker compose -f compose.yaml -f compose.prod.yaml …
    services:
      db01:
        deploy:
          resources:
            limits: {memory: 512m, cpus: "1.0", pids: 200}

      mc01:
        deploy:
          resources:
            limits: {memory: 128m, cpus: "0.5", pids: 100}
        command: ["memcached", "-m", "64"]

      rmq01:
        deploy:
          resources:
            limits: {memory: 512m, cpus: "1.0", pids: 300}

      app01:
        deploy:
          resources:
            limits: {memory: 768m, cpus: "1.5", pids: 300}

      web01:
        deploy:
          resources:
            limits: {memory: 64m, cpus: "0.5", pids: 100}
    ```

Vaata liidetud tulemust ja käivita stack mõlema failiga. `COMPOSE_FILE` kehtib selle shelli lõpuni, `--wait` ootab, kuni kõik teenused on `healthy`.

```bash
export COMPOSE_FILE=compose.yaml:compose.prod.yaml
docker compose config | grep -A4 'limits:' | head -12
docker compose up -d --wait && docker compose ps
docker stats --no-stream
docker compose exec app01 cat /sys/fs/cgroup/memory.max
docker compose exec app01 sh -c 'java -XX:+PrintFlagsFinal -version 2>/dev/null | grep -E "MaxHeapSize|MaxRAMPercentage"'
```

Lisa app01-le `environment`-i `CATALINA_OPTS: "-XX:MaxRAMPercentage=75"`, uuenda stacki ja vaata Tomcati käsurida: `docker compose exec app01 ps -o args= -p 1`.

??? success "Oodatav tulemus"

    `docker stats` näitab igal teenusel LIMIT-veerus tabeli väärtust, app01 `memory.max` on `805306368` ja vaikimisi `MaxHeapSize` on umbes veerand sellest. Pärast muudatust on Tomcati käsureal `-XX:MaxRAMPercentage=75`.

    JVM luges cgroup'i piiri ja arvutas heap'i selle järgi. Vaikimisi veerand 768 MB-st on alla 200 MB, ja raske päring võib anda `OutOfMemoryError`, kuigi konteiner pole piirile lähedalgi. `MaxRAMPercentage=75` annab heap'ile kolm neljandikku ja jätab ülejäänu metaspace'ile ja lõimedele. `java -XX:+PrintFlagsFinal` käivitab uue JVM-i ilma `CATALINA_OPTS`-ita, seepärast vaatad Tomcati väärtust protsessi käsurealt.

### 5.2 Piir peab vastu: protsesside arv

Mälupiiri nägid juba `docker run -m`-iga. Protsesside piir kaitseb teise vea eest: fork-pomm või skript, mis käivitab protsesse lõputult. Ilma `pids`-piiranguta täidab üks konteiner hosti protsessitabeli. Siis ei saa ka `sshd` uut sessiooni avada ja masinat saad parandada ainult konsoolist. Proovid seda web01-s, mille piir on 100.

**Küsimus enne käsku:** mitu protsessi käivitub ja kas `/health` vastab sel ajal?

```bash
docker compose exec web01 sh -c 'for i in $(seq 150); do sleep 30 & done' 2>&1 | sort | uniq -c
docker stats --no-stream --format '{{.Name}} {{.PIDs}}' labori-seis-web01-1
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/health
sleep 30; docker stats --no-stream --format '{{.Name}} {{.PIDs}}' labori-seis-web01-1
```

??? success "Oodatav tulemus"

    Osa `sleep`-e andis `can't fork`, PIDs jõudis 100-ni, `/health` andis 200 ja pärast ootamist on PIDs jälle tavalisel tasemel. Kui piir täis sai, keeldus tuum uut protsessi loomast. Hosti ülejäänud protsessid ei saanud sellest mõju. Nginx teenindas päringuid edasi, sest olemasolevad workerid ei vaja uusi protsesse. Konteinerit polnud vaja taaskäivitada.

### 5.3 Saladused failidest

`docker inspect` näitab praegu paroole igaühele, kes pääseb socket'i juurde. Keskkonnamuutuja lekib mitmest kohast: `docker inspect`, `/proc/<pid>/environ`, rakenduse veateade, mis väljastab keskkonna, ja iga alamprotsess, mis selle pärib. Faili sisu ei jõua neist ühtegi. Tee paroolidest failid ja anna need teenustele [`secrets:`](https://docs.docker.com/compose/how-tos/use-secrets/) kaudu. Konteiner näeb faili kaustas `/run/secrets/` ja keskkonda jääb ainult faili tee.

```bash
docker inspect -f '{{json .Config.Env}}' labori-seis-app01-1 | tr ',' '\n' | grep -iE 'pass|token'
mkdir -m 700 secrets
set -a; . ./.env; set +a
for k in DB_PASSWORD DB_ROOT_PASSWORD RABBITMQ_PASSWORD TEACHER_TOKEN; do printf '%s' "${!k}" > "secrets/$k"; done
chmod 644 secrets/*; ls -la secrets; git status --short
```

`printf '%s'` kirjutab väärtuse ilma reavahetuseta. `echo` lisaks reavahetuse ja see läheks parooli osaks.

??? example "Ülesanne: saladused prod-faili"

    Lisa faili lõppu tipptaseme jaotis `secrets:` nelja kirjega:

    ```yaml
    secrets:
      DB_PASSWORD:
        file: ./secrets/DB_PASSWORD
      DB_ROOT_PASSWORD:
        file: ./secrets/DB_ROOT_PASSWORD
      RABBITMQ_PASSWORD:
        file: ./secrets/RABBITMQ_PASSWORD
      TEACHER_TOKEN:
        file: ./secrets/TEACHER_TOKEN
    ```

    db01 ja app01 juurde. [`!override`](https://docs.docker.com/reference/compose-file/merge/) on vajalik: ilma selleta liidetakse mapping'ud ja `MARIADB_PASSWORD` jääb alles.

    ```yaml
      db01:
        secrets: [DB_ROOT_PASSWORD, DB_PASSWORD]
        environment: !override
          MARIADB_ROOT_PASSWORD_FILE: /run/secrets/DB_ROOT_PASSWORD
          MARIADB_PASSWORD_FILE: /run/secrets/DB_PASSWORD
          MARIADB_DATABASE: labseis
          MARIADB_USER: labseis

      app01:
        secrets: [DB_PASSWORD, RABBITMQ_PASSWORD, TEACHER_TOKEN]
        environment: !override
          SPRING_CONFIG_IMPORT: "optional:configtree:/run/secrets/"
          CATALINA_OPTS: "-XX:MaxRAMPercentage=75"
    ```

```bash
docker compose config | grep -E '_FILE|SPRING_CONFIG|PASSWORD:'
docker compose up -d --wait && docker compose ps
docker inspect -f '{{json .Config.Env}}' labori-seis-app01-1 | tr ',' '\n' | grep -iE 'pass|token'
docker compose exec app01 ls -l /run/secrets; curl -s localhost:8080/health; echo
```

??? success "Oodatav tulemus"

    `git status` ei näita kausta `secrets/`. `config` ei näita db01 ja app01 all ühtegi `MARIADB_PASSWORD:` ega `DB_PASSWORD:` rida, `inspect` ei leia app01 keskkonnast parooli ja `/health` on `UP`. Pärast `!override`-i on keskkonnas ainult failide teed ja configtree import. `/health` UP tõestab, et rakendus luges paroolid failidest ja need klappisid volume'i omadega. Kui parool oleks failis reavahetusega, oleks `db` DOWN.

    Failide õigused on `644`, sest konteiner näeb faili hosti omaniku ja õigustega ja app01 töötab UID 10001-na. Kaitse annab kausta õigus `700`: hostis ei pääse teised kasutajad failideni.

### 5.4 Sisemine võrk ja halduse UI loopback'il

`--internal` võrku proovisid käsitsi. Nüüd jagad stacki kaheks: `front` väljapoole ja `back` ilma väljapääsuta. web01 on mõlemas ja on ainus sild nende vahel. Kui app01 on kompromiteeritud, ei saa ründaja sealt otse internetti ühendust võtta ega tööriistu alla laadida. Halduse UI, mis on nähtav kogu VPN-ile, on parooli äraarvamise sihtmärk. Loopback'il näeb seda ainult SSH-ga sisse loginud administraator.

??? example "Ülesanne: võrgud"

    Tipptasemele:

    ```yaml
    networks:
      front: {}
      back:
        internal: true
    ```

    Igale teenusele `networks` tabeli 3.3 järgi. rmq01 halduse UI ainult loopback'ile. Avaldatud port vajab mitte-sisemist võrku, seepärast on rmq01 ka `front`-is.

    ```yaml
      db01:
        networks: [back]
      mc01:
        networks: [back]
      rmq01:
        networks: [back, front]
        ports: !override
          - "127.0.0.1:15672:15672"
      app01:
        networks: [back]
      web01:
        networks: [front, back]
    ```

```bash
docker compose up -d --wait && docker compose ps
docker network inspect -f '{{.Name}} {{.Internal}}' labori-seis_back labori-seis_front
docker compose exec app01 curl -sS -m 5 https://example.com -o /dev/null; echo "app01 kood $?"
docker compose exec web01 wget -q -T 5 -O /dev/null http://example.com; echo "web01 kood $?"
sudo ss -tlnp | grep -E ':(8080|15672) '
docker run --rm --network labori-seis_back labseis-kontroll:test; echo
```

Ava oma arvutist SSH-tunnel ja seejärel brauseris `http://localhost:15672`:

```bash
ssh -L 15672:127.0.0.1:15672 kasutaja@<control IP>
```

??? success "Oodatav tulemus"

    `back` on `true`. app01 ei jõua internetti (kood pole 0), web01 jõuab (kood 0): segmenteerimine töötab mõlemas suunas õigesti. `ss` näitab, et 15672 kuulab ainult `127.0.0.1`-l: VPN-is olev teine kasutaja ei näe halduse UI-d enam. UI avaneb tunneli kaudu. Kontroll-image `back`-võrgust annab `/health` JSON-i: teenuste vaheline DNS töötab ka sisemises võrgus.

### 5.5 Kirjutuskaitstud konteinerid

Kirjutuskaitstud juurfailisüsteem tähendab, et konteineris ei saa ükski protsess faile muuta väljaspool kaustu, mille sa eraldi lubad. Veebiserveri kompromiteerimise tavaline järgmine samm on veebijuurde faili lisamine või konfiguratsiooni muutmine. `read_only` lõpetab selle failisüsteemi tasandil, sõltumata sellest, mis kasutajana ründaja protsess töötab. Kirjutuskaitse saavad kaks teenust, mis seda kergesti taluvad.

??? example "Ülesanne: `read_only`"

    ```yaml
      mc01:
        read_only: true
      web01:
        read_only: true
        tmpfs: [/var/cache/nginx, /run, /tmp, /etc/nginx/conf.d]
    ```

    `tmpfs` on kaustad, kuhu Nginx kirjutab. Kausta `/etc/nginx/conf.d` kirjutab entrypoint mallist `default.conf`-i.

```bash
docker compose up -d --wait && docker compose ps web01 mc01
docker compose exec web01 touch /usr/share/nginx/html/x; docker compose exec web01 touch /tmp/x && echo tmp-ok
docker inspect -f '{{.HostConfig.ReadonlyRootfs}} {{json .HostConfig.Tmpfs}}' labori-seis-web01-1
curl -s localhost:8080/health; echo
```

Eemalda ajutiselt `/etc/nginx/conf.d` `tmpfs`-i nimekirjast, uuenda stacki ning vaata `docker compose logs web01 | head -15` ja `curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/health`. Taasta eemaldatud rida.

??? success "Oodatav tulemus"

    `touch` veebijuurde annab `Read-only file system`, `/tmp` on kirjutatav, `ReadonlyRootfs` on `true` ja `/health` on `UP`. Viga tuli tuumalt, mitte Nginx'ilt. Ilma `conf.d` tmpfs'ita ei saanud entrypoint mallist konfiguratsiooni kirjutada ja Nginx näitas vaikelehte. See on tüüpiline viga, kui `read_only` lisatakse ilma teenuse kirjutuskohti uurimata.

### 5.6 Logid: rotatsioon ja journald

Logide puhul on kaks küsimust: kui suureks logifail kasvab ja kuhu logid lõpuks jõuavad. `json-file` draiveri vaikeseade on `max-size: -1`: `*-json.log` kasvab piiramatult ja seda ei pööra ka hosti `logrotate`, mis neid faile ei tunne. Compose'i `logging` kaitseb ainult Compose'i teenuseid. Daemoni vaikeseade kaitseb ka konteinereid, mida keegi Compose'iga ei käivita. Lisa logide piirid faili `/etc/docker/daemon.json`, mille 1.6-s lõid.

??? example "Ülesanne: `/etc/docker/daemon.json`"

    ```json
    {
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "10m",
        "max-file": "3"
      }
    }
    ```

    `max-file` on JSON-is tekst, mitte number.

**Küsimus enne käsku:** mis juhtub töötavate konteineritega, kui daemon taaskäivitub?

```bash
sudo dockerd --validate --config-file /etc/docker/daemon.json
sudo systemctl restart docker
docker info --format '{{.LoggingDriver}}'
docker run --rm -d --name logtest $HUB/alpine:3.22 sleep 30
docker inspect -f '{{json .HostConfig.LogConfig}}' logtest
docker compose ps
```

??? success "Oodatav tulemus"

    Taaskäivitus peatas kõik konteinerid ja stack käivitus uuesti tänu `restart: unless-stopped`-ile. `logtest` sai rotatsiooniseaded daemonilt, mitte käsurealt. `daemon.json`-i `log-opts` kehtib ainult pärast seda loodud konteineritele.

Saada app01 logid hosti journal'isse. Kui logikoguja juba loeb journal'it, kogub see ka need logid ilma lisaseadistuseta.

??? example "Ülesanne: app01 journald"

    `logging` vajab `!override`-i: liitmisel jääksid põhifaili `options` (`max-size`) alles ja journald neid ei tunne.

    ```yaml
      app01:
        logging: !override
          driver: journald
          options:
            tag: "labseis/{{.Name}}"
    ```

    [journald draiver](https://docs.docker.com/engine/logging/drivers/journald/) kirjutab iga rea juurde välja `CONTAINER_NAME`.

```bash
docker compose up -d --wait app01
sudo journalctl CONTAINER_NAME=labori-seis-app01-1 -n 5 --no-pager
sudo journalctl -t labseis/labori-seis-app01-1 -n 200 --no-pager | grep -m1 'Server startup'
docker compose logs app01 | tail -3
```

??? success "Oodatav tulemus"

    `journalctl` leiab app01 read mõlemal viisil ja `docker compose logs` töötab edasi. app01 read on journal'is koos hosti teiste logidega ja filtreeritavad konteineri nime või tag'i järgi.

### 5.7 Volume'i varundus ja taastamine

Volume ilma varukoopiata on ühe `docker compose down -v` kaugusel andmete kaotusest. See käsk on Compose'i veaotsingus soovitatud, ja keegi kasutab seda varem või hiljem valel masinal. Peatad andmebaasi teenuse ja varundad selle volume'i abikonteineriga ja taastad selle uude volume'isse. Andmebaasis on tulemus, mille lisasid 4. osas POST-iga, nii et taastamist kontrollid selle reaga.

```bash
mkdir -p backup && docker compose stop app01 db01
docker run --rm -v labori-seis_dbdata:/data:ro -v "$PWD/backup:/backup" $HUB/ubuntu:24.04 \
    tar czf "/backup/dbdata-$(date +%F).tgz" -C /data .
docker compose start db01 app01; ls -lh backup
```

Taasta arhiiv uude volume'isse nii, et omanikud jäävad numbritena alles:

```bash
docker volume create dbdata-taaste
docker run --rm -v dbdata-taaste:/data -v "$PWD/backup:/backup:ro" $HUB/ubuntu:24.04 \
    tar xzf "/backup/dbdata-$(date +%F).tgz" --numeric-owner -C /data
docker run --rm -v dbdata-taaste:/data $HUB/ubuntu:24.04 ls -ln /data | head -4
```

Käivita taastatud volume'iga eraldi MariaDB konteiner ja küsi oma tulemust:

```bash
docker run -d --name dbtaaste -v dbdata-taaste:/var/lib/mysql $HUB/mariadb:11.4
sleep 20; docker exec dbtaaste mariadb -ulabseis -p"$(cat secrets/DB_PASSWORD)" labseis \
    -e "SELECT lab_code, check_name, status FROM result WHERE lab_code='lab-03'"
docker rm -f dbtaaste && docker volume rm dbdata-taaste
```

??? success "Oodatav tulemus"

    `backup/` all on arhiiv, taastatud failide omanik on `999`, taastatud baas näitab rida `lab-03 compose OK` ja stack on jälle `healthy`. Koopia on kasutatav, mitte ainult olemas. Taastamine ei vajanud root-parooli ega init-skripte: andmekataloog oli valmis ja entrypoint jättis algseadistuse vahele. Seisak kestis `stop`-ist `start`-ini. Suurema baasi puhul seisak pikeneb ja siis on õige valik `mariadb-dump` (vt „Miks see nii töötab“).

    Failikoopia on järjepidev ainult peatatud andmebaasist.

### 5.8 Kettaruum ja koristuspoliitika

Iga ehitus jätab vanad kihid ja cache'i alles ning ketas täitub vaikselt. Täis ketas on konteinerihostis üks levinumaid öiseid rikkeid. Vale koristus on veel hullem: `system prune --volumes` kustutab ka peatatud stacki andmebaasi, ja seda ei saa tagasi võtta. Kirjutad skripti, mis koristab vanuse järgi ega puuduta kunagi andmeid.

```bash
docker system df
docker system df -v | grep -A8 'Build cache' | head -10
docker image ls --filter dangling=true
```

Nõuded failile `prune.sh`: `set -euo pipefail`; võti `-n` näitab ainult, mida koristataks, tundmatu võti annab koodi 2; volume'eid ei puuduta kunagi (`docker volume prune` ja `system prune --volumes` puuduvad); koristab peatatud konteinerid vanemad kui 24 h, `<none>` image'id, kasutamata image'id vanemad kui `KEEP_IMAGES` (vaikimisi `168h`) ja build cache'i vanem kui `KEEP_CACHE` (vaikimisi `72h`); `docker system df` enne ja pärast, kokkuvõte `logger -t labseis-prune` kaudu journal'isse.

??? example "Lahendus: `prune.sh`"

    ```bash
    #!/usr/bin/env bash
    # Dockeri koristus vanuse järgi. Volume'eid ei puuduta kunagi.
    #   ./prune.sh -n   näitab, mida koristataks
    set -euo pipefail

    KEEP_IMAGES=${KEEP_IMAGES:-168h}
    KEEP_CACHE=${KEEP_CACHE:-72h}
    kuiv=0

    while getopts ":n" o; do
        case "$o" in
            n) kuiv=1 ;;
            *) echo "kasutus: $0 [-n]" >&2; exit 2 ;;
        esac
    done

    enne=$(docker system df --format '{{.Type}} {{.Reclaimable}}' | tr '\n' ';')

    if [[ $kuiv -eq 1 ]]; then
        echo "== peatatud konteinerid (koristatakse need, mis on vanemad kui 24 h)"
        docker ps -a --filter status=exited --format '{{.Names}} {{.Status}}'
        echo "== <none> image'id"
        docker image ls --filter dangling=true --format '{{.ID}} {{.CreatedSince}}'
        echo "== image'id ja vanus (kustutatakse kasutamata image'id, mis on vanemad kui $KEEP_IMAGES)"
        docker image ls --format '{{.Repository}}:{{.Tag}} {{.CreatedSince}}'
        echo "== build cache"
        docker system df | grep -i 'build cache'
        exit 0
    fi

    docker container prune -f --filter "until=24h" > /dev/null
    docker image prune -f > /dev/null
    docker image prune -af --filter "until=$KEEP_IMAGES" > /dev/null
    docker builder prune -f --filter "until=$KEEP_CACHE" > /dev/null

    parast=$(docker system df --format '{{.Type}} {{.Reclaimable}}' | tr '\n' ';')
    docker system df
    logger -t labseis-prune "enne: $enne pärast: $parast"
    ```

```bash
sudo apt-get install -y shellcheck
chmod +x prune.sh && shellcheck -S warning prune.sh
./prune.sh -n
```

Vaata kuivkäigu nimekiri üle. Kui seal pole midagi, mida tahad alles hoida, käivita koristus:

```bash
./prune.sh
docker volume ls | grep labori-seis
sudo journalctl -t labseis-prune -n 1 --no-pager
```

??? success "Oodatav tulemus"

    ShellCheck ei anna hoiatusi, `-n` ei muutnud midagi, `RECLAIMABLE` vähenes, `labori-seis_dbdata` ja `labori-seis_rmqdata` on alles ja journal'is on `labseis-prune` rida. `-n` näitas plaani, mitte tegevust: nii testid koristust tootmises enne tegelikku käivitust. Journal'i rida on jälg, mida saad hiljem vaadata, kui keegi küsib, kuhu image kadus.

### 5.9 Tagasi põhistacki peale ja commit

5. kohtumise konveier käivitab ainult `compose.yaml`-i. Kui jätad prod-faili peale, loob konveier app01 vaikevõrku ja see ei leia `back`-võrgus olevat andmebaasi. Seepärast valideerid prod-faili ja lähed tagasi põhistacki peale.

```bash
docker compose config -q && echo "prod OK"
unset COMPOSE_FILE && docker compose up -d --wait && docker compose ps
(cd .. && bash autograde/check.sh k03 compose && bash autograde/check.sh k03 deps)
(cd ~/kursus && git add k03-docker && git commit -m "k03: tootmise erisused, logid, prune.sh" && git push)
git ls-files | grep -E 'secrets|backup'
```

??? success "Oodatav tulemus"

    Viis teenust on põhistackiga `healthy`, `compose` ja `deps` annavad `OK` ja viimane käsk ei väljasta midagi. Prod-fail on Gitis ja valideerub, aga see kehtib ainult siis, kui see käivitamisel teadlikult kaasa võetakse. Nii jääb `compose.yaml` kõigile ühiseks aluseks ja tootmise erisused on ühes failis üle vaadatavad.

??? info "Miks see nii töötab"

    **RabbitMQ parool.** Selles praktikumis kasutatav image `rabbitmq:4.1-management-alpine` ei toeta muutujat `RABBITMQ_DEFAULT_PASS_FILE`. Seetõttu jääb rmq01 parool keskkonnamuutujasse. See on selle image'i piirang. Parooli kasutatakse ainult esimesel käivitusel tühja andmekataloogiga. Parooli saab anda failist, kui mount'id saladuse failina `/etc/rabbitmq/conf.d/20-labseis.conf` ridadega `default_user = labseis` ja `default_pass = …`. See näitab, miks „kasuta alati `_FILE`-muutujat“ ei ole universaalne reegel: image'i ametlik entrypoint määrab, milliseid saladuse edastamise viise teenus tegelikult toetab.

    **Spring Boot'i configtree.** Spring Boot'i configtree loeb kaustast `/run/secrets/` iga faili konfiguratsiooniomaduseks, mille nimi on failinimi. Rakenduse `application.properties` viitab `${DB_PASSWORD}`-ile ja rakendus saab väärtuse failist kätte samamoodi nagu keskkonnamuutujast.

    **Avaldatud port ja `internal` võrk.** `internal: true` võrgul pole ühendust hostist väljapoole, seetõttu ei seo Docker sellise võrgu kaudu konteineri porti hosti pordiga. Avaldatud port (`ports`) vajab vähemalt ühte võrku, mis pole `internal`. Seepärast on rmq01 lisaks `back`-võrgule ka `front`-võrgus: halduse UI port `127.0.0.1:15672` seotakse hostiga `front`-võrgu kaudu.

    **Docker ja hosti tulemüür.** Docker lisab avaldatud portidele oma NAT-reeglid (iptables või nftables). Kas UFW või firewalld neid porte piirab, sõltub tulemüüri taustaprogrammist ja Dockeri versioonist. Tavapärase UFW seadistusega jõuab liiklus avaldatud pordini UFW reeglitest mööda. Seetõttu kontrolli pordi ligipääsetavust eraldi, näiteks teisest masinast käsuga `nc -zv <host> 8080`. Kui porti pole väljast vaja, seo see aadressiga (`127.0.0.1:8080:80`), selle asemel et loota hosti tulemüürile.

    **PID-piir.** PID-piir on cgroup'i `pids.max`. Linuxi protsesside arvestuses kuuluvad lõimed samasse piirangusse, sest tuum loeb iga lõime eraldi ülesandeks. Java teenusele, millel on sadu lõimi, tuleb piir seetõttu seada suuremaks kui Nginx'ile.

    **`read_only` ja `tmpfs`.** Võtmega `read_only` on konteineri juurfailisüsteem kirjutuskaitstud ja ajutised kirjutuskohad (näiteks `/tmp` või Nginx'i vahemälukataloog) tuleb määrata `tmpfs`-ina. `tmpfs` asub mälus ja tühjeneb konteineri peatamisel, seetõttu ei jää ükski muudatus väljaspool volume'eid alles.

    **Saladusefailide piir.** Saladusefailid ei kaitse kõige eest. Hosti root ja iga grupi `docker` liige loevad neid ikkagi, kas hostist või `docker exec`-iga. Need kaitsevad juhuslike lekete eest logis, veateates, `inspect`-i väljundis ja ekraanipildil, mis on intsidentides sagedased lekkekohad.

    **Varukoopia ilma katkestuseta.** Loogiline koopia loeb andmed andmebaasi enda kaudu. `mariadb-dump --single-transaction` loeb InnoDB tabelid ühest tehingust ega vaja seisakut. Koopia on SQL-tekst: taastamine on aeglasem kui failide lahtipakkimine, aga see ei sõltu MariaDB versioonist.

    ```bash
    docker compose exec -T db01 sh -c 'mariadb-dump -uroot -p"$(cat /run/secrets/DB_ROOT_PASSWORD)" --single-transaction labseis' | gzip > backup/labseis.sql.gz
    docker run -d --name dbt -e MARIADB_ROOT_PASSWORD=x -e MARIADB_DATABASE=labseis $HUB/mariadb:11.4
    sleep 20; gunzip -c backup/labseis.sql.gz | docker exec -i dbt mariadb -uroot -px labseis
    docker exec dbt mariadb -uroot -px labseis -e "SELECT COUNT(*) FROM result"; docker rm -f dbt
    ```

    Põhistackiga (ilma prod-failita) on root-parool keskkonnas ja käsus on `-p"$MARIADB_ROOT_PASSWORD"`. Parool `-p` järel on konteineri protsessinimekirjas nähtav, Seda väldib võtmega `--defaults-extra-file` antud fail. Konteineri eripära on see, kust käsk käivitub: `docker compose exec` töötab db01 sees, nii et dump'i tööriist ja serveri versioon on alati samast image'ist. Ilma seisakuta füüsilise koopia annab `mariadb-backup`, mis on samuti MariaDB image'is olemas.

## Osa 6 · Harbor, Trivy ja SBOM

Lükkad oma image'id Harborisse, kust 5. kohtumise konveier ja 7. kohtumise klaster neid tõmbavad. Harbor skannib iga image'i Trivy'ga. Oma projektis seadistad robotkonto, muutumatud tag'id ja haavatava image'i tõmbamise keelu ning lõpus teed rakenduse image'ist SBOM-i. Käsud käivitad kaustas `k03-docker/` põhistackiga (`COMPOSE_FILE` seadmata).

<figure markdown="span">
  ![Control tõmbab Docker Hubi image'id Harbori proxy cache'i kaudu, lükkab oma image'id Harbori projekti, kus Trivy need skannib; sealt tõmbavad mc01 ja db01 Podmaniga, 5. kohtumise konveier ja 7. kohtumise k3s](assets/k03_image_teekond.svg)
  <figcaption>Joonis 3.9. Image'i teekond: Docker Hub, Harbori vahemälu, sinu projekt ja kasutajad (Talvik, 2026).</figcaption>
</figure>

### 6.1 Push Harborisse

Tag'iks saab commit'i lühike SHA, et iga image'i saaks seostada koodiga. Tag `latest` või `dev` ei ütle, mis kood image'is on. Kui midagi läheb katki, ei tea sa, millise versiooni juurde tagasi minna, ega saa tõestada, mis tootmises töötas.

1.5-s logisid Harborisse sisse. Pane `.env`-is tag'iks commit'i SHA, seejärel ehita image'id ja lükka need Harborisse:

```bash
TAG=$(git rev-parse --short HEAD) && sed -i "s/^TAG=.*/TAG=$TAG/" .env
grep -E '^(REGISTRY|OWNER|TAG)=' .env
docker compose build && docker compose push
```

Anna web-image'ile teine nimi ja lükka see ka selle nimega:

```bash
W=harbor.lab.hkhk.lan/<github-kasutaja>/labori-seis-web
docker tag "$W:$TAG" "$W:k03" && docker image ls "$W"
docker push "$W:k03"
```

Ava Harboris oma projekt ja vali **Repositories**.

<figure markdown="span">
  ![Harbori projekti Repositories vaade kolme repositooriumiga labori-seis-app, labori-seis-db ja labori-seis-web](assets/k03_harbor_repositories.png)
  <figcaption>Joonis 3.10. Kolm image'it sinu Harbori projektis (Talvik, 2026).</figcaption>
</figure>

??? success "Oodatav tulemus"

    Harboris on kolm repositooriumi tag'iga `<lühike SHA>`, web-image'i kahel real on sama IMAGE ID ja teine push ütles iga kihi kohta `Layer already exists`. Registry hoiab kihte, mitte terveid image'eid: sama sisuga kiht salvestatakse üks kord. Uus tag on ainult uus nimi sama manifesti juurde, seepärast on IMAGE ID mõlemal real sama.

??? warning "Kui `denied: requested access to the resource is denied`"

    `OWNER` pole sinu Harbori kasutajanimi või logisid sisse teise kasutajana. Kasutajanimi ja projekti nimi on GitHubi kasutajanimi väikeste tähtedega.

??? warning "Kui `x509: certificate signed by unknown authority`"

    CA puudub kaustas `/etc/docker/certs.d/harbor.lab.hkhk.lan/`. Korda 1.5 sertifikaadi samme. `insecure-registries` ei ole lahendus: see lülitab sertifikaadi kontrolli välja ja parool liigub siis serverile, mille identiteeti keegi ei kontrolli.

??? note "Kui Harbor ei vasta: GHCR"

    GitHubi registry GHCR sobib samaks tööks. Loo GitHubis **Settings → Developer settings → Personal access tokens → Tokens (classic)** token õigusega `write:packages` ([juhend](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)).

    ```bash
    sed -i -e 's/^REGISTRY=.*/REGISTRY=ghcr.io/' .env
    docker login ghcr.io -u <github-kasutaja>        # parooliks token
    docker compose build && docker compose push
    ```

    Pakett on vaikimisi privaatne. GitHubis näed seda profiili all **Packages**. Trivy skannimise teed siis ainult käsurealt (6.6) ja Podmani osas logid GHCR-i sisse sama tokeniga, millel on õigus `read:packages`.

### 6.2 Trivy skannib push'i ajal

Harbori projektis on seade **Automatically scan images on push**. Iga uus image skannitakse Trivy'ga kohe pärast push'i ja tulemus on image'i juures. Nii näeb iga image'i kasutaja leide enne tõmbamist, ka siis, kui ise Trivy't käivitama ei hakka.

Ava Harboris `labori-seis-app`. Veerg **Vulnerabilities** näitab leidude arvu raskusastme kaupa. Klõpsa sellel, et näha leide pakettide kaupa.

<figure markdown="span">
  ![Harbori artefakti vaade, Vulnerabilities veerg näitab Critical, High ja Medium leidude arvu](assets/k03_harbor_scan.png)
  <figcaption>Joonis 3.11. Trivy tulemus Harboris app-image'i juures (Talvik, 2026).</figcaption>
</figure>

??? question "Leia Harboris"

    1. Mitu CRITICAL leidu on app-image'il ja mitu db-image'il?
    2. Vali üks CRITICAL leid: mis pakett ja millises versioonis on parandus (`Fixed in version`)?
    3. Mis on image'i **Build History** viimased read ja kust need tulevad?

??? success "Vastus"

    Leide on app-image'il kõige rohkem, peamiselt Java teekides ja Ubuntu pakettides. Web-image'il (Alpine) on neid kõige vähem. Build History on sama, mida näitab `docker history`: Dockerfile'i juhised.

### 6.3 Oma projekti seaded

Oma projektis oled **projectAdmin**: saad seadistada samu asju, mida ettevõtte registry administraator teeb iga meeskonna projektile. Iga seade on üks klõps, aga igal neist on tagajärg. Harbori juhend: [Project configuration](https://goharbor.io/docs/2.14.0/working-with-projects/project-configuration/).

**Muutumatud tag'id.** Ava projekt, **Policy → Tag Immutability → Add Rule**, repositooriumid `**`, tag'id `k03`. Proovi siis sama tag'i üle kirjutada:

```bash
docker tag $HUB/nginx:1.30-alpine "$W:k03"
docker push "$W:k03"
docker tag "$W:$TAG" "$W:k03"
```

Esimene `docker tag` seob nime `k03` teise image'iga (tavalise Nginxiga). Viimane rida tõstab kohaliku nime tagasi sinu web-image'ile.

??? success "Oodatav tulemus"

    Push ebaõnnestub teatega, et tag on muutumatu. Kui keegi lükkab sama tag'i alla uue image'i, saab järgmine `pull` teise sisu, ilma et keegi seda märkaks. Muutumatu tag tähendab, et `k03` jääb igaveseks samaks image'iks. Kustutada saad reegli samast vaatest.

**Haavatava image'i tõmbamise keeld.** **Configuration → Deployment security → Prevent vulnerable images from running**, piiriks **Critical**, salvesta. Seejärel:

**Küsimus enne käsku:** kas oma app-image'i saad veel tõmmata?

```bash
docker image rm "harbor.lab.hkhk.lan/<github-kasutaja>/labori-seis-app:$TAG"
docker pull "harbor.lab.hkhk.lan/<github-kasutaja>/labori-seis-app:$TAG"
```

??? success "Oodatav tulemus"

    Tõmme ebaõnnestub, sest image'il on CRITICAL leide. Harbor keeldub andmast image'it, mida ta peab ohtlikuks, ükskõik kes seda küsib: arendaja, konveier või klaster. Lülita seade välja, muidu ei käivitu stack 6.5-s registry'st. Tootmises lisatakse aktsepteeritud leiud projekti **CVE allowlist**'i koos põhjendusega.

**Robotkonto.** **Robot Accounts → New Robot Account**: nimi `podman`, aegumine 30 päeva, õigus **Repository: Pull**. Salvesta saladus kohe: Harbor näitab seda ainult ühe korra. Seda kontot kasutad 7. osas: AlmaLinuxi server vajab ainult image'i tõmbamist, mitte lükkamist ega kustutamist.

??? success "Oodatav tulemus"

    Kontol on nimi kujul `robot$<github-kasutaja>+podman`. Robotkonto ei saa veebiliidesesse sisse logida ja sellel on ainult need õigused, mis talle andsid.

### 6.4 Tag ja digest

Tag on silt, mida saab ümber tõsta. Digest on manifesti räsi ja ei muutu kunagi. Digest'iga viide tagab, et tootmises töötab täpselt see, mida testisid. Vaatad, et sinu kaks web-tag'i viitavad samale digest'ile, ja tõmbad image'i digest'i järgi.

```bash
docker image inspect -f '{{json .RepoDigests}}' "$W:$TAG" | jq .
D=$(docker image inspect -f '{{index .RepoDigests 0}}' "$W:k03")
docker pull "$D" && docker image ls --digests "$W"
docker compose config --images
docker compose images
```

??? success "Oodatav tulemus"

    `RepoDigests` näitab mõlemal tag'il sama `sha256:` väärtust, `pull "$D"` ütles `Image is up to date` ja `image ls --digests` näitab kaht rida sama digest'iga. Nimi on erinev, sisu sama. `pull` digest'i järgi ei laadinud midagi alla, sest kõik kihid olid olemas. Compose'is ja Kubernetes'es saab image'i kirjutada kujul `nimi@sha256:…`, ja siis ei muuda ükski uus push seda, mis töötab. Harboris näed sama digest'i artefakti real.

### 6.5 Stack registry'st

Kustutad oma image'id kohalikult ja käivitad stacki ainult registry'st: nii käivitavad rakenduse konveier ja Kubernetese klaster. Kui mõni image on ainult sinu masinas, töötab käivitus sinu juures ja ebaõnnestub igal teisel masinal. Seda viga on lihtne mitte märgata, sest sinu masinas on kõik alati olemas.

```bash
docker compose down
docker image rm $(docker compose config --images | grep labori-seis-)
docker compose pull && docker compose up -d --no-build --wait
docker compose images
curl -s http://localhost:8080/version; echo
```

??? success "Oodatav tulemus"

    `pull` tõmbas app-, db- ja web-image'i Harborist (olemasolevad kihid `Already exists`), `docker compose images` näitab Harbori nimesid SHA-tag'iga ja `/version` sama SHA-d. Töötav kood on tõendatavalt see, mis on Gitis. 4. osas lisatud tulemus on andmebaasis alles, sest `down` ilma `-v`-ta ei puuduta volume'eid.

??? warning "Kui `pull` ebaõnnestub teatega `current image with … vulnerabilities cannot be pulled`"

    6.3 tõmbamise keeld on sees. Lülita see projekti **Configuration** all välja.

### 6.6 Trivy käsurealt

Harbor skannib push'i ajal. Sama Trivy töötab ka käsurealt ja konveieris. Trivy loeb image'i kihtidest paketid ja teegid ning võrdleb neid haavatavuste andmebaasiga. OS-paketid tuvastab ta paketihalduri andmebaasist (`/var/lib/dpkg/status`, `/lib/apk/db/installed`) ja Java teegid WAR-i sees olevate JAR-ide `pom.properties` failidest. Allikast kompileeritud C-binaar, millel pole paketi- ega manifestiinfot, jääb skannerile nähtamatuks.

Paigalda Trivy [ametliku juhendi](https://trivy.dev/docs/latest/getting-started/installation/) järgi (Ubuntu apt repositoorium). Esimene käivitus laeb haavatavuste andmebaasi alla.

```bash
sudo curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key -o /etc/apt/keyrings/trivy.asc
sudo tee /etc/apt/sources.list.d/trivy.sources <<EOF
Types: deb
URIs: https://aquasecurity.github.io/trivy-repo/deb
Suites: generic
Components: main
Signed-By: /etc/apt/keyrings/trivy.asc
EOF
sudo apt-get update && sudo apt-get install -y trivy
trivy --version
```

Samad sammud lisad 8. osas rolli.

Skanni kõik kolm image'it ja salvesta tulemus faili:

```bash
R=harbor.lab.hkhk.lan/<github-kasutaja>
for i in app db web; do
    trivy image --severity HIGH,CRITICAL --format table "$R/labori-seis-$i:$TAG"
done > trivy.txt 2>&1
grep -E '^Total|labori-seis' trivy.txt
trivy image -q --severity HIGH,CRITICAL --ignore-unfixed "$R/labori-seis-app:$TAG" | grep -E '^Total'
```

Ava `trivy.txt` ja leia: millises image'is on kõige rohkem leide ja kas need on OS-paketid või Java teegid? Vali üks CRITICAL või HIGH leid: millist paketti leid puudutab ja millises versioonis on parandus (`Fixed Version`)? Mida teed: uuendad baasimage'it, teeki `pom.xml`-is või aktsepteerid riski? Miks?

??? success "Oodatav tulemus"

    `trivy.txt` sisaldab kolme image'i tabelit ja arvud on samas suurusjärgus kui Harboris. Leidude jaotus ütleb, kus tööd teha. OS-paketi leid kaob baasimage'i uuendusega, Java teegi leid vajab `pom.xml`-i muudatust ja uut ehitust. `--ignore-unfixed` vahe näitab, kui paljudega sa praegu midagi teha ei saa. Need on aktsepteerimise või komponendi vahetamise küsimused.

### 6.7 Trivy lähtekoodile ja konfiguratsioonile

Image'it skannitakse pärast ehitust. `fs` ja `config` kontrollivad lähtekoodi ja sobivad seepärast konveieri algusesse, enne kui keegi minuteid ehitusele kulutab. Root'ina töötav image või liiga laialt avatud port on seadistusviga, mida CVE-skannimine ei näe. Selle leiab ainult konfiguratsiooni kontroll, ja just sellised vead teevad haavatavuse ärakasutamise lihtsaks.

```bash
trivy fs --severity HIGH,CRITICAL ..
trivy config --severity HIGH,CRITICAL .
```

Proovi Trivy't konteinerist ja vaata, mida ENTRYPOINT teeb:

```bash
V=$(trivy --version | awk 'NR==1{print $2}')
docker run --rm harbor.lab.hkhk.lan/dockerhub/aquasec/trivy:"$V" --version
docker run --rm harbor.lab.hkhk.lan/dockerhub/aquasec/trivy:"$V" trivy --version
docker run --rm --entrypoint "" harbor.lab.hkhk.lan/dockerhub/aquasec/trivy:"$V" trivy --version
```

??? success "Oodatav tulemus"

    `fs` leidis `pom.xml`-ist Java teegid ilma OS-pakettideta, sest lähtekoodis pole OS-pakette. Image'i skannimine näeb mõlemat. `config` ei märgi app-Dockerfile'i root-kasutaja pärast (db ja web võivad olla märgitud). Konteinerist töötasid esimene ja kolmas käsk, teine andis `unknown command "trivy"`: programm on juba ENTRYPOINT ja teine `trivy` sai argumendiks, sama muster nagu sinu kontroll-image'il. Konveier kasutab Trivy't just konteinerina. `aquasec/trivy` ei ole ametlik image, seepärast on nimes `library` asemel `aquasec`.

### 6.8 SBOM

SBOM (Software Bill of Materials) on image'i komponentide nimekiri. Haavatavuste andmebaas muutub iga päev, image mitte: SBOM-i vastu skannimine ei vaja image'it. Kui avaldatakse uus kriitiline CVE laialt kasutatud teegis (nagu Log4Shell), on esimene küsimus „kus meil see teek on“. SBOM-idega vastad minutitega, ilma kõiki image'eid tõmbamata ja lahti pakkimata.

```bash
trivy image --format cyclonedx --output sbom-app.json "$R/labori-seis-app:$TAG"
jq -r '.bomFormat, .specVersion, (.components | length)' sbom-app.json
jq -r '.components[] | select(.name | test("spring-core|tomcat-embed-core")) | "\(.name) \(.version)"' sbom-app.json
jq -r '[.components[].licenses[]?.license | (.id // .name)] | group_by(.) | map("\(length) \(.[0])") | .[]' sbom-app.json | sort -rn | head -5
trivy sbom --severity HIGH,CRITICAL sbom-app.json | grep -E '^Total'
grep -A2 'labori-seis-app' trivy.txt | grep -E '^Total'
```

Harboris saad SBOM-i teha ka veebiliidesest: artefakti juures **Generate SBOM**. Siis on see registry's image'i kõrval.

??? success "Oodatav tulemus"

    `bomFormat` on `CycloneDX`, komponente on sadu, Springi ja Tomcati versioonid on nähtavad ja `trivy sbom` annab leide samas suurusjärgus kui image'i skannimine. Sama suurusjärk tõestab, et SBOM sisaldab kõike, mida Trivy image'ist leiab. Homme saad sama faili uuesti skannida uuema andmebaasiga. Litsentside päring näitab, et enamik komponente on Apache 2.0 või MIT litsentsiga: SBOM vastab ka küsimusele, kas tohid image'it levitada.

### 6.9 Commit

`trivy.txt` ja `sbom-*.json` on `.gitignore`-is. Raport ja SBOM on ajahetke tulemused ja vananevad kiiresti. Konveieris tehakse need iga ehitusega uuesti ja hoitakse koos image'iga, mitte Giti ajaloos.

```bash
(cd ~/kursus && git add k03-docker && git status --short && git commit -m "k03: Harbor, Trivy ja SBOM" && git push)
```

??? success "Oodatav tulemus"

    Commit on GitHubis ja `git status` ei näita `.env`-i ega `secrets/`-i.

??? info "Miks see nii töötab"

    **Registry sisselogimine.** `~/.docker/config.json` näitab, milliste registry'de autentimisandmed on salvestatud. Kui credential helper puudub, on parool seal Base64-kodeeringus, mitte krüpteeritult, seetõttu ei jagata faili kellegagi.

    **Registry prügikoristus.** Kustutatud tag ei vabasta kohe kettaruumi. Kihid jäävad registry's alles, kuni registry prügikoristus (garbage collection) need eemaldab. Harboris käivitab selle süsteemiadministraator ajakava järgi.

    **Robotkonto ja CI.** Inimese parool konveieris tähendab, et konveieril on kõik inimese õigused ja parooli vahetus katkestab konveieri töö. Robotkontol on ainult vajalik õigus (pull või push), aegumisaeg ja see ei saa veebiliidesesse sisse logida. Seepärast antakse CI-le eraldi robotkonto ja seda ei jagata kasutajate vahel.

    **Pull-through cache ja replikatsioon.** Harbori vahemälu projekt `dockerhub` tõmbab image'i esimesel küsimisel ja hoiab seda. Replikatsioon kopeerib image'eid ajakava järgi kahe registry vahel. Mõlemad on süsteemiadministraatori seaded, sest need puudutavad kogu registry't.

    **Trivy pakettide nimekiri.** `trivy image --list-all-pkgs --format json` näitab kõiki pakette, mille Trivy image'ist leidis. Samast paketiloendist koosneb ka SBOM.

    **`--ignore-unfixed`.** `--ignore-unfixed` peidab leiud, millele parandust veel pole. See sobib konveieri peatamise tingimuseks, aga mitte raportiks, sest parandamata riski peab keegi teadlikult aktsepteerima.

    **X-tee konteinerina.** Samad küsimused tulevad ette ka Eesti riigi taristus. X-tee turvaserverit levitatakse ka konteineri image'ina ([Security Server Sidecar](https://github.com/nordic-institute/X-Road-Security-Server-sidecar)), nii et asutus saab selle käivitada ilma eraldi virtuaalmasinat ehitamata. Ka selle image'i puhul tuleb jälgida versiooni, CVE-sid ja SBOM-i samamoodi nagu praktikumis.

## Osa 7 · Sama teenus Podmaniga

Viid mc01 ja db01 teenused samades AlmaLinuxi masinates Podmani konteineritesse. AlmaLinuxis ja RHEL-is Dockerit vaikimisi pole ja Podman töötab ilma daemonita, tavakasutajana ja systemd teenusena SELinuxiga. Kõik käsud käivitad control'ist kasutajana `kasutaja`, `sudo` ainult seal, kus see on kirjas.

Osa eeldab, et mc01-s ja db01-s töötavad 2. kohtumise teenused `memcached` ja `mariadb` ning app01 Tomcat.

??? warning "Kui 2. kohtumise teenuseid mc01-s, db01-s ja app01-s pole"

    Tee enne 2. kohtumise praktikumi osad 1 ja 2 (`labseis.yml` koos kolme parandusega). Kontroll: `ssh web01 curl -s localhost/health` annab neli `UP`-i.

<figure markdown="span">
  ![Ülal docker CLI, dockerd, containerd, shim, runc ja konteiner; all systemd unit'i sees podman, conmon, crun, konteiner ja pasta](assets/k03_docker_vs_podman.svg)
  <figcaption>Joonis 3.12. Docker klient-serverina ja Podman systemd teenusena (Talvik, 2026).</figcaption>
</figure>

Tabel 3.5 seob Podmani mõisted sellega, mida tegid Dockeriga control'is.

??? note "Tabel 3.5. Docker ja Podman sama töö juures"

    | Docker control'is | Podman mc01-s ja db01-s |
    |---|---|
    | `dockerd` root'ina, socket `/var/run/docker.sock` | daemonit pole, iga konteineri juures `conmon`, kasutaja `kasutaja` |
    | `restart: unless-stopped` | systemd unit `Restart=on-failure`, `[Install] WantedBy=default.target` |
    | `compose.yaml` teenus | `~/.config/containers/systemd/<nimi>.container` |
    | nimega volume | `<nimi>.volume` või `Volume=nimi:/tee` |
    | `secrets:` failist | `podman secret` + `Secret=` |
    | `deploy.resources.limits.memory` | `MemoryMax=` unit'i cgroup'is |
    | `/etc/docker/certs.d/` | `/etc/containers/certs.d/` |
    | `$HUB` image'i nimes | `registries.conf` mirror, nimi jääb `docker.io/…` |

### 7.1 Podman hostis

Enne muudatust teed mõlemast VM-ist snapshot'i ja kontrollid, milline Podman on paigaldatud. Quadleti võtmed `Notify=healthy` ja `HealthOnFailure=` vajavad Podmani 5. põhiversiooni. Vanem versioon annab `daemon-reload`-il vea, mis ei ütle, et põhjus on versioonis.

Proxmoxis tee mc01-st ja db01-st snapshot `enne-podman` ilma RAM-ita. Seejärel paigalda Podman ja kontrolli versiooni, rootless-režiimi, cgroup'i versiooni, võrgu taustaprogrammi ja `subuid` vahemikku:

```bash
for h in mc01 db01; do
    ssh "$h" 'hostname; command -v podman >/dev/null || sudo dnf install -y -q podman; podman --version
        podman info --format "rootless={{.Host.Security.Rootless}} cgroup={{.Host.CgroupsVersion}} net={{.Host.NetworkBackend}} store={{.Store.GraphDriverName}}"
        grep "^$USER:" /etc/subuid; sysctl -n net.ipv4.ip_unprivileged_port_start; getenforce'
done
```

??? success "Oodatav tulemus"

    Mõlemal VM-il on snapshot `enne-podman`, Podman on 5.x, väljund ütleb `rootless=true cgroup=v2 net=netavark store=overlay`, `subuid` rida on olemas ja `getenforce` annab `Enforcing`.

    Rootless tähendab, et kõik konteinerid töötavad kasutaja `kasutaja` user namespace'is: konteineri UID 0 on hostis `kasutaja`, ülejäänud UID-d tulevad `/etc/subuid` vahemikust. Pordid 11211 ja 3306 on üle `ip_unprivileged_port_start` piiri, nii et kumbki ei vaja sysctl'i muutmist.

??? warning "Kui `rootless=false` või käsk küsib parooli"

    Käsk käivitus `sudo`-ga või `su`-ga. Rootless vajab kasutaja sessiooni (`/run/user/<UID>`), mille loob ainult SSH- või konsoolisisselogimine (`pam_systemd`). `sudo -u` seda ei tee.

### 7.2 Image Harborist

AlmaLinuxi host tõmbab samad image'id samast registry'st kui control, aga Podmani seadistus on teises kohas. Docker Hubi image'id tulevad Harbori vahemälu kaudu ja sinu image'id 6.3-s loodud robotkontoga, millel on ainult tõmbamise õigus: server ei vaja õigust image'eid lükata ega kustutada.

Podman oskab seda, mida Docker ei oska: peegel võib olla registry projekti all. Kirjuta faili `/etc/containers/registries.conf.d/50-harbor.conf`, et `docker.io` image'id tuleksid Harborist ja image'i nimi jääks `docker.io/library/…`:

??? example "Ülesanne: peegel ja CA mõlemasse masinasse"

    ```bash
    for h in mc01 db01; do
        scp roles/docker/files/harbor-ca.crt "$h":/tmp/harbor-ca.crt
        ssh "$h" 'sudo mkdir -p /etc/containers/certs.d/harbor.lab.hkhk.lan
            sudo cp /tmp/harbor-ca.crt /etc/containers/certs.d/harbor.lab.hkhk.lan/ca.crt
            printf "[[registry]]\nlocation = \"docker.io\"\n\n[[registry.mirror]]\nlocation = \"harbor.lab.hkhk.lan/dockerhub\"\n" |
                sudo tee /etc/containers/registries.conf.d/50-harbor.conf'
    done
    ```

    `[[registry]]` kirjeldab registry't, mille nime image kasutab. `[[registry.mirror]]` on koht, kust Podman proovib esimesena tõmmata. Kui peegel ei vasta, proovib Podman `docker.io`-d ennast. CA läheb kausta `certs.d`, mitte `--tls-verify=false`.

Tõmba mc01-s `docker.io/library/memcached:1.6-alpine` ja db01-s oma `labori-seis-db` sama tag'iga, mis Harboris. Robotkonto nimes on `$`, seepärast on nimi ülakomade vahel. Sisselogimise andmed salvestuvad faili, mis säilib ka pärast taaskäivitust (`--authfile ~/.config/containers/auth.json`).

```bash
R=harbor.lab.hkhk.lan/<github-kasutaja>; TAG=<Harbori TAG>
docker image inspect -f '{{index .RepoDigests 0}}' "$R/labori-seis-db:$TAG"
ssh -t db01 "podman login --authfile ~/.config/containers/auth.json harbor.lab.hkhk.lan -u 'robot\$<github-kasutaja>+podman' &&
    podman pull -q $R/labori-seis-db:$TAG && podman image inspect --format '{{json .RepoDigests}}' $R/labori-seis-db:$TAG"
ssh mc01 'podman --log-level=debug pull docker.io/library/memcached:1.6-alpine 2>&1 | grep -m1 "Trying to access"'
```

??? success "Oodatav tulemus"

    db01-s on `labori-seis-db` sama tag'iga, Dockeri `RepoDigests` väärtus on Podmani `RepoDigests` nimekirjas ja `~/.config/containers/auth.json` on db01-s olemas. mc01 debug-rida näitab `Trying to access "harbor.lab.hkhk.lan/dockerhub/library/memcached:1.6-alpine"`: tõmme läks Harbori kaudu.

    Sama digest kahes eri tööriistas tõestab, et OCI image ei sõltu käitusprogrammist (runtime): kihid ja manifest on samad baidid. Vaikimisi kirjutab `podman login` faili `$XDG_RUNTIME_DIR/containers/auth.json`, mis on tmpfs'is ja kaob taaskäivitusel. Kasutaja teenus, mis peab image'i hiljem uuesti tõmbama, ei leiaks siis volitusi.

??? warning "Kui `Error: short-name \"memcached:1.6-alpine\" did not resolve`"

    Kirjuta image täisnimega `docker.io/library/memcached:1.6-alpine`. `short-name-mode = "enforcing"` ei luba ilma terminalita registry't valida ja systemd teenusel terminali pole.

### 7.3 mc01: teenus konteineriks

Alustad lihtsamast teenusest, mille olek ei pea alles jääma. Peatad native Memcachedi, käivitad sama pordiga konteineri ja vaatad hostist, milline protsess on millise vanemprotsess. Kontrolli teenust sealt, kust seda kasutatakse: app01 `/health` web01 kaudu.

```bash
ssh mc01 'sudo systemctl disable --now memcached
    podman run -d --name mc-proov -p 11211:11211 docker.io/library/memcached:1.6-alpine
    ps -o pid,ppid,user,cmd -C conmon,memcached,pasta'
sleep 15; curl -s http://web01/health; echo
ssh mc01 'podman rm -f mc-proov'
```

??? success "Oodatav tulemus"

    `/health` näitas `"cache":"UP"` ilma app01 taaskäivituseta. `ps` näitas kolme protsessi. `memcached` töötab UID-ga `subuid` vahemikust, mitte root'ina ega `kasutaja`-na. Selle vanem on `conmon`, mis hoiab konteineri stdio't ja väljumiskoodi. Porti hoiab `pasta`, mis kuulab hostis kasutaja õigustega ja suunab ühendused konteineri võrgu namespace'i. `podman` protsessi ennast enam pole: käsk lõpetas töö pärast käivitamist ja ühtegi daemonit, mille taaskäivitus konteineri peataks, ei ole. Seepärast ei käivita seda konteinerit pärast masina taaskäivitust ka keegi uuesti.

### 7.4 Quadlet: konteiner systemd teenusena

Quadlet on systemd generaator: `systemctl --user daemon-reload` loeb kaustast `~/.config/containers/systemd/` faile `.container`, `.volume` ja `.network` ning genereerib neist tavalised `.service` unit'id. Sina kirjeldad konteinerit, systemd hoiab seda töös.

Nõuded failile mc01-s `~/.config/containers/systemd/labseis-mc.container` ([võtmete viide](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)): image täisnimega ja versiooni tag'iga, konteineri nimi `labseis-mc`, port 11211; healthcheck sama käsuga mis Compose'i mc01-l, `unhealthy` olek lõpetab konteineri ja `systemctl --user start` ootab `healthy` olekut; `[Service]`: taaskäivitus vea korral ja mälupiir 128 MB; `[Install]`: teenus käivitub koos kasutaja systemd'ga.

??? example "Lahendus: `labseis-mc.container`"

    ```ini
    [Unit]
    Description=Labori seis: memcached

    [Container]
    Image=docker.io/library/memcached:1.6-alpine
    ContainerName=labseis-mc
    PublishPort=11211:11211
    HealthCmd=sh -c 'echo stats | nc -w 1 127.0.0.1 11211 | grep -q uptime'
    HealthInterval=10s
    HealthRetries=3
    HealthOnFailure=kill
    Notify=healthy

    [Service]
    Restart=on-failure
    MemoryMax=128M

    [Install]
    WantedBy=default.target
    ```

    Kirjuta fail mc01-sse:

    ```bash
    ssh mc01 'mkdir -p ~/.config/containers/systemd && cat > ~/.config/containers/systemd/labseis-mc.container' < labseis-mc.container
    ```

Vaata enne käivitamist, mis unit'i generaator teeb, ja käivita teenus:

```bash
ssh mc01 '/usr/libexec/podman/quadlet -dryrun -user | grep -E "^ExecStart|^MemoryMax|^Restart"
    systemctl --user daemon-reload && systemctl --user start labseis-mc
    systemctl --user status labseis-mc --no-pager | head -5; podman healthcheck run labseis-mc && echo healthy'
```

Luba kasutaja teenustel käivituda ilma sisselogimiseta ja tee taaskäivituse test. Kontrolli väljast enne SSH-sisselogimist, sest sisselogimine ise käivitab kasutaja systemd ja peidaks vea.

```bash
ssh mc01 'sudo loginctl enable-linger kasutaja && sudo systemctl reboot'; sleep 90
curl -s http://web01/health; echo
ssh mc01 'systemctl --user is-active labseis-mc; loginctl show-user kasutaja -p Linger'
```

??? success "Oodatav tulemus"

    `-dryrun` näitas `ExecStart=/usr/bin/podman run … --name labseis-mc …`, teenus on `active` ja `healthy`, pärast taaskäivitust andis `/health` enne sisselogimist `"cache":"UP"` ja `Linger=yes`.

    `systemctl --user enable labseis-mc` annab vea, sest genereeritud unit'it ei saa lubada: käivituse annab `[Install]` jaotis Quadleti failis, mille generaator muudab `default.target.wants` lingiks. `-dryrun` väljund näitab, et `MemoryMax` ja `Restart` on tavalised systemd võtmed ja `podman run` on ainult `ExecStart` rida.

??? warning "Kui `daemon-reload` järel `Unit labseis-mc.service not found`"

    Fail on vales kaustas, vale laiendiga või tundmatu võtmega (vanem Podman). Generaator jätab vigase faili vahele ja kirjutab põhjuse ainult `-dryrun` väljundisse ja journal'isse.

### 7.5 db01 SELinuxiga

Muudatus tehakse tootmise reeglite järgi: andmebaas kolib native teenusest konteinerisse hooldusaknas, ükski tulemus ei kao, parool ei satu üheski kohas keskkonnamuutujasse ega käsureale ja SELinux jääb režiimi `Enforcing`. Andmed tulevad native MariaDB dump'ist, mille konteiner impordib esimesel käivitusel.

Ava hooldusaken: peata app01 Tomcat, et dump'i ja vahetuse vahel ei tuleks kirjeid juurde, ning salvesta algseis.

```bash
ssh app01 sudo systemctl stop tomcat10
ssh db01 "sudo mariadb -N -e 'SELECT COUNT(*) FROM labseis.result'"
ssh db01 'mkdir -p ~/labseis && sudo mariadb-dump --single-transaction labseis > ~/labseis/03-dump.sql &&
    chmod 644 ~/labseis/03-dump.sql && ls -Z ~/labseis/03-dump.sql'
```

Loo kaks `podman secret`-it: `labseis-db-pass` 2. kohtumise Vaulti väärtusega `vault_db_password` (app01 kasutab sama parooli) ja `labseis-db-root` uue juhusliku väärtusega. Väärtus läheb `podman secret create <nimi> -` sisendisse (stdin), mitte käsurea argumendiks, ja shelli muutuja kustutatakse kohe pärast kasutamist.

??? example "Lahendus: saladused"

    ```bash
    cd ../k02-ansible
    P=$(ansible-vault view group_vars/all/vault.yml | awk '/^vault_db_password:/ {print $2}' | tr -d '"')
    cd ../k03-docker
    printf '%s' "$P" | ssh db01 podman secret create labseis-db-pass -
    unset P
    ssh db01 'openssl rand -base64 18 | tr -d "\n" | podman secret create labseis-db-root -; podman secret ls'
    ```

    Kui Vaulti fail on teises kohas või võti teise nimega, leia see `grep -rn vault_db ../k02-ansible`. Kui 2. kohtumise Vault on tegemata, on parool otse `labseis.yml`-is.

Nõuded failidele db01-s `labseis-db.volume` ja `labseis-db.container`: image sinu `labori-seis-db` tag'iga, konteineri nimi `labseis-db`, port 3306, andmed `.volume` failist `/var/lib/mysql` alla; `~/labseis/03-dump.sql` bind mount'ina `/docker-entrypoint-initdb.d/03-dump.sql` kirjutuskaitstud kujul, **esimesel katsel ilma SELinuxi sildita**; paroolid `Secret=` ridadelt failidena ja image'i `MARIADB_*_FILE` muutujatega, andmebaas ja kasutaja `labseis`; healthcheck sama käsuga mis Compose'i db01-l, `start` ootab `healthy` olekut, käivitusaeg vähemalt 300 s; mälupiir 512 MB, taaskäivitus vea korral, `[Install]` nagu mc01-l.

??? example "Lahendus: `labseis-db.volume` ja `labseis-db.container` (esimene katse)"

    ```ini
    # labseis-db.volume
    [Volume]
    VolumeName=labseis-db-data
    ```

    ```ini
    # labseis-db.container
    [Unit]
    Description=Labori seis: MariaDB

    [Container]
    Image=harbor.lab.hkhk.lan/<github-kasutaja>/labori-seis-db:<TAG>
    ContainerName=labseis-db
    PublishPort=3306:3306
    Volume=labseis-db.volume:/var/lib/mysql
    Volume=%h/labseis/03-dump.sql:/docker-entrypoint-initdb.d/03-dump.sql:ro
    Secret=labseis-db-pass,type=mount,target=/run/secrets/labseis-db-pass
    Secret=labseis-db-root,type=mount,target=/run/secrets/labseis-db-root
    Environment=MARIADB_DATABASE=labseis MARIADB_USER=labseis
    Environment=MARIADB_PASSWORD_FILE=/run/secrets/labseis-db-pass
    Environment=MARIADB_ROOT_PASSWORD_FILE=/run/secrets/labseis-db-root
    HealthCmd=healthcheck.sh --connect --innodb_initialized
    HealthInterval=10s
    HealthRetries=10
    HealthStartPeriod=300s
    Notify=healthy

    [Service]
    Restart=on-failure
    MemoryMax=512M
    TimeoutStartSec=600

    [Install]
    WantedBy=default.target
    ```

    `labseis-db.volume:` viitab teisele Quadleti failile: generaator loob volume'i enne konteinerit. `%h` on kasutaja kodukaust. `TimeoutStartSec` peab olema pikem kui algseadistus, sest `Notify=healthy` hoiab teenuse olekus `activating`, kuni healthcheck õnnestub.

    ```bash
    for f in labseis-db.volume labseis-db.container; do
        ssh db01 "mkdir -p ~/.config/containers/systemd && cat > ~/.config/containers/systemd/$f" < "$f"
    done
    ```

Peata native MariaDB, käivita konteiner ja leia, miks esimene käivitus ebaõnnestus. `systemctl --user status` võib minuti pärast näidata `active`: `Restart=on-failure` tegi teise katse. Vaata esimest käivitust journal'ist.

```bash
ssh db01 'sudo systemctl disable --now mariadb
    systemctl --user daemon-reload; systemctl --user start labseis-db
    journalctl --user -u labseis-db --no-pager | grep -m3 -iE "denied|initdb|error"
    sudo ausearch -m avc -ts recent | grep -m2 03-dump'
```

**Hüpotees:** kirjuta K3 issue'sse, miks konteiner ei saa lugeda faili, millel on õigused `644`.

??? tip "Tõend"

    Journal'is ja `ausearch` väljundis on `03-dump.sql` keeld: `denied { read }`, `scontext=…container_t`, `tcontext=…user_home_t`. Konteineri protsess töötab domeenis `container_t` ja dump'il on silt `user_home_t`. Poliitika keelab lugemise, kuigi failiõigused lubavad. Ubuntu control'is Docker seda ei näita, sest seal SELinuxit pole.

Paranda bind mount'i rida. Enne uut käivitust mõtle, mis olekus on volume pärast poolikut algseadistust ja pärast teist katset, ning tee nii, et import käivitub uuesti.

??? example "Paranda"

    `:Z` annab failile sildi `container_file_t` koos selle konteineri MCS kategooriatega, nii et teine konteiner sama faili lugeda ei saa. `:z` jagatud sildiga lubaks.

    ```ini
    Volume=%h/labseis/03-dump.sql:/docker-entrypoint-initdb.d/03-dump.sql:ro,Z
    ```

    Volume algseadistati esimesel katsel poolikult: kataloog, skeem ja algandmed tekkisid, enne kui dump'i lugemine ebaõnnestus. Teine katse leidis valmis kataloogi ja jättis impordi vahele. Seepärast tühjendad volume'i:

    ```bash
    ssh db01 'systemctl --user stop labseis-db; podman volume rm labseis-db-data
        systemctl --user daemon-reload && systemctl --user start labseis-db'
    ```

Kontrolli ridade arvu, silti ja paroolide asukohta, siis sulge hooldusaken:

```bash
ssh db01 'ls -Z ~/labseis/03-dump.sql
    podman exec labseis-db sh -c "MYSQL_PWD=\$(cat /run/secrets/labseis-db-pass) mariadb -ulabseis -N -e \"SELECT COUNT(*) FROM labseis.result\""
    podman inspect labseis-db --format "{{.Config.Env}}" | grep -oiE "[a-z_]*pass[a-z_]*=[^ ]*"
    systemctl --user cat labseis-db | grep -iE "secret|pass"; getenforce'
ssh app01 sudo systemctl start tomcat10; sleep 30; curl -s http://web01/health; echo
```

??? success "Oodatav tulemus"

    Failil on pärast parandust silt `container_file_t`, ridade arv konteineris võrdub algseisuga, `podman inspect` ei näita ühtegi parooli väärtust (ainult `_FILE` teed), `systemctl --user cat` näitab ainult `Secret=` ja `_FILE` ridu, `getenforce` on endiselt `Enforcing` ja `/health` annab `"db":"UP"`.

    Teine katse oli `active`, sest MariaDB entrypoint algseadistab ainult tühja andmekataloogi. Teenus töötas, aga andmed polnud täielikud, ja seda näitas ainult ridade arv.

??? warning "Kui app01-s pole teenust `tomcat10`"

    Vaata nime: `ssh app01 systemctl list-units 'tomcat*'`.

### 7.6 Piirangud cgroup'is

Rootless-režiimis kehtib piirang ainult siis, kui systemd on kasutaja teenusele vastava cgroup'i kontrolleri delegeerinud. Vaatad, kus `MemoryMax` tegelikult kehtib ja milliseid piiranguid sa sellel hostil üldse seada saad.

```bash
ssh mc01 'cg=$(systemctl --user show -p ControlGroup --value labseis-mc)
    systemd-cgls --no-pager --user-unit labseis-mc | head -6
    cat "/sys/fs/cgroup$cg/memory.max"
    cat "/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers"
    podman run --rm --memory 64m docker.io/library/memcached:1.6-alpine cat /sys/fs/cgroup/memory.max
    podman run --rm --cpus 0.5 docker.io/library/memcached:1.6-alpine true; echo "cpus kood $?"'
```

??? success "Oodatav tulemus"

    `memory.max` on `134217728`, `--memory 64m` konteiner näitas `67108864`. `systemd-cgls` näitas, et `conmon` ja konteineri protsess on mõlemad unit'i `labseis-mc.service` cgroup'is: Quadlet käivitab konteineri `--cgroups=split`-iga, nii et unit'i `MemoryMax` piirab kogu teenust koos `conmon`-iga. `--memory` ja `--cpus` töötavad ainult siis, kui `cgroup.controllers` loetelus on `memory` ja `cpu`.

### 7.7 Docker API ja Kubernetese YAML

Osa tööriistu (Trivy, Testcontainers, CI agendid) eeldab Dockeri socket'it. Podman pakub sama REST API-t kasutaja socket'il ilma root-daemonita. Proovid, kui kaugele see ühilduvus ulatub, ja teed töötavast konteinerist Kubernetese manifesti.

Lülita mc01-s sisse API socket ja saada päring otse sellele, siis control'i `docker` CLI-ga üle SSH-tunneli:

```bash
ssh mc01 'systemctl --user enable --now podman.socket
    curl -s --unix-socket "$XDG_RUNTIME_DIR/podman/podman.sock" http://d/version | python3 -m json.tool | grep -E "\"(Version|ApiVersion|Name)\"" | head -5'
U=$(ssh mc01 id -u); rm -f /tmp/mc01-podman.sock
ssh -fNL /tmp/mc01-podman.sock:/run/user/$U/podman/podman.sock mc01
DOCKER_HOST=unix:///tmp/mc01-podman.sock docker ps
DOCKER_HOST=unix:///tmp/mc01-podman.sock docker inspect -f '{{.State.Health.Status}}' labseis-mc
```

Tee töötavast konteinerist Kubernetese YAML ja käivita see teise pordiga pod'ina:

```bash
ssh mc01 'podman kube generate labseis-mc > ~/labseis-mc-kube.yaml && grep -E "kind|image|hostPort" ~/labseis-mc-kube.yaml
    sed "s/hostPort: 11211/hostPort: 11212/" ~/labseis-mc-kube.yaml > ~/labseis-mc-11212.yaml
    podman kube play ~/labseis-mc-11212.yaml && sleep 3
    exec 3<>/dev/tcp/127.0.0.1/11212; printf "version\r\n" >&3; read -r -t 3 l <&3; echo "$l"
    podman kube down ~/labseis-mc-11212.yaml'
```

??? success "Oodatav tulemus"

    `/version` näitas Podmani komponenti ja API versiooni, pod vastas pordil 11212 `VERSION 1.6…`-ga ja on maha võetud. `docker` CLI ei tea, et teisel pool on Podman: see räägib sama HTTP API-ga ja leppis kokku vanema API versiooni, mida server toetab. Mis ei tööta, on peaaegu alati Dockeri-spetsiifiline lisa (Swarm, BuildKit'i võtmed, pluginad). `kube generate` andis `Pod` objekti, mille sees on sama image ja port. Healthcheck ja `MemoryMax` sinna ei jõua, sest need on systemd poolel.

### 7.8 Tagasi algseisu ja commit

Quadleti failid lähevad Giti ja masinad lähevad tagasi native teenustele: 4. kohtumine ja Ansible'i rollid eeldavad, et db01-s ja mc01-s töötavad `mariadb` ja `memcached` systemd teenustena. Konteineri ajal lisatud tulemused jäävad volume'isse ja native baasi tagasi ei tule.

```bash
mkdir -p quadlet
scp mc01:.config/containers/systemd/labseis-mc.container 'db01:.config/containers/systemd/labseis-db.*' quadlet/
```

Vii masinad tagasi algseisu ühel kahest viisist: Proxmoxi snapshot'i `enne-podman` rollback või käsitsi (teenused peatatud, Quadleti failid kaustast `~/.config/containers/systemd/` välja, `daemon-reload`, `podman.socket` välja, native teenused `enable --now`). Seejärel kontrolli, et seis vastab algseisule:

```bash
for h in mc01 db01; do ssh "$h" 'systemctl --user list-units "labseis-*" --no-legend; sudo ss -tlnp | grep -E ":(3306|11211) "'; done
(cd ../k02-ansible && ansible-playbook site.yml --limit db,cache | tail -3)
curl -s http://web01/health; echo
(cd ~/kursus && git add k03-docker && git status --short && git commit -m "k03: sama teenus Podmaniga" && git push)
```

??? success "Oodatav tulemus"

    Kummaski masinas pole `labseis-*` unit'eid, porte 3306 ja 11211 kuulavad otse masinasse paigaldatud teenused, `ansible-playbook` andis `changed=0`, `/health` on `UP` ja commit on GitHubis. Kui 2. kohtumise rollid on tegemata, käivita `site.yml` asemel `labseis.yml`.

??? info "Miks see nii töötab"

    **Fork/exec, mitte klient-server.** `docker run` saadab päringu daemonile ja konteineri vanem on `containerd-shim`. `podman run` on tavaline programm, mis loob konteineri ise (`crun` kaudu), jätab selle juurde `conmon`-i ja lõpetab.

    **Quadlet on generaator.** `daemon-reload` käivitab generaatori `/usr/lib/systemd/user-generators/podman-user-generator`, mis kirjutab `.service` failid kausta `$XDG_RUNTIME_DIR/systemd/generator/`. Need failid on ajutised ja tehakse iga `daemon-reload`-iga uuesti, seepärast muudad ainult `.container` faili. Varasem `podman generate systemd` on aegunud: see tegi staatilise unit'i, mis ei uuenenud koos konteineri seadistusega.

    **Linger.** Kasutaja systemd (`user@<UID>.service`) käivitub tavaliselt esimese sisselogimisega ja lõpetab viimase väljalogimisega. `loginctl enable-linger` loob faili `/var/lib/systemd/linger/<kasutaja>`, ja siis käivitub kasutaja systemd masina käivitumisel ning `default.target` käivitab Quadleti teenused.

    **SELinuxi sildid.** AlmaLinuxi poliitikas tohib `container_t` protsess lugeda ja kirjutada ainult sildiga `container_file_t` faile. Podman paneb `:Z` sildi iga konteineri käivitusel uuesti, `:z` annab ühise sildi ilma MCS kategooriateta. Kodukaustale või `/etc`-le ega nende suurtele alamkaustadele `:Z`-d ei panda: silt muutub kogu puul ja hosti teised teenused võivad ligipääsu kaotada. Kui dump'i hiljem kustutad, eemalda ka `Volume=` rida, muidu ei käivitu konteiner, sest bind mount'i allikas puudub.

    **Registry peegel projekti all.** Podmani `registries.conf` lubab peeglil olla tee (`harbor.lab.hkhk.lan/dockerhub`). Image'i nimi jääb `docker.io/library/…` ja sama Quadleti fail töötab nii peegliga kui ilma. Dockeri `registry-mirrors` toetab ainult registry juurt.

    **Rootless võrk.** `pasta` tõlgib konteineri namespace'i võrgupaketid hosti tavalisteks socket'iteks kasutaja õigustega. Sissetulev ühendus läbib hosti `firewalld`-i nagu native teenuse puhul, nii et 2. kohtumisel avatud pordid kehtivad ka konteinerile. Rootful Dockeri NAT-reegleid, mis lähevad tulemüürist mööda, siin pole.

    **Healthcheck Podmanis.** Podman käivitab healthcheck'i systemd taimeriga, mitte daemoni sees. `HealthOnFailure=kill` lõpetab `unhealthy` konteineri ja unit'i `Restart=` käivitab selle uuesti: seda Docker Compose ei tee. `Notify=healthy` hoiab unit'i olekus `activating`, kuni healthcheck läbib, nii et teised unit'id saavad sellest `After=`-iga sõltuda.

    **Kahe tööriista hind.** Podman sobib serverisse, kus töötab üks või paar teenust ja AlmaLinux/RHEL on standard: systemd, journald, SELinux ja auditilogi on samad mis teistel teenustel. Docker jääb arendusmasinasse, CI-sse ja sinna, kus tööriistad eeldavad Compose'i ja Dockeri socket'it. Kubernetes võtab mõlemast sama OCI image'i.

## Osa 8 · Docker rolliga

Kirjutad osades 1, 5 ja 6 käsitsi tehtud sammud rolliks `docker`. Teises masinas tuleks kõik sammud samas järjekorras korrata ja üks unustatud samm, näiteks CA, annab vea alles esimesel `docker pull`-il. Rakendad rolli control'ile, kus Docker juba töötab, ja teine käivitus peab andma `changed=0`.

### 8.1 Roll `docker`

2. kohtumisel koondasid iga teenuse ülesanded rolli. Docker on samasugune teenus: pakettide repositoorium, paketid, konfiguratsioonifail, teenus ja kasutaja õigused.

Fail `docker.yml` on starteris olemas. See käivitab rolli control'is endas:

```yaml
- name: Docker control node'is
  hosts: localhost
  connection: local
  become: true
  roles:
    - docker
```

`hosts: localhost` koos `connection: local`-iga tähendab, et Ansible ei ühendu SSH-ga ja käivitab moodulid samas masinas. Inventory't pole vaja.

Vaata üle sammud, mida tegid käsitsi osades 1.2, 1.5, 1.6, 5.6 ja 6.6, ja kirjuta iga samm rolli ülesandeks. Roll teeb samad sammud moodulitega. Starteris on ainult kaust `roles/docker/files`, ülejäänud kaustad loo ise:

```bash
mkdir -p roles/docker/{defaults,tasks,templates,handlers}
```

??? example "Ülesanne: `roles/docker/defaults/main.yml`"

    Vaikeväärtused: kes saab grupi `docker` liikmeks, Harbori nimi ja logide piirid.

    ```yaml
    docker_kasutaja: "{{ ansible_env.SUDO_USER | default(ansible_user_id) }}"
    harbor_nimi: harbor.lab.hkhk.lan
    docker_log_max_size: 10m
    docker_log_max_file: 3
    ```

    `become: true` korral käivitab Ansible moodulid `sudo` kaudu. `SUDO_USER` on kasutaja, kes playbook'i käivitas, mitte `root`.

??? example "Ülesanne: repositoorium ja paketid (`roles/docker/tasks/main.yml`)"

    Moodul [`deb822_repository`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/deb822_repository_module.html) kirjutab faili `/etc/apt/sources.list.d/docker.sources`, sama faili, mille 1.2-s käsitsi tegid.

    ```yaml
    - name: Moodul deb822_repository vajab python3-debian paketti
      ansible.builtin.apt:
        name: python3-debian
        state: present
        update_cache: true

    - name: Ubuntu Dockeri paketid eemal
      ansible.builtin.apt:
        name: [docker.io, docker-compose, docker-compose-v2, podman-docker, containerd, runc]
        state: absent

    - name: Dockeri võtmete kaust
      ansible.builtin.file:
        path: /etc/apt/keyrings
        state: directory
        mode: "0755"

    - name: Dockeri GPG võti
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/ubuntu/gpg
        dest: /etc/apt/keyrings/docker.asc
        mode: "0644"

    - name: Dockeri apt-repositoorium
      ansible.builtin.deb822_repository:
        name: docker
        types: [deb]
        uris: https://download.docker.com/linux/ubuntu
        suites: ["{{ ansible_distribution_release }}"]
        components: [stable]
        signed_by: /etc/apt/keyrings/docker.asc

    - name: Docker Engine ja Compose
      ansible.builtin.apt:
        name: [docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin]
        state: present
        update_cache: true
    ```

    `ansible-doc ansible.builtin.deb822_repository`: mis vahe on võtmetel `uris` ja `suites`?

??? example "Ülesanne: daemoni seaded ja Harbori CA (jätka sama faili)"

    Võti `validate` kontrollib uut faili enne, kui see õigesse kohta kopeeritakse, nagu `dockerd --validate` 1.6-s: vigane fail ei jõua kunagi `/etc/docker` alla. Handler taaskäivitab Dockeri ainult siis, kui fail muutus.

    ```yaml
    - name: Daemoni seaded
      ansible.builtin.template:
        src: daemon.json.j2
        dest: /etc/docker/daemon.json
        mode: "0644"
        validate: dockerd --validate --config-file %s
      notify: Docker uuesti

    - name: Harbori sertifikaadi kaust Dockerile
      ansible.builtin.file:
        path: "/etc/docker/certs.d/{{ harbor_nimi }}"
        state: directory
        mode: "0755"

    - name: Harbori CA Dockerile
      ansible.builtin.copy:
        src: harbor-ca.crt
        dest: "/etc/docker/certs.d/{{ harbor_nimi }}/ca.crt"
        mode: "0644"

    - name: Harbori CA süsteemi usaldatud sertifikaatide hulka (curl, Trivy)
      ansible.builtin.copy:
        src: harbor-ca.crt
        dest: /usr/local/share/ca-certificates/labori-ca.crt
        mode: "0644"
      notify: CA nimekiri uuesti
    ```

    Mall `roles/docker/templates/daemon.json.j2` sisaldab samu logide piire, mis 5.6-s käsitsi lisasid. Väärtused tulevad rolli vaikeväärtustest. `max-file` on JSON-is tekst, mitte number.

    ```json
    {
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "{{ docker_log_max_size }}",
        "max-file": "{{ docker_log_max_file }}"
      }
    }
    ```

??? example "Ülesanne: Trivy (jätka sama faili)"

    Samad sammud, millega 6.6-s Trivy käsitsi paigaldasid.

    ```yaml
    - name: Trivy GPG võti
      ansible.builtin.get_url:
        url: https://aquasecurity.github.io/trivy-repo/deb/public.key
        dest: /etc/apt/keyrings/trivy.asc
        mode: "0644"

    - name: Trivy apt-repositoorium
      ansible.builtin.deb822_repository:
        name: trivy
        types: [deb]
        uris: https://aquasecurity.github.io/trivy-repo/deb
        suites: [generic]
        components: [main]
        signed_by: /etc/apt/keyrings/trivy.asc

    - name: Trivy
      ansible.builtin.apt:
        name: trivy
        update_cache: true
    ```

??? example "Ülesanne: teenus, grupp ja handler'id"

    Lisa `tasks/main.yml` lõppu:

    ```yaml
    - name: Teenus töötab ja käivitub koos masinaga
      ansible.builtin.service:
        name: docker
        state: started
        enabled: true

    - name: Kasutaja on grupis docker
      ansible.builtin.user:
        name: "{{ docker_kasutaja }}"
        groups: docker
        append: true
    ```

    Fail `roles/docker/handlers/main.yml`:

    ```yaml
    - name: Docker uuesti
      ansible.builtin.service:
        name: docker
        state: restarted

    - name: CA nimekiri uuesti
      ansible.builtin.command: update-ca-certificates
      changed_when: true
    ```

    `append: true` lisab grupi juurde. Ilma selleta eemaldaks moodul kasutaja kõigist teistest lisagruppidest, ka grupist `sudo`.

### 8.2 Käivita roll

Docker on control'is juba olemas. Enne muudatust vaata, mida roll muudaks.

**Küsimus enne käsku:** mitu ülesannet on `changed`, kui sama seadistus on juba käsitsi tehtud?

```bash
ansible-playbook docker.yml --check --diff
```

??? success "Oodatav tulemus"

    Paketid, teenus, grupp ja CA failid on juba soovitud olekus ja jäävad `ok`. `changed` on ainult failid, mille sisu erineb käsitsi tehtust, näiteks `daemon.json`-i vorming (tühikud ja reavahetused) või repositooriumi faili võtmete järjekord. `--diff` näitab iga erinevuse rida.

Rakenda roll kaks korda ja kontrolli tulemust:

```bash
ansible-playbook docker.yml
ansible-playbook docker.yml
docker compose ps
docker info --format '{{.LoggingDriver}}'
curl -s https://harbor.lab.hkhk.lan/api/v2.0/ping; echo
trivy --version | head -1
```

??? success "Oodatav tulemus"

    Esimene käivitus lõpeb `failed=0`, teine `changed=0`. Kui `daemon.json` muutus, taaskäivitas handler Dockeri ja stack käivitus uuesti tänu `restart: unless-stopped`-ile. Harbor vastab `Pong` ja Trivy versioon on alles.

??? warning "Kui esimene käivitus peatus vea tõttu ja `daemon.json` on muutunud, aga Docker kasutab vana seadet"

    Handler käivitub play lõpus. Kui play peatus enne lõppu, jäi handler käivitamata, kuigi fail muutus. Teisel käivitusel faili enam ei muudeta ja handler'it ei teavitata. Kontrolli faili (`sudo dockerd --validate --config-file /etc/docker/daemon.json`) ja käivita üks kord `sudo systemctl restart docker`. `--force-handlers` aitab ainult samas käivituses: see käivitab teavitatud handler'id ka siis, kui play peatub vea tõttu.

### 8.3 Commit

```bash
(cd ~/kursus && git add k03-docker && git commit -m "k03: Docker rolliga" && git push)
```

??? info "Miks see nii töötab"

    **Käsitsi ja rolliga.** Roll teeb samad sammud nagu käsitsi paigaldus, aga iga moodul kontrollib enne muutmist, kas masin on juba soovitud olekus. Seepärast saab rolli rakendada nii tühjale masinale kui ka masinale, kus Docker juba töötab, ja teine käivitus ei muuda midagi.

    **Erinevused käsitsi seadistusest.** `--check --diff` näitab faile, mille sisu erineb mallist või rolli kirjutatud kujust. Kui serveris on keegi `daemon.json`-i käsitsi muutnud, näitab sama käsk seda erinevust. Nii leiab triivi (drift): olukorra, kus masina tegelik olek on soovitud olekust eemaldunud.

    **Handler ja `validate`.** `validate` kontrollib uut faili enne asendamist. Vigane mall annab vea ja vana fail jääb alles. Handler taaskäivitab Dockeri ainult siis, kui fail muutus, sest iga taaskäivitus peatab hosti konteinerid.

## Osa 9 · Kolm riket

Failis `intsident/compose.yaml` on sama Labori seis eraldi projektina `labori-seis-intsident` pordil 8090 ja selles on kolm viga. Leiad need nagu tootmisintsidendis: alustad sümptomist, parandad faili, mitte töötavat konteinerit, ja lood uuesti ainult need teenused, mida parandus puudutab. Teade `dependency failed to start` ütleb ainult, et ahelas on midagi katki, seepärast ära paranda esimest nähtud sümptomit.

Iga viga leiad samade sammudega nagu 2. kohtumisel: **Sümptom**, **Hüpotees** (kirjuta K3 issue kommentaariks enne tõendi otsimist), **Tõend**, **Paranda** ja **Kontrolli**. Tabelit 3.6 loe ülevalt alla: esimene rida on kõige laiem sümptom, iga järgmine kitsendab otsingu ühe teenuse ja ühe põhjuseni.

??? note "Tabel 3.6. Compose'i stacki veaotsing"

    | Sümptom | Vaata esimesena | Tõenäoline koht |
    |---|---|---|
    | `up` lõpeb `dependency failed to start` | `docker compose ps -a`: kes on `Exited`, kes `unhealthy` | sõltuvus, mitte app01 ise |
    | teenus `Exited (1)` kohe pärast käivitust | `docker compose logs <teenus> \| tail -20` | andmekataloog, õigused, kasutaja |
    | teenus `unhealthy`, aga protsess töötab | `docker inspect -f '{{json .State.Health}}' <konteiner> \| jq` | healthcheck'i käsk, port |
    | web01 `unhealthy`, `curl` annab 502 | `docker compose exec web01 nslookup app01` | võrgud: kes on millises võrgus |
    | kõik `healthy`, aga `/health` ütleb `DOWN` | `docker compose exec app01 curl -s localhost:8080/health` | parool või volume, mis algseadistati varem |

### 9.1 Algseis

Control'is pole kahe stacki jaoks piisavalt mälu. Kahe stacki samaaegne käivitamine annab OOM-kille, mis näevad välja nagu intsidendi vead, aga ei ole. Peata põhistack (volume'id jäävad alles) ja käivita intsidendistack. Salvestad esimese `up`-i väljundi, sest see on intsidendi algne sümptom ja kokkuvõttes viitad sellele.

```bash
docker compose down
git log --oneline -1 -- intsident/compose.yaml
docker compose -f intsident/compose.yaml --env-file .env config -q && echo OK
alias dci='docker compose -f intsident/compose.yaml --env-file .env'
dci up -d 2>&1 | tee intsident/up-1.log
dci ps -a
```

Alias `dci` kehtib selles shellis kogu ülesande ajal. Projekti nimi `labori-seis-intsident` hoiab konteinerid, võrgud ja volume'id põhistackist eraldi: `docker volume ls` näitab mõlema projekti omi.

??? success "Oodatav tulemus"

    `up` lõppes veaga `dependency failed to start`, `up-1.log` on salvestatud ja tead, millised teenused on `Exited` ja millised `unhealthy`. `dependency failed to start` ütleb ainult, et keegi ahelas ei jõudnud `healthy` olekusse. Kaskaad peidab algpõhjuse: teenused, mis ootavad, ei käivitunudki ja nende logid on tühjad. Alusta teenusest, mis on `Exited` või `unhealthy`, mitte ahela viimasest teenusest.

### 9.2 Viga 1: andmebaas ei käivitu

**Sümptom:** db01 lõpetab kohe pärast käivitust. Alusta sellest teenusest, sest kõik teised ootavad selle käivitumist.

**Hüpotees:** kirjuta issue'sse, miks db01 lõpetab kohe pärast käivitust.

??? tip "Tõend"

    ```bash
    dci ps -a db01; dci logs db01 | tail -10
    docker inspect -f '{{.Config.User}} {{json .Mounts}}' labori-seis-intsident-db01-1 | jq .
    ls -ln intsident/data
    ```

    Võrdle, mis kasutajana MariaDB töötab ja kellele kuulub kataloog, kuhu ta kirjutab. Kes selle kataloogi lõi?

Paranda põhjus Compose'i failis. `user: "999:999"` jääb alles: andmebaas ei tohi töötada root'ina. Lahendus ei tohi nõuda käsitsi `chown`-i igal uuel masinal. Hea parandus töötab ka uuel masinal, kus keegi pole midagi käsitsi ette valmistanud. Kui sinu parandus vajab enne `up`-i mõnda käsku, mida failis pole, on see ajutine lahendus, mitte parandus.

??? example "Paranda"

    Bind mount `./data` lõi puuduva kausta root'i omanikuna ja UID 999 ei saa sinna kirjutada. Nimega volume'i täidab Docker esimesel ühendamisel image'i kataloogi sisuga koos omanikuga (`mysql`, 999). Asenda db01 `volumes` rida ja lisa faili lõppu volume:

    ```yaml
        volumes:
          - dbdata:/var/lib/mysql
    ```

    ```yaml
    volumes:
      dbdata:
      rmqdata:
    ```

**Kontrolli:**

```bash
dci up -d --wait db01
dci exec db01 id
```

??? success "Oodatav tulemus"

    db01 on `(healthy)` ja `id` näitab `uid=999`. Tee commit: `git commit -am "fix(intsident): db01 nimega volume, bind mount'i kaust kuulus root'ile"`. Sõnumis on põhjus.

### 9.3 Viga 2: vahemälu on unhealthy

**Sümptom:** mc01 protsess töötab, aga Docker märgib selle `unhealthy`-ks ja seepärast app01 ei käivitu.

**Hüpotees:** kirjuta issue'sse, miks töötav mc01 on `unhealthy`.

??? tip "Tõend"

    ```bash
    docker inspect -f '{{json .State.Health}}' labori-seis-intsident-mc01-1 | jq '.Status, .Log[-1]'
    dci exec mc01 sh -c 'netstat -tln 2>/dev/null || cat /proc/net/tcp'
    dci exec mc01 sh -c 'echo stats | nc -w 1 127.0.0.1 11211 | head -2'
    ```

    Memcached kuulab pordil 11211 ja vastab. Healthcheck küsib teist porti.

Healthcheck on kood nagu iga teine programm. Kui see kontrollib vale asja, annab see vale vastuse, ja iga `depends_on` sõltuvus usaldab seda vastust. Teenuse enda logis pole siin midagi: viga on selles, kuidas teda väljast vaadatakse.

??? example "Paranda"

    ```yaml
        healthcheck:
          test: ["CMD-SHELL", "echo stats | nc -w 1 127.0.0.1 11211 | grep -q uptime"]
    ```

**Kontrolli:**

```bash
dci up -d --wait mc01
dci up -d --wait app01
```

??? success "Oodatav tulemus"

    mc01 on `(healthy)` ja app01 jõuab `(healthy)` olekusse. Commit: `fix(intsident): mc01 healthcheck vale pordiga`.

### 9.4 Viga 3: web01 annab 502

**Sümptom:** app01 on `healthy`, web01 töötab, aga web01 on `unhealthy` ja `curl -s -o /dev/null -w '%{http_code}\n' localhost:8090/` annab 502. Kolmas viga ei ole üheski konteineris eraldi.

**Hüpotees:** kirjuta issue'sse, miks web01 vastab 502-ga, kuigi app01 on `healthy`.

??? tip "Tõend"

    ```bash
    dci exec web01 nslookup app01
    dci logs web01 | grep -m3 -iE 'resolve|upstream|error'
    docker network ls --filter name=labori-seis-intsident
    docker network inspect -f '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}' labori-seis-intsident_front labori-seis-intsident_back
    ```

    web01 on ainult võrgus `front`, app01 ainult võrgus `back`. Nimi `app01` lahendub ainult võrgus, kus app01 on.

Paranda nii, et app01 jääb sisemisse võrku ja ainult web01 on väljast nähtav. Lahendus, mis paneb kõik teenused ühte võrku, töötab samuti, aga avab app01 ja andmebaasi väljapääsu, ja see oleks uus viga vana asemel.

??? example "Paranda"

    web01 on mõlemas võrgus nagu prod-failis:

    ```yaml
      web01:
        networks: [front, back]
    ```

**Kontrolli:**

```bash
dci up -d --wait web01
curl -s localhost:8090/health; echo
```

??? success "Oodatav tulemus"

    web01 on `(healthy)` ja `/health` annab `"status":"UP"`. Commit: `fix(intsident): web01 ka back-võrku`.

### 9.5 Hooldusjärgne taaskäivitus: stack käivitub ise

Kolm riket on parandatud, aga stack töötab ainult seni, kuni keegi daemonit ei puutu. Hooldusaknas taaskäivitatakse Docker või kogu VM. Kontrolli, kas intsidendistack käivitub pärast seda uuesti ilma sinu sekkumiseta. Samal ajal peab hoolduseks käsitsi peatatud teenus jääma seisma. `live-restore` on vaikimisi välja lülitatud, nii et `systemctl restart docker` peatab kõik hosti konteinerid. Taaskäivitamisel ei arvesta `dockerd` `depends_on`-i: see kehtib ainult `docker compose up`-i ajal. Konteinerid käivituvad seega korraga ja suvalises järjekorras.

Peata mc01, nagu teeksid seda hoolduseks ja taaskäivita daemon. Pärast seda ära anna ühtegi `dci` käsku peale `ps`-i.

```bash
dci stop mc01 && sudo systemctl restart docker
sleep 120; dci ps -a --format '{{.Service}} {{.Status}}'
curl -s -w ' HTTP %{http_code}\n' localhost:8090/health
```

Paranda fail nende nõuete järgi: pärast daemoni taaskäivitust on db01, rmq01, app01 ja web01 `healthy` 120 s jooksul ilma käsitsi sekkumiseta; käsitsi peatatud mc01 jääb `Exited` olekusse; app01 ja web01 taluvad seda, et sõltuvus käivitub neist hiljem, kumbagi ei tohi käsitsi taaskäivitada; nõue on kirjas ühes kohas, mitte viie teenuse juures eraldi.

??? tip "Vihje"

    Kui stack ei käivitunud, vaata enne faili muutmist iga konteineri poliitikat: `docker inspect -f '{{.Name}} {{.HostConfig.RestartPolicy.Name}}' $(dci ps -aq)`. Kui mc01 käivitus koos teistega, on poliitika vale. Kui app01 oli `Up`, aga `unhealthy` ka siis, kui db01 oli juba `healthy`, on viga rakenduses: see ei talu sõltuvuse puudumist.

??? example "Paranda"

    Sama ühine plokk nagu põhistackis. Faili algusesse pärast `name:` rida:

    ```yaml
    x-common: &common
      restart: unless-stopped
    ```

    ja iga teenuse esimeseks reaks `<<: *common`. `always` käivitaks ka käsitsi peatatud mc01.

Uuenda stacki (`dci up -d --wait`), korda selle sammu käske ja lõpuks käivita mc01: `dci start mc01`.

??? success "Oodatav tulemus"

    Teine taaskäivitus andis 120 s pärast neli `healthy` teenust ja mc01 olekuga `Exited`. `/health` pordil 8090 andis HTTP 200 ja `"cache":"DOWN"`, pärast `dci start mc01` `"cache":"UP"`. Vahemälu on rakendusele valikuline: `/health` annab 503 ainult siis, kui andmebaas või järjekord puudub. Commit: `fix(intsident): restart-poliitika unless-stopped …`, sõnumis põhjus, miks just see poliitika.

### 9.6 Stack nullist

Viimane kontroll kustutab konteinerid ja käivitab stacki nullist. Kui stack käivitub ilma sinu sekkumiseta, on parandused failis, mitte töötavates konteinerites.

```bash
dci down && dci up -d --wait
dci ps --format '{{.Service}} {{.Status}}'
curl -s localhost:8090/health; echo
git log --oneline -4 -- intsident/compose.yaml
```

Eemalda intsidendistack ja käivita põhistack uuesti. `down -v` ja `rm -rf` kustutavad intsidendistacki andmed, mis loodi ainult rikete jaoks.

```bash
dci down -v && sudo rm -rf intsident/data
docker compose up -d --wait && curl -s localhost:8080/health; echo
```

??? success "Oodatav tulemus"

    Pärast `down` ja `up`-i on viis teenust `healthy` ilma käsitsi sekkumiseta, `/health` pordil 8090 on `UP`, Gitis on neli `fix(intsident)` commit'i ja põhistack on jälle üleval. Neli commit'i nelja põhjusega on intsidendi ajalugu, mida järgmine administraator saab lugeda ilma sinult küsimata. `down` ja uus `up` tõestasid, et ükski parandus ei sõltunud varem loodud kaustast.

### 9.7 Commit

```bash
(cd ~/kursus && git add k03-docker && git commit -m "k03: intsidendi parandused" && git push)
```

??? info "Miks see nii töötab"

    **Volume'i omanik.** Kui nimega volume on tühi, täidab Docker selle esimesel ühendamisel image'i sihtkataloogi sisuga, sealhulgas omaniku ja õigustega. Tulemus sõltub seega image'ist: kui image'is sihtkataloogi pole või selle omanik on root, ei saa mitte-root teenus volume'isse kirjutada.

    **Bind mount'i kaust.** Compose'i lühivorm (`- ./data:/var/lib/mysql`) loob puuduva hosti kausta root'i omana. Mitte-root teenus (`user: "999:999"`) ei saa siis oma andmekataloogi kirjutada.

    **Vale port healthcheck'is.** Healthcheck, mis küsib vale porti, muudab muidu töötava teenuse olekuks `unhealthy`. Kõik teenused, mille käivitamine sõltub selle teenuse olekust `service_healthy`, võivad jääda käivitamata.

    **Võrk teenuse omadusena.** Compose'is määratakse võrgud iga teenuse juures. Kui web01 ja app01 pole ühes võrgus, ei lahendu nimi `app01` ja Nginx vastab 502-ga.

    **Restart ja `depends_on`.** `depends_on` koos `condition: service_healthy`-ga on Compose'i kliendi loogika: `docker compose up` ootab enne järgmise teenuse loomist. Daemon ei tea sellest midagi. Pärast `dockerd` taaskäivitust käivitab see kõik konteinerid, mille restart-poliitika seda lubab, paralleelselt ja ilma järjekorrata. `unless-stopped` jätab vahele konteinerid, mille administraator peatas `docker stop`-iga, `always` käivitab ka need. Järjekorra puudumist peab taluma rakendus ise. app01 HikariCP pool (`initialization-fail-timeout=-1`) lubab Springil käivituda ka ilma andmebaasita ja ühendus luuakse hiljem, RabbitMQ listener proovib uuesti ja Nginx lahendab `app01` nime uuesti iga 10 s järel. Ühel YAML-ankrul (`x-…: &…`) põhinev ühine plokk hoiab poliitika ühes kohas nagu põhistacki `compose.yaml`-is.

    **Süntaktiliselt korras fail.** Kõigil kolmel rikkel on ühine joon: fail on süntaktiliselt korras ja `docker compose config -q` laseb selle läbi. Need vead avastab ainult käivitamine või test, mis kontrollib tulemust, mitte ainult faili süntaksit. Seetõttu on konveieris lisaks süntaksikontrollile (lint) ka samm, mis käivitab stacki ja küsib `/health`-i.

    **Ennetav kontroll.** Intsidendi järel lisatakse kontroll, mis püüab sama vea järgmine kord varem kinni, juba enne käivitamist.

## Osa 10 · Enne esitamist

Konveier võtab 5. kohtumisel sinu `compose.yaml`-i, Dockerfile'id ja `.env.example`-i täpselt sellisel kujul, nagu need `main`-is on. Käivitad samad kontrollid ise ja proovid ehitust puhtast kloonist.

### 10.1 Failide kontroll

Automaatkontroll näeb ainult repositooriumi. Kontrolli Compose'i faile ja Dockerfile'e, seejärel käivita automaatkontrolli testid ning kontrolli saladusi ja idempotentsust:

```bash
docker compose -f compose.yaml config -q && echo compose OK
docker compose -f compose.yaml -f compose.prod.yaml config -q && echo prod OK
for d in app db; do docker build --check -f $d/Dockerfile ..; done
for d in web kontroll; do docker build --check $d; done
(cd .. && for t in files compose deps multistage tags build; do bash autograde/check.sh k03 "$t"; done)
git ls-files .. | grep -E '(^|/)\.env$|secrets/|backup/|\.pem$|\.key$|tfstate'
docker compose up -d --wait
shellcheck -S warning prune.sh
git status --short
```

??? success "Oodatav tulemus"

    `build --check` ei anna hoiatusi, kuus kontrolli annavad `OK` (`build` ehitab kõik kolm image'it ja on aeglaseim), `git ls-files | grep` on tühi, `up -d` ütleb kõigi kohta `Running` või `Healthy` ja midagi ei looda uuesti. `build --check` leiab Dockerfile'i vead (näiteks shell-vormi CMD või valesti suurtähtedega kirjutatud `AS`) ilma ehitamata. Tühi `grep` tähendab, et ükski saladus ega varukoopia pole Giti ajalukku jõudnud.

### 10.2 Puhta klooni test

Kohalik kontroll käivitub sinu töökaustas, kus on ka commit'imata failid. Automaatkontroll alustab puhtast kloonist. See on klassikaline „minu masinas töötab“ olukord: Dockerfile kopeerib faili, mis on töökaustas, aga mitte Gitis, ja GitHubis ebaõnnestub ehitus, kuigi sinu juures läks kõik läbi.

```bash
(cd ~/kursus && git push)
rm -rf /tmp/k03-proov
git clone -q -b k03-docker ~/kursus /tmp/k03-proov
ls -a /tmp/k03-proov/k03-docker
(cd /tmp/k03-proov && bash autograde/check.sh k03 files && bash autograde/check.sh k03 build)
rm -rf /tmp/k03-proov
```

??? success "Oodatav tulemus"

    Kloonis puuduvad `.env` ja `secrets/`, `files` ja `build` annavad `OK`. See on õige: automaatkontroll töötab `.env.example`-iga. Kui klooni ehitus õnnestus, ei sõltu image ühestki failist, mis on ainult sinu töökaustas. Kui see ebaõnnestus, näitab veateade puuduvat faili: lisa see Giti või `.dockerignore` lubamisnimekirja.

### 10.3 Lõppkontroll

Kontrolli seda, mida automaatkontroll ei näe: stacki täielikku taaskäivitust, versiooni, rikkele reageerimist ja vastust stacki seest tehtud päringule.

```bash
docker compose down && docker compose up -d --wait && docker compose ps
curl -s http://localhost:8080/version; echo
docker compose stop rmq01; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/health
docker compose start rmq01 && sleep 30; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/health
docker run --rm --network labori-seis_default labseis-kontroll:test; echo
```

??? success "Oodatav tulemus"

    Viis teenust on `(healthy)` pärast `down` ja `up`-i, `/version` näitab sama SHA-d mis Harbori image'i tag, `/health` annab rmq01 peatamisel 503 ja pärast käivitust 200 ilma app01 taaskäivituseta ning kontroll-image annab `/health` JSON-i.

??? note "Kontrollnimekiri"

    - [ ] Docker on paigaldatud rolliga, teine käivitus `changed=0`
    - [ ] `compose.yaml`, `compose.prod.yaml`, Dockerfile'id ja `.env.example` on Gitis, `.env` ja `secrets/` mitte
    - [ ] kolm image'it on Harboris SHA-tag'iga
    - [ ] `quadlet/` kaustas on kolm faili
    - [ ] `intsident/compose.yaml` on parandatud neljas commit'is
    - [ ] mc01 ja db01 on algseisus

## Töö esitamine

Töö jõuab harusse `main` pull request'iga ja esitatakse tag'iga `k03`.

```bash
(cd ~/kursus && git add -A k03-docker && git commit -m "k03: valmis" && git push)
gh pr create --base main --head k03-docker --title "K3 Docker" --body "3. kohtumise praktikum"
```

Vaata pull request GitHubis üle ja ühenda (**Merge pull request**). Seejärel:

```bash
cd ~/kursus
git switch main
git pull
git tag k03
git push origin k03
```

Tulemuse näed Classroom 50-s.

??? warning "K3 tulemus on 0, kuigi töö on tehtud"

    Tag `k03` osutab siis harus `main` olevatele algfailidele, sest pull request jäi tegemata või haru `k03-docker` ei jõudnud GitHubi. Tee pull request ja ühenda see, seejärel tõsta tag uuele commit'ile:

    ```bash
    cd ~/kursus && git switch main && git pull
    git tag -f k03 && git push -f origin k03
    ```

Pärast esitamist lülita Proxmoxis välja mc01 ja db01 (**VM → Shutdown**): Podmani osa oli viimane, mis neid vajas, ja need kasutavad mälu, mida vajavad teised õppijad. Jäta Compose'i stack control'is tööle, sest 5. kohtumisel on seda vaja.

??? info "Miks see nii töötab"

    **Puhas kloon.** Puhas kloon sisaldab ainult commit'itud ja push'itud faile. Automaatkontroll ja konveier näevad sama mis puhas kloon: `.env`, `secrets/`, `backup/` ja commit'imata muudatused sealt puuduvad, aga `docker build` ehituskontekst töökaustas sisaldab neid.

    **`.env.example`.** `.env.example` kirjeldab nõutavaid keskkonnamuutujaid ja võimaldab konfiguratsiooni valideerida. See peab sisaldama iga muutujat, mida `compose.yaml` nõuab, väärtustega, millega fail läbib valideerimise.

    **Tag `k03`.** Tag `k03` määrab, milline commit esitatakse, ja automaatkontroll hindab alati seda commit'i, millele tag viitab. Tag `main`-i commit'il tähendab, et kontrollitakse sama koodi, mis on kursuse põhiharus. Kursusel on tag'i ümbertõstmine pärast parandust lubatud.

## Rikkeotsing

Iga osa tabelit loe ülevalt alla: esimeses veerus on see, mida näed, teises käsk, mille väljund näitab põhjust. Sama meetod nagu loengus: **sümptom → hüpotees → tõend → parandus → korduskontroll**.

??? note "Tabel 3.7. Osa 1 · Docker ja esimesed konteinerid"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `permission denied … docker.sock` | `id`, `ls -l /var/run/docker.sock` | kasutaja pole grupis `docker` või sessioon on vana: logi välja ja sisse, VS Code'is käivita server uuesti | grupiliikmesus loetakse sisselogimisel; vana shell ja VS Code'i server töötavad vanade gruppidega edasi |
    | `docker: command not found` või `docker compose` puudub | `dpkg -l \| grep -E 'docker-ce\|compose'` | Docker pole paigaldatud ametlikust repositooriumist; paigalda `docker-ce … docker-compose-plugin`, mitte `docker.io` ega eraldi `docker-compose` | Ubuntu `docker.io` on vanem ja Compose'i plugin tuleb ainult Dockeri repositooriumist; vana `docker-compose` (v1) on eraldi programm |
    | apt: `Could not get lock` Dockerit paigaldades | `cloud-init status` | cloud-init paigaldab veel uuendusi: `cloud-init status --wait`, apt'ile `-o DPkg::Lock::Timeout=120` | uue VM-i esimestel minutitel käivitab cloud-init apt'i ja hoiab dpkg lukus |
    | `toomanyrequests: … pull rate limit` | `echo $HUB`, `grep HUB .env` | image tõmmati otse Docker Hubist: nimes peab olema `$HUB/` (Harbori vahemälu) | Docker Hub loeb anonüümseid tõmbeid IP kaupa ja kogu klass on ühe NAT-aadressi taga |
    | `docker rmi`: `conflict: unable to …` | `docker ps -a --filter ancestor=<image>` | image'it kasutab konteiner, ka peatatud: eemalda enne konteiner (`docker rm`) | peatatud konteineri kirjutatav kiht toetub image'i kihtidele ja vajab neid |
    | konteiner on kohe `Exited (0)` | `docker inspect -f '{{.Config.Cmd}}' <konteiner>` | PID 1 lõpetas: bash ilma terminalita (`-it` puudub) või teenus läks taustale | konteiner töötab täpselt nii kaua kui PID 1; kui teenus läheb taustale, lõpetab PID 1 |
    | `Exited (137)`, `OOMKilled: true` | `docker inspect -f '{{.HostConfig.Memory}}' <konteiner>`, `docker stats` | mälupiir liiga väike; JVM-il `-XX:MaxRAMPercentage` | cgroup'i `memory.max` ületamisel tapab tuum protsessi SIGKILL-iga (128 + 9) |
    | `docker update --memory`: `Memory limit should be smaller than already set memoryswap limit` | `docker inspect -f '{{.HostConfig.MemorySwap}}'` | anna koos `--memory-swap` sama väärtusega | `--memory-swap` on mälu ja swap'i summa ega tohi olla väiksem kui mälupiir |
    | `cat: /sys/fs/cgroup/memory.max: No such file` | `docker info --format '{{.CgroupVersion}}'` | host kasutab cgroup v1: fail on `/sys/fs/cgroup/memory/memory.limit_in_bytes` | cgroup v1 ja v2 failipuu on erinev; Ubuntu 24.04 vaikimisi v2 |
    | konteiner ei käivitu pärast `kill -9`-i ega taaskäivitust | `docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' <k>` | restart-poliitika puudub (`no`) | ilma poliitikata ei tee `dockerd` PID 1 lõppemise peale midagi |
    | käsitsi peatatud konteiner käivitus pärast daemoni taaskäivitust uuesti | `docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' <k>` | poliitika on `always`: kasuta `unless-stopped` | `always` käivitab kõik konteinerid daemoni stardil, sõltumata sellest, kas administraator need peatas |
    | `nslookup db01`: `can't resolve` | `docker inspect -f '{{json .NetworkSettings.Networks}}' db01 \| jq 'keys'` | konteiner on vaikevõrgus `bridge`, `--network labnet` jäi puudu | sisseehitatud DNS (`127.0.0.11`) töötab ainult kasutaja loodud võrkudes |
    | MariaDB `Exited (1)` kohe | `docker logs db01 \| tail -5` | root-parooli muutuja puudub (`MARIADB_ROOT_PASSWORD`) | entrypoint keeldub initsialiseerimast baasi, millel pole root-parooli määratud |
    | konteineri IP ei vasta sülearvutist | `docker port <konteiner>` | konteineri IP on ainult hostis: kasuta avaldatud porti | `docker0` sild on hosti sisevõrk ja väljast sinna marsruuti pole |
    | `wget` sisemisest võrgust ootab kaua ja ebaõnnestub | `docker network inspect -f '{{.Internal}}' <võrk>` | ootuspärane: `internal` võrgul pole väljapääsu | sisemisel võrgul pole vaikemarsruuti ega NAT-i välja |
    | `rm -rf ~/k03-bind`: `Permission denied` | `ls -ln ~/k03-bind` | failid kuuluvad UID 999-le: `sudo rm -rf` | konteiner kirjutas bind mount'i oma UID-ga ja tuum kontrollib hostis sama numbrit |
    | `dockerd --validate`: `unknown flag: --validate` | `dockerd --version` | Docker on vanem kui 23; paigalda ametlikust repositooriumist (1.2) | konfiguratsiooni kontrollimise võti lisati daemonile versioonis 23 |
    | `systemctl restart docker` järel `failed`, `docker ps` ei vasta | `sudo journalctl -u docker -n 20`, `sudo dockerd --validate --config-file /etc/docker/daemon.json` | `daemon.json` on vigane või sama võti on ka unit'i `ExecStart` real | daemon loeb faili ainult käivitusel ja keeldub käivitumast, kui JSON on vigane või võti on kahes kohas |
    | `docker info` näitab `overlayfs`, juhend räägib `overlay2`-st | `docker info \| grep -A1 'Storage Driver'` | ootuspärane: uus paigaldus kasutab containerd'i image store'i | Docker 29 vaikimisi salvestus on containerd'i snapshotter, uuendatud masinad jäävad `overlay2` peale |
    | `--network host`: `Published ports are discarded` | `docker inspect -f '{{.HostConfig.NetworkMode}}' <k>` | ootuspärane: host-võrgus `-p` ei kehti | konteiner kuulab otse hosti liidestel, NAT-i ja pordi suunamist pole |
    | host-võrgu nginx lõpetab kohe, logis `Address in use` | `sudo ss -tlnp \| grep ':80 '` | port 80 on hostis juba kasutusel | host-võrgus jagab konteiner hostiga sama pordiruumi |
    | `--env-file`: väärtuses on jutumärgid | `cat <fail>` | eemalda failist jutumärgid | `docker run --env-file` loeb rea sõna-sõnalt; jutumärke tõlgendab ainult Compose'i `.env` |
    | `--env-file`: `variable '…' contains whitespaces` | `grep -n ' ' <fail>` | real on `export` või tühik võtme ees | võtme nimi on kõik märgid `=` märgini ja tühik nimes pole lubatud |
    | `docker stop` kestab 10 s, image käivitab lihtsa skripti või `sleep`-i | `docker top <k>` | PID 1 ei käsitle SIGTERM-i: lisa `--init` (Compose'is `init: true`) | tuum ei rakenda PID 1-le signaali vaikekäitumist; init annab signaali edasi |
    | `--mount`: `bind source path does not exist` | `ls -ld <tee>` | tee on vale või kaust loomata | `--mount` ei loo puuduvat allikat, `-v` lõi selle hoiatuseta ja omanikuks sai root |
    | `-v` järel on konteineris tühi kaust ootuspärase faili asemel | `ls -ld <hosti tee>` | hosti tee oli vale ja Docker lõi tühja kausta | `-v` loob puuduva allika kaustana; kasuta `--mount`-i, mis annab vea |
    | `docker exec`: `container … is not running` | `docker ps -a`, `docker logs <k>` | konteiner ebaõnnestus: vaata logi või käivita sama image `--entrypoint sh` | `exec` vajab töötavat PID 1 protsessi, mille namespace'idesse siseneda |

??? note "Tabel 3.8. Osa 2 · db ja web image"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `"/db/schema.sql": not found` | build'i viimane argument, `.dockerignore` | kontekst pole repositooriumi juurkaust või lubamisnimekirjast puudub `!db` | `COPY` teed on alati konteksti suhtes, mitte Dockerfile'i asukoha suhtes |
    | `"/src": not found` | `cat .dockerignore` | lubamisnimekirjast puudub `!src` | `*` jätab kõik välja ja builder ei näe faile, mida pole tagasi lubatud |
    | muudetud `seed.sql` ei jõua baasi | `docker volume ls` | init-skriptid käivituvad ainult tühja volume'iga: laboriandmetega `docker volume rm` või `docker compose down -v` (kustutab andmed; tootmisbaasis varukoopia enne või migratsioon) | entrypoint jätab `/docker-entrypoint-initdb.d/` vahele, kui `/var/lib/mysql` on juba initsialiseeritud |
    | `nginx -T` näitab `${NGINX_LOCAL_RESOLVERS}` muutmata kujul | `docker run --rm labseis-web:test ls /etc/nginx/templates` | `ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` puudub või fail pole `templates/` all | envsubst käsitleb ainult `templates/*.template` faile ja asendab ainult defineeritud muutujad |
    | web konteiner `Exited (1)`, logis `host not found in upstream` | `docker run --rm labseis-web:test nginx -T \| grep proxy_pass` | `proxy_pass` kasutab nime otse, mitte muutujat `$app_upstream` | staatiline upstream lahendatakse käivitusel ja lahendamata nimega nginx ei käivitu |
    | web annab 502 ja logis `could not be resolved` | `docker network inspect <võrk>` | app01 pole samas võrgus või pole veel käivitunud | muutujaga `proxy_pass` lahendab nginx nime päringu ajal ja vastab 502-ga, kui nimi ei lahendu |
    | `transferring context` on ikka MB-d | `head -3 .dockerignore` | `.dockerignore` pole repo juures või esimene rida pole `*` | builder loeb `.dockerignore` ainult konteksti juurest |
    | `k03 files`: `.dockerignore ei jäta .env faili välja` | `grep -n env .dockerignore` | denylist'is puudub `**/.env`; allowlist'iga (`*`) seda viga ei tule | ilma `**/` eesliiteta kehtib muster ainult konteksti juures, mitte `k03-docker/.env`-ile |

??? note "Tabel 3.9. Osa 3 · App image"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `COPY . .` ei too lähtekoodi | `cat .dockerignore` | allowlist töötab: naiivne variant vajab `!pom.xml` ja `!src` | `COPY . .` kopeerib konteksti, ja kontekst on pärast `.dockerignore`-i peaaegu tühi |
    | iga build käivitab `apt-get` uuesti | `grep -n GIT_SHA k03-docker/app/Dockerfile` | `ARG/ENV GIT_SHA` on käitusastme alguses, mitte lõpus | muutuja väärtus on järgmiste kihtide sisend; uus väärtus tühistab cache'i kõigile järgnevatele |
    | Maven laeb iga build'iga kõik sõltuvused | `grep -n COPY k03-docker/app/Dockerfile` | `src` kopeeritakse enne `dependency:go-offline`-i | koodi muutus muudab `COPY src` kihi ja kõik järgnevad, sh sõltuvuste allalaadimine, käivituvad uuesti |
    | `docker stop` kestab 10 s | `docker exec <k> cat /proc/1/cmdline \| tr '\0' ' '` | CMD on shell-vormis, PID 1 on `sh` | `sh -c` ei edasta SIGTERM-i lapsele; Docker ootab 10 s ja saadab SIGKILL-i |
    | app konteiner `unhealthy` ilma andmebaasita | `docker exec <k> curl -s localhost:8080/health/live` | ootuspärane: `/health` annab 503, kui db pole | `/health` kontrollib sõltuvusi, `/health/live` ainult protsessi |
    | Tomcat ei käivitu pärast `USER 10001`, logis `Permission denied` | `docker run --rm --entrypoint ls labseis-app:multi -ln /usr/local/tomcat` | mõni kirjutatav kaust (`logs`, `temp`, `work`, `webapps`, `conf/Catalina`) kuulub root'ile | Tomcat pakib WAR-i lahti ja kirjutab logisid; mitte-root kasutaja vajab neis kaustades omandit |
    | `useradd: UID 10001 is not unique` | `docker run --rm --entrypoint getent tomcat:10.1-jre21-temurin passwd 10001` | baasimage'is on see UID juba olemas: vali teine | UID peab olema image'i `/etc/passwd`-is unikaalne |
    | `naive` ja `multi` on peaaegu sama suured | `docker history labseis-app:multi \| head -8` | käitusaste kopeerib midagi suurt build-astmest või baas on vale | `COPY --from` kopeerib selle, mis antud teel on; vale tee toob kaasa `~/.m2` või kogu `/src` |
    | kontroll-image: `Could not resolve host: web01` | `docker run` `--network` | ootuspärane testvõrgus; stacki võrgus (`labori-seis_default`) peab vastama | nimi lahendub ainult võrgus, kus see teenus on |
    | `k03 tags` FAIL app-image'i järel | `ls k03-docker/compose.yaml` | test vajab ka `compose.yaml`-i, mis tekib Compose'i lehel | test loeb ametlike image'ite tag'id Compose'i failist |
    | `template: … map has no entry for key "GraphDriver"` | `docker info -f '{{.Driver}}'` | containerd'i image store: kasuta `jq '.[0].GraphDriver // …'` või konteineri `mountinfo`-t | containerd'i salvestusega ei ole image'il `GraphDriver` välja |
    | `grep upperdir … mountinfo`: `Permission denied` või tühi | `docker inspect -f '{{.State.Pid}}' <k>` | `sudo` puudu või konteiner ei tööta | teise protsessi `mountinfo` on loetav ainult root'ile ja ainult töötava protsessi kohta |
    | `kihtproov` on suur, kuigi fail kustutati | `docker history kihtproov` | ootuspärane: kustutamine hilisemas kihis ei vähenda image'it | alumine kiht on muutumatu; `rm` lisab ainult whiteout-kirje |

??? note "Tabel 3.10. Osa 4 · Kogu stack Compose'iga"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `required variable DB_ROOT_PASSWORD is missing` | `pwd`, `ls -la .env` | `.env` puudub või käsk ei tööta kaustas `k03-docker/` | Compose otsib `.env`-i projekti kaustast ja `${VAR:?}` katkestab, kui väärtust pole |
    | `port is already allocated` | `ss -tlnp \| grep 8080` | port on kasutusel (vana konteiner, varem paigaldatud teenus): muuda `WEB_PORT`-i või peata porti kasutav teenus | üks hostiport saab olla seotud ainult ühe kuulajaga |
    | app01 jääb olekusse `starting` või `unhealthy` | `docker compose exec app01 curl -s localhost:8080/health`, `docker compose logs app01` | db või rmq ei vasta, vale parool | `/health` on DOWN, kui ükski sõltuvus ei vasta, ja healthcheck kordab seda |
    | db `Access denied` pärast parooli muutmist | `docker volume ls \| grep dbdata` | volume initsialiseeriti vana parooliga: laboriandmetega `docker compose down -v` (kaotab andmed; tootmisbaasis varukoopia enne või parooli muutmine baasis) | parool kirjutati baasi esimesel käivitusel; muutuja muutmine hiljem kasutajat ei muuda |
    | web01 annab 502 | `docker compose ps`, `nginx -T \| grep -E 'resolver\|proxy_pass'` | app01 pole valmis või nginx kasutab vana IP-d (`resolver` ja `proxy_pass $app_upstream`) | staatiline upstream jääb vanale IP-le, kui app01 luuakse uuesti |
    | `up -d` loob teenuse iga kord uuesti | `docker compose config` kahe käivituse vahel | failis on väärtus, mis muutub (näiteks `latest` või muutuja, mis tuleb käsurealt) | Compose võrdleb seadistuse räsi; muutunud räsi tähendab uut konteinerit |
    | RabbitMQ halduses on järjekorrad pärast konteineri uuesti loomist tühjad | `docker compose exec rmq01 hostname` | `hostname: rmq01` puudub: node'i nimi muutus | RabbitMQ andmekataloog on node'i nime järgi ja uus nimi tähendab uut, tühja node'i |
    | järjekorras on sõnumid, consumer'eid 0 | `docker compose logs app01 \| grep -i rabbit` | app01 consumer ei ühendunud või parool on vale | API ja consumer on eraldi komponendid; POST õnnestub ka siis, kui consumer ei tööta |
    | `k03 deps`: `restart-poliitika puudub` | `docker compose config \| grep restart` | `<<: *common` puudub mõnel teenusel | ankru seaded kehtivad ainult teenustele, kuhu ankur on lisatud |
    | `k03 deps`: `port on hostis avatud` | `docker compose config \| grep -B3 published` | app01, db01 või mc01 all on `ports:` | test nõuab, et väljast oleks nähtav ainult web01 |
    | healthcheck toruga ei tööta | `docker inspect -f '{{json .State.Health.Log}}' <k>` | `CMD` kuju ei käivita shelli: kasuta `CMD-SHELL` | `CMD` käivitab programmi otse ja `\|` läheb talle argumendina |
    | kontroll-image: `Could not resolve host` stacki võrgus | `docker network ls` | võrgu nimi on `<projekt>_default`: projekti nimi `name:` real | Compose paneb võrgu nimele projekti nime ette |
    | `docker compose logs -f --since 1m` ei näita midagi | `docker compose ps web01`, `date -u` | viimase minuti jooksul pole päringuid tehtud või vaatad valet teenust | `--since` filtreerib Dockeri ajatempli järgi; vanemad read jäävad välja |
    | `docker inspect -f`: `map has no entry for key` | `docker inspect <k> \| jq '.[0] \| keys'` | välja nimi on vale või punktiga silt vajab `index`-it | Go template (`--format` muster) loeb JSON-i välju täpse nimega; punktiga võtme jaoks on `{{index .Config.Labels "a.b"}}` |
    | `docker top … -eo`: `error: unsupported option` | `docker top <k>` ilma võtmeteta | võtmed antakse hosti `ps`-ile: kasuta `ps` süntaksit | `docker top` käivitab hostis `ps` ja filtreerib konteineri protsessid |
    | `docker compose cp`: `Could not find the file` | `docker compose exec web01 ls /etc/nginx/conf.d` | tee on vale või fail on tmpfs'is, mis kadus | `cp` loeb konteineri failisüsteemist praegust olekut |

??? note "Tabel 3.11. Osa 5 · Tootmiskeskkonda sobiv stack"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `docker compose config` ei näita piiranguid | `echo $COMPOSE_FILE` | uus shell: `export COMPOSE_FILE=compose.yaml:compose.prod.yaml` | `export` kehtib ainult selles shellis ja selle alamprotsessides |
    | PID-katses ei tule `can't fork` | `docker inspect -f '{{.HostConfig.PidsLimit}}' labori-seis-web01-1` | `pids` piirang puudub või prod-faili pole käivitamisel kaasa võetud | ilma `pids.max` väärtuseta piirab ainult hosti üldine protsessipiir |
    | db01: `Both MARIADB_PASSWORD and MARIADB_PASSWORD_FILE are set` | `docker compose config` db01 `environment` | `environment` ilma `!override`-ita liideti põhifailiga | Compose liidab mapping'ud võtme kaupa ja põhifaili võti jääb alles |
    | `secret … file … not found` | `ls -la secrets/` | saladuste failid tegemata või vales kaustas (tee on `compose.yaml` kausta suhtes) | suhteline tee lahendatakse esimese Compose'i faili kausta suhtes |
    | app01 taaskäivitub, logis `AccessDeniedException: /run/secrets/…` | `ls -l secrets/` | failide õigused on `600` ja UID 10001 ei saa neid lugeda: `chmod 644 secrets/*` (kaust jääb 700) | ilma Swarmita mount'itakse fail hosti omaniku ja õigustega |
    | `/health`: `db` DOWN pärast saladusi, logis `Access denied` | `od -c secrets/DB_PASSWORD \| tail -2` | failis on reavahetus või teine väärtus kui volume'i algseadistamisel | configtree loeb faili sisu täpselt, koos reavahetusega |
    | `secrets/` ilmub `git status`-esse | `git check-ignore -v k03-docker/secrets/x` | `k03-docker/.gitignore` puudub või rida on vale | `.gitignore` muster kehtib selle faili kausta suhtes |
    | app01 ei leia db01 pärast võrkude lisamist | `docker inspect -f '{{json .NetworkSettings.Networks}}' labori-seis-app01-1 \| jq 'keys'` | app01 ja db01 pole ühes võrgus | DNS vastab ainult nende võrkude teenustele, kus konteiner ise on |
    | `ports` 15672 kuulab ikka `0.0.0.0` | `docker compose config \| grep -A6 'ports:'` | `!override` puudub: loend liideti ja mõlemad read jäid | loendid liidetakse, mitte ei asendata |
    | UI ei avane tunneli kaudu | `ss -tlnp \| grep 15672` control node'is | tunnel suunab vale aadressile: `-L 15672:127.0.0.1:15672` | port kuulab ainult loopback'il ja tunneli sihtaadress peab olema sama |
    | web01 `unhealthy` pärast `read_only` | `docker compose logs web01 \| head -15` | puudub `tmpfs` mõnele kaustale (`/var/cache/nginx`, `/run`, `/etc/nginx/conf.d`) | nginx ja entrypoint kirjutavad käivitusel PID-faili, cache'i ja konfiguratsiooni |
    | web01 näitab nginx'i vaikelehte | `docker compose exec web01 ls /etc/nginx/conf.d` | `conf.d` pole kirjutatav ja entrypoint jättis malli töötlemata | entrypoint kontrollib, kas sihtkaust on kirjutatav, ja jätab muidu template'ist konfiguratsiooni tegemata |
    | `unknown log opt 'max-size' for journald log driver` | `docker compose config` app01 `logging` | `logging` liideti, mitte ei asendatud: `logging: !override` | liitmisel jäävad põhifaili `options` alles ja journald neid ei tunne |
    | Docker ei käivitu pärast `daemon.json` muutmist | `sudo journalctl -u docker -n 20` | vigane JSON: `jq . /etc/docker/daemon.json`, taasta `.bak` | `dockerd` loeb faili käivitusel ja lõpetab vigase JSON-iga |
    | `journalctl CONTAINER_NAME=…` on tühi | `docker inspect -f '{{.HostConfig.LogConfig.Type}}' labori-seis-app01-1` | konteiner loodi enne muudatust või draiver pole `journald`: `up -d app01` | logidraiver määratakse konteineri loomisel ega muutu töötaval konteineril |
    | uued konteinerid ei saa `daemon.json` `log-opts`-e | `docker info --format '{{.LoggingDriver}}'` | daemon pole taaskäivitatud või Compose'i `logging` kirjutab üle | konteineri enda seade kirjutab daemoni vaikeseade üle |
    | taastatud volume'iga MariaDB: `Permission denied` | `docker run --rm -v dbdata-taaste:/d ubuntu:24.04 ls -ln /d` | omanik pole 999: taastamine ilma `--numeric-owner`-ita või mitte root'ina | `tar` vastendab omaniku nime järgi ja abikonteineris pole kasutajat `mysql` |
    | taastatud baas on katki või ei käivitu | kas db01 oli varundamise ajal peatatud | töötava andmebaasi failikoopia pole järjepidev | InnoDB kirjutab andmeid ja logisid eri aegadel ning `tar` saab pooliku pildi |
    | `prune.sh` kustutas volume'i | `grep -n volume prune.sh` | skriptis on `volume prune` või `--volumes`: need ei kuulu poliitikasse | peatatud stacki volume on "kasutamata" ja prune ei tee vahet vajalikel ja mittevajalikel andmetel |
    | GitHub Actionsi deploy järel app01 ei leia db01 | `docker network ls \| grep labori-seis` | stack töötas prod-failiga; 5. osa lõpus `unset COMPOSE_FILE && docker compose up -d` | ainult `compose.yaml`-iga loodud app01 on vaikevõrgus, db01 jäi `back`-võrku |
    | Kuma ei jõua web01-ni prod-failiga | `docker compose --profile monitoring config \| grep -A3 kuma` | kuma on vaikevõrgus; lisa talle `networks: [front, back]` või käivita põhistackiga | prod-fail viis teised teenused vaikevõrgust ära, kuma jäi vaikevõrku ainsana |

??? note "Tabel 3.12. Osa 6 · Harbor, Trivy ja SBOM"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `x509: certificate signed by unknown authority` | `ls /etc/docker/certs.d/harbor.lab.hkhk.lan/` | kursuse CA puudub: korda 1.5 sertifikaadi samme; `insecure-registries` ei ole lahendus | Docker usaldab registry sertifikaati ainult süsteemi või `certs.d` CA põhjal |
    | `denied: requested access to the resource is denied` | `grep OWNER .env` | `OWNER` pole sinu Harbori kasutajanimi (GitHubi nimi väikeste tähtedega) või logisid sisse teise kasutajana | registry lubab push'i ainult oma namespace'i ja õigusega tokenile |
    | `unauthorized` pärast `docker login` | `cat ~/.docker/config.json \| jq '.auths \| keys'` | sisselogimisel kasutati vale registry nime või robotkonto on aegunud | volitused on salvestatud registry hostinime kaupa |
    | `docker pull <nimi>@sha256:…`: `manifest unknown` | `docker image inspect -f '{{json .RepoDigests}}' <image>` | digest on lokaalse image'i ID, mitte registry digest | image ID ja manifesti digest on eri räsid; registry tunneb ainult manifesti oma |
    | `docker compose pull` ehitab või ei leia image'it | `docker compose config --images` | `TAG` `.env`-is erineb push'itud tag'ist | Compose otsib registry'st täpselt seda nime ja tag'i, mis on failis |
    | `trivy: command not found` | `apt-cache policy trivy` | paigalda Trivy ametlikust apt repost | Ubuntu standardrepos Trivy't pole |
    | `trivy` esimene käivitus jääb rippuma | proxy, `trivy image --download-db-only` | haavatavuste andmebaasi allalaadimine (mõnikümmend MB) | Trivy laadib andmebaasi enne esimest skannimist ja uuendab seda regulaarselt |
    | `docker run aquasec/trivy … trivy --version`: `unknown command "trivy"` | `docker image inspect -f '{{json .Config.Entrypoint}}' aquasec/trivy:<v>` | ootuspärane: ENTRYPOINT on juba `trivy`, tühjenda `--entrypoint ""` | argumendid lisatakse ENTRYPOINT-i taha ja `trivy trivy` on tundmatu alamkäsk |
    | `trivy sbom` annab 0 leidu | `jq '.components \| length' sbom-app.json` | SBOM tehti valest image'ist või `--format` polnud `cyclonedx` | ilma komponentideta pole Trivy'l midagi andmebaasiga võrrelda |
    | `current image with … vulnerabilities cannot be pulled` | projekt → **Configuration** | haavatava image'i tõmbamise keeld on sees | Harbor kontrollib enne tõmbamist Trivy tulemust |
    | push: `… configured as immutable` | projekt → **Policy → Tag Immutability** | tag on muutumatu: kasuta uut tag'i | muutumatut tag'i ei saa üle kirjutada ega kustutada |

??? note "Tabel 3.13. Osa 7 · Sama teenus Podmaniga"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `podman info`: `rootless=false` või käsk küsib parooli | `id`, `echo $XDG_RUNTIME_DIR` | käsk käivitati `sudo` või `su` kaudu: logi sisse otse SSH-ga kasutajana `kasutaja` | rootless vajab kasutaja sessiooni (`/run/user/<UID>`), mille loob ainult SSH- või konsoolisisselogimine (`pam_systemd`); `sudo -u` seda ei tee |
    | `Error: short-name "memcached:1.6-alpine" did not resolve` | `grep -r short-name /etc/containers/registries.conf*` | kirjuta image täisnimega `docker.io/library/memcached:1.6-alpine` | `short-name-mode = "enforcing"` ei luba ilma terminalita registry't valida, systemd teenusel terminali pole |
    | `podman pull` Harborist: `x509: certificate signed by unknown authority` | `ls /etc/containers/certs.d/harbor.lab.hkhk.lan/` | kopeeri kursuse CA sinna faili `ca.crt`; ära kasuta `--tls-verify=false` | Podman loeb registry CA-d `certs.d` kaustast nagu Docker, aga teisest teest |
    | taaskäivituse järel `unauthorized` Harborist | `ls ~/.config/containers/auth.json $XDG_RUNTIME_DIR/containers/auth.json` | login ilma `--authfile`-ita läks tmpfs'i: korda `--authfile ~/.config/containers/auth.json`-iga | vaikimisi auth-fail on `$XDG_RUNTIME_DIR` all, mis tühjeneb reboot'il |
    | `bind: address already in use` pordil 11211 või 3306 | `sudo ss -tlnp \| grep -E ':(11211\|3306) '` | native teenus töötab: `sudo systemctl disable --now memcached` (või `mariadb`) | sama port saab olla ainult ühe protsessi oma; `pasta` kuulab hostis nagu tavaline teenus |
    | `daemon-reload` järel `Unit labseis-mc.service not found` | `/usr/libexec/podman/quadlet -dryrun -user` | Quadleti fail on vales kaustas, vale laiendiga või tundmatu võtmega (vanem Podman) | generaator jätab vigase faili vahele ja kirjutab põhjuse ainult `-dryrun` väljundisse ja journal'isse |
    | `journalctl --user -u labseis-db` on tühi | `ls /var/log/journal` | kasuta `sudo journalctl _SYSTEMD_USER_UNIT=labseis-db.service` | ilma püsiva journal'ita ei teki kasutajale eraldi journal-faili ja tema read on süsteemi journal'is |
    | `systemctl --user enable`: `Unit … is transient or generated` | `grep -A1 '^\[Install\]' ~/.config/containers/systemd/*.container` | ootuspärane: `enable` pole vaja, käivituse annab `[Install] WantedBy=default.target` | generaator teeb `default.target.wants` lingi ise iga `daemon-reload`-iga |
    | pärast reboot'i teenus ei tööta, SSH-sisselogimise järel töötab | `loginctl show-user kasutaja -p Linger` | `sudo loginctl enable-linger kasutaja` | ilma lingerita käivitub kasutaja systemd alles sisselogimisel |
    | db01: `Permission denied` init-SQL-il, `ausearch` näitab `denied { read }` | `ls -Z ~/labseis/03-dump.sql` | bind mount'il puudub `:Z`: lisa `:ro,Z` | `container_t` tohib lugeda ainult `container_file_t` silti, failiõigused seda ei muuda |
    | db01 on `active`, aga ridu on vähem kui native baasis | `podman volume inspect labseis-db-data`, `journalctl --user -u labseis-db \| grep -m1 initdb` | volume initsialiseeriti poolikult: `stop`, `podman volume rm labseis-db-data`, `start` | entrypoint impordib `initdb.d` faile ainult tühja andmekataloogiga; teine katse leidis kataloogi eest ja jättis impordi vahele |
    | `--cpus` või `--memory`: `controller … is not available` | `cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers` | kontroller pole kasutajale delegeeritud: drop-in `user@.service.d/` `Delegate=` | rootless saab piirata ainult neid kontrollereid, mille systemd kasutaja teenusele delegeeris |
    | `docker ps` tunneli kaudu: `Cannot connect to the Docker daemon` | `ssh mc01 systemctl --user is-active podman.socket`, `ls -l /tmp/mc01-podman.sock` | socket pole aktiivne või tunnel on vana: eemalda socket'i fail (`rm`) ja loo tunnel uuesti | `ssh -L` ei kirjuta olemasoleva socket'i faili üle |

??? note "Tabel 3.14. Osa 8 · Docker rolliga"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | roll: `Destination directory /etc/docker/certs.d/… does not exist` | `ls /etc/docker/certs.d` | ülesanne „Harbori sertifikaadi kaust“ puudub või on pärast `copy`-t | `copy` ei loo puuduvat sihtkausta, kui `dest` on faili tee |
    | roll muutis `daemon.json`-i, aga Docker kasutab vana seadet | `sudo journalctl -u docker -n 5` | play peatus enne lõppu ja handler jäi käivitamata: `sudo systemctl restart docker` | handler käivitub play lõpus ainult siis, kui play jõuab lõpuni |
    | `deb822_repository`: `unsupported parameter` | `ansible --version` | ansible-core on vanem kui 2.15 | moodul lisati versioonis 2.15 |

??? note "Tabel 3.15. Osa 9 · Kolm riket"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | `dci: command not found` | `alias dci` | alias kehtib ainult selles shellis: defineeri uuesti | aliased ei pärandu uude shelli ega skripti |
    | `up` ütleb `dependency failed to start` | `dci ps -a` | sõltuvus on `Exited` või `unhealthy`; vaata veaotsingu tabelit | `service_healthy` tingimus ei käivita teenust enne, kui sõltuvus on terve |
    | pärast parandust on ikka sama viga | `dci config` | fail on parandatud, aga konteiner on vana: `dci up -d --wait <teenus>` | töötav konteiner ei loe faili uuesti; muudatus jõuab kohale alles uue konteineriga |
    | pärast `systemctl restart docker` on intsidendistack `Exited` | `docker inspect -f '{{.Name}} {{.HostConfig.RestartPolicy.Name}}' $(dci ps -aq)` | poliitika on `no`: lisa see ühisesse plokki ja `dci up -d` | `depends_on` kehtib ainult `compose up`-i ajal, daemon käivitab ainult poliitikaga konteinerid |
    | `intsident/data` ei kustu | `ls -ln intsident/data` | kaust kuulub root'ile või UID-le 999: `sudo rm -rf` | kausta lõi Docker või konteiner, mitte sinu kasutaja |

??? note "Tabel 3.16. Osa 10 · Enne esitamist ja töö esitamine"

    | Sümptom | Kontrolli | Tõenäoline põhjus | Miks see juhtub |
    |---|---|---|---|
    | tag pole GitHubis | `git ls-remote --tags origin` | tavaline `git push` tag'e ei lükka: `git push origin k03` | Git lükkab vaikimisi ainult harud |
    | parandus pärast esitamist | `git log --oneline -1 k03` | tag viitab vanale commit'ile: `git tag -f k03 && git push -f origin k03` | tag on fikseeritud viide ühele commit'ile ega liigu koos haruga |
    | `k03 build` ebaõnnestub kloonis või automaatses hindajas, lokaalselt töötab | `git status`, `git ls-files k03-docker` | Dockerfile, `.dockerignore` või kopeeritav fail on commit'imata | värske kloon sisaldab ainult Gitis olevat |
    | `git clone -b k03-docker`: `Remote branch not found` | `git branch --show-current` | haru on teise nimega või kloonid valest kaustast | `-b` otsib haru lähterepositooriumist täpselt selle nimega |
    | `k03 files`: `k03-docker/.env on Gitis` | `git ls-files k03-docker/.env` | fail lisati varem: `git rm --cached k03-docker/.env` | `.gitignore` ei puuduta faile, mida Git juba jälgib |

## Lisaülesanded

Kõik ülesanded on samas projektis ja iga ülesanne lõpeb kontrolliga. Failid lähevad kausta `k03-docker/` (ülesanne 15 kausta `vorgukogu/`). Docker Hubi image'id kirjuta kujul `$HUB/<image>` (näiteks `$HUB/nginx:1.30-alpine`), mitteametlikud kujul `harbor.lab.hkhk.lan/dockerhub/<omanik>/<image>` (näiteks `louislam/uptime-kuma:2`).

??? example "1 · Swarm ühel node'il"

    Compose haldab üht hosti: ta ei hoia mitut koopiat ega uuenda teenust ilma 502-ta. Swarm on Dockeri sisseehitatud orkestraator, ja ühe masina peal näed, mida orkestraator sinu eest teeb. Katse ajaks on control Swarmi manager ja põhistack töötab samal ajal edasi.

    - control on üheliikmeline Swarm ja teenus `websw` töötab kolme koopiana `nginx:1.30-alpine` peal pordil 8085;
    - kustuta üks koopia käsitsi (`docker rm -f`) ja vaata, mida Swarm teeb;
    - uuenda image `nginx:1.29-alpine` peale ükshaaval (`--update-parallelism 1 --update-delay 5s`) ja võta uuendus `docker service rollback`-iga tagasi;
    - lõpuks on teenus eemaldatud, host on Swarmist lahkunud ja `docker_gwbridge` võrku pole.

    **Kontroll:**

    ```bash
    docker service ps websw --format '{{.Name}} {{.Image}} {{.CurrentState}} {{.Error}}'
    curl -sI localhost:8085 | head -1
    docker service inspect -f '{{.UpdateStatus.State}}' websw
    docker info -f '{{.Swarm.LocalNodeState}}'; docker network ls    # pärast koristust
    ```

    **Valmis, kui:**

    - kustutatud koopia asemele tekkis automaatselt uus ja `docker service ls --filter name=websw` näitab `3/3`;
    - uuendus vahetas koopiad ükshaaval;
    - pärast `rollback`-i on kõik koopiad `nginx:1.30-alpine` peal ja `UpdateStatus.State` on `rollback_completed`;
    - pärast koristust annab `LocalNodeState` vastuse `inactive`.

    ??? success "Lahendus"
        ```bash
        docker swarm init --advertise-addr <control IP>
        docker service create --name websw --replicas 3 -p 8085:80 nginx:1.30-alpine
        docker service ps websw --format '{{.Name}} {{.CurrentState}}'
        curl -sI localhost:8085 | head -1

        docker rm -f "$(docker ps -q --filter name=websw | head -1)"
        sleep 10; docker service ps websw --format '{{.Name}} {{.CurrentState}} {{.Error}}'

        docker service update --image nginx:1.29-alpine --update-parallelism 1 --update-delay 5s websw
        docker service ps websw --format '{{.Name}} {{.Image}} {{.CurrentState}}' | head -6
        docker service rollback websw
        ```

        ```bash
        # enne koristust: kustutatud task, praegune ja eelmine spec
        docker service ps websw --filter desired-state=shutdown --format '{{.Name}} {{.CurrentState}} {{.Error}}'
        docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' websw
        docker service inspect -f '{{.PreviousSpec.TaskTemplate.ContainerSpec.Image}}' websw
        docker service inspect -f '{{.UpdateStatus.State}}' websw

        # koristus
        docker service rm websw && docker swarm leave --force
        docker network rm docker_gwbridge 2>/dev/null; docker network ls
        ```

        Kontroll: `docker service ls --filter name=websw` näitab `3/3`, praegune image on `nginx:1.30-alpine@sha256:…`, `UpdateStatus.State` on `rollback_completed`. Pärast koristust annab `docker info -f '{{.Swarm.LocalNodeState}}'` vastuse `inactive`.

        **Miks nii.** Manager hoiab soovitud olekut (`--replicas 3`) Rafti logis ja võrdleb seda task'ide tegeliku olekuga. Kustutatud konteineri task märgitakse `Failed` olekusse ja orkestraator loob uue task'i uue konteineriga. `service create` lahendab tag'i digestiks (`--no-resolve-image` lülitab selle välja), ja `rollback` läheb tagasi teenuse `PreviousSpec`-ile, registry ajalugu selleks vaja pole. Swarmi teenused ja Compose'i konteinerid töötavad samas daemonis kõrvuti, seepärast jääb põhistack tööle ja pärast koristust on host endises olekus. Mida see näitas ja miks kursus läheb edasi Kubernetesesse, on lehe Kogu stack Compose'iga lõpus.

??? example "2 · BuildKit cache mount"

    **Esita:** `k03-docker/app/Dockerfile`

    Praegu laaditakse iga `pom.xml`-i muudatuse järel kõik Maveni sõltuvused uuesti alla, sest kiht tühistatakse tervikuna. Cache mount hoiab Maveni hoidla build'ide vahel alles ja laeb alla ainult muutunud osa.

    - build-astme mõlemal Maveni `RUN`-il on `--mount=type=cache,target=/root/.m2`;
    - kustuta `pom.xml`-ist ajutiselt üks sõltuvus, ehita, pane tagasi ja ehita uuesti;
    - mõõda, mitu MB teisel korral alla laeti;

    **Kontroll:**

    ```bash
    docker build --progress=plain -f k03-docker/app/Dockerfile -t labseis-app:cm . 2>&1 | grep -c 'Downloaded from'
    docker buildx du --verbose | grep -B2 -A4 cachemount
    ```

    **Valmis, kui:**

    - `docker buildx du --verbose` näitab cache mount'i kirjet;
    - build pärast sõltuvuse tagasipanekut laeb alla paar MB, mitte kogu hoidla;

    Vihje: Maven näitab allalaadimisi ainult siis, kui `go-offline` real pole `-q`-d.

    ??? success "Lahendus"
        ```dockerfile
        COPY pom.xml ./
        RUN --mount=type=cache,target=/root/.m2 mvn -B dependency:go-offline
        COPY src ./src
        RUN --mount=type=cache,target=/root/.m2 mvn -B -q package -DskipTests
        ```

        ```bash
        docker build --progress=plain -f k03-docker/app/Dockerfile -t labseis-app:cm . 2>&1 \
          | grep -oE 'Downloaded from [^(]*\([0-9.]+ (B|kB|MB)' | sed -E 's/.*\(([0-9.]+) (B|kB|MB)$/\1 \2/' \
          | awk '{s += ($2 == "MB") ? $1 * 1024 : ($2 == "kB") ? $1 : $1 / 1024} END {printf "%.1f MB, %d faili\n", s / 1024, NR}'
        ```

        Kontroll: esimene build pärast sõltuvuse tagasipanekut laeb alla ainult selle sõltuvuse ja selle transitiivsed sõltuvused (paar MB), ilma cache mount'ita kogu hoidla (sadu MB). `docker buildx du --verbose | grep -B2 -A4 cachemount` näitab cache'i suurust. CI vastus: GitHubi runner on iga job'i jaoks uus VM ja cache mount on olemas ainult kohaliku builder'i olekus. `cache-to type=gha` ekspordib kihid, mitte cache mount'e. Kihtide cache aitab seni, kuni `pom.xml` ei muutu. NB: `prune.sh`-i `docker builder prune` kustutab ka cache mount'id.

        **Miks nii.** Cache mount on BuildKit'i hallatav kaust, mis ühendatakse `RUN`-i ajaks ja mis ei jõua image'i kihti. Kiht `dependency:go-offline` tühistatakse ikka iga `pom.xml`-i muudatusega, aga Maven leiab `/root/.m2/repository`-st juba olemasolevad artefaktid ja laeb alla ainult puuduva. Mõõtmiseks eemalda `go-offline` realt ajutiselt `-q`, et Maven näitaks allalaadimisi.

??? example "3 · Monitooring"

    Docker väljastab olekumuutuse sündmusena `health_status`, aga ei saada sellest teadet kuhugi. Kui app01 olek muutub `unhealthy`-ks, märkab seda praegu alles kasutaja. Uptime Kuma küsib `/health`-i väljast ja saadab teate; detailid on monitooringu kodutöös.

    - teenus `kuma` töötab profiiliga `monitoring` (`docker compose --profile monitoring up -d`);
    - Uptime Kumas on HTTP-monitor `http://web01/health` ja teavituskanal;
    - peata rmq01, oota teadet ja käivita rmq01 uuesti;
    - pane kirja, mitu sekundit kulus peatamisest teateni ja millistest Kuma seadetest see sõltub.

    **Kontroll:**

    ```bash
    docker compose --profile monitoring ps kuma
    docker compose stop rmq01
    curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/health
    docker compose start rmq01
    ```

    **Valmis, kui:**

    - kui rmq01 on peatatud, annab `curl` koodi 503;
    - Kuma näitab monitori `DOWN` olekut ja sündmuste ajaloos on üleminek;
    - teavituskanalisse tuli üks teade peatamisel ja teine pärast `start`-i;
    - tead, millal Kuma teate saadab.

    ??? success "Lahendus"
        ```bash
        docker compose --profile monitoring ps kuma
        docker compose stop rmq01
        curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/health    # 503
        docker compose start rmq01
        ```

        Kontroll: Kuma näitab monitori `DOWN` olekut ja sündmuste ajaloos on üleminek, teavituskanalisse tuli üks teade ja pärast `start`-i teine (`UP`). Lõks: prod-failiga (`compose.prod.yaml`) on web01 ainult võrkudes `front` ja `back`, `kuma` aga vaikevõrgus, ja nimi `web01` ei lahendu. Siis vajab `kuma` prod-failis `networks: [front]`.

        **Miks nii.** rmq01 peatamisel vastab app01 `/health` 503-ga (`"queue":"DOWN"`), web01 annab selle edasi ja Kuma HTTP-monitor loeb 2xx-st erinevat koodi rikkeks. Teade läheb teele olekumuutusel UP → DOWN, mitte iga ebaõnnestunud päringu peale. Seega jõuab see sinuni kõige rohkem `Heartbeat Interval × (Retries + 1)` pärast, korduskatsete vahe on `Heartbeat Retry Interval`.

??? example "4 · Trivy nurjab build'i"

    **Esita:** `k03-docker/scan.sh`

    Praegu vaatad Trivy väljundit silmaga ja haavatav image võib jõuda tootmisse. Skannimine, mis lõpetab veakoodiga, peatab pipeline'i enne seda; sama skript läheb 5. kohtumisel pipeline'i.

    - `scan.sh` skannib kõik kolm image'it (`app`, `db`, `web`, nimed `.env`-ist) võtmetega `--exit-code 1 --severity CRITICAL --ignore-unfixed`;
    - skripti väljumiskood on 0, kui kõik image'id on puhtad, ja 1, kui mõni ebaõnnestus;
    - ehita web-image ka `nginx:1.27-alpine` peal (tag `labseis-web:127`) ja skanni seda.

    **Kontroll:**

    ```bash
    ./scan.sh; echo "kood $?"
    trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed labseis-web:127; echo "kood $?"
    shellcheck scan.sh
    ```

    **Valmis, kui:**

    - `./scan.sh` annab sinu puhaste image'ite peal koodi 0;
    - `1.27-alpine` peal ehitatud web-image ebaõnnestub või annab rohkem leide kui `1.30-alpine`;
    - `shellcheck scan.sh` ei väljasta midagi.

    ??? success "Lahendus"
        ```bash
        #!/usr/bin/env bash
        set -euo pipefail
        cd "$(dirname "$(readlink -f "$0")")"
        set -a
        # shellcheck source=/dev/null
        . ./.env
        set +a
        rc=0
        for n in app db web; do
            img="$REGISTRY/$OWNER/labori-seis-$n:${TAG:-dev}"
            echo "== $img"
            trivy image --quiet --exit-code 1 --severity CRITICAL --ignore-unfixed "$img" || rc=1
        done
        exit "$rc"
        ```

        ```bash
        sed 's/nginx:1.30-alpine/nginx:1.27-alpine/' web/Dockerfile | docker build -q -t labseis-web:127 -f - web
        for i in labseis-web:127 "$REGISTRY/$OWNER/labori-seis-web:$TAG"; do
            trivy image -q --severity CRITICAL,HIGH --ignore-unfixed -f json "$i" \
              | jq -r --arg i "$i" '[.Results[].Vulnerabilities // [] | length] | add | "\($i) \(.)"'
        done
        ```

        Kontroll: `./scan.sh; echo $?` annab 0, kui sinu image'id on puhtad, ja `trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed labseis-web:127; echo $?` annab 1 või leidude arv on suurem kui 1.30 puhul. `shellcheck scan.sh` ei väljasta midagi.

        **Miks nii.** Skript ei lõpeta esimese leiu juures: pipeline'i logis on siis korraga näha kõigi kolme image'i olek. Koondkood on 1, kui mõni image ebaõnnestus. `--ignore-unfixed` jätab välja leiud, millele pole parandust, sest neid ei saa image'i uuesti ehitamisega lahendada.

??? example "5 · Skeemi muudatus olemasolevas baasis"

    **Esita:** `k03-docker/db/migr/001-result-note.sql`

    db-image'i juures nägid, et init-skript ei käivitu olemasoleva volume'iga. Tootmisbaasis muudetakse skeemi migratsiooniga, mis on korduvalt käivitatav ja jõuab ka baasi, mis on juba ammu kasutusel.

    - `001-result-note.sql` lisab tabelisse `result` veeru `note VARCHAR(200) NULL` nii, et teine käivitus ei anna viga;
    - käivita see põhistacki db01-s kaks korda;
    - rakendus töötab edasi: `/health` on `UP` ja POST tulemus jõuab baasi;

    **Kontroll:**

    ```bash
    for _ in 1 2; do
        docker compose exec -T db01 sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" labseis' < db/migr/001-result-note.sql
        echo "kood $?"
    done
    docker compose exec db01 sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" labseis -e "DESCRIBE result"' | grep note
    curl -s localhost:8080/health; echo
    ```

    **Valmis, kui:**

    - mõlemad käivitused lõpevad koodiga 0;
    - `DESCRIBE` näitab rida `note varchar(200) YES`;
    - `/health` on `UP` ja POST jõuab `GET /api/results` vastusesse;

    Vihje: `ADD COLUMN IF NOT EXISTS`.

    ??? success "Lahendus"
        ```sql
        -- 001: tulemuse vabatekstiline märkus. Korduvalt käivitatav, vana kood ignoreerib veergu.
        ALTER TABLE result ADD COLUMN IF NOT EXISTS note VARCHAR(200) NULL;
        ```

        ```bash
        for _ in 1 2; do
            docker compose exec -T db01 sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" labseis' < db/migr/001-result-note.sql
        done
        docker compose exec db01 sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" labseis -e "DESCRIBE result"' | grep note
        curl -s localhost:8080/health; echo
        ```

        Kontroll: mõlemad käivitused lõpevad koodiga 0, `DESCRIBE` näitab rida `note varchar(200) YES`, `/health` on `UP` ja lehe Kogu stack Compose'iga POST jõuab `GET /api/results` vastusesse. initdb vastus: entrypoint käivitab failid failinimede järjekorras ja `001-…` on enne `01-schema.sql`-i, nii et tabelit `result` veel pole. Lisaks käivituvad need failid ainult tühja andmekataloogi korral, seega töötavasse baasi nad nagunii ei jõua.

        **Miks nii.** `ADD COLUMN IF NOT EXISTS` on MariaDB laiendus (MySQL-is seda pole), nii et teine käivitus annab ainult märkuse. Vana image talub veergu, sest `ResultRepository` kirjutab `INSERT`-is veergude nimed välja ja uus veerg lubab väärtust `NULL`: see on expand/contract'i esimene pool.

??? example "6 · Healthcheck'i ajastus"
    app01 healthcheck'i väärtused on praegu Dockerfile'ist võetud, mitte mõõdetud. Vale ajastusega healthcheck teeb deploy aeglaseks või annab valehäireid. Mõõda, kui kaua app01 tegelikult käivitub, ja vali väärtused selle järgi.

    - jälgi teises terminalis olekumuutusi `docker events`-iga (käsk on plokis Kontroll);
    - mõõda aeg app01 uuesti loomisest (`docker compose up -d --force-recreate --no-deps app01`) kuni `healthy`-ni;
    - proovi kolme seadistust: Dockerfile'i vaikeväärtused, `start_period: 5s` koos `retries: 1`-ga ja `interval: 60s`; iga kord märgi aeg `healthy`-ni ja `unhealthy` sündmuste arv;
    - `compose.yaml` jääb lõpuks muutmata.

    **Kontroll:**

    ```bash
    docker events --filter event=health_status --format '{{.Time}} {{.Actor.Attributes.name}} {{.Status}}'
    docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q app01)"
    git diff --stat compose.yaml
    ```

    **Valmis, kui:**

    - `git diff --stat compose.yaml` on tühi ja app01 on `healthy`.

    ??? success "Lahendus"
        ```yaml
        # hc-b.yaml: valehäire
        services:
          app01:
            healthcheck: {start_period: 5s, retries: 1}
        ---
        # hc-c.yaml: aeglane
        services:
          app01:
            healthcheck: {interval: 60s}
        ---
        # hc-d.yaml: tootmine
        services:
          app01:
            healthcheck: {interval: 15s, retries: 3, start_period: 120s, start_interval: 2s}
        ```

        ```bash
        for o in "" hc-b.yaml hc-c.yaml hc-d.yaml; do
            f=(-f compose.yaml); [ -n "$o" ] && f+=(-f "$o")
            t0=$(date +%s); docker compose "${f[@]}" up -d --force-recreate --no-deps app01
            id=$(docker compose ps -q app01)
            until [ "$(docker inspect -f '{{.State.Health.Status}}' "$id")" = healthy ]; do sleep 1; done
            echo "${o:-vaikimisi}: $(( $(date +%s) - t0 )) s, unhealthy: $(docker events --since "$t0" --until "$(date +%s)" \
                --filter container="$id" --filter event=health_status --format '{{.Status}}' | grep -c unhealthy)"
        done
        docker compose up -d --force-recreate --no-deps app01
        ```

        Kontroll: `hc-b` annab vähemalt ühe `unhealthy`, sest java ei vasta 5 s pärast. `hc-c` jõuab `healthy`-ni alles umbes 60 s pärast, ka siis, kui rakendus oli valmis 30 s pärast. `hc-d` jõuab umbes 2 s jooksul pärast valmisolekut ja `unhealthy` on 0. Viimane rida taastab `compose.yaml`-i algse sisu.

        **Miks nii.** Pikk intervall teeb aeglase deploy: teenus on ammu valmis, aga keegi ei tea. Liiga lühike `start_period` teeb valehäire: teenus märgitakse `unhealthy`-ks enne, kui see jõudis käivituda. Koopia asemel on lihtsam override-fail: Compose'i `healthcheck` ilma `test`-ita võtab käsu image'ist ja muudab ainult ajastust. `start_period` ajal ebaõnnestunud kontrolle ei arvestata, aga esimene õnnestumine teeb konteineri kohe `healthy`-ks. Seega `healthy`-ni kulub käivitusaeg pluss kuni üks `interval`. `start_interval` (Engine 25+) laseb käivitusajal kontrollida tihedamalt ilma tavaintervalli lühendamata.

??? example "7 · Väiksem image ilma Tomcatita"

    **Esita:** `k03-docker/app/Dockerfile.jre`

    Tomcati image kannab kaasas terve rakendusserveri, kuigi WAR on käivitatav ja Tomcat on selle sees. Väiksem image tähendab kiiremat tõmbamist ja vähem Trivy leide.

    - `Dockerfile.jre` käitusaste on `eclipse-temurin:21-jre-alpine`, oma kasutaja UID-ga 10001 ja `USER`;
    - `ENTRYPOINT` on exec-vormis: `java -XX:MaxRAMPercentage=75 -jar …`, healthcheck `wget`-iga;
    - võrdle suurust ja HIGH/CRITICAL Trivy leidude arvu Tomcati variandiga;

    **Kontroll:**

    ```bash
    docker image ls labori-seis-app --format '{{.Tag}} {{.Size}}'
    docker exec <konteiner> id
    docker inspect -f '{{.State.Health.Status}}' <konteiner>
    ```

    **Valmis, kui:**

    - `docker exec … id` näitab UID 10001;
    - konteiner on `healthy`;

    ??? success "Lahendus"
        ```dockerfile
        # build-aste sama mis app/Dockerfile-is
        FROM eclipse-temurin:21-jre-alpine
        RUN addgroup -S app && adduser -S -G app -u 10001 app
        WORKDIR /app
        COPY --from=build --chown=app:app /src/target/labori-seis.war /app/app.war
        USER 10001
        EXPOSE 8080
        HEALTHCHECK --interval=15s --timeout=3s --start-period=60s --retries=3 \
            CMD wget -qO- http://127.0.0.1:8080/health > /dev/null || exit 1
        ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.war"]
        ```

        ```bash
        docker build -f k03-docker/app/Dockerfile.jre -t labori-seis-app:jre .
        docker image ls labori-seis-app --format '{{.Tag}} {{.Size}}'
        for t in jre "$TAG"; do trivy image -q --severity HIGH,CRITICAL labori-seis-app:"$t" 2>/dev/null | grep -E '^Total'; done
        docker run -d --name jre --network labori-seis_default --env-file .env labori-seis-app:jre && sleep 75
        docker exec jre id; docker inspect -f '{{.State.Health.Status}}' jre; docker rm -f jre
        ```

        Kontroll: `id` annab `uid=10001(app)`, olek on `healthy`, image on umbes poole väiksem ja OS-pakettide leide on vähem. Erinevused app01 Tomcatiga: `server.xml`-i connector'i seaded, `catalina.out` ja Tomcati access log'id kaovad. Sisseehitatud Tomcati seadistatakse `server.*` omadustega ja logi läheb stdout'i. Prod-faili `CATALINA_OPTS` ei mõju selle image'iga.

        **Miks nii.** Spring Boot'i WAR on käivitatav, sest `spring-boot-maven-plugin` paneb sisseehitatud Tomcati `WEB-INF/lib-provided` kausta ja käivitusklassi manifesti. Alpine'is pole curl'i, healthcheck kasutab busybox'i `wget`-i. `MaxRAMPercentage` läheb `ENTRYPOINT`-i, sest `CATALINA_OPTS`-i siin keegi ei loe.

??? example "8 · Linuxi capability'd maha"

    **Esita:** `k03-docker/compose.prod.yaml`

    Konteineri root'il on vaikimisi kümmekond Linuxi capability't, mida enamik teenuseid ei vaja. Iga ülearune capability on ründajale tööriist, kui ta konteinerisse pääseb.

    - `compose.prod.yaml`-is on mc01-l `cap_drop: [ALL]` ja `security_opt: ["no-new-privileges:true"]` ning ta jääb `healthy`;
    - web01-l on sama ning `cap_add`-is ainult need capability'd, ilma milleta nginx ei käivitu;
    - võrdle capability'sid `docker inspect`-i ja `/proc/1/status`-i järgi enne ja pärast.

    **Kontroll:**

    ```bash
    P=(docker compose -f compose.yaml -f compose.prod.yaml)
    "${P[@]}" up -d --wait mc01 web01
    docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$("${P[@]}" ps -q web01)"
    "${P[@]}" exec web01 grep Cap /proc/1/status
    ```

    **Valmis, kui:**

    - mc01 ja web01 on `healthy`;
    - web01 `cap_add` nimekirjast ei saa ühtegi capability't eemaldada, ilma et nginx ebaõnnestuks;

    Vihje: alusta logist, `docker compose logs web01`.

    ??? success "Lahendus"
        ```yaml
          mc01:
            cap_drop: [ALL]
            security_opt: ["no-new-privileges:true"]
          web01:
            cap_drop: [ALL]
            cap_add: [CHOWN, SETGID, SETUID]
            security_opt: ["no-new-privileges:true"]
        ```

        ```bash
        P=(docker compose -f compose.yaml -f compose.prod.yaml)
        "${P[@]}" up -d --wait mc01 web01
        "${P[@]}" exec web01 grep -E 'CapEff|CapBnd' /proc/1/status
        "${P[@]}" exec mc01 grep CapBnd /proc/1/status
        "${P[@]}" exec web01 cat /proc/sys/net/ipv4/ip_unprivileged_port_start
        ```

        Kontroll: mõlemad on `healthy`, web01 `CapEff` ja `CapBnd` on `00000000000000c1` (bitid 0, 6 ja 7), mc01 `CapBnd` on `0000000000000000`, sysctl annab `0`. Ilma `CHOWN`-ita on logis `chown("/var/cache/nginx/client_temp", 101) failed (1: Operation not permitted)`. Täpne minimaalne nimekiri sõltub Nginx'i image'i versioonist, otsusta oma logi järgi.

        **Miks nii.** memcached töötab image'is kasutajana `memcache` ja ei vaja ühtegi capability't. nginx'i master on root: `CHOWN` vajab ta selleks, et anda `/var/cache/nginx/*_temp` kaustad worker'i kasutajale, ning `SETGID` ja `SETUID` selleks, et worker'id kasutajale `nginx` üle viia. `NET_BIND_SERVICE` pole vaja, sest Docker seab konteineris `net.ipv4.ip_unprivileged_port_start=0`. `no-new-privileges` takistab ainult setuid-bitiga failide käivitamist, `setuid()` süsteemikutset mitte.

??? example "9 · Mikroteenused: tulemuste consumer eraldi konteineriks"

    **Esita:** `k03-docker/compose.micro.yaml`

    API ja järjekorra consumer on praegu üks protsess: neid ei saa eraldi skaleerida ega uuendada, ja consumer'i rike peatab ka API. Jaga need kaheks teenuseks koodi muutmata; kõik peab mahtuma 4 GB VM-i.

    - `compose.micro.yaml`-is on sama image kahe teenusena: `api` (POST `/api/results` ja koondtabel) ja `worker` (järjekorrast MariaDB-sse);
    - `api` teenusel on consumer välja lülitatud (`SPRING_RABBITMQ_LISTENER_SIMPLE_AUTOSTARTUP=false`), `worker` jääb vaikeseadega;
    - mõlemal on healthcheck ja `depends_on` koos `condition: service_healthy`-ga; andmebaasi ja RabbitMQ porte pole hostis avaldatud;
    - käivita `docker compose -f compose.micro.yaml up -d --scale worker=3`, peata kõik workerid minutiks ja saada vahepeal tulemusi.

    **Kontroll:**

    ```bash
    M=(docker compose -f compose.micro.yaml)
    "${M[@]}" exec rmq01 rabbitmqctl list_queues name messages consumers
    curl -s localhost:8080/api/results; echo
    ```

    **Valmis, kui:**

    - kolme workeriga näitab `list_queues` järjekorral `results` kolme consumer'it;
    - põhistack on lõpus jälle üleval.

    ??? success "Lahendus"
        ```yaml
        name: labori-seis-micro
        x-app: &app
          image: ${APP_IMAGE:-${REGISTRY:?}/${OWNER:?}/labori-seis-app:${TAG:-dev}}
          restart: unless-stopped
          depends_on:
            db01: {condition: service_healthy}
            rmq01: {condition: service_healthy}
            mc01: {condition: service_healthy}
        services:
          # db01, mc01, rmq01 nagu compose.yaml-is, ilma ports:-ita
          api:
            <<: *app
            environment:
              DB_PASSWORD: ${DB_PASSWORD:?}
              RABBITMQ_PASSWORD: ${RABBITMQ_PASSWORD:?}
              TEACHER_TOKEN: ${TEACHER_TOKEN:?}
              SPRING_RABBITMQ_LISTENER_SIMPLE_AUTOSTARTUP: "false"
          worker:
            <<: *app
            environment:
              DB_PASSWORD: ${DB_PASSWORD:?}
              RABBITMQ_PASSWORD: ${RABBITMQ_PASSWORD:?}
              TEACHER_TOKEN: ${TEACHER_TOKEN:?}
          web01:
            image: ${REGISTRY:?}/${OWNER:?}/labori-seis-web:${TAG:-dev}
            environment: {APP_UPSTREAM: "api:8080"}
            ports: ["${WEB_PORT:-8080}:80"]
            depends_on: {api: {condition: service_healthy}}
        volumes: {dbdata: {}, rmqdata: {}}
        ```

        ```bash
        docker compose down && M=(docker compose -f compose.micro.yaml) && "${M[@]}" up -d --scale worker=3 --wait
        "${M[@]}" exec rmq01 rabbitmqctl list_queues name messages consumers     # results 0 3
        "${M[@]}" stop worker
        for i in 1 2 3 4 5; do curl -s -X POST localhost:8080/api/results -H 'Authorization: Bearer demo-kati-token' \
            -H 'Content-Type: application/json' -d '{"lab":"lab-03","check":"micro-'"$i"'","status":"OK"}'; echo; done
        "${M[@]}" exec rmq01 rabbitmqctl list_queues name messages consumers     # results 5 0
        "${M[@]}" start worker && sleep 15 && "${M[@]}" exec rmq01 rabbitmqctl list_queues name messages consumers
        ```

        Kontroll: kui workerid olid peatatud, vastas `api` `{"status":"accepted"}` ja järjekorras oli 5 sõnumit 0 consumer'iga, pärast `start`-i on 0 sõnumit ja 3 consumer'it ning `GET /api/results` näitab `micro-1` kuni `micro-5`. Ükski saadetud tulemus ei läinud kaotsi. Lõks: workeri healthcheck kontrollib baasi ja järjekorra ühendust, mitte listener'it, seega katkine consumer on ikkagi `healthy`. Lõpus `"${M[@]}" down -v && docker compose up -d --wait`. Täisfail on õpetajal.

        **Miks nii.** Eraldi projekti nimi hoiab volume'id põhistackist lahus. web01 suunab liikluse `api`-le template'i muutujaga `APP_UPSTREAM`, `worker`-il pole porti ega liiklust. Järjekord `results` on durable ja Spring saadab sõnumid vaikimisi persistent'ina, seega workeriteta jäävad sõnumid järjekorda ja säilivad ka pärast rmq01 taaskäivitust.

??? example "10 · Docker socket'i audit"

    **Esita:** `k03-docker/audit.sh`

    Konteiner, millele on mount'itud `/var/run/docker.sock`, saab käivitada uue konteineri hosti `/`-ga ja on seega sisuliselt root hostis. Monitooringu- ja CI-tööriistad küsivad socket'it sageli, ja serveris tuleb need üles leida.

    - vaata testkonteineriga, mida socket'iga konteiner näeb: `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker:29-cli docker ps`;
    - `audit.sh` käib läbi kõik töötavad konteinerid ja märgib need, millel on socket'i mount, `--privileged`, `network_mode: host` või `pid: host`;
    - käivita skript nii, et Labori seis töötab ja taustal töötab üks socket'iga testkonteiner, ning siis ilma testkonteinerita.

    **Kontroll:**

    ```bash
    docker run -d --name sockproov -v /var/run/docker.sock:/var/run/docker.sock docker:29-cli sleep 600
    ./audit.sh; docker rm -f sockproov; ./audit.sh
    shellcheck audit.sh
    ```

    **Valmis, kui:**

    - esimene käivitus märgib ainult `sockproov`-i;
    - teine käivitus ei märgi midagi;
    - `shellcheck audit.sh` vaikib;

    Vihje: alusta käsust `docker inspect -f '{{.Name}} {{.HostConfig.Privileged}} {{.HostConfig.NetworkMode}} {{range .Mounts}}{{.Source}} {{end}}'`.

    ??? success "Lahendus"
        ```bash
        #!/usr/bin/env bash
        set -euo pipefail
        found=0
        while IFS= read -r id; do
            IFS='|' read -r name priv net pid mounts < <(docker inspect -f \
                '{{.Name}}|{{.HostConfig.Privileged}}|{{.HostConfig.NetworkMode}}|{{.HostConfig.PidMode}}|{{range .Mounts}}{{.Source}} {{end}}' "$id")
            why=()
            [[ " $mounts" == *"docker.sock "* ]] && why+=("docker.sock")
            [[ "$priv" == true ]] && why+=("privileged")
            [[ "$net" == host ]] && why+=("network=host")
            [[ "$pid" == host ]] && why+=("pid=host")
            if [[ ${#why[@]} -gt 0 ]]; then echo "${name#/} ${why[*]}"; found=1; fi
        done < <(docker ps -q)
        exit "$found"
        ```

        ```bash
        docker run -d --name sockproov -v /var/run/docker.sock:/var/run/docker.sock docker:29-cli sleep 600
        ./audit.sh; echo "kood $?"
        docker rm -f sockproov; ./audit.sh; echo "kood $?"
        ```

        Kontroll: esimene käivitus väljastab ainult `sockproov docker.sock` ja koodi 1, teine ei väljasta midagi ja annab koodi 0. Socket'i `:ro` mount ei aita, sest see piirab faili, mitte API-kutseid. Ilma socket'ita saab monitooring info cgroup'idest (cAdvisor, node_exporter) või socket proxy kaudu, mis lubab ainult `GET /containers` ja `GET /events` (nt `tecnativa/docker-socket-proxy`).

        **Miks nii.** Iga konteineri kohta on üks `docker inspect` kõigi väljadega ja leitud põhjused lähevad massiivi. Väljumiskood 1, kui midagi leiti, teeb skriptist cron'i või monitooringu kontrolli.

??? example "11 · Varundus timeriga ja taastamise test"

    **Esita:** `k03-docker/backup.sh`

    Volume'i varundamise samm on praegu käsitsi tehtav ja taastamist varukoopiast pole proovitud. Tee sellest systemd timer'iga korduv töö, mis taastab koopia ajutisse konteinerisse ja kontrollib selle sisu.

    - `backup.sh` teeb `mariadb-dump --single-transaction` koopia (vt Tootmiskeskkonda sobiv stack, lõik "Varukoopia ilma katkestuseta") kuupäevaga faili `backup/` alla, alles jääb seitse viimast varukoopiat, kood on ≠ 0, kui dump ebaõnnestus;
    - võti `--verify` taastab viimase koopia ajutisse MariaDB konteinerisse, kontrollib, et tabelis `result` on ridu, ja koristab konteineri;
    - `systemctl --user` timer käivitab selle kord ööpäevas (`Persistent=true`), tulemus läheb `logger -t labseis-backup` kaudu journal'isse.

    **Kontroll:**

    ```bash
    systemctl --user list-timers labseis-backup.timer
    ./backup.sh --verify; echo "kood $?"
    for _ in $(seq 1 8); do ./backup.sh > /dev/null; sleep 1; done; ls backup/ | wc -l
    journalctl -t labseis-backup -n 5 --no-pager
    ```

    **Valmis, kui:**

    - `systemctl --user list-timers` näitab järgmise käivituse aega;
    - `./backup.sh --verify` annab koodi 0;
    - kaheksas käivitus kustutab vanima faili ja `backup/`-is on 7 faili;
    - journal'is on iga käivituse tulemus.

    ??? success "Lahendus"
        ```bash
        # backup.sh põhiosa (set -euo pipefail, cd skripti kausta, log() = echo + logger -t labseis-backup)
        out="backup/labseis-$(date +%Y%m%d-%H%M%S).sql.gz"; tmp="$out.part"; mkdir -p backup
        docker compose exec -T db01 sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb-dump -uroot \
            --single-transaction --routines --triggers --databases labseis' | gzip > "$tmp" || die "dump ebaõnnestus"
        gzip -dc "$tmp" | tail -n 1 | grep -q '^-- Dump completed' || die "dump on poolik"
        mv "$tmp" "$out"
        mapfile -t files < <(find backup -maxdepth 1 -name 'labseis-*.sql.gz' -printf '%f\n' | sort -r)
        for f in "${files[@]:7}"; do rm -f -- "backup/$f"; done

        # --verify
        last=$(find backup -maxdepth 1 -name 'labseis-*.sql.gz' | sort -r | head -n 1)
        c="labseis-verify-$$"; trap 'docker rm -f "$c" >/dev/null 2>&1 || true' EXIT
        docker run -d --name "$c" --network none -e MARIADB_ROOT_PASSWORD="$(od -An -tx1 -N12 /dev/urandom | tr -d ' \n')" mariadb:11.4
        until docker exec "$c" healthcheck.sh --connect --innodb_initialized 2>/dev/null; do sleep 2; done   # tootmisskriptis ajapiiriga
        gzip -dc "$last" | docker exec -i "$c" sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot'
        n=$(docker exec "$c" sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot -N -e "SELECT COUNT(*) FROM labseis.result"')
        [[ "$n" -gt 0 ]] || die "taastatud baasis result=$n"
        ```

        ```ini
        # ~/.config/systemd/user/labseis-backup.service
        [Service]
        Type=oneshot
        ExecStart=%h/<repo>/k03-docker/backup.sh
        ExecStart=%h/<repo>/k03-docker/backup.sh --verify

        # ~/.config/systemd/user/labseis-backup.timer
        [Timer]
        OnCalendar=*-*-* 02:30:00
        RandomizedDelaySec=15min
        Persistent=true
        [Install]
        WantedBy=timers.target
        ```

        ```bash
        systemctl --user daemon-reload && systemctl --user enable --now labseis-backup.timer
        loginctl enable-linger "$USER"
        systemctl --user list-timers labseis-backup.timer; ./backup.sh --verify; echo "kood $?"
        for _ in $(seq 1 8); do ./backup.sh > /dev/null; sleep 1; done; ls backup/ | wc -l
        ```

        Kontroll: `list-timers` näitab `NEXT` aega, `--verify` annab koodi 0 ja journal'is on `VERIFY OK … result=N`, pärast kaheksat käivitust on `backup/`-is 7 faili. Lõks: ilma `enable-linger`-ita ei käivitu kasutaja timer, kui keegi pole sisse loginud. Prod-failis pole `MARIADB_ROOT_PASSWORD`-i keskkonnas, siis loe parool failist `/run/secrets/DB_ROOT_PASSWORD`. Täisskript on õpetajal.

        **Miks nii.** Kolm kohta, kus lihtne skript eksib: `docker compose exec … | gzip` annab ilma `pipefail`-ita koodi 0 ka siis, kui dump ebaõnnestus; poolik fail ei tohi saada lõplikku nime (kirjuta `.part` ja `mv`); `mariadb-dump` kirjutab viimaseks reaks `-- Dump completed`, ja see on odav terviklikkuse kontroll. Ajutine MariaDB tuleb `--network none`-ga ja valmisolekut kontrollib `healthcheck.sh --connect`, mis init-faasi ajutise serveri ajal (`--skip-networking`) ei läbi.

??? example "12 · Oma baas-image ja selle elutsükkel"

    **Esita:** `k03-docker/base/Dockerfile`, `base-build.sh`, `base-stale.sh`, `app/Dockerfile.base`

    app01 image'i käitusaste paigaldab ise curl'i, loob kasutaja 10001 ja kustutab Tomcati näiterakendused. Kui sama teeb kümme meeskonda, on kümme veidi erinevat baasi ja pärast üht turvaparandust pole selge, millised image'id on veel vana Tomcati peal.

    - `base/Dockerfile` ja `base-build.sh`: upstream'i image `tomcat:10.1-jre21-temurin` lahendatakse build'i ajal digest'iks ja kirjutatakse label'isse `org.opencontainers.image.base.digest`; baasis on app01 käitusastme `RUN` (curl, kasutaja 10001, õigused), `tzdata` ja `TZ=Europe/Tallinn`;
    - `base-build.sh` skannib baasi (CRITICAL nurjab) ja lükkab registry'sse tag'id `labseis-base-tomcat:<YYYYMMDD>` ja liikuva `labseis-base-tomcat:10.1-jre21`;
    - `app/Dockerfile.base`: build-aste sama mis `app/Dockerfile`-is, käitusaste `FROM ${BASE}` ilma oma `apt-get`-ita; põhilabori `app/Dockerfile` jääb muutmata;
    - `base-stale.sh <baas> <image>...` väljastab iga image'i kohta `OK` või `VANA` ja lõpetab koodiga 1, kui mõni image on ehitatud baasi varasema versiooni peale; ära usalda image'i nime ega label'it, kontrolli sisu;

    **Kontroll:**

    ```bash
    B="$REGISTRY/$OWNER/labseis-base-tomcat:10.1-jre21"; A="$REGISTRY/$OWNER/labori-seis-app:base-$TAG"
    ./base-stale.sh "$B" "$A"; echo "kood $?"
    ./base-build.sh && PULL=0 ./base-stale.sh "$B" "$A"; echo "kood $?"
    # pärast app01 uut build'i Dockerfile.base-iga: ./base-stale.sh "$B" "$A"
    docker image inspect -f '{{index .Config.Labels "org.opencontainers.image.base.digest"}}' "$B"
    ```

    **Valmis, kui:**

    - esimene kontroll annab `OK` ja koodi 0;
    - pärast baasi uut build'i annab sama image `VANA` ja koodi 1, pärast app01 uut build'i jälle `OK`;
    - label'is on `sha256:…`;
    - ShellCheck ei anna hoiatusi.

    ??? success "Lahendus"
        ```dockerfile
        # base/Dockerfile
        ARG UPSTREAM=tomcat:10.1-jre21-temurin
        FROM ${UPSTREAM}
        ARG UPSTREAM
        ARG UPSTREAM_DIGEST=unknown
        RUN apt-get update -qq \
            && apt-get install -y -qq --no-install-recommends curl ca-certificates tzdata \
            && rm -rf /var/lib/apt/lists/* /usr/local/tomcat/webapps/* \
            && ln -sf /usr/share/zoneinfo/Europe/Tallinn /etc/localtime \
            && useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin labseis \
            && mkdir -p /usr/local/tomcat/conf/Catalina/localhost \
            && chown -R 10001:10001 /usr/local/tomcat/logs /usr/local/tomcat/temp /usr/local/tomcat/work \
                /usr/local/tomcat/webapps /usr/local/tomcat/conf/Catalina
        ENV TZ=Europe/Tallinn
        LABEL org.opencontainers.image.base.name="${UPSTREAM}" \
              org.opencontainers.image.base.digest="${UPSTREAM_DIGEST}"
        ```

        ```bash
        # base-build.sh põhiosa (set -euo pipefail, cd skripti kausta, .env loetud nagu scan.sh-is)
        up=tomcat:10.1-jre21-temurin; docker pull -q "$up" > /dev/null
        ref=$(docker image inspect -f '{{index .RepoDigests 0}}' "$up")      # docker.io/library/tomcat@sha256:…
        img="$REGISTRY/$OWNER/labseis-base-tomcat"; day=$(date +%Y%m%d)
        docker build --no-cache --build-arg UPSTREAM="$ref" --build-arg UPSTREAM_DIGEST="${ref#*@}" \
            -t "$img:$day" -t "$img:10.1-jre21" base
        trivy image --quiet --exit-code 1 --severity CRITICAL --ignore-unfixed "$img:$day"
        docker push -q "$img:$day" && docker push -q "$img:10.1-jre21"
        ```

        ```bash
        #!/usr/bin/env bash
        # base-stale.sh <baas> <image>...   PULL=0 jätab tõmbamise vahele
        set -euo pipefail
        base=${1:?baas-image puudub}; shift
        [[ $# -gt 0 ]] || { echo "image'id puuduvad" >&2; exit 2; }
        pull() { [[ ${PULL:-1} == 1 ]] && docker pull -q "$1" > /dev/null; return 0; }
        layers() { docker image inspect -f '{{json .RootFS.Layers}}' "$1"; }
        pull "$base"; top=$(layers "$base" | jq -r '.[-1]'); rc=0
        for img in "$@"; do
            pull "$img"
            if layers "$img" | jq -e --arg t "$top" 'any(.[]; . == $t)' > /dev/null; then
                echo "OK     $img"
            else
                echo "VANA   $img"; rc=1
            fi
        done
        exit "$rc"
        ```

        `app/Dockerfile.base` algab `ARG BASE=…` reaga enne esimest `FROM`-i (globaalne ARG), käitusaste on `FROM ${BASE}`, selle järel `COPY --from=build`, `HEALTHCHECK`, `GIT_SHA` label ja `USER 10001` nagu `app/Dockerfile`-is. Ehita `--build-arg BASE="$B" -t "$A"`.

        Kontroll: nagu ülesande juures, kolm käivitust annavad `OK`/0, `VANA`/1 ja pärast `docker build -f app/Dockerfile.base …` jälle `OK`/0. Lõks: baasi label'id päritakse, nii et app01 image'is näitab `org.opencontainers.image.base.digest` Tomcati upstream'i, mitte sinu baasi. Kirjuta see rakenduse Dockerfile'is üle või ära tee selle põhjal otsuseid. Täisfailid on õpetajal.

        **Miks nii.** `FROM` kopeerib baasi kihid rakenduse image'isse. Kui baasi viimane kiht (`RootFS.Layers` viimane element) on rakenduse kihtide seas, on rakendus ehitatud just selle baasi peale. Kuupäevaga tag ja label võivad valetada, kihi räsi mitte. `--no-cache` baasi build'il on vajalik, muidu jätab cache vana `apt-get` kihi alles ja paik ei jõua baasi.

??? example "13 · Saladuse rotatsioon töötavas stackis"

    **Esita:** `k03-docker/rotate-db-password.sh`

    Prod-failis on andmebaasi parool failis `secrets/DB_PASSWORD`. Auditi järel tuleb kasutaja `labseis` parool vahetada töötavas stackis: andmed ei kao, katkestus on ainult app01 uuesti loomise aeg ja ebaõnnestumisel taastatakse eelmine olek. MariaDB-l pole topeltparooli (MySQL 8 `RETAIN CURRENT PASSWORD`), nii et vana ja uus parool ei kehti korraga.

    - enne esimest käivitust salvesta algseis: `ps`, tabeli `result` ridade arv ja `sha256sum secrets/DB_PASSWORD`;
    - `rotate-db-password.sh` kontrollib enne muudatust, et failis olev parool töötab baasis ja `/health` on `UP`; kui ei, ei muuda midagi;
    - uus parool genereeritakse skriptis ega ole üheski käsurea argumendis (hosti `ps`, shelli ajalugu);
    - pärast käivitust on uus parool baasis, `secrets/DB_PASSWORD`-is ja `.env`-is, ja uuesti luuakse ainult app01;
    - kui mõni samm pärast baasi muutmist ebaõnnestub, taastab skript baasi parooli ja failid ning lõpetab koodiga ≠ 0;
    - proovi ebaõnnestumist `APP_IMAGE=<lisaprojekti katki image> ./rotate-db-password.sh`-iga, loo siis app01 tavalise image'iga uuesti.

    **Kontroll:**

    ```bash
    D=(docker compose -f compose.yaml -f compose.prod.yaml); OLD=$(< secrets/DB_PASSWORD)
    ./rotate-db-password.sh; echo "kood $?"; curl -s localhost:8080/health; echo
    printf '%s\n' "$OLD" | "${D[@]}" exec -T db01 sh -c 'read -r p; MYSQL_PWD="$p" mariadb -ulabseis -e "SELECT 1" labseis'
    grep -c "$OLD" .env secrets/DB_PASSWORD; "${D[@]}" ps --format '{{.Service}} {{.RunningFor}}'
    ```

    **Valmis, kui:**

    - skript lõpetas koodiga 0 ja `/health` näitab `"db":"UP"`;
    - vana parool annab `ERROR 1045` ja `grep -c` annab mõlemale failile 0;
    - ainult app01 on uus ja ridade arv `result`-is ei vähenenud;
    - ebaõnnestumise katse lõppes koodiga ≠ 0 ja vana parool töötas pärast seda.

    ??? tip "Lahenduse suund"
        Parool muutub baasis ainult `ALTER USER 'labseis'@'%' IDENTIFIED BY …` käsuga. `MARIADB_PASSWORD_FILE` loeb entrypoint ainult tühja andmekataloogi korral. Faili muutmine ja db01 uuesti loomine ei tee olemasoleva volume'iga midagi, ja see on ülesande peamine lõks. Järjekord: eelkontroll → failide varukoopia kausta `secrets/` → `ALTER USER` root'ina → uus väärtus faili ja `.env`-i → `up -d --no-deps --force-recreate --wait app01` → kontroll. `ALTER USER` ei katkesta olemasolevaid sessioone, nii et HikariCP pool'i ühendused töötavad app01 uuesti loomiseni edasi. SQL ja paroolid saada konteinerisse `docker compose exec -T` stdin'i kaudu, konteineris kasuta `MYSQL_PWD`-d, mitte `-p<parool>`-i. Faili kirjuta `printf '%s' > fail`-iga: sama inode jääb alles ja töötav db01 näeb bind mount'i kaudu kohe uut sisu, `mv` või redaktor teeks uue inode'i. Tüüpilised lõksud: `.env` jääb vanaks ja järgmine `docker compose up -d` ilma prod-failita annab `"db":"DOWN"`; `.env.bak` repo juures ei ole `.gitignore`-is; `set -e` lõpetab skripti enne rollback'i, kui samm 4 või 5 ei ole `|| rollback` kaitse all. Ilma katkestuseta variant kasutab sammu 5 asemel ülesande 14 mustrit või kahte vahelduvat kasutajat (`DB_USER`).

??? example "14 · Uuendus ilma katkestuseta"

    **Esita:** `k03-docker/rollout.sh`

    Compose peatab `up -d` ajal vana app01 enne uue käivitamist, ja see vahe annab web01 kaudu 502. Lisaprojekti `uuenda.sh` teeb sama. Kasutaja ei tohi näha ühtegi vastust peale 200 ja vigase image'iga konteinerisse ei tohi kunagi liiklust suunata; Compose ise kahte versiooni korraga ei halda, seega lahendus on skriptis.

    - tee vigane image `katki`, mis käivitub, aga ei saa kunagi `healthy` (sama mis lisaprojekti eeltingimustes):

        ```bash
        printf 'FROM %s\nHEALTHCHECK --interval=5s --retries=2 CMD false\n' "$R/labori-seis-app:$TAG" \
            | docker build -t "$R/labori-seis-app:katki" - && docker push "$R/labori-seis-app:katki"
        ```

    - `rollout.sh <tag>` kontrollib enne muudatust, et image on registry's; kui ei ole, stack jääb puutumata;
    - uus app01 koopia töötab vana kõrval ja liiklus jõuab uuele alles siis, kui see on `healthy`; vana peatatakse alles siis, kui web01 teab uue koopia aadressi;
    - kui uus koopia ei jõua `healthy` olekusse, eemaldatakse ainult see ja vana konteiner teenindab edasi;
    - pärast õnnestunud uuendust ei vii `docker compose up -d` app01-te vanale image'ile tagasi; ShellCheck ei anna hoiatusi;
    - käivita teises terminalis mõõtmine ja tee kaks uuendust: uus tag ja `katki`.

    **Kontroll:**

    ```bash
    ( for _ in $(seq 1 900); do curl -s -o /dev/null -m 10 -w '%{http_code}\n' localhost:8080/health; sleep 0.2; done ) > codes.txt &
    ./rollout.sh "<uus tag>"; echo "kood $?"; ./rollout.sh katki; echo "kood $?"
    wait; sort codes.txt | uniq -c
    curl -s localhost:8080/version; echo; docker compose ps app01 --format '{{.Name}} {{.Image}}'
    docker compose up -d 2>&1 | grep app01
    ```

    **Valmis, kui:**

    - `codes.txt`-is on ainult `200`;
    - `/version` näitab uut tag'i ja `katki` lõppes koodiga 1;
    - app01 konteinereid on täpselt üks, uue tag'iga;
    - viimane `up -d` ütleb app01 kohta `Running`, mitte `Recreated`.

    ??? tip "Lahenduse suund"
        Muster on sama mis tööriistal [docker-rollout](https://github.com/wowu/docker-rollout): `APP_IMAGE=<uus> docker compose up -d --no-deps --no-build --no-recreate --scale app01=2 app01`. `--no-recreate` jätab vana konteineri alles, kuigi tema konfiguratsioon enam ei klapi, ja uus koopia saab uue image'i. app01-l pole `ports:` ega `container_name:`, nii et kaks koopiat ei põrka kokku. Uue koopia ID leiad `docker compose ps -q app01` võrdlusest enne ja pärast. Oota `docker inspect -f '{{.State.Health.Status}}'` kuni `healthy`, siis veel üle 10 s, sest nginx lahendab nime `app01` uuesti `resolver valid=10s` järgi ja peab nägema mõlemat IP-d. Seejärel `docker stop` ja `docker rm` vanale. Kuni 10 s jooksul võib nginx proovida kadunud IP-d, aga `proxy_next_upstream error timeout` (vaikeväärtus) proovib järgmist aadressi, nii et GET saab 200. Lõpuks kirjuta `APP_IMAGE=<uus>` `.env`-i, muidu loob järgmine `up -d` app01 uuesti `.env`-i `TAG`-iga. Tüüpilised lõksud: vana peatamine kohe pärast `healthy` olekut annab 502 akna; skriptid, mis kasutavad nime `labori-seis-app01-1`, ei leia enam konteinerit, sest uus on `-2`; kaks JVM-i korraga vajavad mälu, prod-failis 2 × 768 MB.

??? example "Lisaprojekt · uuendus ja rollback"

    **Esita:** `k03-docker/uuenda.sh`

    Praegu uuendad app01-te käsitsi ja kui uus image ei käivitu, otsid eelmise tag'i ise üles. Skript `uuenda.sh` viib app01 uuele image'i tag'ile, kontrollib tulemust ja läheb vea korral ise eelmisele tagasi. Nõuded on ülevalt alla ka skripti töö järjekord: ükski samm ei muuda stacki enne, kui eelmine on õnnestunud.

    - põhistack töötab ilma prod-failita (`COMPOSE_FILE` seadmata) ja Harboris on vähemalt kaks app-image'i tag'i (muuda `VersionController.java`-s üht rida, commit'i, `docker compose build app01 && docker compose push app01` uue `TAG`-iga);
    - vigane image `katki` käivitub, aga ei saa kunagi `healthy`:

        ```bash
        printf 'FROM %s\nHEALTHCHECK --interval=5s --retries=2 CMD false\n' "$R/labori-seis-app:$TAG" \
            | docker build -t "$R/labori-seis-app:katki" - && docker push "$R/labori-seis-app:katki"
        ```

    - `uuenda.sh <tag>` annab ilma argumendita kasutusjuhendi ja koodi 2; `set -euo pipefail`, ShellCheck ei anna hoiatusi; image'i täisnimi tuleb `.env`-i `REGISTRY` ja `OWNER` väärtustest;
    - enne muudatust kontrollib, et image on registry's (`docker pull`); kui ei ole, stack jääb puutumata;
    - salvestab praeguse image'i ja uuendab ainult app01-te: `APP_IMAGE=… docker compose up -d --no-deps --no-build --wait app01`;
    - pärast uuendust küsib `/health`-i web01 kaudu;
    - ebaõnnestumisel paneb tagasi eelmise image'i ja lõpetab koodiga 1;
    - iga käivituse tulemus läheb `logger -t labseis-deploy` kaudu journal'isse.

    **Kontroll:**

    ```bash
    ./uuenda.sh; echo "kood $?"
    ./uuenda.sh olematu; echo "kood $?"; docker inspect -f '{{.Config.Image}}' labori-seis-app01-1
    ./uuenda.sh katki; echo "kood $?"; docker inspect -f '{{.Config.Image}}' labori-seis-app01-1
    ./uuenda.sh "<uus tag>" && curl -s localhost:8080/version; echo
    sudo journalctl -t labseis-deploy -n 4 --no-pager
    ```

    **Valmis, kui:**

    - kolm esimest käivitust lõppesid koodiga ≠ 0, app01 jäi vanale image'ile ja on `healthy`;
    - neljas käivitus viis `/version`-i uuele tag'ile ja teiste teenuste `RunningFor` ei muutunud;
    - journal'is on neli rida.

    Vihje: praeguse image'i nime annab `docker inspect -f '{{.Config.Image}}' labori-seis-app01-1`.

    ??? tip "Lahenduse suund"
        Skriptil on kolm osa: kontroll, muudatus ja tulemuse kontroll. Iga osa lõpeb kas `exit`-iga või läheb järgmisse. Logi ka kasutusviga, enne `exit 2`-te. Image'i täisnime saad, kui loed `.env`-i (`set -a; . ./.env; set +a`) ja paned kokku `$REGISTRY/$OWNER/labori-seis-app:$1`. Olemasolu kontrolliks sobib `docker pull -q`: see kontrollib korraga registry't, autentimist, CA-d ja tag'i. Eelmine image tuleb töötavalt konteinerilt (`docker inspect -f '{{.Config.Image}}' "$(docker compose ps -q app01)"`), mitte `.env`-ist, sest `.env` ütleb, mis peaks töötama, konteiner aga, mis töötab. Uuendus ja rollback on sama funktsioon erineva image'iga: `APP_IMAGE="$1" docker compose up -d --no-deps --no-build --wait --wait-timeout 180 app01`. `--wait` lõpeb veaga, kui konteiner läheb `unhealthy`. Pärast seda küsi `/health`-i web01 kaudu korduskatsega umbes 30 s, sest nginx lahendab uue konteineri IP alles `resolver valid=10s` järel. Kasuta eraldi väljumiskoode: uuendus ebaõnnestus ja rollback õnnestus ning ka rollback ebaõnnestus. Konveier peab neid eristama. Tüüpilised lõksud: konteineri nimi koodis (`labori-seis-app01-1`) läheb katki, kui keegi on teenust skaleerinud; `set -e` lõpetab skripti enne rollback'i, kui `deploy` ei ole `if`-i tingimuses. Täislahendus on õpetajal.

        **Miks nii.** Skript on käsitsi käivitatav versioon sellest, mida GitHub Actionsi pipeline deploy-sammus teeb. `up -d` loob app01 uuesti: vana konteiner peatatakse, uus käivitatakse. Selle vahe jooksul vastab web01 502-ga, sest teist app01 koopiat pole. Compose ei tee rolling update'i ega hoia eelmist versiooni meeles; mõlemad on skripti või orkestraatori töö. Kubernetes teeb sama Deployment'iga: uus pod käivitatakse enne vana peatamist ja liiklus läheb sinna alles siis, kui readiness-kontroll õnnestub.

        Rollback sõltub sellest, kas vana image on veel olemas. Lokaalne cache pole selleks usaldusväärne koht, sest `prune.sh` kustutab vanad image'id. Registry on õige koht, ja seepärast on mõistlik registry's hoida vähemalt mõnda eelmist versiooni. Kui tahad garanteerida, et rollback toob täpselt sama sisu, salvesta tag'i asemel digest.

        Skript võtab tagasi ainult image'i, volume jääb uude olekusse. Kui uus versioon muutis skeemi, peab skeem ühilduma ka eelmise image'iga (expand/contract: kõigepealt lisatakse veerg, mida vana kood ignoreerib, ja eemaldatakse alles järgmises versioonis). Muidu saab rollback'i teha ainult varukoopiast ja sellega kaasneb andmekadu.

??? example "Lisaprojekt · oma registry control'is"

    **Esita:** `k03-docker/registry/compose.yaml`, `k03-docker/.gitignore`

    Harbor on valmis teenus ja selle sisemust sa ei näe. Paned control'is käima oma `registry:2` TLS-i ja parooliga ning lükkad sinna Labori seisu web-image'i.

    - kaust `k03-docker/registry/` alamkaustadega `certs/` ja `auth/`, mõlemad `.gitignore`-is; self-signed sertifikaat SAN-iga control'i IP ja bcrypt'iga paroolifail:

        ```bash
        sudo ss -tlnp | grep ':5000 '; command -v openssl jq    # port vaba, tööriistad olemas
        cd k03-docker/registry && IP=<control IP VPN-is>    # see on registry nimi
        openssl req -x509 -newkey rsa:4096 -nodes -days 30 -subj "/CN=$IP" \
            -addext "subjectAltName=IP:$IP" -keyout certs/registry.key -out certs/registry.crt
        read -rsp 'registry parool: ' P; echo
        docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn labseis "$P" > auth/htpasswd; unset P
        ```

    - `registry/compose.yaml`: `registry:2`, port 5000, nimega volume `/var/lib/registry`, `restart: unless-stopped`, `/certs` ja `/auth` kirjutuskaitstud mount'iga ning muutujad:

        ```text
        REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt
        REGISTRY_HTTP_TLS_KEY=/certs/registry.key
        REGISTRY_AUTH=htpasswd
        REGISTRY_AUTH_HTPASSWD_REALM=labseis        # vabalt valitud nimi
        REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd
        REGISTRY_STORAGE_DELETE_ENABLED=true
        ```

    - Docker usaldab CA-d `certs.d` kaudu, `insecure-registries` jääb tühjaks; logi sisse enne ja pärast CA paigaldust ja lükka web-image sinna:

        ```bash
        docker login "$IP:5000" -u labseis
        sudo install -D -m 644 certs/registry.crt "/etc/docker/certs.d/$IP:5000/ca.crt"
        docker login "$IP:5000" -u labseis
        # $W ja $TAG on samad mis Harbori push'il
        docker tag "$W:$TAG" "$IP:5000/labseis/labori-seis-web:$TAG" && docker push "$IP:5000/labseis/labori-seis-web:$TAG"
        ```

    - teine tag `vana` (teine nginx'i versioon) kustutatakse API kaudu (`DELETE /v2/<repo>/manifests/<digest>`) koos lapsmanifestidega; enne kontrolli, et ükski teine tag ei viita samale digestile:

        ```bash
        sed 's/nginx:1.30-alpine/nginx:1.29-alpine/' ../web/Dockerfile \
            | docker build -t "$IP:5000/labseis/labori-seis-web:vana" -f - ../web
        docker push "$IP:5000/labseis/labori-seis-web:vana"
        docker compose exec registry du -sm /var/lib/registry
        ```

    - garbage collection'i ajal on registry read-only režiimis (`REGISTRY_STORAGE_MAINTENANCE_READONLY`), pärast tavarežiimis;

    **Kontroll:**

    ```bash
    openssl s_client -connect "$IP:5000" </dev/null 2>/dev/null | openssl x509 -noout -ext subjectAltName
    curl -s -o /dev/null -w '%{http_code}\n' --cacert certs/registry.crt "https://$IP:5000/v2/"
    docker info -f '{{json .RegistryConfig.InsecureRegistryCIDRs}}'
    git check-ignore registry/certs/registry.key registry/auth/htpasswd
    curl -s --cacert certs/registry.crt -u labseis "https://$IP:5000/v2/_catalog"; echo
    curl -s --cacert certs/registry.crt -u labseis "https://$IP:5000/v2/labseis/labori-seis-web/tags/list"; echo
    docker image rm "$IP:5000/labseis/labori-seis-web:$TAG" && docker pull "$IP:5000/labseis/labori-seis-web:$TAG"
    docker compose exec registry registry garbage-collect --dry-run /etc/docker/registry/config.yml | tail -2
    docker compose exec registry du -sm /var/lib/registry; docker pull "$IP:5000/labseis/labori-seis-web:vana"
    ```

    **Valmis, kui:**

    - esimene `login` andis `x509` vea, teine õnnestus; SAN-is on sinu IP, `/v2/` annab 401, `InsecureRegistryCIDRs` on ainult loopback;
    - `git check-ignore` leiab mõlemad failid, `garbage-collect --dry-run` töötab vigadeta;
    - kataloogis on ainult `$TAG`, see tõmmatakse sinu registry'st, `vana` annab `manifest unknown`;
    - read-only režiimis õnnestus pull, aga push andis vea;
    - `du -sm /var/lib/registry` on väiksem kui pärast `vana` push'i.

    ??? tip "Lahenduse suund"
        API kustutab manifesti ainult digesti järgi. Digesti saad `HEAD /v2/<repo>/manifests/<tag>` vastuse päisest `Docker-Content-Digest`, kui `Accept` päistes on kõik neli manifestitüüpi (OCI index ja manifest, Docker manifest list ja v2). Ilma nendeta võib registry anda vea või teise digesti. Docker 29 BuildKit lükkab OCI index'i, milles on image'i manifest ja attestation'i manifest. Index'i kustutamisel jäävad lapsmanifestid repositooriumisse alles ja nende kihid jäävad garbage collection'il alles, seega loe index'ist `.manifests[].digest` ja kustuta need enne. Digesti järgi kustutamine eemaldab kõik tag'id, mis sellele digestile viitavad: võrdle enne kõigi `tags/list` tag'ide digeste. Read-only režiim on konfiguratsiooni võti `storage.maintenance.readonly`. Keskkonnamuutuja väärtus parsitakse YAML-ina (`'{"enabled": true}'`) ja seda on mugav lisada eraldi override-failiga (`compose.maint.yaml`). Režiimi vahetus loob konteineri uuesti, seega on paar sekundit katkestust, aga mitte kogu GC aja. Siis käivita `registry garbage-collect /etc/docker/registry/config.yml` ja mine tagasi tavarežiimi. Tüüpiline lõks: `--delete-untagged` võib `registry:2` puhul kustutada ka teiste index'ite lapsmanifestid, sest need ei ole otse tag'itud, ja pärast seda ei saa ka `$TAG`-i tõmmata. Paroolile sobib `curl --netrc-file`, mitte `-u kasutaja:parool` argv-s. Täislahendus on õpetajal.

        **Miks nii.** Iga nõue on üks omadus, mis eristab tööks sobivat registry't demost: püsivad andmed, krüpteeritud ühendus, autentimine, kustutamise võimalus, usaldus ilma kontrolli välja lülitamata ja hooldus, mis pull'e ei katkesta.

        Registry on HTTP API. `docker push` küsib iga kihi kohta digesti järgi, kas see on olemas, saadab ainult puuduvad ja lõpuks manifesti, mis seob tag'i kihtidega. Seepärast nägid Harbori push'il `Layer already exists`. Kettal on volume'is `docker/registry/v2/blobs` kaust, kus iga kiht on üks fail oma räsi nime all, ja `repositories` kaust, kus tag'id viitavad manifestidele. Tag'i kustutamine eemaldab ainult viite. Ruumi vabastab `garbage-collect`, ja seda käivitatakse siis, kui keegi parasjagu image'eid ei lükka, sest samaaegne push võib jääda poolikuks.

        `insecure-registries` lülitab selle registry jaoks välja sertifikaadi kontrolli ja lubab ka tavalise HTTP. `docker login` saadab parooli Basic-autentimisega ja Docker hoiab seda `~/.docker/config.json`-is või credential helper'is. Ilma kontrollita saab vahel olev masin parooli kätte ja võib sama tag'i all anda teise image'i, ning tag'iga tõmbav masin seda ei märka. Seade kehtib kogu daemonile ja kõigile selle hosti kasutajatele. Loopback (`127.0.0.0/8`) on vaikimisi ebaturvaliste registry'te nimekirjas, seepärast töötab `localhost:5000` ka ilma TLS-ita ja seepärast testid siin IP-aadressiga. Õige lahendus on alati CA fail `certs.d` all: kontroll jääb sisse ja usaldus kehtib ainult sellele registry'le.

        Harbori projekt `dockerhub` teeb sama, mida `registry:2` teeb teises režiimis: `REGISTRY_PROXY_REMOTEURL` teeb registry'st pull-through cache'i, mis tõmbab puuduva image'i Docker Hubist ja hoiab seda alles. Uuem põhiversioon on `registry:3`, mille seadistus on suures osas sama. Tootmises on lihtsal registry'l üks puudus: ühe parooliga saab igaüks push'ida igasse repositooriumi. Harbor, Gitea ja pilveregistrid lisavad kasutajad, õigused repositooriumi kaupa, säilituspoliitika ja skannimise, ja seepärast kasutab kursus Harborit.

??? example "Lisaprojekt · rootless Docker"
    Turvanõue „konteinerid ilma root-daemonita“ ei tähenda alati Podmani: osa tiime vajab Compose'i ja Dockeri socket'it muutmata. Käivitad control'is sama db-image'i tavalise ja rootless Dockeriga kõrvuti ning võrdled tulemust sellega, mida Podman mc01-s ja db01-s näitas. `labori-seis-db` image on Harboris, control'is on paketid `uidmap` ja `docker-ce-rootless-extras` ([rootless Docker](https://docs.docker.com/engine/security/rootless/)) ja `grep "$USER" /etc/subuid` annab rea.

    - rootless Docker on control'is teine kontekst `rootless`, rootful Docker töötab edasi:

        ```bash
        dockerd-rootless-setuptool.sh install
        docker context ls
        docker --context rootless info --format '{{.SecurityOptions}}'
        ```

    - sama image töötab kaks korda, `docker run` (rootful) ja `docker --context rootless run`, mõlemal nimega volume'iga;
    - rootless daemon ja selle konteiner käivituvad pärast control'i taaskäivitust ilma sisselogimiseta.

    **Kontroll:**

    ```bash
    docker context ls; docker ps --format '{{.Names}} {{.Status}}'
    docker --context rootless ps --format '{{.Names}} {{.Status}}'
    ps -o user,pid,cmd -C mariadbd
    cat /proc/"$(pgrep -u "$USER" -n mariadbd)"/uid_map
    systemctl --user is-enabled docker; loginctl show-user "$USER" -p Linger
    ```

    **Valmis, kui:**

    - `docker context ls` näitab mõlemat konteksti ja mõlema variandi `SHOW TABLES` annab neli tabelit;
    - rootless `mariadbd` protsess hostis ei ole root ega UID 999;
    - pärast reboot'i enne sisselogimist vastab rootless konteineri port ja `Linger` on `yes`.

    ??? tip "Lahenduse suund"
        Rootless daemon on kasutaja teenus (`systemctl --user status docker`) oma socket'iga `/run/user/<UID>/docker.sock`, ja tal on eraldi image'id ning volume'id kaustas `~/.local/share/docker`. Seepärast tõmbab ta db-image'i uuesti, ja kursuse CA peab olema ka kasutaja kaustas `~/.config/docker/certs.d/<registry>/`. UID-de vastavuse näed `/proc/<pid>/uid_map`-ist: konteineri 0 on sinu UID, 1… on `/etc/subuid` vahemiku algus. Port 80 ebaõnnestub `net.ipv4.ip_unprivileged_port_start` tõttu, vali kõrgem port, mitte kogu hosti sysctl'i muudatus. `--memory` vajab, et systemd oleks kasutaja sessioonile `memory` kontrolleri delegeerinud (`cgroup.controllers` kasutaja `user@<UID>.service` all), muidu ignoreerib daemon piirangut hoiatusega. Et teenus pärast taaskäivitust ise käivituks, vajad kaht asja: linger ja `systemctl --user enable docker`; konteineri enda käivitab uuesti `restart: unless-stopped`. Tüüpiline lõks: `docker` ilma `--context`-ita räägib endiselt rootful daemoniga, nii et "töötav" konteiner võib olla vales daemonis. Täislahendus on õpetajal.

        **Miks nii.** Rootless Docker kasutab sama user namespace'i mudelit mis Podman: konteineri root on hostis sinu kasutaja ja konteinerist välja pääsenud ründaja saab ainult sinu õigused. Pordipiir ja kasutajaruumi võrk (`slirp4netns` või `pasta`) on samad. Vahe on elutsüklis: Dockeril on endiselt daemon, nüüd kasutaja kohta, ja selle restart peatab tema konteinerid. Compose, Dockeri socket ja kõik tööriistad töötavad muutmata, mis on rootless Dockeri peamine põhjus Podmani asemel. Serveris, kus töötab üks teenus ja standard on AlmaLinux/RHEL, on Quadlet lihtsam; arendusmasinas ja CI agendil, kus tööriistad eeldavad Dockeri API-t, on rootless Docker väiksem muudatus.

??? example "15 · vorgukogu konteineris"

    Võrguinseneri osa jätkab tööriistaga `vorgukogu` (1. kohtumise lisaülesanne 21). Seni töötas see sinu venv'is: Pythoni versioon, Netmiko ja Paramiko on just selles kaustas ja teises masinas teised. Image paneb Pythoni ja paketid ühte tervikusse, mida 6. kohtumisel Jenkins ja 7. kohtumisel Kubernetes käivitavad muutmata. Õpetaja on loonud `rtr01` ja `rtr02` (Ubuntu 24.04 + FRR 10.x, kasutaja `kasutaja` sinu võtmega), `vorgukogu/` kaustas on 1. kohtumise failid.

    **Esita:** `vorgukogu/Dockerfile`, `vorgukogu/.dockerignore`

    Öine kogumine peab töötama ühtemoodi igas masinas, kus see käivitub, ja võti ei tohi image'isse jõuda: image läheb registry'sse ja seda näevad kõik, kel on lugemisõigus. Tee `vorgukogu/Dockerfile`, mille konteiner kogub sama väljundi kui 1. kohtumise venv'is töötav skript. Docker töötab control'is nagu põhilaboris; kustutada võib ainult image'id `vorgukogu:*` (`docker image rm vorgukogu:1`).

    - baas `python:3.12-slim`, sõltuvused `requirements.txt`-ist enne koodi kopeerimist (koodi muutus ei ehita pip-kihti uuesti);
    - image'is on `vorgukogu.py`, `inventory.yaml` ja `known_hosts`, mitte `.venv/`, `out/`, `*.env` ega võti (`.dockerignore`);
    - konteiner töötab mitte-root kasutajana; `ENTRYPOINT` on skript, `CMD` vaikeargumendid (`--inventory /app/inventory.yaml --out /app/out`);
    - `VORK_USER` ja `VORK_KEY_FILE` tulevad `--env-file vorgukogu.env`-ist (`.gitignore`-is), võti ja `out/` mount'iga;
    - konteineri väljumiskood on sama mis skriptil (0 / 2 / 1).

    **Kontroll:**

    ```bash
    cd ~/labori-seis/vorgukogu && docker build -t vorgukogu:1 .
    mkdir -p out && docker run --rm --user "$(id -u):$(id -g)" --env-file vorgukogu.env \
      -v ~/.ssh/id_ed25519_labseis:/run/secrets/rtr_key:ro -v "$PWD/out:/app/out" vorgukogu:1; echo "kood $?"
    stat -c '%U %n' out/rtr01/*
    docker run --rm --entrypoint id vorgukogu:1
    docker run --rm --entrypoint sh vorgukogu:1 -c 'ls -a /app; ls /run/secrets 2>&1'
    # proov.yaml: 1. kohtumise kontrolli fail, lisatud rtr09 aadressil 192.0.2.1
    docker run --rm --user "$(id -u):$(id -g)" --env-file vorgukogu.env \
      -v ~/.ssh/id_ed25519_labseis:/run/secrets/rtr_key:ro -v "$PWD/out:/app/out" \
      -v "$PWD/proov.yaml:/app/proov.yaml:ro" vorgukogu:1 --inventory /app/proov.yaml --out /app/out; echo "kood $?"
    ```

    **Valmis, kui:**

    - esimene `docker run` annab `OK` mõlemale ruuterile ja koodi `0`, `out/` failide omanik on sinu kasutaja;
    - `id` näitab `uid=10001`;
    - `/app`-is on ainult kolm faili ja `requirements.txt`, `/run/secrets` puudub ilma mount'ita;
    - `proov.yaml`-iga on kood `2`.

    ??? success "Lahendus"
        ```dockerfile
        # syntax=docker/dockerfile:1
        # vorgukogu konteineris: sama Python ja samad paketid igal käivitajal (control, Jenkins, Kubernetes).
        FROM python:3.12-slim

        ENV PYTHONDONTWRITEBYTECODE=1 \
            PYTHONUNBUFFERED=1 \
            PIP_NO_CACHE_DIR=1 \
            PIP_DISABLE_PIP_VERSION_CHECK=1 \
            HOME=/tmp

        WORKDIR /app
        # sõltuvused enne koodi: koodi muutus ei ehita pip-kihti uuesti
        COPY requirements.txt .
        RUN pip install -r requirements.txt

        COPY vorgukogu.py inventory.yaml known_hosts ./
        RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin vorgu
        USER 10001

        ENTRYPOINT ["python", "/app/vorgukogu.py"]
        CMD ["--inventory", "/app/inventory.yaml", "--out", "/app/out"]
        ```

        ```text
        .venv/
        out/
        out-ansible/
        build/
        tests/
        ansible/
        *.env
        __pycache__/
        .git
        ```

        ```bash
        # Kopeeri: cp vorgukogu.env.example vorgukogu.env (vorgukogu.env on .gitignore's)
        VORK_USER=kasutaja
        # võti tuleb konteinerisse mount'iga, mitte image'isse
        VORK_KEY_FILE=/run/secrets/rtr_key
        ```

        Kontroll: ülesande Kontrolli käsud. Kui konteiner annab `FAIL … not found in known_hosts`, ehitati image enne `known_hosts` faili tegemist: ehita uuesti.

        **Miks nii.** `--user "$(id -u):$(id -g)"` käivitab konteineri sinu UID-iga: mount'itud võti on `0600` ja loetav ainult sinule ning `out/` failid jäävad sinu omaks. Image'i oma kasutaja 10001 on vaikimisi kasutaja juhuks, kui keegi käivitab ilma `--user`-ita: siis on protsess ikkagi mitte-root. `HOME=/tmp`, sest suvalise UID-iga protsessil pole kodukausta. Võti on mount, mitte `COPY` ega `ENV`: image'i kihid ja `docker inspect` näitavad kõike, mis ehituse ajal sisse läks. Kui annad konteinerile argumente, asendavad need kogu `CMD`-i, seepärast on proovis ka `--out /app/out`.

??? question "Arutelu"

    1. `docker exec w id` ütleb `uid=0`. Kas see on sama root mis hostis? Mida see tähendab, kui konteineris on turvaauk?
    2. Mälupiiri katses võttis `tail /dev/zero` 64 MB mälu ja tuum lõpetas protsessi. Mis oleks juhtunud ilma `--memory-swap`-ita ja kumb on tootmises hullem: OOM-kill või teenus, mis swap'i tõttu vaevu vastab?
    3. Saladus on failis `/run/secrets/DB_PASSWORD`. Kes control'is saab seda ikkagi lugeda ja kas see on parem kui `.env`?
    4. Trivy ütles täna "0 CRITICAL". Kas see image on kuu aja pärast ka puhas, kui sa midagi ei muuda, ja kuidas SBOM sellele küsimusele vastata aitab?
    5. Registry lehel viitasid image'ile digestiga. Mis juhtub sinu stackiga, kui keegi lükkab registry's tag'i `k03` alla teise image'i, ja kumb viis seda märkab: tag või digest?
