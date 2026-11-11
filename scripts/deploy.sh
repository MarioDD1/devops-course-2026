#!/usr/bin/env bash
set -euo pipefail
die() { echo "ERROR: $*" >&2; exit 1; }
trap 'echo "ERROR: deployment failed" >&2; exit 1' ERR
DRY=0
case "${1:-}" in
  '') [[ $# -eq 0 ]] || die "Usage: deploy.sh [--dry-run]" ;;
  --dry-run) [[ $# -eq 1 ]] || die "Usage: deploy.sh [--dry-run]"; DRY=1 ;;
  *) die "Usage: deploy.sh [--dry-run]" ;;
esac
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
[[ -f "$ROOT/site/index.html" ]] || die "site/index.html is missing"
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || die "Commit or restore all changes before deployment"
OPTIONS=(-avz --delete --chmod=D755,F644 -e 'ssh -o BatchMode=yes -o ConnectTimeout=5')
if [[ $DRY -eq 1 ]]; then OPTIONS+=(--dry-run); fi
rsync "${OPTIONS[@]}" "$ROOT/site/" devops:/var/www/devops-site/
if [[ $DRY -eq 1 ]]; then echo "Dry run complete; server files unchanged"; exit 0; fi
curl --noproxy '*' --fail --silent --show-error --connect-timeout 5 --max-time 15 --cacert "$HOME/devops.crt" https://devops.local/ -o /dev/null
echo "Deployed commit $(git -C "$ROOT" rev-parse --short HEAD)"
