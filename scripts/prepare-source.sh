#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Download, verify and prepare a Firefox source tree for Ironwood.
#
#   usage: scripts/prepare-source.sh <firefox-version> <dest-dir>
#   e.g.   scripts/prepare-source.sh 140.5.0esr src
#
# Steps: fetch the official source tarball from archive.mozilla.org,
# check it against Mozilla's SHA512SUMS, unpack it, apply patches/*.patch,
# create the Ironwood branding and drop in the mozconfig.
# ---------------------------------------------------------------------
set -euo pipefail

VERSION="${1:?firefox version, e.g. 140.5.0esr}"
DEST="${2:?destination directory}"
APP_NAME="${APP_NAME:-ironwood}"
APP_DISPLAY="${APP_DISPLAY:-Ironwood}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

BASE="https://archive.mozilla.org/pub/firefox/releases/${VERSION}"
TARBALL="firefox-${VERSION}.source.tar.xz"
WORK="$(mktemp -d)"

echo ">> Downloading Firefox ${VERSION} source"
curl -fL --retry 5 -o "${WORK}/${TARBALL}" "${BASE}/source/${TARBALL}"
curl -fL --retry 5 -o "${WORK}/SHA512SUMS"  "${BASE}/SHA512SUMS"

echo ">> Verifying checksum"
EXPECTED="$(awk -v f="source/${TARBALL}" '$2==f {print $1}' "${WORK}/SHA512SUMS")"
[ -n "${EXPECTED}" ] || { echo "No checksum listed for ${TARBALL}"; exit 1; }
echo "${EXPECTED}  ${WORK}/${TARBALL}" | sha512sum -c -

echo ">> Unpacking"
mkdir -p "${DEST}"
tar -xJf "${WORK}/${TARBALL}" -C "${DEST}" --strip-components=1
rm -rf "${WORK}"
cd "${DEST}"

# ---- Your patches (applied in name order) ----------------------------
shopt -s nullglob
for p in "${REPO}"/patches/*.patch; do
  echo ">> Applying $(basename "$p")"
  patch -p1 --forward --no-backup-if-mismatch < "$p"
done
shopt -u nullglob

# ---- Branding: copy Mozilla's neutral "unofficial" branding ----------
# It has no Firefox trademarks; we only rename it.
echo ">> Creating ${APP_DISPLAY} branding"
B="browser/branding/${APP_NAME}"
rm -rf "${B}"
cp -r browser/branding/unofficial "${B}"

# Rename the user-visible brand strings (unofficial uses "Nightly").
# Only the locale files: moz.build calls build functions such as
# FirefoxBranding(), which must keep their names.
grep -rlE 'Nightly|Firefox' "${B}" --include='*.ftl' --include='*.properties' 2>/dev/null \
  | while read -r f; do
      sed -i -E "s/Mozilla Firefox|Firefox Nightly|Nightly|Firefox/${APP_DISPLAY}/g" "$f"
    done

# configure.sh controls the display / remoting names.
cat > "${B}/configure.sh" <<EOF
MOZ_APP_DISPLAYNAME="${APP_DISPLAY}"
MOZ_APP_REMOTINGNAME="${APP_NAME}"
MOZ_MACBUNDLE_ID="${APP_NAME}"
EOF

# ---- mozconfig --------------------------------------------------------
cp "${REPO}/mozconfig" ./mozconfig
echo ">> Source ready in $(pwd)"
