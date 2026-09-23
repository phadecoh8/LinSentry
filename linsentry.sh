#!/bin/bash

echo "=========================================================================================================="
echo " System Hardening Audit"
echo "=========================================================================================================="
echo ""
echo "Starting checks..."

echo ""
echo "[1] Checking open network ports"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
ss -tuln

echo ""
echo "[1b] Flagging ports exposed to the outside world"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

RISKY_PORTS=$(ss -tuln | awk '$5 ~ /^0\.0\.0\.0:|^\[::\]:/')

if [ -z "$RISKY_PORTS" ]; then
        echo "None Found. All listening ports are local-only (safe)."
else
        echo "WARNING: The following ports are open to any network device:"
        echo "$RISKY_PORTS"
fi
echo "=========================================================================================================="

echo ""
echo "[2a] Checking SSH configuration"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

SSHD_CONFIG="/etc/ssh/sshd_config"

if [ ! -f "$SSHD_CONFIG" ]; then
        echo "No SSH server config found ($SSHD_CONFIG). SSH checks skipped."
else
        check_ssh_setting() {
                SETTING_NAME=$1
                SAFE_VALUES=$2
                PREFERRED_VALUE=$(echo $SAFE_VALUES | awk '{print $1}')

                ACTIVE_LINE=$(grep -E "^${SETTING_NAME}[[:space:]]" "$SSHD_CONFIG")

                if [ -n "$ACTIVE_LINE" ]; then
                        echo "Current setting found: $ACTIVE_LINE"
                        CURRENT_VALUE=$(echo "$ACTIVE_LINE" | awk '{print $2}')

                        IS_SAFE="no"
                        for VALUE in $SAFE_VALUES; do
                                if [ "$CURRENT_VALUE" == "$VALUE" ]; then
                                        IS_SAFE="yes"
                                fi
                        done

                        if [ "$IS_SAFE" == "yes" ]; then
                                echo "OK: $SETTING_NAME = $CURRENT_VALUE (safe)"
                        else
                                echo "WARNING: $SETTING_NAME = $CURRENT_VALUE (recommended: $PREFERRED_VALUE)"
                                read -p "Change $SETTING_NAME to '$PREFERRED_VALUE' now? (y/n): " ANSWER
                                if [ "$ANSWER" == "y" ]; then
                                        sudo sed -i "s/^${SETTING_NAME}.*/${SETTING_NAME} ${PREFERRED_VALUE}/" "$SSHD_CONFIG"
                                        echo "Updated. (Run: sudo service ssh restart  to apply it)"
                                else
                                        echo "Skipped. No changes made."
                                fi
                        fi
                else
                        echo "NOTICE: $SETTING_NAME is not explicitly set (using default)."
                        read -p "Set $SETTING_NAME to '$PREFERRED_VALUE' now? (y/n): " ANSWER
                        if [ "$ANSWER" == "y" ]; then
                                echo "$SETTING_NAME $PREFERRED_VALUE" | sudo tee -a "$SSHD_CONFIG" > /dev/null
                                echo "Updated. (Run: sudo service ssh restart  to apply it)"
                        else
                                echo "Skipped. No changes made."
                        fi
                fi
        }

        check_ssh_setting "PermitRootLogin" "prohibit-password no"
        check_ssh_setting "PasswordAuthentication" "no"
        check_ssh_setting "PermitEmptyPasswords" "no"

        echo ""
        echo "[2b] Checking permissions on $SSHD_CONFIG"
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

        FILE_OWNER=$(stat -c "%U" "$SSHD_CONFIG")
        FILE_PERMS=$(stat -c "%a" "$SSHD_CONFIG")

        echo "Owner: $FILE_OWNER | Permissions: $FILE_PERMS"

        if [ "$FILE_OWNER" != "root" ]; then
                echo "WARNING: $SSHD_CONFIG is not owned by root (owned by $FILE_OWNER)."
        else
                echo "OK: File is owned by root."
        fi

        GROUP_OTHER_WRITE=$(echo "$FILE_PERMS" | cut -c2-3 | grep -E '[2367]')

        if [ -n "$GROUP_OTHER_WRITE" ]; then
                echo "WARNING: Group or others have write access to $SSHD_CONFIG (permissions: $FILE_PERMS)."
        else
                echo "OK: Group/others do not have write access."
        fi
fi
echo "=========================================================================================================="

echo ""
echo "[3] Checking for world-writable files in your home folder"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

WORLD_WRITABLE=$(find ~ -type f -perm -o+w 2>/dev/null)

if [ -z "$WORLD_WRITABLE" ]; then
        echo "None found. No world-writable files in $HOME."
else
        echo "WARNING: The following files can be modified by ANY user on this system:"
        echo "$WORLD_WRITABLE"
fi
echo "=========================================================================================================="

echo ""
echo "[4a] Checking User's accounts ... "
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "Checking for duplicate UID 0 (root-level) accounts..."
ROOT_ACCOUNTS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
ROOT_COUNT=$(echo "$ROOT_ACCOUNTS" | wc -l)

if [ "$ROOT_COUNT" -gt 1 ]; then
        echo "WARNING: Multiple UID 0 accounts found:"
        echo "$ROOT_ACCOUNTS"
        echo ""
        echo "Accounts other than 'root' with UID 0 (review these carefully):"
        echo "$ROOT_ACCOUNTS" | grep -v "^root$"
else
        echo "OK: Only one UID 0 (root) account found."
fi

echo ""
echo "[4b] Checking for accounts with empty passwords..."
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
EMPTY_PASS=$(sudo awk -F: '($2 == "") {print $1}' /etc/shadow)

if [ -z "$EMPTY_PASS" ]; then
        echo "OK: No accounts with empty passwords."
else
        echo "WARNING: the following accounts have NO password set:"
        echo "$EMPTY_PASS"
        for USERNAME in $EMPTY_PASS; do
                read -p "Set a password for '$USERNAME' now? (y/n): " ANSWER
                if [ "$ANSWER" == "y" ]; then
                        sudo passwd "$USERNAME"
                else
                        echo "Skipped. '$USERNAME' still has no password."
                fi
        done
fi
echo "=========================================================================================================="

echo ""
echo "[5] Checking sudo privileges"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "[5a] Members of the sudo group..."
SUDO_MEMBERS=$(getent group sudo | cut -d: -f4)

if [ -z "$SUDO_MEMBERS" ]; then
        echo "No users found in the sudo group."
else
        echo "The following users have sudo privileges:"
        echo "$SUDO_MEMBERS" | tr ',' '\n'
fi

echo ""
echo "[5b] Checking for users with NOPASSWD sudo privileges..."
NOPASSWD_ENTRIES=$(sudo grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null)

if [ -z "$NOPASSWD_ENTRIES" ]; then
        echo "OK: No NOPASSWD entries found."
else
        echo "WARNING: The following NOPASSWD entries were found (users can run commands without a password):"
        echo "$NOPASSWD_ENTRIES"
fi
echo "=========================================================================================================="

echo ""
echo "[6a] Checking firewall status"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

if ! command -v ufw &> /dev/null; then
        echo "NOTICE: ufw (firewall) is not installed on this system."
        read -p "Install ufw now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                sudo apt update
                sudo apt install ufw -y
                if [ $? -eq 0 ]; then
                        echo "ufw installed. It is not enabled yet — see below."
                else
                        echo "WARNING: ufw installation did not complete successfully."
                fi
        else
                echo "Skipped. No firewall protection is active on this system."
        fi
fi

if command -v ufw &> /dev/null; then
        UFW_STATUS=$(sudo ufw status | head -n 1)

        if [ "$UFW_STATUS" == "Status: active" ]; then
                echo "OK: ufw is installed and active."
                echo ""
                echo "Current rules:"
                sudo ufw status verbose
        else
                echo "WARNING: ufw is installed but NOT active. No firewall protection is enforced."
                read -p "Enable ufw now? (y/n): " ANSWER
                if [ "$ANSWER" == "y" ]; then
                        sudo ufw enable
                        if [ $? -eq 0 ]; then
                                echo "ufw enabled."
                        else
                                echo "WARNING: Failed to enable ufw."
                        fi
                else
                        echo "Skipped. Firewall remains inactive."
                fi
        fi
fi

if [ -n "$RISKY_PORTS" ]; then
        echo ""
        echo "NOTE: Earlier, this script found ports exposed to any network device (see [1b])."
        echo "A firewall does not automatically protect those ports unless a rule specifically"
        echo "restricts them. Review your ufw rules above, or run a command like:"
        echo "  sudo ufw allow from <trusted-IP> to any port 22"
        echo "to restrict SSH to a specific trusted source, instead of leaving it open to everyone."
fi
echo "=========================================================================================================="

echo ""
echo "[6b] Closing exposed ports"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

if [ -z "$RISKY_PORTS" ]; then
        echo "No exposed ports to close."
else
        read -p "Would you like to close any exposed ports? (y/n): " WANTS_TO_CLOSE

        if [ "$WANTS_TO_CLOSE" == "y" ]; then
                PORT_NUMBERS=$(echo "$RISKY_PORTS" | awk '{print $5}' | awk -F: '{print $NF}' | sort -u)

                echo ""
                echo "The following ports are exposed to any network device:"
                echo ""
                INDEX=1
                for PORT in $PORT_NUMBERS; do
                        echo "  [$INDEX] Port $PORT"
                        INDEX=$((INDEX + 1))
                done

                echo ""
                read -p "Enter the port number(s) you want to close (space-separated): " PORTS_TO_CLOSE

                if [ -z "$PORTS_TO_CLOSE" ]; then
                        echo "No ports entered. Skipped."
                else
                        for PORT in $PORTS_TO_CLOSE; do
                                read -p "Close port $PORT now? (y/n): " CONFIRM
                                if [ "$CONFIRM" == "y" ]; then
                                        sudo ufw deny "$PORT"
                                        echo "Port $PORT has been denied via ufw."
                                else
                                        echo "Skipped port $PORT."
                                fi
                        done
                fi
        else
                echo "Skipped. No ports were closed."
        fi
fi
echo "=========================================================================================================="

echo ""
echo "[7] Checking for pending security updates"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

sudo apt update > /dev/null 2>&1

SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security)
SECURITY_COUNT=$(echo "$SECURITY_UPDATES" | grep -c .)

if [ -z "$SECURITY_UPDATES" ]; then
        echo "OK: No pending security updates."
else
        echo "WARNING: $SECURITY_COUNT package(s) have pending security updates:"
        echo "$SECURITY_UPDATES"
        echo ""
        read -p "Install these security updates now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                sudo apt upgrade -y
                if [ $? -eq 0 ]; then
                        echo "Security updates installed."
                else
                        echo "WARNING: Update installation did not complete successfully."
                fi
        else
                echo "Skipped. Security updates remain pending."
        fi
fi
echo "=========================================================================================================="

echo ""
echo "[8] Checking security framework (AppArmor) status"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

if ! command -v aa-status &> /dev/null; then
        echo "NOTICE: AppArmor is not installed on this system."
        read -p "Install AppArmor now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                sudo apt update
                sudo apt install apparmor apparmor-utils -y
                if [ $? -eq 0 ]; then
                        echo "AppArmor installed."
                else
                        echo "WARNING: AppArmor installation did not complete successfully."
                fi
        else
                echo "Skipped. No mandatory access control framework is active."
        fi
else
        AA_OUTPUT=$(sudo aa-status 2>&1)
        echo "$AA_OUTPUT"
        echo ""

        if echo "$AA_OUTPUT" | grep -q "profiles are loaded"; then
                echo "OK: AppArmor is active and enforcing profiles."

        elif echo "$AA_OUTPUT" | grep -q "filesystem is not mounted"; then
                echo "NOTICE: AppArmor's module is loaded, but its filesystem isn't mounted."
                read -p "Attempt to mount it now? (y/n): " ANSWER
                if [ "$ANSWER" == "y" ]; then
                        sudo mount -t securityfs securityfs /sys/kernel/security 2>&1
                        AA_RECHECK=$(sudo aa-status 2>&1)
                        if echo "$AA_RECHECK" | grep -q "profiles are loaded"; then
                                echo "OK: AppArmor is now active and enforcing profiles."
                        else
                                echo "NOTICE: Mount attempted, but AppArmor still isn't enforcing."
                                echo "This is a known limitation on WSL — WSL's default kernel does"
                                echo "not include full AppArmor enforcement support, even when the"
                                echo "module is present. On a real Linux server (not WSL), this same"
                                echo "message would indicate a deeper issue worth investigating."
                        fi
                else
                        echo "Skipped."
                fi

        else
                echo "WARNING: AppArmor is installed but does not appear to be active."
                read -p "Enable AppArmor now? (y/n): " ANSWER
                if [ "$ANSWER" == "y" ]; then
                        sudo systemctl enable apparmor
                        sudo systemctl start apparmor
                        if [ $? -eq 0 ]; then
                                echo "AppArmor enabled and started."
                        else
                                echo "WARNING: Failed to enable/start AppArmor."
                        fi
                else
                        echo "Skipped. AppArmor remains inactive."
                fi
        fi
fi
echo "=========================================================================================================="

echo ""
echo "[9] Checking for malware scanning tools"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

if command -v rkhunter &> /dev/null || command -v chkrootkit &> /dev/null; then
        echo "OK: A malware/rootkit scanning tool is installed."
else
        echo "NOTICE: No malware/rootkit scanning tool (rkhunter or chkrootkit) is installed."
        echo "These tools check for known rootkit signatures — they are not a full"
        echo "antivirus, but provide a basic detection baseline."
        read -p "Install rkhunter now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                sudo apt update
                sudo apt install rkhunter -y
                if [ $? -eq 0 ]; then
                        echo "rkhunter installed successfully. Run 'sudo rkhunter --check' separately to perform a scan"
                        echo "(not run automatically here, as a full scan can take several minutes)."
                else
                        echo "WARNING: rkhunter installation did not complete successfully."
                        echo "No malware scanning tool is currently installed."
                fi
        else
                echo "Skipped. No malware scanning tool installed."
        fi
fi
echo "=========================================================================================================="

echo ""
echo "[10] Checking password complexity and expiration policy"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

LOGIN_DEFS="/etc/login.defs"

if [ ! -f "$LOGIN_DEFS" ]; then
        echo "NOTICE: $LOGIN_DEFS not found. Password policy checks skipped."
else
        check_login_defs_setting() {
                SETTING_NAME=$1
                COMPARISON=$2
                RECOMMENDED_VALUE=$3

                ACTIVE_LINE=$(grep -E "^${SETTING_NAME}[[:space:]]" "$LOGIN_DEFS")

                if [ -z "$ACTIVE_LINE" ]; then
                        PASSWORD_POLICY_WARNING="yes"
                        echo "NOTICE: $SETTING_NAME is not set in $LOGIN_DEFS (using system default)."
                        read -p "Set $SETTING_NAME to $RECOMMENDED_VALUE now? (y/n): " ANSWER
                        if [ "$ANSWER" == "y" ]; then
                                echo "$SETTING_NAME   $RECOMMENDED_VALUE" | sudo tee -a "$LOGIN_DEFS" > /dev/null
                                echo "Updated. (Applies to newly created accounts only.)"
                        else
                                echo "Skipped. No changes made."
                        fi
                        return
                fi

                echo "Current setting found: $ACTIVE_LINE"
                CURRENT_VALUE=$(echo "$ACTIVE_LINE" | awk '{print $2}')

                IS_SAFE="no"
                if [ "$COMPARISON" == "le" ]; then
                        [ "$CURRENT_VALUE" -le "$RECOMMENDED_VALUE" ] 2>/dev/null && IS_SAFE="yes"
                else
                        [ "$CURRENT_VALUE" -ge "$RECOMMENDED_VALUE" ] 2>/dev/null && IS_SAFE="yes"
                fi

                if [ "$IS_SAFE" == "yes" ]; then
                        echo "OK: $SETTING_NAME = $CURRENT_VALUE (safe)"
                else
                        PASSWORD_POLICY_WARNING="yes"
                        echo "WARNING: $SETTING_NAME = $CURRENT_VALUE (recommended: $RECOMMENDED_VALUE)"
                        read -p "Change $SETTING_NAME to '$RECOMMENDED_VALUE' now? (y/n): " ANSWER
                        if [ "$ANSWER" == "y" ]; then
                                sudo sed -i "s/^${SETTING_NAME}.*/${SETTING_NAME}   ${RECOMMENDED_VALUE}/" "$LOGIN_DEFS"
                                echo "Updated. (Applies to newly created accounts only — use 'chage' to update existing users.)"
                        else
                                echo "Skipped. No changes made."
                        fi
                fi
        }

        check_login_defs_setting "PASS_MAX_DAYS" "le" 90
        check_login_defs_setting "PASS_MIN_DAYS" "ge" 1
        check_login_defs_setting "PASS_MIN_LEN" "ge" 8
fi
echo "=========================================================================================================="

echo ""
echo "[11] Checking shared memory protection"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

FSTAB="/etc/fstab"
SHM_LINE=$(grep -E '[[:space:]](/run/shm|/dev/shm)[[:space:]]' "$FSTAB" 2>/dev/null)

if [ -z "$SHM_LINE" ]; then
        SHM_WARNING="yes"
        echo "NOTICE: No explicit /dev/shm entry found in $FSTAB (using kernel default mount)."
        read -p "Add a hardened /dev/shm entry (noexec,nosuid,nodev) to $FSTAB now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" | sudo tee -a "$FSTAB" > /dev/null
                echo "Added. (Run: sudo mount -o remount /dev/shm  to apply it, or reboot.)"
        else
                echo "Skipped. No changes made."
        fi
else
        echo "Current entry found: $SHM_LINE"
        MISSING_OPTS=""
        echo "$SHM_LINE" | grep -q "noexec" || MISSING_OPTS="${MISSING_OPTS}noexec,"
        echo "$SHM_LINE" | grep -q "nosuid" || MISSING_OPTS="${MISSING_OPTS}nosuid,"

        if [ -z "$MISSING_OPTS" ]; then
                echo "OK: Shared memory is mounted with noexec and nosuid."
        else
                SHM_WARNING="yes"
                echo "WARNING: Shared memory is missing protective option(s): ${MISSING_OPTS%,}"
                read -p "Add ${MISSING_OPTS%,} to the /dev/shm mount options now? (y/n): " ANSWER
                if [ "$ANSWER" == "y" ]; then
                        CURRENT_OPTS=$(echo "$SHM_LINE" | awk '{print $4}')
                        NEW_OPTS="${CURRENT_OPTS},${MISSING_OPTS%,}"
                        sudo sed -i "s|${CURRENT_OPTS}|${NEW_OPTS}|" "$FSTAB"
                        SHM_MOUNT_POINT=$(echo "$SHM_LINE" | awk '{print $2}')
                        echo "Updated. (Run: sudo mount -o remount $SHM_MOUNT_POINT  to apply it.)"
                else
                        echo "Skipped. No changes made."
                fi
        fi
fi
echo "=========================================================================================================="

echo ""
echo "[12] Checking system core dump settings"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

LIMITS_CONF="/etc/security/limits.conf"
CORE_LIMIT_LINE=$(grep -E '^\*[[:space:]]+hard[[:space:]]+core[[:space:]]+0' "$LIMITS_CONF" 2>/dev/null)

if [ -n "$CORE_LIMIT_LINE" ]; then
        echo "OK: Core dumps are disabled via $LIMITS_CONF ($CORE_LIMIT_LINE)."
else
        CORE_DUMP_WARNING="yes"
        echo "WARNING: No '* hard core 0' entry found in $LIMITS_CONF. Core dumps are not disabled."
        read -p "Add '* hard core 0' to $LIMITS_CONF now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                echo "*               hard    core            0" | sudo tee -a "$LIMITS_CONF" > /dev/null
                echo "Added. (Takes effect for new login sessions.)"
        else
                echo "Skipped. No changes made."
        fi
fi

echo ""
CORE_PATTERN=$(sysctl -n kernel.core_pattern 2>/dev/null)
echo "Current kernel.core_pattern: $CORE_PATTERN"

if [ "$CORE_PATTERN" == "|/bin/false" ] || [ "$CORE_PATTERN" == "/dev/null" ]; then
        echo "OK: kernel.core_pattern is configured to discard core dumps."
else
        CORE_DUMP_WARNING="yes"
        echo "WARNING: kernel.core_pattern is not configured to discard core dumps."
        read -p "Set kernel.core_pattern to discard core dumps now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                sudo sysctl -w kernel.core_pattern="|/bin/false" > /dev/null
                echo "kernel.core_pattern=|/bin/false" | sudo tee -a /etc/sysctl.conf > /dev/null
                echo "Updated and persisted in /etc/sysctl.conf."
        else
                echo "Skipped. No changes made."
        fi
fi
echo "=========================================================================================================="

echo ""
echo "[13] Checking automatic update configuration"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

if dpkg -l unattended-upgrades 2>/dev/null | grep -q "^ii"; then
        echo "OK: unattended-upgrades is installed."

        AUTO_UPGRADES_CONF="/etc/apt/apt.conf.d/20auto-upgrades"
        if [ -f "$AUTO_UPGRADES_CONF" ] && grep -q 'APT::Periodic::Unattended-Upgrade "1"' "$AUTO_UPGRADES_CONF"; then
                echo "OK: Automatic (unattended) upgrades are enabled."
        else
                AUTO_UPDATE_WARNING="yes"
                echo "WARNING: unattended-upgrades is installed but not enabled."
                read -p "Enable automatic security updates now? (y/n): " ANSWER
                if [ "$ANSWER" == "y" ]; then
                        sudo dpkg-reconfigure -plow unattended-upgrades
                        echo "Reconfigured. Check $AUTO_UPGRADES_CONF to confirm."
                else
                        echo "Skipped. Automatic updates remain disabled."
                fi
        fi
else
        AUTO_UPDATE_WARNING="yes"
        echo "NOTICE: unattended-upgrades is not installed. This system will not automatically"
        echo "install future security patches (see [7] for updates currently pending)."
        read -p "Install and enable unattended-upgrades now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                sudo apt update
                sudo apt install unattended-upgrades -y
                if [ $? -eq 0 ]; then
                        sudo dpkg-reconfigure -plow unattended-upgrades
                        echo "unattended-upgrades installed and configured."
                else
                        echo "WARNING: Installation did not complete successfully."
                fi
        else
                echo "Skipped. No automatic update mechanism installed."
        fi
fi
echo "=========================================================================================================="

echo ""
echo "[14] Checking audit logging"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

if command -v auditctl &> /dev/null; then
        if systemctl is-active --quiet auditd; then
                echo "OK: auditd is installed and running."
        else
                AUDIT_WARNING="yes"
                echo "WARNING: auditd is installed but not running."
                read -p "Start and enable auditd now? (y/n): " ANSWER
                if [ "$ANSWER" == "y" ]; then
                        sudo systemctl enable --now auditd
                        if [ $? -eq 0 ]; then
                                echo "auditd enabled and started."
                        else
                                echo "WARNING: Failed to enable/start auditd."
                        fi
                else
                        echo "Skipped. auditd remains inactive."
                fi
        fi
else
        AUDIT_WARNING="yes"
        echo "NOTICE: auditd is not installed. Security-relevant events (file access,"
        echo "privilege changes, auth attempts) are not being audited."
        read -p "Install and enable auditd now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                sudo apt update
                sudo apt install auditd audispd-plugins -y
                if [ $? -eq 0 ]; then
                        sudo systemctl enable --now auditd
                        echo "auditd installed, enabled, and started."
                else
                        echo "WARNING: auditd installation did not complete successfully."
                fi
        else
                echo "Skipped. No audit logging installed."
        fi
fi

echo ""
if systemctl is-active --quiet systemd-journald || systemctl is-active --quiet rsyslog; then
        echo "OK: A system logger (journald or rsyslog) is active."
else
        AUDIT_WARNING="yes"
        echo "WARNING: Neither systemd-journald nor rsyslog appears to be active."
        echo "System logs may not be captured. Manual investigation recommended —"
        echo "this typically indicates a non-standard init setup and is not auto-fixed."
fi
echo "=========================================================================================================="

echo ""
echo "[15] Overall Summary"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

WARNING_COUNT=0

[ -n "$RISKY_PORTS" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$GROUP_OTHER_WRITE" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$WORLD_WRITABLE" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ "$ROOT_COUNT" -gt 1 ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$EMPTY_PASS" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$NOPASSWD_ENTRIES" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$SECURITY_UPDATES" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$PASSWORD_POLICY_WARNING" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$SHM_WARNING" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$CORE_DUMP_WARNING" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$AUTO_UPDATE_WARNING" ] && WARNING_COUNT=$((WARNING_COUNT + 1))
[ -n "$AUDIT_WARNING" ] && WARNING_COUNT=$((WARNING_COUNT + 1))

echo "LinSentry Audit Complete."
echo ""
if [ "$WARNING_COUNT" -eq 0 ]; then
        echo "Result: EXCELLENT — no warnings found across any check."
elif [ "$WARNING_COUNT" -le 2 ]; then
        echo "Result: GOOD — $WARNING_COUNT warning(s) found. Review the sections above."
else
        echo "Result: NEEDS ATTENTION — $WARNING_COUNT warnings found. Review the sections above."
fi
echo "=========================================================================================================="