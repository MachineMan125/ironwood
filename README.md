# Ironwood

A Gecko (Firefox-based) browser built for one machine:

| | |
|---|---|
| OS | Devuan 6 "excalibur" (Debian trixie base, no systemd) |
| CPU | Intel Core i5-7300U, Kaby Lake (Skylake ISA: AVX2/FMA, no AVX-512) |
| GPU | Intel HD Graphics 620 (VA-API: H.264, HEVC, VP9; no AV1) |
| Desktop | MATE 1.28 / Marco on X11, 2560x1440 @ 100 Hz |

Built on GitHub Actions from the official Firefox ESR source, with
PGO + cross-language LTO, Skylake CPU tuning, X11-only, ALSA, no
telemetry, no updater, and packaged as a `.deb`.

## Repository layout

```
mozconfig                        build options (CPU tuning, PGO/LTO, X11, ALSA)
prefs/device-prefs.js            default prefs: VA-API, AV1 off, privacy
prefs/policies.json              enterprise policies: no Pocket/sponsored, uBlock Origin
patches/                         your own *.patch files, applied in name order
scripts/prepare-source.sh        download + SHA512-verify source, patch, brand
scripts/setup-rust.sh            install the Rust version Mozilla builds this Firefox with
scripts/check-toolchain.sh       fail early if Rust's LLVM is newer than clang's
scripts/make-deb.sh              turn `./mach package` output into a .deb
.github/actions/setup-build/     shared runner setup (CPU check, disk, swap, deps, sccache)
.github/workflows/build.yml      the workflow
```

## Building

1. Create a GitHub repository and push this folder to it.
2. Open **Actions → Build Ironwood → Run workflow**.
   - `firefox_version`: `latest-esr` (recommended), `latest`, or an exact version like `140.5.0esr`
   - `pgo`: on for best speed (two jobs, roughly 4–8 hours total); off for a quicker single job
   - `publish_release`: attach the `.deb` to a GitHub Release
3. Download the `.deb` and `SHA256SUMS` from the run's artifacts (or the Release).

Before the run finishes, the `.deb` is test-installed in a Debian trixie
container (Devuan 6's base) to check its dependencies and that the
browser starts.

### Automatic builds

The workflow also runs by itself twice a day. Each scheduled run checks
Mozilla's current ESR version; if that version has already been built
here it stops within seconds, otherwise it does the full PGO build and
publishes the `.deb` as a GitHub Release. To be emailed when one
appears, use **Watch → Custom → Releases** on the repository page.

GitHub only runs the schedule from the default branch, and pauses it
after 60 days without commits (re-enable it on the Actions page).
Installing the new `.deb` is still done by hand.

Use a **public** repository if you can: hosted runners are free there,
while private repos use your Actions minutes, and a PGO build burns many.

## Installing on Devuan

```bash
sudo apt install ./ironwood_*_amd64.deb

# Hardware video decoding on HD 620 (needs the non-free component):
sudo apt install intel-media-va-driver-non-free vainfo
vainfo        # should list VAProfileVP9Profile0 / H264 / HEVC
```

Then open `about:support` in Ironwood and check:

- **Compositing**: WebRender
- **HARDWARE_VIDEO_DECODING**: available
- **Refresh rate**: 100 (if it shows 60, uncomment `layout.frame_rate` in `/etc/ironwood/ironwood-prefs.js`)

`/etc/ironwood/ironwood-prefs.js` and `/etc/ironwood/policies.json` are
conffiles, so your edits survive upgrades. `/usr/lib/ironwood/ironwood-build-info.txt`
records the Firefox version, source checksum and patches of the installed build.

Package versions look like `140.5.0~esr-42`, where the last number is the
workflow run number, so a rebuild of the same Firefox version installs as an upgrade.

## Keeping it secure

Mozilla ships security fixes about every four weeks. Re-run the
workflow with `latest-esr` each time; your patches, prefs and branding
are reapplied automatically. If a patch stops applying, the
`Prepare Firefox source` step fails and tells you which one; a patch that
still applies but no longer matches exactly produces a warning to refresh it.

## Notes and limits

- **CPU tuning**: `-march=skylake` means the build will not run on CPUs
  older than about 2015 or on most Atom/Celeron chips. To share builds
  more widely, change it to `-march=x86-64-v3` (still AVX2) in `mozconfig`.
- **Branding**: built from Mozilla's neutral "unofficial" branding,
  renamed to Ironwood. Do not ship it with the Firefox name or logo.
- **Time limits**: each GitHub-hosted job can run at most 6 hours. If an
  LTO build ever hits that, set `pgo` off, or run the workflow on a
  self-hosted runner (your own machine with `runs-on: self-hosted`).
