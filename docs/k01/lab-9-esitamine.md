---
tags:
  - Git
  - Hindamine
---

# 9. Esitamine

Automaatne hindaja näeb ainult seda, mis on GitHubis. Töö jõuab `main`-i, tag `k01` käivitab automaatse hindaja ja tulemus on GitHubi Releases all. Enne seda käivitad samad kontrollid ise.

Järjekord on sama mis meeskonna release'il: kontroll kohapeal, kontroll värskes kloonis, ülevaatus PR-is, merge ja tag, ning iga samm püüab kinni vea, mida eelmine ei näe.

**Kui teed seda tööl iga päev:** `git status --short` on tühi, kõik commit'id on GitHubis ja iga `autograde/TESTS.md` 1. kohtumise kontroll annab kohapeal `OK`. Kui see on sul juba korras, kirjuta etapi „Sinu töökohal“ tekst ja mine siis otse etappi [„Kontrolli värsket klooni“](#kontrolli-varsket-klooni).

## Sinu töökohal

Kirjuta `k01-bash/NOTES.md`-sse pealkirja "Minu töökohal" alla 3–5 lauset: kus sinu töökohal käib täna käsitsi midagi, mida selles kohtumises automatiseerisid (paigaldus mitmesse hosti, teenuse kontroll, rollback, konfi varundus, saladuse vahetus), ja mis oleks esimene samm selle automatiseerimiseks. Nimeta üks konkreetne takistus: õigused, change'i protsess, võrk, see, et keegi teine hoiab seda masinat. Hoste ega sisevõrgu nimesid pole vaja.

```bash
grep -A6 '^#* *Minu töökohal' k01-bash/NOTES.md
git add k01-bash/NOTES.md && git commit -m "notes: minu töökohal" && git push
```

✅ **Edasi saad minna, kui** `NOTES.md`-s on pealkiri "Minu töökohal" ja selle all 3–5 lauset koos ühe esimese sammuga.

## Enne esitamist

Automaatne hindaja näeb ainult repot. Käivita tema kontrollid kohapeal ja vaata, et ükski saladus pole Gitis. Kontrollide nimekiri ja punktid on ühes kohas, failis `autograde/TESTS.md`: tsükkel loeb sealt 1. kohtumise read, nii et nimekirja ei pea ise kordama.

```bash
cd ~/labori-seis
shellcheck -S warning k01-bash/*.sh k01-bash/services/*.sh
grep -oE 'check\.sh k01 [a-z]+' autograde/TESTS.md | while read -r _ d t; do
    bash autograde/check.sh "$d" "$t" < /dev/null
done
git ls-files | grep -E 'secrets\.env$|proxmox\.env|id_ed25519|ansible\.log' || echo "OK: saladusi pole Gitis"
```

Seejärel `web.yml` kontrollid ja idempotentsus töötava stackiga: teine täielik käivitus peab lõppema koodiga 0 ja `web.yml` andma `changed=0`.

```bash
(cd k02-ansible && ansible-playbook web.yml --syntax-check && ansible-lint web.yml)
(cd k01-bash && ./deploy-all.sh && ./check.sh); echo "kood $?"
(cd k02-ansible && ansible-playbook web.yml -e web_template_url="$TEMPLATE_URL" | tail -4)
git status --short
```

Kaks plokki kontrollivad eri asju. Esimene vaatab faile, nagu automaatne hindaja neid näeb. Teine vaatab süsteemi, mida automaatne hindaja ei näe: kas kogu stack tuleb ühe käsuga üles ja kas `check.sh` on pärast seda roheline.

✅ **Edasi saad minna, kui** ShellCheck ja ansible-lint vaikivad, iga `TESTS.md` 1. kohtumise kontroll annab `OK`, saladuste rida näitab `OK: saladusi pole Gitis` ja teine käivitus annab koodi 0.

## Kontrolli värsket klooni

Kohapeal võivad kontrollid läbida ka siis, kui fail on ainult sinu töökaustas: jälgimata, `.gitignore` taga või push'imata commit'is. Automaatne hindaja kloonib repo GitHubist, nii et kontrolli sama asja.

1. Push'i kõik ja klooni oma haru ajutisse kausta. Tee on `rm -rf`-is kirjutatud välja, mitte muutujast.

    ```bash
    git push
    ls -d /tmp/k01-proov 2> /dev/null
    rm -rf -- /tmp/k01-proov
    git clone -q --branch k01-bash "$(git remote get-url origin)" /tmp/k01-proov
    ```

2. Käivita kontrollid kloonis ja kustuta see siis.

    ```bash
    cd /tmp/k01-proov
    grep -oE 'check\.sh k01 [a-z]+' autograde/TESTS.md | while read -r _ d t; do
        bash autograde/check.sh "$d" "$t" < /dev/null
    done
    cd ~/labori-seis && ls -d /tmp/k01-proov && rm -rf -- /tmp/k01-proov
    ```

Kui kõik 1. kohtumise kontrollid on ka kloonis `OK`, näeb automaatne hindaja sama, mida sina. Kui mõni kontroll ebaõnnestus ainult kloonis, on vastav fail sinu masinas, aga mitte GitHubis; `git status --short --ignored` näitab, milline kolmest põhjusest see on.

✅ **Edasi saad minna, kui** kloonis annab iga `TESTS.md` 1. kohtumise kontroll `OK`.

## PR, merge ja tag

Tag peab olema `main`-i peal pärast merge'i. `git push` üksi tag'e ei lükka, VS Code'i Sync samuti mitte.

Selle merge'iga sulguvad ka issue'd, mille `closes #N` jäi `k01-bash`-is ootama, sest GitHub sulgeb need alles vaikeharul.

Eeldus: repo on sinu oma ja PR-i merge'id sina ise. `main`-il pole kaitsereeglit, mis nõuaks teise inimese kinnitust või rohelist CI-d. Kui `gh pr merge` siiski keeldub, näitab `gh pr view --json mergeStateStatus` põhjust.

```bash
git push
gh pr create --base main --head k01-bash --title "K1 Bash" --body "K1: Bash, kõik laborid"
gh pr merge --merge
git switch main && git pull
git tag k01 && git push origin k01
```

> Parandus pärast esitust: uus commit `main`-i, siis `git tag -f k01 && git push -f origin k01`.

Merge tehti GitHubis: ilma `git pull`-ita läheks tag vanale commit'ile ja automaatne hindaja hindaks seisu enne sinu tööd.

✅ **Edasi saad minna, kui** `git ls-remote --tags origin` näitab `k01`.

## Automaatse hindaja tulemus

Tag `k01` käivitab GitHubis automaatse hindaja. Tulemus on paari minuti pärast: repo → **Releases** → viimane `submit/…`, iga mitteläbinud kontrolli juures on põhjus. Automaatne hindaja annab tag'ile `k01` kuni 100 punkti ja iga kontrolli punktid on samas failis `autograde/TESTS.md`, millest kontrolle kohapeal käivitasid. Eesmärk on 100/100. Eraldi läbimise lävendit kursuse hindamine ei sea, nii et iga puuduv punkt on konkreetne ebaõnnestunud kontroll, mille põhjus on Releases'is. Automaatne hindaja sinu VM-e ei näe, stacki seisu näeb koolitaja Labori seisust.

Hinne tuleb kahest allikast, mis teineteist täiendavad. Automaatne hindaja kontrollib koodi ja Labori seis näitab, kas sama kood töötab. Kui üks on roheline ja teine punane, on see sama vastuolu, mida kolme vea juures lahendasid: viga on kahe kontrolli vahel.

✅ **Edasi saad minna, kui** Releases näitab tag'i `k01` tulemust 100/100 või iga puuduva punkti juures on ebaõnnestunud kontroll, mille põhjust tead, ja Labori seisus on sinu `lab-01` read rohelised.

## Tõendid moodulite kaupa

- [ ] 1. Keskkond: commit `hosts`, `cloud-init status` väljund, `getent` ja `dig` võrdlus, rollback'i proov, Cloud-Init'i ja snapshot'i ekraanipilt
- [ ] 2. websetup.sh: käsitsi käsud, "muudatusi pole" web01-s ja mc01-s, peatatud Apache'i test, ERR-rida, `journalctl -t websetup` väljavõte, SC-kood
- [ ] 3. Mitu hosti: `sysinfo.sh` väljund, `while read` põhjus ja parandused, `-j 1` / `-j 5` ajad, FAIL-test, lukutest ja `kill -9` test, `sshd -T` väljund viiest hostist ja vigase poliitika test
- [ ] 4. Viis teenust: hostifaili valideerimine, health check'i ebaõnnestumise väljund, sudo logi rida, `check.sh` esimene väljund, `curl -v` TLS-i read, `secrets` ja `report` OK
- [ ] 5. Kolm viga: `fix(tomcat)`, `fix(mariadb)`, `fix(memcache)` commit'id, `X-Cache` MISS → HIT, db01 taastamine skriptiga
- [ ] 6. Sama töö Ansible'iga: `k02-ansible/` kolm faili, maas hosti kood, teine jooks `changed=0`, rikketest, tabel "Bash → Ansible"
- [ ] 7. Operatsioon: unit-failid repos, journal rikke ja taastumisega, UNKNOWN-test, redeploy katkestuse pikkus, kaks vigast release'i ja rollback, logide mahu piirang ja vana logi kustutamine ilma Tomcati restardita
- [ ] 8. Git meeskonnas: merge'itud PR `k01-runbook`, konflikti merge-commit, rebase'i hash'id, saladuse proov, tühjad ajaloo otsingud, bisect'i leitud commit, hotfix'i hash release-harul
- [ ] 9. Esitamine: "Minu töökohal" `NOTES.md`-s, värske klooni kontroll, tag `k01`, Releases tulemus

✅ **Edasi saad minna, kui** kõik linnukesed on tehtud ja `NOTES.md` on viimases commit'is.

📎 **Selle mooduli tõend:** tag `k01` `main`-i peal ja automaatse hindaja tulemus GitHubi Releases all.

Kui jõudsid kiiremini: [Lisaülesanded → 6. AI ülevaatus](lisa.md#6-ai-ulevaatus), lased AI-l ühe skripti üle vaadata ja põhjendad, millise soovituse võtad ja millise jätad.
