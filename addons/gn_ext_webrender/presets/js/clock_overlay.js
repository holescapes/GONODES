// Clock Overlay — digital clock with date, centered on page
const el = document.createElement('div');
Object.assign(el.style, {
  position: 'fixed', inset: '0',
  display: 'flex', flexDirection: 'column',
  alignItems: 'center', justifyContent: 'center',
  fontFamily: 'monospace', color: '#0ff', background: '#111'
});
document.body.appendChild(el);

function pad(n) { return String(n).padStart(2, '0'); }

function tick() {
  const d = new Date();
  const time = [d.getHours(), d.getMinutes(), d.getSeconds()].map(pad).join(':');
  const ms = String(d.getMilliseconds()).padStart(3, '0');
  const date = d.toLocaleDateString('en-US', {
    weekday: 'short', year: 'numeric', month: 'short', day: 'numeric'
  });
  el.innerHTML =
    `<div style="font-size:8vw;letter-spacing:0.1em">${time}<span style="font-size:3vw;opacity:0.5">.${ms}</span></div>` +
    `<div style="font-size:2vw;opacity:0.6;margin-top:0.5em">${date}</div>`;
  requestAnimationFrame(tick);
}
tick();
