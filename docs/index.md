---
tags:
  - Kursuse ülevaade
hide:
  - navigation
  - toc
---

<div class="avaleht-hero" markdown>

<div class="hero-tekst" markdown>

# IT-infrastruktuuri automatiseerimine&nbsp;I

Seitse kohtumist, üks kasvav automaatika. Alustad käsitsi tehtud Linuxi tööst ja jõuad selleni, et rakenduse paigaldus, taristu, tarne ja käitus on kood, mida saab korrata ja kontrollida.

[Alusta siit](00-ulevaade/keskkond.md){ .md-button .md-button--primary } [Vaata õppepäevi](#oppepaevad){ .md-button }

</div>

<figure class="lx hero-pilt" markdown="0">
<svg viewBox="0 0 360 300" role="img" aria-label="Rakendus keskel, selle ümber neli automatiseerimise osa: paigaldus, taristu, tarne ja käitus" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .core{fill:var(--md-primary-fg-color);fill-opacity:.18;stroke:var(--md-primary-fg-color);stroke-width:2}.lx .ring{fill:none;stroke:var(--md-default-fg-color--lightest);stroke-width:1.5;stroke-dasharray:4 4}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-accent-fg-color);stroke-width:1.5}.lx .t{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:11.5px}</style>
<circle class="ring" cx="180" cy="150" r="105"/>
<circle class="core" cx="180" cy="150" r="52"/><text class="t" x="180" y="146" text-anchor="middle">Rakendus</text><text class="s" x="180" y="164" text-anchor="middle">sinu teenus</text>
<rect class="box" x="115" y="8" width="130" height="48" rx="10"/><text class="b" x="180" y="29" text-anchor="middle">Paigaldus</text><text class="s" x="180" y="46" text-anchor="middle">Bash · Ansible</text>
<rect class="box" x="230" y="126" width="124" height="48" rx="10"/><text class="b" x="292" y="147" text-anchor="middle">Taristu</text><text class="s" x="292" y="164" text-anchor="middle">OpenTofu</text>
<rect class="box" x="115" y="244" width="130" height="48" rx="10"/><text class="b" x="180" y="265" text-anchor="middle">Tarne</text><text class="s" x="180" y="282" text-anchor="middle">Actions · Jenkins</text>
<rect class="box" x="6" y="126" width="124" height="48" rx="10"/><text class="b" x="68" y="147" text-anchor="middle">Käitus</text><text class="s" x="68" y="164" text-anchor="middle">Docker · Kubernetes</text>
</svg>
</figure>

</div>

<div class="avaleht" markdown>

!!! tip "Enne esimest kohtumist"

    Võta vastu GitHubi kutse orgi `hkhk-tk`, seadista VPN ja VS Code ning kontrolli ühendust laboriga. [Ava ettevalmistusjuhend →](00-ulevaade/keskkond.md)

## Kursuse teekond

<figure style="max-width:760px;margin:.2em auto .6em" class="lx" markdown="0">
<svg viewBox="0 0 760 105" role="img" aria-label="Kursuse teekond: 1 Bash ja Ansible, 2 Ansible, 3 Konteinerid, 4 Taristu, 5 Tarneahel, 6 Jenkins, 7 Kubernetes" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .ln{stroke:var(--md-default-fg-color--lighter);stroke-width:2}.lx .c{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.5}.lx .on{fill:var(--md-primary-fg-color);stroke:var(--md-primary-fg-color)}.lx .n{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .non{fill:var(--md-primary-bg-color);font-size:15px;font-weight:700}.lx .t{fill:var(--md-default-fg-color);font-size:13px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:11.5px}</style>
<line class="ln" x1="54" y1="30" x2="706" y2="30"/>
<a href="k01/"><circle class="c on" cx="54" cy="30" r="20"/><text class="non" x="54" y="35" text-anchor="middle">1</text><text class="t" x="54" y="72" text-anchor="middle">Bash</text><text class="s" x="54" y="89" text-anchor="middle">ja Ansible</text></a>
<circle class="c" cx="163" cy="30" r="20"/><text class="n" x="163" y="35" text-anchor="middle">2</text><text class="t" x="163" y="72" text-anchor="middle">Ansible</text><text class="s" x="163" y="89" text-anchor="middle">mitu masinat</text>
<circle class="c" cx="271" cy="30" r="20"/><text class="n" x="271" y="35" text-anchor="middle">3</text><text class="t" x="271" y="72" text-anchor="middle">Konteinerid</text><text class="s" x="271" y="89" text-anchor="middle">Docker, Podman</text>
<circle class="c" cx="380" cy="30" r="20"/><text class="n" x="380" y="35" text-anchor="middle">4</text><text class="t" x="380" y="72" text-anchor="middle">Taristu</text><text class="s" x="380" y="89" text-anchor="middle">OpenTofu</text>
<circle class="c" cx="489" cy="30" r="20"/><text class="n" x="489" y="35" text-anchor="middle">5</text><text class="t" x="489" y="72" text-anchor="middle">Tarneahel</text><text class="s" x="489" y="89" text-anchor="middle">GitHub Actions</text>
<circle class="c" cx="597" cy="30" r="20"/><text class="n" x="597" y="35" text-anchor="middle">6</text><text class="t" x="597" y="72" text-anchor="middle">Jenkins</text><text class="s" x="597" y="89" text-anchor="middle">kvaliteedivärav</text>
<circle class="c" cx="706" cy="30" r="20"/><text class="n" x="706" y="35" text-anchor="middle">7</text><text class="t" x="706" y="72" text-anchor="middle">Kubernetes</text><text class="s" x="706" y="89" text-anchor="middle">GitOps</text>
</svg>
</figure>

## Õppepäevad { #oppepaevad }

<div class="grid cards paevad" markdown>

-   <span class="paev-nr">01 · Alustamine</span>

    **Linuxi haldusest automatiseerimiseni**

    Sama ülesanne käsitsi, Bashiga ja Ansible'iga.

    [Ava õppepäev →](k01/index.md)

-   <span class="paev-nr">02 · Ansible</span>

    **Mitu masinat, üks kirjeldus**

    Üks playbook seadistab kõik labori masinad.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">03 · Konteinerid</span>

    **Docker ja Podman**

    Rakendus koos vajaliku käituskeskkonnaga.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">04 · Taristu koodina</span>

    **OpenTofu (Terraform)**

    Virtuaalmasinad koodis kirjeldatud plaani järgi.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">05 · Tarneahel</span>

    **GitHub Actions**

    Töövoog, mis kontrollib muudatusi ning ehitab ja tarnib kokkulepitud tingimustel.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">06 · Kvaliteet</span>

    **Jenkins, SonarQube ja Nexus**

    Kvaliteedivärav ja versioonitud artefakt.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">07 · Klaster</span>

    **Kubernetes ja GitOps**

    Rakendus klastris, Git on tõe allikas.

    <span class="tuleb">Avaneb enne kohtumist</span>

</div>

## Kuidas õppimine toimub

<figure style="max-width:760px;margin:.2em auto" class="lx" markdown="0">
<svg viewBox="0 0 760 70" role="img" aria-label="Loe, vaata näidet, tee laboris, kontrolli, esita" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .box{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.2}.lx .hi{fill:var(--md-primary-fg-color);fill-opacity:.16;stroke:var(--md-primary-fg-color);stroke-width:1.5}.lx .b{fill:var(--md-default-fg-color);font-size:14px;font-weight:600}.lx .a{stroke:var(--md-default-fg-color--light);stroke-width:1.5;fill:none}.lx .h{fill:var(--md-default-fg-color--light)}</style>
<defs><marker id="lxo" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path class="h" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="5" y="12" width="128" height="44" rx="8"/><text class="b" x="69" y="39" text-anchor="middle">Loe</text>
<line class="a" x1="133" y1="34" x2="155" y2="34" marker-end="url(#lxo)"/>
<rect class="box" x="157" y="12" width="128" height="44" rx="8"/><text class="b" x="221" y="39" text-anchor="middle">Vaata näidet</text>
<line class="a" x1="285" y1="34" x2="307" y2="34" marker-end="url(#lxo)"/>
<rect class="box" x="309" y="12" width="140" height="44" rx="8"/><text class="b" x="379" y="39" text-anchor="middle">Tee laboris</text>
<line class="a" x1="449" y1="34" x2="471" y2="34" marker-end="url(#lxo)"/>
<rect class="hi" x="473" y="12" width="128" height="44" rx="8"/><text class="b" x="537" y="39" text-anchor="middle">Kontrolli</text>
<line class="a" x1="601" y1="34" x2="623" y2="34" marker-end="url(#lxo)"/>
<rect class="box" x="625" y="12" width="128" height="44" rx="8"/><text class="b" x="689" y="39" text-anchor="middle">Esita</text>
</svg>
</figure>

Iga kohtumine on loeng, praktikum ja lühike kodutöö. Töö on sinu GitHubi repos ja automaatne hindaja kontrollib seda iga `git push`-i järel. Täpsemalt: [Töö repos ja hindamine](00-ulevaade/too-ja-hindamine.md).

</div>
