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
| `lab_dir: command not found` | tühikud võrdusmärgi ümber | `lab_dir="..."`, ilma tühikuteta |
| `./prepare-training.sh: Permission denied` | fail pole käivitatav | `chmod u+x prepare-training.sh` või `bash prepare-training.sh` |
| `$'\r': command not found` | Windowsi reavahetused | VS Code all paremal `CRLF` → `LF`, salvesta |
| `bash: prepare-training.sh: No such file or directory` web01-s | skript pole web01-l | `scp prepare-training.sh web01:` |
| `mkdir: cannot create directory ... File exists` | kausta kohal on fail | `ssh web01 rm automation-lab` |
| **Ansible** | | |
| `ansible: command not found` | Ansible pole paigaldatud | [5. Ansible, A1](lab-5-ansible.md#a1-paigalda-ansible) |
| `UNREACHABLE` | vale IP inventory's või võti puudub | kontrolli `inventory.ini`, proovi `ssh kasutaja@<ip>` |
| `Could not match supplied host pattern` | inventory't ei leitud | lisa `-i inventory.ini`, ole kaustas `~/kursus/k01` |
| `Syntax Error while loading YAML` | vale taane või tabulaator | taane ainult tühikutega, vaata rea numbrit |
| teine käivitus annab ikka `changed` | `mode` ilma jutumärkideta või keegi muudab faili | `mode: "0640"` |
| **Git** | | |
| `git push` → `rejected` | GitHubis on uuem commit | `git pull --rebase`, siis `git push` |
| `fatal: not a git repository` | oled vales kaustas | `cd ~/kursus` |

*Tabel 1. Levinud vead.*

Ei leidnud? Küsi [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehel, lisa käsk ja kogu veateade tekstina.
