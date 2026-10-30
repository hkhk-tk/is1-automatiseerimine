---
tags:
  - Ansible
  - Praktikum
---

# 6. Korduv käivitus ja esitamine

Labori seis töötab. Enne esitamist kontrollid kolme asja, mida automatiseerimisel töös vajad: kuidas muudatust enne rakendamist näha ja masinate kaupa rakendada, kuidas playbook vea korral ise põhjust otsib ja kas kogu playbook on idempotentne.

!!! abstract "Dokumentatsioonis"

    [Check mode and diff mode](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_checkmode.html) · [Strategies (`serial`)](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_strategies.html)  · [Error handling](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html) · [Blocks](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_blocks.html) · [Delegation](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_delegation.html)

## A1 · Muudatus enne rakendamist

Muuda failis `roles/common/defaults/main.yml` teate teksti, näiteks lisa lõppu ` Küsimused: IT-tugi.`. Vaata enne käivitamist, mida Ansible ühes masinas muudaks:

```bash
ansible-playbook site.yml --check --diff --limit web01
```

Väljundis on teate vana ja uus rida ning masinas ei muutu midagi. Rakenda muudatus kõigepealt ühes masinas ja seejärel kõigis:

```bash
ansible-playbook site.yml --limit web01
ansible-playbook site.yml
```

## A2 · Masinate kaupa: `serial`

Kui sama muudatus läheb korraga kõigisse masinatesse ja on vigane, on korraga katki kõik. Võti `serial` käivitab play masinate kaupa: kõigepealt mõni masin ja alles siis järgmised. Kui esimeses osas tuleb viga, ülejäänud masinaid ei puudutata.

Lisa `site.yml`-i esimesse play'sse rida `serial: 2`:

```yaml
- name: Kõik masinad
  hosts: all
  become: true
  serial: 2
  roles:
    - common
```

**Ennusta:** mitu korda on väljundis rida `PLAY [Kõik masinad]`?

```bash
ansible-playbook site.yml
```

??? success "Oodatav tulemus"

    Kolm korda: kaks masinat, kaks masinat ja üks masin.

## A3 · Kui midagi läheb valesti: `block` ja `rescue`

Praegu ütleb viimane play vea korral ainult, et `/health` ei vastanud. Põhjus on aga tavaliselt app01 Tomcati logis. Teeme kontrolli nii, et vea korral loeb Ansible ise rakendusserveri logi ja näitab seda.

Asenda `site.yml`-i viimane play järgmisega:

```yaml
- name: Labori seis vastab
  hosts: web
  gather_facts: false
  vars:
    health_retries: 30
  tasks:
    - name: Kontroll, vea korral rakendusserveri logi
      block:
        - name: Rakendus vastab web01 kaudu
          ansible.builtin.uri:
            url: http://localhost/health
            return_content: true
          register: health
          until: health.status == 200
          retries: "{{ health_retries }}"
          delay: 5
          failed_when: health.status != 200 or 'DOWN' in (health.content | default(''))
      rescue:
        - name: Tomcati logi app01-st
          ansible.builtin.command: journalctl -u tomcat10 -n 20 --no-pager
          delegate_to: "{{ groups['app'][0] }}"
          become: true
          register: tomcat_logi
          changed_when: false

        - name: Logi viimased read
          ansible.builtin.debug:
            var: tomcat_logi.stdout_lines

        - name: Labori seis ei vasta
          ansible.builtin.fail:
            msg: "Labori seis ei vasta web01 kaudu. Põhjus on tõenäoliselt ülal Tomcati logis."
```

| Võti | Mida teeb |
|---|---|
| `block` / `rescue` | kui mõni `block`-i ülesanne ebaõnnestub, käivituvad `rescue` ülesanded (nagu `try` / `catch`) |
| `register` | salvestab mooduli tagastatud väärtused muutujasse; `health.status` ja `health.content` on mooduli `uri` [tagastusväärtused](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/uri_module.html#return-values) |
| `failed_when` | ise määratud veatingimus: HTTP 200 ei piisa, vastuses ei tohi olla `DOWN` |
| `changed_when: false` | `command` ei tea, kas ta muutis midagi, ja teataks alati `changed`. Logi lugemine ei muuda midagi |
| `delegate_to` | play käib web01-s, aga see ülesanne käivitatakse app01-s |

*Tabel 1. Vigade käsitlemise võtmed.*

Proovi viga järele. Peata Tomcat ja käivita playbook ainult web01-s. `-e health_retries=2` lühendab ootamist:

```bash
ssh app01 sudo systemctl stop tomcat10
ansible-playbook site.yml --limit web01 -e health_retries=2
```

**Ennusta:** mis on PLAY RECAP-is väljade `failed` ja `rescued` väärtus?

??? success "Oodatav tulemus"

    Ülesanne `Rakendus vastab web01 kaudu` ebaõnnestub koodiga 502, seejärel käivituvad `rescue` ülesanded. Logis on rida `Stopped tomcat10.service` ja viimane teade on `Labori seis ei vasta web01 kaudu`. Kokkuvõttes on `failed=1` ja `rescued=1`.

Taasta Tomcat playbook'iga, mitte käsitsi:

```bash
ansible-playbook site.yml --limit app01
```

## A4 · Korduv käivitus

Automaatne hindaja kontrollib, et kogu playbook on idempotentne. Selleks salvestad teise käivituse väljundi faili `run2.txt`.

**Ennusta:** mitu muudatust on nüüd kogu playbook'i käivitusel?

```bash
ansible-playbook site.yml | tee run2.txt
```

??? success "Oodatav tulemus"

    PLAY RECAP-is on kõigil viiel masinal `changed=0` ja `failed=0`. Kui mõnes masinas on `changed`, vaata väljundist, milline ülesanne muutis, paranda see ja salvesta `run2.txt` uuesti.

## A5 · Töö esitamine

Salvesta viimased muudatused ja saada need GitHubi:

```bash
cd ~/kursus
git add -A
git commit -m "k02: serial ja run2.txt"
git push
```

Ava GitHubis oma repositoorium ja tee pull request harust `k02-ansible` harusse `main` (**Compare & pull request**). Vaata muudatused üle ja ühenda (**Merge pull request**). Pärast ühendamist lisa tag:

```bash
git switch main
git pull
git tag k02
git push origin k02
```

Töö esitatakse tag'iga `k02`. Automaatne hindaja kontrollib tag'iga märgitud versiooni: failid ja rollid, inventory, mallid ja handlerid, Vault, `run2.txt`, süntaks ja `ansible-lint`. Tulemus ilmub [Classroom 50](https://classroom50.org/hkhk-tk/is126-automatiseerimine/assignments) lehele.

Kui hindaja leiab vea, paranda see harus `main`, tee commit ja saada tag uuesti: `git tag -f k02 && git push -f origin k02`.

**Valmis, kui** pull request on ühendatud ja tag `k02` on GitHubis.

Edasi: [Kodutöö](kodutoo.md).
