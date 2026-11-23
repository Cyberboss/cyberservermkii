# Cyberserver MkII

My personal NixOS configuration.

## Context Dependent Configs

See highlighted section in [globals.nix](./system/globals.nix).

## External Configuration

Mostly done via [secrets.yml](./system/modules/secrets/secrets.yml).

### Restic Backup Target

Must be S3.

Recommend Backblaze B2.

### Cloudflare Tunnels

Setup via free cloudflare.

## Backup Restore

1. Install a BASIC FUNCTIONAL (without the flake) barebones NixOS, partition FS as necessary, and reboot into it. MAKE SURE HOSTNAME IS SET TO EITHER `cyberservermkii-BACKUPRESTORE` or `cyberservermkii` AS APPROPRIATE!
1. Setup [.local](./.local) layout LEAVE THE `backup-restore-safety-key` TURNED.
1. Copy latest `flake.lock` backup from `flake-lock-backup-path` in [globals.nix](./system/globals.nix) to `/etc/nixos/flake.lock` and restore `/etc/ssh/ssh_host_ed25519_key` (Use restic-browser).
1. Run `nixos-rebuild --flake /etc/nixos build`, confirm everything looks good.
1. Disconnect from the internet.
1. Run `nixos-rebuild --flake /etc/nixos switch`.
1. Run `passwd dominion`. Configure google authenticator for account.
1. Ensure no key services (like bluesky or cloudflared) are started.
1. Run `backup-restore-YES-REALLY_FOR_REALZ_NOT_A_DRILL` and follow prompts.
