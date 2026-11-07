#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Turn the output of `./mach package` into a Devuan .deb.
#
#   usage: scripts/make-deb.sh <firefox-src-dir> <firefox-version> <out-dir>
#
# Installs to /usr/lib/ironwood with a launcher in /usr/bin, a .desktop
# file, icons, the Ironwood default prefs and the enterprise policies.
# No systemd or init-system hooks are involved.
# ---------------------------------------------------------------------
set -euo pipefail

SRC="$(cd "${1:?firefox source dir}" && pwd)"
FFVER="${2:?firefox version}"
OUT="$(mkdir -p "${3:?output dir}" && cd "$3" && pwd)"
APP_NAME="${APP_NAME:-ironwood}"
APP_DISPLAY="${APP_DISPLAY:-Ironwood}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

# Debian version: 140.5.0esr -> 140.5.0~esr-1 (sorts correctly in dpkg)
DEBVER="$(echo "${FFVER}" | sed -E 's/esr$/~esr/')-1"

PKG_TARBALL="$(ls "${SRC}"/obj-release/dist/"${APP_NAME}"-*.tar.* 2>/dev/null | head -n1)"
[ -n "${PKG_TARBALL}" ] || { echo "No package tarball in obj-release/dist (did ./mach package run?)"; exit 1; }
echo ">> Packaging ${PKG_TARBALL}"

ROOT="$(mktemp -d)/${APP_NAME}_${DEBVER}_amd64"
LIBDIR="${ROOT}/usr/lib/${APP_NAME}"
mkdir -p "${LIBDIR}" "${ROOT}/usr/bin" "${ROOT}/DEBIAN" \
         "${ROOT}/usr/share/applications" "${ROOT}/etc/${APP_NAME}"

tar -xf "${PKG_TARBALL}" -C "${LIBDIR}" --strip-components=1

# Launcher
ln -s "/usr/lib/${APP_NAME}/${APP_NAME}" "${ROOT}/usr/bin/${APP_NAME}"

# Default prefs: Debian-style, editable in /etc
cp "${REPO}/prefs/device-prefs.js" "${ROOT}/etc/${APP_NAME}/${APP_NAME}-prefs.js"
mkdir -p "${LIBDIR}/defaults/pref"
ln -s "/etc/${APP_NAME}/${APP_NAME}-prefs.js" "${LIBDIR}/defaults/pref/${APP_NAME}-prefs.js"

# Enterprise policies
mkdir -p "${LIBDIR}/distribution"
cp "${REPO}/prefs/policies.json" "${LIBDIR}/distribution/policies.json"

# Icons
for s in 16 32 48 64 128; do
  icon="${LIBDIR}/browser/chrome/icons/default/default${s}.png"
  if [ -f "${icon}" ]; then
    d="${ROOT}/usr/share/icons/hicolor/${s}x${s}/apps"
    mkdir -p "$d" && cp "${icon}" "$d/${APP_NAME}.png"
  fi
done

# Desktop entry (MATE menu)
cat > "${ROOT}/usr/share/applications/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_DISPLAY}
GenericName=Web Browser
Comment=Browse the Web
Exec=/usr/bin/${APP_NAME} %u
Icon=${APP_NAME}
Terminal=false
StartupNotify=true
StartupWMClass=${APP_NAME}
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=/usr/bin/${APP_NAME} --new-window

[Desktop Action new-private-window]
Name=New Private Window
Exec=/usr/bin/${APP_NAME} --private-window
EOF

SIZE_KB="$(du -sk "${ROOT}" | cut -f1)"

# Devuan 6 (excalibur) is based on Debian trixie, where many libraries
# got a "t64" suffix; the alternatives keep older names working too.
cat > "${ROOT}/DEBIAN/control" <<EOF
Package: ${APP_NAME}
Version: ${DEBVER}
Architecture: amd64
Maintainer: Ironwood builder <noreply@localhost>
Installed-Size: ${SIZE_KB}
Section: web
Priority: optional
Depends: libgtk-3-0t64 | libgtk-3-0, libasound2t64 | libasound2, libdbus-1-3, libx11-xcb1, libxtst6, libxrandr2, libpci3, fontconfig
Recommends: libavcodec61 | libavcodec60 | libavcodec-extra, intel-media-va-driver-non-free | intel-media-va-driver, libva2
Suggests: libpulse0
Provides: www-browser, gnome-www-browser
Description: Ironwood web browser
 Gecko-based browser built from Firefox ${FFVER} source, tuned for an
 Intel Core i5-7300U with HD Graphics 620 on Devuan with MATE (X11).
 Built with PGO and cross-language LTO, ALSA audio, VA-API video
 decoding enabled, and telemetry removed.
EOF

cat > "${ROOT}/DEBIAN/conffiles" <<EOF
/etc/${APP_NAME}/${APP_NAME}-prefs.js
EOF

# Register as an alternative for x-www-browser
cat > "${ROOT}/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
if [ "\$1" = "configure" ]; then
  update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/${APP_NAME} 60
  update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/${APP_NAME} 60
fi
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
command -v update-desktop-database >/dev/null && update-desktop-database -q || true
exit 0
EOF
cat > "${ROOT}/DEBIAN/prerm" <<EOF
#!/bin/sh
set -e
if [ "\$1" = "remove" ]; then
  update-alternatives --remove x-www-browser /usr/bin/${APP_NAME}
  update-alternatives --remove gnome-www-browser /usr/bin/${APP_NAME}
fi
exit 0
EOF
chmod 0755 "${ROOT}/DEBIAN/postinst" "${ROOT}/DEBIAN/prerm"

dpkg-deb --root-owner-group -Zxz --build "${ROOT}" "${OUT}/"
ls -lh "${OUT}"
