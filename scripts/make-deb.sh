#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Turn the output of `./mach package` into a Devuan .deb.
#
#   usage: scripts/make-deb.sh <firefox-src-dir> <firefox-version> <out-dir>
#
# Installs to /usr/lib/ironwood with a launcher in /usr/bin, a .desktop
# file, icons, the Ironwood default prefs and the enterprise policies
# (both editable in /etc/ironwood and kept across upgrades).
# No systemd or init-system hooks are involved.
#
# Environment:
#   DEB_REVISION  Debian revision; defaults to the GitHub run number, so
#                 a rebuild of the same Firefox version is an upgrade.
#   PGO_STAGE     "use" when the build used a PGO profile (description only).
# ---------------------------------------------------------------------
set -euo pipefail

SRC="$(cd "${1:?firefox source dir}" && pwd)"
FFVER="${2:?firefox version}"
OUT="$(mkdir -p "${3:?output dir}" && cd "$3" && pwd)"
APP_NAME="${APP_NAME:-ironwood}"
APP_DISPLAY="${APP_DISPLAY:-Ironwood}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

[[ "${FFVER}" =~ ^[0-9]+(\.[0-9]+)+(esr|b[0-9]+)?$ ]] \
  || { echo "Not a Firefox version: '${FFVER}'"; exit 1; }
DEBREV="${DEB_REVISION:-${GITHUB_RUN_NUMBER:-1}}"
[[ "${DEBREV}" =~ ^[0-9a-z.+~]+$ ]] || { echo "Invalid Debian revision: '${DEBREV}'"; exit 1; }

# Debian version: 140.5.0esr -> 140.5.0~esr-<rev>, 146.0b5 -> 146.0~b5-<rev>
# ("~" sorts before the plain release in dpkg).
DEBVER="$(sed -E 's/(esr|b[0-9]+)$/~\1/' <<<"${FFVER}")-${DEBREV}"

# Pick the package tarball with a glob (not "ls | head": under pipefail a
# failing ls would end the script before the message below).
shopt -s nullglob
PKG_TARBALL=""
for f in "${SRC}"/obj-release/dist/"${APP_NAME}"-*.tar "${SRC}"/obj-release/dist/"${APP_NAME}"-*.tar.*; do
  case "$f" in *tests*|*.asc|*.sig) continue ;; esac
  PKG_TARBALL="$f"; break
done
shopt -u nullglob
[ -n "${PKG_TARBALL}" ] || { echo "No package tarball in obj-release/dist (did ./mach package run?)"; exit 1; }
echo ">> Packaging ${PKG_TARBALL}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
ROOT="${TMP}/${APP_NAME}_${DEBVER}_amd64"
LIBDIR="${ROOT}/usr/lib/${APP_NAME}"
ETCDIR="${ROOT}/etc/${APP_NAME}"
mkdir -p "${LIBDIR}" "${ROOT}/usr/bin" "${ROOT}/DEBIAN" \
         "${ROOT}/usr/share/applications" "${ETCDIR}"

tar -xf "${PKG_TARBALL}" -C "${LIBDIR}" --strip-components=1
[ -x "${LIBDIR}/${APP_NAME}" ] || { echo "No ${APP_NAME} binary in the package tarball"; exit 1; }

# Launcher
ln -s "/usr/lib/${APP_NAME}/${APP_NAME}" "${ROOT}/usr/bin/${APP_NAME}"

# Default prefs: Debian-style, editable in /etc
cp "${REPO}/prefs/device-prefs.js" "${ETCDIR}/${APP_NAME}-prefs.js"
mkdir -p "${LIBDIR}/defaults/pref"
ln -s "/etc/${APP_NAME}/${APP_NAME}-prefs.js" "${LIBDIR}/defaults/pref/${APP_NAME}-prefs.js"
# Files in defaults/pref only understand pref(), not user_pref().
if grep -qE '^[[:space:]]*user_pref\(' "${ETCDIR}/${APP_NAME}-prefs.js"; then
  echo "::warning::prefs/device-prefs.js uses user_pref(); only pref() lines take effect from defaults/pref"
fi

# Enterprise policies: also in /etc, so local edits survive upgrades
python3 -m json.tool "${REPO}/prefs/policies.json" >/dev/null \
  || { echo "prefs/policies.json is not valid JSON"; exit 1; }
cp "${REPO}/prefs/policies.json" "${ETCDIR}/policies.json"
mkdir -p "${LIBDIR}/distribution"
ln -s "/etc/${APP_NAME}/policies.json" "${LIBDIR}/distribution/policies.json"

# Build record written by prepare-source.sh
if [ -f "${SRC}/ironwood-build-info.txt" ]; then
  cp "${SRC}/ironwood-build-info.txt" "${LIBDIR}/${APP_NAME}-build-info.txt"
  echo "Package version: ${DEBVER}" >> "${LIBDIR}/${APP_NAME}-build-info.txt"
fi

# Icons
for s in 16 32 48 64 128; do
  icon="${LIBDIR}/browser/chrome/icons/default/default${s}.png"
  if [ -f "${icon}" ]; then
    d="${ROOT}/usr/share/icons/hicolor/${s}x${s}/apps"
    mkdir -p "$d" && cp "${icon}" "$d/${APP_NAME}.png"
  fi
done

# Desktop entry (MATE menu)
DESKTOP="${ROOT}/usr/share/applications/${APP_NAME}.desktop"
cat > "${DESKTOP}" <<EOF
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
if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "${DESKTOP}" || echo "::warning::desktop-file-validate reported problems in ${APP_NAME}.desktop"
fi

chmod -R u+rwX,go+rX,go-w "${ROOT}"
SIZE_KB="$(du -sk "${ROOT}" | cut -f1)"

if [ "${PGO_STAGE:-none}" = use ]; then OPTIMIZED="PGO and cross-language LTO"; else OPTIMIZED="cross-language LTO"; fi

# Devuan 6 (excalibur) is based on Debian trixie, where many libraries
# got a "t64" suffix; the alternatives keep older names working too.
# No libc6 version is listed: the build uses Mozilla's sysroot, which
# targets a much older glibc than any supported Devuan release has.
# libegl1 / libgl1 are loaded at run time for hardware WebRender.
cat > "${ROOT}/DEBIAN/control" <<EOF
Package: ${APP_NAME}
Version: ${DEBVER}
Architecture: amd64
Maintainer: Ironwood builder <noreply@localhost>
Installed-Size: ${SIZE_KB}
Section: web
Priority: optional
Depends: libgtk-3-0t64 | libgtk-3-0, libasound2t64 | libasound2, libdbus-1-3, libx11-xcb1, libxtst6, libxrandr2, libpci3, fontconfig
Recommends: libavcodec61 | libavcodec60 | libavcodec-extra, libegl1, libgl1, intel-media-va-driver-non-free | intel-media-va-driver | i965-va-driver, libva2
Suggests: libpulse0
Provides: www-browser, gnome-www-browser
Description: Ironwood web browser
 Gecko-based browser built from Firefox ${FFVER} source, tuned for an
 Intel Core i5-7300U with HD Graphics 620 on Devuan with MATE (X11).
 Built with ${OPTIMIZED}, ALSA audio, VA-API video
 decoding enabled, and telemetry upload, the crash reporter and the
 built-in updater left out.
EOF

cat > "${ROOT}/DEBIAN/conffiles" <<EOF
/etc/${APP_NAME}/${APP_NAME}-prefs.js
/etc/${APP_NAME}/policies.json
EOF

# Register as an alternative for x-www-browser. The icon cache and the
# desktop database are refreshed by dpkg triggers; nothing to do here.
cat > "${ROOT}/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e
if [ "\$1" = "configure" ]; then
  update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/${APP_NAME} 60
  update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/${APP_NAME} 60
fi
exit 0
EOF
cat > "${ROOT}/DEBIAN/prerm" <<EOF
#!/bin/sh
set -e
if [ "\$1" = "remove" ] || [ "\$1" = "deconfigure" ]; then
  update-alternatives --remove x-www-browser /usr/bin/${APP_NAME}
  update-alternatives --remove gnome-www-browser /usr/bin/${APP_NAME}
fi
exit 0
EOF
chmod 0755 "${ROOT}/DEBIAN/postinst" "${ROOT}/DEBIAN/prerm"

DEB="${OUT}/${APP_NAME}_${DEBVER}_amd64.deb"
dpkg-deb --root-owner-group -Zxz --build "${ROOT}" "${DEB}"

echo ">> Package"
dpkg-deb --info "${DEB}"
echo ">> $(dpkg-deb --contents "${DEB}" | wc -l) entries"
(cd "${OUT}" && sha256sum -- *.deb > SHA256SUMS && cat SHA256SUMS)
ls -lh "${OUT}"
