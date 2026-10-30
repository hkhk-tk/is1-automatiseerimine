---
tags:
  - Ansible
  - Praktikum
---

# 7. Iseseisev ülesanne ja töö esitamine

Viimases osas kirjutad ilma valmis näiteta ühe ülesande olemasolevasse playbook'i ja ühe uue playbook'i. Seejärel esitad päeva töö.

## A1 · Ülesanne olemasolevas playbook'is

Lisa playbook'i `training.yml` kolmas ülesanne: kaustas `automation-lab` peab olema fail `README.txt` õigustega `0644` ja sisuga:

```text
Seda kausta haldab Ansible. Ära muuda käsitsi.
```

Sobiva mooduli ja parameetrid leiad playbook'i teisest ülesandest.

**Ennusta:** mis on esimese ja mis teise käivituse kokkuvõttes `changed`?

```bash
ansible-playbook training.yml
ansible-playbook training.yml
ssh web01 "cat automation-lab/README.txt; stat -c '%a %n' automation-lab/README.txt"
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on uus ülesanne `changed`, kaks varasemat `ok`. Teisel käivitusel on kokkuvõttes `changed=0`. Failis on üks rida ja õigused on `644`.

??? tip "Vihje"

    Kopeeri `ansible.builtin.copy` ülesanne ja muuda väärtusi `name`, `dest`, `content` ja `mode`.

## A2 · Uus playbook: aja sünkroniseerimine

Kirjuta playbook `ajasunk.yml`, mis paigaldab kõigisse viide masinasse paketi `chrony` ja hoiab selle teenuse käigus. Teenus peab käivituma ka pärast alglaadimist. Paketi nimi on mõlemas distributsioonis `chrony`, teenuse nimi on Ubuntus `chrony` ja AlmaLinuxis `chronyd`.

Kasuta 6. osa lahendust: distributsioonide erinevus läheb grupimuutujatesse, mitte võtmesse `when`. Enne käivitamist kontrolli playbook'i võtmetega `--check --diff`.

```bash
ansible-playbook ajasunk.yml
ansible-playbook ajasunk.yml
ansible all -a "chronyc tracking"
```

??? success "Oodatav tulemus"

    Teisel käivitusel on kõigis masinates `changed=0`. `chronyc tracking` näitab igas masinas aja allikat ja rida `Leap status     : Normal`. Ubuntus asendab chrony paketi `systemd-timesyncd`, see on ootuspärane.

## A3 · Töö esitamine

Töö esitatakse tag'iga `k01`. Tee muudatustest commit, saada see GitHubi ja lisa tag:

```bash
cd ~/kursus
git add k01/
git commit -m "k01: README.txt ja ajasunk.yml"
git push
git tag k01
git push origin k01
```

Automaatne hindaja kontrollib tag'iga märgitud versiooni ja tulemus ilmub mõne minuti pärast [Classroom 50](https://classroom50.org/hkhk-tk/is126-automatiseerimine/assignments) lehele. Kohustuslik osa annab 80 punkti, `when` ja `tags` failis `tools.yml` ning `README.txt` kumbki 10 boonuspunkti.

Kui hindaja leiab vea, paranda see, tee uus commit ja saada tag uuesti: `git tag -f k01 && git push -f origin k01`.

Edasi: [Kodutöö](kodutoo.md).
