---
tags:
  - Bash
  - Ansible
  - systemd
  - Proxmox
---

# 1. kohtumine, labor: Bash nagu tootmises, siis sama Ansible'iga

!!! info "Selle korra töö"
    - **Masin:** control node, repo `~/labori-seis`, töökaustad `k01-bash/` ja Ansible'i osast alates `k02-ansible/`, märkmed `k01-bash/NOTES.md`
    - **Sihtmasinad:** web01, app01, rmq01 (Ubuntu 24.04), mc01, db01 (Rocky 9), kasutaja `kasutaja`, VPN
    - **Esitamine:** haru `k01-bash` → PR → merge → tag `k01`
    - **Vaja koolitajalt:** VPN, control node'i aadress, VM-ide IP-d, `LABSEIS_TOKEN`; tahvlilt `TEMPLATE_URL`, `TOMCAT_URL` ja uue WAR-i URL
    - **Testitud:** Ubuntu 24.04, Rocky 9, ansible-core 2.21, ansible-lint 26.9, Tomcat 10.1 + OpenJDK 21; Bash, Git, ShellCheck ja cloud-init kursuse VM-i versioon; PHP 8.3 (lisaülesanne 4); MariaDB, Memcached, RabbitMQ, Nginx ja Apache distributsiooni paketist; Proxmox VE kursuse keskkonna versioon
    - **Dokumentatsioon:** [Bash](https://www.gnu.org/software/bash/manual/) · [ShellCheck](https://www.shellcheck.net/wiki/) · [Git](https://git-scm.com/docs) · [cloud-init](https://cloudinit.readthedocs.io/) · [Proxmox VE](https://pve.proxmox.com/pve-docs/) · [Ansible](https://docs.ansible.com/ansible/latest/)

Kohtumise lõpuks paigaldab üks käsk viis teenust viiele VM-ile õiges järjekorras ja ootab iga kihi järel, kuni teenus vastab. Skriptid on idempotentsed, logivad journald-isse ja läbivad ShellChecki, saladused on Gitist ja `ps`-ist väljas. Sama veebimalli paigaldus on ka Ansible'i playbook'ina, mille teine käivitus annab `changed=0`, ja control node'i systemd timer kontrollib stacki iga viie minuti järel.

Kui jätad etappe vahele rea **Kui teed seda tööl iga päev** järgi, kirjuta `NOTES.md`-sse kontrollkäsk ja selle väljund.

Lõpeta iga moodul commit'iga. Kui moodulil on GitHubis issue (milestone `K1`), lisa sõnumisse `closes #N`. Kirjuta `NOTES.md`-sse lisaks käskudele ka see, mida väljund näitas.

## Mis on kohustuslik

| Osa | Mis | Millal |
|---|---|---|
| Kohtumise ajal | [Keskkond](lab-1-keskkond.md), [websetup.sh nagu tootmises](lab-2-websetup.md), [Üks käsk, mitu hosti](lab-3-mitu-hosti.md), [Viis teenust](lab-4-viis-teenust.md), [Kolm viga](lab-5-kolm-viga.md) | laboris 11:30–15:00 |
| Võib lõpetada pärast kohtumist | [Sama töö Ansible'iga](lab-6-ansible.md), [Operatsioon](lab-7-operatsioon.md), [Git meeskonnas](lab-8-git-meeskonnas.md); `NOTES.md` vastused; [Esitamise](lab-9-esitamine.md) kontrollid uuesti pärast viimast commit'i | enne järgmist kohtumist: 2. kohtumine algab `k02-ansible/` kolmest failist, mille teed lehel Sama töö Ansible'iga |
| Hindamise eeltingimus | tag `k01` `main`-i commit'il pärast merge'i ja GitHubis näha (`git ls-remote --tags origin`); automaatse hindaja 1. kohtumise kontrollid (`autograde/TESTS.md`) on ka värskes kloonis `OK` ([Esitamine](lab-9-esitamine.md)) | esimene tag kohtumise lõpus; hilisem töö uue commit'iga ja `git tag -f k01` |

## Moodulid

1. [Keskkond](lab-1-keskkond.md): viis VM-i, snapshot `algus` ja proovitud rollback, `ssh db01` töötab nimepidi.
2. [websetup.sh nagu tootmises](lab-2-websetup.md): dry-run, ERR-trap, journald; teine käivitus Ubuntus ja Rockys ütleb "muudatusi pole".
3. [Üks käsk, mitu hosti](lab-3-mitu-hosti.md): paralleelne `webdeploy.sh` hostipõhiste logide, kokkuvõtte ja lukuga; sshd poliitika viide hosti ilma end välja lukustamata.
4. [Viis teenust](lab-4-viis-teenust.md): `deploy-all.sh` health check'iga ja `check.sh` väljumiskoodidega.
5. [Kolm viga](lab-5-kolm-viga.md): rike leitud kihtide kaupa, parandus skriptis, kõik kihid UP ka pärast rollback'i.
6. [Sama töö Ansible'iga](lab-6-ansible.md): `ansible.cfg`, inventory, ad-hoc käsud, `web.yml` Ubuntus ja Rockys, teine jooks `changed=0`.
7. [Operatsioon](lab-7-operatsioon.md): `check.sh` timeriga, rike ja taastumine, app01 redeploy, vigane release ja rollback ilma snapshot'ita, host snapshot'ist, logide maht ilma Tomcati restardita.
8. [Git meeskonnas](lab-8-git-meeskonnas.md): PR `k01-bash`-i, lahendatud konflikt, rebase, `git bisect` leiab murdva commit'i, saladuse proov, ajaloo kontroll ja hotfix release-harule cherry-pick'iga.
9. [Esitamine](lab-9-esitamine.md): sinu töökoha esimene automatiseerimise samm, kontrollid ka värskes kloonis, PR, tag `k01`, automaatse hindaja tulemus.

Veaotsing: [Abi](abi.md) ja [Linux + Bash spikker](spikker.md).
