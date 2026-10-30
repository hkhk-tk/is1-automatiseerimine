---
tags:
  - Veaotsing
---

# Abi: levinud vead

| Mida näed | Põhjus | Mida teha |
|---|---|---|
| **SSH** | | |
| `Connection timed out` | VPN pole ühendatud või IP-aadress on vale | ühenda VPN, kontrolli IP-aadressi |
| `Permission denied (publickey,password)` | avalik võti pole hallatavas masinas või parool on vale | käivita uuesti `bash ~/ssh-seadistus.sh` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | masin loodi uuesti | `ssh-keygen -R <ip>` |
| `ssh -T git@github.com` → `Permission denied` | control node'i võti pole GitHubis | [1. Keskkond, A6](lab-1-keskkond.md#a6-voti-githubi-ja-kursuse-repo) |
| **Bash** | | |
| `./prepare-training.sh: Permission denied` | fail pole käivitatav | `chmod u+x prepare-training.sh` või `bash prepare-training.sh` |
| `$'\r': command not found` | Windowsi reavahetused | VS Code all paremal `CRLF` → `LF`, salvesta |
| `bash: prepare-training.sh: No such file or directory` web01-s | skript pole web01-l | `scp prepare-training.sh web01:` |
| `mkdir: cannot create directory ... File exists` | kaust on juba olemas (käsitsi osas) | see on oodatav; skriptis kasutad `mkdir -p` |
| **Ansible** | | |
| `ansible: command not found` | Ansible pole paigaldatud | [3. Ansible'i alused, A1](lab-3-ansible-alused.md#a1-paigalda-ansible) |
| `UNREACHABLE` | SSH konfiguratsioonis puudub masina aadress või autentimine SSH-võtmega ei tööta | proovi `ssh web01`; vajadusel käivita `bash ~/ssh-seadistus.sh` |
| `Could not match supplied host pattern` | masinat või gruppi ei leitud kasutatavast inventory'st | ole kaustas `~/kursus/k01`, kontrolli `ansible --version` real `config file` ja nimesid failis `inventory.ini` |
| `Incorrect sudo password` | kasutasid võtit `-K` ja sisestasid vale parooli | sisesta kasutaja `kasutaja` parool; laboris pole `-K` vaja |
| `Missing sudo password` | masinas nõutakse `sudo` jaoks parooli, aga `-K` puudub | lisa käsule `-K` |
| `Syntax Error while loading YAML` | vale taane või tabulaator | taane ainult tühikutega, vaata rea numbrit |
| teine käivitus annab ikka `changed` | mõni ülesanne muudab igal käivitusel olekut või tegelik olek muutub käivituste vahel | vaata, milline ülesanne annab `changed`, ja kontrolli selle mooduli parameetreid (nt `mode: "0640"` jutumärkides) |
| **Git** | | |
| `git push` → `rejected` | GitHubis on uuem commit | `git pull --rebase`, siis `git push` |
| `fatal: not a git repository` | oled vales kaustas | `cd ~/kursus` |

*Tabel 1. Levinud vead.*

Ei leidnud oma viga? Kirjuta [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehele. Lisa käsk ja kogu veateade tekstina.
