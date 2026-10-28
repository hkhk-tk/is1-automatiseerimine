---
tags:
  - Veaotsing
---

# Abi: levinud vead

| Mida näed | Põhjus | Mida teha |
|---|---|---|
| **SSH** | | |
| `Connection timed out` | VPN pole ühendatud või vale IP | ühenda VPN, kontrolli IP-d |
| `Permission denied (publickey,password)` | võti pole masinas või vale parool | käivita uuesti `bash ~/ssh-seadistus.sh` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | masin loodi uuesti | `ssh-keygen -R <ip>` |
| `ssh -T git@github.com` → `Permission denied` | control node'i võti pole GitHubis | [1. Keskkond, A7](lab-1-keskkond.md#a7-voti-githubi-ja-kursuse-repo) |
| **Bash** | | |
| `./prepare-training.sh: Permission denied` | fail pole käivitatav | `chmod u+x prepare-training.sh` või `bash prepare-training.sh` |
| `$'\r': command not found` | Windowsi reavahetused | VS Code all paremal `CRLF` → `LF`, salvesta |
| `bash: prepare-training.sh: No such file or directory` web01-s | skript pole web01-l | `scp prepare-training.sh web01:` |
| `mkdir: cannot create directory ... File exists` | kaust on juba olemas (käsitsi osas) | see on oodatav; skriptis kasutad `mkdir -p` |
| **Ansible** | | |
| `ansible: command not found` | Ansible pole paigaldatud | [3. Ansible'i alused, A1](lab-3-ansible-alused.md#a1-paigalda-ansible) |
| `UNREACHABLE` | masina nimi pole `~/.ssh/config`-is või võti puudub | proovi `ssh web01`; vajadusel käivita `bash ~/ssh-seadistus.sh` |
| `Could not match supplied host pattern` | inventory't ei leitud | ole kaustas `~/kursus/k01`, kontrolli `ansible --version` real `config file` |
| `Incorrect sudo password` | `-K` parool on vale või masinates on eri paroolid | kasuta kõigis masinates sama parooli |
| `Missing sudo password` | ülesanne vajab `become`-i, aga `-K` puudub | lisa käsule `-K` |
| `Syntax Error while loading YAML` | vale taane või tabulaator | taane ainult tühikutega, vaata rea numbrit |
| teine käivitus annab ikka `changed` | `mode` ilma jutumärkideta või keegi muudab faili | `mode: "0640"` |
| **Git** | | |
| `git push` → `rejected` | GitHubis on uuem commit | `git pull --rebase`, siis `git push` |
| `fatal: not a git repository` | oled vales kaustas | `cd ~/kursus` |

*Tabel 1. Levinud vead.*

Ei leidnud? Küsi [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehel, lisa käsk ja kogu veateade tekstina.
