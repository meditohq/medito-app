const fs=require('fs');
const sharp=require('/Users/mike/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root='/Users/mike/Projects/Medito/medito_new';
const source=fs.readFileSync(root+'/assets/medito_ios_logo.icon/Assets/logo.svg','utf8');
const path=source.match(/<path[^>]*d="([^"]+)"/)[1];
const colors={white:'#FFFFFF',cream:'#F5EBD8',charcoal:'#171717',forest:'#315A4B'};
(async()=>{
 for(const [name,color] of Object.entries(colors)){
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="2400" height="1220" viewBox="0 0 120 61"><path d="${path}" fill="${color}"/></svg>`;
  fs.writeFileSync(root+`/output/merch-expansion/medito-mark-${name}.svg`,svg);
  await sharp(Buffer.from(svg)).png().withMetadata({density:300}).toFile(root+`/output/merch-expansion/medito-mark-${name}.png`);
 }
 const panels=[['Washed charcoal','cream','#323331'],['Forest','cream','#345447'],['Natural','forest','#E9E3D6'],['Navy','white','#26323E']];
 const body=panels.map(([label,ink,bg],i)=>`<g transform="translate(${i*420},0)"><rect width="420" height="420" fill="${bg}"/><g transform="translate(120,150) scale(1.5)"><path d="${path}" fill="${colors[ink]}"/></g><text x="30" y="380" font-family="Arial, sans-serif" font-size="20" fill="${i===2?'#171717':'#FFFFFF'}">${label} / ${ink}</text></g>`).join('');
 const preview=`<svg xmlns="http://www.w3.org/2000/svg" width="1680" height="420" viewBox="0 0 1680 420">${body}</svg>`;
 fs.writeFileSync(root+'/output/merch-expansion/logo-color-study.svg',preview);
 await sharp(Buffer.from(preview)).png().toFile(root+'/output/merch-expansion/logo-color-study.png');
 for(const name of Object.keys(colors)){
  const m=await sharp(root+`/output/merch-expansion/medito-mark-${name}.png`).metadata();
  console.log(name,m.width,m.height,'alpha',m.hasAlpha,'dpi',m.density);
 }
})();
