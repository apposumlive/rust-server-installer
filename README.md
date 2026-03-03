# Rust Dedicated Server — One-Click Installer

**The fastest and most reliable way to install a Rust Dedicated Server on Ubuntu**

One single command → answer 5 simple questions → fully working server with systemd, rcon-cli, auto-restart, logs, firewall and everything you need.

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20%2F%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Rust](https://img.shields.io/badge/Rust-258550-000000?style=for-the-badge&logo=rust&logoColor=white)
![SteamCMD](https://img.shields.io/badge/SteamCMD-171A21-000000?style=for-the-badge)

## ✨ Features

- True **one-command installation**
- Interactive setup (server name, RCON password, map seed, world size, max players)
- Strong random RCON password generated automatically
- Professional **rcon-cli** installed automatically
- systemd service with auto-restart on crash
- Clean folder structure + central `config.env` file
- Automatic opening of all required ports via UFW
- Rust+ App support included
- Ready for daily scheduled restarts

## 🚀 Installation (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/apposumlive/rust-server-installer/main/install.sh | bash