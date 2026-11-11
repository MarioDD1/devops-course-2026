#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
PASS=0; FAIL=0
check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "[OK] $desc"; PASS=$((PASS+1))
    else
        echo "[FAIL] $desc expected=$expected actual=$actual"; FAIL=$((FAIL+1))
    fi
}
sudo -v || exit 1
SSH_CONFIG=$(sudo /usr/sbin/sshd -T) || exit 1
UFW_STATUS=$(sudo env LC_ALL=C ufw status verbose) || exit 1
echo "Audit: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"
echo '[1] SSH'
check 'Root login disabled' no "$(awk '$1=="permitrootlogin"{print $2}' <<< "$SSH_CONFIG")"
check 'Password authentication disabled' no "$(awk '$1=="passwordauthentication"{print $2}' <<< "$SSH_CONFIG")"
PORTS=$(awk '$1=="port"{print $2}' <<< "$SSH_CONFIG")
NONSTANDARD=no
if [[ -n "$PORTS" ]] && ! grep -qx 22 <<< "$PORTS"; then NONSTANDARD=yes; fi
check 'Nonstandard SSH port' yes "$NONSTANDARD"
check 'MaxAuthTries equals 3' 3 "$(awk '$1=="maxauthtries"{print $2}' <<< "$SSH_CONFIG")"
echo '[2] Firewall'
check 'UFW active' active "$(awk '/^Status:/{print $2}' <<< "$UFW_STATUS")"
DENY=no
if grep -Eq '^Default: deny \(incoming\)' <<< "$UFW_STATUS"; then DENY=yes; fi
check 'Incoming policy deny' yes "$DENY"
echo '[3] Accounts'
awk -F: '$3>=1000 && $3<65534 {printf "%s (uid=%s)\n",$1,$3}' /etc/passwd
echo '[4] Web server'
check 'Nginx active' active "$(systemctl is-active nginx)"
NGINX_OK=no
if sudo nginx -t; then NGINX_OK=yes; fi
check 'Nginx configuration valid' yes "$NGINX_OK"
CERT_OK=no
if openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend "${CERT_MIN_SECONDS:-2592000}"; then CERT_OK=yes; fi
check 'Certificate exceeds required validity' yes "$CERT_OK"
FILES_OK=no
WORLD_WRITABLE=$(find /var/www/devops-site -perm -o+w 2>&1)
FIND_CODE=$?
KEY_MODE=$(sudo stat -c '%a' /etc/ssl/private/devops.key)
if [[ $FIND_CODE -eq 0 && -z "$WORLD_WRITABLE" && "$KEY_MODE" == 600 ]]; then FILES_OK=yes; fi
check 'No world-writable paths and TLS key mode 600' yes "$FILES_OK"
echo "Passed: $PASS; Failed: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
