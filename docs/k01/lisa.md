---
tags:
  - Ansible
  - Lisaülesanne
---

# 1. kohtumine · Lisaülesanded

Need ülesanded on mõeldud neile, kes on praktikumi lõpetanud ja kellel jääb aega üle. Kõik käsud käivitad control node'is kaustas `~/kursus/k01`.

## L1 · Kasutaja kõigis masinates

Lisa uus playbook `users.yml`, mis loob kõigis viies masinas kasutaja `kolleeg` kodukaustaga ja shelliga `/bin/bash`. Kasutaja loomiseks on vaja administraatori õigusi.

??? tip "Vihje"

    Kasuta moodulit `ansible.builtin.user`. Mooduli parameetrid näed käsuga `ansible-doc ansible.builtin.user`. Näited on dokumentatsiooni lõpus jaotises `EXAMPLES`.

```bash
ansible-playbook users.yml
ansible all -m ansible.builtin.command -a "id kolleeg"
```

??? success "Oodatav tulemus"

    Esimesel käivitusel on kõigi viie masina olek `changed`, teisel käivitusel on kokkuvõttes `changed=0`. Käsk `id kolleeg` annab vastuse igast masinast.

## L2 · ansible-lint

`--syntax-check` kontrollib ainult, kas faili saab lugeda. `ansible-lint` kontrollib playbook'e ka levinud vigade ja soovitatud stiilireeglite suhtes, enne kui playbook masinaid muudab. Paigalda see control node'i ja kontrolli oma playbook'e:

```bash
sudo apt install -y ansible-lint
ansible-lint training.yml tools.yml
```

Paranda vähemalt üks leitud märkus ja käivita kontroll uuesti.

## L3 · Failide kopeerimine hallatavatest masinatest

Moodul `ansible.builtin.fetch` kopeerib faili hallatavast masinast control node'i. Kopeeri kõigist viiest masinast fail `/etc/os-release` kausta `~/kursus/k01/os/`.

??? tip "Vihje"

    ```bash
    ansible all -m ansible.builtin.fetch -a "src=/etc/os-release dest=os/"
    ```

    Vaata käsuga `find os -type f`, millise kaustastruktuuri `fetch` lõi.

`fetch` sobib näiteks konfiguratsioonifailide, logide või muu kontrollimiseks vajaliku info kogumiseks hallatavatest masinatest.
