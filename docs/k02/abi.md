---
tags:
  - Veaotsing
---

# Abi: levinud vead

Iga rida on üles ehitatud samamoodi: mida näed, mis on tõenäoline põhjus ja millise käsuga seda kontrollida. 1. kohtumise vead (SSH, `sudo`, YAML-i taane) on [1. kohtumise abilehel](../k01/abi.md).

??? note "Tabel 2.5. Inventory ja muutujad"

    | Mida näed | Põhjus | Mida teha |
    |---|---|---|
    | `VARIABLE IS NOT DEFINED!` | masin pole selles grupis või faili nimi ei klapi grupiga | `ansible-inventory --graph`; fail peab olema `group_vars/<grupp>.yml` |
    | `We were unable to read either as JSON nor YAML` ja `{{` | `{{ ... }}` väärtus ilma jutumärkideta | `password: "{{ vault_db_password }}"` |
    | `'dict object' has no attribute 'ansible_default_ipv4'` | `--limit` korral pole teiste masinate fakte | kasuta inventory muutujat `ansible_host` või käivita ilma `--limit`'ita |

??? note "Tabel 2.6. Handler'id ja korduv käivitus"

    | Mida näed | Põhjus | Mida teha |
    |---|---|---|
    | handler ei käivitu | ülesanne oli `ok` või `notify` nimi erineb handler'i nimest | nimi peab olema täpselt sama |
    | `The requested handler ... was not found` | handler puudub rolli failist `handlers/main.yml` | kontrolli faili teed ja nime |
    | teine käivitus annab `changed` | mõni ülesanne muudab igal käivitusel olekut | vaata väljundist, milline ülesanne; `shell` ja `command` asemel moodul, mallis `sort` |

??? note "Tabel 2.7. Kogud ja Vault"

    | Mida näed | Põhjus | Mida teha |
    |---|---|---|
    | `couldn't resolve module/action 'community.mysql.mysql_db'` | kogu pole paigaldatud | `ansible-galaxy collection install -r requirements.yml` |
    | `A MySQL module is required` | `python3-PyMySQL` puudub db01-s | see on rolli `mariadb` esimeses ülesandes |
    | `Attempting to decrypt but no vault secrets found` | Vaulti parooli fail puudub | `ls -l ~/.config/is1/vault_pass`, rida `vault_password_file` failis `ansible.cfg` |
    | `Decryption failed` | vale Vaulti parool | kontrolli faili `~/.config/is1/vault_pass` sisu |

??? note "Tabel 2.8. Teenused"

    | Mida näed | Põhjus | Mida teha |
    |---|---|---|
    | `/health` näitab `"db":"DOWN"` | rakendus ei saa andmebaasiga ühendust | `ssh db01 sudo ss -tln \| grep 3306`, `ssh db01 sudo firewall-cmd --list-ports`, `ssh app01 getent hosts db01` |
    | `/health` näitab `"cache":"DOWN"` | rakendus ei saa vahemäluga ühendust | `ssh mc01 sudo ss -tln \| grep 11211`, `ssh mc01 sudo firewall-cmd --list-ports` |
    | `/health` näitab `"queue":"DOWN"` | RabbitMQ kasutaja või parool ei klapi | `ssh rmq01 sudo rabbitmqctl list_users` |
    | `Rakendus vastab app01-s` ebaõnnestub 40 korduse järel | rakendus ei käivitunud | `ssh app01 sudo journalctl -u tomcat10 -n 50 --no-pager` |
    | web01 annab 502 | Tomcat ei tööta või `nginx_upstream` on vale | `ssh app01 curl -s localhost:8080/health/live`, `host_vars/web01.yml` |

Ei leidnud lahendust? Kirjuta [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehele ning lisa käsk ja kogu veateade tekstina.
