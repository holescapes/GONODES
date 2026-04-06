// Bar Chart — animated random bar chart, redraws every 2 seconds
const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
Object.assign(canvas.style, { position: 'fixed', inset: '0' });
const ctx = canvas.getContext('2d');
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

const N = 12;
let current = Array.from({ length: N }, () => Math.random());
let target = current.slice();
const labels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

setInterval(() => { target = Array.from({ length: N }, () => Math.random()); }, 2000);

function lerp(a, b, t) { return a + (b - a) * t; }

function draw() {
  const w = canvas.width, h = canvas.height;
  ctx.fillStyle = '#111';
  ctx.fillRect(0, 0, w, h);

  const pad = 60, barW = (w - pad * 2) / N * 0.7, gap = (w - pad * 2) / N;
  const maxH = h - pad * 2;

  for (let i = 0; i < N; i++) {
    current[i] = lerp(current[i], target[i], 0.04);
    const bh = current[i] * maxH;
    const x = pad + i * gap + (gap - barW) / 2;
    const y = h - pad - bh;
    const hue = (i / N) * 300;
    ctx.fillStyle = `hsl(${hue}, 70%, 55%)`;
    ctx.fillRect(x, y, barW, bh);
    ctx.fillStyle = '#aaa';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(labels[i], x + barW / 2, h - pad + 18);
    ctx.fillText(Math.round(current[i] * 100), x + barW / 2, y - 6);
  }
  requestAnimationFrame(draw);
}
requestAnimationFrame(draw);
