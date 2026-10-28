---
tags:
  - SSH
  - Info
---

# Töökeskkonna ettevalmistus

!!! abstract "Eesmärgid"

    Enne esimest kohtumist, oma arvutis. Lõpuks:

    - ühendub VPN kooli laborivõrku;
    - tead Proxmoxist oma masinate IP-sid;
    - avab VS Code terminali otse sinu control node'il;
    - on control node'il sinu enda parool ja oma hostivõtmed.

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

Vaja läheb:

| Mis | Kust |
|---|---|
| kooli kasutajanimi ja parool | sama, millega logid kooli e-posti (kasutajanimi nt `silmberg.is126`) |
| VPN-i profiil (fail `.ovpn`) | e-kirjaga eraldi |
| VM-ide kasutaja ja parool | kasutaja `kasutaja`, parooli annab juhendaja |

*Tabel 1. Mida vajad.*

## 1 · VPN

Kooli Proxmox ja sinu masinad on nähtavad ainult VPN-iga, ka klassis. Kool kasutab **OpenVPN**-i.

### 1.1 Paigalda OpenVPN

=== "Windows"

    Koolis: võrgukettalt `\\192.168.5.2\Jagatud\openvpn`. Kodus: [openvpn.net/community-downloads](https://openvpn.net/community-downloads/), fail **Windows 64-bit MSI installer**. Paigalda vaikeseadetega.

=== "macOS"

    Paigalda tasuta klient [Tunnelblick](https://tunnelblick.net/downloads.html) (Stable). Esimesel käivitusel vasta küsimusele „I have configuration files“.

=== "Linux"

    ```bash
    sudo apt install -y openvpn
    ```

### 1.2 Lisa HKHK profiil

Salvesta e-kirjaga saadud `.ovpn` fail oma arvutisse.

=== "Windows"

    Ekraani all paremal on OpenVPN-i ikoon (monitor lukuga; kui seda pole, vaata noolekese alt). **Paremklõps → Import file…** ja vali fail.

=== "macOS"

    Tee `.ovpn` failil topeltklõps. Tunnelblick küsib, kas lisada profiil: vali **Only Me**.

=== "Linux"

    Profiili pole vaja importida, see antakse ühendumisel käsule kaasa.

### 1.3 Ühendu

Kasutajanimi ja parool on **sama mis kooli kontol** (näiteks `silmberg.is126`).

=== "Windows"

    Paremklõps OpenVPN-i ikoonil → **Connect**. Kui ühendus on üleval, muutub ikoon roheliseks.

=== "macOS"

    Ülemisel ribal Tunnelblicki ikoon → **Connect HKHK**.

=== "Linux"

    ```bash
    sudo openvpn --config <fail>.ovpn
    ```

    Terminal jääb lahti, kuni VPN on ühendatud. Katkestamiseks ++ctrl+c++.

### 1.4 Kontrolli

Ava brauseris `https://192.168.124.200:8006`. Kui leht avaneb (ka hoiatusega), töötab VPN.

!!! warning "Klassi arvutis"

    Tunni lõpus **katkesta VPN ja sulge OpenVPN** (paremklõps ikoonil → Disconnect, siis Exit). Muidu ei saa järgmine inimene arvutisse sisse logida.

## 2 · Proxmox: sinu masinate IP-d

1. Ava `https://192.168.124.200:8006`. Brauser hoiatab sertifikaadi eest: see on kooli enda server, vajuta **Advanced → Proceed** (või **Täpsemalt → Jätka**).
2. Logi sisse kooli kasutajanime ja parooliga. **Realm** on kooli domeen; kui sa pole kindel, küsi juhendajalt.
3. Vasakul puus on sinu masinad. Klõpsa masinal → **Summary**. Real **IPs** on selle IP-aadress.

Kirjuta IP-d üles, neid läheb vaja kogu kursusel:

| Masin | IP |
|---|---|
| control | |
| web01 | |
| app01 | |
| rmq01 | |
| mc01 | |
| db01 | |

*Tabel 2. Sinu masinad.*

## 3 · VS Code ja Remote-SSH

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

## 4 · Esimene sisselogimine: parool ja hostivõtmed

Need kaks asja teed control node'il **üks kord**, VS Code'i terminalis.

### 4.1 Oma parool

Juhendajalt saadud parool on kõigil sama. Vaheta see:

```bash
passwd
```

`passwd` küsib vana parooli, siis kaks korda uut. Liiga lihtsa parooli lükkab süsteem tagasi (`BAD PASSWORD`). Vali vähemalt 8 märki, tähed ja numbrid segamini.

### 4.2 Oma hostivõtmed

Kõik masinad on tehtud samast mallist, seega on neil sama **hostivõti**: SSH ei saa nii aru, kas räägid päriselt oma masinaga. Tee control node'ile uued võtmed:

```bash
sudo rm -f /etc/ssh/ssh_host_*
sudo ssh-keygen -A
sudo systemctl restart ssh
```

Nüüd tunneb sinu arvuti control node'i vana võtme järgi ja järgmine ühendus annab hoiatuse. Sulge VS Code'i ühendus (vasakul all roheline silt → **Close Remote Connection**) ja kustuta vana võti **oma arvuti** terminalis (Windowsis PowerShell):

```bash
ssh-keygen -R <control-ip>
```

Ühendu VS Code'iga uuesti ja kinnita uus võti (**Continue**).

??? success "Oodatav tulemus"

    VS Code ühendub, küsib uut parooli ja terminal avaneb control node'il. Labori masinatel (web01 … db01) uuendab hostivõtmed 1. praktikumi skript ise.

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
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | hostivõti muutus (samm 4.2) või VM loodi uuesti | oma arvutis `ssh-keygen -R <control-ip>` ja ühendu uuesti |
| VPN küsib parooli uuesti ja ei ühendu | vale kasutajanimi või parool | kasutajanimi on kujul `perenimi.is126`, parool sama mis kooli e-postil |
| Proxmoxi leht ei avane | VPN pole ühendatud | ühenda VPN (samm 1.3) |
| VS Code jääb „Setting up SSH Host“ juurde | ühendus katkes poole pealt | ++f1++ → **Remote-SSH: Kill VS Code Server on Host**, proovi uuesti |
| macOS-is Tunnelblick ei ühendu | süsteemilaiendus lubamata | **System Settings → Privacy & Security → Allow** |

*Tabel 3. Levinud vead.*

Kui kasutad Windowsis WSL-i, tee see leht siiski Windowsi enda PowerShellis. VPN-i ja WSL-i koos seadistamine on eraldi teema ja seda pole vaja.

## Kokkuvõte

VPN avab kooli laborivõrgu nii klassis kui kodus, Proxmoxist näed oma masinate IP-sid ja VS Code avab terminali control node'il. Control node'il on sinu parool ja oma hostivõtmed; labori masinad seadistad 1. praktikumis.
