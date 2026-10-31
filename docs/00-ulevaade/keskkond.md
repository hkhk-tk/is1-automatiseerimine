---
tags:
  - SSH
  - Info
---

# Töökeskkonna ettevalmistus

!!! abstract "Eesmärgid"

    Enne esimest tundi seadista oma arvutis VPN ja VS Code. Pärast seadistamist saad:

    - luua VPN-ühenduse kooli laborivõrguga;
    - avada VS Code'is terminali, mis töötab control node'is.

**Control node on virtuaalmasin, mis töötab kooli Proxmoxi serveris.** See ei asu sülearvutis ega klassi arvutis.

Oma arvutit kasutad ainult ühenduse loomiseks. Kõigepealt loob VPN ühenduse kooli laborivõrguga, seejärel ühendub VS Code SSH kaudu control node'iga.

Kõik kursuse käsud käivitad control node'is. Oma arvutisse on vaja paigaldada ainult VPN-i klient ja VS Code. WSL-i ega oma arvuti käsurida (PowerShell, Terminal) ei ole kursuse ülesannete tegemiseks vaja.

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
<figcaption>Joonis 1. Vasakul on õppija arvuti kodus või klassis, kummaski VS Code ja OpenVPN. Paremal on kooli laborivõrk, kuhu pääseb ainult VPN-i kaudu. Selles võrgus töötab Proxmox ja seal on kuus virtuaalmasinat. Control node'iga ühendud parooliga. Pärast 1. praktikumi ühendub control node teiste masinatega SSH-võtmega.</figcaption>
</figure>

Kursusel on kaks parooli. Kumbagi ei ole vaja muuta:

- **kooli konto** (näiteks `maasikas.is126`): kasutajanimi ja parool, mille said kooli e-kirjaga. Sama kontoga logid sisse kooli Gmaili, VPN-i ja Proxmoxi;
- **virtuaalmasinate kasutaja** `kasutaja` parooli leiad [arutelu teatest „Virtuaalmasinate kasutaja ja parool“](https://github.com/hkhk-tk/is126-arutelu/discussions/5).

## 1 · VPN

Need sammud teed oma arvutis. Klassi arvutites on OpenVPN juba paigaldatud, seal alusta sammust 1.2.

**1.1 Paigalda OpenVPN**

=== "Windows"

    Laadi alla [openvpn.net/community-downloads](https://openvpn.net/community-downloads/) lehelt **Windows 64-bit MSI installer** ja paigalda see vaikeseadetega.

=== "macOS"

    Laadi alla [Tunnelblick](https://tunnelblick.net/downloads.html) (Stable) ja paigalda see. Kui paigaldaja küsib konfiguratsioonifailide kohta, vali „I have configuration files“.

=== "Linux"

    `sudo apt install -y network-manager-openvpn-gnome`

**1.2 Lisa VPN-i profiilifail.** Laadi alla manus `HKHK-OpenVPN.zip` arutelu teatest [„VPN-i profiilifail“](https://github.com/hkhk-tk/is126-arutelu/discussions/2), paki see lahti ja lisa `.ovpn` fail OpenVPN-i:

=== "Windows"

    Tee ekraani paremas alanurgas OpenVPN-i ikoonil paremklõps ja vali **Import file…**.

=== "macOS"

    Tee failil topeltklõps ja vali **Only Me**.

=== "Linux"

    Ava **Settings → Network → VPN**, vajuta **+** ja vali **Import from file…**.

**1.3 Loo ühendus.** Vali OpenVPN-i ikoonil **Connect** ja sisesta kooli konto kasutajanimi ja parool. Kui ühendus on loodud, muutub ikoon roheliseks.

!!! warning "Klassi arvutis"

    Tunni lõpus vali **Disconnect** ja seejärel **Exit**. Muidu ei saa järgmine kasutaja arvutisse sisse logida.

## 2 · Proxmox

Ava Proxmox brauseris. VPN-ühendus peab olema aktiivne.

**2.1 Logi sisse.** Ava `https://192.168.124.200:8006` ja logi sisse kooli konto kasutajanime ja parooliga. Kui brauser hoiatab sertifikaadi eest, vali **Advanced → Continue**.

**2.2 Kontrolli masinaid.** Vasakul on kuus virtuaalmasinat, mille nimed lõpevad nii: `-Control`, `-Web01`, `-App01`, `-Rmq01`, `-Mc01` ja `-Db01` (näiteks `Automatiseerimine-IS126-Maasikas-Control`). Kõik peavad töötama. Kui mõni masin on välja lülitatud, vali see ja vajuta **Start**.

**2.3 Ava control node'i konsool.** Vali `-Control` masin ja seejärel **Console**. Logi sisse kasutajaga `kasutaja` ja virtuaalmasinate parooliga (vt arutelu teadet). Käivita need käsud:

```bash
sudo rm -f /etc/ssh/ssh_host_*
sudo ssh-keygen -A
sudo systemctl restart ssh
hostname -I
```

Käsk `hostname -I` kuvab sinu control node'i IP-aadressi (algab `192.168.125.`). Pane see aadress kirja, sest kasutad seda järgmises sammus. Kasuta ainult enda masinate aadresse: laborivõrgus on kõigi õppijate masinad.

??? info "Mida need käsud teevad?"

    Virtuaalmasinad on loodud samast mallist ja seetõttu on neil alguses samad SSH hostivõtmed. SSH hostivõti võimaldab kliendil kontrollida, millise serveriga ta ühendub. Esimesed kolm käsku loovad control node'ile uued hostivõtmed enne, kui VS Code sellega esimest korda ühendub. Ülejäänud viie masina hostivõtmed uuendab 1. praktikumi skript.

??? question "Proxmoxi sisselogimine ei õnnestu?"

    Kirjuta arutelu kategooriasse **Küsimused**. Control node'i IP-aadressi saad sel juhul juhendajalt ja võid jätkata sammuga 3.

## 3 · VS Code

Need sammud teed oma arvutis.

**3.1 Paigalda VS Code ja laiendus.** Paigalda [VS Code](https://code.visualstudio.com/). Ava vasakul **Extensions**, otsi laiendus **Remote - SSH** ja paigalda see.

**3.2 Lisa control node SSH konfiguratsioonifaili.** Vajuta ++f1++, vali `Remote-SSH: Open SSH Configuration File` ja seejärel loendi esimene fail. Lisa faili järgmised read, asenda `<control-IP>` sammus 2.3 leitud aadressiga ja salvesta fail:

```text
Host control
    HostName <control-IP>
    User kasutaja
```

**3.3 Ühendu control node'iga.** Ava vasakul **Remote Explorer**, vali `control` ja vajuta **Connect**. Kui VS Code küsib serveri platvormi, vali `Linux`. Seejärel kinnita ühendus (**Continue**) ja sisesta virtuaalmasinate parool (mitte kooli konto parool).

**3.4 Ava terminal.** Vali menüüst **Terminal → New Terminal**.

**Kontrolli:** VS Code'i vasakus alanurgas on kiri **SSH: control** ja terminali viip algab kujul `kasutaja@`. See terminal töötab control node'is.

??? info "Mis on SSH konfiguratsioonifail ja miks küsitakse iga kord parooli?"

    SSH konfiguratsioonifail asub Windowsis kohas `C:\Users\<kasutajanimi>\.ssh\config`, macOS-is ja Linuxis kohas `~/.ssh/config`. Real `Host` on ühenduse lühinimi, real `HostName` serveri IP-aadress ja real `User` kasutajanimi serveris.

    VS Code küsib ühenduse loomisel parooli, sest sinu arvutisse ei ole SSH-võtit seadistatud. Selle kursuse puhul on see taotluslik. SSH-võtme lood 1. praktikumis control node'is: privaatvõti `~/.ssh/id_ed25519` jääb control node'i, avalik võti `id_ed25519.pub` läheb ülejäänud viide masinasse ja GitHubi. Pärast seda logib control node teistesse masinatesse sisse ilma paroolita, ja just seda vajab Ansible.

??? info "Kas teisi masinaid saab VS Code'is avada?"

    Tavaliselt ei ole seda vaja, sest muudatused teeb Ansible. Pärast 1. praktikumi on kõige lihtsam valida **Terminal → Split Terminal** ja logida igas terminalis control node'ist edasi, näiteks `ssh web01` või `ssh db01`.

    Kui soovid masinat avada eraldi VS Code'i aknas koos failipuuga, lisa oma arvuti SSH konfiguratsioonifaili iga masina kohta kirje:

    ```text
    Host web01
        HostName <web01-IP>
        User kasutaja
        ProxyJump control
    ```

    Rida `ProxyJump control` tähendab, et ühendus web01-ga luuakse control node'i kaudu. Sisselogimise teeb sel juhul sinu arvuti, mitte control node. Seetõttu küsitakse parooli kaks korda, control node'i ja web01 jaoks, ka pärast 1. praktikumi.

??? info "Kas võib kasutada Termiust, JetBrainsi või mõnda muud tööriista?"

    Võib. Ühenduse andmed on samad: kasutaja `kasutaja`, control node'i IP-aadress ja parool. **Soovitan siiski VS Code'i**, sest:

    - failid ja terminal on samas aknas;
    - Ansible'i ja YAML-i laiendused näitavad vigu juba kirjutamise ajal;
    - see töötab ühtemoodi Windowsis, macOS-is ja Linuxis ning on tasuta;
    - kõik juhendid on kirjutatud VS Code'i jaoks, seega saab juhendaja kiiremini aidata.

    Termiuses tuleb faile muuta näiteks `nano` abil. JetBrainsi tööriistad on võimsad, kuid raskemad ja kursusel neid ei kasutata.

## Kui midagi ei tööta

??? failure "Kontrolli kõigepealt ühendust"

    Ava oma arvutis käsurida (Windowsis **cmd**, macOS-is **Terminal**) ja käivita:

    ```text
    ping 192.168.124.200
    ```

    Kui vastused tulevad, on VPN-ühendus korras. Seejärel kontrolli sama käsuga control node'i IP-aadressi. Kui Proxmox vastab, aga control node ei vasta, kontrolli Proxmoxis, kas masin töötab. Kui kumbki ei vasta, ei ole VPN-ühendus aktiivne.

??? failure "VPN ei ühendu"

    Kasutajanimi on kujul `perekonnanimi.is126` ja parool on sama mis kooli Gmailis (kooli konto, mille andmed said e-kirjaga). macOS-is tuleb ühendus lubada: **System Settings → Privacy & Security → Allow**.

??? failure "`Connection timed out`"

    Kontrolli, kas VPN-ühendus on aktiivne, virtuaalmasin Proxmoxis töötab ja SSH konfiguratsioonifailis on õige IP-aadress.

??? failure "`Permission denied` pärast parooli sisestamist"

    Kontrolli, et SSH konfiguratsioonifailis on rida `User kasutaja`. Kasuta virtuaalmasina kasutaja `kasutaja` parooli, mitte kooli konto parooli.

??? failure "`Permission denied (publickey)` ja parooli ei küsitud"

    Masinas on parooliga sisselogimine keelatud. Ava masin Proxmoxis (**Console**), logi sisse ja käivita:

    ```bash
    echo "PasswordAuthentication yes" | sudo tee /etc/ssh/sshd_config.d/01-parool.conf
    sudo systemctl restart ssh      # AlmaLinuxis: sudo systemctl restart sshd
    ```

    !!! danger "Ainult laboris"

        Laboris on parooliga sisselogimine lubatud, sest masinad asuvad suletud võrgus, neile pääseb ainult VPN-i kaudu ja need kustutatakse kursuse lõpus. Avalikust internetist ligipääsetavates serverites ei ole parooliga SSH-sisselogimine soovitatav, sest selliste serverite vastu tehakse pidevalt automatiseeritud sisselogimiskatseid. Seal kasutatakse ainult SSH-võtmeid (`PasswordAuthentication no`).

??? failure "`REMOTE HOST IDENTIFICATION HAS CHANGED`"

    Ava VS Code'is fail `C:\Users\<kasutajanimi>\.ssh\known_hosts` (macOS-is ja Linuxis `~/.ssh/known_hosts`), kustuta read, kus on control node'i IP-aadress, salvesta fail ja ühendu uuesti.

??? failure "VS Code jääb teate „Setting up SSH Host“ juurde"

    Vajuta ++f1++, vali **Remote-SSH: Kill VS Code Server on Host** ja ühendu uuesti.
