---
tags:
  - Monitooring
---

# Monitooringu ülesanded (Proxmox)

| Ülesanne | Seos | Tulemus |
|---|---|---|
| [1. kohtumine · Neli signaali ühe skriptiga](#1-kohtumine-neli-signaali-uhe-skriptiga) | [1. kohtumise praktikum](../k01/lab.md) · Bash, cron | latentsus, liiklus, vead ja ketas Labori seisus |
| [2. kohtumine · Sama kontroll kõigil hostidel](#2-kohtumine-sama-kontroll-koigil-hostidel-systemd-timerina) | [2. kohtumise praktikum](../k02/lab.md) · Ansible, systemd | iga host taaskäivitab oma teenuse ise |
| [3. kohtumine · Konteinerite tervis ja Uptime Kuma](#3-kohtumine-konteinerite-tervis-ja-uptime-kuma) | [3. kohtumise praktikum](../k03/lab.md) · Docker, Compose | `unhealthy` jõuab Labori seisu ja Kumasse |
| [4. kohtumine · Drift-valvur](#4-kohtumine-drift-valvur) | [4. kohtumise praktikum](../k04/lab.md) · OpenTofu | käsitsi muudatus Proxmoxis annab FAIL-i |
| [5. kohtumine · Kontroll väljast](#5-kohtumine-kontroll-valjast-schedule-workflow) | [5. kohtumise praktikum](../k05/lab.md) · GitHub Actions | ajastatud workflow, punane jooks rikke korral |
| [6. kohtumine · Öine kontroll ajalooga](#6-kohtumine-oine-kontroll-ajalooga) | [6. kohtumise praktikum](../k06/lab.md) · Jenkins | Test Result Trend kolme käivitusega |
| [7. kohtumine · Kubernetes valvab ise](#7-kohtumine-kubernetes-valvab-ise) | [7. kohtumise praktikum](../k07/lab.md) · kubectl | restart ja tühi endpoint näidatud |

*Tabel 1. Monitooringu ülesanded kohtumiste kaupa.*

Kõik ülesanded tehakse klassi Proxmoxis viie virtuaalmasina ja control node'iga. Issue'del on silt `monitooring` ja
tulemused lähevad Labori seisu laboritesse `mon-01` … `mon-07`. Iga ülesanne eeldab sama kohtumise praktikumi ja
töötavat skripti `scripts/labseis-report.sh` (1. kohtumine).

---

## 1. kohtumine · Neli signaali ühe skriptiga

**Eeldus:** [1. kohtumise praktikum](../k01/lab.md), `labseis-report.sh` · **Esita:** `k01-bash/golden-signals.sh`

Labori seis võib muutuda aeglaseks, anda vigu või võib ketas täis saada, ja sageli kuuled sellest alles kasutajalt. Skript
peaks probleemi märkama varem ja kirjutama tulemuse Labori seisu.

1. `golden-signals.sh` saadab `curl`-iga päringu web01 aadressile `/health` (`-o /dev/null -s -w`, `--max-time 5`) ja väljastab `kood aeg`.
2. Teisenda aeg millisekunditeks (`awk`), võrdle seda lävega `MAX_MS` (vaikimisi 500) ja saada tulemus: `labseis-report.sh mon-01 latency OK|FAIL "…"`.
3. Liikluse ja vead loe web01 access log'ist (`ssh web01 sudo tail -n 20000 /var/log/nginx/access.log`). Viimase 5 minuti
   read leiad viie mustriga `date -d "-$i min" '+[%d/%b/%Y:%H:%M'` ja `grep -F`-ga. Loe kokku kõik read ja 9. välja järgi 5xx vastused.
4. Küllastus: kontrolli kõigi viie hosti `df --output=pcent /` väljundit. Lävi on 80 % ja kontrolli nimi `disk-<host>`.
5. Kasuta skripti alguses `flock`-i, et kaks cron'i käivitust ei töötaks korraga. Cron käivitab skripti iga 5 minuti järel. `LABSEIS_TOKEN` pane cron'i
   reale või faili `~/.labseis.env` (`chmod 600`).
6. Fail asub kaustas `k01-bash/`, seega kontrollib seda ka `k01` automaatne hindaja: fail peab olema käivitatav, sellel peab olema shebang ja `set -e` ning ShellCheck ei tohi leida vigu.

**Kontroll:**

```bash
./k01-bash/golden-signals.sh                 # nt 200 0.034
ssh app01 sudo systemctl stop tomcat         # järgmine käivitus: 502 …, siis start
ssh db01 'df -h /; sudo fallocate -l 1G /tmp/fill'   # vaata enne df-i, et ketas päriselt täis ei saaks
ssh db01 sudo rm /tmp/fill
shellcheck k01-bash/golden-signals.sh; crontab -l
```

**Valmis, kui:**

- `golden-signals.sh` väljastab `200 <aeg>`, peatatud Tomcatiga `502 …`
- Labori seisus on `mon-01` all read `latency`, `traffic` ja `disk-*`
- `disk-db01` muutus pärast `fallocate`-i FAIL-iks ja pärast `rm`-i tagasi OK-ks
- `shellcheck` ei leia vigu, `crontab -l` näitab 5-minutilist rida

??? info "Miks nii"
    Mõõdad [nelja golden signal'it](https://sre.google/sre-book/monitoring-distributed-systems/):

    | Signaal | Kuidas Bashis mõõdad |
    |---|---|
    | latentsus | `curl -w '%{time_total}'` |
    | liiklus | Nginxi access log'i ridu minutis |
    | vead | HTTP 5xx arv, `/health` kood |
    | küllastus | `df`, mälu, RabbitMQ järjekorra pikkus |

    **Mõtle.** Miks mitte võrrelda ajatempleid stringina (`$4 >= "[04/Oct/<aasta>:14:00"`)? Mis juhtub kuuvahetusel?
    See on *pull*-kontroll (control node küsib). Kumb ebaõnnestub vaikselt, pull või push, kui control node ise on maas?

---

## 2. kohtumine · Sama kontroll kõigil hostidel, systemd timer'ina

**Eeldus:** [2. kohtumise praktikum](../k02/lab.md), Vault · **Esita:** `k02-ansible/roles/labseis_monit/`

Control node'i cron on üks võimalik rikkekoht: kui control node on maas, ei kontrolli keegi midagi. Seepärast peaks iga host
ennast ise kontrollima.

1. Loo uus roll `labseis_monit` ja muutuja, mis seob grupi teenusega (`db` → `mariadb`, `app` → `tomcat` …). Host valib
   oma teenuse `group_names` järgi.
2. Mall `labseis-monit.sh.j2`: kui teenus ei ole olekus `active`, taaskäivitab skript selle (`systemctl restart`), kirjutab logisse `/var/log/labseis/monit.log` ja teatab Labori seisu (`mon-02`).
3. Hoia token eraldi failis `/etc/labseis-monit.env` (`0600`, `no_log: true`), mitte unit'is ega skriptis. Väärtus tuleb Vaultist (`vault_labseis_token`).
4. `labseis-monit.service` (`Type=oneshot`, `EnvironmentFile=`) ja [`labseis-monit.timer`](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html) (`OnUnitActiveSec=5min`). Lisa handler `daemon_reload`.
5. `/etc/logrotate.d/labseis`: logi roteeritakse kord nädalas, alles jääb 4 koopiat ja vanad koopiad pakitakse (`compress`).

**Kontroll:**

```bash
ansible all -a 'systemctl list-timers labseis-monit.timer'
ssh mc01 sudo systemctl stop memcached      # oota kuni 5 min
ssh mc01 'systemctl is-active memcached; sudo tail -3 /var/log/labseis/monit.log'
ansible all -b -a 'stat -c %a /etc/labseis-monit.env'
ansible-playbook site.yml --ask-vault-pass  # teine käivitus
```

**Valmis, kui:**

- `list-timers` näitab timerit viiel hostil
- memcached on 5 minuti jooksul jälle olekus `active`, failis `monit.log` on selle kohta rida ja Labori seisus on OK "oli maas"
- `/etc/labseis-monit.env` õigused on `600` kõigil hostidel
- teise `ansible-playbook` käivituse kokkuvõttes on `changed=0`

??? info "Miks nii"
    **Mõtle.** systemd-l on ka `Restart=on-failure`. Millal piisab sellest ja millal on oma kontroll parem?
    Mida `Restart=` ei näe? (Vihje: protsess töötab, aga port ei vasta.)

---

## 3. kohtumine · Konteinerite tervis ja Uptime Kuma

**Eeldus:** [3. kohtumise praktikum](../k03/lab.md), healthcheck'id `compose.yaml`-is · **Esita:** `k03-docker/health-events.sh`, `k03-docker/compose.monitoring.yaml`

`docker compose ps` näitab `healthy` ja `unhealthy`, aga keegi ei vaata seda. Rike on nähtav ainult siis, kui keegi
juhtumisi käsu käivitab.

1. `health-events.sh` loeb käsuga `docker events --filter event=health_status` ([`docker events`](https://docs.docker.com/reference/cli/docker/system/events/)) konteineri nime ja oleku (`--format`) ning saadab `while read` tsüklis tulemuse:
   `labseis-report.sh mon-03 <konteiner> OK|FAIL`.
2. Loo `compose.yaml`-i kõrvale fail `compose.monitoring.yaml`: teenus [`louislam/uptime-kuma:2`](https://github.com/louislam/uptime-kuma), port 3001 ja **volume kausta `/app/data`**.
3. Käivita kahe failiga: `docker compose -f compose.yaml -f compose.monitoring.yaml up -d`.
4. Lisa Kumas monitorid: HTTP `http://web01/health` märksõnaga `UP` ning TCP `db01:3306`, `rmq01:5672` ja `mc01:11211`.
5. Seadista teavitus e-posti või webhook'i kaudu (Slacki ei kasutata).

**Kontroll:**

```bash
docker compose stop rmq01     # app01 /health → 503 → app01 unhealthy
docker compose ps app01
docker compose start rmq01
docker compose -f compose.yaml -f compose.monitoring.yaml down
docker compose -f compose.yaml -f compose.monitoring.yaml up -d
```

**Valmis, kui:**

- Labori seisus on `mon-03 app01` olnud FAIL ja muutunud tagasi OK-ks
- Kuma ajaloos on punane lõik (`stop rmq01`) ja roheline taastumine
- pärast käske `down` ja `up` on Kuma monitorid alles

??? info "Miks nii"
    Ilma volume'ita `/app/data`-le kaovad Kuma monitorid järgmise `up`-iga.

    **Mõtle.** Kuma töötab samas Compose'i projektis, mida see jälgib. Mis juhtub, kui Docker ise seiskub?

---

## 4. kohtumine · Drift-valvur

**Eeldus:** [4. kohtumise praktikum](../k04/lab.md) · **Esita:** `k04-tofu/drift-watch.sh`

Keegi muutis Proxmoxi veebiliideses virtuaalmasina mälu. Koodis kirjeldatud soovitud olek ja tegelik olek erinevad ning järgmine `apply` teeb ootamatu muudatuse.

1. `drift-watch.sh <kaust>`: `tofu plan -refresh-only -detailed-exitcode -lock=false -input=false -no-color`, väljund kirjuta ajutisse faili
   ([`tofu plan` exit-koodid](https://opentofu.org/docs/cli/commands/plan/)).
2. Väljumiskood 0 annab tulemuse `mon-04 drift OK`, kood 2 annab FAIL-i koos muutunud ressursside nimedega (`# … has changed` read) ja kood 1 FAIL-i teatega "plan ebaõnnestus".
3. Kasuta `flock`-i ja käivita skript cron'iga iga 15 minuti järel.
4. Proxmoxi token loe keskkonnamuutujana failist (`0600`), mitte cron'i realt.

**Kontroll:**

```bash
./k04-tofu/drift-watch.sh k04-tofu; echo "exit=$?"
# Proxmoxi UI-s muuda web01 RAM, oota järgmist cron'i käivitust
tofu -chdir=k04-tofu apply
shellcheck k04-tofu/drift-watch.sh
```

**Valmis, kui:**

- Labori seisus on `mon-04 drift` 15 minuti jooksul pärast mälu muutmist FAIL
- FAIL sõnumis on muutunud ressursi nimi
- pärast `tofu apply` on `drift` OK
- `crontab -l` real pole tokenit

??? info "Miks nii"
    **Mõtle.** Miks `-lock=false`? Mis juhtuks, kui valvur hoiaks lukku just siis, kui sa ise `apply` teed?
    Ja miks `-refresh-only`: mida näitaks tavaline `plan` lisaks, mis ei ole triiv?

---

## 5. kohtumine · Kontroll väljast: `schedule` workflow

**Eeldus:** [5. kohtumise praktikum](../k05/lab.md) (self-hosted runner) · **Esita:** `.github/workflows/smoke.yml`

Kõik seni tehtud kontrollid käivituvad samast võrgust. Kasutaja pöördub teenuse poole väljastpoolt ja võib näha probleeme, mida sisemised kontrollid ei märka.

1. Käivitaja [`schedule`](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#schedule) (näiteks iga 30 minuti järel tööajal) ja `workflow_dispatch`.
2. Üks job mõõdab `curl`-iga `/health` vastuse koodi ja aja ning kirjutab tabeli `$GITHUB_STEP_SUMMARY`-sse.
3. Job ebaõnnestub, kui kood ei ole 200, ja annab hoiatuse (`::warning::`), kui vastus võtab üle 1 sekundi.
4. GitHubi hostitud runner ei pääse VPN-i taga olevasse Proxmoxi: kasuta `runs-on: self-hosted` (5. kohtumise labori runner control node'il) või 5. kohtumise kodutöö EC2 avalikku aadressi (`vars.SMOKE_URL`).

**Kontroll:**

```bash
actionlint .github/workflows/smoke.yml
gh workflow run smoke.yml
ssh web01 sudo systemctl stop nginx; gh workflow run smoke.yml; ssh web01 sudo systemctl start nginx
gh run list --workflow smoke.yml
```

**Valmis, kui:**

- `gh run list` näitab `schedule` sündmusega käivitusi
- kui Nginx on peatatud, on käivitus punane ja GitHub saatis e-kirja
- `actionlint` ei leia vigu (`k05` automaatne hindaja käivitab selle kõigil workflow'del)

??? info "Miks nii"
    **Mõtle.** Control node'is töötav self-hosted runner ei kontrolli tegelikult väljastpoolt. Mida lisab see kontroll siis 1. kohtumise skriptile?

---

## 6. kohtumine · Öine kontroll ajalooga

**Eeldus:** [6. kohtumise praktikum](../k06/lab.md) (agent label'iga) · **Esita:** `k06-jenkins/Jenkinsfile.nightly`

Labori seis näitab praegust olekut. Nädala trendist näed, millal ja kui tihti mõni teenus maas oli.

1. Loo eraldi job: `agent { label '<sinu-github>' }`, `triggers { cron('H 2 * * *') }`.
2. `parallel` plokis on viis haru (db01:3306 … web01:80). Iga haru kirjutab ühe JUnit XML-faili (`<testcase>`, vea korral `<failure>`) ja mõõdab aja.
3. Lisa eraldi kontroll `/health` HTTP koodile.
4. Etapp "Kettaruum" kontrollib agendi `df` väljundit ja ebaõnnestub, kui kasutus on üle 85 % (Docker image'id kuhjuvad 6. kohtumise laboris).
5. `post { always { junit 'reports/*.xml' } }` ([`junit` samm](https://www.jenkins.io/doc/pipeline/steps/junit/)) ja plokis `unsuccessful` samm `mail` (kui Jenkinsis on e-post seadistatud).

**Kontroll:**

```bash
# käivita job Jenkinsis käsitsi kolm korda, ühel korral:
ssh rmq01 sudo systemctl stop rabbitmq-server
ssh rmq01 sudo systemctl start rabbitmq-server
```

**Valmis, kui:**

- jobi lehel on "Test Result Trend" graafik vähemalt kolme käivitusega
- kui rmq01 on maas, on üks testcase `<failure>` ja build `UNSTABLE` või `FAILURE`
- "Kettaruum" etapp näitab agendi kasutust protsentides

??? info "Miks nii"
    **Mõtle.** JUnit on testide formaat. Mida võidad, kui paned monitooringu tulemuse testiraporti kujule? Mida kaotad?

---

## 7. kohtumine · Kubernetes valvab ise

**Eeldus:** [7. kohtumise praktikum](../k07/lab.md) (Labori seis sinu namespace'is)

1.–6. kohtumisel kirjutasid kontrolli ja taaskäivituse ise. Kubernetesis on see olemas, kui määrad, mida kontrollida
([probe'id](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)).

1. Vaata, mis probe'id sinu Deployment'is on.
2. Tapa protsess konteineris ja jälgi restartide arvu ning sündmusi.
3. Riku readiness: vähenda rmq01 replica'te arv nullini. Siis vastab `/health` koodiga 503 ja app01 pod on olekus `0/1 Ready`. Seejärel taasta rmq01.
4. Vaata ressursikasutust käsuga `kubectl top pods` (k3s metrics-server). Viga `Forbidden` tähendab, et sinu rollil puudub õigus `metrics.k8s.io`. Sel juhul anna koolitajale teada.

**Kontroll:**

```bash
kubectl get deploy app01 -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'
kubectl get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount
kubectl exec deploy/app01 -- kill 1
kubectl get pods -w
kubectl get events --sort-by=.lastTimestamp
kubectl scale deploy/rmq01 --replicas=0; kubectl get endpoints app01
kubectl scale deploy/rmq01 --replicas=1
kubectl top pods
```

**Valmis, kui:**

- app01 `restartCount` on pärast `kill 1` ühe võrra suurem
- kui rmq01 replica'te arv on 0, on `kubectl get endpoints app01` tühi ja pod `0/1 Ready`
- pärast taastamist on endpoint jälle olemas
- issue'sse on kirjutatud üks lause restarti ja tühja endpointi vahe kohta

??? info "Miks nii"
    **Mõtle.** Kui liveness ebaõnnestub, taaskäivitatakse konteiner. Kui readiness ebaõnnestub, ei suunata pod'ile liiklust. Kumb peaks vaatama `/health`-i, mis
    sõltub andmebaasist? Mis juhtuks, kui liveness kontrolliks andmebaasi ja db01 oleks 5 minutit maas?

---

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| skript töötab käsitsi, aga mitte cron'iga | cron'i `PATH` on lühike ja keskkond tühi | täispikad teed, token failist |
| `labseis-report.sh` 401 | vale `LABSEIS_TOKEN` | kontrolli tokenit |
| systemd timer ei käivitu | timer pole lubatud või unit ebaõnnestub | `systemctl list-timers`, `journalctl -u labseis-monit` |
| Kuma ei leia `web01` | Kuma pole samas Compose'i võrgus | kontrolli, kas andsid `-f`-iga mõlemad failid |
| `drift-watch` alati FAIL "plan ebaõnnestus" | token pole cron'i keskkonnas või `tofu init` puudub | token failist, käivita `tofu init` |
| Actions `schedule` ei käivitu | schedule käivitub ainult vaikeharu workflow'st ja võib hilineda; avalikus repos peatub schedule 60 päeva järel | pane workflow vaikeharusse |
