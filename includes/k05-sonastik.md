*[orkestreerimine]: Tarkvara valib konteinerile masina, asendab rikkis koopiad ja vahetab versioone
*[klaster]: Mitu masinat, mida hallatakse koos
*[node]: Klastri masin (füüsiline või virtuaalne), kus pod'id töötavad. Eesti keeles ka sõlm
*[control plane]: Klastri juhttasand: API server, scheduler, kontrollerid ja etcd. Otsustab, kus pod töötab
*[juhttasand]: Control plane: klastri juhtimise osa
*[worker node]: Masin, kus töötavad sinu rakendused
*[pod]: Kubernetese väikseim üksus: üks või mitu konteinerit ühise IP-aadressiga
*[ephemeral]: Ajutine: pod võib igal hetkel kaduda, asemele tuleb uus uue nime ja IP-ga
*[nimeruum]: Namespace: klastri jaotus osadeks, näiteks default ja kube-system
*[silt]: Label: võti ja väärtus (app: tere), mille järgi objektid üksteist leiavad
*[API server]: Klastri ainus sissepääs, kõik käsud käivad selle kaudu. Port 6443
*[etcd]: Andmebaas, kus on kogu klastri olek. k3s-is ühe masina puhul SQLite
*[scheduler]: Valib uuele pod'ile node'i vaba mälu ja protsessori järgi
*[Scheduler]: Valib uuele pod'ile node'i vaba mälu ja protsessori järgi
*[kontroller]: Võrdleb soovitud ja tegelikku olekut ning kõrvaldab vahe
*[Controller Manager]: Protsess, milles töötavad kõik kontrollerid
*[kubelet]: Igal node'il töötav agent, mis käivitab talle määratud pod'id
*[containerd]: Konteineri käivitaja: laadib image'i ja käivitab konteineri
*[kube-proxy]: Seab node'il võrgureeglid, mis viivad Service'i päringu pod'ini
*[Flannel]: Virtuaalvõrk, mis ühendab k3s-is kõigi node'ide pod'id
*[Deployment]: Pod'i mall: mitu koopiat peab töötama ja millisest image'ist
*[ReplicaSet]: Deployment'i loodud objekt, mis hoiab õiget arvu pod'e
*[StatefulSet]: Andmebaasidele: igal pod'il püsiv nimi ja oma ketas. Andmeid kopeerib andmebaas ise
*[DaemonSet]: Üks pod igal node'il, näiteks logikoguja
*[CronJob]: Ajastatud töö nagu cron
*[Service]: Püsiv nimi ja IP-aadress pod'ide grupile, jagab ka koormust
*[ClusterIP]: Service'i tüüp, nähtav ainult klastri sees (vaikimisi)
*[NodePort]: Service'i tüüp, avab pordi 30000–32767 igal node'il
*[Ingress]: Suunab päringu nime järgi õigele Service'ile. k3s-is Traefik
*[ConfigMap]: Seadistus väljaspool image'it
*[Secret]: Nagu ConfigMap, aga paroolidele. Ainult base64, mitte krüpteeritud
*[Volume]: Pod'iga ühendatud ketas, mis jääb alles ka pod'i kadumisel
*[PersistentVolumeClaim]: Kettaruumi taotlus: kui palju ja mitu kirjutajat
*[PVC]: PersistentVolumeClaim: kettaruumi taotlus
*[triiv]: Drift: klaster erineb failist, näiteks käsitsi muudatuse järel
*[kubectl]: Käsurea tööriist, millega räägid API serveriga
*[kubeconfig]: Fail (~/.kube/config) klastri aadressi ja sertifikaadiga
*[rolling update]: Pod'id vahetatakse uue versiooni vastu järk-järgult
*[readinessProbe]: Kontroll, kas pod võib päringuid saada. Ebaõnnestumisel jääb Service'ist välja
*[livenessProbe]: Kontroll, kas konteiner on terve. Ebaõnnestumisel taaskäivitatakse
*[Helm]: Kubernetese paketihaldur, paketid on chart'id
*[Argo CD]: GitOps-tööriist: viib klastri Gitis kirjeldatud olekusse
*[k3s]: Kerge Kubernetes ühes programmis, paigaldub ühe käsuga
*[kube-system]: Nimeruum, kus on klastri enda osad
