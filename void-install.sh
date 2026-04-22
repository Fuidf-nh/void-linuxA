#!/bin/bash
# void-install.sh — run from live ISO as root
# Edit the CONFIG section, then: bash void-install.sh

set -euo pipefail

# ─── CONFIG ────────────────────────────────────────────────
DISK="/dev/sda"
USERNAME="x7s"
HOSTNAME="voidbox"
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
REPO="https://repo-default.voidlinux.org/current"
ARCH="x86_64"
GITHUB_USER="your-github-username"
GITHUB_REPO="void-dotfiles"
# ───────────────────────────────────────────────────────────

EFI="${DISK}1"
SWAP="${DISK}2"
ROOT="${DISK}3"

echo ">>> Partitioning $DISK"
parted -s "$DISK" \
  mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart swap linux-swap 513MiB 4609MiB \
  mkpart root ext4 4609MiB 100%

echo ">>> Formatting"
mkfs.fat -F32 "$EFI"
mkswap "$SWAP" && swapon "$SWAP"
mkfs.ext4 -F "$ROOT"

echo ">>> Mounting"
mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI" /mnt/boot/efi

echo ">>> Installing base"
XBPS_ARCH=$ARCH xbps-install -S -R "$REPO" -r /mnt \
  base-system grub-x86_64-efi efibootmgr

echo ">>> Copying DNS"
cp /etc/resolv.conf /mnt/etc/

echo ">>> Chroot setup"
xchroot /mnt /bin/bash <<CHROOT
set -euo pipefail

# Passwords
echo "root:root" | chpasswd
useradd -m -G wheel,audio,video,input,_seatd "$USERNAME"
echo "${USERNAME}:${USERNAME}" | chpasswd
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME

# System
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Locale
echo "$LOCALE UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales

# fstab
ROOT_UUID=\$(blkid -s UUID -o value $ROOT)
EFI_UUID=\$(blkid -s UUID -o value $EFI)
SWAP_UUID=\$(blkid -s UUID -o value $SWAP)
cat >> /etc/fstab <<FSTAB
UUID=\$ROOT_UUID / ext4 defaults 0 1
UUID=\$EFI_UUID /boot/efi vfat defaults 0 2
UUID=\$SWAP_UUID swap swap defaults 0 0
FSTAB

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=void
grub-mkconfig -o /boot/grub/grub.cfg

# Desktop stack
xbps-install -Sy \
  sway xwayland waybar wofi foot \
  dbus elogind polkit seatd \
  pipewire wireplumber alsa-utils \
  NetworkManager \
  lightdm lightdm-gtk3-greeter \
  git curl wget nano bash-completion \
  mako grim slurp wl-clipboard \
  brightnessctl pamixer \
  void-repo-nonfree

# Services
ln -s /etc/sv/dbus            /var/service/
ln -s /etc/sv/elogind         /var/service/
ln -s /etc/sv/seatd           /var/service/
ln -s /etc/sv/NetworkManager  /var/service/
ln -s /etc/sv/lightdm         /var/service/

# ─── Configs ───────────────────────────────────────────────
CFGDIR="/home/$USERNAME/.config"
mkdir -p \$CFGDIR/sway \$CFGDIR/waybar \$CFGDIR/wofi \$CFGDIR/foot \$CFGDIR/mako

# Sway
cp /etc/sway/config \$CFGDIR/sway/config
cat >> \$CFGDIR/sway/config <<SWAYCONF

exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
exec pipewire &
exec pipewire-pulse &
exec wireplumber &
exec mako &

bindsym \$mod+Return exec foot
bindsym \$mod+d exec wofi --show drun
bindsym \$mod+Shift+s exec grim -g "\$(slurp)" ~/Pictures/shot-\$(date +%s).png

gaps inner 8
gaps outer 4
default_border pixel 2
SWAYCONF

# Waybar
cat > \$CFGDIR/waybar/config <<WAYBAR
{
  "layer": "top",
  "position": "top",
  "modules-left": ["sway/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio","network","battery","tray"],
  "clock": { "format": "%a %d %b  %H:%M" },
  "network": { "format-wifi": " {essid}", "format-ethernet": " eth", "format-disconnected": "offline" },
  "pulseaudio": { "format": " {volume}%" },
  "battery": { "format": "{capacity}% {icon}", "format-icons": ["","","","",""] }
}
WAYBAR

# Foot
cat > \$CFGDIR/foot/foot.ini <<FOOT
[main]
font=monospace:size=11

[colors]
background=0d0d0d
foreground=f0f0f0
regular1=cc3333
regular2=44aa44
regular4=3366cc
FOOT

# Git config
sudo -u $USERNAME git config --global user.name "$USERNAME"
sudo -u $USERNAME git config --global user.email "$USERNAME@$HOSTNAME"
sudo -u $USERNAME git config --global init.defaultBranch main

chown -R $USERNAME:$USERNAME /home/$USERNAME/.config

# ─── Dotfiles repo ─────────────────────────────────────────
cd /home/$USERNAME
sudo -u $USERNAME git init dotfiles
cd dotfiles
sudo -u $USERNAME cp -r /home/$USERNAME/.config .

cat > README.md <<README
# void-dotfiles
Void Linux + Sway config for $HOSTNAME

## Stack
sway / waybar / wofi / foot / mako / pipewire / lightdm

## Push
\`\`\`bash
git remote add origin git@github.com:$GITHUB_USER/$GITHUB_REPO.git
git push -u origin main
\`\`\`
README

sudo -u $USERNAME git add .
sudo -u $USERNAME git commit -m "init: void linux dotfiles"
chown -R $USERNAME:$USERNAME /home/$USERNAME/dotfiles

xbps-reconfigure -fa
CHROOT

echo ""
echo "════════════════════════════════════"
echo " Done! Default passwords = username"
echo " Change after reboot: passwd"
echo "════════════════════════════════════"
echo ""
echo ">>> umount -R /mnt && reboot"
echo ""
echo ">>> After reboot, push dotfiles:"
echo "    cd ~/dotfiles"
echo "    git remote add origin git@github.com:$GITHUB_USER/$GITHUB_REPO.git"
echo "    git branch -M main"
echo "    git push -u origin main"
