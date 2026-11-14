#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Download, verify and prepare a Firefox source tree for Ironwood.
#
#   usage: scripts/prepare-source.sh <firefox-version> <dest-dir>
#   e.g.   scripts/prepare-source.sh 140.5.0esr src
#
# Steps: fetch the official source tarball from archive.mozilla.org,
# check it against Mozilla's SHA512SUMS, unpack it, apply patches/*.patch,
# create the Ironwood branding, drop in the mozconfig and record what
# was used in ironwood-build-info.txt (shipped in the .deb).
# ---------------------------------------------------------------------
set -euo pipefail

VERSION="${1:?firefox version, e.g. 140.5.0esr}"
DEST="${2:?destination directory}"
APP_NAME="${APP_NAME:-ironwood}"
APP_DISPLAY="${APP_DISPLAY:-Ironwood}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

# The version goes into a URL here and into the Debian version later.
[[ "${VERSION}" =~ ^[0-9]+(\.[0-9]+)+(esr|b[0-9]+)?$ ]] \
  || { echo "Not a Firefox version: '${VERSION}' (expected e.g. 140.5.0esr, 145.0.1, 146.0b5)"; exit 1; }

# Unpacking over an old tree would leave stale and already-patched files.
if [ -d "${DEST}" ] && [ -n "$(ls -A "${DEST}")" ]; then
  echo "Destination '${DEST}' is not empty; remove it first."; exit 1
fi

BASE="https://archive.mozilla.org/pub/firefox/releases/${VERSION}"
TARBALL="firefox-${VERSION}.source.tar.xz"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

echo ">> Downloading Firefox ${VERSION} source"
curl -fL --retry 5 --retry-all-errors -o "${WORK}/${TARBALL}" "${BASE}/source/${TARBALL}"
curl -fL --retry 5 --retry-all-errors -o "${WORK}/SHA512SUMS"  "${BASE}/SHA512SUMS"

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
# A hunk that fails stops the build. A hunk that only applies with fuzz
# still goes in, but is reported: it means the patch is drifting away
# from this Firefox version and should be refreshed.
APPLIED=()
shopt -s nullglob
for p in "${REPO}"/patches/*.patch; do
  name="$(basename "$p")"
  echo ">> Applying ${name}"
  log="$(mktemp)"
  patch -p1 --forward --no-backup-if-mismatch < "$p" | tee "${log}"
  if grep -qi 'fuzz' "${log}"; then
    echo "::warning::${name} applied with fuzz on Firefox ${VERSION}; refresh the patch"
  fi
  rm -f "${log}"
  APPLIED+=("${name}")
done
shopt -u nullglob

# ---- Branding: copy Mozilla's neutral "unofficial" branding ----------
# It has no Firefox trademarks; we only rename it.
echo ">> Creating ${APP_DISPLAY} branding"
B="browser/branding/${APP_NAME}"
[ -d browser/branding/unofficial ] || { echo "browser/branding/unofficial not found in this Firefox version"; exit 1; }
rm -rf "${B}"
cp -r browser/branding/unofficial "${B}"

# Rename the user-visible brand strings (unofficial uses "Nightly").
# Only the locale files: moz.build calls build functions such as
# FirefoxBranding(), which must keep their names.
# (find + sed rather than "grep -l | while read": with pipefail, a grep
# that matches nothing would end this script without any message.)
find "${B}" -type f \( -name '*.ftl' -o -name '*.properties' \) -exec \
  sed -i -E \
    -e "s/Mozilla Firefox|Firefox Nightly|Nightly|Firefox/${APP_DISPLAY}/g" \
    -e "s/^(-vendor-short-name[[:space:]]*=[[:space:]]*).*/\1${APP_DISPLAY}/" \
    -e "s/^(vendorShortName[[:space:]]*=[[:space:]]*).*/\1${APP_DISPLAY}/" \
    {} +
if ! grep -rqF "${APP_DISPLAY}" "${B}" --include='*.ftl' --include='*.properties'; then
  echo "Branding rename changed nothing: the layout of browser/branding/unofficial has changed; review this script"
  exit 1
fi

# configure.sh controls the display / remoting names.
cat > "${B}/configure.sh" <<EOF
MOZ_APP_DISPLAYNAME="${APP_DISPLAY}"
MOZ_APP_REMOTINGNAME="${APP_NAME}"
MOZ_MACBUNDLE_ID="${APP_NAME}"
EOF

# ---- mozconfig --------------------------------------------------------
cp "${REPO}/mozconfig" ./mozconfig

# ---- Build record (make-deb.sh installs it next to the browser) -------
{
  echo "Firefox source: ${VERSION}"
  echo "Tarball: ${BASE}/source/${TARBALL}"
  echo "Tarball SHA512: ${EXPECTED}"
  echo "Ironwood commit: $(git -C "${REPO}" rev-parse HEAD 2>/dev/null || echo unknown)"
  if [ "${#APPLIED[@]}" -gt 0 ]; then
    echo "Patches:"
    printf '  %s\n' "${APPLIED[@]}"
  else
    echo "Patches: none"
  fi
} > ironwood-build-info.txt

echo ">> Source ready in $(pwd)"
