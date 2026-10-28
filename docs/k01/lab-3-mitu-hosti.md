---
tags:
  - Bash
  - SSH
---

# 3. Üks käsk, mitu hosti

Mitme hosti juures jääb üks host maha, teine vastab aeglaselt, kolmas on juba seadistatud ja kolleeg käivitab sama deploy'd samal ajal. Tsükkel, mis selles olukorras ripub kaks minutit maas hosti taga, jätab vaikselt hosti vahele või ütleb lõpus "valmis", ei ütle sulle, mis seis hostides on. `websetup.sh` jõuab nüüd mitmesse hosti korraga: ilma paroolideta, paralleelselt, iga hosti logi eraldi failis, lõpus kokkuvõte ja väljumiskood, mida saab teises skriptis kasutada. Lõpus läheb samal teel kõigisse hostidesse sshd seadistus, ja see ei tohi ühtki hosti kättesaamatuks teha.

**Kui teed seda tööl iga päev:** sinu `webdeploy.sh` täidab juba selle lehe nõuded (hostifail, `mapfile`, `-j`, hostipõhised logid, kokkuvõte koodiga, `flock -n`) ja `bash autograde/check.sh k01 loop` annab `OK`. Kui see on sul juba korras, mine otse etappi [„sshd seadistus koodist, ilma end välja lukustamata“](#sshd-seadistus-koodist-ilma-end-valja-lukustamata).

## Automatiseerimise võti

Skriptid kasutavad eraldi võtit. Selle saab tühistada, ilma et sinu isiklik ligipääs kaoks.

Kui automaatika võti lekib, eemaldad ühe rea `authorized_keys`-ist kõigis hostides ja sinu enda ligipääs töötab edasi. sshd logib iga sisselogimise juurde võtme sõrmejälje (`Accepted publickey for kasutaja … ED25519 SHA256:…`), nii et `ssh-keygen -lf` järgi näed auditis, kas sisse tuli inimene või skript. `authorized_keys`-is saab automaatika võtit piirata ka valikutega `from="<control node IP>"` ja `restrict`.

1. Tee võti ilma paroolifraasita ja vii see web01-le.

    ```bash
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_labseis -N "" -C "labseis-automation"
    ssh-copy-id -i ~/.ssh/id_ed25519_labseis.pub web01
    ```

2. Vii sama võti tsükliga ülejäänud neljale hostile.
3. `ssh-copy-id` logib sisse olemasoleva võtmega, sest pilvepildis parooliga sisselogimist pole.

Võti on ilma paroolifraasita, sest timer ja öine skript ei saa seda sisestada. Selle hind on, et faili `~/.ssh/id_ed25519_labseis` õigused (`600`) ja control node'i turvalisus on nüüd sama tähtsad kui parool.

✅ **Edasi saad minna, kui** igas viies hostis on `~/.ssh/authorized_keys`-is rida `labseis-automation`.

## SSH config automaatikale

Automaatika ei tohi kunagi küsida ega jääda maas hosti taha rippuma. Lisa `~/.ssh/config`-i lõppu ühine plokk:

```
Host web01 app01 mc01 rmq01 db01
    IdentityFile ~/.ssh/id_ed25519_labseis
    IdentityFile ~/.ssh/id_ed25519
    BatchMode yes
    ConnectTimeout 5
    StrictHostKeyChecking accept-new
```

Iga rida vastab ühele rikkele. `BatchMode` muudab paroolipäringu kohe veaks, `ConnectTimeout` piirab ootamist maas hosti taga ja `accept-new` võtab uue hosti vastu, aga keeldub, kui tuntud hosti võti muutus. Kaks `IdentityFile` rida tähendavad, et ssh proovib esmalt automaatika võtit ja siis sinu oma.

`ssh -G` näitab seadeid, millega ssh ühendub pärast kõigi `Host` plokkide ühendamist. Teine käsk simuleerib maas hosti.

```bash
ssh -G db01 | grep -E '^(user|hostname|batchmode|connecttimeout|identityfile) '
time ssh -o HostName=10.255.255.1 web01 true
```

Kui siin pole `batchmode yes`, ei klapi ploki `Host` rida sinu hostinimega. Viis sekundit maas hosti peal tähendab, et 200 hostiga tsükkel, kus 10 on maas, kaotab kõige rohkem 50 sekundit, mitte 10 × 2 minutit.

✅ **Edasi saad minna, kui** `ssh -G` näitab `batchmode yes` ja `connecttimeout 5` ning maas host annab vea umbes 5 sekundiga.

## sysinfo.sh kõigis hostides

Skripti ei pea hosti kopeerima: `bash -s` loeb selle ssh standardsisendist. Kirjuta `k01-bash/sysinfo.sh`:

- üks rida hosti kohta: nimi, `$ID-$VERSION_ID`, uptime minutites, `MemAvailable` MB, `/` täituvus %, ebaõnnestunud unit'ide arv
- allikad: `/proc/uptime`, `/proc/meminfo`, `df --output=pcent /`, `systemctl --failed --no-legend`
- `MAX_DISK` (vaikimisi 90) või `MIN_MEM_MB` (vaikimisi 100) ületatud → teade stderr-i, kood 1

```bash
for h in web01 app01 rmq01 mc01 db01; do
    ssh "$h" 'bash -s' < k01-bash/sysinfo.sh || echo "$h: HOIATUS"
done
ssh db01 MAX_DISK=1 bash -s < k01-bash/sysinfo.sh; echo "kood $?"
```

Viis rida ühes formaadis saad võrrelda ühe pilguga. Viimane käsk tõestab, et lävend on muudetav ilma skripti muutmata ja et hoiatus jõuab kutsujani koodina.

✅ **Edasi saad minna, kui** saad viis rida ja viimane käsk annab hoiatuse ning koodi 1.

## webdeploy.sh: hostid failist

Hostide nimekiri ei tohi olla skriptis. Kui see on failis, saad sama skriptiga deploy'da kahte testhosti, kõiki viit või ühte, mis vajab parandust, ilma koodi muutmata. Kirjuta `k01-bash/webdeploy.sh`, alguses järjestikuse tsükliga:

- hostifail `-f`-iga (vaikimisi `webhosts`, tee on `k01-bash` kausta suhtes); read `nimi IP`, kommentaarid, tühjad read ja CRLF välja
- hostinimed massiivi `mapfile -t`-ga; ühendus nime järgi, siis kehtib `~/.ssh/config`
- iga host: `scp websetup.sh` → `ssh … sudo bash /tmp/websetup.sh <argumendid>`
- `-n`, `-v` ja URL lähevad `websetup.sh`-ile edasi, URL `printf %q`-ga

```bash
cp k01-bash/webhosts.example k01-bash/webhosts      # web01 ja mc01
./k01-bash/webdeploy.sh -n "$TEMPLATE_URL"
./k01-bash/webdeploy.sh "$TEMPLATE_URL"
bash autograde/check.sh k01 loop
```

Mõlemad hostid seadistas juba `websetup.sh`, seega "muudatusi pole" on õige vastus. See tõestab, et `webdeploy.sh` annab argumendid muutmata edasi: kui URL oleks teel katki läinud, oleks `websetup.sh` laadinud teise malli või ebaõnnestunud. `printf %q` on vajalik, sest kaugkäsk läbib teise shelli ja `&` või `?` URL-is muutuks seal käsuks.

✅ **Edasi saad minna, kui** mõlemad hostid ütlevad "muudatusi pole" ja `loop` annab `OK`.

## Lõhu tsükkel tahtlikult

`while read` + `ssh` on klassikaline lõks, mida AI-tööriistad kirjutavad sageli ise. Tekitad vea teadlikult, et tunneksid selle hiljem ära ka võõras skriptis.

1. Kirjuta tsükkel ajutiselt ümber: `while read -r name ip; do … ssh … ; done < webhosts`
2. Käivita ja vaata, mitu hosti seadistati.
3. Vaata, kust `ssh` oma standardsisendi saab ja mida ta sellega teeb.
4. Paranda kahel viisil (üks `ssh` võtmega, teine ilma `while read`-ita) ja jäta alles `mapfile`-versioon.

Selle vea teeb ohtlikuks vaikus: skript lõpeb koodiga 0 ja ükski rida ei ütle, et teine host jäi vahele. Kahe hostiga paistab see kohe silma, 200 hostiga mitte. Seepärast kontrollib ka automaatse hindaja `loop` test, et `while read` kõrval oleks kaitse.

✅ **Edasi saad minna, kui** `while`-versioon seadistas ainult esimese hosti ja põhjus ning kaks parandust on `NOTES.md`-s.

## Paralleelne deploy

200 hostiga ei oota keegi järjestikust tsüklit. Lisa paralleelsus nii, et ükski viga kaduma ei läheks:

- `-j N` (vaikimisi 4): korraga kuni N hosti (`&` + `wait -n` või `xargs -P`)
- iga hosti väljund faili `logs/<host>.log`, ekraanile ainult edenemine
- iga hosti väljumiskood säilib: taustatöö kood kaob, kui sa seda ei salvesta (`wait "$pid"` või `logs/<host>.rc`)
- `logs/` on `.gitignore`-s

Paralleelsuse piir on tahtlik. Piiramatu paralleelsus koormab korraga paketi-mirror'it, sinu control node'i ja võrku, ja vea korral on katki kõik hostid korraga.

Dry-run on kahjutu, nii et proovi kõigi viie hostiga.

```bash
time ./k01-bash/webdeploy.sh -f hosts -n -j 1 "$TEMPLATE_URL"
time ./k01-bash/webdeploy.sh -f hosts -n -j 5 "$TEMPLATE_URL"
ls k01-bash/logs/
git check-ignore -v k01-bash/logs/web01.log
```

Ajavahe näitab, kuhu aeg läheb: ootamisse võrgu ja kaugmasina taga, mitte control node'i protsessorisse. Kui `-j 5` oleks peaaegu sama aeglane kui `-j 1`, oleks pudelikael control node'is või ühises ressursis. Laboris on selleks tavaliselt sama paketi-mirror.

✅ **Edasi saad minna, kui** `-j 5` on selgelt kiirem, igal hostil on oma logi ja `git check-ignore` leiab reegli.

## Kokkuvõte ja väljumiskood

Kutsuv skript ja inimene peavad ühe pilguga nägema, mis ebaõnnestus. Lisa lõppu:

- tabel `host OK|FAIL` koos logi viimase reaga või logifaili teega
- rida `Valmis: 2/2 hosti OK, <aeg> s`
- väljumiskood 0 ainult siis, kui kõik hostid õnnestusid

```bash
printf 'web01 x\nbad01 10.255.255.1\n' > /tmp/wh-test
./k01-bash/webdeploy.sh -f /tmp/wh-test -n; echo "kood $?"
```

Test kontrollib kolme asja korraga. `bad01` ei peatanud `web01`-i, kood 1 ütleb kutsujale, et kõik ei õnnestunud, ja logi tee ütleb inimesele, kust edasi vaadata. Kui kood oleks 0, jätkaks iga skript, mis `webdeploy.sh`-i kutsub, nagu kõik oleks korras.

✅ **Edasi saad minna, kui** web01 on `OK`, bad01 `FAIL` koos logi teega ja kood on 1.

## Kaks jooksu korraga ei käi

Kaks kolleegi, kes deploy'vad samal ajal, kirjutavad teineteise töö üle. Sama juhtub, kui timer käivitab skripti ajal, mil sa seda käsitsi käivitad. Lisa lukk:

- `flock -n` lukufailiga `logs/.webdeploy.lock`
- teine jooks lõpetab kohe teatega ja koodiga 1
- lukk vabaneb ise, kui protsess lõpeb, ka `kill -9` järel

```bash
./k01-bash/webdeploy.sh -n "$TEMPLATE_URL" & sleep 1
./k01-bash/webdeploy.sh -n "$TEMPLATE_URL"; echo "kood $?"
wait
```

Ava lukufail `exec 9> …`-ga, siis hoiab lukku kogu skript, mitte üks käsk. Mustri leiad `man flock` näidetest.

`-n` tähendab "ära oota". Ilma selleta jääks teine jooks järjekorda ja käivituks pärast esimest, mis on hullem: kaks korda sama deploy'd, millest teine võib kasutada juba vananenud argumente.

✅ **Edasi saad minna, kui** teine jooks lõpeb kohe teatega "juba jookseb" ja koodiga 1, esimene lõpetab normaalselt.

## Lukk pärast `kill -9`

Lukust on kasu ainult siis, kui see vabaneb ka siis, kui skript sureb. Kontrolli seda, sest just ebaõnnestunud või tapetud jooks on see olukord, kus kõige rohkem tahad uuesti käivitada.

1. Käivita jooks taustal ja tapa see kohe signaaliga, mida ei saa püüda.

    ```bash
    ./k01-bash/webdeploy.sh -n "$TEMPLATE_URL" & sleep 1
    kill -9 $!
    ```

2. Oota mõni sekund ja käivita uuesti.

    ```bash
    sleep 5
    ./k01-bash/webdeploy.sh -n "$TEMPLATE_URL"; echo "kood $?"
    ls -l k01-bash/logs/.webdeploy.lock
    ```

Teine jooks läks läbi, kuigi lukufail on endiselt olemas: lukk on tuuma lukk avatud failikirjeldusel, mitte faili olemasolu. `sleep 5` annab tapetud skripti taustal töötavatele `scp`-le ja `ssh`-le aega lõpetada.

✅ **Edasi saad minna, kui** jooks pärast `kill -9`-i lõpetab koodiga 0 ja `NOTES.md`-s on üks lause, miks oli vaja oodata.

## sshd seadistus koodist, ilma end välja lukustamata

Pilvemallis on parooliga sisselogimine keelatud seni, kuni keegi muudab `sshd_config`-i käsitsi või pakett toob oma drop-in'i. Auditis ei piisa vastusest "mallis on nii": viis hosti peavad saama sama sshd poliitika failist repos ja sa pead näitama, mis väärtus igas hostis kehtib. Tootmispiirang: sinu ainus tee hostidesse on sama SSH. Vigane konf, mida sshd reload'il ei loe, või poliitika, mis lukustab välja kasutaja `kasutaja`, jätab sulle ainult Proxmoxi konsooli.

Nõuded:

- poliitika on failis `k01-bash/ssh/10-labseis.conf`: parooli ja keyboard-interactive autentimine välja, root'i sisselogimine välja, agent forwarding ja X11 välja, `MaxAuthTries 3`; hostis läheb see faili `/etc/ssh/sshd_config.d/10-labseis.conf` (root, `644`)
- `k01-bash/sshd-policy.sh` loeb hostid failist `hosts` (sama loogika nagu `webdeploy.sh`) ja käib need läbi **ükshaaval**; esimene host on sinu canary
- igas hostis: uus fail kõrvale, `sshd -t` enne aktiveerimist; kui `sshd -t` ebaõnnestub, jääb eelmine seis (ka eelmine `10-labseis.conf`) alles ja reload'i ei tehta
- reload ainult siis, kui fail muutus; teenuse nimi on Ubuntus `ssh`, Rockys `sshd`
- pärast reload'i uus SSH-ühendus control node'ilt (`ssh -n -o ControlPath=none <host> true`); kui see ebaõnnestub, lõpetab skript koodiga 1 ja järgmisi hoste ei puuduta
- teine käivitus ütleb igas hostis "muudatusi pole" ja ei tee reload'i

Enne rollout'i vaata, mida agent forwarding sinu agendiga teeb. Agent on control node'il tööl ainult selle katse jaoks.

```bash
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
ssh -A web01 'echo "$SSH_AUTH_SOCK"; ssh-add -l'
ssh -J web01 db01 hostname
```

Esimene käsk näitab web01-s sinu võtme sõrmejälge: web01 root saab sama socket'i kaudu sinu võtmega edasi logida, kuni oled sisse logitud. `-J` jõuab db01-le web01 kaudu ilma agendita, sest web01 edastab ainult TCP-voogu.

Rollout ja kontroll:

```bash
./k01-bash/sshd-policy.sh; echo "kood $?"
./k01-bash/sshd-policy.sh | tail -1
for h in web01 app01 rmq01 mc01 db01; do
    printf '%s ' "$h"; ssh -n "$h" "sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|allowagentforwarding) ' | tr '\n' ' '"; echo
done
ssh -o BatchMode=no -o PubkeyAuthentication=no web01 true
ssh -A web01 'ssh-add -l'; ssh -J web01 db01 hostname
ssh-agent -k
```

`sshd -T` näitab väärtust, mis kehtib pärast kõigi failide lugemist. `ssh -o PubkeyAuthentication=no` peab andma `Permission denied (publickey)`, mitte paroolipäringut.

Viimaseks rikketest: lisa poliitikasse ajutiselt kirjaviga (`PasswordAuthentcation no`) ja käivita skript. Esimene host peab andma `sshd -t` vea, jääma eelmise poliitikaga, reload'i ei tehta ja ülejäänud hoste skript ei puuduta. Seejärel paranda fail ja käivita uuesti.

> Kui skript ütleb pärast reload'i, et uus ühendus ebaõnnestus, ära sulge olemasolevat sessiooni: see jääb ellu ka siis, kui sshd ei lase uusi sisse, ja sellega saad faili tagasi panna.

✅ **Edasi saad minna, kui** `sshd -T` näitab viies hostis kõigil neljal real `no`, teine käivitus ütleb "muudatusi pole", `PubkeyAuthentication=no` annab `Permission denied (publickey)`, `ssh -A web01 'ssh-add -l'` ei näe pärast rollout'i sinu võtit, `-J` töötab ja kirjaviga peatas skripti esimese hosti juures koodiga 1.

## ShellCheck ja commit

Nüüd on `k01-bash/` all mitu skripti, mis kutsuvad üksteist. ShellCheck kõigil korraga hoiab ära olukorra, kus üks fail on puhas ja teine mitte.

```bash
shellcheck -S warning k01-bash/*.sh
chmod +x k01-bash/*.sh
git add k01-bash/sysinfo.sh k01-bash/webdeploy.sh k01-bash/webhosts k01-bash/sshd-policy.sh k01-bash/ssh/ k01-bash/NOTES.md
git commit -m "webdeploy.sh: paralleelne, logid, kokkuvõte, flock; sysinfo.sh; sshd poliitika" && git push
```

`logs/` jääb commit'ist välja ka siis, kui kasutaksid `git add -A`, sest see on `.gitignore`-s. Logides on hostinimed ja IP-d ning need muutuvad iga jooksuga, seega repos oleks neist ainult müra.

✅ **Edasi saad minna, kui** ShellCheck on vaikne ja commit on GitHubis.

📎 **Selle mooduli tõend:** commit `webdeploy.sh: …`; `NOTES.md`-s `sysinfo.sh` väljund, `while read` põhjus ja parandused, `-j 1` ja `-j 5` ajad, FAIL-testi kokkuvõte, `kill -9` lukutest, `sshd -T` väljund viiest hostist ja kirjavea test.

## Miks see nii töötab

**`ssh` ja `while read`.** `ssh` loeb sama standardsisendit kui `while read` ja loeb ära ka ülejäänud read.

**SSH valikud automaatikas.** `BatchMode=yes` lõpetab ühenduse kohe veaga, kui ssh peaks kasutajalt midagi küsima. `ConnectTimeout` ei lase kättesaamatul hostil tsüklit kinni hoida. `StrictHostKeyChecking=accept-new` lisab uue hosti võtme faili `known_hosts`, aga keeldub ühendusest, kui juba tuntud hosti võti on muutunud. Väärtusega `no` ühenduks ssh ka muutunud võtmega. OpenSSH keelab siis küll parooliga sisselogimise, kuid võtmega sisselogimine õnnestub (kehtib Ubuntu 24.04 ja Rocky 9 OpenSSH versioonide kohta). Just muutunud võtme korral võib ühenduse vahel olla ründaja.

**sshd seadistuse järjekord.** Nii Ubuntu 24.04 kui Rocky 9 `sshd_config` algab reaga `Include /etc/ssh/sshd_config.d/*.conf`, failid loetakse tähestiku järjekorras ja iga võtme puhul kehtib esimene väärtus. Seepärast võidab `10-labseis.conf` nii Ubuntu pilvemalli `60-cloudimg-settings.conf`-i, Rocky `50-redhat.conf`-i kui ka `sshd_config`-i enda read, ja `sshd -T` on ainus usaldusväärne vastus küsimusele, mis kehtib. `Match`-plokid muudavad tulemust ühenduse kaupa (`sshd -T -C user=kasutaja,host=x,addr=10.0.0.1`). Reload (SIGHUP) laseb sshd-l konfi uuesti lugeda ja olemasolevad sessioonid jäävad alles, sest iga sessioon on eraldi protsess. SIGHUP-i peale käivitab sshd end vigase konfiga uuesti ja kuulav protsess lõpetab, nii et uued ühendused lükatakse tagasi. Ubuntu `ssh.service` käivitab reload'il enne SIGHUP-i `sshd -t`, Rocky `sshd.service` mitte; seepärast on `sshd -t` skriptis ja olemasolev sessioon sinu kaks kaitset. Ubuntu 24.04-s käivitab sshd `ssh.socket`; pordi või `ListenAddress`-i muudatus vajab seal `systemctl daemon-reload` ja `ssh.socket`-i taaskäivitust, mitte ainult reload'i. `ProxyJump` kasutab bastionis TCP-edastust (`AllowTcpForwarding`), mitte agenti: kui bastionis on `AllowTcpForwarding no`, lakkab `-J` töötamast.

**Lukk `flock`-iga.** `flock(2)` lukk on seotud avatud faili kirjeldusega (open file description), mitte fd numbri ega failinimega. Lukk vabaneb, kui viimane seda failikirjeldust hoidev protsess lõpetab töö, ka pärast `kill -9`-t. Kui skript käivitas taustal `ssh`- või `scp`-protsesse, pärisid need failikirjelduse ja lukk vabaneb alles siis, kui ka need on lõppenud. PID-faili (`echo $$ > lock`) puhul nii ei juhtu: pärast `kill -9`-t jääb fail alles, järgmine käivitus ootab, kuni keegi selle käsitsi kustutab, ja öine automaatika seisab.

**Paralleelsus ja logid.** Paralleelsel käivitusel segunevad hostide väljundid. Seepärast kirjutab iga host oma logifaili ja ekraanile tuleb ainult kokkuvõte. Ansible'is vastab failile `webhosts` inventory (`inventory.ini`) ja võtmele `webdeploy.sh -j` seade `forks` (`-f`).

**Saladused standardsisendis.** `deploy-all.sh` annab saladused ssh standardsisendisse, mitte käsureale, sest käsurida on näha `ps` väljundis ja sudo kirjutab käsu logisse. Linuxis on iga protsessi käsurida failis `/proc/<pid>/cmdline`, mida saab vaikimisi lugeda iga kasutaja. Erand on süsteem, kus `/proc` on monteeritud valikuga `hidepid`; Ubuntu 24.04 ja Rocky 9 vaikepaigaldus seda valikut ei kasuta.

**Erimärgid ja `printf %q`.** `printf %q` kirjutab väärtuse shelli jaoks turvalisel kujul, nii et erimärgid (`$`, tühik, jutumärk) jõuavad sihtmasinasse muutmata. Ilma selleta muutuks näiteks parool `a$b` teel ja viga paistaks valeparoolina.

Kui jõudsid kiiremini: [Lisaülesanded → 5. Hostifaili valideerimine](lisa.md#5-hostifaili-valideerimine), paned `webdeploy.sh`-i keelduma tühja või topelt-IP-ga hostifailist enne esimest `scp`-d.
