# LinSentry

A lightweight Linux security hardening auditor, written in Bash.

LinSentry scans a Linux system for common security misconfigurations —
the kind of everyday oversights (open ports, weak SSH settings, loose file
permissions) that automated attacks scan for constantly. It reports what
it finds in plain language, and offers to fix certain issues interactively.

## Features

- **Open port scanning** — lists all active TCP/UDP listening ports
- **Port exposure detection** — flags any port reachable from any network
  device (`0.0.0.0` / `[::]`), not just the local machine
- **SSH configuration audit** — checks `PermitRootLogin`,
  `PasswordAuthentication`, and `PermitEmptyPasswords` against safe values,
  with interactive prompts to fix unsafe or unset settings
- **SSH config file permission audit** — verifies `sshd_config` is owned
  by root and not writable by group or others
- **World-writable file scanner** — finds files that any user on the
  system can modify, starting with the home directory
- **User account audit** — flags duplicate UID 0 (root-level) accounts
  and lists unfamiliar ones for review; detects accounts with no
  password set and offers to assign one interactively
- **Sudo privilege audit** — lists sudo group members for review and
  flags NOPASSWD entries (detection only — sudo/privilege changes are
  intentionally left to the administrator's judgment)
- **Firewall status check** — detects if ufw is installed/active, offers
  to install or enable it, and lets you selectively close specific
  exposed ports
- **Pending security update check** — flags packages with available
  security updates and offers to install them
- **Security framework (AppArmor) status** — checks if AppArmor is
  installed and enforcing; handles a known WSL limitation gracefully
- **Malware/rootkit scanner presence check** — checks for rkhunter or
  chkrootkit; offers to install rkhunter if neither is present
- **Overall risk summary** — tallies warnings across all checks into a
  final result (Excellent / Good / Needs Attention)

## Requirements

- A Linux environment (tested on Ubuntu via WSL)
- Bash
- `sudo` privileges (required only if you choose to apply suggested fixes)

## Usage

```bash
chmod +x linsentry.sh
./linsentry.sh
```

The script will print a report section by section. For any setting it
finds unsafe or unset, it will ask for confirmation (y/n) before making
any changes — nothing is modified without explicit permission.

## Roadmap

- [ ] Pending security update check
- [ ] Overall risk score summary
- [ ] Windows, MacOs and Termux implementation

## Versioning

This project follows [Semantic Versioning](https://semver.org/).
See tagged releases for version history.

## Disclaimer

This tool is for educational and personal auditing purposes. Always
review suggested changes before applying them to a production system.
