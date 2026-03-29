#!/usr/bin/env bash
set -e

echo "[1/6] Installing dependencies..."
sudo apt update
sudo apt install -y fprintd libpam-fprintd

echo "[2/6] Installing patched libfprint..."
sudo dpkg -i libfprint-2-2_*.deb libfprint-dev_*.deb || sudo apt -f install -y

echo "[3/6] Fixing library path..."
sudo ldconfig

echo "[4/6] Adding permission rule..."
sudo tee /etc/polkit-1/rules.d/50-fprintd.rules > /dev/null <<EOF
polkit.addRule(function(action, subject) {
  if ((action.id == "net.reactivated.fprint.device.enroll" ||
       action.id == "net.reactivated.fprint.device.verify") &&
      subject.isInGroup("sudo")) {
    return polkit.Result.YES;
  }
});
EOF

echo "[5/6] Restarting service..."
sudo systemctl restart fprintd

echo "[6/6] Verifying setup..."
ldd /usr/libexec/fprintd | grep fprint || echo "WARNING: libfprint not loaded correctly"

echo "--------------------------------"
echo "Setup complete!"
echo "Next:"
echo "  fprintd-enroll"
echo "  fprintd-verify"
