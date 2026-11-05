import { drawOrbits } from './orbits.js';

const res = await fetch('data/planets.json');
const planets = await res.json();
const grid = document.getElementById('planets');
for (const p of planets) {
  const card = document.createElement('article');
  card.className = 'card';
  card.innerHTML = `<h3><span class="dot" style="background:${p.color}"></span>${p.name}</h3>
    <p>${p.distance} AU from the Sun · ${p.moons} moon${p.moons === 1 ? '' : 's'}</p>`;
  grid.appendChild(card);
}
drawOrbits(document.getElementById('orbit'), planets);
document.getElementById('status').textContent = `JavaScript modules and fetch() working · ${planets.length} planets`;
console.log('Loaded', planets.length, 'planets');
console.info('Rendering orbits with canvas');
