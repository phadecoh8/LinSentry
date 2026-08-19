#!/bin/bash

echo "=========================================================================================================="
echo " Sysytem Hardening Aduit"
echo "=========================================================================================================="
echo ""
echo "Starting checks..."

echo ""
echo "[1] checking open network ports"
echo "-----------------------------------------------------------------------------------------------------------"
ss -tuln

echo ""
echo "[1b] Flagging ports exposed to the outside world"
echo "-----------------------------------------------------------------------------------------------------------"

RISKY_PORTS=$(ss -tuln | awk '$5 ~ /^0\.0\.0\.0:|^\[::\]:/')

if [ -z "$RISKY_PORTS" ]; then
        echo "None Found. All listening ports are local-only (safe)."
else
        echo "WARNING: The following ports are open to any network device:"
        echo "$RISKY_PORTS"
fi

echo""
echo "[2] Checking SSH configuration"
echo "-----------------------------------------------------------------------------------------------------------"

SSHD_CONFIG="/etc/ssh/sshd_config"
if [ ! -f $SSHD_CONFIG ]; then
	echo "No SSH server config found ($SSHD_CONFIG). SSH checks skipped"
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
fi


    echo ""
    echo "[2b] Checking permissions on $SSHD_CONFIG..."
    echo "------------------------------------"

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
