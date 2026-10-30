const fs=require('fs');
const sharp=require('/Users/mike/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const source=fs.readFileSync('assets/medito_ios_logo.icon/Assets/logo.svg','utf8').match(/<path[^>]*d="([^"]+)"/)[1];
(async()=>{
 const out=[];
 for(const name of ['cream','white','charcoal','forest']){
  const file=`output/merch-expansion/medito-mark-${name}.png`;
  const svg=fs.readFileSync(`output/merch-expansion/medito-mark-${name}.svg`,'utf8');
  const metadata=await sharp(file).metadata();
  const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const corners=[[0,0],[info.width-1,0],[0,info.height-1],[info.width-1,info.height-1]].map(([x,y])=>data[(y*info.width+x)*4+3]);
  const seen=new Uint8Array(info.width*info.height); let components=0; const areas=[];
  for(let i=0;i<seen.length;i++) if(!seen[i]&&data[4*i+3]>8){
   components++;let area=0;const q=[i];seen[i]=1;
   while(q.length){const j=q.pop();area++;let x=j%info.width,y=Math.floor(j/info.width);
    for(const k of [x?j-1:-1,x+1<info.width?j+1:-1,y?j-info.width:-1,y+1<info.height?j+info.width:-1]) if(k>=0&&!seen[k]&&data[k*4+3]>8){seen[k]=1;q.push(k);}
   }areas.push(area);
  }
  out.push({name,width:metadata.width,height:metadata.height,dpi:metadata.density,alpha:metadata.hasAlpha,corners,components,componentAreas:areas,pathExact:svg.match(/<path[^>]*d="([^"]+)"/)[1]===source});
 }
 fs.writeFileSync('output/merch-expansion/logo-verification.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out));
})();
