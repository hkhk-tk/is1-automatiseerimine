---
tags:
  - Ansible
  - Loeng
---

# Loeng: Labori seis rollidega

1. kohtumisel kirjutasid playbook'e, mis teevad viies masinas sama, ja panid distributsioonide erinevused grupimuutujatesse. Täna paigaldad viide masinasse rakenduse koos kõigi teenustega ja muudad ühe suure playbook'i rollidega projektiks.

??? abstract "Õpiväljundid"

    Pärast loengut ja praktikumi oskad:

    - leida playbook'i vea sammudega sümptom, hüpotees, tõend ja parandus;
    - jagada masinad inventory's teenuse ja distributsiooni gruppidesse ning valida muutujale õige taseme;
    - kirjutada Jinja2 malli ja taaskäivitada teenust handler'iga ainult muudatuse korral;
    - jagada playbook rollideks nii, et masinate olek ei muutu;
    - kasutada kogude mooduleid ja hoida paroole Vaultis;
    - kontrollida muudatust enne rakendamist (`--check --diff`, `--limit`, `serial`, `ansible-lint`).

## 1. Ühest failist projektiks

Rakendus Labori seis vajab viit teenust ja iga masin teeb erinevat tööd. Brauser saadab päringu web01-le, Nginx suunab selle app01-le ja rakendus kasutab andmebaasi, vahemälu ja sõnumijärjekorda.

<figure markdown="span">
  ![Labori seis viies masinas: web01 Nginx, app01 Tomcat, db01 MariaDB, mc01 Memcached, rmq01 RabbitMQ](assets/k02_stack.svg){ width="720" }
  <figcaption>Joonis 2.1. Labori seisu teenused viies masinas (Talvik, 2026).</figcaption>
</figure>

Kõik need teenused saab paigaldada ühe playbook'iga. Selline fail töötab, aga seda on raske muuta: väärtused ja paroolid on ülesannetes, sama tingimus kordub mitmes kohas ja ühe teenuse muutmiseks tuleb lugeda läbi kogu fail. Töökohas on see sage olukord, sest playbook kasvab koos süsteemiga.

**Refaktoreerimine** tähendab, et koodi ülesehitus muutub, aga tulemus jääb samaks. Ansible'is saab seda tõestada: kui uus projekt annab samades masinates `--check --diff` käivitusel ainult oodatud erinevused ja teisel käivitusel `changed=0`, on masinate olek sama.

??? question "Kontrolli ennast"

    1. Miks on ühe faili playbook'i viie teenuse puhul raske muuta?
    2. Kuidas tõestad, et ümberkirjutatud playbook ei muutnud masinate olekut?

## 2. Vigade otsimine

Playbook võib lõppeda vigadeta ja süsteem ikka mitte töötada. Viga leitakse samade sammudega nagu iga teine haldusviga: **sümptom** (mida näed), **hüpotees** (mis võib olla põhjus), **tõend** (käsk, mis hüpoteesi kinnitab või lükkab ümber), parandus ja kontroll. Hüpotees kirjutatakse üles enne tõendi otsimist, siis on näha, kas mõttekäik oli õige.

Teine sage viga on playbook, mis muudab masinat igal käivitusel. Moodulid `shell` ja `command` käivitavad käsu iga kord, sest need ei tea soovitud olekut. Rida `echo … >> /etc/hosts` lisab igal käivitusel faili uue rea ja `systemctl restart` katkestab teenuse ka siis, kui midagi ei muutunud. Selliste ülesannete asemel kasutatakse moodulit, mis kontrollib olekut (`blockinfile`, `lineinfile`, `template`), ja taaskäivitust handler'iga.

??? note "Tabel 2.1. Käsk ja moodul"

    | Käsk ülesandes | Moodul, mis kontrollib olekut |
    |---|---|
    | `echo "…" >> /etc/hosts` | `ansible.builtin.blockinfile` |
    | `sed -i 's/…/…/' fail` | `ansible.builtin.lineinfile` või `template` |
    | `systemctl restart teenus` igal käivitusel | handler, mida teavitab `notify` |
    | `mysql -e "CREATE USER …"` | `community.mysql.mysql_user` |

??? question "Kontrolli ennast"

    1. Playbook lõppes `failed=0`, aga rakendus ei tööta. Mis on järgmine samm?
    2. Miks annab `command` ülesanne igal käivitusel `changed`?

## 3. Grupid ja muutujad

1. kohtumise inventory's olid grupid distributsiooni järgi. Labori seisus lisanduvad grupid teenuse järgi ja distributsioonigrupid koostatakse nendest. Järelliide `:children` tähendab, et grupi liikmed on teised grupid. Teenusegrupp määrab, mida masinas teha, distributsioonigrupp hoiab grupimuutujaid, mis ütlevad, kuidas.

```ini
[web]
web01 ansible_host=<web01-IP>

[db]
db01 ansible_host=<db01-IP>

[alma:children]
cache
db
```

Muutuja `ansible_host` on masina IP-aadress. Kui see on inventory's, on aadress kirjas ainult ühes kohas ja mallid saavad seda kasutada.

<figure markdown="span">
  ![Inventory: grupid teenuse ja distributsiooni järgi](assets/k02_inventory.svg){ width="720" }
  <figcaption>Joonis 2.2. Iga masin on teenuse grupis ja distributsiooni grupis (Talvik, 2026).</figcaption>
</figure>

Muutujad on kaustades `group_vars` ja `host_vars`. Grupi muutujad võivad olla ühes failis või kaustas, kus on mitu faili: kausta kuju `group_vars/all/` on vajalik, kui osa muutujaid on krüpteeritud. Kui sama muutuja on mitmes kohas, kehtib täpsem väärtus.

??? note "Tabel 2.2. Milline väärtus kehtib (nõrgemast tugevamani)"

    | Koht | Näide selles projektis |
    |---|---|
    | rolli `defaults/main.yml` | `tomcat_heap: 256m` |
    | `group_vars/all/` | `labseis_db_name: labseis` |
    | `group_vars/<grupp>.yml` | `group_vars/app.yml`: `tomcat_heap: 512m` |
    | `host_vars/<masin>.yml` | `host_vars/web01.yml`: `nginx_upstream: app01:8080` |
    | käsurea `-e` | `-e tomcat_heap=1g` |

    Kogu järjekord on lehel [Variable precedence](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence). Ühe masina muutujaid näitab `ansible-inventory --host app01`.

Teiste masinate andmetele pääseb ligi muutujatega `groups` ja `hostvars`. Rakenduse seadetes on andmebaasi aadress `{{ groups['db'][0] }}`, st grupi `db` esimene masin. Kui andmebaas kolib teise masinasse, muudetakse ainult inventory't.

??? question "Kontrolli ennast"

    1. Kas mc01 on grupis `alma`, kui inventory's on `[alma:children]` all `cache`?
    2. Rolli vaikeväärtus on 256m ja `group_vars/app.yml`-is 512m. Mis väärtuse saab app01?

## 4. Mallid ja handler'id

Moodul `copy` kopeerib teksti muutmata kujul. Moodul `template` töötleb faili enne kopeerimist Jinja2-ga: `{{ muutuja }}` asendatakse väärtusega, `{% for %}` ja `{% if %}` kordavad või valivad ridu. Mallid on rolli kaustas `templates/` ja nende laiend on `.j2`. Rida `{{ ansible_managed }}` lisab faili algusesse märkuse, et faili haldab Ansible ja käsitsi tehtud muudatused kirjutatakse üle.

```jinja
{% for h in groups['all'] | sort %}
{{ hostvars[h].ansible_host }} {{ h }}
{% endfor %}
```

Filter `sort` hoiab masinate järjekorra alati samana. Ilma selleta võib järjekord muutuda ja fail oleks iga kord `changed`.

**Handler** on ülesanne, mis käivitub play lõpus ainult siis, kui mõni teine ülesanne teavitas teda võtmega `notify` ja tegi muudatuse. Handler käivitub üks kord, isegi kui teda teavitas mitu ülesannet. Kui teenus peab enne järgmisi ülesandeid uue seadistusega töötama, käivitab `ansible.builtin.meta: flush_handlers` ootel handler'id kohe.

```yaml
- name: Labori seisu sait on seadistatud
  ansible.builtin.template:
    src: labori-seis.conf.j2
    dest: /etc/nginx/sites-available/labori-seis
    mode: "0644"
  notify: Reload nginx
```

<figure markdown="span">
  ![Moodul võrdleb soovitud olekut tegeliku olekuga ja muudab ainult erinevuse](assets/k02_idempotentsus.svg){ width="720" }
  <figcaption>Joonis 2.3. Kui fail ei muutu, ei käivitu ka handler (Talvik, 2026).</figcaption>
</figure>

??? question "Kontrolli ennast"

    1. Kolm ülesannet teavitavad sama handler'it ja kaks neist on `changed`. Mitu korda handler käivitub?
    2. Miks tuleb teenuse seadistus enne andmebaasi loomist rakendada (`flush_handlers`)?

## 5. Rollid

**Roll** on kindla ülesehitusega kaust ühe teenuse jaoks. Ansible leiab failid nime järgi, neid ei pea playbook'is eraldi nimetama. Fail `site.yml` määrab ainult, milline roll millises grupis käivitub.

```text
roles/nginx/
├── defaults/main.yml     vaikeväärtused, mida võib üle kirjutada
├── handlers/main.yml     handler'id
├── tasks/main.yml        ülesanded
└── templates/            mallid
```

Playde järjekord `site.yml`-is on oluline: andmebaas, vahemälu ja sõnumijärjekord paigaldatakse enne rakendust, sest rakendus ühendub käivitumisel nende kõigiga. `defaults` on kõige nõrgemad ja mõeldud ülekirjutamiseks, `vars` on tugevamad kui `group_vars` ning sobivad väärtustele, mida rolli kasutaja ei peaks muutma. Kogu projekti kaustastruktuur järgib dokumentatsiooni soovitust [Sample Ansible setup](https://docs.ansible.com/projects/ansible/latest/tips_tricks/sample_setup.html).

Rolli `mariadb` vaikeväärtused on AlmaLinuxi omad, sest andmebaas on db01-s. Kui sama rolli on vaja Ubuntu masinas, ei muudeta rolli, vaid kirjutatakse väärtused üle failis `group_vars/ubuntu.yml`. Tingimus `when` jääb ülesandele, mida ühes distributsioonis on vaja ja teises ei ole, näiteks tulemüür `firewalld` AlmaLinuxis.

Valmis rolle jagatakse [Ansible Galaxys](https://galaxy.ansible.com/). Enne valmis rolli kasutamist vaata, millal seda viimati uuendati, milliseid distributsioone see toetab, kas sellel on testid ja millise litsentsiga see on. Roll käivitub `become: true` õigustes, nii et see on võõras kood sinu serverites. Kasutatava rolli versioon pannakse kirja faili `requirements.yml`.

??? question "Kontrolli ennast"

    1. Miks peab andmebaasi play olema `site.yml`-is enne rakendusserveri play'd?
    2. Mida kontrollid enne, kui kasutad Galaxy rolli tootmises?

## 6. Kogud ja Vault

Moodulid `apt`, `template` ja `service` kuuluvad kogusse `ansible.builtin`, mis on `ansible-core`'iga kaasas. Andmebaasi, RabbitMQ ja tulemüüri moodulid on eraldi kogudes. Mooduli täisnimi näitab kogu: `community.mysql.mysql_user` on moodul `mysql_user` kogust `community.mysql`. Kogud ja nende versioonid on failis `requirements.yml` ja `ansible-galaxy collection install -r requirements.yml` paigaldab need. Versioon on kinni, et sama projekt töötaks kuu aja pärast samamoodi.

??? note "Tabel 2.3. Kogud selles projektis"

    | Kogu | Moodul | Kasutus |
    |---|---|---|
    | `community.mysql` | `mysql_db`, `mysql_user` | andmebaas `labseis` ja selle kasutaja |
    | `community.rabbitmq` | `rabbitmq_user` | järjekorra kasutaja |
    | `ansible.posix` | `firewalld` | AlmaLinuxi tulemüüri pordid |

Paroolid peavad olema repositooriumis, sest playbook vajab neid. Avatekstina ei tohi neid sinna panna: kõik, kellel on ligipääs repositooriumile või selle koopiale, näeksid neid. **Ansible Vault** krüpteerib terve faili ja Ansible avab selle käivitamisel. Paroolid on kahes failis: krüpteeritud `vault.yml`, kus on ainult eesliitega `vault_` väärtused, ja loetav `main.yml`, mis viitab neile (`labseis_db_password: "{{ vault_db_password }}"`).

<figure markdown="span">
  ![Vault: krüpteeritud väärtus, avatekstis viide ja kasutus mallis](assets/k02_vault_vahekiht.svg){ width="720" }
  <figcaption>Joonis 2.4. Saladus krüpteeritud failis, viide loetavas failis, kasutus mallis (Talvik, 2026).</figcaption>
</figure>

Vaulti parool on control node'is failis `~/.config/is1/vault_pass` (`chmod 600`) ja `ansible.cfg` rida `vault_password_file` ütleb, kust see võtta. Fail on väljaspool repositooriumi. Ülesanne võtmesõnaga `no_log: true` peidab väljundi, et parool ei jõuaks logisse.

??? question "Kontrolli ennast"

    1. Miks on viide `labseis_db_password` loetavas failis, kui väärtus on krüpteeritud failis?
    2. Kus on Vaulti parool ja miks mitte repositooriumis?

## 7. Kontrollitud muudatus

Viie masinaga projektis võib üks vigane mall peatada teenuse kõigis grupi masinates korraga. Seepärast vaadatakse muudatus enne rakendamist üle ja rakendatakse see kõigepealt ühes masinas.

??? note "Tabel 2.4. Muudatuse kontroll"

    | Võti või võtmesõna | Tulemus |
    |---|---|
    | `--check --diff` | näitab, mis failides muutuks, midagi muutmata |
    | `--limit app01` | rakendab muudatuse ainult valitud masinates |
    | `serial: 2` | play töötleb korraga kahte masinat; vea korral ülejäänuid ei puudutata |
    | `--syntax-check` | leiab vigase YAML-i ja tundmatud võtmed |
    | `ansible-lint` | kontrollib häid tavasid: täisnimed, `mode`, `changed_when` |

Vaikimisi täidab Ansible iga ülesande kõigis play masinates ja liigub seejärel järgmise juurde. `serial` täidab play kõigepealt esimeses masinate rühmas ja alles siis järgmises, väljundis on sama play päis iga rühma kohta. [ansible-lint](https://docs.ansible.com/projects/lint/) leiab vead, mida süntaksikontroll ei leia, ja automaatne hindaja kasutab sama tööriista.

??? question "Kontrolli ennast"

    1. Viie masinaga play'l on `serial: 2`. Mitu korda on väljundis play päis?
    2. Miks käivitatakse muudatus enne kõiki masinaid `--limit`'iga ühes masinas?

??? abstract "Kokkuvõte"

    | Mõiste | Lühidalt |
    |---|---|
    | refaktoreerimine | ülesehitus muutub, olek mitte; tõend on `--check --diff` ja `changed=0` |
    | sümptom, hüpotees, tõend | vigade otsimise sammud, hüpotees enne tõendit |
    | `:children` | grupp, mille liikmed on teised grupid |
    | `group_vars`, `host_vars`, `defaults` | muutujate tasemed, täpsem väärtus kehtib |
    | mall | Jinja2 fail, millest Ansible teeb igale masinale oma faili |
    | handler | käivitub ainult muudatuse korral, üks kord |
    | roll | ühe teenuse ülesanded, mallid ja vaikeväärtused ühes kaustas |
    | kogu | moodulite pakett, versioon failis `requirements.yml` |
    | Vault | krüpteeritud saladused Gitis, parool väljaspool repositooriumi |
