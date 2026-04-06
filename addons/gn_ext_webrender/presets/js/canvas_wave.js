// Canvas Wave — animated sine wave overlay
const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
Object.assign(canvas.style, { position: 'fixed', inset: '0' });
const ctx = canvas.getContext('2d');

function resize() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
}
window.addEventListener('resize', resize);
resize();

function draw(t) {
  const w = canvas.width, h = canvas.height;
  ctx.clearRect(0, 0, w, h);
  ctx.lineWidth = 2;
  for (let j = 0; j < 5; j++) {
    ctx.beginPath();
    ctx.strokeStyle = `hsl(${j * 60 + t * 0.02}, 80%, 60%)`;
    for (let x = 0; x < w; x++) {
      const y = h / 2 + Math.sin(x * 0.01 + t * 0.002 + j) * (80 - j * 10);
      x === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    }
    ctx.stroke();
  }
  requestAnimationFrame(draw);
}
requestAnimationFrame(draw);
