# 🌸 vapor-rice-i3

> Declarative Arch Linux dotfiles with vaporwave aesthetics
>
> `./install.sh` — use it for install this rice

## Screenshots

![rice](screenshots/rice.png)
![rice2](screenshots/rice2.png)

## Snapshots

System snapshot support for easy rollback:

- **ext4/xfs/etc**: Timeshift with rsync (auto-snapshots on boot, daily, weekly, monthly)
- **Btrfs**: Snapper with native snapshots (auto-snapshots on pacman, bootable from GRUB)

Commands: `snapshot-create`, `snapshot-list`, `snapshot-delete`, `snapshot-rollback`

