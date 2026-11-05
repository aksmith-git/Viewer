export function drawOrbits(canvas, planets) {
  const ctx = canvas.getContext('2d');
  const c = canvas.width / 2;
  let t = 0;
  function frame() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const sun = ctx.createRadialGradient(c, c, 4, c, c, 34);
    sun.addColorStop(0, '#fff6c8'); sun.addColorStop(1, '#ff9d2e');
    ctx.fillStyle = sun; ctx.beginPath(); ctx.arc(c, c, 26, 0, Math.PI * 2); ctx.fill();
    planets.forEach((p, i) => {
      const r = 48 + i * 30;
      ctx.strokeStyle = 'rgba(255,255,255,0.10)'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke();
      const a = t / (8 + i * 6) + i;
      ctx.fillStyle = p.color; ctx.beginPath();
      ctx.arc(c + Math.cos(a) * r, c + Math.sin(a) * r, 5 + Math.min(p.moons, 8) * 0.6, 0, Math.PI * 2); ctx.fill();
    });
    t += 1;
    requestAnimationFrame(frame);
  }
  frame();
}
