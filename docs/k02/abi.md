---
tags:
  - Veaotsing
---

# Abi: levinud vead

| Mida näed | Põhjus | Mida teha |
|---|---|---|
| **Inventory ja muutujad** | | |
| `VARIABLE IS NOT DEFINED!` | masin pole selles grupis või faili nimi ei klapi grupiga | `ansible-inventory --graph`; fail peab olema `group_vars/<grupp>.yml` |
| `We were unable to read either as JSON nor YAML` ja `{{` | `{{ ... }}` väärtus ilma jutumärkideta | `password: "{{ vault_db_password }}"` |
| **Handler** | | |
| handler ei käivitu | ülesanne oli `ok` või `notify` nimi erineb handler'i nimest | nimi peab olema täpselt sama |
| `The requested handler ... was not found` | handler puudub rolli failist `handlers/main.yml` | kontrolli faili teed ja nime |
| **Kogud ja Vault** | | |
| `couldn't resolve module/action 'community.mysql.mysql_db'` | kogu pole paigaldatud | `ansible-galaxy collection install -r requirements.yml` |
| `A MySQL module is required` | `python3-PyMySQL` puudub db01-s | see on rolli `mariadb` esimeses ülesandes |
| `Attempting to decrypt but no vault secrets found` | Vaulti parooli fail puudub | `ls -l ~/.config/is1/vault_pass`, rida `vault_password_file` failis `ansible.cfg` |
| `Decryption failed` | vale Vaulti parool | kontrolli faili `~/.config/is1/vault_pass` sisu |
| **Teenused** | | |
| `/health` näitab `"db":"DOWN"` | rakendus ei saa andmebaasiga ühendust | `ssh db01 ss -tln \| grep 3306`, tulemüür, `ssh app01 getent hosts db01` |
| `/health` näitab `"cache":"DOWN"` | Memcached kuulab ainult kohalikke ühendusi | `ssh mc01 ss -tln \| grep 11211` peab näitama `0.0.0.0` |
| `/health` näitab `"queue":"DOWN"` | RabbitMQ kasutaja või parool ei klapi | `ssh rmq01 sudo rabbitmqctl list_users` |
| `Rakendus vastab app01-s` ebaõnnestub 40 korduse järel | rakendus ei käivitunud | `ssh app01 sudo journalctl -u tomcat10 -n 50` |
| `HTTP Error 404` WAR-i allalaadimisel | WAR-i aadress on vale | `tomcat_war_url` failis `roles/tomcat/defaults/main.yml` |
| web01 annab 502 | Tomcat ei tööta või `nginx_upstream` on vale | `ssh app01 curl -s localhost:8080/health/live`, `host_vars/web01.yml` |
| **Korduv käivitus** | | |
| teine käivitus annab `changed` | mõni ülesanne muudab igal käivitusel olekut | vaata väljundist, milline ülesanne; mallis kasuta `sort` ja muutujates püsivaid väärtusi |

*Tabel 1. Levinud vead.*

1. kohtumise vead (SSH, `sudo`, YAML-i taane): [1. kohtumise abi](../k01/abi.md).

Ei leidnud lahendust? Kirjuta [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehele ning lisa käsk ja kogu veateade tekstina.
