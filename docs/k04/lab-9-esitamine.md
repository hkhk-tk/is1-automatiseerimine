---
tags:
  - Git
  - Hindamine
---

# 4. Esitamine

Kood, mis töötab sinu kaustas, võib värskes kloonis ebaõnnestuda, sest pool vajalikest failidest on ainult sinu kettal. Kogu korra töö on harus `k04-tofu`, aga automaatne hindaja näeb ainult `main`-i ja seda, mis sinna jõudis. Enne PR-i käivitad samad kontrollid ise ja vaatad, et ükski saladus ega state pole Gitis: mida rohkem leiad oma terminalis, seda vähem parandusi tuleb pärast tag'i. Lõpuks on töö `main`-is, tag `k04` on käivitanud automaatse hindaja ja tulemus on GitHubi Releases all.

## Enne esitamist

Kontrollid koodi, plaani, Giti sisu ja Ansible'i ühendust samas järjekorras, nagu need üksteisest sõltuvad. Automaatne hindaja näeb ainult repositooriumi: vormindus, `validate`, ressursid ja saladused. Proxmoxi VM-e see ei näe.

Kaks esimest sammu kontrollivad seda, mida automaatne hindaja ei saa näha.

1. Kontrolli koodi ja plaani.

    ```bash
    cd ~/kursus/k04-tofu
    tofu fmt -check -recursive && tofu validate
    tofu plan -detailed-exitcode > /dev/null; echo "kood $?"
    ```

2. Kontrolli, mis on Gitis ja kas inventory töötab.

    ```bash
    git ls-files | grep -E 'tfstate|\.tfvars$|tfplan|backend\.hcl|\.env$|import\.tf|pkrvars\.hcl$|manifest\.json'
    cd ../k02-ansible
    ANSIBLE_HOST_KEY_CHECKING=False ansible all -i inventory.ini -u kasutaja -m ansible.builtin.ping -o
    ```

3. Käivita automaatse hindaja kontrollid.

    ```bash
    cd ~/kursus
    for t in files secrets fmt validate resources; do
        bash autograde/check.sh k04 "$t"
    done
    ```

`git ls-files | grep` ei tohi midagi leida. Kõik viis `OK` tähendavad, et kood on automaatse hindaja silmis valmis.

> `validate` vajab provider'i allalaadimist registry'st. Kui control node registry't ei näe, ebaõnnestub ainult see kontroll; automaatne hindaja GitHubis seda ei mõjuta.

**Edasi saad minna, kui** `fmt` vaikib, `validate` on `Success!`, plaani kood on `0`, `git ls-files | grep` ei näita midagi, viis hosti vastavad `SUCCESS` ja kõik viis kontrolli annavad `OK`.

Enne PR-i saad proovida, kas kood töötab ka värskes kloonis: IS2 [süvenemise osa 4](https://hkhk-tk.github.io/is2-automatiseerimine/k04/syvenemine/#osa-4-varske-kloon-enne-esitamist).

## PR, merge ja tag

Nüüd viid haru `main`-i ja märgid esitatava versiooni tag'iga. Tag peab olema `main`-i peal pärast merge'i. Kui see on vales kohas, hindab automaatne hindaja koodi, mida sa ei tahtnud esitada.

```bash
git push
gh pr create --base main --head k04-tofu --title "K4 OpenTofu" --body "K4: OpenTofu, kõik laborietapid"
gh pr merge --merge
git switch main && git pull
git tag k04 && git push origin k04
```

PR on ülevaatuse koht ka siis, kui sa ise selle kohe merge'id. Selle diff näitab kogu korra muudatust ühes vaates: kui seal on fail, mida sa ei tunne, on veel aega see eemaldada.

> Parandus pärast esitust: uus commit `main`-i, siis `git tag -f k04 && git push -f origin k04`.

<!-- EKRAANIPILT: GitHub, õppija repo → Pull request k04-tofu → main, Checks vahekaart: automaatse hindaja testid k04 files, secrets, fmt, validate, resources kõik rohelised, punktisumma näha.
<figure markdown="span">
  ![GitHubi PR, automaatse hindaja kontrollid rohelised](assets/k04_gh_pr_autograder.png)
  <figcaption>Joonis L4.11. PR <code>k04-tofu</code> → <code>main</code>: kõik automaatse hindaja testid on läbitud.</figcaption>
</figure>
-->

**Edasi saad minna, kui** `git ls-remote --tags origin` näitab `k04`.

## Automaatse hindaja tulemus

Tag `k04` käivitab GitHubis automaatse hindaja. Loed tulemust ja seod iga mitteläbinud kontrolli oma koodiga. Tulemus on paari minuti pärast: repo → **Releases** → viimane `submit/…`, iga mitteläbinud kontrolli juures on põhjus. Testide nimekiri on repositooriumi failis `autograde/TESTS.md`.

Automaatne hindaja kontrollib, kas failid on olemas, kas kood läbib `fmt`-i ja `validate`-i, kas VM-id on kirjeldatud data source'i ja `for_each`-iga, kas inventory tuleb Tofust ning kas token, state ja `terraform.tfvars` on Gitist väljas. Kui mõni kontroll ebaõnnestus GitHubis, aga mitte sinu terminalis, on erinevus keskkonnas: tavaliselt fail, mis on sinu kaustas, aga mitte commit'is.

**Edasi saad minna, kui** Releases näitab tulemust 100 lähedal.

## Pärast esitamist: VM-id välja

5. ja 6. kohtumine töötavad control node'is ja koolitaja serverites, 7. kohtumisel lood ühe uue VM-i. web01…db01 neid ei vaja. Kooli Proxmoxis jagavad kõik õppijad sama mälu, nii et need lülitatakse välja, aga mitte ei kustutata: kood ja state jäävad alles ning lisaülesannete jaoks saad need uuesti käivitada.

1. Kui test01 (`01-alused`) või IS2 dev-workspace'i VM-id on veel alles, eemalda need `tofu destroy`-ga samas kaustas ja workspace'is, kus need lõid.
2. Lülita Proxmoxis välja web01, app01, rmq01, mc01 ja db01: **VM → Shutdown**.

> 5. kohtumise eelõhtul token aegub ja `tofu plan` annab siis `401`. Kood ja state jäävad alles. VM-e saad käivitada Proxmoxi veebiliidesest.

**Edasi saad minna, kui** Proxmoxis on sinu pool'is töötamas ainult control node.

## Miks see nii töötab

**Automaatne hindaja.** Automaatne hindaja töötab nagu pipeline: värske kloon, `init -backend=false -lockfile=readonly`, `validate`, failide ja mustrite kontroll. See ei näe Proxmoxi ega sinu state'i, nii et roheline tulemus tähendab „kood on korras", mitte „taristu töötab".

**Tag.** Tag ei liigu koos haruga. Seepärast pannakse tag alles pärast merge'i, kui `main` on lõplik.

Kui jõudsid kiiremini: [Lisaülesanded → Lisaprojekt: Docker ja Kubernetes OpenTofuga](https://hkhk-tk.github.io/is2-automatiseerimine/k04/lisa/#lisaprojekt-docker-ja-kubernetes-opentofuga), haldad sama tsükliga control node'i Dockerit ja oma Kubernetese namespace'i.
