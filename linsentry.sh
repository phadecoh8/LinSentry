#!/bin/bash

echo "=========================================================================================================="
echo " Sysytem Hardening Aduit"
echo "=========================================================================================================="
echo ""
echo "Starting checks..."

echo ""
echo "[1] checking open network ports"
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
echo "==========================================================================================================="

echo""
echo "[2a] Checking SSH configuration"
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

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


	echo ""
	echo "[2b] Checking permissions on $SSHD_CONFIG..."
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

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
echo "[3] Checking for world-writeble files in your home folder"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

WORLD_WRITABLE=$(find ~ -type f -perm -o+w 2>/dev/null)

if [ -z "$WORLD_WRITABLE" ]; then 
	echo "None found. No world-writable files in $HOME."
else 
	echo "WARNING: The following files can be modified by ANY user on this system:"
	echo "$WORLD_WRITABLE"
fi
echo "==========================================================================================================="

echo ""
echo "[4a] Checking User's accounts ... "
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "Checking for duplicate UID 0 (root-level) accounts..."
ROOT_ACCOUNTS=$(awk -F: '$3 == 0 {print $1} ' /etc/passwd)
ROOT_COUNT=$(echo "$ROOT_ACCOUNTS" | wc -l)

if [ "$ROOT_COUNT" -gt 1 ]; then
	echo "WARNING: Multiple UID 0 accounts found:"
	echo "$ROOT_ACCOUNTS"
	echo ""
	echo "Acounts other than 'root' with UID 0 (review these carefully):"
	echo "$ROOT_ACCOUNTS" | grep -v "^root$"
else 
	echo "OK: Only one UID 0 (root) account found."
fi

echo ""
echo "[4b] Checking for accounts with empty passwords..."
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
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
echo "=============================================================================================================="

echo ""
echo "[5] Checking sudo privileges"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

echo "[5a] Members of the sudo group..."
SUDO_MEMBERS=$(getent group sudo | cut -d: -f4)

if [ -z "$SUDO_MEMBERS" ]; then
	echo "No user found in the sudo group."
else 
	echo "The following users have sudo privileges"
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

echo "=============================================================================================================="


echo ""
echo "[6a] Checking firewall status"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

if ! command -v ufw &> /dev/null; then
        echo "NOTICE: ufw (firewall) is not installed on this system."
        read -p "Install ufw now? (y/n): " ANSWER
        if [ "$ANSWER" == "y" ]; then
                sudo apt update
                sudo apt install ufw -y
                echo "ufw installed. It is not enabled yet — see below."
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
                        echo "ufw enabled."
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
echo "=============================================================================================================="



echo ""
echo "[6b] Closing exposed ports"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

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
echo "================================================================="