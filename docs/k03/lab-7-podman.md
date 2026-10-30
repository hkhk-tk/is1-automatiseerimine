---
tags:
  - Podman
  - Quadlet
  - SELinux
  - systemd
---

# 7. Sama teenus Podmaniga

AlmaLinux ja RHEL serveris Dockerit vaikimisi pole: `dnf install docker` paigaldab `podman-docker`-i ja turvanõue keelab tihti root-daemoni, mille socket'i omanik on hostis sisuliselt root. Kui tiim tahab sinna konteinerit, pead oskama teenust käivitada ilma daemonita, systemd all, SELinuxi sees. Viid Labori seisu mc01 ja db01 teenused nende samade AlmaLinuxi hostide peal rootless Podmani konteineritesse, image'id tulevad kooli registry'st ja app01 jõuab neisse ilma restardita. Kõik käsud on kasutajana `kasutaja`, `sudo` ainult seal, kus see on kirjas.

**Kui teed seda tööl iga päev:** sinu serverites käivad konteinerid Quadleti unit'itena ja `loginctl show-user <kasutaja> -p Linger` annab `Linger=yes`. Kui see on sul juba korras, kirjuta mc01 Quadlet etapi „[Quadlet: konteiner systemd teenusena](#quadlet-konteiner-systemd-teenusena)“ nõuete järgi ise ja mine otse etappi „[db01 SELinuxiga](#db01-selinuxiga)“.

Tabel L3.6 seob Podmani mõisted sellega, mida tegid Dockeriga control node'is.

| Docker control node'is | Podman mc01-s ja db01-s |
|---|---|
| `dockerd` root'ina, socket `/var/run/docker.sock` | daemonit pole, iga konteineri juures `conmon`, kasutaja `kasutaja` |
| `restart: unless-stopped` | systemd unit `Restart=on-failure`, `[Install] WantedBy=default.target` |
| `compose.yaml` teenus | `~/.config/containers/systemd/<nimi>.container` |
| nimega volume | `<nimi>.volume` või `Volume=nimi:/tee` |
| `secrets:` failist | `podman secret` + `Secret=` |
| `deploy.resources.limits.memory` | `MemoryMax=` unit'i cgroup'is |
| `/etc/docker/certs.d/` | `/etc/containers/certs.d/` |

*Tabel L3.6. Docker ja Podman sama töö juures.*

## Podman hostis

Enne muudatust teed mõlemast VM-ist snapshot'i ja vaatad, millise Podmaniga sul tegu on. Quadleti võtmed `Notify=healthy` ja `HealthOnFailure=` vajavad Podmani 5. põhiversiooni; vanem versioon annab `daemon-reload`-il vea, mis ei ütle, et põhjus on versioonis.

1. Proxmoxis tee mc01-st ja db01-st snapshot `enne-podman` ilma RAM-ita.
2. Kontrolli mõlemas hostis versiooni, rootless-režiimi, cgroup'i versiooni, võrgu backend'i ja `subuid` vahemikku. Kui `podman` puudub, paigalda see AppStreamist (`sudo dnf install -y podman`).

    ```bash
    for h in mc01 db01; do
        ssh "$h" 'hostname; podman --version
            podman info --format "rootless={{.Host.Security.Rootless}} cgroup={{.Host.CgroupsVersion}} net={{.Host.NetworkBackend}} store={{.Store.GraphDriverName}}"
            grep "^$USER:" /etc/subuid; sysctl -n net.ipv4.ip_unprivileged_port_start; getenforce'
    done
    ```

Rootless tähendab, et kõik konteinerid töötavad kasutaja `kasutaja` user namespace'is: konteineri UID 0 on hostis `kasutaja`, ülejäänud UID-d tulevad `/etc/subuid` vahemikust. 11211 ja 3306 on üle `ip_unprivileged_port_start` piiri, nii et kumbki port ei vaja sysctl'i muutmist.

✅ **Edasi saad minna, kui** mõlemal VM-il on snapshot `enne-podman`, Podman on 5.x, väljund ütleb `rootless=true cgroup=v2 net=netavark store=overlay`, `subuid` rida on olemas ja `getenforce` annab `Enforcing`. Kirjuta TOEND.md-sse jaotis `## Podman` ja sinna `podman info` rida.

## Image registry'st

AlmaLinuxi host tõmbab samad image'id samast registry'st kui control node, aga Podmani seadistus on teises kohas. Docker Hubi image'id tulevad kooli peegli kaudu, Gitea image'id kooli CA-ga ja ainult lugemisõigusega tokeniga: server ei vaja õigust image'eid lükata ega kustutada.

1. Loo Gitea's teine token õigusega `read:package` (nimi `podman-read`).
2. Seadista mõlemas hostis peegel ja Gitea CA nõuete järgi:
    - peegel on drop-in failis `/etc/containers/registries.conf.d/50-labseis-mirror.conf`: `[[registry]]` `location = "docker.io"` ja selle all `[[registry.mirror]]` kooli peegli aadressiga (sama mis `daemon.json`-is);
    - kui `podman pull` annab `x509`, läheb kooli CA faili `/etc/containers/certs.d/gitea.lab.hkhk.ee/ca.crt`, mitte `--tls-verify=false`;
    - login salvestub faili, mis säilib ka pärast taaskäivitust (`--authfile ~/.config/containers/auth.json`).
3. Tõmba mc01-s `docker.io/library/memcached:1.6-alpine`, db01-s oma `labori-seis-db` image sama tag'iga, mis registry lehel, ja võrdle digesti control node'i omaga.

    ```bash
    R=gitea.lab.hkhk.ee/<sinu-github>; TAG=<registry lehe TAG>
    docker image inspect -f '{{index .RepoDigests 0}}' "$R/labori-seis-db:$TAG"
    ssh -t db01 "podman login --authfile ~/.config/containers/auth.json gitea.lab.hkhk.ee -u <sinu-github> &&
        podman pull -q $R/labori-seis-db:$TAG && podman image inspect --format '{{json .RepoDigests}}' $R/labori-seis-db:$TAG"
    ssh mc01 'podman pull docker.io/library/memcached:1.6-alpine 2>&1 | grep -iE "trying|copying blob" | head -3'
    ```

Sama digest kahes eri tööriistas tõestab, et OCI image ei sõltu runtime'ist: kihid ja manifest on samad baidid. Vaikimisi kirjutab `podman login` faili `$XDG_RUNTIME_DIR/containers/auth.json`, mis on tmpfs'is ja kaob reboot'iga. Kasutaja teenus, mis peab image'i hiljem uuesti tõmbama, ei leiaks siis volitusi.

✅ **Edasi saad minna, kui** db01-s on `labori-seis-db` sama tag'iga, Dockeri `RepoDigests` väärtus on Podmani `RepoDigests` nimekirjas, mc01 tõmbas memcached'i peegli kaudu ja `~/.config/containers/auth.json` on db01-s olemas. Kirjuta TOEND.md-sse kaks digesti kõrvuti.

## mc01: teenus konteineriks

Alustad lihtsamast teenusest, mille olek ei pea alles jääma. Peatad native memcached'i, käivitad sama pordiga konteineri ja vaatad hostist, kes kellele vanem on. Kontroll tuleb sealt, kust teenust kasutatakse: app01 `/health` web01 kaudu.

```bash
ssh mc01 'sudo systemctl disable --now memcached
    podman run -d --name mc-proov -p 11211:11211 docker.io/library/memcached:1.6-alpine
    ps -o pid,ppid,user,cmd -C conmon,memcached,pasta'
sleep 15; curl -s http://web01/health; echo
ssh mc01 'podman rm -f mc-proov'
```

`ps` näitas kolme protsessi. `memcached` töötab UID-ga `subuid` vahemikust, mitte root'ina ega `kasutaja`-na. Tema vanem on `conmon`, mis hoiab konteineri stdio't ja väljumiskoodi. Porti hoiab `pasta`, mis kuulab hostis kasutaja õigustega ja suunab ühendused konteineri võrgu namespace'i. `podman` protsessi ennast enam pole: käsk lõpetas töö pärast käivitamist ja ühtegi daemonit, mille restart konteineri peataks, ei ole. Seepärast ei käivita seda konteinerit pärast taaskäivitust ka keegi uuesti.

✅ **Edasi saad minna, kui** `/health` näitas `"cache":"UP"` ilma app01 restardita, `ps` näitab `memcached`-i numbrilise UID-ga ja `conmon`-i tema vanemana ning `mc-proov` on kustutatud. Kirjuta `/health` ja `ps` väljund TOEND.md-sse.

## Quadlet: konteiner systemd teenusena

Quadlet on systemd generaator: `systemctl --user daemon-reload` loeb kaustast `~/.config/containers/systemd/` faile `.container`, `.volume` ja `.network` ning genereerib neist tavalised `.service` unit'id. Sa kirjeldad konteinerit, systemd hoiab teda käigus.

1. Kirjuta mc01-s `~/.config/containers/systemd/labseis-mc.container` nende nõuete järgi ([võtmete viide](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)):
    - image täisnimega ja versiooni tag'iga, konteineri nimi `labseis-mc`, port 11211;
    - healthcheck sama käsuga mis Compose'i mc01-l, `unhealthy` olek lõpetab konteineri ja `systemctl --user start` ootab `healthy` olekut;
    - `[Service]`: taaskäivitus vea korral ja mälupiir 128 MB;
    - `[Install]`: teenus käivitub koos kasutaja systemd'ga.
2. Vaata enne käivitamist, mis unit'i generaator teeb, ja käivita teenus.

    ```bash
    ssh mc01 '/usr/libexec/podman/quadlet -dryrun -user | grep -E "^ExecStart|^MemoryMax|^Restart"
        systemctl --user daemon-reload && systemctl --user start labseis-mc
        systemctl --user status labseis-mc --no-pager | head -5; podman healthcheck run labseis-mc && echo healthy'
    ```

3. Luba kasutaja teenustel käivituda ilma sisselogimiseta ja tee reboot'i test. Kontroll tuleb väljast enne SSH-sisselogimist, sest sisselogimine ise käivitab kasutaja systemd ja peidaks vea.

    ```bash
    ssh mc01 'sudo loginctl enable-linger kasutaja && sudo systemctl reboot'; sleep 90
    curl -s http://web01/health; echo
    ssh mc01 'systemctl --user is-active labseis-mc; loginctl show-user kasutaja -p Linger'
    ```

`systemctl --user enable labseis-mc` annab vea, sest genereeritud unit'i ei saa lubada: käivituse reboot'il annab `[Install]` jaotis Quadleti failis, mille generaator muudab `default.target.wants` lingiks. `-dryrun` väljund näitab, et `MemoryMax` ja `Restart` on tavalised systemd võtmed ja `podman run` on ainult `ExecStart` rida.

✅ **Edasi saad minna, kui** `-dryrun` näitas `ExecStart=/usr/bin/podman run … --name labseis-mc …`, teenus on `active` ja `healthy`, pärast reboot'i andis `/health` enne sisselogimist `"cache":"UP"` ja `Linger=yes`. Kirjuta TOEND.md-sse `is-active` väljund pärast reboot'i ja üks lause, miks `enable` ei tööta.

## db01 SELinuxiga

Muudatus käib tootmise reeglitega: andmebaas kolib native teenusest konteinerisse hooldusaknas, ükski tulemus ei kao, parool ei satu üheski kohas keskkonnamuutujasse ega käsureale ja SELinux jääb `Enforcing`. Andmed tulevad native MariaDB dump'ist, mille konteiner impordib esimesel käivitusel.

1. Ava hooldusaken: peata app01 Tomcat, et dump'i ja vahetuse vahel ei tuleks kirjeid juurde, ning salvesta algseis.

    ```bash
    ssh app01 sudo systemctl stop tomcat
    ssh db01 "sudo mariadb -N -e 'SELECT COUNT(*) FROM labseis.result'"
    ssh db01 'mkdir -p ~/labseis && sudo mariadb-dump --single-transaction labseis > ~/labseis/03-dump.sql &&
        chmod 644 ~/labseis/03-dump.sql && ls -Z ~/labseis/03-dump.sql'
    ```

2. Loo kaks `podman secret`-it: `labseis-db-pass` 2. kohtumise Vaulti väärtusega `vault_db_password` (app01 kasutab sama parooli) ja `labseis-db-root` uue juhusliku väärtusega. Väärtus läheb `podman secret create <nimi> -` stdin'i, mitte käsurea argumenti, ja shelli muutuja kustutatakse kohe pärast.
3. Kirjuta db01-s `labseis-db.volume` ja `labseis-db.container` nende nõuete järgi:
    - image sinu `labori-seis-db` tag'iga, konteineri nimi `labseis-db`, port 3306, andmed `.volume` failist `/var/lib/mysql` alla;
    - `~/labseis/03-dump.sql` bind mount'ina `/docker-entrypoint-initdb.d/03-dump.sql` kirjutuskaitstud kujul, **esimesel katsel ilma SELinuxi sildita**;
    - paroolid `Secret=` ridadelt failidena ja image'i `MARIADB_*_FILE` muutujatega, andmebaas ja kasutaja `labseis`;
    - healthcheck sama käsuga mis Compose'i db01-l, `start` ootab `healthy` olekut, käivitusaega vähemalt 300 s;
    - mälupiir 512 MB, taaskäivitus vea korral, `[Install]` nagu mc01-l.
4. Peata native MariaDB, käivita konteiner ja leia, miks esimene käivitus ebaõnnestus. `systemctl --user status` võib minuti pärast näidata `active`: `Restart=on-failure` tegi teise katse. Vaata esimest käivitust journal'ist.

    ```bash
    ssh db01 'sudo systemctl disable --now mariadb
        systemctl --user daemon-reload; systemctl --user start labseis-db
        journalctl --user -u labseis-db --no-pager | grep -m3 -iE "denied|initdb|error"
        sudo ausearch -m avc -ts recent | grep -m2 03-dump'
    ```

5. Paranda bind mount'i rida. Enne uut starti mõtle, mis olekus on volume pärast poolikut initsialiseerimist ja pärast teist katset, ning tee nii, et import käivitub uuesti. Kontrolli ridade arvu, silti ja paroolide asukohta, siis sulge hooldusaken.

    ```bash
    ssh db01 'ls -Z ~/labseis/03-dump.sql
        podman exec labseis-db sh -c "MYSQL_PWD=\$(cat /run/secrets/labseis-db-pass) mariadb -ulabseis -N -e \"SELECT COUNT(*) FROM labseis.result\""
        podman inspect labseis-db --format "{{.Config.Env}}" | grep -oiE "[a-z_]*pass[a-z_]*=[^ ]*"
        systemctl --user cat labseis-db | grep -iE "secret|pass"'
    ssh app01 sudo systemctl start tomcat; sleep 30; curl -s http://web01/health; echo
    ```

Ilma sildita on dump'il `user_home_t` ja konteineri protsess töötab domeenis `container_t`: poliitika keelab lugemise, kuigi failiõigused (`644`) lubavad. Ubuntu control node'il Docker seda ei näita, sest seal SELinuxit pole. `:Z` annab failile sildi `container_file_t` koos selle konteineri MCS kategooriatega, nii et teine konteiner sama faili lugeda ei saa; `:z` jagatud sildiga lubaks. Teine katse oli `active`, sest MariaDB entrypoint initsialiseerib ainult tühja andmekataloogi: esimene katse jõudis luua kataloogi, skeemi ja algandmed, enne kui dump'i lugemine ebaõnnestus. Teenus oli terve, andmed mitte, ja seda näitas ainult ridade arv.

✅ **Edasi saad minna, kui** journal'is ja `ausearch` väljundis on `03-dump.sql` keeld (`denied { read }`, `scontext=…container_t`), pärast parandust on failil `container_file_t`, ridade arv konteineris võrdub algseisuga, `podman inspect` ei näita ühtegi parooli väärtust, `systemctl --user cat` näitab ainult `Secret=` ja `_FILE` ridu, `getenforce` on endiselt `Enforcing` ja `/health` annab `"db":"UP"`. Kirjuta TOEND.md-sse AVC rida, parandus ja kaks ridade arvu.

## Piirangud cgroup'is

Rootless-režiimis kehtib piirang ainult siis, kui systemd on kasutaja teenusele vastava cgroup'i kontrolleri delegeerinud. Vaatad, kus `MemoryMax` tegelikult kehtib ja milliseid piiranguid sa sellel hostil üldse seada saad.

```bash
ssh mc01 'cg=$(systemctl --user show -p ControlGroup --value labseis-mc)
    systemd-cgls --no-pager --user-unit labseis-mc | head -6
    cat "/sys/fs/cgroup$cg/memory.max"
    cat "/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers"
    podman run --rm --memory 64m docker.io/library/memcached:1.6-alpine cat /sys/fs/cgroup/memory.max
    podman run --rm --cpus 0.5 docker.io/library/memcached:1.6-alpine true; echo "cpus kood $?"'
```

`systemd-cgls` näitas, et `conmon` ja konteineri protsess on mõlemad unit'i `labseis-mc.service` cgroup'is: Quadlet käivitab konteineri `--cgroups=split`-iga, nii et unit'i `MemoryMax` piirab kogu teenust koos `conmon`-iga. `--memory` ja `--cpus` töötavad ainult siis, kui `cgroup.controllers` loetelus on `memory` ja `cpu`.

✅ **Edasi saad minna, kui** `memory.max` on `134217728`, `--memory 64m` konteiner näitas `67108864` ja tead `--cpus` katse tulemust. Kirjuta TOEND.md-sse `memory.max` väärtus, `cgroup.controllers` rida ja üks lause: mis juhtus `--cpus`-iga ja miks.

## Docker API ja Kubernetese YAML

Osa tööriistu (Trivy, Testcontainers, CI agendid) eeldab Dockeri socket'it. Podman pakub sama REST API-t kasutaja socket'il ilma root-daemonita. Proovid, kui kaugele see ühilduvus ulatub, ja teed töötavast konteinerist Kubernetese manifesti.

1. Lülita mc01-s sisse API socket ja küsi seda otse, siis control node'i `docker` CLI-ga üle SSH tunneli.

    ```bash
    ssh mc01 'systemctl --user enable --now podman.socket
        curl -s --unix-socket "$XDG_RUNTIME_DIR/podman/podman.sock" http://d/version | python3 -m json.tool | grep -E "\"(Version|ApiVersion|Name)\"" | head -5'
    U=$(ssh mc01 id -u); rm -f /tmp/mc01-podman.sock
    ssh -fNL /tmp/mc01-podman.sock:/run/user/$U/podman/podman.sock mc01
    DOCKER_HOST=unix:///tmp/mc01-podman.sock docker ps
    DOCKER_HOST=unix:///tmp/mc01-podman.sock docker inspect -f '{{.State.Health.Status}}' labseis-mc
    ```

2. Tee töötavast konteinerist Kubernetese YAML ja käivita see teise pordiga pod'ina.

    ```bash
    ssh mc01 'podman kube generate labseis-mc > ~/labseis-mc-kube.yaml && grep -E "kind|image|hostPort" ~/labseis-mc-kube.yaml
        sed "s/hostPort: 11211/hostPort: 11212/" ~/labseis-mc-kube.yaml > ~/labseis-mc-11212.yaml
        podman kube play ~/labseis-mc-11212.yaml && sleep 3
        exec 3<>/dev/tcp/127.0.0.1/11212; printf "version\r\n" >&3; read -r -t 3 l <&3; echo "$l"
        podman kube down ~/labseis-mc-11212.yaml'
    ```

`docker` CLI ei tea, et teisel pool on Podman: ta räägib sama HTTP API-ga ja leppis kokku vanema API versiooni, mida server toetab. Mis ei tööta, on peaaegu alati Dockeri-spetsiifiline lisa (Swarm, BuildKit'i võtmed, plugin'id). `kube generate` andis `Pod` objekti, mille sees on sama image ja port; healthcheck ja `MemoryMax` sinna ei jõua, sest need on systemd poolel.

✅ **Edasi saad minna, kui** `/version` näitas Podmani komponenti ja API versiooni, tead, kas `docker ps` ja `docker inspect` töötasid tunneli kaudu, ning pod pordil 11212 vastas `VERSION 1.6…` ja on maha võetud. Kirjuta TOEND.md-sse kaks rida: mis töötas ja mis mitte.

## Tagasi algseisu ja commit

Quadleti failid lähevad Giti ja hostid lähevad tagasi native teenustele: 4. kohtumine ja Ansible'i rollid eeldavad, et db01-s ja mc01-s töötavad `mariadb` ja `memcached` systemd teenustena. Konteineri ajal lisatud tulemused jäävad volume'isse ja native baasi tagasi ei tule.

1. Kopeeri failid repo'sse ja käivita automaatse hindaja kontroll.

    ```bash
    cd "$(git rev-parse --show-toplevel)" && mkdir -p k03-docker/quadlet
    scp mc01:.config/containers/systemd/labseis-mc.container 'db01:.config/containers/systemd/labseis-db.*' k03-docker/quadlet/
    bash autograde/check.sh k03 quadlet
    ```

2. Vii hostid tagasi algseisu ühel kahest viisist: Proxmoxi snapshot'i `enne-podman` rollback või käsitsi (teenused peatatud, Quadleti failid kaustast `~/.config/containers/systemd/` välja, `daemon-reload`, `podman.socket` välja, native teenused `enable --now`). Siis tõesta, et algseis klapib.

    ```bash
    for h in mc01 db01; do ssh "$h" 'systemctl --user list-units "labseis-*" --no-legend; ss -tlnp | grep -E ":(3306|11211) "'; done
    cd k02-ansible && ansible-playbook site.yml --limit db,cache | tail -3; cd ..
    curl -s http://web01/health; echo
    ```

3. Commit.

    ```bash
    git add k03-docker/quadlet k03-docker/TOEND.md && git status --short
    git commit -m "K3.7 sama teenus Podmaniga (closes #N)" && git push
    ```

✅ **Edasi saad minna, kui** `check.sh k03 quadlet` annab `OK`, kummaski hostis pole `labseis-*` unit'eid, 3306 ja 11211 kuulavad native teenused, `ansible-playbook` andis `changed=0`, `/health` on `UP` ja commit on GitHubis.

📎 **Selle mooduli tõend:** commit `K3.7 …` kaustaga `k03-docker/quadlet/`; TOEND.md jaotises `## Podman` `podman info` rida, kaks digesti, `/health` ja `ps`, `is-active` pärast reboot'i ja `enable` lause, AVC rida koos parandusega ja kaks ridade arvu, `memory.max` ja `cgroup.controllers`, Docker API kaks rida.

## Miks see nii töötab

**Fork/exec, mitte klient-server.** `docker run` saadab päringu daemonile ja konteineri vanem on `containerd-shim`. `podman run` on tavaline programm, mis loob konteineri ise (`crun` kaudu), jätab selle juurde `conmon`-i ja lõpetab.

**Quadlet on generaator.** `daemon-reload` käivitab generaatori `/usr/lib/systemd/user-generators/podman-user-generator`, mis kirjutab `.service` failid kausta `$XDG_RUNTIME_DIR/systemd/generator/`. Need failid on ajutised ja tehakse iga `daemon-reload`-iga uuesti, seepärast muudad ainult `.container` faili. Varasem `podman generate systemd` on aegunud: see tegi staatilise unit'i, mis ei uuenenud koos konteineri seadistusega.

**Linger.** Kasutaja systemd (`user@<UID>.service`) käivitub tavaliselt esimese sisselogimisega ja lõpetab viimase väljalogimisega. `loginctl enable-linger` loob faili `/var/lib/systemd/linger/<kasutaja>`, ja siis käivitub kasutaja systemd boot'il ning `default.target` käivitab Quadleti teenused.

**SELinuxi sildid.** AlmaLinuxi poliitikas tohib `container_t` lugeda ja kirjutada ainult `container_file_t` silti. Podman paneb `:Z` sildi iga konteineri stardil uuesti, `:z` annab ühise sildi ilma MCS kategooriateta. Kodukausta või `/etc` alla ei panda `:Z`-ga laia kausta: silt muutub kogu puul ja hosti teised teenused võivad ligipääsu kaotada. Kui dump'i hiljem kustutad, eemalda ka `Volume=` rida, muidu ei käivitu konteiner, sest bind mount'i allikas puudub.

**Rootless võrk.** `pasta` tõlgib konteineri namespace'i võrgupaketid hosti tavalisteks socket'iteks kasutaja õigustega. Sissetulev ühendus läbib hosti `firewalld`-i nagu native teenuse puhul, nii et 2. kohtumisel avatud pordid kehtivad ka konteinerile. Rootful Dockeri NAT-reegleid, mis lähevad tulemüürist mööda, siin pole.

**Healthcheck Podmanis.** Podman käivitab healthcheck'i systemd taimeriga, mitte daemoni sees. `HealthOnFailure=kill` lõpetab `unhealthy` konteineri ja unit'i `Restart=` käivitab selle uuesti: see on käitumine, mida Docker Compose'il pole. `Notify=healthy` hoiab unit'i olekus `activating`, kuni healthcheck läbib, nii et teised unit'id saavad sellest `After=`-iga sõltuda.

**Kahe tööriista hind.** Podman sobib serverisse, kus töötab üks või paar teenust ja AlmaLinux/RHEL on standard: systemd, journald, SELinux ja auditilogi on samad mis teistel teenustel. Docker jääb arendusmasinasse, CI-sse ja sinna, kus tööriistad eeldavad Compose'i ja Dockeri socket'it. Kubernetes võtab mõlemast sama OCI image'i.

Kui jõudsid kiiremini: [Lisaülesanded → Lisaprojekt: rootless Docker](lisa.md#lisaprojekt-rootless-docker), käivitad sama db-image'i control node'is rootless Dockeriga ja võrdled, mida Docker ilma root-daemonita teisiti teeb.
