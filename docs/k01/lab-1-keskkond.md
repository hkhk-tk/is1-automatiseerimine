---
tags:
  - SSH
  - Bash
  - Praktikum
---

# 1. Keskkond: SSH-võti, nimed ja ühendus

!!! abstract "Eesmärgid"

    Pärast selle osa läbimist:

    - on control node'i hostinimi `control`;
    - on control node'is SSH-võtmepaar ja avalik võti on lisatud kõigisse viide labori virtuaalmasinasse;
    - on virtuaalmasinate hostinimed `web01`, `app01`, `rmq01`, `mc01` ja `db01`;
    - saad control node'ist virtuaalmasinatega ühenduda nende nime järgi ja ilma parooli sisestamata.

## Enne alustamist

Enne selle osa alustamist peab [töökeskkond](../00-ulevaade/keskkond.md) olema valmis: VPN-ühendus töötab ja VS Code'i terminal avaneb control node'is.

Jäta Proxmox brauseris avatuks, sest selles osas on vaja viie virtuaalmasina IP-aadresse. Masina IP-aadressi näed, kui valid Proxmoxis masina ja avad vahelehe **Summary**. Aadress on real **IPs**. Neid aadresse kasutad sammus A2.

| Masin (nime lõpp Proxmoxis) | Operatsioonisüsteem |
|---|---|
| `web01`, `app01`, `rmq01` | Ubuntu 24.04 |
| `mc01`, `db01` | AlmaLinux 9 |

*Tabel 1. Labori virtuaalmasinad.*

Kõigis masinates on kasutajanimi `kasutaja`. Selle osa käsud käivitad control node'is, VS Code'i terminalis.

## A1 · Control node'i nimi

Control node'i hostinimi ei ole veel `control`. Terminali prompt kuvab praegust hostinime. Muuda hostinimi ja ava uus shell, et prompt uueneks:

```bash
sudo hostnamectl set-hostname control
exec bash
```

??? success "Oodatav tulemus"

    ```
    kasutaja@control:~$
    ```

    Laboris `sudo` parooli ei küsi, sest virtuaalmasinate mallis on kasutajal `kasutaja` lubatud kasutada `sudo`-t ilma paroolita. `hostnamectl` muudab hostinime püsivalt, nii et see jääb alles ka pärast taaskäivitust.

## A2 · Seadista SSH-ühendus

Selles sammus seadistad control node'ist SSH-ühenduse viie virtuaalmasinaga, nii et saad nendega ühenduda nime järgi ja ilma paroolita. Allpool on kirjeldatud, mida tuleb teha. Iga sammu juures on käsk masina web01 näitel. Sammud 1 ja 2 teed üks kord, sammud 3–6 iga masinaga eraldi.

Kui ei soovi viit masinat käsitsi seadistada, kasuta lehe lõpus olevat [skripti](#skript-koik-viis-masinat-korraga), mis teeb kõik sammud korraga.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 210" role="img" aria-label="control node'is on võtmepaar ja SSH konfiguratsioonifail; avalik võti lisatakse ssh-copy-id abil viide virtuaalmasinasse" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:15px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .c{fill:var(--md-default-fg-color);font-size:13px;font-family:var(--md-code-font-family,monospace)}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxs" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="hi" x="10" y="20" width="300" height="170" rx="10"/><text class="b" x="26" y="46">control · ~/.ssh/</text>
<rect class="box" x="26" y="60" width="268" height="34" rx="6"/><text class="c" x="40" y="82">id_ed25519      privaatvõti</text>
<rect class="box" x="26" y="100" width="268" height="34" rx="6"/><text class="c" x="40" y="122">id_ed25519.pub  avalik võti</text>
<rect class="box" x="26" y="140" width="268" height="34" rx="6"/><text class="c" x="40" y="162">config          nimi → IP</text>
<line class="a" x1="294" y1="117" x2="418" y2="117" marker-end="url(#lxs)"/><text class="s" x="356" y="108" text-anchor="middle">ssh-copy-id</text>
<rect class="box" x="420" y="20" width="290" height="170" rx="10"/><text class="b" x="436" y="46">web01 … db01</text>
<text class="c" x="436" y="80">~/.ssh/authorized_keys</text><text class="s" x="436" y="102">siia lisatakse avalik võti</text>
<text class="c" x="436" y="140">hostnamectl set-hostname</text><text class="s" x="436" y="162">masin saab oma nime</text>
</svg>
<figcaption>Joonis 1. Privaatvõti jääb control node'i, avalik võti lisatakse igasse virtuaalmasinasse.</figcaption>
</figure>

### 1. Kaust `~/.ssh`

SSH hoiab kasutaja võtmeid ja seadeid kodukausta peidetud kaustas `.ssh`. Kaustale määratakse õigused `700`, nii et sellele pääseb ligi ainult omanik. Liiga laiade õiguste korral keeldub SSH kausta kasutamast.

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

### 2. SSH-võtmepaar

`ssh-keygen` loob kaks faili: privaatvõti `id_ed25519` jääb control node'i, avalik võti `id_ed25519.pub` lisatakse teistesse masinatesse. Kui võtmepaar on juba olemas, ära seda käsku uuesti käivita.

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519 -C "kasutaja@control"
```

### 3. Masin SSH konfiguratsioonifaili

SSH konfiguratsioonifaili `~/.ssh/config` lisad iga masina nime ja IP-aadressi. Seejärel piisab käsust `ssh web01` ja IP-aadressi ei pea meeles pidama. Ava fail VS Code'is:

```bash
touch ~/.ssh/config
chmod 600 ~/.ssh/config
code ~/.ssh/config
```

Lisa faili kirje ja asenda IP-aadress Proxmoxist leitud aadressiga:

```text
Host web01
    HostName 192.168.125.11
    User kasutaja
    IdentityFile ~/.ssh/id_ed25519
```

### 4. Avalik võti masinasse

`ssh-copy-id` lisab avaliku võtme hallatava masina faili `~/.ssh/authorized_keys`. Esimesel ühendusel küsitakse, kas usaldad masina hostivõtit (vasta `yes`), ja seejärel kasutaja `kasutaja` parooli. Edaspidi parooli ei küsita.

```bash
ssh-copy-id web01
```

### 5. Hostinimi ja SSH hostivõtmed

Määra masinale hostinimi ja loo sellele uued SSH hostivõtmed. Samast mallist kloonitud virtuaalmasinatel võivad alguses olla samad SSH hostivõtmed. Hostivõti on serveri võti, millega klient kontrollib, millise serveriga ta ühendub. Hostivõti ei ole sama mis kasutaja SSH-võti, mille lõid sammus 2.

```bash
ssh -t web01 "sudo hostnamectl set-hostname web01 && sudo rm -f /etc/ssh/ssh_host_* && sudo ssh-keygen -A && (sudo systemctl restart ssh || sudo systemctl restart sshd)"
ssh-keygen -R 192.168.125.11
```

Teine käsk eemaldab control node'i failist `~/.ssh/known_hosts` masina vana hostivõtme, sest masinal on nüüd uus võti. AlmaLinuxi masinates (mc01, db01) on SSH teenuse nimi `sshd`, Ubuntu masinates `ssh`. Käsk proovib mõlemat.

### 6. Kontroll

```bash
ssh web01 hostname
```

Kinnita uus hostivõti (`yes`). Käsk peab kuvama `web01` ilma parooli küsimata.

Korda samme 3–6 masinatega `app01`, `rmq01`, `mc01` ja `db01`.

### Skript: kõik viis masinat korraga

??? example "Ava skript, mis teeb sammud 1–6 kõigi viie masinaga"

    Loo control node'is fail `~/ssh-seadistus.sh` (VS Code'is vali **File → New File** ja salvesta fail kodukausta). Kopeeri faili alljärgnev skript ja **asenda viis IP-aadressi** Proxmoxist leitud aadressidega. Skripti kommentaarides on samad sammude numbrid nagu ülal.

    ```bash
    #!/usr/bin/env bash
    # Seadistab control node'ilt SSH-ühenduse viie labori VM-iga.
    # Käivita control node'il oma kasutajana, ilma sudo-ta:
    #   bash ~/ssh-seadistus.sh

    # --- Sinu VM-ide IP-d (Proxmoxist). Muuda need! ---
    WEB01_IP="192.168.125.11"
    APP01_IP="192.168.125.12"
    RMQ01_IP="192.168.125.13"
    MC01_IP="192.168.125.14"
    DB01_IP="192.168.125.15"

    ssh_kaust="$HOME/.ssh"
    voti="$ssh_kaust/id_ed25519"
    config="$ssh_kaust/config"
    vigu=0

    # 1. Kaust ~/.ssh, ligipääs ainult omanikule
    mkdir -p "$ssh_kaust"
    chmod 700 "$ssh_kaust"

    # 2. Võtmepaar, kui seda veel pole
    if [[ -f "$voti" ]]; then
        echo "Võti on juba olemas: $voti"
    else
        ssh-keygen -t ed25519 -N "" -f "$voti" -C "kasutaja@control"
    fi

    # 3. SSH konfiguratsioonifail, ligipääs ainult omanikule
    touch "$config"
    chmod 600 "$config"

    # 4.–5. Iga masin: kirje konfiguratsioonifaili, avalik võti masinasse, hostinimi
    seadista() {
        local nimi="$1"
        local ip="$2"
        echo
        echo "=== $nimi ($ip) ==="

        if grep -q "^Host $nimi\$" "$config"; then
            echo "config: $nimi on juba olemas"
        else
            printf 'Host %s\n    HostName %s\n    User kasutaja\n    IdentityFile %s\n\n' \
                "$nimi" "$ip" "$voti" >> "$config"
            echo "config: lisatud $nimi"
        fi

        # Küsib masina parooli üks kord. Kui võti on juba seal, ei küsi.
        if ! ssh-copy-id -i "$voti.pub" -o StrictHostKeyChecking=accept-new "$nimi"; then
            echo "VIGA: võtit ei saanud masinasse $nimi" >&2
            return 1
        fi

        # Masina nimi ja (ainult esimesel korral) uued hostivõtmed. Laboris sudo parooli ei küsi.
        if ssh -t "$nimi" "sudo sh -c 'hostnamectl set-hostname $nimi; if [ ! -f /etc/ssh/.hostvotmed-uued ]; then rm -f /etc/ssh/ssh_host_* && ssh-keygen -A > /dev/null && touch /etc/ssh/.hostvotmed-uued && echo UUED_VOTMED && (systemctl restart ssh 2> /dev/null || systemctl restart sshd); fi'" | grep -q UUED_VOTMED; then
            ssh-keygen -R "$ip" > /dev/null 2>&1
            ssh-keygen -R "$nimi" > /dev/null 2>&1
            ssh -n -o StrictHostKeyChecking=accept-new "$nimi" true
            echo "hostivõtmed uuendatud: $nimi"
        fi
    }

    seadista web01 "$WEB01_IP" || vigu=$((vigu + 1))
    seadista app01 "$APP01_IP" || vigu=$((vigu + 1))
    seadista rmq01 "$RMQ01_IP" || vigu=$((vigu + 1))
    seadista mc01  "$MC01_IP"  || vigu=$((vigu + 1))
    seadista db01  "$DB01_IP"  || vigu=$((vigu + 1))

    # 6. Kontroll: iga masin vastab oma nimega, parooli küsimata
    echo
    echo "=== Kontroll ==="
    for nimi in web01 app01 rmq01 mc01 db01; do
        if vastus=$(ssh -n -o BatchMode=yes "$nimi" hostname); then
            echo "OK    $nimi vastab: $vastus"
        else
            echo "VIGA  $nimi ei vasta ilma paroolita" >&2
            vigu=$((vigu + 1))
        fi
    done

    echo
    if (( vigu == 0 )); then
        echo "Valmis: kõik viis masinat töötavad."
    else
        echo "Vigu: $vigu. Vaata ülalt, milline masin." >&2
        exit 1
    fi
    ```


    ??? note "Bashi võtted selles skriptis"

        | Kirjutis | Tähendus |
        |---|---|
        | `#!/usr/bin/env bash` | shebang: faili käivitab Bash |
        | `WEB01_IP="192.168.125.11"` | muutuja; võrdusmärgi ümber pole tühikuid |
        | `"$voti"` | muutuja väärtus; jutumärgid hoiavad väärtuse ühe tervikuna ka siis, kui selles on tühik |
        | `if [[ -f "$voti" ]]` | kas selline fail on olemas? |
        | `seadista() { ... }` | **funktsioon**: käskude rühm nimega, mida saab mitu korda kasutada |
        | `$1`, `$2` | funktsiooni esimene ja teine argument: `seadista web01 "$WEB01_IP"` |
        | `>>` | lisab faili lõppu (`>` kirjutaks üle) |
        | `|| vigu=$((vigu + 1))` | kui eelmine käsk ebaõnnestus, suurenda vigade arvu |
        | `exit 1` | skript lõpetab veakoodiga 1, et seda käivitav programm saaks vea tuvastada |

        Skripti piirid on [loengu](loeng.md#4-skripti-piirid) 4. peatükis.

    Enne käivitamist kontrolli skripti süntaksit. Käsk loeb skripti läbi, kuid ei käivita seda:

    ```bash
    bash -n ~/ssh-seadistus.sh && echo "süntaks korras"
    ```

    Käivita skript:

    ```bash
    bash ~/ssh-seadistus.sh
    ```

    Iga masina juures küsib `ssh-copy-id` üks kord parooli, et lisada avalik võti masinasse. Sisesta kasutaja `kasutaja` parool, mille said juhendajalt. `sudo` laboris parooli ei küsi.

    ??? success "Oodatav tulemus"

        ```
        === web01 (192.168.125.11) ===
        config: lisatud web01
        kasutaja@192.168.125.11's password:
        Number of key(s) added: 1
        hostivõtmed uuendatud: web01
        ...
        === Kontroll ===
        OK    web01 vastab: web01
        OK    app01 vastab: app01
        OK    rmq01 vastab: rmq01
        OK    mc01 vastab: mc01
        OK    db01 vastab: db01

        Valmis: kõik viis masinat töötavad.
        ```

    Käivita skript teist korda:

    Enne käivitamist ennusta tulemust. Mida skript teisel käivitusel teeb? Kas see küsib parooli? Kas see lisab SSH konfiguratsioonifaili samad read teist korda?

    ```bash
    bash ~/ssh-seadistus.sh
    grep -c '^Host ' ~/.ssh/config
    ```

    ??? success "Oodatav tulemus"

        ```
        Võti on juba olemas: /home/kasutaja/.ssh/id_ed25519
        config: web01 on juba olemas
        ...
        All keys were skipped because they already exist on the remote system.
        ...
        Valmis: kõik viis masinat töötavad.
        5
        ```

        Uut võtmepaari ei looda, konfiguratsioonifaili midagi ei lisata ja `ssh-copy-id` ei küsi parooli, sest avalik võti on juba masinas. Hostinimi määratakse siiski uuesti, sest skript ei kontrolli enne, kas hostinimi on juba õige. Teine käivitus jätab lõpptulemuse samaks, kuid osa käske käivitatakse siiski uuesti. Järgmises osas võrdled seda Ansible'i moodulite käitumisega.

    ??? question "Mõtle (valikuline)"

        Kuidas muudaksid funktsiooni nii, et `hostnamectl` käivitatakse ainult siis, kui hostinimi ei ole veel õige? Vihje: `ssh -n "$nimi" hostname` kuvab praeguse hostinime.

## A3 · Proovi ise

```bash
cat ~/.ssh/config
ssh web01
hostname
exit
```

??? success "Oodatav tulemus"

    `cat` kuvab viis `Host`-plokki. `ssh web01` logib sisse ilma parooli küsimata ja prompt on `kasutaja@web01`. Käsk `exit` viib tagasi control node'i.

!!! warning "Privaatvõti jääb control node'i"

    Fail `~/.ssh/id_ed25519` (ilma laiendita `.pub`) on privaatvõti. Seda ei kopeerita mujale, ei lisata Giti ega saadeta kellelegi. Avalikku võtit (`.pub`) võib jagada.

## A4 · Võti GitHubi ja kursuse repo

Sama SSH-võtit saad kasutada GitHubiga autentimiseks, nii et Git-toimingute jaoks ei ole vaja parooli ega access token'it. Kuva avalik võti:

```bash
cat ~/.ssh/id_ed25519.pub
```

Ava GitHubis profiilipildi alt **Settings → SSH and GPG keys → New SSH key**. Kirjuta väljale *Title* `control`, kleebi väljale *Key* kogu rida ja vajuta **Add SSH key**. Seejärel kontrolli ühendust:

```bash
ssh -T git@github.com
```

??? success "Oodatav tulemus"

    Esimesel ühendusel kinnita `yes`. Seejärel kuvatakse:

    ```
    Hi <sinu-github-kasutaja>! You've successfully authenticated, but GitHub does not provide shell access.
    ```

Ava [Classroom 50 ülesanne](https://classroom50.org/hkhk-tk/is126-automatiseerimine/assignments) ja võta see vastu. Organisatsioonis `hkhk-tk` luuakse sulle privaatne repositoorium. Ava repositooriumi lehel **Code → SSH** ja kopeeri aadress.

```bash
git config --global user.name "Eesnimi Perenimi"
git config --global user.email "sinu@email.ee"
cd ~
git clone git@github.com:hkhk-tk/<sinu-repo>.git kursus
cd ~/kursus
mkdir -p k01
```

Kõik selle kohtumise failid salvestad kausta `~/kursus/k01/`.

## Veaotsing

| Mida näed | Põhjus | Mida teha |
|---|---|---|
| `Connection timed out` | IP-aadress on vale või masin ei tööta | võrdle skripti alguses olevaid IP-aadresse Proxmoxiga ja kontrolli, et masin töötab |
| `Permission denied (publickey,password)` | parool on vale | sisesta parool uuesti ja kontrolli, et kasutajanimi on `kasutaja` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | masina SSH hostivõti muutus, näiteks loodi masin uuesti | `ssh-keygen -R <ip>` ja käivita skript uuesti |
| `Bad owner or permissions on ~/.ssh/config` | konfiguratsioonifail on teistele kasutajatele kirjutatav | `chmod 600 ~/.ssh/config` |
| skripti kontrollis on `VIGA ... ei vasta ilma paroolita` | avalik võti ei jõudnud masinasse | käivita skript uuesti ja vaata selle masina väljundit |

*Tabel 2. Levinud vead.*

??? info "Loe juurde"

    - [OpenSSH: ssh_config](https://man.openbsd.org/ssh_config) (mida SSH konfiguratsioonifaili read tähendavad)
    - [`ssh-copy-id`](https://man.openbsd.org/ssh-copy-id)
    - [GNU Bash: Shell Functions](https://www.gnu.org/software/bash/manual/html_node/Shell-Functions.html)
    - [systemd: hostnamectl](https://www.freedesktop.org/software/systemd/man/latest/hostnamectl.html)

**Valmis, kui** käsk `ssh <masin> hostname` vastab kõigis viies masinas õige nimega ja parooli ei küsita.
