// =====================================================================
//  Ironwood default prefs (appended to browser/app/profile/firefox.js)
//  Tuned for: i5-7300U, Intel HD 620, 29.8 GB RAM,
//             Dell P2725DE 2560x1440 @ 100 Hz, MATE on X11
//  These are defaults only; users can still change them in about:config.
// =====================================================================

// ---- Graphics / video ----------------------------------------------
// Hardware video decoding through VA-API.
// Needs intel-media-va-driver(-non-free) and libavcodec on Devuan.
pref("media.ffmpeg.vaapi.enabled", true);
pref("gfx.x11-egl.force-enabled", true);
pref("gfx.webrender.all", true);

// HD 620 (Kaby Lake) can hardware-decode H.264, HEVC and VP9, but NOT AV1.
// Turning AV1 off makes YouTube and similar sites serve VP9, which the
// GPU decodes. That means far less CPU load and better battery life.
pref("media.av1.enabled", false);

// Your Dell runs at 100 Hz. With EGL on X11, Firefox should pick that up
// from vsync automatically (check "Refresh rate" in about:support).
// Only force it if about:support still shows 60; forcing it switches
// Firefox to a software timer, which can cause tearing.
// pref("layout.frame_rate", 100);

// HiDPI: you already scale through GTK (20pt fonts, 64px cursor), so
// Firefox follows the system by default. Uncomment to force a factor.
// pref("layout.css.devPixelsPerPx", "1.5");

// ---- Memory / disk (you have ~30 GB RAM) -----------------------------
pref("browser.cache.memory.capacity", 1048576);   // 1 GB RAM cache (KB)
pref("browser.sessionstore.interval", 60000);     // save session every 60s

// ---- Privacy ---------------------------------------------------------
pref("datareporting.healthreport.uploadEnabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("toolkit.telemetry.enabled", false);
pref("toolkit.telemetry.unified", false);
pref("toolkit.telemetry.archive.enabled", false);
pref("app.shield.optoutstudies.enabled", false);
pref("app.normandy.enabled", false);
pref("browser.discovery.enabled", false);
pref("extensions.pocket.enabled", false);
pref("browser.newtabpage.activity-stream.showSponsored", false);
pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
pref("browser.contentblocking.category", "strict");
pref("dom.security.https_only_mode", true);
pref("browser.shell.checkDefaultBrowser", false);
