---
tags:
  - Ansible
  - Praktikum
---

# 2. kohtumine · Praktikum

1. kohtumisel kirjutasid playbook'e, mis teevad kõigis masinates sama, ja panid distributsioonide erinevused grupimuutujatesse. Täna paigaldad Ansible'iga kogu Labori seisu: viis teenust viies masinas. Igal teenusel on oma **roll** ja ehitad need ükshaaval, alates andmebaasist. Kaks rolli (Memcached ja Nginx) kirjutad nõuete järgi ise. Iga osa lõpus kontrollid, kas teenus töötab, enne kui järgmise juurde lähed.

!!! info "Selle korra töö"

    - **Masinad:** control node ja viis labori VM-i, kasutaja `kasutaja`
    - **Failid:** kaust `~/kursus/k02-ansible/`, haru `k02-ansible`
    - **Esitamine:** pull request harusse `main`, merge ja tag `k02`
    - **Ülesanded:** issue `K2` sinu repositooriumis, märkeruut iga osa kohta
    - **Edenemine:** [laboritahvel](http://192.168.125.187:8093) (VPN-iga)

Kui juhendis on **Ennusta:**, ütle vastus enne käsu käivitamist naabrile või mõtle see läbi. Seejärel käivita käsk ja võrdle tulemust oma ennustusega. Kui need erinevad, uuri, miks.

![Labori seis viies masinas: web01 Nginx, app01 Tomcat, db01 MariaDB, mc01 Memcached, rmq01 RabbitMQ](assets/k02_stack.svg){ width="720" }

*Joonis 1. Labori seis: brauser → web01 (Nginx) → app01 (Tomcat), mis kasutab andmebaasi, vahemälu ja sõnumijärjekorda.*

| Osa | Mida teed | Valmis, kui |
|---|---|---|
| [1. Projekt ja inventory](lab-1-projekt.md) | haru, inventory gruppidega, muutujad | kõik viis masinat vastavad `pong` |
| [2. Esimene roll](lab-2-common.md) | roll `common`: masinad tunnevad üksteist nime järgi | `ssh app01 getent hosts db01` vastab |
| [3. Andmebaas](lab-3-andmebaas.md) | kogu, Vault, mall ja handler | andmebaasis on tabelid ja algandmed |
| [4. Vahemälu ja järjekord](lab-4-vahemalu-jarjekord.md) | roll `memcached` ise, RabbitMQ | mõlemad kuulavad oma porti |
| [5. Rakendus ja veebiserver](lab-5-rakendus.md) | Tomcat ja rakendus, roll `nginx` ise | `/health` vastab web01 kaudu `UP` |
| [6. Korduv käivitus ja esitamine](lab-6-esitamine.md) | `--check --diff`, `serial`, `run2.txt`, pull request | tag `k02` on GitHubis |

*Tabel 1. Praktikumi osad.*

Vajad abi? [Abi](abi.md) · [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions)

Jäi aega üle? [Lisaülesanded](lisa.md)
