# Samsung Galaxy Book 4 Fingerprint Fix (Fedora)

Enables the fingerprint sensor on Samsung Galaxy Book 4 devices running
**Fedora**. This is the Fedora counterpart of
[ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu)
(which ships Debian `.deb` files). Where that repo distributes a
pre-built `libfprint`, this one wires up the equivalent Fedora
artefact: the
[`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/)
COPR repository, which provides a `libfprint` RPM rebuilt with the
FocalTech Match-on-Chip support (libfprint MR #554, by Sid1803).

---

## Quick start

```bash
git clone https://github.com/dalsochio/Samsung-Galaxy-Book-4-Fingerprint-Fedora.git
cd Samsung-Galaxy-Book-4-Fingerprint-Fedora
chmod +x install.sh fingerprint-enroll.sh uninstall.sh

# 1) Install the patched libfprint and enable PAM (run as root):
sudo ./install.sh

# 2) Enroll your fingerprint (run as your NORMAL user, NOT sudo):
./fingerprint-enroll.sh
```

> The two steps run under different accounts on purpose. The installer
> needs root to change system files. The enrollment must run as your
> normal user so the desktop authentication agent can authorise it —
> running it under `sudo` causes a `PermissionDenied` error from
> polkit.

---

## What the installer does

1. **Pre-flight checks** — confirms you are on Fedora and that the
   FocalTech sensor (`2808:6553`) is plugged in. Aborts with a clear
   message otherwise.
2. **Cleans up** any leftover files from previous manual `.so` drops
   (these would shadow the COPR RPM and cause `undefined symbol` errors).
3. **Enables the COPR**
   `hichambel/libfprint-galaxybook`. If your Fedora release has no
   native build (e.g. Fedora 44 beta), it transparently falls back to
   the `fedora-43-x86_64` build, which is ABI-compatible.
4. **Installs** `fprintd`, `fprintd-pam` and the patched `libfprint`
   from the COPR (force-replacing the stock one if needed).
5. **Turns on fingerprint login** for `sudo`, the login screen and
   the lock screen.

   > ⚠️ **Read this carefully — only matters the first time:**
   > To turn on fingerprint login, the installer must modify some
   > system files. As a side effect, **your desktop may close itself
   > and bring you back to the login screen**, as if you had clicked
   > "Log out". Saved files are safe, but **unsaved work in open
   > apps (browser tabs, editors, terminals) will be lost.**
   >
   > Before answering "yes" to the PAM prompt:
   > - Save your work everywhere.
   > - Close apps whose state you don't want to lose.
   > - You can run the installer from a regular terminal — it will
   >   ask you, then briefly your desktop may restart.
   >
   > After this happens once, the installer skips this step on
   > every later run. You won't be asked again.
6. **Installs a systemd hook** (`fprintd-resume.service`) that
   restarts `fprintd` after every suspend/hibernate. The FocalTech
   driver is known to lose the device after sleep without this.
7. **Version-locks `libfprint`** via `dnf versionlock` so a future
   `dnf upgrade` does not silently replace the patched build with the
   stock one and break the sensor again. **You can unlock it any time
   — see the section below.**
8. **Refreshes** `ldconfig`, `udev`, and restarts `fprintd`.
9. **Tells you what to do next** — namely, run
   `./fingerprint-enroll.sh` as your normal user (without sudo) to
   actually register a finger.

---

## Supported hardware

* Device: Samsung Galaxy Book 4 series (Pro / Ultra / 360)
* Sensor: FocalTech FT9365 ESS (Match-on-Chip)
* USB ID: `2808:6553`

Verify with:

```bash
lsusb | grep 2808:6553
```

If the line is missing the sensor is either disabled in firmware or it
is a different model — this fix will not help.

---

## Fedora version compatibility

| Fedora        | Status                                                                 |
|---------------|------------------------------------------------------------------------|
| 40 / 41       | Untested. Will use the `fedora-43` fallback. May fail on dependencies. |
| 42            | Untested. Will use the `fedora-43` fallback; expected to work.         |
| 43            | **Native build, fully supported.**                                     |
| 44 (beta)     | **Tested, works via the `fedora-43` fallback.**                        |
| 45+           | Best-effort while the C ABI of glib2 / libgusb / libusb1 stays stable. |

When `hichambel/libfprint-galaxybook` publishes a build for your exact
Fedora version, simply re-run `sudo ./install.sh` — the installer
prefers the native chroot whenever it is available.

---

## Manual installation (no scripts)

If you prefer to do it by hand:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf copr enable -y hichambel/libfprint-galaxybook
sudo dnf install -y fprintd fprintd-pam libfprint
sudo dnf reinstall -y libfprint        # force the COPR build
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
sudo systemctl restart fprintd
```

If `dnf copr enable` complains that there is no chroot for your
Fedora version, the script-based installation handles that for you;
doing it manually requires creating a `.repo` file pointing at
`fedora-43-x86_64` (see the install.sh source).

---

## Fingerprint enrollment (terminal-only)

Fedora ships **no graphical interface** for enrolling fingerprints, so
it must be done from the terminal. This repository ships a friendly
helper, `fingerprint-enroll.sh`, that drives `fprintd-*` for you.

### Run it

```bash
./fingerprint-enroll.sh
```

Without arguments it shows an interactive menu:

```
Fingerprint manager (user: yourname)

  Currently enrolled:
    ● right-index-finger

  e) Enroll a new finger
  v) Verify a finger (test)
  d) Delete a finger
  D) Delete ALL fingers
  l) List enrolled fingers
  q) Quit
```

It also accepts subcommands for scripting:

```bash
./fingerprint-enroll.sh list
./fingerprint-enroll.sh enroll right-index-finger
./fingerprint-enroll.sh enroll right-index-finger left-thumb     # multiple
./fingerprint-enroll.sh verify right-index-finger
./fingerprint-enroll.sh delete left-thumb
./fingerprint-enroll.sh delete-all
```

### What to expect during enrollment

* You will see prompts in the terminal — there is no popup window.
* Place your finger **flat and centered** on the sensor.
* **Lift your finger completely** between touches.
* Expect 8 to 15 touches until you see `enroll-completed`.

Status messages explained:

| Message                        | Meaning                              |
|--------------------------------|--------------------------------------|
| `enroll-stage-passed`          | Touch was good, keep going.          |
| `enroll-finger-not-centered`   | Reposition the finger and try again. |
| `enroll-retry-scan`            | Lift and touch again.                |
| `enroll-completed`             | Done. Finger is registered.          |

After enrollment the helper offers to verify the finger immediately
(`fprintd-verify`) so you know it really works.

### Valid finger names

```
left-thumb         right-thumb
left-index-finger  right-index-finger
left-middle-finger right-middle-finger
left-ring-finger   right-ring-finger
left-little-finger right-little-finger
```

---

## Using the fingerprint

Once a finger is enrolled, it is automatically available for:

* **`sudo`** — try `sudo -k && sudo ls` and you should be asked to
  touch the sensor before / instead of typing your password.
* **GDM login screen** — touch the sensor at the login prompt.
* **Lock screen** — same.

If `sudo` still asks only for a password, check that authselect knows
about the feature:

```bash
authselect current
```

The output should mention `with-fingerprint`. If it does not:

```bash
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
```

---

## Suspend & resume

The FocalTech MoC driver tends to lose the device after the laptop
suspends. To work around this the installer ships a systemd unit at
`/etc/systemd/system/fprintd-resume.service` that restarts `fprintd`
on every wake-up. It is enabled automatically and you do not have to
touch it.

If you ever want to inspect or disable it:

```bash
systemctl status fprintd-resume.service
sudo systemctl disable fprintd-resume.service
```

---

## Version lock (important)

`install.sh` automatically version-locks the `libfprint` package using
`dnf versionlock`. Without this, a routine `sudo dnf upgrade` would
eventually pull the stock Fedora `libfprint` back, overwriting the
patched build and silently breaking the sensor.

**You will see this in `dnf upgrade`:**

```
Package "libfprint" excluded by versionlock plugin.
```

That is expected — it is the lock doing its job.

### How to unlock (e.g. when the COPR has a build for your Fedora)

```bash
sudo dnf versionlock list                  # see what's locked
sudo dnf versionlock delete libfprint      # unlock
```

After unlocking, you are free to upgrade. To re-apply the lock later:

```bash
sudo dnf versionlock add libfprint
```

---

## Verification

After installation, sanity-check with:

```bash
# The library should belong to the COPR RPM (release contains "galaxybook"):
rpm -qf /usr/lib64/libfprint-2.so.2

# fprintd should be running and should resolve the patched library:
systemctl status fprintd
ldd /usr/libexec/fprintd | grep fprint

# The device must be visible:
lsusb | grep 2808:6553

# Enrolled fingers (per user):
fprintd-list "$USER"
```

---

## Troubleshooting

### `failed to claim device: Remote peer disconnected`

`fprintd` is crashing. Look at the log:

```bash
journalctl -u fprintd -n 50 --no-pager
```

If you see `undefined symbol: g_usb_device_get_interfaces`, an old
manually-installed `.so` is shadowing the RPM. Run:

```bash
sudo ./uninstall.sh
sudo ./install.sh
```

### Sensor not detected (`lsusb | grep 2808:6553` empty)

This is a hardware/firmware issue, not a `libfprint` issue. Check
BIOS settings, kernel version, and that no Windows fast-boot left the
USB device powered down.

### Enrollment keeps saying `enroll-finger-not-centered`

* Use the **pad** of your finger, not the tip.
* Cover the sensor fully and stay still until the message changes.
* Cancel with `Ctrl+C` and start over if it gets stuck for more than
  a minute.

### `sudo` does not ask for fingerprint

Check that PAM knows about the feature:

```bash
authselect current
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
```

### After suspend the sensor stops working

The resume hook normally fixes this. If it does not:

```bash
sudo systemctl restart fprintd
```

If that consistently fails to recover, you can disable the laptop's
USB autosuspend for the sensor (see the `udev` section of the Arch
wiki on `fprint`).

### SELinux denials

If you suspect SELinux is blocking something:

```bash
sudo ausearch -m AVC -ts recent
```

The COPR RPM ships with proper SELinux labels, so this should not
happen, but it is the first thing to check.

---

## Uninstall / Rollback

```bash
sudo ./uninstall.sh
```

This fully reverses `install.sh`. It will:

1. Delete **all** enrolled fingerprints from every user.
2. Disable and remove the `fprintd-resume.service` systemd unit.
3. Remove the `libfprint` version-lock.
4. Disable the PAM `with-fingerprint` feature.
5. Remove any unmanaged files from previous manual installs.
6. Remove the `hichambel/libfprint-galaxybook` COPR repository.
7. `dnf distro-sync libfprint` to bring back the stock Fedora build.
8. Refresh the linker cache, udev rules, and restart `fprintd`.

The script will ask for confirmation before doing anything; pass
`--yes` to skip the prompt.

---

## Repository layout

```
.
├── README.md                      # this file
├── install.sh                     # install everything
├── uninstall.sh                   # full rollback
├── fingerprint-enroll.sh          # enroll/list/verify/delete helper
└── systemd/
    └── fprintd-resume.service     # restart fprintd after wake-up
```

---

## Credits

* Original Ubuntu / Debian fix:
  [ishashanknigam](https://github.com/ishashanknigam/Samsung-Galaxy-Book-4-Fingerprint-Ubuntu).
* FocalTech MoC driver: libfprint MR #554 by Sid1803.
* Fedora COPR build:
  [`hichambel/libfprint-galaxybook`](https://copr.fedorainfracloud.org/coprs/hichambel/libfprint-galaxybook/).
* Fedora port (this repo): scripts, systemd hook, multi-finger enroll
  helper, version-lock automation, troubleshooting docs.

---

## Disclaimer

This installer replaces a system library via a third-party COPR and
modifies PAM configuration. Use at your own risk.
