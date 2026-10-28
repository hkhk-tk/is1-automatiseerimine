---
tags:
  - SSH
  - Info
---

# Töökeskkonna ettevalmistus

!!! abstract "Eesmärgid"

    Tee see leht läbi oma arvutis enne esimest kohtumist või kohtumise alguses. Lõpuks:

    - ühendub VPN kooli laborivõrku;
    - avab VS Code terminali otse sinu control node'il;
    - on control node'il sinu enda parool.

Sinu arvuti on ainult aken. Kõik kursuse käsud jooksevad control node'il, kooli Proxmoxis. Sinu arvutisse on vaja kaht asja: VPN-i ja VS Code'i.

??? info "Mis on PowerShell ja kas WSL-i on vaja?"

    **PowerShell** on Windowsi käsurida, sama roll mis Terminalil macOS-is. See on Windowsiga kaasas: Start → kirjuta `powershell`. Sellel lehel on seda vaja ainult paigalduseks ja ühenduse kontrolliks, kui eelistad käske klõpsamisele. Kõik saab teha ka ilma selleta.

    **WSL-i pole vaja.** Linux jookseb control node'il, mitte sinu arvutis. VS Code avab terminali otse control node'il ja kõik kursuse käsud käivad seal.

<figure style="max-width:720px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 720 200" role="img" aria-label="Sinu arvuti ühendub VPN-i ja SSH-ga control node'ile, control node SSH-ga viiele labori VM-ile ja git pushiga GitHubi" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14.5px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:13px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxk" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="10" y="50" width="200" height="70" rx="8"/><text class="b" x="110" y="80" text-anchor="middle">Sinu arvuti</text><text class="s" x="110" y="100" text-anchor="middle">VS Code, VPN</text>
<line class="a" x1="210" y1="85" x2="278" y2="85" marker-end="url(#lxk)"/><text class="s" x="244" y="76" text-anchor="middle">VPN + SSH</text>
<rect class="hi" x="280" y="50" width="180" height="70" rx="8"/><text class="b" x="370" y="80" text-anchor="middle">control node</text><text class="s" x="370" y="100" text-anchor="middle">siin jooksevad käsud</text>
<line class="a" x1="460" y1="85" x2="528" y2="85" marker-end="url(#lxk)"/><text class="s" x="494" y="76" text-anchor="middle">SSH</text>
<rect class="box" x="530" y="20" width="180" height="130" rx="8"/><text class="b" x="620" y="60" text-anchor="middle">web01 · app01</text><text class="b" x="620" y="82" text-anchor="middle">rmq01 · mc01 · db01</text><text class="s" x="620" y="110" text-anchor="middle">labori VM-id</text>
<line class="a" x1="370" y1="120" x2="370" y2="156" marker-end="url(#lxk)"/><text class="s" x="380" y="143">git push</text>
<rect class="box" x="300" y="158" width="140" height="36" rx="8"/><text class="b" x="370" y="181" text-anchor="middle">GitHub</text>
</svg>
<figcaption>Joonis 1. Kus miski jookseb.</figcaption>
</figure>

Kõigis VM-ides on kasutaja `kasutaja`. Juhendaja annab sulle VPN-i andmed, oma VM-ide IP-d ja parooli. Kirjuta need üles:

| Nimi | IP |
|---|---|
| control | |
| web01 | |
| app01 | |
| rmq01 | |
| mc01 | |
| db01 | |

*Tabel 1. Sinu VM-id.*

## 1 · VPN

Laborivõrk on nähtav ainult VPN-iga, nii klassis kui kodus. Kooli VPN kasutab FortiClienti (SSL-VPN).

<!-- KOOLITAJALE: kontrolli enne avaldamist, kas kooli VPN on FortiClient SSL-VPN ja kas port on 443. -->

1. Paigalda klient.

    === "Windows"

        Lae alla **FortiClient VPN** (tasuta, ainult VPN) aadressilt [fortinet.com/support/product-downloads](https://www.fortinet.com/support/product-downloads#vpn) või PowerShellis:

        ```powershell
        winget install -e --id Fortinet.FortiClientVPN
        ```

    === "macOS"

        Lae alla **FortiClient VPN** aadressilt [fortinet.com/support/product-downloads](https://www.fortinet.com/support/product-downloads#vpn) ja paigalda. Esimesel käivitusel küsib macOS luba: **System Settings → Privacy & Security** → luba Fortineti süsteemilaiendus ja nõustu VPN-i seadistuse lisamisega.

    === "Linux"

        Lihtsaim on `openfortivpn`, mis on distro repos:

        ```bash
        sudo apt install openfortivpn      # Debian, Ubuntu
        sudo dnf install openfortivpn      # Fedora, Rocky, Alma
        ```

2. Seadista ja ühenda.

    === "Windows"

        FortiClient → **Remote Access → Configure VPN**: tüüp **SSL-VPN**, Connection Name `HKHK labor`, Remote Gateway = VPN-i aadress juhendajalt. Salvesta, sisesta kasutajanimi ja parool, **Connect**.

    === "macOS"

        Sama mis Windowsis: **Remote Access → Configure VPN**, **SSL-VPN**, Remote Gateway = VPN-i aadress, **Connect**.

    === "Linux"

        ```bash
        sudo openfortivpn <vpn-aadress>:443 -u <vpn-kasutaja>
        ```

        Terminal jääb lahti, kuni VPN on ühendatud. Katkestamiseks ++ctrl+c++. Kui `openfortivpn` keeldub sertifikaadi tõttu ja trükib `--trusted-cert <räsi>`, võrdle räsi juhendaja antuga ja lisa see käsule.

3. Kontrolli, et control node'i SSH-port vastab:

    === "Windows"

        ```powershell
        Test-NetConnection <control-ip> -Port 22
        ```

    === "macOS"

        ```bash
        nc -vz <control-ip> 22
        ```

    === "Linux"

        ```bash
        nc -vz <control-ip> 22
        ```

??? success "Oodatav tulemus"

    Windowsis `TcpTestSucceeded : True`, macOS-is ja Linuxis `succeeded` või `open`. Kui ühendus aegub, pole VPN ühendatud.

## 2 · VS Code ja Remote-SSH

1. Paigalda VS Code.

    === "Windows"

        ```powershell
        winget install -e --id Microsoft.VisualStudioCode
        ```

        Või lae alla [code.visualstudio.com](https://code.visualstudio.com/). Windows 10 ja 11 sisaldavad SSH klienti. Kui PowerShellis `ssh -V` annab vea, paigalda see: **Settings → System → Optional features → Add a feature → OpenSSH Client**.

    === "macOS"

        ```bash
        brew install --cask visual-studio-code
        ```

        Või lae alla [code.visualstudio.com](https://code.visualstudio.com/) ja lohista **Applications** kausta.

    === "Linux"

        Ubuntu ja Debian: `.deb` aadressilt [code.visualstudio.com](https://code.visualstudio.com/) ja `sudo apt install ./code_*.deb`. Teised distrod: [Microsofti juhend](https://code.visualstudio.com/docs/setup/linux).

2. Paigalda laiendus **Remote - SSH** (`ms-vscode-remote.remote-ssh`): vasakul **Extensions** (++ctrl+shift+x++, macOS-is ++cmd+shift+x++), otsi `Remote - SSH`, **Install**.

3. Ühendu: ++f1++ → **Remote-SSH: Connect to Host...** → `kasutaja@<control-ip>`. Kui küsitakse platvormi, vali **Linux**. Kinnita host key (**Continue**) ja sisesta parool. VS Code paigaldab control node'ile oma serveri, see võtab minuti.

4. Ava terminal (**Terminal → New Terminal**).

??? success "Oodatav tulemus"

    Vasakul all on roheline silt **SSH: <control-ip>**. Iga terminal, mille nüüd avad, on control node'il, mitte sinu arvutis.

??? info "Ilma VS Code'ita"

    Kõik töötab ka tavalise terminaliga (PowerShell, Terminal): `ssh kasutaja@<control-ip>`. VS Code annab lisaks failipuu ja redaktori, juhendid eeldavad seda.

## 3 · Oma parool

Juhendajalt saadud parool on kõigil sama ja masinad on ühes võrgus. Vaheta see kohe ära, control node'il:

```bash
passwd
```

`passwd` küsib vana parooli, siis kaks korda uut. Liiga lihtsa parooli lükkab süsteem tagasi (`BAD PASSWORD`). Vali vähemalt 8 märki, tähed ja numbrid segamini.

Labori VM-ide paroolid vahetad ja võtmed seadistad esimese kohtumise laboris. Seal teed control node'il SSH-võtme, viid selle labori VM-idele ja GitHubi.

??? info "Ilma paroolita ühendus oma arvutist (valikuline)"

    Kui VS Code küsib parooli iga kord, vii oma arvuti võti control node'ile.

    === "Windows"

        ```powershell
        ssh-keygen -t ed25519
        type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh kasutaja@<control-ip> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
        ```

    === "macOS"

        ```bash
        ssh-keygen -t ed25519
        ssh-copy-id kasutaja@<control-ip>
        ```

    === "Linux"

        ```bash
        ssh-keygen -t ed25519
        ssh-copy-id kasutaja@<control-ip>
        ```

    `ssh-keygen` küsimustele vajuta ++enter++. Järgmine ühendus ei küsi parooli.

??? info "Loe juurde"

    - [VS Code: Remote Development over SSH](https://code.visualstudio.com/docs/remote/ssh)
    - [OpenSSH Windowsis](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse)
    - [VS Code: Remote-SSH tõrkeotsing](https://code.visualstudio.com/docs/remote/troubleshooting#_troubleshooting-hanging-or-failing-connections)

## Veaotsing

| Mida näed | Põhjus | Mida teha |
|---|---|---|
| `Connection timed out` | VPN pole ühendatud või vale IP | ühenda VPN, kontrolli IP-d |
| `Permission denied` | vale kasutajanimi või parool | kasutaja on `kasutaja`; pärast `passwd`-d kasuta uut parooli |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | VM loodi uuesti | `ssh-keygen -R <control-ip>` ja ühendu uuesti |
| VS Code jääb „Setting up SSH Host“ juurde | ühendus katkes poole pealt | ++f1++ → **Remote-SSH: Kill VS Code Server on Host**, proovi uuesti |
| macOS-is VPN ei ühendu | süsteemilaiendus lubamata | **System Settings → Privacy & Security → Allow** |

*Tabel 2. Levinud vead.*

Kui kasutad Windowsis WSL-i, tee see leht siiski Windowsi enda PowerShellis. VPN-i ja WSL-i koos seadistamine on eraldi teema ja klassis seda vaja pole.

## Kokkuvõte

VPN avab laborivõrgu nii klassis kui kodus. VS Code Remote-SSH avab terminali ja failid control node'il, nii et kursuse käsud jooksevad seal, mitte sinu arvutis. Ühine parool on vahetatud, võtmed tulevad esimeses laboris.
