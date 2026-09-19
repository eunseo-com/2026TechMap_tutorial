(() => {
  const base = "/2026TechMap_tutorial";
  const legacy = `${base}/tutorials/scenekittorealitykit`;
  const routes = new Map([
    [legacy, `${base}/`],
    [`${legacy}/01-closedworld`, `${base}/`],
    [`${legacy}/02-openingthedoor`, `${base}/chapters/2/`],
    [`${legacy}/03-realhideandseek`, `${base}/chapters/3/`],
    [`${legacy}/04-comparison`, `${base}/chapters/4/`],
  ]);

  // Run before the DocC router intercepts a reference-document link.
  document.addEventListener("click", (event) => {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return;
    const link = event.target.closest?.("a[href]");
    if (!link || link.hasAttribute("download") || (link.target && link.target !== "_self")) return;
    const url = new URL(link.href, location.href);
    if (url.origin !== location.origin) return;
    const target = routes.get(url.pathname.replace(/\/$/, ""));
    if (!target) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    location.assign(target);
  }, true);
})();
