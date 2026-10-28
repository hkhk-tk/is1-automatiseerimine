---
tags:
  - Monitooring
---

# Monitooringu ülesanded (Proxmox)

| Ülesanne | Seos | Tulemus |
|---|---|---|
| [1. kohtumine · Neli signaali ühe skriptiga](#1-kohtumine-neli-signaali-uhe-skriptiga) | [1. kohtumise labor](../k01/lab.md) · Bash, cron | latentsus, liiklus, vead ja ketas Labori seisus |
| [2. kohtumine · Sama kontroll kõigil hostidel](#2-kohtumine-sama-kontroll-koigil-hostidel-systemd-timerina) | [2. kohtumise labor](../k02/lab.md) · Ansible, systemd | iga host taaskäivitab oma teenuse ise |
| [3. kohtumine · Konteinerite tervis ja Uptime Kuma](#3-kohtumine-konteinerite-tervis-ja-uptime-kuma) | [3. kohtumise labor](../k03/lab.md) · Docker, Compose | `unhealthy` jõuab Labori seisu ja Kumasse |
| [4. kohtumine · Drift-valvur](#4-kohtumine-drift-valvur) | [4. kohtumise labor](../k04/lab.md) · OpenTofu | käsitsi muudatus Proxmoxis annab FAIL-i |
| [5. kohtumine · Kontroll väljast](#5-kohtumine-kontroll-valjast-schedule-workflow) | [5. kohtumise labor](../k05/lab.md) · GitHub Actions | ajastatud workflow, punane jooks rikke korral |
| [6. kohtumine · Öine kontroll ajalooga](#6-kohtumine-oine-kontroll-ajalooga) | [6. kohtumise labor](../k06/lab.md) · Jenkins | Test Result Trend kolme käivitusega |
| [7. kohtumine · Kubernetes valvab ise](#7-kohtumine-kubernetes-valvab-ise) | [7. kohtumise labor](../k07/lab.md) · kubectl | restart ja tühi endpoint näidatud |

*Tabel 1. Monitooringu ülesanded kohtumiste kaupa.*

Kõik ülesanded töötavad klassi Proxmoxis sinu viie VM-i ja control node'iga, issue'd on labeliga `monitooring` ja
tulemused lähevad Labori seisu laboritesse `mon-01` … `mon-07`. Eeldus on igal ülesandel sama kohtumise labor ja
töötav `scripts/labseis-report.sh` (1. kohtumine).

---

## 1. kohtumine · Neli signaali ühe skriptiga

**Eeldus:** [1. kohtumise labor](../k01/lab.md), `labseis-report.sh` · **Esita:** `k01-bash/golden-signals.sh`

Labori seis võib olla aeglane, anda vigu või ketas võib täis saada ja sina kuuled sellest kasutajalt. Tahad, et
skript märkaks seda enne ja kirjutaks tulemuse Labori seisu.

1. `golden-signals.sh` teeb `curl`-i web01 `/health` vastu (`-o /dev/null -s -w`, `--max-time 5`) ja väljastab `kood aeg`.
2. Aeg millisekunditeks (`awk`), võrdlus lävega `MAX_MS` (vaikimisi 500), tulemus `labseis-report.sh mon-01 latency OK|FAIL "…"`.
3. Liiklus ja vead web01 access log'ist (`ssh web01 sudo tail -n 20000 /var/log/nginx/access.log`): viimase 5 minuti
   read leiad viie mustriga `date -d "-$i min" '+[%d/%b/%Y:%H:%M'` ja `grep -F`-ga; loe kokku read ja 9. välja järgi 5xx.
4. Küllastus: kõigi viie hosti `df --output=pcent /`, lävi 80 %, check `disk-<host>`.
5. Skripti alguses `flock`, et kaks cron'i käivitust ei töötaks korraga. Cron iga 5 min järel, `LABSEIS_TOKEN` cron'i
   real või failis `~/.labseis.env` (`chmod 600`).
6. Fail on `k01-bash/` kaustas, seega `k01` automaatne hindaja kontrollib seda samuti: käivitatav, shebang, `set -e`, ShellCheck.

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
- `disk-db01` on läinud FAIL → OK pärast `fallocate` ja `rm`-i
- `shellcheck` on puhas, `crontab -l` näitab 5-minutilist rida

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

**Eeldus:** [2. kohtumise labor](../k02/lab.md), Vault · **Esita:** `k02-ansible/roles/labseis_monit/`

Cron control node'il on üks koht, kus asi võib katki minna. Kui control node on maas, ei valva keegi. Iga host peaks
ennast ise valvama.

1. Uus roll `labseis_monit`. Muutuja, mis seob grupi teenusega (`db` → `mariadb`, `app` → `tomcat` …). Host valib
   oma teenuse `group_names` järgi.
2. Mall `labseis-monit.sh.j2`: kui teenus pole `active`, `systemctl restart`, logi `/var/log/labseis/monit.log`, teata Labori seisu (`mon-02`).
3. Token eraldi faili `/etc/labseis-monit.env` (`0600`, `no_log: true`), mitte unit'isse ega skripti. Väärtus Vaultist (`vault_labseis_token`).
4. `labseis-monit.service` (`Type=oneshot`, `EnvironmentFile=`) + [`labseis-monit.timer`](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html) (`OnUnitActiveSec=5min`). Handler `daemon_reload`.
5. `/etc/logrotate.d/labseis`: nädalas, 4 koopiat, `compress`.

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
- memcached on 5 minuti jooksul jälle `active`, `monit.log`-is on rida ja Labori seisus OK "oli maas"
- `/etc/labseis-monit.env` õigused on `600` kõigil hostidel
- teine `ansible-playbook` → `changed=0`

??? info "Miks nii"
    **Mõtle.** systemd-l on ka `Restart=on-failure`. Millal piisab sellest ja millal on oma kontroll parem?
    Mida `Restart=` ei näe? (Vihje: protsess töötab, aga port ei vasta.)

---

## 3. kohtumine · Konteinerite tervis ja Uptime Kuma

**Eeldus:** [3. kohtumise labor](../k03/lab.md), healthcheck'id `compose.yaml`-is · **Esita:** `k03-docker/health-events.sh`, `k03-docker/compose.monitoring.yaml`

`docker compose ps` näitab `healthy` ja `unhealthy`, aga keegi ei vaata seda. Rike on nähtav ainult siis, kui keegi
juhtumisi käsu käivitab.

1. `health-events.sh`: `docker events --filter event=health_status` ([`docker events`](https://docs.docker.com/reference/cli/docker/system/events/)) + `--format` nimi ja olek, `while read` tsüklis
   `labseis-report.sh mon-03 <konteiner> OK|FAIL`.
2. `compose.monitoring.yaml` `compose.yaml`-i kõrval: teenus [`louislam/uptime-kuma:2`](https://github.com/louislam/uptime-kuma), port 3001, **volume `/app/data`-le**.
3. Käivita kahe failiga: `docker compose -f compose.yaml -f compose.monitoring.yaml up -d`.
4. Kuma monitorid: HTTP `http://web01/health` keyword `UP`; TCP `db01:3306`, `rmq01:5672`, `mc01:11211`.
5. Teavitus e-postiga või webhook'iga (Slacki ei kasuta).

**Kontroll:**

```bash
docker compose stop rmq01     # app01 /health → 503 → app01 unhealthy
docker compose ps app01
docker compose start rmq01
docker compose -f compose.yaml -f compose.monitoring.yaml down
docker compose -f compose.yaml -f compose.monitoring.yaml up -d
```

**Valmis, kui:**

- Labori seisus on `mon-03 app01` läinud FAIL → OK
- Kuma ajaloos on punane lõik (`stop rmq01`) ja roheline taastumine
- pärast `down` + `up` on Kuma monitorid alles

??? info "Miks nii"
    Ilma volume'ita `/app/data`-le kaovad Kuma monitorid järgmise `up`-iga.

    **Mõtle.** Kuma on samas Compose'i projektis kui see, mida ta valvab. Mis juhtub, kui Docker ise seiskub?

---

## 4. kohtumine · Drift-valvur

**Eeldus:** [4. kohtumise labor](../k04/lab.md) · **Esita:** `k04-tofu/drift-watch.sh`

Keegi muutis Proxmoxi UI-s VM-i RAM-i. Kood ütleb üht, tegelikkus teist, ja järgmine `apply` toob üllatuse.

1. `drift-watch.sh <kaust>`: `tofu plan -refresh-only -detailed-exitcode -lock=false -input=false -no-color`, väljund ajutisse faili
   ([`tofu plan` exit-koodid](https://opentofu.org/docs/cli/commands/plan/)).
2. Exit 0 → `mon-04 drift OK`, 2 → FAIL ja muutunud ressursside nimed (`# … has changed` read), 1 → FAIL "plan ebaõnnestus".
3. `flock`, cron iga 15 min.
4. Proxmoxi token keskkonnamuutujana failist (`0600`), mitte cron'i reale.

**Kontroll:**

```bash
./k04-tofu/drift-watch.sh k04-tofu; echo "exit=$?"
# Proxmoxi UI-s muuda web01 RAM, oota järgmist cron'i käivitust
tofu -chdir=k04-tofu apply
shellcheck k04-tofu/drift-watch.sh
```

**Valmis, kui:**

- Labori seisus on `mon-04 drift` FAIL 15 min jooksul pärast RAM-i muutmist
- FAIL sõnumis on muutunud ressursi nimi
- pärast `tofu apply` on `drift` OK
- `crontab -l` real pole tokenit

??? info "Miks nii"
    **Mõtle.** Miks `-lock=false`? Mis juhtuks, kui valvur hoiaks lukku just siis, kui sa ise `apply` teed?
    Ja miks `-refresh-only`: mida tavaline `plan` lisaks näitaks, mis pole drift?

---

## 5. kohtumine · Kontroll väljast: `schedule` workflow

**Eeldus:** [5. kohtumise labor](../k05/lab.md) (self-hosted runner) · **Esita:** `.github/workflows/smoke.yml`

Kõik sinu kontrollid käivituvad sama võrgu seest. Kasutaja tuleb väljast ja näeb seda, mida sisemised kontrollid ei näe.

1. Trigger [`schedule`](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#schedule) (nt iga 30 min tööajal) + `workflow_dispatch`.
2. Üks job: `curl` `/health` kood ja aeg, tabel `$GITHUB_STEP_SUMMARY`-sse.
3. Job ebaõnnestub, kui kood ≠ 200, ja hoiatab (`::warning::`), kui aeg > 1 s.
4. GitHubi hostitud runner ei näe sinu Proxmoxi VPN-i taha: kasuta `runs-on: self-hosted` (5. kohtumise labori runner control node'il) või 5. kohtumise kodutöö EC2 avalikku aadressi (`vars.SMOKE_URL`).

**Kontroll:**

```bash
actionlint .github/workflows/smoke.yml
gh workflow run smoke.yml
ssh web01 sudo systemctl stop nginx; gh workflow run smoke.yml; ssh web01 sudo systemctl start nginx
gh run list --workflow smoke.yml
```

**Valmis, kui:**

- `gh run list` näitab `schedule` sündmusega käivitusi
- peatatud Nginxiga on jooks punane ja GitHubi e-kiri tuli
- `actionlint` on puhas (`k05` automaatne hindaja käivitab selle kõigil workflow'del)

??? info "Miks nii"
    **Mõtle.** Self-hosted runner control node'il ei ole tegelikult "väljast". Mida see kontroll siis ikkagi lisab 1. kohtumise skriptile?

---

## 6. kohtumine · Öine kontroll ajalooga

**Eeldus:** [6. kohtumise labor](../k06/lab.md) (agent label'iga) · **Esita:** `k06-jenkins/Jenkinsfile.nightly`

Labori seis näitab praegust seisu. Tahad näha nädala trendi: millal ja kui tihti mõni teenus maas oli.

1. Eraldi job: `agent { label '<sinu-github>' }`, `triggers { cron('H 2 * * *') }`.
2. `parallel` viis haru (db01:3306 … web01:80), igaüks kirjutab ühe JUnit XML faili (`<testcase>`, vea korral `<failure>`) ja mõõdab aja.
3. Eraldi kontroll `/health` HTTP koodile.
4. Etapp "Kettaruum": agendi `df`, ebaõnnestub üle 85 % (Docker image'id kuhjuvad 6. kohtumise laboris).
5. `post { always { junit 'reports/*.xml' } }` ([`junit` samm](https://www.jenkins.io/doc/pipeline/steps/junit/)), `unsuccessful` → `mail` (kui Jenkinsis on e-post seadistatud).

**Kontroll:**

```bash
# käivita job Jenkinsis käsitsi kolm korda, ühel korral:
ssh rmq01 sudo systemctl stop rabbitmq-server
ssh rmq01 sudo systemctl start rabbitmq-server
```

**Valmis, kui:**

- jobi lehel on "Test Result Trend" graafik vähemalt kolme käivitusega
- rmq01 maas olles on üks testcase `<failure>` ja build `UNSTABLE` või `FAILURE`
- "Kettaruum" etapp näitab agendi kasutust protsentides

??? info "Miks nii"
    **Mõtle.** JUnit on testide formaat. Mida võidad, kui paned monitooringu tulemuse testiraporti kujule? Mida kaotad?

---

## 7. kohtumine · Kubernetes valvab ise

**Eeldus:** [7. kohtumise labor](../k07/lab.md) (Labori seis sinu namespace'is)

1.–6. kohtumisel kirjutasid ise kontrolli ja taaskäivituse. Kubernetesis on see sisse ehitatud, kui ütled, mida kontrollida
([probe'id](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)).

1. Vaata, mis probe'id sinu Deployment'is on.
2. Tapa protsess konteineris ja jälgi restartide arvu ning sündmusi.
3. Riku readiness: rmq01 0 replica'ni → `/health` 503 → app01 pod `0/1 Ready`. Taasta.
4. Vaata ressursse `kubectl top pods`-iga (k3s metrics-server). `Forbidden` tähendab, et sinu rollil puudub `metrics.k8s.io` õigus: ütle koolitajale.

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
- rmq01 0 replica'ga on `kubectl get endpoints app01` tühi ja pod `0/1 Ready`
- pärast taastamist on endpoint jälle olemas
- issue'sse on kirjutatud üks lause restarti ja tühja endpointi vahe kohta

??? info "Miks nii"
    **Mõtle.** Liveness ebaõnnestumine → restart, readiness ebaõnnestumine → liiklus eemale. Kumb peaks vaatama `/health`-i, mis
    sõltub andmebaasist? Mis juhtuks, kui liveness kontrolliks andmebaasi ja db01 oleks 5 minutit maas?

---

## Veaotsing

| Probleem | Põhjus | Lahendus |
|---|---|---|
| cron'is töötab käsitsi, aga mitte ajastatult | cron'i `PATH` on lühike ja keskkond tühi | täispikad teed, token failist |
| `labseis-report.sh` 401 | vale `LABSEIS_TOKEN` | kontrolli tokenit |
| systemd timer ei käivitu | timer pole lubatud või unit ebaõnnestub | `systemctl list-timers`, `journalctl -u labseis-monit` |
| Kuma ei leia `web01` | Kuma pole samas Compose'i võrgus | kas `-f` mõlemad failid? |
| `drift-watch` alati FAIL "plan ebaõnnestus" | token pole cron'i keskkonnas või `tofu init` puudub | token failist, käivita `tofu init` |
| Actions `schedule` ei käivitu | schedule käivitub ainult vaikeharu workflow'st ja võib hilineda; avalikus repos peatub schedule 60 päeva järel | pane workflow vaikeharusse |
