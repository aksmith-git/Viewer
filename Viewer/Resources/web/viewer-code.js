// Viewer: code / text rendering with line numbers.
window.viewerRender = function (text, lang) {
  const code = document.getElementById('code');
  const gutter = document.getElementById('gutter');
  let count = text.split('\n').length;
  if (text.endsWith('\n')) count -= 1;
  const numbers = new Array(Math.max(count, 1));
  for (let i = 0; i < numbers.length; i++) numbers[i] = i + 1;
  gutter.textContent = numbers.join('\n');
  code.textContent = text;
  if (lang && lang !== 'plaintext' && window.hljs && hljs.getLanguage(lang)) {
    setTimeout(() => {
      try { code.innerHTML = hljs.highlight(text, { language: lang, ignoreIllegals: true }).value; } catch (e) {}
    }, 0);
  }
};
window.viewerSetWrap = on => document.body.classList.toggle('wrap', on);
window.viewerSetSize = px => document.documentElement.style.setProperty('--size', px + 'px');
window.viewerCopyText = () => document.getElementById('code').textContent;
