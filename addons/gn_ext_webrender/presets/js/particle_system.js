// Particle System — burst of particles following the mouse
const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
Object.assign(canvas.style, { position: 'fixed', inset: '0' });
const ctx = canvas.getContext('2d');
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

const particles = [];
let mx = canvas.width / 2, my = canvas.height / 2;

document.addEventListener('mousemove', e => { mx = e.clientX; my = e.clientY; });

function spawn(x, y) {
  for (let i = 0; i < 3; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 1 + Math.random() * 3;
    particles.push({
      x, y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: 1.0,
      hue: Math.random() * 360,
      size: 2 + Math.random() * 4
    });
  }
}

function draw() {
  ctx.fillStyle = 'rgba(0, 0, 0, 0.08)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  spawn(mx, my);
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.x += p.vx;
    p.y += p.vy;
    p.vy += 0.02;
    p.life -= 0.008;
    if (p.life <= 0) { particles.splice(i, 1); continue; }
    ctx.globalAlpha = p.life;
    ctx.fillStyle = `hsl(${p.hue}, 90%, 60%)`;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.size * p.life, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
  requestAnimationFrame(draw);
}
requestAnimationFrame(draw);
