// =====================================================================
//  Ironwood: extra default prefs for the "westmere" build
//  (Dell Latitude E6410: first-generation Core, older graphics, less RAM)
//
//  This file is appended to device-prefs.js when the package is built
//  for this CPU target, so it only lists what differs. A pref set here
//  replaces the same pref from device-prefs.js.
//  These are defaults only; users can still change them in about:config.
// =====================================================================

// ---- Graphics / video ----------------------------------------------
// device-prefs.js forces hardware rendering and VA-API for the HD 620.
// On this laptop's older graphics that can glitch or crash, so let the
// browser decide for itself what the hardware supports.
pref("gfx.webrender.all", false);
pref("gfx.x11-egl.force-enabled", false);
pref("media.ffmpeg.vaapi.enabled", false);

// Old graphics chips draw scrolling animations slowly.
pref("general.smoothScroll", false);

// ---- Memory ----------------------------------------------------------
pref("browser.cache.memory.capacity", 262144);    // 256 MB RAM cache (KB)
// Fewer content processes: less memory, at some cost when many tabs are busy.
pref("dom.ipc.processCount", 4);
pref("dom.ipc.processCount.webIsolated", 2);
// Unload tabs that have not been used for a while when memory runs low.
pref("browser.tabs.unloadOnLowMemory", true);
