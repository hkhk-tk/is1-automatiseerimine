---
tags:
  - SSH
  - Info
---

# Töökeskkonna ettevalmistus

!!! abstract "Eesmärgid"

    Enne esimest kohtumist, oma arvutis. Lõpuks:

    - ühendub VPN kooli laborivõrku;
    - avab VS Code terminali otse sinu control node'il.

**Control node on virtuaalmasin kooli Proxmoxis.** See ei ole sinu sülearvuti ega klassi arvuti. Sinu arvuti, olgu isiklik või kooli oma, on ainult aken sinna: VPN viib kooli võrku, VS Code avab seal terminali.

Kõik kursuse käsud jooksevad control node'il. Sinu arvutisse on vaja ainult VPN-i ja VS Code'i. Käsurida oma arvutis (PowerShell, Terminal) ega WSL-i pole vaja.

<figure style="max-width:780px;margin:.8em auto" class="lx" markdown="0">
<svg viewBox="0 0 780 415" role="img" aria-label="Vasakul sinu pool: kodune või klassi arvuti. Paremal kooli laborivõrk, kuhu pääseb ainult VPN-tunneliga. Seal on Proxmox ja selles sinu kuus virtuaalmasinat. All internetis GitHub." xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-default-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.18;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .zl{fill:var(--md-default-fg-color);fill-opacity:.04;stroke:var(--md-default-fg-color--light);stroke-width:1.2;stroke-dasharray:6 4}.lx .zr{fill:var(--md-primary-fg-color);fill-opacity:.07;stroke:var(--md-primary-fg-color);stroke-width:1.4;stroke-dasharray:6 4}.lx .pve{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--light);stroke-width:1.2}.lx .vpn{fill:var(--md-primary-fg-color);stroke:none}.lx .vt{fill:var(--md-primary-bg-color,#fff);font-size:14px;font-weight:700}.lx .t{fill:var(--md-default-fg-color);font-size:13px;font-weight:700;letter-spacing:.06em}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:12.5px}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .v{stroke:var(--md-primary-fg-color);stroke-width:2.2;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxk" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="zl" x="10" y="10" width="210" height="320" rx="10"/><text class="t" x="115" y="36" text-anchor="middle">SINU POOL</text><text class="s" x="115" y="54" text-anchor="middle">kodu-WiFi või klassi võrk</text>
<rect class="box" x="25" y="80" width="180" height="62" rx="8"/><text class="b" x="115" y="106" text-anchor="middle">Kodus: sinu arvuti</text><text class="s" x="115" y="126" text-anchor="middle">VS Code · OpenVPN</text>
<rect class="box" x="25" y="210" width="180" height="62" rx="8"/><text class="b" x="115" y="236" text-anchor="middle">Klassis: kooli arvuti</text><text class="s" x="115" y="256" text-anchor="middle">VS Code · OpenVPN</text>
<rect class="zr" x="300" y="10" width="470" height="320" rx="10"/><text class="t" x="535" y="36" text-anchor="middle">KOOLI LABORIVÕRK</text><text class="s" x="535" y="54" text-anchor="middle">ligi ainult VPN-iga</text>
<rect class="pve" x="315" y="68" width="440" height="250" rx="8"/><text class="b" x="330" y="92">Proxmox</text><text class="s" x="330" y="110">192.168.124.200:8006 · sinu 6 virtuaalmasinat</text>
<path class="v" d="M205,111 C225,111 230,175 240,180"/><path class="v" d="M205,241 C225,241 230,185 240,180"/>
<rect class="vpn" x="236" y="164" width="56" height="32" rx="16"/><text class="vt" x="264" y="185" text-anchor="middle">VPN</text>
<line class="v" x1="292" y1="180" x2="336" y2="183" marker-end="url(#lxk)"/>
<text class="s" x="264" y="216" text-anchor="middle">+ SSH</text><text class="s" x="264" y="231" text-anchor="middle">parooliga</text>
<rect class="hi" x="340" y="150" width="150" height="70" rx="8"/><text class="b" x="415" y="180" text-anchor="middle">control</text><text class="s" x="415" y="200" text-anchor="middle">siin on SSH-võti</text>
<line class="a" x1="490" y1="185" x2="580" y2="185"/><line class="a" x1="580" y1="134" x2="580" y2="286"/><text class="s" x="535" y="177" text-anchor="middle">SSH-võti</text>
<rect class="box" x="600" y="120" width="140" height="28" rx="6"/><text class="b" x="670" y="139" text-anchor="middle">web01</text><line class="a" x1="580" y1="134" x2="598" y2="134" marker-end="url(#lxk)"/><rect class="box" x="600" y="158" width="140" height="28" rx="6"/><text class="b" x="670" y="177" text-anchor="middle">app01</text><line class="a" x1="580" y1="172" x2="598" y2="172" marker-end="url(#lxk)"/><rect class="box" x="600" y="196" width="140" height="28" rx="6"/><text class="b" x="670" y="215" text-anchor="middle">rmq01</text><line class="a" x1="580" y1="210" x2="598" y2="210" marker-end="url(#lxk)"/><rect class="box" x="600" y="234" width="140" height="28" rx="6"/><text class="b" x="670" y="253" text-anchor="middle">mc01</text><line class="a" x1="580" y1="248" x2="598" y2="248" marker-end="url(#lxk)"/><rect class="box" x="600" y="272" width="140" height="28" rx="6"/><text class="b" x="670" y="291" text-anchor="middle">db01</text><line class="a" x1="580" y1="286" x2="598" y2="286" marker-end="url(#lxk)"/>
<line class="a" x1="415" y1="220" x2="415" y2="353" marker-end="url(#lxk)"/><text class="s" x="425" y="345">git · SSH-võti</text>
<rect class="box" x="340" y="355" width="150" height="45" rx="8"/><text class="b" x="415" y="383" text-anchor="middle">GitHub</text><text class="s" x="505" y="383">internetis</text>
</svg>
<figcaption>Joonis 1. Vasakul sinu pool: arvuti kodus või klassis, mõlemas VS Code ja OpenVPN. Paremal kooli laborivõrk, kuhu pääseb ainult VPN-iga. Seal on Proxmox ja sinu kuus masinat. Control node'ile ühendud parooliga, control node'ilt edasi SSH-võtmega.</figcaption>
</figure>

**Kaks parooli, kumbagi ei muuda:**

- **kooli konto** (nt `maasikas.is126`): VPN ja Proxmox;
- **masinate kasutaja** `kasutaja`: parool juhendajalt.

## 1 · VPN

Sinu arvutis. Klassi arvutites on OpenVPN juba olemas, alusta sammust 1.2.

**1.1 Paigalda OpenVPN**

=== "Windows"

    [openvpn.net/community-downloads](https://openvpn.net/community-downloads/), **Windows 64-bit MSI installer**, vaikeseadetega.

=== "macOS"

    [Tunnelblick](https://tunnelblick.net/downloads.html) (Stable). Küsimusele vasta „I have configuration files“.

=== "Linux"

    `sudo apt install -y network-manager-openvpn-gnome`

**1.2 Lisa e-kirjaga saadud `.ovpn` fail**

=== "Windows"

    OpenVPN-i ikoon ekraani all paremal → **paremklõps → Import file…**

=== "macOS"

    Topeltklõps failil → **Only Me**.

=== "Linux"

    **Settings → Network → VPN → + → Import from file…**

**1.3 Ühendu** kooli kasutajanime ja parooliga: ikoon → **Connect**. Ikoon läheb roheliseks.

!!! warning "Klassi arvutis"

    Tunni lõpus **Disconnect** ja **Exit**. Muidu ei saa järgmine inimene arvutisse sisse.

## 2 · Proxmox

Brauseris, VPN ühendatud.

**2.1 Logi sisse:** `https://192.168.124.200:8006`, kooli kasutajanimi ja parool. Sertifikaadi hoiatus: **Advanced → Continue**.

**2.2 Kontrolli:** vasakul on kuus masinat (`control`, `web01`, `app01`, `rmq01`, `mc01`, `db01`), kõik rohelised. Hall masin: vali see → **Start**.

**2.3 Control node'i konsool:** `control` → **Console**, logi sisse `kasutaja` ja parooliga. Kirjuta:

```bash
sudo rm -f /etc/ssh/ssh_host_*
sudo ssh-keygen -A
sudo systemctl restart ssh
hostname -I
```

Viimase käsu esimene number on **control node'i IP**. Seda on vaja järgmises sammus.

??? info "Mida need käsud tegid?"

    Masinad on kloonitud ühest mallist, seega on kõigil samad hostivõtmed (masina „isikutunnistus“ SSH-s). Esimesed kolm käsku teevad control node'ile uued, enne kui VS Code sellega esimest korda ühendub. Ülejäänud viie masina võtmed uuendab 1. praktikumi skript ise.

??? question "Proxmox ei lase sisse?"

    Kirjuta kategooriasse **Küsimused**. IP saad juhendajalt, jätka sammuga 3.

## 3 · VS Code

Sinu arvutis.

**3.1** Paigalda [VS Code](https://code.visualstudio.com/) ja laiendus **Remote - SSH** (vasakul **Extensions**).

**3.2** ++f1++ → `Remote-SSH: Open SSH Configuration File` → vali esimene fail. Kirjuta sinna oma control node'i IP-ga ja salvesta:

```text
Host control
    HostName 192.168.125.10
    User kasutaja
```

**3.3** Vasakul **Remote Explorer** → `control` → **Connect**. Platvorm **Linux**, **Continue**, masinate parool.

**3.4** **Terminal → New Terminal**.

**Kontrolli:** all vasakul on **SSH: control**, terminalis `kasutaja@control` või `kasutaja@...`. See terminal on control node'il.

??? info "Mis on SSH config fail ja miks küsitakse alati parooli?"

    Fail on Windowsis `C:\Users\<sinu nimi>\.ssh\config`, macOS-is ja Linuxis `~/.ssh/config`. `Host` on lühinimi, `HostName` päris aadress, `User` kasutaja masinas.

    Sinu arvutis SSH-võtit pole, seega küsib VS Code parooli igal ühendusel. Nii on mõeldud. Võti tehakse 1. praktikumis control node'il: privaatvõti `~/.ssh/id_ed25519` jääb sinna, avalik võti `id_ed25519.pub` läheb viide masinasse ja GitHubi. Siis logib control node edasi ilma paroolita, ja Ansible vajab just seda.

??? info "Tahan teisi masinaid VS Code'is näha"

    Tavaliselt pole vaja: Ansible teeb muudatused ise. Kiireim viis: **Terminal → Split Terminal** ja igas `ssh web01`, `ssh db01` jne (pärast 1. praktikumi).

    Eraldi aknaks koos failipuuga lisa sinu arvuti config faili iga masina kohta:

    ```text
    Host web01
        HostName 192.168.125.11
        User kasutaja
        ProxyJump control
    ```

    `ProxyJump control`: mine läbi control node'i. Parooli küsitakse kaks korda, control node'i ja web01 oma.

??? info "Termius, JetBrains või muu tööriist?"

    Võib, ühendus on sama: `kasutaja`, control node'i IP, parool. **Soovitan VS Code'i**, sest:

    - failid ja terminal on ühes aknas;
    - Ansible'i ja YAML-i laiendused näitavad vigu juba kirjutades;
    - töötab ühtemoodi Windowsis, macOS-is ja Linuxis, tasuta;
    - kõik juhendid on VS Code'iga, juhendaja saab kiiremini aidata.

    Termiuses peaksid faile muutma `nano`-ga. JetBrains on võimas, aga raskem ja kursusel seda ei näidata.

## Kui midagi ei tööta

??? failure "VPN ei ühendu"

    Kasutajanimi on kujul `perekonnanimi.is126`, parool sama mis kooli e-postil. macOS-is: **System Settings → Privacy & Security → Allow**.

??? failure "`Connection timed out`"

    VPN pole ühendatud, masin seisab Proxmoxis või IP config failis on vale.

??? failure "`Permission denied` (parool küsiti)"

    Config failis peab olema `User kasutaja`. Parool on masinate oma, mitte kooli konto oma.

??? failure "`Permission denied (publickey)` (parooli ei küsitudki)"

    Masinas on parooliga sisselogimine keelatud. Proxmoxis masin → **Console**, logi sisse ja kirjuta:

    ```bash
    echo "PasswordAuthentication yes" | sudo tee /etc/ssh/sshd_config.d/01-parool.conf
    sudo systemctl restart ssh      # AlmaLinuxis: sudo systemctl restart sshd
    ```

    !!! danger "Ainult laboris"

        Siin on see lubatud, sest masinad on suletud võrgus, ainult VPN-iga, ja kursuse lõpus kustutatakse. **Päris serverites nii ei tehta:** robotid proovivad paroole ööpäev läbi ära arvata. Seal logitakse sisse ainult SSH-võtmega (`PasswordAuthentication no`).

??? failure "`REMOTE HOST IDENTIFICATION HAS CHANGED`"

    Ava VS Code'is fail `C:\Users\<sinu nimi>\.ssh\known_hosts` (macOS-is `~/.ssh/known_hosts`), kustuta read control node'i IP-ga, salvesta ja ühendu uuesti.

??? failure "VS Code jääb „Setting up SSH Host“ juurde"

    ++f1++ → **Remote-SSH: Kill VS Code Server on Host**, siis uuesti.
