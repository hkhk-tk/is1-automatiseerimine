---
tags:
  - Kursuse ülevaade
hide:
  - navigation
  - toc
---

<div class="avaleht-hero" markdown>

# IT-infrastruktuuri automatiseerimine I

Käsitsi tehtud Linuxi tööst korratava ja kontrollitava automaatikani: Bash, Ansible, konteinerid, taristu koodina, tarneahel ja Kubernetes.

[Alusta siit](00-ulevaade/keskkond.md){ .md-button .md-button--primary } [Vaata õppepäevi](#oppepaevad){ .md-button }

<p class="avaleht-info">7 laupäeva · 10:00–15:00 · HKHK ja kooli Proxmoxi labor</p>

</div>

## Kursuse teekond

<figure style="max-width:760px;margin:.4em auto 1em" class="lx" markdown="0">
<svg viewBox="0 0 760 110" role="img" aria-label="Kursuse teekond: 1 Bash ja Ansible, 2 Ansible, 3 Konteinerid, 4 Taristu koodina, 5 Tarneahel, 6 Jenkins, 7 Kubernetes" xmlns="http://www.w3.org/2000/svg">
<style>.lx svg{width:100%;height:auto;font-family:var(--md-text-font-family,sans-serif)}.lx .ln{stroke:var(--md-default-fg-color--lighter);stroke-width:2}.lx .c{fill:var(--md-code-bg-color);stroke:var(--md-default-fg-color--lighter);stroke-width:1.5}.lx .on{fill:var(--md-primary-fg-color);stroke:var(--md-primary-fg-color)}.lx .n{fill:var(--md-default-fg-color);font-size:15px;font-weight:700}.lx .non{fill:var(--md-primary-bg-color);font-size:15px;font-weight:700}.lx .t{fill:var(--md-default-fg-color);font-size:13px;font-weight:600}.lx .s{fill:var(--md-default-fg-color--light);font-size:11.5px}</style>
<line class="ln" x1="54" y1="34" x2="706" y2="34"/>
<a href="k01/loeng/"><circle class="c on" cx="54" cy="34" r="20"/><text class="non" x="54" y="39" text-anchor="middle">1</text><text class="t" x="54" y="76" text-anchor="middle">Bash</text><text class="s" x="54" y="93" text-anchor="middle">ja Ansible</text></a>
<circle class="c" cx="163" cy="34" r="20"/><text class="n" x="163" y="39" text-anchor="middle">2</text><text class="t" x="163" y="76" text-anchor="middle">Ansible</text><text class="s" x="163" y="93" text-anchor="middle">mitu masinat</text>
<circle class="c" cx="271" cy="34" r="20"/><text class="n" x="271" y="39" text-anchor="middle">3</text><text class="t" x="271" y="76" text-anchor="middle">Konteinerid</text><text class="s" x="271" y="93" text-anchor="middle">Docker, Podman</text>
<circle class="c" cx="380" cy="34" r="20"/><text class="n" x="380" y="39" text-anchor="middle">4</text><text class="t" x="380" y="76" text-anchor="middle">Taristu</text><text class="s" x="380" y="93" text-anchor="middle">OpenTofu</text>
<circle class="c" cx="489" cy="34" r="20"/><text class="n" x="489" y="39" text-anchor="middle">5</text><text class="t" x="489" y="76" text-anchor="middle">Tarneahel</text><text class="s" x="489" y="93" text-anchor="middle">GitHub Actions</text>
<circle class="c" cx="597" cy="34" r="20"/><text class="n" x="597" y="39" text-anchor="middle">6</text><text class="t" x="597" y="76" text-anchor="middle">Jenkins</text><text class="s" x="597" y="93" text-anchor="middle">kvaliteedivärav</text>
<circle class="c" cx="706" cy="34" r="20"/><text class="n" x="706" y="39" text-anchor="middle">7</text><text class="t" x="706" y="76" text-anchor="middle">Kubernetes</text><text class="s" x="706" y="93" text-anchor="middle">GitOps</text>
</svg>
</figure>

## Õppepäevad { #oppepaevad }

<div class="grid cards paevad" markdown>

-   <span class="paev-nr">01 · Alustamine</span>

    **Linuxi haldusest automatiseerimiseni**

    Kuidas muuta käsitsi tehtud töö korratavaks ja kontrollitavaks?

    *Päeva tulemus:* sama seadistus käsitsi, Bashi skriptiga ja Ansible'iga. Teine käivitus ei muuda midagi.

    [Loeng](k01/loeng.md) · [Praktikum](k01/lab.md) · [Kodutöö](k01/kodutoo.md)

-   <span class="paev-nr">02 · Ansible</span>

    **Mitu masinat, üks kirjeldus**

    Kuidas seadistada viis masinat ühe playbook'iga?

    *Päeva tulemus:* inventory, muutujad ja mallid; üks playbook seadistab kõik labori masinad.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">03 · Konteinerid</span>

    **Docker ja Podman**

    Kuidas pakkida rakendus nii, et see töötab igal pool ühtemoodi?

    *Päeva tulemus:* rakendus ja andmebaas konteinerites Compose'iga.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">04 · Taristu koodina</span>

    **OpenTofu (Terraform)**

    Kuidas luua virtuaalmasinad koodist, mitte hiirega?

    *Päeva tulemus:* labori masinad tekivad ja kaovad ühe käsuga.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">05 · Tarneahel</span>

    **GitHub Actions**

    Kuidas kontrollida ja tarnida iga muudatust automaatselt?

    *Päeva tulemus:* iga `git push` käivitab kontrolli, ehituse ja tarne.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">06 · Kvaliteet</span>

    **Jenkins, SonarQube ja Nexus**

    Kuidas peatada vigane muudatus enne tootmist?

    *Päeva tulemus:* tarneahel kvaliteediväravaga ja versioonitud artefaktiga.

    <span class="tuleb">Avaneb enne kohtumist</span>

-   <span class="paev-nr">07 · Klaster</span>

    **Kubernetes ja GitOps**

    Kuidas hoida rakendust klastris nii, et Git on tõe allikas?

    *Päeva tulemus:* rakendus klastris, muudatus jõuab sinna Giti kaudu.

    <span class="tuleb">Avaneb enne kohtumist</span>

</div>

## Enne esimest kohtumist

<div class="grid cards sammud" markdown>

-   **1 · GitHub**

    Võta vastu e-postiga tulnud kutse orgi `hkhk-tk`. Konto puudumisel loo see kooli e-postiga.

-   **2 · VPN ja VS Code**

    Paigalda VPN-i klient ja VS Code laiendusega Remote - SSH.

-   **3 · Ühenduse kontroll**

    Logi VS Code'iga control node'ile ja vaheta parool.

</div>

[Ava ettevalmistusjuhend](00-ulevaade/keskkond.md){ .md-button .md-button--primary }

## Kuidas õppimine toimub

<figure style="max-width:760px;margin:.4em auto" class="lx" markdown="0">
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

## Lisapraktika

Valikuline, põhiteekonnast eraldi.

<div class="grid cards" markdown>

-   **[Pilv (AWS)](kodutood/kodutood.md)**

    Sama oskus pilves, oma kontol. Loe enne [reeglid ja kulud](kodutood/aws-reeglid.md).

-   **[Monitooring](kodutood/monitooring.md)**

    Väike ülesanne iga päeva tööriistaga.

-   **[Teemad](teemad/it-automatiseerimine.md)**

    Süvalugemine automatiseerimise valdkondade kohta.

</div>

---

<p class="avaleht-info">Koolitajad: Maria Talvik, Rain Koor · Küsimused: <a href="https://github.com/hkhk-tk/is126-arutelu/discussions">is126-arutelu</a></p>
