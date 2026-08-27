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
- **World-writable file scanner** — finds files that any user on the
  system can modify, starting with the home directory
- **User account audit** — flags duplicate UID 0 (root-level) accounts
  and lists unfamiliar ones for review; detects accounts with no
  password set and offers to assign one interactively

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

- [ ] Permission checks on critical individual files (e.g. `sshd_config`)
- [ ] Sudo privilege audit
- [ ] Firewall status check
- [ ] Pending security update check
- [ ] Overall risk score summary

## Versioning

This project follows [Semantic Versioning](https://semver.org/).
See tagged releases for version history.

## Disclaimer

This tool is for educational and personal auditing purposes. Always
review suggested changes before applying them to a production system.
