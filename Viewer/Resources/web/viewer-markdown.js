// Viewer: Markdown rendering (GitHub-flavoured) with highlighted code blocks.
window.viewerRenderMarkdown = function (text) {
  const el = document.getElementById('md');
  // strip YAML front matter
  text = text.replace(/^---\n[\s\S]*?\n---\n/, '');
  el.innerHTML = marked.parse(text, { gfm: true, breaks: false });
  el.querySelectorAll('pre code').forEach(block => {
    const cls = Array.from(block.classList).find(c => c.startsWith('language-'));
    const lang = cls && cls.slice(9);
    try {
      if (lang && hljs.getLanguage(lang)) block.innerHTML = hljs.highlight(block.textContent, { language: lang, ignoreIllegals: true }).value;
      else block.innerHTML = hljs.highlightAuto(block.textContent).value;
      block.classList.add('hljs');
    } catch (e) {}
  });
  const first = el.querySelector('h1');
  if (first) document.title = first.textContent;
};
window.viewerSetSize = px => document.documentElement.style.setProperty('--size', px + 'px');
