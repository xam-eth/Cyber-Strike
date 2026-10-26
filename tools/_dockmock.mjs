import fs from 'node:fs';
import puppeteer from 'puppeteer-core';
import chromium from '@sparticuz/chromium';
const img = fs.readFileSync('/tmp/hud-02-combat.png').toString('base64');
const browser = await puppeteer.launch({ executablePath: await chromium.executablePath(), args: [...chromium.args, '--no-sandbox'], headless: true });
const page = await browser.newPage();
await page.setViewport({ width: 844, height: 390, deviceScaleFactor: 2 });
await page.setContent(`<body style="margin:0"><canvas id="c" width="844" height="390"></canvas>
<script>
const c=document.getElementById('c'),x=c.getContext('2d');
const im=new Image(); im.onload=()=>{ x.drawImage(im,0,0,844,390); window.__draw(); }; im.src='data:image/png;base64,${img}';
window.__draw=()=>{
 // top dock behind vitals+wave+system (measured from the frame)
 plate({x:34,y:36,w:810,h:112},true);
 // bottom action rail
 plate({x:505,y:150,w:330,h:230},false);
 window.__done=true;
};
function plate(r,down){
 const cut=14;
 const p=[];
 if(down){ p.push([r.x+cut,r.y],[r.x+r.w-cut,r.y],[r.x+r.w,r.y+cut],[r.x+r.w,r.y+r.h],[r.x,r.y+r.h],[r.x,r.y+cut]); }
 else { p.push([r.x,r.y],[r.x+r.w,r.y],[r.x+r.w,r.y+r.h-cut],[r.x+r.w-cut,r.y+r.h],[r.x+cut,r.y+r.h],[r.x,r.y+r.h-cut]); }
 x.beginPath(); p.forEach(([a,b],i)=> i?x.lineTo(a,b):x.moveTo(a,b)); x.closePath();
 x.fillStyle='rgba(2,5,8,0.34)'; x.fill();
 x.strokeStyle='rgba(78,106,126,0.9)'; x.lineWidth=1; x.stroke();
 const acc='rgba(122,160,188,0.85)';
 if(down) x.fillRect(r.x+cut,r.y+r.h-2,r.w-cut*2,2); else x.fillRect(r.x+cut,r.y,r.w-cut*2,2);
 x.strokeStyle='rgba(120,158,186,0.75)';
 if(down){ x.beginPath(); x.moveTo(r.x+cut,r.y); x.lineTo(r.x+cut+7,r.y); x.moveTo(r.x+r.w-cut-7,r.y); x.lineTo(r.x+r.w-cut,r.y); x.stroke(); }
 else { x.beginPath(); x.moveTo(r.x+cut,r.y+r.h); x.lineTo(r.x+cut+7,r.y+r.h); x.moveTo(r.x+r.w-cut-7,r.y+r.h); x.lineTo(r.x+r.w-cut,r.y+r.h); x.stroke(); }
}
</script></body>`, { waitUntil: 'load' });
await page.waitForFunction(() => window.__done, { timeout: 15000 });
await page.screenshot({ path: '/tmp/dock-mock.png' });
await browser.close();
