---
tags:
  - SSH
  - Bash
  - Praktikum
---

# 1. Keskkond: SSH-võti ja ühendus masinatega

Selles osas seadistad control node'ist paroolita SSH-ühenduse viie masinaga. Ansible vajab just sellist ühendust.

[Töökeskkond](../00-ulevaade/keskkond.md) peab olema valmis. Hoia Proxmox brauseris lahti: masina IP-aadress on vahelehel **Summary** real **IPs**.

## A1 · Control node'i nimi

```bash
sudo hostnamectl set-hostname control
exec bash
```

Prompt on nüüd `kasutaja@control:~$`.

## A2 · Üks masin käsitsi

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

Loo võtmepaar, lisa web01 SSH konfiguratsioonifaili, kopeeri avalik võti masinasse ja määra masina nimi. Asenda IP-aadress Proxmoxist leitud aadressiga:

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
printf 'Host web01\n    HostName 192.168.125.11\n    User kasutaja\n' >> ~/.ssh/config
ssh-copy-id web01
ssh web01 "sudo hostnamectl set-hostname web01"
ssh web01 hostname
```

`ssh-copy-id` küsib esimesel korral kinnitust (`yes`) ja parooli. Viimane käsk peab kuvama `web01` ilma parooli küsimata.

## A3 · Ülejäänud masinad skriptiga

Sama töö tuleks teha veel neli korda. Skript teeb selle kõigi viie masinaga korraga.

??? example "Skript `~/ssh-seadistus.sh`"

    Loo control node'is fail `~/ssh-seadistus.sh`, kopeeri sinna skript ja asenda IP-aadressid:

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

```bash
bash ~/ssh-seadistus.sh
```

Lõpus peab olema rida `Valmis: kõik viis masinat töötavad.`

Privaatvõti `~/.ssh/id_ed25519` jääb control node'i. Seda ei kopeerita mujale ega lisata Giti.

## A4 · Võti GitHubi ja kursuse repositoorium

Lisa sama avalik võti GitHubi, siis töötab `git` ilma paroolita. Kuva võti:

```bash
cat ~/.ssh/id_ed25519.pub
```

Ava GitHubis **Settings → SSH and GPG keys → New SSH key**, kleebi võti väljale *Key* ja salvesta. Kontrolli:

```bash
ssh -T git@github.com
```

Vastus algab `Hi <kasutajanimi>!`.

Võta vastu [Classroom 50 ülesanne](https://classroom50.org/hkhk-tk/is126-automatiseerimine/assignments). GitHubis luuakse sulle repositoorium. Kopeeri selle aadress (**Code → SSH**) ja klooni see:

```bash
git config --global user.name "Eesnimi Perenimi"
git config --global user.email "sinu@email.ee"
git clone git@github.com:hkhk-tk/<sinu-repo>.git ~/kursus
mkdir -p ~/kursus/k01
```

Selle kohtumise failid lähevad kausta `~/kursus/k01/`.

## Kui midagi ei tööta

| Viga | Mida teha |
|---|---|
| `Connection timed out` | kontrolli IP-aadressi Proxmoxis ja et masin töötab |
| `Permission denied` | kontrolli parooli ja kasutajanime `kasutaja` |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | `ssh-keygen -R <ip>` ja proovi uuesti |

*Tabel 1. Levinud vead.*

**Valmis, kui** `ssh web01 hostname` (ja sama teiste masinatega) vastab ilma parooli küsimata.
