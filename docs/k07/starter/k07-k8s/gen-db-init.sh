#!/usr/bin/env bash
# Genereerib 05-db-init.yaml failidest db/schema.sql ja db/seed.sql (ConfigMap labori-seis-db).
# Käivita pärast iga muudatust db/ kaustas ja commit'i tulemus: Argo CD vajab ConfigMap'i Gitis.
# Kasutus: bash gen-db-init.sh          (töötab nii deploy/k8s/ kui ka k07-k8s/ kaustas)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
out="$here/05-db-init.yaml"

for f in "$root/db/schema.sql" "$root/db/seed.sql"; do
    [[ -f "$f" ]] || { echo "puudub $f" >&2; exit 1; }
done

# Võtmete järjekord on oluline: MariaDB entrypoint käivitab /docker-entrypoint-initdb.d/* tähestiku järgi
{
    echo "# GENEREERITUD: bash gen-db-init.sh (allikas db/schema.sql, db/seed.sql). Ära muuda käsitsi."
    kubectl create configmap labori-seis-db \
        --from-file=01-schema.sql="$root/db/schema.sql" \
        --from-file=02-seed.sql="$root/db/seed.sql" \
        --dry-run=client -o yaml | grep -v 'creationTimestamp: null'
} > "$out"
echo "kirjutatud $out"
