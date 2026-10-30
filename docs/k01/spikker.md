---
tags:
  - Bash
  - Linux
---

# Linuxi ja Bashi spikker

Siin on käsud, mida 1. kohtumisel kasutad. Käsud on testitud Ubuntu 24.04 ja AlmaLinux 9 keskkonnas.

<div class="spikker" markdown>

**Kaustad ja failid**

| Käsk | Milleks |
|---|---|
| `pwd` · `cd ~/kursus/k01` · `cd -` | praegune kaust · kausta vahetamine · tagasi eelmisesse kausta |
| `ls -la` | kausta sisu koos peidetud failide ja õigustega |
| `cat fail` | faili sisu kuvamine |
| `mkdir kaust` · `mkdir -p a/b` | kausta loomine · loob ka vahepealsed kaustad ega anna viga, kui kaust on olemas |
| `rm fail` · `rm -r kaust` | faili kustutamine · kausta kustutamine koos sisuga |
| `cp fail koopia` · `scp fail web01:` | kopeerimine samas masinas · kopeerimine teise masina kodukausta |

**Õigused**

| Käsk | Milleks |
|---|---|
| `chmod 0750 kaust` · `chmod 0640 fail` | õigused numbrina: omanik, grupp, teised |
| `chmod u+x skript.sh` | omanik saab skripti käivitada |
| `stat -c '%a %U %n' fail` | õigused, omanik ja nimi ühel real |
| `sudo käsk` | käsu käivitamine administraatori õigustega |

**SSH**

| Käsk | Milleks |
|---|---|
| `ssh web01` | sisselogimine masinasse nime järgi (nimi on failis `~/.ssh/config`) |
| `ssh web01 'cat automation-lab/training.conf'` | ühe käsu käivitamine teises masinas |
| `ssh-keygen -t ed25519` · `ssh-copy-id web01` | võtmepaari loomine · avaliku võtme lisamine masinasse |

**Bash**

| Muster | Milleks |
|---|---|
| `nimi="web01"` · `echo "$nimi"` | muutuja (võrdusmärgi ümber pole tühikuid) · muutuja väärtus jutumärkides |
| `printf '%s\n' 'rida 1' 'rida 2' > fail` | mitme rea kirjutamine faili |
| `grep enabled fail` · `grep -c '^Host ' ~/.ssh/config` | ridade otsimine · sobivate ridade arv |
| `if [ -f fail ]; then echo olemas; fi` | tingimus: kas fail on olemas |
| `käsk; echo $?` | eelmise käsu lõpetamise kood: `0` õnnestus, muu number tähendab viga |
| `bash -n skript.sh` · `bash skript.sh` | süntaksi kontroll · skripti käivitamine |

**Git**

| Käsk | Milleks |
|---|---|
| `git status` | mis on muutunud ja mis on commit'i jaoks valitud |
| `git add k01/` · `git commit -m "k01: …"` | failide valimine · commit'i tegemine |
| `git push` | commit'ide saatmine GitHubi |
| `git tag k01` · `git push origin k01` | tag'i loomine · tag'i saatmine GitHubi |
| `git log --oneline` | viimased commit'id |

</div>

Edasijõudnutele: [Linux ja Bash edasijõudnutele](spikker-edasijoudnutele.md) (veakäsitlus skriptides, systemd, logid, SELinux, võrgu diagnostika).
