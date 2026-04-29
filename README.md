# Samsung Galaxy Book 4 Fingerprint Fix (Fedora)

**Languages:** **English** · [Português (Brasil)](README.pt-BR.md) · [Español](README.es.md)

Make the fingerprint reader of the **Samsung Galaxy Book 4** work on **Fedora**
(login, lock screen and `sudo`).

> **TL;DR for end users**
>
> 1. Open a terminal.
> 2. Copy-paste the four commands in [Quick start](#quick-start).
> 3. Done. You can log in and use `sudo` with your finger.

---

## Will this work for me?

You need **all three** of these to be true:

- [x] You have a **Samsung Galaxy Book 4** (Pro, Ultra or 360).
- [x] You are running **Fedora** (43, 44 beta confirmed; 42 likely).
- [x] You see the sensor when you run:
      ```bash
      lsusb | grep 2808:6553
      ```
      If a line appears, you're good. If nothing shows up, this fix
      will **not** help you — it is specific to that exact sensor.

---

## Quick start

Open a terminal and run:

```bash
git clone https://github.com/dalsochio/Samsung-Galaxy-Book-4-Fingerprint-Fedora.git
cd Samsung-Galaxy-Book-4-Fingerprint-Fedora
chmod +x install.sh fingerprint-enroll.sh uninstall.sh

# 1) Install the patched driver and enable fingerprint login (asks for password):
sudo ./install.sh

# 2) Register your finger (run as YOUR user, NOT with sudo):
./fingerprint-enroll.sh
```

That's it. After step 2 you can:

- Touch the sensor at the **login screen** instead of typing your password.
- Touch the sensor when you run `sudo` in a terminal.
- Touch the sensor on the **lock screen**.

> **Why two steps under different accounts?**
> Step 1 needs root because it installs system packages.
> Step 2 must run as your normal user because the desktop's
> permission system (polkit) only authorises fingerprint enrollment
> for the user actually sitting at the desk. If you run step 2 with
> `sudo` you'll get a `PermissionDenied` error.

---

## What to expect when registering your finger

When you run `./fingerprint-enroll.sh`, you'll see a menu like this:

```
Fingerprint manager (user: yourname)

  Currently enrolled: (none)

  e) Enroll a new finger
  v) Verify a finger (test)
  d) Delete a finger
  D) Delete ALL fingers
  l) List enrolled fingers
  q) Quit
>
```

Type `e` and press Enter, then pick a finger. Then:

- Place your finger **flat and centered** on the sensor.
- **Lift it completely** between touches.
- Repeat **8 to 15 times**, until you see `enroll-completed`.
- The script will then offer to **test** the finger right away.

If you mess up, just keep going — the sensor only counts good touches.

### What the messages mean

| Message                        | Meaning (in plain words)                |
|--------------------------------|-----------------------------------------|
| `enroll-stage-passed`          | OK, that touch worked. Keep going.      |
| `enroll-finger-not-centered`   | You missed the sensor. Try again.       |
| `enroll-retry-scan`            | Lift your finger and touch again.       |
| `enroll-completed`             | Done! Your finger is registered.        |

You can register **as many fingers as you want**. Just choose `e` again
in the menu, or run `./fingerprint-enroll.sh enroll left-thumb`.

---

## Common problems (read this if something doesn't work)

### `sudo` does not ask for fingerprint

Make sure the feature is on:

```bash
authselect current
```

If the output does not mention `with-fingerprint`, run:

```bash
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
```

### Sensor stops working after suspend

The installer ships a fix for this (a small systemd hook that restarts
`fprintd` on wake-up). If it ever fails:

```bash
sudo systemctl restart fprintd
```

### `failed to claim device: Remote peer disconnected`

`fprintd` crashed. Most often this means an old library is in the way.
Reinstall:

```bash
sudo ./uninstall.sh
sudo ./install.sh
```

### Enrollment keeps saying `enroll-finger-not-centered`

- Use the **pad** of your finger, not the tip.
- Cover the sensor fully.
- Stay still until the message changes.

### Fingerprint stopped working after a system update

That can happen if a `dnf upgrade` overrides the patched driver. Just
re-run:

```bash
sudo ./install.sh
```

---

## Uninstall / Rollback

To undo everything:

```bash
sudo ./uninstall.sh
```

This will **delete every registered fingerprint** and put your system
back to the way it was. The script asks for confirmation; pass `--yes`
to skip the prompt.

---

---

## Technical reference (for advanced users)

The sections below are for power users, packagers and people debugging
the installer.

### Why this exists

Fedora's stock `libfprint` does not yet support the FocalTech
Match-on-Chip sensor that ships with the Galaxy Book 4
(USB ID `2808:6553`). The fix is a patched `libfprint` based on the
unmerged libfprint MR #554 by Sid1803.

This repository is the Fedora counterpart of
[ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu),
which ships Debian `.deb` files with the same patch. Where the
upstream repo distributes a pre-built binary, this one wires up the
equivalent Fedora artefact: the
[`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/)
COPR.

> Why not reuse the Debian `.so`? Because it is dynamically linked
> against `libgusb` symbols tagged `LIBGUSB_0.1.0`, while Fedora's
> `libgusb` exports the same functions tagged `LIBGUSB_0.2.8`.
> Dropping the Debian binary in `/usr/lib64` produces
> `undefined symbol: g_usb_device_get_interfaces` and `fprintd`
> dies. The COPR build is compiled against Fedora's libraries.

### What the installer actually does

1. **Pre-flight** — checks Fedora (`/etc/os-release`) and presence of
   sensor `2808:6553`. Aborts otherwise.
2. **Cleanup** — removes any leftover `.so`/`.h`/`.pc`/`.gir` that
   are not RPM-managed (would shadow the COPR build).
3. **Enable COPR** `hichambel/libfprint-galaxybook`. If the user's
   Fedora has no native chroot, falls back to `fedora-43-x86_64`
   by writing `/etc/yum.repos.d/_copr_hichambel-libfprint-galaxybook.repo`
   manually.
4. **Install** `fprintd`, `fprintd-pam`, `libfprint`, force-replacing
   the stock build with the COPR NVR if needed.
5. **Enable PAM** via `authselect enable-feature with-fingerprint`
   (idempotent; skipped if already enabled, because
   `apply-changes` rewrites `/etc/pam.d/*` and may force-logout the
   active GDM session).
6. **Install systemd unit** `fprintd-resume.service` — restarts
   `fprintd` after `suspend.target`, `hibernate.target`,
   `hybrid-sleep.target`, `suspend-then-hibernate.target`.
7. **Version-lock** `libfprint` via `dnf versionlock` (auto-installs
   `python3-dnf-plugin-versionlock` if missing).
8. **Refresh** `ldconfig`, `udevadm control --reload-rules`,
   `udevadm trigger`, `systemctl restart fprintd`.
9. **Print summary** with installed NVR, service state, lock state.
10. **Tell user** to run `./fingerprint-enroll.sh` as their user.

### Manual installation

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf copr enable -y hichambel/libfprint-galaxybook
sudo dnf install -y fprintd fprintd-pam libfprint
sudo dnf reinstall -y libfprint
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
sudo systemctl restart fprintd
```

If `dnf copr enable` reports no chroot for your Fedora release, write
the repo file by hand pointing at `fedora-43-x86_64` (see `install.sh`).

### Fedora version compatibility

| Fedora        | Status                                                                 |
|---------------|------------------------------------------------------------------------|
| 40 / 41       | Untested. Will use the `fedora-43` fallback. May fail on dependencies. |
| 42            | Untested. Will use the `fedora-43` fallback; expected to work.         |
| 43            | **Native build, fully supported.**                                     |
| 44 (beta)     | **Tested, works via the `fedora-43` fallback.**                        |
| 45+           | Best-effort while the C ABI of glib2 / libgusb / libusb1 stays stable. |

### `fingerprint-enroll.sh` CLI

```bash
./fingerprint-enroll.sh                                  # interactive menu
./fingerprint-enroll.sh list
./fingerprint-enroll.sh enroll right-index-finger
./fingerprint-enroll.sh enroll right-index-finger left-thumb
./fingerprint-enroll.sh verify right-index-finger
./fingerprint-enroll.sh delete left-thumb
./fingerprint-enroll.sh delete-all
```

The script refuses to run as root (polkit denies the operations) and
auto-starts `fprintd.service` if needed.

#### Valid finger names

```
left-thumb         right-thumb
left-index-finger  right-index-finger
left-middle-finger right-middle-finger
left-ring-finger   right-ring-finger
left-little-finger right-little-finger
```

### Version lock

`install.sh` runs `dnf versionlock add libfprint` automatically. Without
it, a routine `sudo dnf upgrade` would eventually pull the stock
Fedora `libfprint` back, overwriting the patched build and silently
breaking the sensor.

You will see this in `dnf upgrade`:

```
Package "libfprint" excluded by versionlock plugin.
```

Unlock with:

```bash
sudo dnf versionlock list
sudo dnf versionlock delete libfprint
```

Re-apply later:

```bash
sudo dnf versionlock add libfprint
```

### Verification commands

```bash
rpm -qf /usr/lib64/libfprint-2.so.2          # should contain "galaxybook"
systemctl status fprintd
ldd /usr/libexec/fprintd | grep fprint
lsusb | grep 2808:6553
fprintd-list "$USER"
```

### What `uninstall.sh` does

In order:

1. Deletes **all** enrolled fingerprints (per user under
   `/var/lib/fprint/`).
2. Disables and removes the `fprintd-resume.service` systemd unit.
3. Removes the `libfprint` version-lock.
4. Disables the PAM `with-fingerprint` feature.
5. Removes any unmanaged files from previous manual installs.
6. Removes the COPR repository (and the manual `.repo` file).
7. Runs `dnf distro-sync libfprint` to bring back the stock build.
8. Refreshes linker, udev, and restarts `fprintd`.

The script asks for confirmation; `--yes` skips the prompt.

### Repository layout

```
.
├── README.md                      # this file (English)
├── README.pt-BR.md                # Portuguese (Brazil) translation
├── README.es.md                   # Spanish translation
├── install.sh                     # install everything
├── uninstall.sh                   # full rollback
├── fingerprint-enroll.sh          # enroll/list/verify/delete helper
└── systemd/
    └── fprintd-resume.service     # restart fprintd after wake-up
```

### SELinux

The COPR RPM ships with proper SELinux labels. If you suspect a
denial:

```bash
sudo ausearch -m AVC -ts recent
```

---

## Credits

- Original Ubuntu / Debian fix:
  [ishashanknigam](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu).
- FocalTech MoC driver: libfprint MR #554 by Sid1803.
- Fedora COPR build:
  [`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/).
- Fedora port (this repo): scripts, systemd hook, multi-finger enroll
  helper, version-lock automation, troubleshooting docs.

---

## Disclaimer

This installer replaces a system library via a third-party COPR and
modifies PAM configuration. Use at your own risk.
