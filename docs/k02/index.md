---
tags:
  - Ansible
  - Info
---

# 02 · Labori seis rollidega

Sel kohtumisel paigaldad Ansible'iga kogu Labori seisu: andmebaasi, vahemälu, sõnumijärjekorra, rakenduse ja veebiserveri viies masinas. Kõigepealt parandad ühe suure playbook'i vead ja seejärel jagad selle rollideks, nii et päeva lõpus seadistab üks käsk kogu süsteemi.

[Loeng](loeng.md){ .md-button } [Praktikum](lab.md){ .md-button .md-button--primary } [Kodutöö](kodutoo.md){ .md-button }

??? abstract "Õpiväljundid"

    Päeva lõpuks oskad:

    - leida playbook'i vea sammudega sümptom, hüpotees, tõend ja parandus;
    - kirjeldada inventory's masinad teenuse ja distributsiooni gruppidena ning valida muutujale õige taseme;
    - teha mallist igale masinale oma konfiguratsioonifaili ja taaskäivitada teenust handler'iga ainult muudatuse korral;
    - hoida paroole Vaultis ja kasutada kogude mooduleid;
    - jagada playbook rollideks ja tõestada, et masinate olek ei muutunud.

Töö jõuab harusse `main` pull request'iga ja esitatakse tag'iga `k02`. Päeva jooksul näitab laboritahvel, millised teenused sinu masinates töötavad.

[Abi: levinud vead](abi.md) · [Küsimused ja teated](https://github.com/hkhk-tk/is126-arutelu/discussions)
