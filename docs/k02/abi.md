---
tags:
  - Veaotsing
---

# Abi: levinud vead

| Mida näed | Põhjus | Mida teha |
|---|---|---|
| **Muutujad** | | |
| `VARIABLE IS NOT DEFINED!` | masin pole selles grupis või faili nimi ei klapi grupiga | `ansible-inventory --graph`; fail peab olema `group_vars/<grupp>.yml` |
| `'veeb_port' is undefined` playbook'is | muutuja pole selles masinas määratud | kontrolli `ansible <masin> -m ansible.builtin.debug -a "var=veeb_port"` |
| `We were unable to read either as JSON nor YAML` ja `{{` | `{{ ... }}` väärtus ilma jutumärkideta | `path: "{{ veeb_juur }}"` |
| **Tsükkel ja handler** | | |
| `'item' is undefined` | `loop:` on vale taandega või puudub | `loop:` on sama taandega nagu moodul |
| handler ei käivitu | ülesanne oli `ok` või `notify` nimi erineb handler'i nimest | nimi peab olema täpselt sama |
| `ERROR! The requested handler 'reload nginx' was not found` | handler puudub play'st või rollist | rollis: `roles/veeb/handlers/main.yml` |
| **nginx** | | |
| `curl` ei vasta | nginx ei tööta või port on vale | `ssh web01 "sudo nginx -t; systemctl status nginx"` |
| `a duplicate default server` | Ubuntu vaikesait on alles | `ls /etc/nginx/sites-enabled/` peab olema tühi |
| **Andmebaas ja kogud** | | |
| `couldn't resolve module/action 'ansible.mysql.mysql_db'` | kogu pole paigaldatud | `ansible-galaxy collection install -r requirements.yml` |
| `A MySQL module is required` | `python3-PyMySQL` puudub db01-s | paigalda see samas ülesandes kui `mariadb-server` |
| `unable to connect to database` | vale sokli tee või MariaDB ei tööta | `login_unix_socket: /var/lib/mysql/mysql.sock`, `systemctl status mariadb` |
| **Vault** | | |
| `Attempting to decrypt but no vault secrets found` | Vaulti parooli ei küsitud | lisa `--ask-vault-pass` |
| `Decryption failed` | vale Vaulti parool | proovi `ansible-vault view group_vars/andmebaas/vault.yml` |
| **Rollid** | | |
| `the role 'veeb' was not found` | kaust `roles/` pole `site.yml`-i kõrval | käivita käsk kaustas `~/kursus/k02` |
| `Could not find or access 'index.html.j2'` | mall pole rolli `templates/` kaustas | `roles/veeb/templates/index.html.j2` |

*Tabel 1. Levinud vead.*

1. kohtumise vead (SSH, `sudo`, YAML-i taane): [1. kohtumise abi](../k01/abi.md).

Ei leidnud lahendust? Kirjuta [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions) lehele ning lisa käsk ja kogu veateade tekstina.
