# Samsung Galaxy Book 4 Fingerprint Fix (Fedora)

**Languages:** **English** · [Português (Brasil)](README.pt-BR.md) · [Español](README.es.md)

Makes the fingerprint reader of the **Samsung Galaxy Book 4** work on **Fedora**
(login screen, lock screen and `sudo`).

> **TL;DR for end users**
>
> 1. Open a terminal.
> 2. Paste the four commands from [Quick start](#quick-start).
> 3. Done. You can log in and use `sudo` with your finger.

---

## What it looks like

After installing, run `./fingerprint-enroll.sh` to manage your fingerprints.
The tool shows a live view of your hands — enrolled fingers appear as `●`,
unenrolled ones show their number so you can pick one to register:

```
Fingerprint manager (user: yourname)

     Left hand                       Right hand

          _.-._                          _.-._
        _|1|2|3|\                       /|●|7|8|_
       |0| | | ||                       || | | |9|
       | | | | ||                       || | | | |
       | `     ||_                     _||     ` |
       ;       /4//                   \\●\       ;
       |        //                     \\        |
        \      //                       \\      /
         |    | |                       | |    |
         |    | |                       | |    |

  e) Enroll a new finger
  v) Verify a finger (test)
  d) Delete a finger
  D) Delete ALL fingers
  l) List enrolled fingers
  q) Quit

>
```

> In a real terminal the `●` dots are highlighted in green and unenrolled
> digits appear dimmed. The same drawing is shown every time you enroll,
> verify or delete a finger.

---

## Will this work for me?

You need **all three** of these to be true:

- [x] You have a **Samsung Galaxy Book 4** (Pro, Ultra or 360).
- [x] You are running **Fedora** (43 and 44 beta confirmed; 42 likely works).
- [x] You see the sensor when you run:
      ```bash
      lsusb | grep 2808:6553
      ```
      If a line appears, you're good. If nothing shows up, this fix
      **will not** work for you — it is specific to that exact sensor.

---

## Quick start

Open a terminal and run:

```bash
git clone https://github.com/dalsochio/Samsung-Galaxy-Book-4-Fingerprint-Fedora.git
cd Samsung-Galaxy-Book-4-Fingerprint-Fedora
chmod +x install.sh fingerprint-enroll.sh uninstall.sh

# 1) Install the patched driver and enable fingerprint login (asks for your password):
sudo ./install.sh

# 2) Register your finger (run as YOUR user, NOT with sudo):
./fingerprint-enroll.sh
```

That's it. After step 2 you can:

- Touch the sensor at the **login screen** instead of typing your password.
- Touch the sensor when you run `sudo` in a terminal.
- Touch the sensor on the **lock screen**.

> **Why two steps under different accounts?**
> Step 1 needs root to install system packages.
> Step 2 must run as your normal user because the desktop permission system
> (polkit) only authorises fingerprint enrollment for the user actually sitting
> at the desk. Running step 2 with `sudo` will give you a `PermissionDenied` error.

---

## What to expect when registering your finger

When you run `./fingerprint-enroll.sh`, choose `e` in the menu, then pick a finger. Then:

- Place your finger **flat and centered** on the sensor.
- **Lift it completely** between touches.
- Repeat **8 to 15 times** until you see `enroll-completed`.
- The script will offer to **test** the finger right away.

If you mess up, just keep going — the sensor only counts good touches.

### What the messages mean

| Message                        | Meaning                                      |
|--------------------------------|----------------------------------------------|
| `enroll-stage-passed`          | OK, that touch worked. Keep going.           |
| `enroll-finger-not-centered`   | You missed the sensor. Try again.            |
| `enroll-retry-scan`            | Lift your finger and touch again.            |
| `enroll-completed`             | Done! Your finger is registered.             |

You can register **as many fingers as you want**. Just choose `e` again in the menu,
or run `./fingerprint-enroll.sh enroll left-thumb`.

---

## Common problems

### `sudo` does not ask for fingerprint

Check that the feature is on:

```bash
authselect current
```

If the output does not mention `with-fingerprint`, run:

```bash
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
```

### Sensor stops working after suspend

The installer already includes a fix for this (a small systemd service that
restarts `fprintd` on wake-up). If it ever fails:

```bash
sudo systemctl restart fprintd
```

### `failed to claim device: Remote peer disconnected`

`fprintd` crashed. Most often it means an old library is in the way.
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

That can happen if `dnf upgrade` overwrites the patched driver. Just re-run:

```bash
sudo ./install.sh
```

---

## Uninstall / Rollback

To undo everything:

```bash
sudo ./uninstall.sh
```

This will **delete every registered fingerprint** and put your system back to
the way it was. The script asks for confirmation; pass `--yes` to skip the prompt.

---

---

## Technical reference (for advanced users)

### Why this exists

Fedora's stock `libfprint` does not yet support the FocalTech Match-on-Chip sensor
that ships with the Galaxy Book 4 (USB ID `2808:6553`). The fix is a patched
`libfprint` based on libfprint MR #554 by Sid1803, not yet merged upstream.

This repository is the Fedora counterpart of
[ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu),
which ships Debian `.deb` files with the same patch. The installer uses the
[`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/)
COPR, compiled against Fedora's libraries.

> Why not reuse the Debian `.so`? Because it is dynamically linked against
> `libgusb` symbols tagged `LIBGUSB_0.1.0`, while Fedora's `libgusb` exports
> the same functions tagged `LIBGUSB_0.2.8`. Copying the Debian binary to
> `/usr/lib64` produces `undefined symbol: g_usb_device_get_interfaces` and
> `fprintd` dies.

### Fedora version compatibility

| Fedora        | Status                                                                      |
|---------------|-----------------------------------------------------------------------------|
| 40 / 41       | Untested. Will use the `fedora-43` fallback. May fail on dependencies.      |
| 42            | Untested. Will use the `fedora-43` fallback; expected to work.              |
| 43            | **Native build, fully supported.**                                          |
| 44 (beta)     | **Tested, works via the `fedora-43` fallback.**                             |
| 45+           | Best-effort while the C ABI of glib2 / libgusb / libusb1 stays stable.     |

### Version lock

`install.sh` locks the `libfprint` version with `dnf versionlock` automatically.
Without it, a routine `sudo dnf upgrade` would eventually pull the stock Fedora
`libfprint` back, overwriting the patched build and silently breaking the sensor.

You will see this in `dnf upgrade`:

```
Package "libfprint" excluded by versionlock plugin.
```

That is expected — it is the lock doing its job.

To unlock (e.g. when the COPR publishes a build for your Fedora version):

```bash
sudo dnf versionlock list                  # see what's locked
sudo dnf versionlock delete libfprint      # unlock
```

To re-apply later:

```bash
sudo dnf versionlock add libfprint
```

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

### Verification commands

```bash
rpm -qf /usr/lib64/libfprint-2.so.2   # should contain "galaxybook"
systemctl status fprintd
ldd /usr/libexec/fprintd | grep fprint
lsusb | grep 2808:6553
fprintd-list "$USER"
```

### SELinux

The COPR RPM ships with proper SELinux labels. If you suspect a denial:

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
- Fedora port (this repo): scripts, systemd hook, multi-finger enroll helper,
  version-lock automation, documentation — built with the help of **Claude Opus 4.7**.
- ASCII hand drawing adapted from
  [Joan G. Stark (Spunk)](https://www.asciiart.eu/art/f8977d5ed396941a).

---

## Disclaimer

This installer replaces a system library via a third-party COPR and modifies
PAM configuration. Use at your own risk.
