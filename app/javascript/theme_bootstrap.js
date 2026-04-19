// Classic script (NOT an ES module) loaded synchronously in <head> via
// javascript_include_tag("theme_bootstrap") so it runs before first paint
// and avoids flash-of-wrong-theme when the user has dark mode selected.
//
// Runtime theme management (cycling auto → light → dark, persisting the
// choice, syncing tabs) lives in app/javascript/controllers/theme_controller.js.

(function () {
  var STORAGE_KEY = "kitchef_theme";

  try {
    var stored = localStorage.getItem(STORAGE_KEY) || "auto";
    var systemDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    var isDark = stored === "dark" || (stored === "auto" && systemDark);
    if (isDark) document.documentElement.classList.add("dark");
  } catch (e) {
    // localStorage may be disabled (private mode, enterprise policy). Stay
    // in light mode silently — the toggle controller will recover gracefully.
  }
})();
