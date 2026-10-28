---
tags:
  - SSH
  - Bash
  - Praktikum
---

# 1. Keskkond: SSH-võti, nimed ja ühendus

!!! abstract "Eesmärgid"

    Lõpuks:

    - on control node'il nimi `control`;
    - on control node'il SSH-võti ja see võti on kõigis viies labori VM-is;
    - kannavad VM-id nimesid `web01`, `app01`, `rmq01`, `mc01`, `db01`;
    - logid control node'ilt igasse VM-i käsuga `ssh web01`, ilma IP-d ja parooli küsimata.

## Enne alustamist

[Töökeskkonna ettevalmistus](../00-ulevaade/keskkond.md) on tehtud: VPN töötab ja VS Code avab terminali control node'il. Masinate IP-d said Proxmoxist ([keskkonnaleht, samm 2](../00-ulevaade/keskkond.md#2-proxmox-sinu-masinate-ip-d)), parooli juhendajalt. Kirjuta IP-d siia:

| Nimi | IP | OS |
|---|---|---|
| control | | Ubuntu |
| web01 | | Ubuntu |
| app01 | | Ubuntu |
| rmq01 | | Ubuntu |
| mc01 | | Rocky Linux |
| db01 | | Rocky Linux |

*Tabel 1. Sinu masinad. Kasutaja kõigis: `kasutaja`.*

Kõik käsud käivad **control node'il**, VS Code'i terminalis.

## A1 · Control node'i nimi

Masinal pole veel nime, prompt näitab midagi muud kui `control`. Pane nimi ja ava uus shell, et prompt uueneks:

```bash
sudo hostnamectl set-hostname control
exec bash
```

??? success "Oodatav tulemus"

    ```
    kasutaja@control:~$
    ```

    `sudo` küsib sinu parooli. `hostnamectl` muudab masina nime jäädavalt, ka pärast taaskäivitust.

## A2 · Mida skript teeb

Viie masina seadistamine käsitsi tähendab viis korda samu käske. Just sellist tööd tasub automatiseerida. Enne kui skripti käivitad, vaata, mida see teeb. Iga punkt on ka skriptis kommentaarina:

1. **Kaust `~/.ssh`.** SSH hoiab võtmeid ja seadeid kodukausta peidetud kaustas `.ssh`. Kaust peab olema ainult sinu loetav (`chmod 700`), muidu SSH keeldub seda kasutamast.
2. **Võtmepaar.** `ssh-keygen` teeb kaks faili: privaatvõti `id_ed25519` jääb control node'ile, avalik võti `id_ed25519.pub` läheb teistesse masinatesse. Kui võti on juba olemas, skript uut ei tee.
3. **`~/.ssh/config`.** Siia kirjutab skript iga masina kohta nime ja IP. Pärast seda piisab käsust `ssh web01`, IP-d pole vaja meeles pidada. Kui nimi on failis juba olemas, skript seda teist korda ei lisa.
4. **Võti masinasse.** `ssh-copy-id` küsib masina parooli **üks kord** ja lisab sinu avaliku võtme sinna. Edaspidi parooli ei küsita.
5. **Masina nimi ja hostivõtmed.** Skript paneb masinale nime ja teeb esimesel korral uued SSH hostivõtmed, sest kõik masinad on samast mallist ja neil on sama võti. `sudo` küsib parooli.
6. **Kontroll.** Lõpus küsib skript igalt masinalt nime ilma paroolita. Kui mõni küsib parooli või ei vasta, on seadistus pooleli.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 210" role="img" aria-label="control node'il on võtmepaar ja config-fail; avalik võti läheb ssh-copy-id-ga viide VM-i" xmlns="http://www.w3.org/2000/svg">
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
<figcaption>Joonis 1. Privaatvõti jääb control node'ile, avalik võti läheb igasse VM-i.</figcaption>
</figure>

## A3 · Loo skript

Loo control node'il fail `~/ssh-seadistus.sh` (VS Code: **File → New File**, salvesta kodukausta). Kopeeri sisse alljärgnev ja **muuda viis IP-d** oma tabeli järgi:

```bash
#!/usr/bin/env bash
# Seadistab control node'ilt SSH-ühenduse viie labori VM-iga.
# Käivita control node'il oma kasutajana, ilma sudo-ta:
#   bash ~/ssh-seadistus.sh

# --- Sinu VM-ide IP-d (koolitajalt). Muuda need! ---
WEB01_IP="10.10.N.11"
APP01_IP="10.10.N.12"
RMQ01_IP="10.10.N.13"
MC01_IP="10.10.N.14"
DB01_IP="10.10.N.15"

ssh_kaust="$HOME/.ssh"
voti="$ssh_kaust/id_ed25519"
config="$ssh_kaust/config"
vigu=0

# 1. Kaust ~/.ssh, ainult sinu loetav
mkdir -p "$ssh_kaust"
chmod 700 "$ssh_kaust"

# 2. Võtmepaar, kui seda veel pole
if [[ -f "$voti" ]]; then
    echo "Võti on juba olemas: $voti"
else
    ssh-keygen -t ed25519 -N "" -f "$voti" -C "kasutaja@control"
fi

# 3. config-fail olemas ja ainult sinu loetav
touch "$config"
chmod 600 "$config"

# 4.–5. Üks masin: nimi config-faili, võti masinasse, masina nimi
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

    # Masina nimi ja (ainult esimesel korral) uued hostivõtmed. sudo küsib parooli.
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

??? note "Mis on skriptis uut (lühidalt)"

    | Kirjutis | Tähendus |
    |---|---|
    | `#!/usr/bin/env bash` | shebang: seda faili loeb Bash |
    | `WEB01_IP="10.10.N.11"` | muutuja; võrdusmärgi ümber pole tühikuid |
    | `"$voti"` | muutuja väärtus, jutumärkides, et tee jääks üheks tervikuks |
    | `if [[ -f "$voti" ]]` | kas selline fail on olemas? |
    | `seadista() { ... }` | **funktsioon**: käskude rühm nimega, mida saab mitu korda kasutada |
    | `$1`, `$2` | funktsiooni esimene ja teine argument: `seadista web01 "$WEB01_IP"` |
    | `>>` | lisab faili lõppu (`>` kirjutaks üle) |
    | `|| vigu=$((vigu + 1))` | kui eelmine käsk ebaõnnestus, suurenda vigade arvu |
    | `exit 1` | skript lõpeb veaga, et ka teine programm saaks sellest aru |

    Bashi põhimõisted on [loengu](loeng.md#5-bash-kui-esimene-samm) 5. peatükis.

Enne käivitamist kontrolli süntaksit. See loeb skripti läbi, aga ei käivita midagi:

```bash
bash -n ~/ssh-seadistus.sh && echo "süntaks korras"
```

## A4 · Käivita ja vasta küsimustele

```bash
bash ~/ssh-seadistus.sh
```

Iga masina juures küsitakse parooli kaks korda: esmalt `ssh-copy-id` (et võti masinasse viia), siis `sudo` (et panna nimi ja uued hostivõtmed). Sisesta ühine parool, mille said juhendajalt.

??? success "Oodatav tulemus"

    ```
    === web01 (10.10.N.11) ===
    config: lisatud web01
    kasutaja@10.10.N.11's password:
    Number of key(s) added: 1
    [sudo] password for kasutaja:
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

## A5 · Käivita teist korda

Ennusta enne: mida skript teisel korral teeb? Kas küsib parooli? Kas lisab config-faili topelt read?

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

    Võtit ei tehta uuesti, config-faili ei lisata midagi ja `ssh-copy-id` ei küsi parooli, sest võti on juba masinas. `sudo` võib parooli veel küsida, sest nime panemine ei kontrolli enne, kas nimi on juba õige. Skript on peaaegu idempotentne: teine käivitus ei muuda midagi, aga teeb osa tööd siiski uuesti.

??? question "Mõtle (valikuline)"

    Kuidas muudaksid funktsiooni nii, et `hostnamectl` käivitatakse ainult siis, kui masina nimi pole veel õige? Vihje: `ssh -n "$nimi" hostname` annab praeguse nime.

## A6 · Proovi ise

```bash
cat ~/.ssh/config
ssh web01
hostname
exit
```

??? success "Oodatav tulemus"

    `cat` näitab viit `Host` plokki. `ssh web01` logib sisse ilma parooli küsimata, prompt on `kasutaja@web01`. `exit` viib tagasi control node'ile.

!!! warning "Privaatvõti ei lahku control node'ilt"

    `~/.ssh/id_ed25519` (ilma `.pub`-ita) on sinu privaatvõti. Seda ei kopeerita kuhugi, ei panda Giti ega saadeta kellelegi. Avaliku võtme (`.pub`) võib jagada.

## A7 · Võti GitHubi ja kursuse repo

Control node'i võtmega saad ka GitHubiga parooli ja tokenita suhelda. Kuva avalik võti:

```bash
cat ~/.ssh/id_ed25519.pub
```

GitHubis: profiilipilt → **Settings → SSH and GPG keys → New SSH key**. *Title:* `control`, kleebi kogu rida, **Add SSH key**. Kontrolli:

```bash
ssh -T git@github.com
```

??? success "Oodatav tulemus"

    Esimesel korral kinnita `yes`, siis:

    ```
    Hi <sinu-github-kasutaja>! You've successfully authenticated, but GitHub does not provide shell access.
    ```

Ava [Classroom 50 ülesanne](https://classroom50.org/hkhk-tk/is126-automatiseerimine/assignments) ja võta see vastu. Sulle tekib privaatne repo orgis `hkhk-tk`. Repo lehel: **Code → SSH**, kopeeri aadress.

```bash
git config --global user.name "Eesnimi Perenimi"
git config --global user.email "sinu@email.ee"
cd ~
git clone git@github.com:hkhk-tk/<sinu-repo>.git kursus
cd ~/kursus
mkdir -p k01
```

Kõik selle kohtumise failid lähevad kausta `~/kursus/k01/`.

## Veaotsing

| Mida näed | Põhjus | Mida teha |
|---|---|---|
| `Connection timed out` | vale IP või masin ei tööta | kontrolli IP-d tabelis ja skripti alguses |
| `Permission denied (publickey,password)` | vale parool | proovi uuesti, kasutaja on `kasutaja` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | masin loodi uuesti | `ssh-keygen -R <ip>`, siis käivita skript uuesti |
| `Bad owner or permissions on ~/.ssh/config` | config on teistele loetav | `chmod 600 ~/.ssh/config` |
| kontrollis `VIGA ... ei vasta ilma paroolita` | võti ei jõudnud masinasse | käivita skript uuesti ja vaata selle masina väljundit |

*Tabel 2. Levinud vead.*

??? info "Loe juurde"

    - [OpenSSH: ssh_config](https://man.openbsd.org/ssh_config) (mida config-failis olevad read tähendavad)
    - [`ssh-copy-id`](https://man.openbsd.org/ssh-copy-id)
    - [GNU Bash: Shell Functions](https://www.gnu.org/software/bash/manual/html_node/Shell-Functions.html)
    - [systemd: hostnamectl](https://www.freedesktop.org/software/systemd/man/latest/hostnamectl.html)

**Valmis, kui** skript lõpetas reaga „Valmis: kõik viis masinat töötavad.“ ja `ssh web01` logib sisse parooli küsimata.
