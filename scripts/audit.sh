#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "[OK] $desc"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $desc expected=$expected actual=$actual"
        FAIL=$((FAIL + 1))
    fi
}

sudo -v || exit 1
SSH_CONFIG=$(sudo /usr/sbin/sshd -T) || exit 1
UFW_STATUS=$(sudo env LC_ALL=C ufw status verbose) || exit 1

echo "Audit: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

check "Root login disabled" "no" \
    "$(awk '$1=="permitrootlogin"{print $2}' <<< "$SSH_CONFIG")"

check "Password authentication disabled" "no" \
    "$(awk '$1=="passwordauthentication"{print $2}' <<< "$SSH_CONFIG")"

PORTS=$(awk '$1=="port"{print $2}' <<< "$SSH_CONFIG")
NONSTANDARD=no
if [[ -n "$PORTS" ]] && ! grep -qx '22' <<< "$PORTS"; then
    NONSTANDARD=yes
fi
check "SSH uses a nonstandard port" "yes" "$NONSTANDARD"

check "MaxAuthTries equals 3" "3" \
    "$(awk '$1=="maxauthtries"{print $2}' <<< "$SSH_CONFIG")"

check "UFW is active" "active" \
    "$(awk '/^Status:/{print $2}' <<< "$UFW_STATUS")"

DEFAULT_DENY=no
if grep -Eq '^Default: deny \(incoming\)' <<< "$UFW_STATUS"; then
    DEFAULT_DENY=yes
fi
check "Incoming policy is deny" "yes" "$DEFAULT_DENY"

echo "User accounts:"
awk -F: '$3>=1000 && $3<65534 {printf "%s (uid=%s)\n",$1,$3}' /etc/passwd

echo "Passed: $PASS; Failed: $FAIL"
if [[ "$FAIL" -eq 0 ]]; then
    exit 0
else
    exit 1
fi
