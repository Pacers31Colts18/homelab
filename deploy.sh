#!/bin/bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"

for dir in opt etc usr; do
    src="${REPO}/${dir}"
    if [[ -d "$src" ]]; then
        echo "Syncing /${dir}/..."
        rsync -av "${src}/" "/${dir}/"
    fi
done

echo "Done."
