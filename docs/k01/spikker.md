---
tags:
  - Bash
  - Linux
---

# Linux + Bash spikker

Testitud Ubuntu 24.04 (Bash 5.2, systemd 255) ja Rocky 9 (Bash 5.1, systemd 252) peal.

<div class="spikker" markdown>

**Bash: veakäsitlus, muutujad, taustatööd**

| Muster | Mida teeb ja lõks |
|---|---|
| `set -Eeuo pipefail`, `shopt -s inherit_errexit` | `-E` annab ERR-trap'i funktsioonidele; `inherit_errexit` lülitab `-e` käsuasenduses sisse |
| `trap 'echo "viga real $LINENO: $BASH_COMMAND" >&2' ERR` | rea number ja käsk stderr-i; `-e` ei rakendu `if`/`&&`/`||` tingimuses |
| `tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT` | koristus ka katkestuse korral |
| `local x; x=$(käsk)` | `local x=$(käsk)` tagastab alati 0 (SC2155) |
| `: "${DB_PASSWORD:?puudub}"` · `${GATE_TIMEOUT:-120}` | kohustuslik muutuja · vaikeväärtus |
| `printf '%q ' "$@"` | argumendid teise shelli (ssh kaugkäsk) muutmata kujul |
| `mapfile -t hosts < <(grep -v '^#' hosts)` | read massiivi enne tsüklit, `ssh` ei saa tsükli stdin'i |
| `while getopts 'nvf:j:' o; do case $o in …; esac; done; shift $((OPTIND-1))` | lühivõtmed |
| `[[ $s =~ ^([a-z0-9]+)\ ([0-9.]+)$ ]] && echo "${BASH_REMATCH[1]}"` | regex ilma `grep`-ita |
| `cmd1 | cmd2; echo "${PIPESTATUS[@]}"` | toru iga lüli kood |
| `exec 9> lock; flock -n 9 || exit 1` | lukk kogu skriptile, vabaneb ka pärast `kill -9` |
| `pid[$h]=$!` … `wait "${pid[$h]}" || rc=$?` · `wait -n` | iga taustatöö kood eraldi; argumentideta `wait` annab 0 |
| `timeout --kill-after=10 60 käsk` | 124 ajapiir, 137 = SIGKILL |
| `shellcheck -S warning *.sh` · `bash -n` · `PS4='+ ${LINENO}: ' bash -x` | staatiline kontroll · süntaks · jälitus reanumbriga |

**Väljund, protsessid, koodid**

| Käsk | Milleks |
|---|---|
| `käsk > fail 2>&1` · `käsk 2>&1 > fail` | mõlemad faili · ainult stdout faili (järjekord loeb) |
| `echo "viga" >&2` · `logger -t websetup -p user.err "…"` | teade stderr-i · journal'isse sildi ja prioriteediga |
| `ps -o pid,ppid,user,etimes,cmd -C java` · `pgrep -af tomcat` | kes, kui kaua, millise käsureaga |
| `tr '\0' ' ' < /proc/<pid>/cmdline` · `cat /proc/<pid>/environ` | mida näeb teine kasutaja (käsurida) ja root (keskkond) |
| `kill -0 "$pid"` | kas protsess elab, signaali saatmata |
| koodid `1–2` · `126` · `127` · `130` · `141` · `143` | viga · pole käivitatav · käsku pole (PATH) · Ctrl-C · SIGPIPE torus · SIGTERM |

**Failid, õigused, PATH**

| Käsk | Milleks |
|---|---|
| `install -m 640 -o root -g tomcat uus /etc/x` | kopeerimine koos õiguste ja omanikuga ühe käsuga |
| `cmp -s uus vana || install …` | idempotentne muudatus |
| `stat -c '%a %U:%G %n' f` · `namei -l /opt/tomcat/logs` | õigused · iga tee lüli õigused (kus `x` puudub) |
| `umask 077` | uued failid ainult omanikule (saladused) |
| `type -a ansible` · `command -v jq` · `hash -r` | milline fail käivitub · kas tööriist on · unusta vahemälu |
| `sudo sh -c 'echo $PATH'` · `sudo -l` | sudo `secure_path` erineb sinu PATH-ist · mida tohid |
| `restorecon -Rnv /var/www` · `ls -Z` | SELinuxi konteksti kontroll enne parandust (Rocky) |
| `df -h --output=pcent,target` · `du -xsh /var/log/*` · `findmnt /var` | ketas, kes selle täitis, mis on monteeritud |

**systemd ja logid**

| Käsk | Milleks |
|---|---|
| `systemctl is-active` / `is-enabled` / `is-failed` | skriptile sobiv kood, mitte väljund |
| `systemctl cat tomcat` · `systemctl show -p MainPID,ActiveEnterTimestamp tomcat` | unit koos drop-in'idega · olek skriptile |
| `systemctl --user …` · `loginctl enable-linger "$USER"` | kasutaja unit'id · töötavad ka ilma sessioonita |
| `systemd-analyze calendar '*:0/5'` · `systemctl list-timers` | ajastus enne kasutamist · järgmine käivitus |
| `journalctl -u tomcat -n 50 --no-pager` · `-t websetup` · `-p err -b` | unit · silt · vead sellest boodist |
| `journalctl --since -30min -o short-iso` · `--disk-usage` · `--list-boots` | ajajoon · journal'i maht · kas on püsiv |

**Võrk, SSH, distro**

| Käsk | Milleks |
|---|---|
| `ss -tlnp` · `ss -tnp state established '( dport = :3306 )'` | kes kuulab ja kus · aktiivsed ühendused |
| `getent hosts db01` · `dig +short db01` | nimi nagu rakendus seda näeb (`/etc/hosts`) · ainult DNS |
| `timeout 2 bash -c ': < /dev/tcp/db01/3306'` | TCP kontroll ilma `nc`-ta |
| `curl -sS -o /tmp/b -w '%{http_code}' URL` · `curl -sv URL 2>&1 | grep -E 'Connected|SSL|expire'` | kood ja keha eraldi · kihid nimi → TCP → TLS → HTTP |
| `ssh -G host` · `ssh -n host käsk` · `ssh host 'bash -s' < skript.sh` | tegelikud seaded · stdin kinni · skript kopeerimata |
| `sshd -t` · `sshd -T | grep -i passwordauth` · `ssh-keygen -lf ~/.ssh/id_ed25519.pub` | konf enne reload'i · kehtiv väärtus · võtme sõrmejälg logis |
| `. /etc/os-release; echo "$ID $VERSION_ID"` | distro skriptis |
| `apt-get -o DPkg::Lock::Timeout=120 install -y …` · `dpkg-query -W -f='${Status}' pkg` | ootab lukku · kas pakk on paigas |
| `dnf -yq install …` · `rpm -q pkg` · `dnf needs-restarting -r` | sama Rocky's · kas reboot on vaja |
| `cloud-init status --wait` | esimene boot on lõppenud |
| `jq -r '.db // "puudub"' health.json` | JSON-väli ilma `grep`-ita |

</div>

*Bashi manuaal: [set](https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html), [trap](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-trap); [ShellChecki koodid](https://www.shellcheck.net/wiki/); [journalctl(1)](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html).*
