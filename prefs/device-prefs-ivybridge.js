// =====================================================================
//  Ironwood: extra default prefs for the "ivybridge" build
//  (HP Z220: Ivy Bridge CPU, AMD graphics card, 16 GB RAM)
//
//  This file is appended to device-prefs.js when the package is built
//  for this CPU target, so it only lists what differs. A pref set here
//  replaces the same pref from device-prefs.js.
//  These are defaults only; users can still change them in about:config.
// =====================================================================

// ---- Graphics / video ----------------------------------------------
// Nothing changed: hardware rendering and VA-API stay switched on, as in
// device-prefs.js. With an AMD card, VA-API video decoding comes from
// Mesa (package mesa-va-drivers), not from the Intel drivers.
// AV1 also stays off: older AMD cards cannot decode it in hardware.

// ---- Memory (16 GB RAM) ----------------------------------------------
pref("browser.cache.memory.capacity", 524288);    // 512 MB RAM cache (KB)
