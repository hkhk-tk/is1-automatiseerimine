---
tags:
  - Ansible
  - Praktikum
---

# 6. Korduv käivitus ja esitamine

Labori seis töötab. Enne esitamist kontrollid kahte asja, mida automatiseerimisel töös vajad: kuidas muudatust enne rakendamist näha ja ühe masina peal proovida, ning kas kogu playbook on idempotentne.

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

## A3 · Korduv käivitus

Automaatne hindaja kontrollib, et kogu playbook on idempotentne. Selleks salvestad teise käivituse väljundi faili `run2.txt`.

**Ennusta:** mitu muudatust on nüüd kogu playbook'i käivitusel?

```bash
ansible-playbook site.yml | tee run2.txt
```

??? success "Oodatav tulemus"

    PLAY RECAP-is on kõigil viiel masinal `changed=0` ja `failed=0`. Kui mõnes masinas on `changed`, vaata väljundist, milline ülesanne muutis, paranda see ja salvesta `run2.txt` uuesti.

## A4 · Töö esitamine

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
