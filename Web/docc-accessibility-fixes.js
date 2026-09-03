(() => {
  "use strict";

  function effectiveBackground(element) {
    let current = element;
    while (current) {
      const match = getComputedStyle(current).backgroundColor.match(
        /^rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)$/,
      );
      if (match && (match[4] === undefined || Number(match[4]) > 0)) {
        return [Number(match[1]), Number(match[2]), Number(match[3])];
      }
      current = current.parentElement;
    }
    return [255, 255, 255];
  }

  function enforceTextContrast(element) {
    const [red, green, blue] = effectiveBackground(element);
    const perceivedBrightness = (red * 299 + green * 587 + blue * 114) / 1000;
    const foreground = perceivedBrightness < 150
      ? "rgb(255, 255, 255)"
      : "rgb(17, 17, 17)";
    if (getComputedStyle(element).color !== foreground) {
      element.style.setProperty("color", foreground, "important");
    }
  }

  function repairDocument() {
    if (document.getElementById("resources")) {
      for (const link of document.querySelectorAll('a[href*="#"]')) {
        const target = new URL(link.href, document.baseURI);
        let fragment;
        try {
          fragment = decodeURIComponent(target.hash.slice(1));
        } catch {
          continue;
        }
        if (target.pathname === location.pathname && fragment === "리소스") {
          target.hash = "resources";
          link.href = target.href;
        }
      }
    }

    for (const item of document.querySelectorAll(".item[aria-label]:not([role])")) {
      item.setAttribute("role", "group");
    }

    for (const button of document.querySelectorAll("button.toggle:not([aria-label])")) {
      const label = button.closest(".hierarchy-collapsed-items")
        ? "숨겨진 탐색 경로 보기"
        : "추가 내용 보기";
      button.setAttribute("aria-label", label);
    }

    for (const checkbox of document.querySelectorAll('input[type="checkbox"]:not([aria-label])')) {
      const label = checkbox.parentElement?.innerText.trim() || "체크리스트 항목";
      checkbox.setAttribute("aria-label", label);
    }

    for (const tableWrapper of document.querySelectorAll(".table-wrapper:not([tabindex])")) {
      tableWrapper.setAttribute("tabindex", "0");
    }

    for (const label of document.querySelectorAll(".color-scheme-toggle label")) {
      if (!label.querySelector('input[type="radio"]:checked')) {
        const text = label.querySelector(".text");
        if (text) enforceTextContrast(text);
      }
    }

    for (const text of document.querySelectorAll(
      ".mobile-code-preview .filename a, .mobile-code-preview .toggle-text",
    )) {
      enforceTextContrast(text);
    }
  }

  repairDocument();

  const observer = new MutationObserver(repairDocument);
  observer.observe(document.body, {
    attributes: true,
    attributeFilter: ["class"],
    childList: true,
    subtree: true,
  });
  document.addEventListener("change", repairDocument, true);
})();
