#!/usr/bin/env bash
set -euo pipefail

# --- Color Output Helpers ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Set workspace fallback directory
WORK_DIR="/tmp/nixos-config"

# Safely check if BASH_SOURCE[0] exists (curl piping leaves it unset)
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR="$WORK_DIR"
fi

echo -e "${BLUE}=== NixOS Modular Automated Installer ===${NC}\n"

# --- Pre-Flight System Checks ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run as root (e.g. using sudo).${NC}"
  exit 1
fi

if [ ! -d "/sys/firmware/efi" ]; then
  echo -e "${RED}Error: Booted in Legacy mode. UEFI is required.${NC}"
  exit 1
fi

# --- Helper Functions ---
detect_gpu() {
  local gpu_info
  gpu_info=$(lspci -vnnn | grep -E "VGA|3D|Display" || true)

  if echo "$gpu_info" | grep -iq "NVIDIA"; then
    echo "nvidia"
  elif echo "$gpu_info" | grep -iq "Advanced Micro Devices\|AMD\|ATI"; then
    echo "amd"
  elif echo "$gpu_info" | grep -iq "Intel"; then
    echo "intel"
  else
    echo "none"
  fi
}

select_filesystem() {
  local prompt_target="$1"
  echo -e "\n${BLUE}--> Select Filesystem for ${prompt_target} Partition:${NC}" >&2
  echo "1) ext4 (Standard / Robust - Default)" >&2
  echo "2) btrfs (Snapshots / Compression)" >&2
  echo "3) xfs (High Performance)" >&2
  echo "4) zfs (Advanced Data Integrity)" >&2
  read -rp "Choice [1-4]: " FS_CHOICE

  case $FS_CHOICE in
    1) echo "ext4" ;;
    2) echo "btrfs" ;;
    3) echo "xfs" ;;
    4) echo "zfs" ;;
    *) echo "ext4" ;;
  esac
}

select_timezone() {
  echo -e "\n${BLUE}--> Timezone Selection${NC}"
  echo "1) Pick from Region list (recommended)"
  echo "2) Enter raw timezone string manually"
  read -rp "Choice [1-2]: " TZ_CHOICE

  if [ "$TZ_CHOICE" -eq 1 ]; then
    echo -e "\nSelect Region:"
    regions=("America" "Europe" "Asia" "Africa" "Australia" "Pacific" "UTC")
    select reg in "${regions[@]}"; do
      if [ -n "$reg" ]; then
        if [ "$reg" = "UTC" ]; then
          TIMEZONE_VAR="UTC"
          break
        fi
        
        echo -e "\nMatching timezones for ${reg}:"
        mapfile -t tz_list < <(timedatectl list-timezones | grep "^${reg}/" || true)
        
        if [ ${#tz_list[@]} -eq 0 ]; then
          read -rp "Enter Timezone (e.g. America/Edmonton): " TIMEZONE_VAR
          break
        fi

        PS3="Select city/zone number: "
        select tz in "${tz_list[@]}"; do
          if [ -n "$tz" ]; then
            TIMEZONE_VAR="$tz"
            break 2
          fi
        done
      fi
    done
  else
    read -rp "Enter Timezone (e.g. America/Edmonton): " TIMEZONE_VAR
  fi
}

# --- 1. User & System Parameters Gathering ---
echo -e "${BLUE}--> Select Target Disk:${NC}"
lsblk -d -n -o NAME,SIZE,TYPE,MODEL | grep -E "disk"
read -rp "Enter Target Disk (e.g. /dev/sda or /dev/nvme0n1): " DISK_VAR

if [ ! -b "$DISK_VAR" ]; then
  echo -e "${RED}Error: Device ${DISK_VAR} is not a valid block device.${NC}"
  exit 1
fi

DISK_BYTES=$(lsblk -b -d -n -o SIZE "$DISK_VAR")
DISK_SIZE_GB=$(( DISK_BYTES / 1024 / 1024 / 1024 ))

read -rp "Enter Hostname: " HOST_VAR
read -rp "Enter Username: " USER_VAR

select_timezone

echo ""
read -rsp "Enter Password for ${USER_VAR} & Root: " PASS_VAR
echo ""
read -rsp "Confirm Password: " PASS_CONFIRM_VAR
echo ""

if [ "$PASS_VAR" != "$PASS_CONFIRM_VAR" ]; then
  echo -e "${RED}Error: User passwords do not match.${NC}"
  exit 1
fi
HASHED_PASS=$(mkpasswd -m sha-512 "$PASS_VAR")

# --- LUKS Encryption Password Prompt ---
echo ""
read -rsp "Enter LUKS Disk Encryption Password: " LUKS_PASS_VAR
echo ""
read -rsp "Confirm LUKS Disk Encryption Password: " LUKS_PASS_CONFIRM_VAR
echo ""

if [ "$LUKS_PASS_VAR" != "$LUKS_PASS_CONFIRM_VAR" ]; then
  echo -e "${RED}Error: LUKS passwords do not match.${NC}"
  exit 1
fi

echo -e "\n${BLUE}--> Select Default Wayland Compositor${NC}"
echo "1) Umbriel"
echo "2) Hyprland"
read -rp "Choice [1-2]: " COMPOSITOR_CHOICE

if [ "$COMPOSITOR_CHOICE" -eq 2 ]; then
  UMBRIEL_SYS="false"
  HYPR_SYS="true"
  COMPOSITOR_NAME="Hyprland"
else
  UMBRIEL_SYS="true"
  HYPR_SYS="false"
  COMPOSITOR_NAME="Umbriel"
fi

DETECTED_GPU=$(detect_gpu)
echo -e "\n${BLUE}--> GPU Hardware Detection${NC}"
echo -e "Auto-detected GPU Vendor: ${GREEN}${DETECTED_GPU}${NC}"
echo "1) Use Auto-detected (${DETECTED_GPU})"
echo "2) AMD"
echo "3) Intel"
echo "4) Nvidia"
echo "5) Integrated / None"
read -rp "Choice [1-5]: " GPU_SELECT

case $GPU_SELECT in
  1) GPU_TYPE="$DETECTED_GPU" ;;
  2) GPU_TYPE="amd" ;;
  3) GPU_TYPE="intel" ;;
  4) GPU_TYPE="nvidia" ;;
  5) GPU_TYPE="none" ;;
  *) GPU_TYPE="$DETECTED_GPU" ;;
esac

TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$(( (TOTAL_RAM_KB + 1048575) / 1048576 ))

echo -e "\n${BLUE}--> Swap & Partition Scheme Selection${NC}"
echo "Detected System RAM: ${TOTAL_RAM_GB} GB"
echo "1) Hibernation Swap (Equal to RAM size: ${TOTAL_RAM_GB}G)"
echo "2) Minimal Swap (4 GB)"
echo "3) No Swap (0 GB)"
read -rp "Choice [1-3]: " SWAP_CHOICE

case $SWAP_CHOICE in
  1) SWAP_SIZE_G=$TOTAL_RAM_GB ;;
  2) SWAP_SIZE_G=4 ;;
  3) SWAP_SIZE_G=0 ;;
  *) SWAP_SIZE_G=4 ;;
esac

REMAINING_GB=$(( DISK_SIZE_GB - SWAP_SIZE_G - 1 ))
SPLIT_HOME=false
ROOT_SIZE_G=$REMAINING_GB

if [ "$REMAINING_GB" -ge 120 ]; then
  echo -e "\nUsable disk space (${REMAINING_GB} GB) allows a separate /home volume."
  echo "1) Single Root Partition (100% FREE to /)"
  echo "2) Separate /home Volume (80GB for /, remainder for /home)"
  read -rp "Choice [1-2]: " SPLIT_CHOICE
  if [ "$SPLIT_CHOICE" -eq 2 ]; then
    SPLIT_HOME=true
    ROOT_SIZE_G=80
  fi
fi

# Select Filesystems for Partitions
ROOT_FS=$(select_filesystem "Root (/)")
if [ "$SPLIT_HOME" = true ]; then
  HOME_FS=$(select_filesystem "Home (/home)")
else
  HOME_FS="$ROOT_FS"
fi

# --- 2. Interactive Package Selection & Default Applications ---
echo -e "\n${BLUE}--> Application & Package Selection${NC}"

PKG_OPTIONS=(
  "Audacity (Audio Editor)"             "audacity"
  "Bitwarden (Password Manager)"        "bitwarden-desktop"
  "Blender (3D Modeling)"               "blender"
  "Calibre (E-Book Manager)"            "calibre"
  "Element (Matrix Client)"             "element-desktop"
  "FileZilla (FTP Client)"              "filezilla"
  "GIMP (Image Editor)"                 "gimp"
  "HandBrake (Video Transcoder)"        "handbrake"
  "Inkscape (Vector Graphics)"          "inkscape"
  "Kdenlive (Video Editor)"             "kdenlive"
  "KeePassXC (Password Manager)"        "keepassxc"
  "LibreOffice (Office Suite)"          "libreoffice"
  "Lutris (Gaming Platform)"            "lutris"
  "MPV (Media Player)"                  "mpv"
  "OBS Studio (Screen Recording)"       "obs-studio"
  "Obsidian (Notes & Knowledge)"        "obsidian"
  "P7Zip (Archive Utility)"             "p7zip"
  "Ripgrep (CLI Search Utility)"        "ripgrep"
  "Signal Desktop (Messaging)"          "signal-desktop"
  "Spotify (Music Client)"              "spotify"
  "Steam (Gaming Platform)"             "steam"
  "Syncthing (File Sync)"               "syncthing"
  "Thunderbird (Email Client)"          "thunderbird"
  "Tmux (Terminal Multiplexer)"         "tmux"
  "Tor Browser (Privacy Browser)"       "tor-browser"
  "Transmission (BitTorrent Client)"    "transmission_4-qt"
  "Vesktop (Discord Client)"            "vesktop"
  "VLC (Multimedia Player)"             "vlc"
  "VS Code (Code Editor)"               "vscode"
  "VSCodium (Telemetry-Free VS Code)"   "vscodium"
  "Wireshark (Network Analyzer)"        "wireshark"
  "Zotero (Reference Manager)"          "zotero"
)

SELECTED_CHOICES=()

for ((i=0; i<${#PKG_OPTIONS[@]}; i+=2)); do
  label="${PKG_OPTIONS[i]}"
  attr="${PKG_OPTIONS[i+1]}"
  read -rp "Install $label? [y/N]: " choice
  choice_clean=$(echo "$choice" | tr '[:upper:]' '[:lower:]' | xargs)
  if [[ "$choice_clean" == "y" || "$choice_clean" == "yes" ]]; then
    SELECTED_CHOICES+=("$attr")
    echo -e "  ${GREEN}+ Added: ${attr}${NC}"
  fi
done

echo -e "\n${BLUE}--> Select Default File Manager${NC}"
echo "1) Yazi (Terminal TUI Default)"
echo "2) Thunar (GTK / XFCE)"
echo "3) Dolphin (KDE)"
echo "4) Nemo (GTK)"
echo "5) PCManFM"
read -rp "Choice [1-5]: " FM_SEL
case $FM_SEL in
  1) FM_CHOICE="yazi" ;;
  2) FM_CHOICE="thunar" ;;
  3) FM_CHOICE="dolphin" ;;
  4) FM_CHOICE="nemo" ;;
  5) FM_CHOICE="pcmanfm" ;;
  *) FM_CHOICE="yazi" ;;
esac

echo -e "\n${BLUE}--> Select Default Web Browser${NC}"
echo "1) Firefox"
echo "2) Brave"
echo "3) Chromium"
echo "4) Tor Browser"
read -rp "Choice [1-4]: " BROWSER_SEL
case $BROWSER_SEL in
  1) BROWSER_CHOICE="firefox" ;;
  2) BROWSER_CHOICE="brave" ;;
  3) BROWSER_CHOICE="chromium" ;;
  4) BROWSER_CHOICE="tor-browser" ;;
  *) BROWSER_CHOICE="firefox" ;;
esac

echo -e "\n${BLUE}--> Select Default Terminal Emulator${NC}"
echo "1) foot / footclient"
echo "2) Kitty"
echo "3) Alacritty"
read -rp "Choice [1-3]: " TERM_SEL
case $TERM_SEL in
  1) TERM_CHOICE="foot" ;;
  2) TERM_CHOICE="kitty" ;;
  3) TERM_CHOICE="alacritty" ;;
  *) TERM_CHOICE="foot" ;;
esac

echo -e "\n${BLUE}--> Select Default Text Editor${NC}"
echo "1) Neovim"
echo "2) VS Code"
echo "3) VSCodium"
read -rp "Choice [1-3]: " EDITOR_SEL
case $EDITOR_SEL in
  1) EDITOR_CHOICE="neovim" ;;
  2) EDITOR_CHOICE="vscode" ;;
  3) EDITOR_CHOICE="vscodium" ;;
  *) EDITOR_CHOICE="neovim" ;;
esac

if [ "$EDITOR_CHOICE" = "neovim" ]; then
  EDITOR_EXEC="nvim"
else
  EDITOR_EXEC="$EDITOR_CHOICE"
fi

if [ "$FM_CHOICE" = "yazi" ]; then
  FM_EXEC="footclient -e yazi"
else
  FM_EXEC="$FM_CHOICE"
fi

ALL_PKGS=("$FM_CHOICE" "$BROWSER_CHOICE" "$TERM_CHOICE" "$EDITOR_CHOICE")

if [ "${#SELECTED_CHOICES[@]}" -gt 0 ]; then
  ALL_PKGS+=("${SELECTED_CHOICES[@]}")
fi

mapfile -t UNIQUE_PKGS < <(printf "%s\n" "${ALL_PKGS[@]}" | sort -u)

# --- 3. Pre-Flight Review & Confirmation ---
echo -e "\n${YELLOW}====================================================${NC}"
echo -e "${YELLOW}            PRE-FLIGHT CONFIGURATION SUMMARY          ${NC}"
echo -e "${YELLOW}====================================================${NC}"
printf "%-22s : %s (%s GB)\n" "Target Disk:" "${DISK_VAR}" "${DISK_SIZE_GB}"
printf "%-22s : %s\n" "Hostname:" "${HOST_VAR}"
printf "%-22s : %s\n" "Username:" "${USER_VAR}"
printf "%-22s : %s\n" "Timezone:" "${TIMEZONE_VAR}"
printf "%-22s : %s\n" "Compositor:" "${COMPOSITOR_NAME}"
printf "%-22s : %s\n" "GPU Profile:" "${GPU_TYPE}"
printf "%-22s : %s GB\n" "Swap Size:" "${SWAP_SIZE_G}"
printf "%-22s : %s\n" "Root Filesystem:" "${ROOT_FS}"
if [ "$SPLIT_HOME" = true ]; then
  printf "%-22s : %s\n" "Home Filesystem:" "${HOME_FS}"
fi
printf "%-22s : %s\n" "Default Browser:" "${BROWSER_CHOICE}"
printf "%-22s : %s\n" "Default Editor:" "${EDITOR_CHOICE}"
printf "%-22s : %s\n" "Default Terminal:" "${TERM_CHOICE}"
printf "%-22s : %s\n" "Default File Manager:" "${FM_CHOICE}"
printf "%-22s : %s packages selected\n" "Extra Packages:" "${#SELECTED_CHOICES[@]}"
echo -e "${YELLOW}====================================================${NC}"
echo -e "${RED}WARNING: ALL DATA ON ${DISK_VAR} WILL BE ERASED!${NC}"
read -rp "Proceed with disk formatting & installation? [y/N]: " CONFIRM_PROCEED

if [[ ! "$CONFIRM_PROCEED" =~ ^[Yy]$ ]]; then
  echo -e "${BLUE}Installation aborted by user.${NC}"
  exit 0
fi

# --- 4. Partitioning & Formatting via Disko ---
REPO_URL="https://github.com/dyl914/nixos-noctalia-install.git"
WORK_DIR="/tmp/nixos-config"

echo -e "\n${BLUE}--> Fetching configuration repository...${NC}"
rm -rf "$WORK_DIR"
git clone --depth 1 "$REPO_URL" "$WORK_DIR"
SCRIPT_DIR="$WORK_DIR"

echo -e "\n${BLUE}--> Writing keyfile and running Disko...${NC}"

KEYFILE="/tmp/disko-luks.key"
echo -n "${LUKS_PASS_VAR}" > "$KEYFILE"
chmod 600 "$KEYFILE"

# Clean up keyfile on exit or interrupt
trap 'rm -f "$KEYFILE"' EXIT

nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- \
  --mode disko "${SCRIPT_DIR}/disko.nix" \
  --argstr disk "${DISK_VAR}" \
  --argstr keyFile "${KEYFILE}" \
  --argstr rootFS "${ROOT_FS}" \
  --argstr homeFS "${HOME_FS}" \
  --arg swapSizeG "${SWAP_SIZE_G}" \
  --arg rootSizeG "${ROOT_SIZE_G}" \
  --arg splitHome "${SPLIT_HOME}"

# --- 5. Provision Target Workspace & Symlink Configuration ---
TARGET_DIR="/mnt"
USER_HOME="${TARGET_DIR}/home/${USER_VAR}"
DOTFILES_DIR="${USER_HOME}/dotfiles"

echo -e "\n${BLUE}--> Provisioning dotfiles to target system (${DOTFILES_DIR})...${NC}"
mkdir -p "${DOTFILES_DIR}"
cp -r "${SCRIPT_DIR}/"* "${DOTFILES_DIR}/"

echo -e "${BLUE}--> Constructing /etc/nixos symlink to user dotfiles...${NC}"
mkdir -p "${TARGET_DIR}/etc"
rm -rf "${TARGET_DIR}/etc/nixos"
ln -s "/home/${USER_VAR}/dotfiles" "${TARGET_DIR}/etc/nixos"

# --- 6. Write Generated Home Manager Modules ---
HOME_MODULE_DIR="${DOTFILES_DIR}/modules/home"
mkdir -p "$HOME_MODULE_DIR"

FORMATTED_PKGS=""
for pkg in "${UNIQUE_PKGS[@]}"; do
  FORMATTED_PKGS="${FORMATTED_PKGS}\n    ${pkg}"
done

cat <<EOF > "${HOME_MODULE_DIR}/userPackages.nix"
# Auto-generated by install.sh
{ pkgs, ... }:

{
  home.packages = with pkgs; [${FORMATTED_PKGS}
  ];
}
EOF

FOOT_SERVICE_NIX=""
if [ "$TERM_CHOICE" = "foot" ]; then
  FOOT_SERVICE_NIX="
  services.foot.enable = true;
  services.foot.server.enable = true;"
fi

cat <<EOF > "${HOME_MODULE_DIR}/defaultApps.nix"
# Auto-generated by install.sh
{ ... }:

{
  home.sessionVariables = {
    BROWSER = "${BROWSER_CHOICE}";
    FILEMANAGER = "${FM_EXEC}";
    TERMINAL = "${TERM_CHOICE}";
    EDITOR = "${EDITOR_EXEC}";
  };${FOOT_SERVICE_NIX}
}
EOF

# --- 7. Apply Variables and Compositor Toggles ---
cd "${DOTFILES_DIR}"
echo -e "${BLUE}--> Injecting configuration template variables...${NC}"

find . -type f -name "*.nix" -exec sed -i "s|@USERNAME@|${USER_VAR}|g" {} +
find . -type f -name "*.nix" -exec sed -i "s|@HOSTNAME@|${HOST_VAR}|g" {} +
find . -type f -name "*.nix" -exec sed -i "s|@TIMEZONE@|${TIMEZONE_VAR}|g" {} +
sed -i "s|@HASHED_PASSWORD@|${HASHED_PASS}|g" configuration.nix

if [ -f "modules/configuration/gpuConfiguration.nix" ]; then
  sed -i "s|@GPU_TYPE@|${GPU_TYPE}|g" modules/configuration/gpuConfiguration.nix
fi

sed -i "s|programs.umbriel.enable = .*;|programs.umbriel.enable = ${UMBRIEL_SYS};|g" configuration.nix home.nix
sed -i "s|programs.hyprland.enable = .*;|programs.hyprland.enable = ${HYPR_SYS};|g" configuration.nix home.nix

# --- 8. Hardware Detection & Flake Git Setup ---
echo -e "${BLUE}--> Generating hardware configuration...${NC}"
nixos-generate-config --root "${TARGET_DIR}" --dir "${DOTFILES_DIR}"

echo -e "${BLUE}--> Initializing Git repository for Nix Flake tracking...${NC}"
git init
git config user.name "NixOS Installer"
git config user.email "installer@localhost"
git add .
git commit -m "chore: automated nixos deployment" || true

# --- 9. Execute System Build ---
echo -e "\n${GREEN}=== Executing nixos-install ===${NC}"
nixos-install --root "${TARGET_DIR}" --flake "${TARGET_DIR}/etc/nixos#default"

# --- 10. Correct System & Symlink Permissions ---
echo -e "${BLUE}--> Setting ownership across home directory and /etc/nixos symlink...${NC}"
nixos-enter --root "${TARGET_DIR}" -- chown -R -h "${USER_VAR}:users" "/home/${USER_VAR}" "/etc/nixos"

echo -e "\n${GREEN}=== Installation Complete! Remove installation media and reboot. ===${NC}"
