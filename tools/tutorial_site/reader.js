/* The full lesson, links and code disclosures remain usable without JavaScript. */
document.documentElement.classList.add('js');
const toc = document.querySelector('.toc-disclosure');
const mobileLayout = window.matchMedia('(max-width: 760px)');
if (toc) {
  toc.open = !mobileLayout.matches;
  mobileLayout.addEventListener('change', event => { toc.open = !event.matches; });
}
const status = document.getElementById('copy-status');
let statusTimer;
for (const button of document.querySelectorAll('[data-copy]')) {
  button.addEventListener('click', async () => {
    const code = document.getElementById(button.dataset.copy).textContent;
    let copied = false;
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(code);
        copied = true;
      }
    } catch { /* Try the selection-based fallback below. */ }
    if (!copied) {
      const field = document.createElement('textarea');
      field.value = code;
      field.setAttribute('aria-label', '복사할 코드');
      field.style.cssText = 'position:fixed;left:-9999px;top:0';
      document.body.append(field);
      field.select();
      try { copied = document.execCommand('copy'); } catch { copied = false; }
      field.remove();
      button.focus({ preventScroll: true });
    }
    status.textContent = copied ? '파일의 전체 코드를 복사했습니다.' : '복사하지 못했습니다. 전체 코드를 펼쳐 직접 선택해 주세요.';
    clearTimeout(statusTimer);
    statusTimer = setTimeout(() => { status.textContent = ''; }, 3500);
  });
}
const links = [...document.querySelectorAll('.sidebar a[href^="#"]')];
if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      for (const link of links) {
        if (decodeURIComponent(link.hash.slice(1)) === entry.target.id) link.setAttribute('aria-current', 'location');
        else link.removeAttribute('aria-current');
      }
    }
  }, { rootMargin: '0px 0px -65% 0px', threshold: 0 });
  document.querySelectorAll('.chapter-section').forEach(section => observer.observe(section));
}
window.addEventListener('beforeprint', () => {
  document.querySelectorAll('details').forEach(detail => {
    detail.dataset.printOpen = detail.open ? 'yes' : 'no';
    detail.open = true;
  });
});
window.addEventListener('afterprint', () => {
  document.querySelectorAll('details').forEach(detail => {
    detail.open = detail.dataset.printOpen === 'yes';
    delete detail.dataset.printOpen;
  });
});
