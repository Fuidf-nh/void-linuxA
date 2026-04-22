# void-install

Automated Void Linux installer with Sway desktop stack.

## Stack

| component | package |
|-----------|---------|
| WM | sway |
| Bar | waybar |
| Launcher | wofi |
| Terminal | foot |
| Notifications | mako |
| Audio | pipewire + wireplumber |
| Display manager | lightdm |
| Network | NetworkManager |

## Usage

Boot the Void Linux live ISO, then:

```bash
# Edit config block at top of script
nano void-install.sh

# Run
bash void-install.sh

# Reboot
umount -R /mnt && reboot
```

## Config

```bash
DISK="/dev/sda"        # target drive — check with lsblk
USERNAME="x7s"
HOSTNAME="voidbox"
TIMEZONE="America/New_York"
GITHUB_USER="your-username"
GITHUB_REPO="void-dotfiles"
```

## Partition layout

```
sda1  512M   EFI (vfat)
sda2  4G     swap
sda3  rest   / (ext4)
```

## After reboot

```bash
# Change default passwords
passwd
sudo passwd root

# Push dotfiles to GitHub
cd ~/dotfiles
git remote add origin git@github.com:$GITHUB_USER/$GITHUB_REPO.git
git branch -M main
git push -u origin main
```

## Services enabled

```
dbus / elogind / seatd / NetworkManager / lightdm
```

## Requirements

- UEFI system
- x86_64
- Target disk will be **wiped**
