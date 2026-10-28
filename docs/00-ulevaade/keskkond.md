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

**Kaks parooli, mõlemad olemas, kumbagi ei muuda:**

- **kooli konto** (kasutajanimi nt `maasikas.is126`): VPN ja Proxmox;
- **masinate kasutaja** `kasutaja`: parool juhendajalt, kõigis sinu masinates sama.

**Järjekord:**

1. **VPN**: sinu arvutis.
2. **Proxmox**: brauseris. Kontrolli masinaid, leia IP-d, uuenda control node'i hostivõtmed.
3. **VS Code**: sinu arvutis. Kirjuta IP SSH config faili ja ühendu.
4. **SSH-võti**: control node'il, alles 1. praktikumis.

## 1 · VPN

**Kus:** sinu arvutis. Sinu masinad on nähtavad ainult VPN-iga, ka klassis.

**1.1 Paigalda OpenVPN.** Klassi arvutites on see juba olemas, mine sammu 1.2 juurde.

=== "Windows"

    [openvpn.net/community-downloads](https://openvpn.net/community-downloads/), fail **Windows 64-bit MSI installer**. Paigalda vaikeseadetega.

=== "macOS"

    Paigalda tasuta klient [Tunnelblick](https://tunnelblick.net/downloads.html) (Stable). Esimesel käivitusel vasta küsimusele „I have configuration files“.

=== "Linux"

    Ubuntu, Debian: `sudo apt install -y network-manager-openvpn-gnome`.

**1.2 Lisa profiil**

Salvesta e-kirjaga saadud `.ovpn` fail oma arvutisse.

=== "Windows"

    Ekraani all paremal on OpenVPN-i ikoon (monitor lukuga; kui seda pole, vaata noolekese alt). **Paremklõps → Import file…** ja vali fail.

=== "macOS"

    Tee `.ovpn` failil topeltklõps. Tunnelblick küsib, kas lisada profiil: vali **Only Me**.

=== "Linux"

    **Settings → Network → VPN → + → Import from file…** ja vali fail.

**1.3 Ühendu** kooli kasutajanime ja parooliga.

=== "Windows"

    Paremklõps OpenVPN-i ikoonil → **Connect**. Kui ühendus on üleval, muutub ikoon roheliseks.

=== "macOS"

    Ülemisel ribal Tunnelblicki ikoon → **Connect**.

=== "Linux"

    Ülemisel ribal võrguikoon → **VPN** → lülita sisse.

**Kontrolli:** ikoon on roheline (Windows) või „Connected“ (macOS, Linux).

!!! warning "Klassi arvutis"

    Tunni lõpus **katkesta VPN ja sulge OpenVPN** (paremklõps ikoonil → Disconnect, siis Exit). Muidu ei saa järgmine inimene arvutisse sisse logida.

## 2 · Proxmox: masinad ja IP-d

**Kus:** brauseris, VPN ühendatud.

**2.1 Logi sisse.** Ava `https://192.168.124.200:8006`. Brauser hoiatab sertifikaadi eest: **Advanced → Continue** (see on kooli sisevõrk, hoiatus on ootuspärane). Kasutajanimi ja parool on kooli konto omad.

**2.2 Kontrolli masinaid.** Vasakul puus on sinu kuus masinat: `control`, `web01`, `app01`, `rmq01`, `mc01`, `db01`. Igaühe ikoon peab olema roheline kolmnurgaga (töötab). Kui mõni on hall: vali see ja vajuta üleval **Start**.

**2.3 Uuenda control node'i hostivõtmed.** Masinad on kloonitud ühest mallist, nii et kõigil on samad hostivõtmed (masina „isikutunnistus“ SSH-s). Uuendame need enne esimest ühendust, siis ei hakka VS Code hiljem hoiatama.

Vali `control` → **Console**. Logi sisse: kasutaja `kasutaja` ja masinate parool (tähti ei kuvata, see on tavaline). Kirjuta:

```bash
sudo rm -f /etc/ssh/ssh_host_*
sudo ssh-keygen -A
sudo systemctl restart ssh
```

Ülejäänud viie masina hostivõtmed uuendab 1. praktikumi skript ise.

**2.4 Leia IP-d.** Samas konsoolis:

```bash
hostname -I
```

Esimene number on control node'i IP. Seda on vaja järgmises sammus. Teiste viie masina IP-sid on vaja alles 1. praktikumis.

??? question "Proxmox ei lase sisse?"

    Kirjuta kategooriasse **Küsimused** või küsi juhendajalt: saad IP-d temalt ja hostivõtmed uuendatakse sinu eest. Jätka sammuga 3.

## 3 · VS Code

**Kus:** sinu arvutis.

**3.1 Paigalda VS Code.** [code.visualstudio.com](https://code.visualstudio.com/), vaikeseadetega (macOS-is lohista **Applications** kausta).

**3.2 Lisa laiendus.** Vasakul **Extensions** (nelja ruuduga ikoon), otsi `Remote - SSH` (Microsoft), **Install**.

**3.3 Kirjuta control node'i aadress SSH config faili.** Vajuta ++f1++, kirjuta `Remote-SSH: Open SSH Configuration File` ja vali esimene fail:

- Windows: `C:\Users\<sinu nimi>\.ssh\config`
- macOS, Linux: `~/.ssh/config`

Kirjuta faili kolm rida, `HostName` asemele oma control node'i IP, ja salvesta (++ctrl+s++):

```text
Host control
    HostName 192.168.124.51
    User kasutaja
```

`Host control` on lühinimi, `HostName` on päris aadress, `User` on kasutaja masinas. Sinu arvuti ühendub ainult control node'iga, teisi masinaid siia ei kirjutata. See fail jääb kogu kursuseks samaks: ka pärast 1. praktikumi logid control node'ile parooliga.

**3.4 Ühendu.**

1. Vasakul **Remote Explorer** (monitori ikoon) → **SSH** all on `control`. Vajuta selle kõrval noolt (**Connect in Current Window**).
2. Kui küsitakse platvormi, vali **Linux**. Kinnita masina võti (**Continue**).
3. Sisesta masinate parool. VS Code paigaldab control node'ile oma osa, see võtab minuti.
4. **Terminal → New Terminal**.

**Kontrolli:** vasakul all on roheline silt **SSH: control** ja terminalis on prompt `kasutaja@control` või `kasutaja@...`. Iga terminal selles aknas on nüüd control node'il.

VS Code küsib parooli igal ühendusel. See on nii mõeldud: sinu arvutisse SSH-võtit ei tehta.

??? info "Tahan teisi masinaid VS Code'is näha"

    Tavaliselt pole vaja: Ansible teeb teistes masinates muudatused ise. Kiireim viis vaadata on control node'i aknas **Terminal → Split Terminal** ja igas terminalis `ssh web01`, `ssh db01` jne (pärast 1. praktikumi).

    Kui tahad iga masinat eraldi aknas koos failipuuga, lisa sinu arvuti config faili iga masina kohta kirje:

    ```text
    Host web01
        HostName 192.168.124.52
        User kasutaja
        ProxyJump control
    ```

    `ProxyJump control` tähendab: mine web01-sse läbi control node'i. Masin ilmub **Remote Explorer**isse nagu `control`. Parooli küsitakse kaks korda, esmalt control node'i, siis web01 oma, sest sinu arvutis SSH-võtit pole.

??? info "Termius, JetBrains või muu tööriist?"

    Võid kasutada ka [Termiust](https://termius.com/), JetBrains Gateway't või tavalist terminali. Ühendus on sama: kasutaja `kasutaja`, control node'i IP, parool.

    **Soovitan VS Code'i**, sest:

    - failid ja terminal on ühes aknas: Ansible'i failid kirjutad ja käivitad samas kohas;
    - Ansible'i ja YAML-i laiendused näitavad vigu juba kirjutades;
    - töötab ühtemoodi Windowsis, macOS-is ja Linuxis, tasuta;
    - kõik juhendid ja ekraanipildid on VS Code'iga, juhendaja saab kiiremini aidata.

    Termius on hea ainult terminaliks, failide muutmiseks peaksid kasutama `nano`-t. JetBrains on võimas, aga raskem ja kursusel seda ei näidata.

## 4 · SSH-võti

**Kus:** control node'il, **1. praktikumis**. Praegu ei tee midagi.

Sinu arvutisse SSH-võtit ei tehta. Võtmepaar tehakse control node'il 1. praktikumi skriptiga:

- `~/.ssh/id_ed25519` on **privaatvõti**. See jääb control node'ile ega lähe kuhugi.
- `~/.ssh/id_ed25519.pub` on **avalik võti**. Skript kopeerib selle viide labori masinasse, hiljem lisad selle ka GitHubi.

Pärast seda logib control node teistesse masinatesse ja GitHubi ilma paroolita. Ansible vajab just seda.

??? info "Loe juurde"

    - [VS Code: Remote Development over SSH](https://code.visualstudio.com/docs/remote/ssh)
    - [OpenSSH: ssh_config](https://man.openbsd.org/ssh_config)

## Veaotsing

| Mida näed | Põhjus | Mida teha |
|---|---|---|
| VPN küsib parooli uuesti ja ei ühendu | vale kasutajanimi või parool | kasutajanimi on kujul `perekonnanimi.is126`, parool sama mis kooli e-postil |
| Proxmox ei avane | VPN pole ühendatud | ühenda VPN, proovi uuesti |
| VS Code: `Connection timed out` | VPN pole ühendatud, masin seisab või vale IP | ühenda VPN, kontrolli Proxmoxis, et `control` töötab, kontrolli IP-d config failis |
| VS Code: `Permission denied` | vale kasutajanimi või parool | config failis `User kasutaja`, parool on masinate oma, mitte kooli konto oma |
| VS Code: `REMOTE HOST IDENTIFICATION HAS CHANGED` | hostivõtmed uuendati pärast esimest ühendust | ava VS Code'is fail `C:\Users\<sinu nimi>\.ssh\known_hosts` (macOS-is `~/.ssh/known_hosts`), kustuta read control node'i IP-ga, salvesta ja ühendu uuesti |
| VS Code jääb „Setting up SSH Host“ juurde | ühendus katkes poole pealt | ++f1++ → **Remote-SSH: Kill VS Code Server on Host**, proovi uuesti |
| macOS-is Tunnelblick ei ühendu | süsteemilaiendus lubamata | **System Settings → Privacy & Security → Allow** |

*Tabel 1. Levinud vead.*
