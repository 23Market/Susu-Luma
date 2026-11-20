"use strict";
function mulberry(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const rnd=mulberry(2311);
const pick=a=>a[Math.floor(rnd()*a.length)];
const ri=(lo,hi)=>lo+Math.floor(rnd()*(hi-lo+1));
const DAY=864e5, NOW=Date.parse("2026-10-21T07:00:00Z");
const BOOT=Date.now(), demoNow=()=>NOW+(Date.now()-BOOT);

const CATS=[["construction","Construction"],["agriculture","Agriculture"],["metals","Metals & Hardware"],["equipment","Equipment & Machinery"],["food","Food & Beverage"],["energy","Energy & Power"],["packaging","Packaging & Office"],["logistics","Logistics & Services"]];
const CATNAME=Object.fromEntries(CATS);
const first=["Mohamed","Fatmata","Ibrahim","Aminata","Alusine","Isatu","Abu","Mariama","Santigie","Kadiatu","Alhaji","Haja","Sorie","Zainab","Foday","Yeabu","Osman","Memunatu","Sahr","Jebbeh"];
const last=["Kamara","Sesay","Bangura","Conteh","Koroma","Turay","Mansaray","Jalloh","Kargbo","Fofanah","Sankoh","Bah","Kanu","Dumbuya","Saidu","Momoh","Williams","Coker","Deen","Yansaneh"];
const areas=["Freetown — Aberdeen","Freetown — Lumley","Freetown — Hill Station","Freetown — Wellington","Waterloo","Bo","Kenema","Makeni","Koidu","Port Loko"];
// "Title|unit" — every listing carries an explicit unit of sale.
const titlesBy={
 construction:["Portland cement 50 kg|bag","Iron roofing sheets 3 m|sheet","Sharp sand (tipper load)|load","Hollow blocks 6\"|block","Granite chippings 3/4\"|load","Ceramic floor tiles 60x60|carton","PVC pipe 4\" 6 m|length"],
 agriculture:["Fresh cocoa beans|kg","Cassava flour 25 kg|sack","Paddy rice, local variety|bag","Palm oil, 25 L|drum","Groundnuts, shelled|kg","Ginger, dried|kg"],
 metals:["Iron rods 12 mm|length","Galvanised nails 4\"|kg","Steel angle bar 40x40|length","Padlocks, heavy duty|dozen","Welding rods 3.2 mm|box","Barbed wire 50 m|roll"],
 equipment:["Concrete mixer 350 L|unit","Water pump 3 in|unit","Generator 20 kVA (hire)|day","Angle grinder 230 mm|unit","Wheelbarrow, steel|unit","Mini excavator (hire)|day"],
 food:["Bottled water 500 ml|carton","Cooking oil 5 L|carton","Sugar 50 kg|bag","Tomato paste 400 g|carton","Frozen chicken, 10 kg|carton","Instant coffee 200 g|carton"],
 energy:["Solar panel 400 W|unit","Inverter 3 kVA|unit","Deep-cycle battery 200 Ah|unit","LED floodlight 100 W|unit","Diesel, bulk|litre","Cable 2.5 mm\u00b2, 100 m|roll"],
 packaging:["Corrugated cartons, 5-ply|bundle","Plastic bags, 50 micron|bale","A4 paper 80 gsm|ream","Pallet wrap 500 mm|roll","Thermal receipt rolls|carton","Jute sacks 50 kg|bale"],
 logistics:["Container haulage Freetown\u2013Bo|trip","Warehouse space, per pallet|pallet","Freight forwarding, 20 ft|container","Cold-chain delivery|trip","Courier, upcountry|parcel","Customs clearance support|job"]
};
/* Sample photos (Wikimedia Commons, cropped/resized). Matched to listing titles by keyword; see docs/photo-credits.md. */
const PHOTO_CREDITS=[{"file": "cement","subject": "Portland cement 50 kg","title": "Portland Cement Bags","author": "KVD","license": "Public domain","page": "https://commons.wikimedia.org/wiki/File:Portland_Cement_Bags.jpg"},{"file": "cocoa","subject": "Fresh cocoa beans","title": "Cocoa beans in Guadeloupe","author": "Pkraemer","license": "CC BY-SA 4.0","page": "https://commons.wikimedia.org/wiki/File:Cocoa_beans_in_Guadeloupe.jpg"},{"file": "rebar","subject": "Iron rods 12 mm","title": "A bunch of rebar up close","author": "W.carter","license": "CC BY-SA 4.0","page": "https://commons.wikimedia.org/wiki/File:A_bunch_of_rebar_up_close.jpg"},{"file": "cassava","subject": "Cassava flour 25 kg","title": "Cassava flour","author": "Hajia Hijjah","license": "CC BY-SA 4.0","page": "https://commons.wikimedia.org/wiki/File:Cassava_flour.jpg"},{"file": "sand","subject": "Sand (tipper load)","title": "Pile of Sand for Building in Anambra State","author": "Johnnybam","license": "CC BY-SA 4.0","page": "https://commons.wikimedia.org/wiki/File:Pile_of_Sand_for_Building_in_Anambra_State.jpg"},{"file": "generator","subject": "Generator 20 kVA (hire)","title": "Sudhir diesel generator","author": "Microrao","license": "CC BY-SA 4.0","page": "https://commons.wikimedia.org/wiki/File:Sudhir_diesel_generator.jpg"}];
const PHOTO_RULES=[[/cement/i,"cement"],[/cocoa/i,"cocoa"],[/\biron rods?\b|\brebar\b/i,"rebar"],[/cassava|flour/i,"cassava"],[/\bsand\b/i,"sand"],[/generator/i,"generator"]];
function photoFor(title){if(window.LIVE&&LIVE.on)return null; /* live listings are real records: never decorate them with sample photos */const r=PHOTO_RULES.find(x=>x[0].test(title||""));return r?"photos/"+r[1]+".jpg":null}
const STAT=["active","active","active","pending","pending","paused","rejected","sold","expired","removed","archived"];
const reasonCodes=["Prohibited item","Duplicate listing","Misleading price","Wrong category","Suspected scam","Counterfeit goods","Incomplete details","Other"];
function mkName(){return pick(first)+" "+pick(last)}
function mask(s,kind){ if(!s)return "—"; if(kind==="email"){const[a,b]=s.split("@");return a[0]+"•••@"+b;} return s.replace(/(\+232 \d\d )\d\d\d(.*)/,"$1•••$2"); }
function initials(n){return n.split(" ").map(x=>x[0]).join("").slice(0,2).toUpperCase()}

let tu;let USERS=[], LISTINGS=[], REPORTS=[], CONVOS={}, CAMPAIGNS=[];
(function seed(){
  for(let i=0;i<46;i++){
    const nm=mkName(); const type=rnd()<.52?"seller":(rnd()<.2?"business":"buyer");
    const st=pick(["active","active","active","active","active","restricted","suspended","pending"]);
    const ver= type==="buyer"?"none":pick(["verified","verified","pending","none","rejected"]);
    const flags=[]; if(rnd()<.12)flags.push("impersonation"); if(rnd()<.18)flags.push("spam"); if(rnd()<.1)flags.push("repeat abuse");
    USERS.push({id:"USR-"+(40000+ri(100,999)*10+i),name:nm,type,status:st,verification:ver,
      joined:NOW-ri(2,520)*DAY, lastActive:NOW-ri(0,120)*DAY,
      email:nm.toLowerCase().replace(/[^a-z]/g,".")+"@"+pick(["gmail.com","yahoo.com","hotmail.com"]),
      phone:"+232 "+pick(["76","77","78","79","30","88","99"])+" "+ri(100,999)+" "+ri(100,999),
      area:pick(areas), reports:flags.length?ri(1,6):(rnd()<.2?ri(1,3):0), flags,
      consent:{inapp:true,push:rnd()<.85,sms:rnd()<.8,whatsapp:rnd()<.6,email:rnd()<.4}, marketingOptIn:rnd()<.72});
  }
  const sellers=USERS.filter(u=>u.type!=="buyer");
  let n=0;
  for(const[cid,]of CATS){ const arr=titlesBy[cid];
    for(let k=0;k<ri(6,9);k++){ const sel=pick(sellers); let status=pick(STAT);
      const fl=[]; if(rnd()<.14)fl.push("duplicate"); if(rnd()<.14)fl.push("misleading price"); if(rnd()<.1)fl.push("suspicious");
      if(fl.includes("suspicious")&&rnd()<.6)status="pending";
      const promoted= rnd()<.16?pick(["boost","featured","top"]):null;
      const base={construction:[120,4500],agriculture:[8,900],metals:[90,6500],equipment:[900,60000],food:[20,1800],energy:[250,22000],packaging:[15,900],logistics:[300,15000]}[cid];
      const price=ri(base[0],base[1]);
      LISTINGS.push({id:"LST-"+(10000+n++),title:(tu=pick(arr).split("|"))[0],unit:tu[1],cat:cid,sellerId:sel.id,sellerName:sel.name,
        price,status,promoted,flags:fl,reports:fl.length?ri(1,5):(rnd()<.15?1:0),
        created:NOW-ri(0,90)*DAY, views:ri(3,1400)});
    }
  }
  // reports inbox
  const rreasons=["Item never delivered","Off-platform payment demanded","Counterfeit / fake","Misleading price","Prohibited item","Spam / duplicate","Offensive content","Impersonation"];
  let rn=0;
  LISTINGS.filter(l=>l.reports>0).slice(0,14).forEach(l=>{
    REPORTS.push({id:"RPT-"+(5000+rn++),type:"listing",targetId:l.id,targetLabel:l.title,cat:l.cat,
      reason:l.flags.includes("suspicious")?"Off-platform payment demanded":pick(rreasons),
      reporter:mask(pick(USERS).email,"email"),created:NOW-ri(0,10)*DAY,status:"open",count:l.reports});
  });
  USERS.filter(u=>u.flags.includes("impersonation")).slice(0,4).forEach(u=>{
    REPORTS.push({id:"RPT-"+(5000+rn++),type:"user",targetId:u.id,targetLabel:u.name,cat:null,
      reason:"Impersonation",reporter:mask(pick(USERS).email,"email"),created:NOW-ri(0,8)*DAY,status:"open",count:ri(1,4)});
  });
  // seed a few 1:1 conversations
  const convSellers=sellers.slice(0,6);
  convSellers.forEach((s,i)=>{
    const msgs=[];
    if(i%2===0){msgs.push({from:"seller",body:"Hello admin, why was my listing paused? I don't understand.",at:NOW-ri(20,90)*6e4,channel:"in-app",state:"read"});}
    else{msgs.push({from:"system",body:'Your listing "'+(LISTINGS.find(l=>l.sellerId===s.id)||{title:"item"}).title+'" was approved and is now live.',at:NOW-ri(120,400)*6e4,channel:"in-app",state:"delivered"});
         msgs.push({from:"seller",body:"Thank you! How do I feature it?",at:NOW-ri(10,110)*6e4,channel:"in-app",state:"read"});}
    CONVOS[s.id]={sellerId:s.id,sellerName:s.name,unread:i%2===0?1:0,messages:msgs};
  });
  // seed past campaigns
  CAMPAIGNS=[
    {id:"BC-311",name:"Verify to keep selling",audience:"Unverified sellers with active listings",channels:["in-app","push","sms"],recipients:214,status:"delivered",at:NOW-2*DAY,by:"J. Momoh",cost:19350,delivered:201,read:148,replied:12},
    {id:"BC-308",name:"Eid featured promo — 30% off",audience:"All active sellers",channels:["in-app","push"],recipients:612,status:"delivered",at:NOW-6*DAY,by:"Haja Jalloh",cost:0,delivered:598,read:402,replied:0},
    {id:"BC-305",name:"Re-engage inactive sellers (60d)",audience:"Sellers inactive 60 days",channels:["sms","in-app"],recipients:88,status:"delivered",at:NOW-11*DAY,by:"J. Momoh",cost:13200,delivered:83,read:51,replied:9},
  ];
})();

/* roles / permissions */
const PERMS={
  superadmin:{label:"Super Admin",all:true,scope:null},
  operations:{label:"Operations Lead",scope:null,perms:["overview.view","listings.view","listings.moderate","listings.remove","listings.restore","listings.recategorize","listings.bulk","listings.feature","categories.view","categories.edit","categories.publish","rfqs.view","rfqs.routing.view","rfqs.investigate","rfqs.notes.manage","rfqs.export","quotes.view","quotes.compare","quotes.history.view","quotes.export","orders.view","orders.history.view","fulfilment.view","fulfilment.evidence.view","orders.investigate","orders.export","payments.view","organisations.view","organisations.members.view","verification.view","verification.evidence.view","verification.assign","verification.decide","support.cases.view","support.cases.assign","support.cases.claim","support.cases.notes.manage","support.cases.respond","support.cases.escalate","support.cases.resolve","reports.view","reports.resolve","reviews.view","reviews.moderate","analytics.view","analytics.export","catalogue.import","catalogue.import.validate","catalogue.import.commit","catalogue.import.history.view","system.health.view","messaging.send","users.view","search.listings","search.rfqs","search.orders","search.users","search.organisations","search.cases","audit.view","audit.export"]},
  trust:{label:"Trust & Safety",scope:["construction","metals","equipment","energy"],perms:["overview.view","listings.view","listings.moderate","listings.remove","listings.restore","listings.recategorize","listings.bulk","reports.view","reports.resolve","rfqs.view","rfqs.investigate","quotes.view","quotes.investigate","orders.view","orders.investigate","support.cases.view","support.cases.assign","support.cases.claim","support.cases.notes.manage","support.cases.respond","support.cases.escalate","support.cases.resolve","support.evidence.view","reviews.view","reviews.moderate","reviews.restore","reviews.appeals.view","users.view","users.restrict","users.suspend","users.reinstate","verification.view","privacy.requests.view","privacy.requests.review","analytics.view","messaging.send","search.users","search.listings","search.cases","audit.view","audit.export"]},
  support:{label:"Support",scope:null,perms:["overview.view","users.view","users.pii.search","users.pii.reveal","users.cases","users.restrict","users.reinstate","users.verify","organisations.view","organisations.members.view","reports.view","listings.view","rfqs.view","quotes.view","orders.view","payments.view","support.cases.view","support.cases.assign","support.cases.claim","support.cases.notes.manage","support.cases.respond","support.cases.escalate","support.cases.resolve","support.evidence.view","analytics.view","messaging.send","search.users","search.cases","search.orders"]},
  finance:{label:"Finance",scope:null,perms:["overview.view","revenue.view","payments.view","payments.evidence.view","payments.reconcile","payments.export","orders.view","orders.history.view","quotes.view","listings.view","listings.feature","organisations.view","analytics.view","analytics.financial.view","analytics.export","messaging.broadcast","search.orders","audit.view","audit.export"]},
  analyst:{label:"Analyst",scope:null,perms:["overview.view","analytics.view","analytics.export","listings.view","users.view","organisations.view","rfqs.view","quotes.view","orders.view","reviews.view","search.listings","search.orders"]}
};
let role="superadmin";
const ADMIN_NAME={superadmin:"J. Momoh",operations:"Sorie Mansaray",trust:"Isatu Bangura",support:"Abu Koroma",finance:"Haja Jalloh",analyst:"Zainab Kargbo"};
function can(p){const r=PERMS[role];if(r.all)return true;if(p==="search.any")return !!(r.perms&&r.perms.some(x=>x.startsWith("search.")));return !!(r.perms&&r.perms.includes(p))}
function inScope(cat){const r=PERMS[role];return !r.scope||r.scope.includes(cat)}

/* audit */
let AUDIT=[
  {at:NOW-42*6e4,actor:"Isatu Bangura",role:"Moderator",sev:"warn",action:"listing.reject",summary:'Rejected "Generator 3.5KVA Tiger"',reason:"Suspected scam"},
  {at:NOW-96*6e4,actor:"J. Momoh",role:"Super Admin",sev:"critical",action:"user.suspend",summary:"Suspended seller USR-40631",reason:"Repeat abuse"},
  {at:NOW-150*6e4,actor:"Abu Koroma",role:"Support Agent",sev:"info",action:"case.resolve",summary:"Upheld appeal, reinstated account",reason:""},
  {at:NOW-210*6e4,actor:"J. Momoh",role:"Super Admin",sev:"critical",action:"broadcast.send",summary:'Broadcast "Verify to keep selling" to 214 sellers',reason:""},
  {at:NOW-320*6e4,actor:"Isatu Bangura",role:"Moderator",sev:"warn",action:"listing.remove",summary:'Removed "iPhone 13 128GB" (counterfeit)',reason:"Counterfeit goods"},
];
let AUDSEQ=9000;
function audit(action,summary,sev,reason){if(window.LIVE&&LIVE.on)return; /* live: the database writes the audit entry */AUDSEQ++;AUDIT.unshift({id:"AUD-"+AUDSEQ,at:demoNow(),actor:ADMIN_NAME[role],role:PERMS[role].label,sev,action,summary,reason:reason||"",ref:"REQ-"+(AUDSEQ*7919%100000).toString(36).toUpperCase().padStart(4,"0"),key:"idem-"+(AUDSEQ*104729%1e9).toString(36)});renderOverviewFeeds();if(typeof window.onAudit==="function")window.onAudit();}

/* helpers */
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const money=n=> n===0?"—":"SLE "+n.toLocaleString("en-US");
function ago(t){const m=Math.round((demoNow()-t)/6e4);if(m<1)return"just now";if(m<60)return m+"m ago";const h=Math.round(m/60);if(h<24)return h+"h ago";const dd=Math.round(h/24);return dd+"d ago";}
function dateStr(t){return new Date(t).toLocaleDateString("en-GB",{day:"2-digit",month:"short",year:"numeric"})}
const esc=s=>String(s).replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
function toast(msg,kind){const t=document.createElement("div");t.className="toast"+(kind?" "+kind:"");t.textContent=msg;$("#toasts").appendChild(t);setTimeout(()=>t.remove(),2800);}

/* metrics */
function metrics(){
  const u=USERS,l=LISTINGS;
  return{users:u.length,activeUsers:u.filter(x=>x.status==="active").length,newUsers:u.filter(x=>x.joined>NOW-30*DAY).length,
    listings:l.length,activeListings:l.filter(x=>x.status==="active").length,pendingListings:l.filter(x=>x.status==="pending").length,
    reportedListings:l.filter(x=>x.reports>0).length,scams:l.filter(x=>x.flags.includes("suspicious")).length,
    verifyQueue:u.filter(x=>x.verification==="pending").length,promoted:l.filter(x=>x.promoted).length,
    revenue:l.filter(x=>x.promoted).reduce((s,x)=>s+({boost:150,featured:450,top:900}[x.promoted]),0),
    openReports:REPORTS.filter(r=>r.status==="open").length,
    unread:Object.values(CONVOS).reduce((s,c)=>s+(c.unread||0),0),
    openCases:u.filter(x=>x.status==="suspended"||x.status==="restricted").length+u.filter(x=>x.flags.includes("repeat abuse")).length};
}

/* ---------- OVERVIEW ---------- */
function regSeries(){const out=[];for(let i=13;i>=0;i--){const day=NOW-i*DAY;let c=0;for(const u of USERS){if(u.joined>=day-DAY/2&&u.joined<day+DAY/2)c++;}out.push(Math.max(c,ri(1,6)));}return out;}
const REG=regSeries();
function lineChart(data){
  const w=560,h=150,pad=22,max=Math.max(...data)*1.2;
  const x=i=>pad+i*(w-pad*2)/(data.length-1), y=v=>h-pad-(v/max)*(h-pad*2);
  const pts=data.map((v,i)=>[x(i),y(v)]);
  const line=pts.map((p,i)=>(i?"L":"M")+p[0].toFixed(1)+" "+p[1].toFixed(1)).join(" ");
  const area=line+` L ${x(data.length-1).toFixed(1)} ${h-pad} L ${pad} ${h-pad} Z`;
  let g="";[0,.5,1].forEach(f=>{const yy=(pad+f*(h-pad*2)).toFixed(1);g+=`<line class="grid-l" x1="${pad}" y1="${yy}" x2="${w-pad}" y2="${yy}"/>`});
  const last=pts[pts.length-1];
  return `<svg class="chart" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" role="img" aria-label="New registrations, last 14 days">${g}<path class="area" d="${area}"/><path class="line" d="${line}"/><circle class="dot" cx="${last[0].toFixed(1)}" cy="${last[1].toFixed(1)}" r="3.5"/><text x="${pad}" y="${h-6}">14d ago</text><text x="${w-pad}" y="${h-6}" text-anchor="end">today</text><text x="${pad}" y="14">peak ${Math.max(...data)}</text></svg>`;
}
function catBars(){const counts=CATS.map(([id,nm])=>[nm,LISTINGS.filter(l=>l.cat===id&&l.status==="active").length]).sort((a,b)=>b[1]-a[1]).slice(0,6);const max=Math.max(...counts.map(c=>c[1]),1);return `<div class="bars">`+counts.map(([nm,n])=>`<div class="bar-row"><span>${esc(nm)}</span><div class="bar-track"><div class="bar-fill" style="width:${Math.round(n/max*100)}%"></div></div><span class="n tnum">${n}</span></div>`).join("")+`</div>`;}
function renderOverview(){
  const m=metrics();
  const kpi=(lab,val,sub,cls)=>`<div class="kpi${cls?" "+cls:""}"><div class="lab">${lab}</div><div class="val tnum">${val}</div><div class="sub">${sub}</div></div>`;
  $("#view-overview").innerHTML=`
   <div class="view-head"><div><h1>Executive overview</h1><p>Marketplace performance and anything that needs attention today. Generated sample data for Freetown and nationwide sellers.</p></div></div>
   <div class="eyebrow">People &amp; listings</div>
   <div class="kpis">${kpi("Total users",m.users.toLocaleString(),`<b class="up">+${m.newUsers}</b> new in 30d`)}${kpi("Active users",m.activeUsers.toLocaleString(),`${Math.round(m.activeUsers/m.users*100)}% of accounts`)}${kpi("Total listings",m.listings.toLocaleString(),`<b>${m.activeListings}</b> active now`)}${kpi("Pending review",m.pendingListings,"awaiting moderation",m.pendingListings>6?"alert":"")}</div>
   <div class="eyebrow">Engagement &amp; risk</div>
   <div class="kpis">${kpi("New enquiries",ri(180,240),`buyer messages, 7d · <b class="up">+14%</b>`)}${kpi("Open reports",m.openReports,`<b>${m.scams}</b> suspected scams`,m.openReports>0?"alert":"")}${kpi("Unresolved cases",m.openCases,"appeals & restrictions",m.openCases>5?"alert":"")}${kpi("Ad revenue (30d)",money(m.revenue),`<b>${m.promoted}</b> promoted`)}</div>
   <div id="b2bKpis"></div>
   <div class="eyebrow">Operations</div>
   <div class="grid-2">
     <div class="panel"><div class="panel-h"><h3>New registrations</h3><span class="hint">last 14 days</span></div><div class="panel-b">${lineChart(REG)}</div><div class="panel-h" style="border-top:1px solid var(--border)"><h3>Active listings by category</h3><span class="hint">top 6</span></div><div class="panel-b">${catBars()}</div></div>
     <div style="display:flex;flex-direction:column;gap:14px">
       <div class="panel"><div class="panel-h"><h3>Work queues</h3></div><div class="qlist" id="queues"></div></div>
       <div class="panel"><div class="panel-h"><h3>System status</h3><span class="hint">live</span></div><div class="svc"><span class="chip"><i></i>Mobile API</span><span class="chip"><i></i>Payments</span><span class="chip degraded"><i></i>Media upload</span><span class="chip"><i></i>Search</span><span class="chip"><i></i>SMS gateway</span></div><div class="qlist"><div class="qrow"><div class="qi tone-warn"><svg viewBox="0 0 24 24"><path d="M12 9v4m0 4h.01M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg></div><div class="qt"><b>API error rate</b><span>0.4% of requests, last hour</span></div><span class="qn tnum">0.4%</span></div><div class="qrow"><div class="qi tone-crit"><svg viewBox="0 0 24 24"><path d="M3 12a9 9 0 1 0 18 0 9 9 0 0 0-18 0Z"/><path d="M12 8v4m0 4h.01"/></svg></div><div class="qt"><b>Background-job failures</b><span>media-thumbnailer, retrying</span></div><span class="qn tnum">3</span></div></div></div>
     </div>
   </div>
   <div class="eyebrow">Recent administrative actions &amp; alerts</div>
   <div class="grid-2"><div class="panel"><div class="panel-h"><h3>Audit trail</h3><span class="hint">every change &amp; refusal</span></div><div class="feed" id="auditFeed"></div></div><div class="panel"><div class="panel-h"><h3>Critical alerts</h3></div><div class="qlist" id="alerts"></div></div></div>`;
  renderQueues();renderOverviewFeeds();renderAlerts();if(typeof window.overviewExtra==="function")window.overviewExtra();
}
function renderQueues(){
  const m=metrics();
  const q=[["tone-warn","review","Pending listing reviews",m.pendingListings,"listings"],["tone-crit","flag","Open reports",m.openReports,"reports"],["tone-acc","verify","Seller verification queue",m.verifyQueue,"users"],["tone-crit","case","Appeals & recovery cases",m.openCases,"users"]];
  const ic={review:'<path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>',flag:'<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><path d="M4 22V4"/>',verify:'<path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="9"/>',case:'<path d="M3 12a9 9 0 1 0 18 0 9 9 0 0 0-18 0Z"/><path d="M12 8v4m0 4h.01"/>'};
  $("#queues").innerHTML=q.map(([tone,ik,lab,n,view])=>`<div class="qrow" data-goto="${view}" role="button" tabindex="0"><div class="qi ${tone}"><svg viewBox="0 0 24 24">${ic[ik]}</svg></div><div class="qt"><b>${lab}</b><span>tap to open queue</span></div><span class="qn tnum">${n}</span><span class="go">›</span></div>`).join("");
}
function renderOverviewFeeds(){const f=$("#auditFeed");if(!f)return;f.innerHTML=AUDIT.slice(0,6).map(a=>`<div class="feed-row"><div class="sev sev-${a.sev==="critical"?"crit":a.sev}"></div><div class="fb"><b>${esc(a.summary)}</b>${a.reason?` · ${esc(a.reason)}`:""}<time>${esc(a.actor)} · ${esc(a.role)} · ${ago(a.at)}</time></div></div>`).join("");}
function renderAlerts(){const m=metrics();const al=[];if(m.scams>0)al.push(["crit",`${m.scams} listings flagged as suspected scams`,"Awaiting moderator review"]);al.push(["warn","Media-upload service degraded","Thumbnails delayed ~4 min"]);if(m.pendingListings>6)al.push(["warn",`${m.pendingListings} listings pending beyond SLA`,"Oldest waiting 2 days"]);al.push(["acc","Broadcast approval waiting","“Price-drop weekend” needs sign-off"]);$("#alerts").innerHTML=al.map(([s,t,d])=>`<div class="qrow"><div class="qi tone-${s==="crit"?"crit":s==="warn"?"warn":"acc"}"><svg viewBox="0 0 24 24"><path d="M12 9v4m0 4h.01M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg></div><div class="qt"><b>${t}</b><span>${d}</span></div></div>`).join("");}

/* ---------- LISTINGS (with bulk) ---------- */
let LF={q:"",status:"all",cat:"all",flag:"all"}; let LSEL=new Set();
function renderListings(){
  const v=$("#view-listings");
  if(!v.dataset.built){
    v.innerHTML=`<div class="view-head"><div><h1>Listings &amp; catalogue</h1><p>Control the quality and lifecycle of every listing. Select rows for bulk moderation. Actions are role-checked, audited, and notify the seller.</p></div></div>
     <div class="toolbar"><input type="search" id="lSearch" placeholder="Search title, seller or ID…">
       <div class="seg" id="lStatus">${["all","draft","pending","active","paused","rejected","removed","sold","expired","archived"].map(s=>`<button data-s="${s}" aria-pressed="${s==="all"}">${s[0].toUpperCase()+s.slice(1)}</button>`).join("")}</div>
       <select class="filt" id="lCat"><option value="all">All categories</option>${CATS.map(([id,nm])=>`<option value="${id}">${nm}</option>`).join("")}</select>
       <select class="filt" id="lFlag"><option value="all">Any quality flag</option><option value="duplicate">Duplicates</option><option value="misleading price">Misleading price</option><option value="suspicious">Suspicious</option><option value="reported">Reported</option><option value="promoted">Promoted</option></select></div>
     <div class="tablewrap"><div class="tscroll"><table><thead><tr><th class="selcol"><input type="checkbox" id="lAll" aria-label="Select all"></th><th>Listing</th><th>Seller</th><th>Category</th><th>Price</th><th>Flags</th><th>Status</th><th></th></tr></thead><tbody id="lBody"></tbody></table></div></div>
     <div id="bulkbar"></div>`;
    v.dataset.built="1";
    $("#lSearch").addEventListener("input",e=>{LF.q=e.target.value.toLowerCase();drawListings()});
    $("#lStatus").addEventListener("click",e=>{const b=e.target.closest("button");if(!b)return;$$("#lStatus button").forEach(x=>x.setAttribute("aria-pressed",x===b));LF.status=b.dataset.s;drawListings()});
    $("#lCat").addEventListener("change",e=>{LF.cat=e.target.value;drawListings()});
    $("#lFlag").addEventListener("change",e=>{LF.flag=e.target.value;drawListings()});
    $("#lAll").addEventListener("change",e=>{const rows=LISTINGS.filter(listingMatch);if(e.target.checked)rows.forEach(l=>LSEL.add(l.id));else LSEL.clear();drawListings()});
  }
  drawListings();
}
function listingMatch(l){
  if(LF.status!=="all"&&l.status!==LF.status)return false;
  if(LF.cat!=="all"&&l.cat!==LF.cat)return false;
  if(LF.flag==="reported"&&!(l.reports>0))return false;
  if(LF.flag==="promoted"&&!l.promoted)return false;
  if(["duplicate","misleading price","suspicious"].includes(LF.flag)&&!l.flags.includes(LF.flag))return false;
  if(LF.q){const h=(l.title+" "+l.sellerName+" "+l.id).toLowerCase();if(!h.includes(LF.q))return false;}
  return true;
}
function flagHtml(l){let s=l.flags.map(f=>`<span class="flagtag${f==="suspicious"?" sus":""}">${f}</span>`).join("");if(l.reports>0)s+=`<span class="flagtag sus">${l.reports} report${l.reports>1?"s":""}</span>`;return s||`<span class="meta">—</span>`;}
function drawListings(){
  const rows=LISTINGS.filter(listingMatch).sort((a,b)=>b.created-a.created);
  const b=$("#lBody");
  [...LSEL].forEach(id=>{if(!rows.find(r=>r.id===id))LSEL.delete(id)});
  if(!rows.length){b.innerHTML=`<tr><td colspan="8"><div class="empty">No listings match these filters.</div></td></tr>`;renderBulkBar();return;}
  b.innerHTML=rows.map(l=>`<tr data-id="${l.id}">
    <td class="selcol"><input type="checkbox" data-sel="${l.id}" ${LSEL.has(l.id)?"checked":""} aria-label="Select ${l.id}"></td>
    <td><div class="lrow">${photoFor(l.title)?`<img class="lthumb" src="${photoFor(l.title)}" alt="" loading="lazy">`:`<span class="lthumb" aria-hidden="true"></span>`}<div><span class="ttl">${esc(l.title)}</span><span class="meta">${l.id} · ${ago(l.created)}${l.promoted?` · <span style="color:var(--accent)">★ ${l.promoted}</span>`:""}</span></div></div></td>
    <td class="selname">${esc(l.sellerName)}<span>${l.sellerId}</span></td>
    <td>${CATNAME[l.cat]}</td><td class="price">${money(l.price)}${l.price?` <span class="meta">/ ${esc(l.unit||"unit")}</span>`:""}</td><td>${flagHtml(l)}</td>
    <td><span class="pill st-${l.status}">${l.status}</span></td>
    <td><div class="rowacts">${listingActionsInline(l)}</div></td></tr>`).join("");
  const all=$("#lAll");if(all)all.checked=rows.every(r=>LSEL.has(r.id))&&rows.length>0;
  renderBulkBar();
}
function listingActionsInline(l){
  const scoped=inScope(l.cat);
  const btn=(act,cls,txt,perm)=>{const ok=can(perm)&&scoped;return `<button class="btn sm ${cls}" data-act="${act}" data-id="${l.id}" ${ok?"":"data-lock disabled title='Not permitted for your role/scope'"}>${txt}</button>`};
  if(l.status==="pending")return btn("approve","good","Approve","listings.moderate")+btn("reject","danger","Reject","listings.moderate");
  if(l.status==="active")return btn("pause","","Pause","listings.moderate")+btn("remove","danger","Remove","listings.remove");
  if(l.status==="paused")return btn("resume","good","Resume","listings.moderate");
  if(l.status==="rejected"||l.status==="removed")return btn("restore","","Restore","listings.restore");
  return `<button class="btn sm" data-open="${l.id}">View</button>`;
}
function renderBulkBar(){
  const bar=$("#bulkbar");if(!bar)return;if(window.LIVE&&LIVE.on){bar.innerHTML="";return}
  if(!LSEL.size){bar.innerHTML="";return;}
  const canBulk=can("listings.bulk")||can("listings.moderate");
  bar.innerHTML=`<div class="bulkbar"><b>${LSEL.size}</b> selected<span class="sp"></span>
    <button class="btn" data-bulk="approve" ${canBulk?"":"disabled data-lock"}>Approve</button>
    <button class="btn" data-bulk="reject" ${canBulk?"":"disabled data-lock"}>Reject</button>
    <button class="btn" data-bulk="remove" ${can("listings.remove")?"":"disabled data-lock"}>Remove</button>
    <button class="btn" data-bulk="clear">Clear</button></div>`;
}

/* ---------- USERS ---------- */
let UF={q:"",type:"all",status:"all"};
function renderUsers(){
  const v=$("#view-users");
  if(!v.dataset.built){
    v.innerHTML=`<div class="view-head"><div><h1>Users &amp; sellers</h1><p>Manage accounts while protecting people from abuse. Contact details are masked by default and revealed only with a stated purpose, where your role permits.</p></div></div>
     <div class="toolbar"><input type="search" id="uSearch" placeholder="Search by name, ID, email or phone…"><div class="seg" id="uType">${["all","buyer","seller","business"].map(s=>`<button data-s="${s}" aria-pressed="${s==="all"}">${s[0].toUpperCase()+s.slice(1)}</button>`).join("")}</div><select class="filt" id="uStatus"><option value="all">Any status</option><option value="active">Active</option><option value="restricted">Restricted</option><option value="suspended">Suspended</option><option value="pending">Pending</option></select></div>
     <div class="tablewrap"><div class="tscroll"><table><thead><tr><th>Account</th><th>Type</th><th>Contact</th><th>Verification</th><th>Reports</th><th>Status</th><th></th></tr></thead><tbody id="uBody"></tbody></table></div></div>`;
    v.dataset.built="1";
    $("#uSearch").addEventListener("input",e=>{UF.q=e.target.value.toLowerCase();drawUsers()});
    $("#uType").addEventListener("click",e=>{const b=e.target.closest("button");if(!b)return;$$("#uType button").forEach(x=>x.setAttribute("aria-pressed",x===b));UF.type=b.dataset.s;drawUsers()});
    $("#uStatus").addEventListener("change",e=>{UF.status=e.target.value;drawUsers()});
  }
  drawUsers();
}
function userMatch(u){
  if(UF.type!=="all"&&u.type!==UF.type)return false;
  if(UF.status!=="all"&&u.status!==UF.status)return false;
  if(UF.q){if(!can("users.pii.search")&&(UF.q.includes("@")||/\d{3,}/.test(UF.q)))return false;const h=(u.name+" "+u.id+" "+u.email+" "+u.phone).toLowerCase();if(!h.includes(UF.q))return false;}
  return true;
}
function drawUsers(){
  const rows=USERS.filter(userMatch).sort((a,b)=>b.joined-a.joined);const b=$("#uBody");
  const piiNote=UF.q&&!can("users.pii.search")&&(UF.q.includes("@")||/\d{3,}/.test(UF.q));
  if(!rows.length){b.innerHTML=`<tr><td colspan="7"><div class="empty">${piiNote?"Searching by email or phone needs the <b>Search by email &amp; phone</b> permission, which your role doesn't have.":"No accounts match."}</div></td></tr>`;return;}
  b.innerHTML=rows.map(u=>`<tr data-uid="${u.id}"><td><span class="ttl">${esc(u.name)}</span><span class="meta">${u.id} · ${u.area}</span></td><td><span class="pill st-${u.type==="buyer"?"buyer":"active"}" style="text-transform:capitalize">${u.type}</span></td><td class="meta">${esc(mask(u.email,"email"))}<br>${esc(mask(u.phone,"phone"))}</td><td><span class="pill st-${u.verification}">${u.verification}</span></td><td class="tnum">${u.reports||"—"}</td><td><span class="pill st-${u.status}">${u.status}</span></td><td><div class="rowacts"><button class="btn sm" data-uopen="${u.id}">Manage</button></div></td></tr>`).join("");
}

/* ---------- REPORTS ---------- */
let RFs="open";
function renderReports(){
  const v=$("#view-reports");
  if(!can("reports.view")){v.innerHTML=`<div class="view-head"><div><h1>Reports</h1></div></div><div class="tablewrap"><div class="empty">Your role (${PERMS[role].label}) can't view the report inbox.</div></div>`;return;}
  if(!v.dataset.built){
    v.innerHTML=`<div class="view-head"><div><h1>Reports &amp; trust</h1><p>User reports on listings, accounts and messages. Resolve as actioned or dismissed — every decision is audited.</p></div></div>
      <div class="toolbar"><div class="seg" id="rSeg">${["open","actioned","dismissed","all"].map(s=>`<button data-s="${s}" aria-pressed="${s==="open"}">${s[0].toUpperCase()+s.slice(1)}</button>`).join("")}</div></div>
      <div class="tablewrap"><div class="tscroll"><table><thead><tr><th>Report</th><th>Target</th><th>Reason</th><th>Reporter</th><th>Status</th><th></th></tr></thead><tbody id="rBody"></tbody></table></div></div>`;
    v.dataset.built="1";
    $("#rSeg").addEventListener("click",e=>{const b=e.target.closest("button");if(!b)return;$$("#rSeg button").forEach(x=>x.setAttribute("aria-pressed",x===b));RFs=b.dataset.s;drawReports()});
  }
  drawReports();
}
function drawReports(){
  const rows=REPORTS.filter(r=>RFs==="all"||r.status===RFs).sort((a,b)=>b.created-a.created);const b=$("#rBody");
  if(!rows.length){b.innerHTML=`<tr><td colspan="6"><div class="empty">No ${RFs} reports.</div></td></tr>`;return;}
  const can2=can("reports.resolve");
  b.innerHTML=rows.map(r=>`<tr data-rid="${r.id}"><td><span class="ttl">${r.id}</span><span class="meta">${r.type} · ${ago(r.created)} · ${r.count}×</span></td><td><span class="ttl">${esc(r.targetLabel)}</span><span class="meta">${r.targetId}</span></td><td>${esc(r.reason)}</td><td class="meta">${esc(r.reporter)}</td><td><span class="pill st-${r.status}">${r.status}</span></td><td><div class="rowacts">${r.status==="open"?`<button class="btn sm good" data-rresolve="actioned" data-rid="${r.id}" ${can2?"":"disabled data-lock"}>Action</button><button class="btn sm" data-rresolve="dismissed" data-rid="${r.id}" ${can2?"":"disabled data-lock"}>Dismiss</button>`:`<span class="meta">resolved</span>`}</div></td></tr>`).join("");
}

/* ---------- MESSAGING ---------- */
let MSUB="inbox", MSEL=null;
const TEMPLATES=[
  {id:"t_approved",name:"Listing approved",kind:"auto",ch:["in-app","push"],body:'Good news {{seller}} — your listing "{{listing}}" is now live on Susu Luma.'},
  {id:"t_rejected",name:"Listing rejected",kind:"auto",ch:["in-app","push","sms"],body:'Hi {{seller}}, your listing "{{listing}}" was not approved. Reason: {{reason}}. You can edit and resubmit.'},
  {id:"t_expiring",name:"Listing expiring in 48h",kind:"auto",ch:["in-app","push"],body:'{{seller}}, your listing "{{listing}}" expires in 48 hours. Renew it to keep it visible.'},
  {id:"t_verify",name:"Verification outcome",kind:"auto",ch:["in-app","sms"],body:'{{seller}}, your seller verification was {{decision}}. {{note}}'},
  {id:"t_suspend",name:"Suspension notice",kind:"auto",ch:["in-app","sms","email"],body:'{{seller}}, your Susu Luma account has been suspended. Reason: {{reason}}. You may appeal in the app.'},
  {id:"t_verifypush",name:"Verify to keep selling",kind:"marketing",ch:["in-app","push","sms"],body:'{{seller}}, verify your account to keep your listings live and build buyer trust. It takes 2 minutes.'},
  {id:"t_reengage",name:"Re-engage inactive seller",kind:"marketing",ch:["sms","in-app"],body:'We miss you on Susu Luma, {{seller}}! Post a listing today — buyers are searching in {{area}}.'},
  {id:"t_promo",name:"Promotion announcement",kind:"marketing",ch:["in-app","push"],body:'{{seller}}, featured listings are 30% off this weekend. Boost your items to the top of the category.'}
];
function renderMessaging(){
  const v=$("#view-messaging");
  v.innerHTML=`<div class="view-head"><div><h1>Messaging &amp; broadcast</h1><p>Message sellers one-to-one, send segmented broadcasts across in-app, push, SMS, WhatsApp and email, and manage the automatic notices sent when you moderate.</p></div></div>
    <div class="toolbar"><div class="seg" id="mSeg">
      <button data-s="inbox" aria-pressed="${MSUB==="inbox"}">Seller inbox</button>
      <button data-s="broadcast" aria-pressed="${MSUB==="broadcast"}">Broadcast</button>
      <button data-s="templates" aria-pressed="${MSUB==="templates"}">Templates</button>
    </div></div>
    <div id="mBody"></div>`;
  $("#mSeg").addEventListener("click",e=>{const b=e.target.closest("button");if(!b)return;MSUB=b.dataset.s;$$("#mSeg button").forEach(x=>x.setAttribute("aria-pressed",x.dataset.s===MSUB));drawMsgBody();});
  drawMsgBody();
}
function drawMsgBody(){const el=$("#mBody");if(MSUB==="inbox")drawInbox(el);else if(MSUB==="broadcast")drawBroadcast(el);else drawTemplates(el);}

function drawInbox(el){
  const ids=Object.keys(CONVOS);
  if(!MSEL||!CONVOS[MSEL])MSEL=ids[0];
  const list=ids.map(id=>{const c=CONVOS[id];const lastMsg=c.messages[c.messages.length-1];return `<div class="conv" data-conv="${id}" aria-selected="${id===MSEL}"><div class="av">${initials(c.sellerName)}</div><div class="cm"><b>${esc(c.sellerName)}</b><span>${esc(lastMsg.body)}</span></div>${c.unread?`<div class="unread" title="unread"></div>`:""}</div>`}).join("");
  const c=CONVOS[MSEL];
  const thread=c?c.messages.map(m=>`<div class="bubble ${m.from}">${esc(m.body)}<div class="bm">${m.from==="system"?"auto-notice · ":m.from==="admin"?"you · ":""}${m.channel} · ${ago(m.at)}</div></div>`).join(""):"";
  const canSend=can("messaging.send");
  el.innerHTML=`<div class="inbox"><div class="convlist" id="convlist">${list}</div>
    <div class="thread">${c?`<div class="thread-h"><div class="av" style="width:34px;height:34px;border-radius:50%;display:grid;place-items:center;background:var(--surface-3);font-weight:700;font-family:var(--disp)">${initials(c.sellerName)}</div><div><b>${esc(c.sellerName)}</b><div class="meta">${c.sellerId}</div></div><button class="btn sm" style="margin-left:auto" data-uopen="${c.sellerId}">Open profile</button></div>
      <div class="thread-b" id="threadB">${thread}</div>
      <div class="composer"><textarea id="mInput" placeholder="${canSend?'Message '+c.sellerName+'…':'Your role can’t send messages'}" ${canSend?"":"disabled"}></textarea><button class="btn pri" id="mSend" ${canSend?"":"disabled data-lock"}>Send</button></div>`:`<div class="empty">No conversations yet.</div>`}</div></div>`;
  if(c){CONVOS[MSEL].unread=0;const tb=$("#threadB");if(tb)tb.scrollTop=tb.scrollHeight;
    const send=()=>{const inp=$("#mInput");const txt=inp.value.trim();if(!txt)return;c.messages.push({from:"admin",body:txt,at:demoNow(),channel:"in-app",state:"delivered"});audit("message.send",`Messaged ${c.sellerName}`,"info","");inp.value="";drawInbox(el);toast("Message sent to "+c.sellerName+" (in-app + push)","ok");refreshCounts();
      setTimeout(()=>{if(rnd()<.5){c.messages.push({from:"seller",body:pick(["Thank you, understood.","Okay I will fix it now.","Can you call me please?","Appreciate the help!"]),at:demoNow(),channel:"in-app",state:"read"});if(MSUB==="inbox")drawInbox(el);}},1500);};
    const sb=$("#mSend");if(sb&&canSend)sb.onclick=send;
    const mi=$("#mInput");if(mi&&canSend)mi.addEventListener("keydown",e=>{if(e.key==="Enter"&&!e.shiftKey){e.preventDefault();send();}});
  }
}

let BC={type:"all",status:"active",cat:"all",activity:"any",channels:new Set(["in-app","push"]),templateId:"",body:"",schedule:"now"};
function audienceUsers(){
  return USERS.filter(u=>{
    if(BC.type==="sellers"&&u.type==="buyer")return false;
    if(BC.type==="business"&&u.type!=="business")return false;
    if(BC.type==="buyers"&&u.type!=="buyer")return false;
    if(BC.status==="active"&&u.status!=="active")return false;
    if(BC.status==="unverified"&&!(u.type!=="buyer"&&u.verification!=="verified"))return false;
    if(BC.status==="restricted"&&!(u.status==="restricted"||u.status==="suspended"))return false;
    if(BC.cat!=="all"){const has=LISTINGS.some(l=>l.sellerId===u.id&&l.cat===BC.cat&&l.status==="active");if(!has)return false;}
    if(BC.activity==="inactive"&&!(u.lastActive<NOW-60*DAY))return false;
    if(BC.activity==="new"&&!(u.joined>NOW-7*DAY))return false;
    if(BC.activity==="power"&&!(LISTINGS.filter(l=>l.sellerId===u.id&&l.status==="active").length>=5))return false;
    return true;
  });
}
function isMarketing(){const t=TEMPLATES.find(t=>t.id===BC.templateId);return !t||t.kind==="marketing";}
function channelReach(aud){
  const marketing=isMarketing();
  const elig=marketing?aud.filter(u=>u.marketingOptIn):aud;
  const r={};["in-app","push","sms","whatsapp","email"].forEach(ch=>{const key=ch==="in-app"?"inapp":ch;r[ch]=BC.channels.has(ch)?elig.filter(u=>ch==="in-app"?true:u.consent[key]).length:0;});
  return{elig:elig.length,reach:r};
}
const CH_COST={"in-app":0,push:0,sms:150,whatsapp:50,email:0};
function drawBroadcast(el){
  const cats=CATS.map(([id,nm])=>`<option value="${id}" ${BC.cat===id?"selected":""}>${nm}</option>`).join("");
  const tmplOpts=TEMPLATES.filter(t=>t.kind==="marketing").map(t=>`<option value="${t.id}" ${BC.templateId===t.id?"selected":""}>${t.name}</option>`).join("");
  el.innerHTML=`<div class="bc-grid">
    <div class="panel"><div class="panel-b bc-form">
      <div class="fld"><label>Campaign name</label><input id="bcName" type="text" placeholder="e.g. Verify to keep selling" value="${esc(BC.name||"")}"></div>
      <label style="font-weight:600;color:var(--fg)">Audience</label>
      <div class="audrow" style="margin:8px 0 0">
        <div class="fld"><label>Who</label><select id="bcType"><option value="all"${BC.type==="all"?" selected":""}>All users</option><option value="sellers"${BC.type==="sellers"?" selected":""}>Sellers</option><option value="business"${BC.type==="business"?" selected":""}>Business accounts</option><option value="buyers"${BC.type==="buyers"?" selected":""}>Buyers</option></select></div>
        <div class="fld"><label>Status</label><select id="bcStatus"><option value="any"${BC.status==="any"?" selected":""}>Any status</option><option value="active"${BC.status==="active"?" selected":""}>Active</option><option value="unverified"${BC.status==="unverified"?" selected":""}>Unverified sellers</option><option value="restricted"${BC.status==="restricted"?" selected":""}>Restricted/suspended</option></select></div>
        <div class="fld"><label>Category (has active listing)</label><select id="bcCat"><option value="all">Any category</option>${cats}</select></div>
        <div class="fld"><label>Activity</label><select id="bcAct"><option value="any"${BC.activity==="any"?" selected":""}>Any activity</option><option value="new"${BC.activity==="new"?" selected":""}>Joined &lt; 7 days</option><option value="inactive"${BC.activity==="inactive"?" selected":""}>Inactive 60 days</option><option value="power"${BC.activity==="power"?" selected":""}>Power sellers (5+ listings)</option></select></div>
      </div>
      <div class="fld"><label>Channels</label><div class="chans" id="bcChans">${["in-app","push","sms","whatsapp","email"].map(ch=>`<button type="button" class="chan" data-ch="${ch}" aria-pressed="${BC.channels.has(ch)}">${ch} <small>${CH_COST[ch]?"SLE "+CH_COST[ch]:"free"}</small></button>`).join("")}</div></div>
      <div class="fld"><label>Message template</label><select id="bcTmpl"><option value="">Free text (marketing)</option>${tmplOpts}</select></div>
      <div class="fld"><label>Message</label><textarea id="bcBody" placeholder="Write your message… use {{seller}} and {{area}} for personalisation">${esc(BC.body)}</textarea></div>
      <div class="fld"><label>Send</label><select id="bcSched"><option value="now"${BC.schedule==="now"?" selected":""}>Send now</option><option value="scheduled"${BC.schedule==="scheduled"?" selected":""}>Schedule for tomorrow 09:00</option></select></div>
    </div></div>
    <div><div class="readout" id="bcReadout"></div></div>
  </div>
  <div class="eyebrow">Recent campaigns</div><div id="campList"></div>`;
  // wire
  $("#bcName").addEventListener("input",e=>BC.name=e.target.value);
  $("#bcBody").addEventListener("input",e=>BC.body=e.target.value);
  $("#bcType").addEventListener("change",e=>{BC.type=e.target.value;drawReadout()});
  $("#bcStatus").addEventListener("change",e=>{BC.status=e.target.value;drawReadout()});
  $("#bcCat").addEventListener("change",e=>{BC.cat=e.target.value;drawReadout()});
  $("#bcAct").addEventListener("change",e=>{BC.activity=e.target.value;drawReadout()});
  $("#bcTmpl").addEventListener("change",e=>{BC.templateId=e.target.value;const t=TEMPLATES.find(x=>x.id===BC.templateId);if(t){BC.body=t.body;$("#bcBody").value=t.body;BC.channels=new Set(t.ch);$$("#bcChans .chan").forEach(c=>c.setAttribute("aria-pressed",BC.channels.has(c.dataset.ch)));}drawReadout()});
  $("#bcChans").addEventListener("click",e=>{const b=e.target.closest(".chan");if(!b)return;const ch=b.dataset.ch;if(BC.channels.has(ch))BC.channels.delete(ch);else BC.channels.add(ch);b.setAttribute("aria-pressed",BC.channels.has(ch));drawReadout()});
  $("#bcSched").addEventListener("change",e=>BC.schedule=e.target.value);
  drawReadout();drawCampaigns();
}
function drawReadout(){
  const el=$("#bcReadout");if(!el)return;
  const aud=audienceUsers();const {elig,reach}=channelReach(aud);
  const cost=Object.entries(reach).reduce((s,[ch,n])=>s+n*CH_COST[ch],0);
  const marketing=isMarketing();
  const total=Math.max(...Object.values(reach),0);
  const bigReach=BC.channels.size?Math.max(...["in-app","push","sms","whatsapp","email"].filter(c=>BC.channels.has(c)).map(c=>reach[c])):0;
  const canBroadcast=can("messaging.broadcast");
  const needsApproval=elig>100&&!(PERMS[role].all);
  el.innerHTML=`<div class="big">${elig.toLocaleString()}<small> recipients</small></div>
    <div style="font-size:12px;color:var(--fg-muted);margin:4px 0 12px">${marketing?`marketing — opted-in only (of ${aud.length} matched)`:"transactional — all matched"}</div>
    ${["in-app","push","sms","whatsapp","email"].filter(c=>BC.channels.has(c)).map(c=>`<div class="rb"><span style="text-transform:capitalize">${c}</span><span class="n">${reach[c].toLocaleString()}${CH_COST[c]?` · SLE ${(reach[c]*CH_COST[c]).toLocaleString()}`:""}</span></div>`).join("")||`<div class="rb"><span>No channel selected</span></div>`}
    <div class="cost"><span>Estimated cost</span><b>${cost?"SLE "+cost.toLocaleString():"Free"}</b></div>
    <div style="margin-top:14px;display:flex;flex-direction:column;gap:8px">
      ${needsApproval?`<div style="font-size:11.5px;color:var(--warn);background:var(--warn-weak);border-radius:8px;padding:8px 10px">Over 100 recipients — needs a second admin with broadcast-approval to release.</div>`:""}
      <button class="btn pri" id="bcSend" ${canBroadcast&&BC.channels.size&&elig>0?"":"disabled "+(!canBroadcast?"data-lock":"")}>${BC.schedule==="scheduled"?"Schedule broadcast":needsApproval?"Submit for approval":"Send broadcast"}</button>
      ${!canBroadcast?`<div class="meta">Your role (${PERMS[role].label}) can't send broadcasts.</div>`:""}
    </div>`;
  const sb=$("#bcSend");if(sb&&!sb.disabled)sb.onclick=()=>sendBroadcast(elig,reach,cost,needsApproval);
}
function sendBroadcast(elig,reach,cost,needsApproval){
  const name=BC.name||"Untitled broadcast";
  if(!BC.body.trim()){toast("Add a message first","bad");return;}
  const channels=[...BC.channels];
  const scheduled=BC.schedule==="scheduled";
  const status= scheduled?"scheduled":needsApproval?"open":"delivered";
  const camp={id:"BC-"+ri(320,399),name,audience:audienceLabel(),channels,recipients:elig,status,at:demoNow(),by:ADMIN_NAME[role],cost,
    delivered:status==="delivered"?Math.round(elig*0.94):0,read:status==="delivered"?Math.round(elig*0.58):0,replied:status==="delivered"?Math.round(elig*0.04):0};
  CAMPAIGNS.unshift(camp);
  audit("broadcast.send",`${scheduled?"Scheduled":needsApproval?"Submitted for approval":"Broadcast"} "${name}" to ${elig} recipients`,"critical","");
  toast(scheduled?"Broadcast scheduled for 09:00":needsApproval?"Submitted for approval":`Broadcast sent to ${elig} recipients`+(cost?` · SLE ${cost.toLocaleString()}`:""),"ok");
  BC.name="";BC.body="";drawBroadcast($("#mBody"));refreshCounts();
}
function audienceLabel(){
  const p=[];if(BC.type!=="all")p.push(BC.type);else p.push("all users");
  if(BC.status==="unverified")p.push("unverified");else if(BC.status==="restricted")p.push("restricted");else if(BC.status==="active")p.push("active");
  if(BC.cat!=="all")p.push("in "+CATNAME[BC.cat]);
  if(BC.activity==="inactive")p.push("inactive 60d");else if(BC.activity==="new")p.push("joined <7d");else if(BC.activity==="power")p.push("power sellers");
  return p.join(", ");
}
function drawCampaigns(){
  const el=$("#campList");if(!el)return;
  el.innerHTML=CAMPAIGNS.map(c=>`<div class="camp-card"><div class="ch"><b>${esc(c.name)}</b><span class="pill st-${c.status}">${c.status}</span></div>
    <div class="meta" style="margin-bottom:10px">${c.id} · ${esc(c.audience)} · ${c.channels.join(", ")} · by ${esc(c.by)} · ${ago(c.at)}${c.cost?` · SLE ${c.cost.toLocaleString()}`:""}</div>
    <div class="delv"><div class="d"><b class="tnum">${c.recipients.toLocaleString()}</b><span>Recipients</span></div><div class="d"><b class="tnum">${(c.delivered||0).toLocaleString()}</b><span>Delivered</span></div><div class="d"><b class="tnum">${(c.read||0).toLocaleString()}</b><span>Read</span></div><div class="d"><b class="tnum">${(c.replied||0).toLocaleString()}</b><span>Replied</span></div></div>
    ${c.status==="open"?`<div style="margin-top:10px"><button class="btn sm ${PERMS[role].all?"pri":""}" data-approve="${c.id}" ${PERMS[role].all?"":"disabled data-lock"}>Approve &amp; release</button></div>`:""}</div>`).join("");
}
function drawTemplates(el){
  el.innerHTML=`<div class="panel"><div class="panel-h"><h3>Automatic notices</h3><span class="hint">sent by the system on moderation events</span></div><div>${TEMPLATES.filter(t=>t.kind==="auto").map(tmplRow).join("")}</div></div>
    <div class="eyebrow">Marketing templates</div><div class="panel"><div>${TEMPLATES.filter(t=>t.kind==="marketing").map(tmplRow).join("")}</div></div>`;
}
function tmplRow(t){return `<div class="tmpl"><div class="tt"><b>${esc(t.name)}</b><p>${esc(t.body)}</p><div class="meta" style="margin-top:4px">${t.ch.join(" · ")}</div></div><span class="tk ${t.kind==="auto"?"auto":""}">${t.kind==="auto"?"automatic":"marketing"}</span></div>`;}

/* auto-notice to seller on moderation */
function notifySeller(sellerId,sellerName,body,channels){if(window.LIVE&&LIVE.on)return; /* live: the database notifies */
  if(!CONVOS[sellerId])CONVOS[sellerId]={sellerId,sellerName,unread:0,messages:[]};
  CONVOS[sellerId].messages.push({from:"system",body,at:demoNow(),channel:channels.join("+"),state:"delivered"});
}

/* ---------- DRAWERS ---------- */
let revealState={};
function openListing(id){
  const l=LISTINGS.find(x=>x.id===id);if(!l)return;const scoped=inScope(l.cat);
  const quality=[];if(l.flags.includes("duplicate"))quality.push(["warn","Possible duplicate","Same title and seller as 2 other live listings"]);if(l.flags.includes("misleading price"))quality.push(["warn","Misleading price","Price is 70% below category median"]);if(l.flags.includes("suspicious"))quality.push(["crit","Suspicious content","Contact details in description; off-platform payment"]);if(l.reports>0)quality.push(["crit",`${l.reports} user report${l.reports>1?"s":""}`,"Most recent: “item never delivered”"]);
  $("#drawer").innerHTML=`<div class="drawer-h"><div><div class="hid">${l.id} · ${CATNAME[l.cat]}</div><h2>${esc(l.title)}</h2></div><button class="closex" data-close aria-label="Close">✕</button></div>
   <div class="drawer-b">${photoFor(l.title)?`<div><img class="dphoto" src="${photoFor(l.title)}" alt="${esc(l.title)}"><p class="meta" style="margin-top:5px">Sample photo · Wikimedia Commons · see credits in Settings</p></div>`:""}<div><div class="sec-t">Details</div><dl class="dl"><dt>Price</dt><dd class="price">${money(l.price)}${l.unit?` per ${esc(l.unit)}`:""}</dd><dt>Status</dt><dd><span class="pill st-${l.status}">${l.status}</span></dd><dt>Seller</dt><dd>${esc(l.sellerName)}</dd><dt>Views</dt><dd class="tnum">${l.views.toLocaleString()}</dd><dt>Listed</dt><dd>${dateStr(l.created)}</dd><dt>Promotion</dt><dd>${l.promoted?`<span class="pill promo">★ ${l.promoted}</span>`:"—"}</dd></dl></div>
     ${quality.length?`<div><div class="sec-t">Quality signals</div><div class="qlist" style="border:1px solid var(--border);border-radius:var(--r);overflow:hidden">${quality.map(([s,t,dsc])=>`<div class="qrow"><div class="qi tone-${s}"><svg viewBox="0 0 24 24"><path d="M12 9v4m0 4h.01M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg></div><div class="qt"><b>${t}</b><span>${dsc}</span></div></div>`).join("")}</div></div>`:`<div><div class="sec-t">Quality signals</div><p class="meta">No quality flags on this listing.</p></div>`}
     ${!scoped?`<div style="font-size:12.5px;color:var(--warn);background:var(--warn-weak);border:1px solid color-mix(in srgb,var(--warn) 25%,transparent);border-radius:8px;padding:9px 11px">This listing is in <b>${CATNAME[l.cat]}</b>, outside your assigned categories. You can view it but not act on it.</div>`:""}
   </div><div class="drawer-f">${listingDrawerActions(l,scoped)}</div>`;
  showDrawer();
}
function listingDrawerActions(l,scoped){const A=[];const mk=(act,cls,txt,perm)=>{const ok=can(perm)&&scoped;A.push(`<button class="btn ${cls}" data-act="${act}" data-id="${l.id}" ${ok?"":"data-lock disabled"}>${txt}</button>`)};
  if(l.status==="pending"){mk("approve","good","Approve","listings.moderate");mk("reject","danger","Reject","listings.moderate");}
  else if(l.status==="active"){mk("pause","","Pause","listings.moderate");mk("feature","pri","Promote","listings.feature");mk("remove","danger","Remove","listings.remove");}
  else if(l.status==="paused"){mk("resume","good","Resume","listings.moderate");mk("remove","danger","Remove","listings.remove");}
  else mk("restore","","Restore to review","listings.restore");
  mk("recategorize","","Recategorise","listings.recategorize");return A.join("");}
function openUser(id){
  const u=USERS.find(x=>x.id===id);if(!u)return;closeModal();
  const theirListings=LISTINGS.filter(l=>l.sellerId===u.id);const rv=revealState[u.id];
  const consentStr=Object.entries(u.consent).filter(([,v])=>v).map(([k])=>k==="inapp"?"in-app":k).join(", ")||"none";
  $("#drawer").innerHTML=`<div class="drawer-h"><div><div class="hid">${u.id} · joined ${dateStr(u.joined)}</div><h2>${esc(u.name)}</h2></div><button class="closex" data-close aria-label="Close">✕</button></div>
   <div class="drawer-b"><div><div class="sec-t">Account</div><dl class="dl"><dt>Type</dt><dd style="text-transform:capitalize">${u.type}</dd><dt>Status</dt><dd><span class="pill st-${u.status}">${u.status}</span></dd><dt>Verification</dt><dd><span class="pill st-${u.verification}">${u.verification}</span></dd><dt>Area</dt><dd>${u.area}</dd><dt>Last active</dt><dd>${ago(u.lastActive)}</dd><dt>Reports</dt><dd class="tnum">${u.reports||"—"}</dd></dl></div>
     <div><div class="sec-t">Contact</div><dl class="dl"><dt>Email</dt><dd class="reveal">${rv?esc(u.email):esc(mask(u.email,"email"))} ${rv?"":revealBtn(u.id)}</dd><dt>Phone</dt><dd class="reveal">${rv?esc(u.phone):esc(mask(u.phone,"phone"))}</dd><dt>Reachable on</dt><dd style="text-align:right">${consentStr}${u.marketingOptIn?"":" · <span style='color:var(--warn)'>no marketing</span>"}</dd></dl>${rv?`<p class="meta" style="margin-top:6px;color:var(--warn)">Revealed for “${rv}” · logged to audit</p>`:""}</div>
     ${u.flags.length?`<div><div class="sec-t">Abuse signals</div>${u.flags.map(f=>`<span class="flagtag sus">${f}</span>`).join(" ")}</div>`:""}
     <div><div class="sec-t">Listing history (${theirListings.length})</div><div class="minihist">${theirListings.slice(0,5).map(l=>`<div class="mh"><span class="pill st-${l.status}" style="transform:scale(.9)">${l.status}</span><span class="ttl">${esc(l.title)}</span><span class="price">${money(l.price)}</span></div>`).join("")||'<p class="meta">No listings.</p>'}</div></div>
   </div><div class="drawer-f">${u.type!=="buyer"?`<button class="btn" data-msg="${u.id}" ${can("messaging.send")?"":"data-lock disabled"}>Message seller</button>`:""}${userDrawerActions(u)}</div>`;
  showDrawer();
}
function revealBtn(id){return can("users.pii.reveal")?`<button data-reveal="${id}">Reveal</button>`:`<button data-lock disabled style="opacity:.5">Reveal</button>`}
function userDrawerActions(u){const A=[];const mk=(act,cls,txt,perm)=>A.push(`<button class="btn ${cls}" data-uact="${act}" data-id="${u.id}" ${can(perm)?"":"data-lock disabled"}>${txt}</button>`);
  if(u.verification==="pending")mk("verify","good","Review verification","users.verify");
  if(u.status==="active"){mk("restrict","","Restrict","users.restrict");mk("suspend","danger","Suspend","users.suspend");}
  else if(u.status==="suspended"||u.status==="restricted")mk("reinstate","good","Reinstate","users.reinstate");
  if(u.flags.length)mk("case","","Open case","users.cases");return A.join("");}
function showDrawer(){$("#drawer").classList.add("on");$("#drawer").setAttribute("aria-hidden","false");$("#scrim").classList.add("on");}
function closeDrawer(){$("#drawer").classList.remove("on");$("#drawer").setAttribute("aria-hidden","true");$("#scrim").classList.remove("on");}

/* ---------- ACTIONS + MODAL ---------- */
const NEEDS_REASON={reject:1,remove:1,restrict:1,suspend:1,recategorize:1,feature:1,verify:1};
const DESTRUCTIVE={remove:1,suspend:1};
const ACTVERB={approve:"Approve listing",reject:"Reject listing",pause:"Pause listing",resume:"Resume listing",remove:"Remove listing",restore:"Restore listing",feature:"Promote listing",recategorize:"Recategorise listing",restrict:"Restrict account",suspend:"Suspend account",reinstate:"Reinstate account",verify:"Verification decision",case:"Open case"};
function doListingAction(act,id){const l=LISTINGS.find(x=>x.id===id);if(!l)return;const pm={approve:"listings.moderate",reject:"listings.moderate",pause:"listings.moderate",resume:"listings.moderate",remove:"listings.remove",restore:"listings.restore",feature:"listings.feature",recategorize:"listings.recategorize"};if(!can(pm[act])||!inScope(l.cat)){refuse(pm[act],`listing ${id}`);return;}openActionModal({kind:"listing",act,target:l,title:ACTVERB[act],label:`${l.id} — ${l.title}`});}
function doUserAction(act,id){if(window.LIVE&&LIVE.on){toast("Account actions are not connected to the database yet in live mode","bad");return}const u=USERS.find(x=>x.id===id);if(!u)return;const pm={restrict:"users.restrict",suspend:"users.suspend",reinstate:"users.reinstate",verify:"users.verify",case:"users.cases"};if(!can(pm[act])){refuse(pm[act],`account ${id}`);return;}openActionModal({kind:"user",act,target:u,title:ACTVERB[act],label:`${u.id} — ${u.name}`});}
function refuse(perm,on){toast(`Refused: your role can't do that (${perm})`,"bad");audit("access.denied",`Refused ${perm} on ${on}`,"warn","Permission denied");}
function openActionModal(o){
  const needReason=NEEDS_REASON[o.act],destructive=DESTRUCTIVE[o.act];
  const catOpts=CATS.filter(([id])=>id!==o.target.cat).map(([id,nm])=>`<option value="${id}">${nm}</option>`).join("");
  const packOpts=`<option value="boost">Boost — SLE 150</option><option value="featured">Featured — SLE 450</option><option value="top">Top of category — SLE 900</option>`;
  const field=o.act==="verify"?`<label>Decision</label><select id="mDecision"><option value="approve">Approve verification</option><option value="reject">Reject verification</option></select>`
    :o.act==="recategorize"?`<label>Move to category</label><select id="mCat">${catOpts}</select>`
    :o.act==="feature"?`<label>Promotion pack</label><select id="mPack">${packOpts}</select><label>Billing reference</label><select id="mReason"><option>BIL-${ri(20000,29999)}</option></select>`
    :needReason?`<label>Reason</label><select id="mReason">${reasonCodes.map(r=>`<option>${r}</option>`).join("")}</select>`:"";
  const noteField=(needReason||o.act==="case")?`<label>Note ${["reject","remove","suspend","verify"].includes(o.act)?"(required)":"(optional)"}</label><textarea id="mNote" placeholder="Context for the audit trail…"></textarea>`:"";
  const notifyLine=(o.kind==="listing"||["suspend","verify","restrict"].includes(o.act))?`<p style="font-size:12px;color:var(--fg-muted);margin:-4px 0 12px;display:flex;gap:6px;align-items:center"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>The seller will be notified automatically.</p>`:"";
  $("#modalBox").innerHTML=`<h3>${o.title}</h3><p class="mono" style="font-size:12.5px">${esc(o.label)}</p>${destructive?`<div class="warnbox"><svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 9v4m0 4h.01M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg><div>This is a destructive action${o.act==="suspend"?" and will pause the seller's live listings":""}. It is written to the audit log as critical.</div></div>`:""}${field}${noteField}${notifyLine}<div class="acts"><button class="btn" data-cancel>Cancel</button><button class="btn ${destructive?"danger":"pri"}" id="mConfirm">${destructive?"Confirm":"Apply"}</button></div>`;
  $("#modal").classList.add("on");$("#modal").setAttribute("aria-hidden","false");
  $("#mConfirm").onclick=()=>applyAction(o);$("#modalBox").querySelector("[data-cancel]").onclick=closeModal;
}
function closeModal(){$("#modal").classList.remove("on");$("#modal").setAttribute("aria-hidden","true");}
function applyAction(o){
  const reason=$("#mReason")?$("#mReason").value:"";const note=$("#mNote")?$("#mNote").value.trim():"";
  if(["reject","remove","suspend"].includes(o.act)&&!note){toast("A note is required for this action","bad");return;}
  if(window.LIVE&&LIVE.on&&o.kind==="listing"){
    if(["feature","recategorize"].includes(o.act)){toast("Not connected to the database yet in live mode","bad");return}
    const why=(reason&&note?reason+" — "+note:(note||reason)).trim();
    if(["reject","pause","remove","restore"].includes(o.act)&&why.length<8){toast("Add a note: the reason must be at least 8 characters","bad");return}
    closeModal();LIVE.act("admin_moderate_listing",{p_listing:o.target._id,p_action:o.act,p_reason:why||null},"Listing "+o.act+" done");return;
  }
  const t=o.target;
  if(o.kind==="listing"){
    const map={approve:"active",reject:"rejected",pause:"paused",resume:"active",remove:"removed",restore:"pending"};
    if(o.act==="recategorize"){const nc=$("#mCat").value;const old=CATNAME[t.cat];t.cat=nc;audit("listing.recategorize",`Moved "${t.title}" from ${old} to ${CATNAME[nc]}`,"info",reason);toast("Listing recategorised","ok");}
    else if(o.act==="feature"){const pack=$("#mPack").value;t.promoted=pack;audit("listing.promote",`Promoted "${t.title}" (${pack})`,"info","");toast("Promotion applied","ok");}
    else{t.status=map[o.act];const sev=o.act==="remove"?"critical":(o.act==="reject"?"warn":"info");audit("listing."+o.act,`${o.act[0].toUpperCase()+o.act.slice(1)}ed "${t.title}"`,sev,reason);
      // auto-notice
      if(o.act==="approve")notifySeller(t.sellerId,t.sellerName,`Good news — your listing "${t.title}" is now live on Susu Luma.`,["in-app","push"]),toast("Listing live · seller notified","ok");
      else if(o.act==="reject")notifySeller(t.sellerId,t.sellerName,`Your listing "${t.title}" was not approved. Reason: ${reason}. You can edit and resubmit.`,["in-app","push","sms"]),toast("Listing rejected · seller notified","ok");
      else if(o.act==="remove")notifySeller(t.sellerId,t.sellerName,`Your listing "${t.title}" has been removed. Reason: ${reason}.`,["in-app","sms"]),toast("Listing removed · seller notified","ok");
      else toast("Listing "+t.status,"ok");}
    drawListings();
  }else{
    if(o.act==="verify"){const dec=$("#mDecision").value;t.verification=dec==="approve"?"verified":"rejected";audit("user.verify",`${dec==="approve"?"Approved":"Rejected"} verification for ${t.name}`,"info",note);notifySeller(t.id,t.name,`Your seller verification was ${dec==="approve"?"approved":"rejected"}. ${note||""}`,["in-app","sms"]);toast("Verification "+t.verification+" · seller notified","ok");}
    else{if(o.act==="case"&&window.createCaseFromUser)createCaseFromUser(t,note);const map={restrict:"restricted",suspend:"suspended",reinstate:"active"};t.status=map[o.act]||t.status;const sev=o.act==="suspend"?"critical":"warn";audit("user."+o.act,`${ACTVERB[o.act]} — ${t.name}`,o.act==="reinstate"?"info":sev,reason||note);
      if(o.act==="suspend")notifySeller(t.id,t.name,`Your Luma account has been suspended. Reason: ${note}. You may appeal in the app.`,["in-app","sms","email"]);
      if(o.act==="reinstate")notifySeller(t.id,t.name,`Your Luma account has been reinstated. Welcome back.`,["in-app","push"]);
      toast(ACTVERB[o.act]+" done"+(["suspend","reinstate"].includes(o.act)?" · seller notified":""),"ok");}
    drawUsers();
  }
  closeModal();
  if($("#drawer").classList.contains("on")){o.kind==="listing"?openListing(t.id):openUser(t.id);}
  refreshCounts();if(currentView==="overview")renderOverview();
}
function openReveal(id){const u=USERS.find(x=>x.id===id);if(!u)return;$("#modalBox").innerHTML=`<h3>Reveal contact details</h3><p>Revealing ${esc(u.name)}'s email and phone is logged with your name and the purpose you choose.</p><label>Purpose</label><select id="mPurpose"><option value="ticket">Support ticket</option><option value="fraud">Fraud investigation</option><option value="legal">Legal request</option><option value="recovery">Account recovery</option></select><div class="acts"><button class="btn" data-cancel>Cancel</button><button class="btn pri" id="mReveal">Reveal &amp; log</button></div>`;$("#modal").classList.add("on");$("#modal").setAttribute("aria-hidden","false");$("#modalBox").querySelector("[data-cancel]").onclick=closeModal;$("#mReveal").onclick=()=>{const p=$("#mPurpose").value;revealState[id]=p;audit("user.pii.reveal",`Revealed contact details for ${u.name}`,"warn",p);closeModal();openUser(id);toast("Details revealed — logged","ok");};}

/* bulk */
function openBulkModal(act){if(window.LIVE&&LIVE.on){toast("Bulk moderation is not connected to the database yet in live mode","bad");return}
  const ids=[...LSEL];const eligible=LISTINGS.filter(l=>ids.includes(l.id)&&inScope(l.cat));
  if(!eligible.length){toast("No selected listings are in your scope","bad");return;}
  const reasonSel=act!=="approve"?`<label>Reason</label><select id="mReason">${reasonCodes.map(r=>`<option>${r}</option>`).join("")}</select>`:"";
  $("#modalBox").innerHTML=`<h3>Bulk ${act} — ${eligible.length} listing${eligible.length>1?"s":""}</h3><p>${ids.length-eligible.length?`${ids.length-eligible.length} skipped (out of scope). `:""}One audit entry will record all of them. Sellers are notified.</p>${reasonSel}<div class="acts"><button class="btn" data-cancel>Cancel</button><button class="btn ${act==="remove"?"danger":"pri"}" id="mConfirm">${act[0].toUpperCase()+act.slice(1)} ${eligible.length}</button></div>`;
  $("#modal").classList.add("on");$("#modal").setAttribute("aria-hidden","false");$("#modalBox").querySelector("[data-cancel]").onclick=closeModal;
  $("#mConfirm").onclick=()=>{const reason=$("#mReason")?$("#mReason").value:"";const map={approve:"active",reject:"rejected",remove:"removed"};eligible.forEach(l=>{l.status=map[act];if(act==="approve")notifySeller(l.sellerId,l.sellerName,`Your listing "${l.title}" is now live on Susu Luma.`,["in-app","push"]);else notifySeller(l.sellerId,l.sellerName,`Your listing "${l.title}" was ${act==="remove"?"removed":"rejected"}. Reason: ${reason}.`,["in-app","sms"]);});audit("listing.bulk",`Bulk ${act} of ${eligible.length} listings`,act==="remove"?"critical":"warn",reason);eligible.forEach(l=>LSEL.delete(l.id));closeModal();drawListings();refreshCounts();toast(`${eligible.length} listings ${map[act]} · sellers notified`,"ok");};
}

/* ---------- reports resolve ---------- */
function resolveReport(id,outcome){const r=REPORTS.find(x=>x.id===id);if(!r)return;if(!can("reports.resolve")){refuse("reports.resolve","report "+id);return;}r.status=outcome;audit("report.resolve",`${outcome==="actioned"?"Actioned":"Dismissed"} report ${id} on "${r.targetLabel}"`,outcome==="actioned"?"warn":"info","");drawReports();refreshCounts();if(currentView==="overview")renderOverview();toast("Report "+outcome,"ok");}

/* ---------- module registry (Susu Luma admin spec) ---------- */
const G1="Management",G2="Marketplace Operations",G3="Trust, Safety & Service",G4="Intelligence & Governance";
const MODULES={
 overview:{g:G1,label:"Executive Overview",code:"ADM-07",pri:"P0",st:"part",legacy:"overview",perm:"overview.view"},
 orgs:{g:G1,label:"Buyers & Organisations",code:"ADM-06",pri:"P0",st:"api",perm:"organisations.view",
  blurb:"Buyer organisations, membership roles, invitations and access history.",
  kpis:["Organisations","Active buyers","Pending invitations","Suspended"],
  cols:["Organisation","Type","Owner","Location","Members","Verification","Status"],
  perms:["organisations.view","organisations.members.view"],
  api:[["GET","/admin/v1/organisations","Organisation directory"],["GET","/admin/v1/organisations/{id}","Organisation detail"],["GET","/admin/v1/organisations/{id}/members","Membership list"]]},
 users:{g:G1,label:"Sellers & Suppliers",code:"ADM-06",pri:"P0",st:"demo",legacy:"users",perm:"users.view"},
 verification:{g:G1,label:"Verification & Compliance",code:"ADM-06",pri:"P0",st:"api",perm:"verification.view",
  blurb:"Supplier verification dossiers, evidence checklists, reviewer decisions and expiry.",
  kpis:["Submitted","In review","More info required","Approved","Rejected","Suspended","Expiring soon"],
  cols:["Verification ref","Organisation","Supplier type","Submitted","Risk category","Checklist","Reviewer","Status","Review / expiry"],
  perms:["verification.view","verification.evidence.view","verification.assign","verification.decide","verification.suspend"],
  api:[["GET","/admin/v1/verifications","Verification queue"],["GET","/admin/v1/verifications/{id}","Verification dossier"],["GET","/admin/v1/verifications/{id}/evidence","Authorised evidence access"],["POST","/admin/v1/verifications/{id}/request-information","Request more information"],["POST","/admin/v1/verifications/{id}/decision","Record decision"]]},

 listings:{g:G2,label:"Listings Management",code:"ADM-—",pri:"P0",st:"demo",legacy:"listings",perm:"listings.view"},
 categories:{g:G2,label:"Categories & Attributes",code:"ADM-—",pri:"P1",st:"prop",perm:"categories.view",
  blurb:"Draft/publish taxonomy with per-category attributes, units and listing rules.",
  kpis:["Published version","Draft changes","Categories","Attributes"],
  cols:["Category","Parent","Attributes","Required unit","Pre-moderate","Status"],
  perms:["categories.view","categories.edit","categories.publish"],
  api:[["GET","/admin/v1/taxonomy","Published + draft taxonomy"],["PATCH","/admin/v1/categories/{id}","Edit draft category"],["POST","/admin/v1/taxonomy/publish","Publish draft version"]]},
 rfqs:{g:G2,label:"RFQ Management",code:"ADM-01",pri:"P0",st:"api",perm:"rfqs.view",
  blurb:"Monitor buyer Requests for Quotation, inspect supplier routing, find unanswered requests and investigate delivery failures.",
  kpis:["Total RFQs","New RFQs","Awaiting supplier response","With ≥1 quotation","Overdue","Expired","Cancelled"],
  cols:["RFQ ref","Buyer organisation","Created","Items","Destination","Target delivery","Invited suppliers","Responses","Status","Age","Priority","Operator"],
  perms:["rfqs.view","rfqs.routing.view","rfqs.investigate","rfqs.notes.manage","rfqs.export"],
  api:[["GET","/admin/v1/rfqs","Paginated RFQ directory"],["GET","/admin/v1/rfqs/{id}","RFQ detail"],["GET","/admin/v1/rfqs/{id}/routing","Supplier routing history"],["GET","/admin/v1/rfqs/{id}/quotations","Related quotations"],["POST","/admin/v1/rfqs/{id}/notes","Add internal note"],["POST","/admin/v1/rfqs/{id}/flags","Flag for investigation"]]},
 quotes:{g:G2,label:"Quotation Management",code:"ADM-02",pri:"P0",st:"api",perm:"quotes.view",
  blurb:"Oversight of supplier quotations, revisions, expiry, withdrawal and acceptance. Currency and units are shown explicitly — never silently converted.",
  kpis:["Total quotations","Awaiting buyer decision","Accepted","Declined","Expired","Withdrawn","Revised"],
  cols:["Quote ref","RFQ ref","Supplier","Buyer","Version","Lines","Currency","Submitted","Valid until","Status"],
  perms:["quotes.view","quotes.compare","quotes.history.view","quotes.investigate","quotes.export"],
  api:[["GET","/admin/v1/quotations","Quote directory"],["GET","/admin/v1/quotations/{id}","Quote detail"],["GET","/admin/v1/quotations/{id}/versions","Version history"],["GET","/admin/v1/quotations/{id}/acceptance","Acceptance record"],["GET","/admin/v1/rfqs/{id}/quote-comparison","Side-by-side comparison"]]},
 orders:{g:G2,label:"Orders & Fulfilment",code:"ADM-03",pri:"P0",st:"api",perm:"orders.view",
  blurb:"Order intent, seller confirmation, fulfilment progress and delivery exceptions. Payment and fulfilment states stay independent.",
  kpis:["Awaiting confirmation","Confirmed","Awaiting payment arrangement","Payment pending","Processing","Ready for dispatch","In transit","Delivered","Disputed","Cancelled"],
  cols:["Order ref","Buyer","Supplier","Accepted quote","Quote version","Order date","Currency","Order status","Payment status","Fulfilment status","Expected delivery","Exception"],
  perms:["orders.view","orders.history.view","fulfilment.view","fulfilment.evidence.view","orders.investigate","orders.export"],
  api:[["GET","/admin/v1/orders","Order directory"],["GET","/admin/v1/orders/{id}","Order detail"],["GET","/admin/v1/orders/{id}/timeline","Fulfilment history"],["GET","/admin/v1/orders/{id}/quote-snapshot","Accepted quote snapshot"],["GET","/admin/v1/orders/{id}/evidence","Permitted evidence"],["GET","/admin/v1/orders/{id}/issues","Related delivery issues"]]},
 delivery:{g:G2,label:"Delivery & Logistics",code:"ADM-03",pri:"P1",st:"api",perm:"fulfilment.view",
  blurb:"Fulfilment milestones across orders, including partial delivery with delivered and outstanding quantities preserved.",
  kpis:["In transit","Ready for collection","Partially delivered","Delivery exceptions","Late deliveries"],
  cols:["Order ref","Event","Timestamp","Actor","Organisation","Qty affected","Unit","Mode","Evidence","Exception"],
  perms:["fulfilment.view","fulfilment.evidence.view"],
  api:[["GET","/admin/v1/orders/{id}/timeline","Fulfilment milestones"],["GET","/admin/v1/orders/{id}/evidence","Delivery evidence references"]]},
 payments:{g:G2,label:"Payment Reconciliation",code:"ADM-04",pri:"P0",st:"api",perm:"payments.view",
  blurb:"Records and investigates payment status only. Susu Luma does not hold funds, operate escrow or settle. A user assertion alone can never mark a payment confirmed.",
  kpis:["Pending confirmation","Confirmed","Failed","Reversed","Disputed","Reconciliation exceptions"],
  cols:["Payment ref","Order ref","Buyer","Supplier","Amount","Currency","Arrangement","Provider / reference","Status","Last updated","Reconciliation"],
  perms:["payments.view","payments.evidence.view","payments.reconcile","payments.export"],
  api:[["GET","/admin/v1/payments","Payment directory"],["GET","/admin/v1/payments/{id}","Payment detail"],["GET","/admin/v1/payments/{id}/events","Provider / reconciliation events"],["POST","/admin/v1/payments/{id}/reconcile","Authorised reconciliation decision"],["POST","/admin/v1/payments/{id}/refer","Refer an exception"]]},

 reports:{g:G3,label:"Reports & Moderation",code:"ADM-05",pri:"P0",st:"demo",legacy:"reports",perm:"reports.view"},
 cases:{g:G3,label:"Support & Case Management",code:"ADM-05",pri:"P0",st:"api",perm:"support.cases.view",
  blurb:"One queue across buyer, supplier, listing, RFQ, quote, order, payment and delivery problems, with assignment, escalation and SLA.",
  kpis:["Open cases","Unassigned","High priority","Critical","Overdue","Awaiting user","Escalated","Resolved this period"],
  cols:["Case ref","Category","Reporter","Related object","Priority","Severity","Operator","Status","Created","Due","Age","Escalated"],
  perms:["support.cases.view","support.cases.assign","support.cases.claim","support.cases.notes.manage","support.cases.respond","support.cases.escalate","support.cases.resolve","support.evidence.view"],
  api:[["GET","/admin/v1/support/cases","Case queue"],["GET","/admin/v1/support/cases/{id}","Case detail"],["POST","/admin/v1/support/cases/{id}/claim","Claim case"],["POST","/admin/v1/support/cases/{id}/assign","Assign case"],["POST","/admin/v1/support/cases/{id}/notes","Internal note"],["POST","/admin/v1/support/cases/{id}/responses","User-visible response"],["POST","/admin/v1/support/cases/{id}/escalate","Escalate"],["POST","/admin/v1/support/cases/{id}/resolve","Resolve"]]},
 reviews:{g:G3,label:"Reviews & Reputation",code:"ADM-08",pri:"P1",st:"api",perm:"reviews.view",
  blurb:"Moderate reviews tied to eligible completed orders. Hiding a review always requires a reason.",
  kpis:["Awaiting moderation","Reported","Hidden","Published","Appeals open"],
  cols:["Review ref","Buyer","Supplier","Completed order","Rating","Submitted","Report status","Moderation status"],
  perms:["reviews.view","reviews.moderate","reviews.restore","reviews.appeals.view"],
  api:[["GET","/admin/v1/reviews","Review queue"],["GET","/admin/v1/reviews/{id}","Review detail"],["POST","/admin/v1/reviews/{id}/moderation","Record moderation decision"],["GET","/admin/v1/reviews/{id}/history","Moderation history"]]},
 messaging:{g:G3,label:"Inquiry & Chat Hub",code:"ADM-—",pri:"P0",st:"demo",legacy:"messaging",perm:"messaging.send"},
 ads:{g:G3,label:"Ads & Promotions",code:"ADM-—",pri:"P1",st:"part",perm:"listings.feature",
  blurb:"Promotion packs, authorisation and billing reference. Revenue reporting sits in Analytics.",
  kpis:["Active promotions","Boost","Featured","Top of category","Revenue (30d)"],
  cols:["Listing","Supplier","Pack","Source","Billing reference","Started","Ends","Status"],
  perms:["listings.feature","revenue.view"],
  api:[["POST","/admin/v1/listings/{id}/promotion","Apply promotion"],["POST","/admin/v1/listings/{id}/promotion/end","End promotion"]]},

 analytics:{g:G4,label:"Analytics & Reports",code:"ADM-07",pri:"P0",st:"api",perm:"analytics.view",
  blurb:"Operational reporting on real marketplace events. GMV and recognised revenue are not claimed until commercial and payment definitions are approved.",
  kpis:["Supplier activation","Buyer usefulness","RFQ responsiveness","Quotation performance","Orders","Catalogue quality","Trust & safety","Complaints"],
  cols:["Metric","Definition","Formula","Source events","Window","Time zone","Last refresh","Data quality"],
  perms:["analytics.view","analytics.financial.view","analytics.export","analytics.definitions.manage"],
  api:[["GET","/admin/v1/analytics/overview","Executive KPI summary"],["GET","/admin/v1/analytics/rfqs","RFQ metrics"],["GET","/admin/v1/analytics/quotes","Quotation metrics"],["GET","/admin/v1/analytics/orders","Order metrics"],["GET","/admin/v1/analytics/definitions","Metric definitions"],["POST","/admin/v1/analytics/exports","Authorised export"]]},
 search:{g:G4,label:"Global Search",code:"ADM-09",pri:"P1",st:"prop",perm:"search.listings",
  blurb:"One search across users, organisations, listings, RFQs, quotations, orders, cases and verification records — scoped to the same read permission as the destination record.",
  kpis:["Searchable entities","Indexed records","Audited PII lookups"],
  cols:["Entity","Match","Reference","Permission required","Open"],
  perms:["search.users","search.organisations","search.listings","search.rfqs","search.orders","search.cases"],
  api:[["GET","/admin/v1/search?q={query}&types={types}","Permission-scoped global search"]]},
 locations:{g:G4,label:"Locations",code:"ADM-—",pri:"P1",st:"prop",perm:"organisations.view",
  blurb:"Governed district and region reference data used by RFQ destinations and delivery.",
  kpis:["Regions","Districts","Active","Deactivated"],
  cols:["Location","Type","Parent","Code","Status"],
  perms:["organisations.view"],
  api:[["GET","/admin/v1/locations","Location directory"],["PATCH","/admin/v1/locations/{id}","Governed correction"]]},
 privacy:{g:G4,label:"Data & Privacy Requests",code:"ADM-10",pri:"P1",st:"api",perm:"privacy.requests.view",
  blurb:"Access, correction, deletion and retention-review requests with identity checks and completion evidence. No request is silently marked complete.",
  kpis:["Open requests","Awaiting identity check","Due this week","Overdue","Completed"],
  cols:["Request ref","Type","User / organisation","Received","Identity verified","Privacy owner","Due","Status","Completed"],
  perms:["privacy.requests.view","privacy.requests.assign","privacy.requests.review","privacy.requests.decide","privacy.requests.complete"],
  api:[["GET","/admin/v1/privacy/requests","Request queue"],["GET","/admin/v1/privacy/requests/{id}","Request detail"],["POST","/admin/v1/privacy/requests/{id}/assign","Assign owner"],["POST","/admin/v1/privacy/requests/{id}/decision","Record decision"],["POST","/admin/v1/privacy/requests/{id}/complete","Record completion"]]},
 imports:{g:G4,label:"Bulk Catalogue Import",code:"ADM-11",pri:"P1",st:"api",perm:"catalogue.import",
  blurb:"CSV import that validates before committing and creates drafts, never auto-published listings. All-or-nothing, and retries cannot duplicate records.",
  kpis:["Imports this month","Rows accepted","Rows rejected","Awaiting commit"],
  cols:["Import ref","Operator","Uploaded","Category","Total rows","Valid","Invalid","Status"],
  perms:["catalogue.import","catalogue.import.validate","catalogue.import.commit","catalogue.import.history.view"],
  api:[["POST","/admin/v1/catalogue/imports","Start import"],["POST","/admin/v1/catalogue/imports/{id}/validate","Validate rows"],["GET","/admin/v1/catalogue/imports/{id}","Import detail"],["POST","/admin/v1/catalogue/imports/{id}/commit","Commit drafts"],["GET","/admin/v1/catalogue/imports/{id}/errors","Error report"]]},
 audit:{g:G4,label:"Security & Audit Logs",code:"ADM-—",pri:"P0",st:"part",perm:"audit.view",
  blurb:"Append-only record of every change and every refusal, with actor, reason, request reference and idempotency key.",
  kpis:["Entries today","Critical","Refusals","PII reveals"],
  cols:["Entry","Actor","Role","Action","Target","Severity","Reason","Request ref","Time"],
  perms:["audit.view","audit.export"],
  api:[["GET","/admin/v1/audit","Paginated audit log"],["POST","/admin/v1/audit/exports","Permission-controlled export"]]},
 system:{g:G4,label:"System Health & Resilience",code:"ADM-12",pri:"P1",st:"part",perm:"system.health.view",
  blurb:"Service health, performance, capacity and recovery. Recovery claims must be backed by actual restore evidence.",
  kpis:["Services up","API latency","Error rate","Failed jobs","Backup freshness","Last restore test"],
  cols:["Area","Measure","Value","Source","Measured at","Assumption"],
  perms:["system.health.view","system.capacity.view","system.incidents.view","system.recovery.view","system.operations.manage"],
  api:[["GET","/admin/v1/system/health","Service health"],["GET","/admin/v1/system/metrics","Performance metrics"],["GET","/admin/v1/system/incidents","Incident history"],["GET","/admin/v1/system/backups","Backup freshness"],["GET","/admin/v1/system/recovery","RPO / RTO and restore evidence"]]},
 settings:{g:G4,label:"Settings & Permissions",code:"ADM-—",pri:"P0",st:"demo",custom:"settings",perm:"overview.view"}
};
const ST_LABEL={demo:["Demo","sc-demo"],part:["Partial","sc-part"],api:["API pending","sc-api"],prop:["Proposed","sc-prop"]};

function buildNav(){
  const groups={};Object.entries(MODULES).forEach(([id,m])=>{(groups[m.g]=groups[m.g]||[]).push([id,m])});
  const cntId={listings:"cnt-listings",users:"cnt-users",reports:"cnt-reports",messaging:"cnt-msg"};
  $("#nav").innerHTML=[G1,G2,G3,G4].map(g=>`<div class="navgroup">${g}</div>`+groups[g].map(([id,m])=>{
    const st=ST_LABEL[m.st];
    return `<button data-view="${id}"><span class="nb"></span>${esc(m.label)}${cntId[id]?`<span class="count" id="${cntId[id]}"></span>`:`<span class="sc ${st[1]}">${st[0]}</span>`}</button>`;
  }).join("")).join("");
}

function renderModuleShell(id){
  const m=MODULES[id],v=$("#view-module"),st=ST_LABEL[m.st];
  const head=`<div class="view-head"><div>
    <div class="modhead"><span class="modcode">${m.code}</span><span class="chip-pri">${m.pri}</span><span class="chip-st ${st[1]}">${st[0]}</span></div>
    <h1>${esc(m.label)}</h1><p>${esc(m.blurb||"")}</p></div></div>`;
  if(!can(m.perm)){
    v.innerHTML=head+`<div class="panel"><div class="shell-empty"><div class="ei" style="background:var(--crit-weak);color:var(--crit)"><svg viewBox="0 0 24 24"><rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg></div>
      <b>Not available to your role</b><p>${PERMS[role].label} does not hold <code>${m.perm}</code>. UI visibility is not authorisation — the server validates every request.</p></div></div>`;
    return;
  }
  v.innerHTML=head+`
   <div class="eyebrow">Key figures</div>
   <div class="kpis">${(m.kpis||[]).map(k=>`<div class="kpi ghost"><div class="lab">${esc(k)}</div><div class="val">Not connected</div><div class="sub">awaiting Admin API</div></div>`).join("")}</div>
   <div class="eyebrow">Directory</div>
   <div class="shell-grid">
     <div class="tablewrap"><div class="tscroll"><table><thead><tr>${(m.cols||[]).map(c=>`<th>${esc(c)}</th>`).join("")}</tr></thead><tbody><tr><td colspan="${(m.cols||[]).length||1}">
       <div class="shell-empty"><div class="ei"><svg viewBox="0 0 24 24"><path d="M12 9v4m0 4h.01M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg></div>
       <b>No data source connected</b><p>This directory will list records from <code>${esc((m.api&&m.api[0]&&m.api[0][1])||"the Admin API")}</code> once the contract is approved and the endpoint is implemented. Columns above are the approved shape.</p></div>
     </td></tr></tbody></table></div>
     <div class="foot"><span>Showing 0 of 0</span><span class="sp"></span><span>Server-side pagination required</span></div></div>
     <div style="display:flex;flex-direction:column;gap:14px">
       <div class="panel"><div class="panel-h"><h3>Permissions</h3></div><div class="panel-b"><div class="permlist">${(m.perms||[]).map(p=>`<span>${esc(p)}</span>`).join("")}</div></div></div>
       <div class="panel"><div class="panel-h"><h3>Proposed API</h3><span class="hint">not yet implemented</span></div><div class="panel-b" style="padding:4px 8px"><table class="apit"><tbody>${(m.api||[]).map(([mt,p,d])=>`<tr><td class="m">${mt}</td><td><div class="p">${esc(p)}</div><div class="meta">${esc(d)}</div></td></tr>`).join("")}</tbody></table></div></div>
     </div>
   </div>`;
}

const MATRIX_CAPS=[["Overview",["Full","Full","Limited","Limited","Financial view","Read"]],
 ["RFQ inspection",["Yes","Yes","Investigations","Related cases","No by default","Aggregate"]],
 ["Quote inspection",["Yes","Yes","Investigations","Related cases","Approved scope","Aggregate"]],
 ["Order inspection",["Yes","Yes","Related cases","Related cases","Payment scope","Aggregate"]],
 ["Payment reconciliation",["Governed","No by default","No","No","Yes","No"]],
 ["Verification decisions",["Governed","Yes","Approved scope","No","No","Aggregate"]],
 ["Case assignment",["Yes","Yes","Yes","Yes","Related cases","No"]],
 ["Case resolution",["Governed","Yes","Yes","Yes","Related cases","No"]],
 ["Review moderation",["Yes","Yes","Yes","No","No","Aggregate"]],
 ["Analytics",["Full","Operations","Trust","Support","Financial","Read"]],
 ["Privacy requests",["Governed","No by default","Approved scope","No","No","No"]],
 ["Audit export",["Governed","Limited","Limited","No","Limited","No"]],
 ["Role administration",["Yes","No","No","No","No","No"]]];
function mvClass(v){return v==="Yes"||v==="Full"?"mv-yes":(v==="No"||v==="No by default"?"mv-no":(v==="Governed"?"mv-gov":"mv-lim"))}
function renderSettings(){
  const st=ST_LABEL.demo;
  $("#view-module").innerHTML=`<div class="view-head"><div>
     <div class="modhead"><span class="modcode">Section 5</span><span class="chip-pri">P0</span><span class="chip-st ${st[1]}">${st[0]}</span></div>
     <h1>Settings &amp; permissions</h1><p>The six approved roles and their capabilities. Switch the “Viewing as” role in the sidebar to see the console enforce this matrix. These are proposed capability names, to be reconciled with the repository catalogue before implementation.</p></div></div>
   <div class="eyebrow">Role &amp; permission matrix</div>
   <div class="tablewrap"><div class="tscroll"><table class="mx"><thead><tr><th>Capability</th><th>Super Admin</th><th>Operations Lead</th><th>Trust &amp; Safety</th><th>Support</th><th>Finance</th><th>Analyst</th></tr></thead>
   <tbody>${MATRIX_CAPS.map(([cap,vals])=>`<tr><td class="cap">${esc(cap)}</td>${vals.map(v=>`<td><span class="mv ${mvClass(v)}">${esc(v)}</span></td>`).join("")}</tr>`).join("")}</tbody></table></div>
   <div class="foot"><span>13 capabilities × 6 roles</span><span class="sp"></span><span>UI visibility is not authorisation</span></div></div>
   <div class="eyebrow">Sample photo credits</div><div class="panel"><div class="panel-b" style="font-size:12.5px;color:var(--fg-muted)"><p style="margin:0 0 8px">Demo product photos are from Wikimedia Commons, cropped and resized. They illustrate sample listings only.</p>${PHOTO_CREDITS.map(c=>`<div>${esc(c.subject)}: <a href="${esc(c.page)}" target="_blank" rel="noopener noreferrer">“${esc(c.title)}”</a> by ${esc(c.author)}, ${/^CC BY-SA 4\.0/.test(c.license)?`<a href="https://creativecommons.org/licenses/by-sa/4.0/" target="_blank" rel="noopener noreferrer">${esc(c.license)}</a>`:esc(c.license)}. Cropped and resized.</div>`).join("")}</div></div>
   <div class="eyebrow">Implementation status key</div>
   <div class="panel"><div class="qlist">
     ${[["Demo","sc-demo","Works here on generated sample data."],["Partial","sc-part","Some functionality exists; the complete workflow does not."],["API pending","sc-api","Needs a backend endpoint or data contract."],["Proposed","sc-prop","Specified in the gap analysis, not yet built."]].map(([l,c,d])=>`<div class="qrow"><span class="chip-st ${c}">${l}</span><div class="qt" style="margin-left:4px"><span>${d}</span></div></div>`).join("")}
   </div></div>
   <div class="panel" style="margin-top:14px"><div class="panel-b" style="font-size:12.5px;color:var(--fg-muted)">A screen is never marked <b>Integrated</b> or <b>Production approved</b> merely because its interface renders. Demo data, local reference-server results and a successful frontend build are not production acceptance evidence.</div></div>`;
}

/* ---------- nav ---------- */
const LEGACY=["overview","listings","users","reports","messaging"];
let currentView="overview";
function show(view){
  if(!MODULES[view])view="overview";
  currentView=view;const m=MODULES[view];
  LEGACY.forEach(v=>{$("#view-"+v).hidden=true;});$("#view-module").hidden=true;
  $$("#nav button").forEach(b=>b.setAttribute("aria-current",b.dataset.view===view));
  if(m.legacy){$("#view-"+m.legacy).hidden=false;
    if(m.legacy==="overview")renderOverview();else if(m.legacy==="listings")renderListings();
    else if(m.legacy==="users")renderUsers();else if(m.legacy==="reports")renderReports();else if(m.legacy==="messaging")renderMessaging();}
  else{$("#view-module").hidden=false;if(m.custom==="settings")renderSettings();else if(window.MODULE_RENDER&&MODULE_RENDER[view]&&can(m.perm))MODULE_RENDER[view]($("#view-module"),m);else renderModuleShell(view);}
  try{history.replaceState(null,"","#"+view);}catch(e){}
  $("#rail").classList.remove("on");$("#scrim").classList.remove("on");window.scrollTo(0,0);
}
function refreshCounts(){const m=metrics();const set=(id,v,alert)=>{const el=$("#"+id);if(!el)return;el.textContent=v||"";el.className="count"+(alert&&v?" alert":"");};
  set("cnt-listings",m.pendingListings);set("cnt-users",m.verifyQueue);set("cnt-reports",m.openReports,1);set("cnt-msg",m.unread);}
function buildRoles(){$("#roleSel").innerHTML=Object.entries(PERMS).map(([k,v])=>`<option value="${k}">${v.label}</option>`).join("");$("#roleSel").value=role;$("#who-name").textContent=ADMIN_NAME[role];}

document.addEventListener("click",e=>{
  const t=e.target;
  const navB=t.closest("#nav button");if(navB){show(navB.dataset.view);return;}
  if(t.closest("[data-close]")||t===$("#scrim")){closeDrawer();return;}
  const goto=t.closest("[data-goto]");if(goto){show(goto.dataset.goto);return;}
  const conv=t.closest("[data-conv]");if(conv){MSEL=conv.dataset.conv;drawInbox($("#mBody"));return;}
  const msg=t.closest("[data-msg]");if(msg&&!msg.disabled){closeDrawer();show("messaging");MSUB="inbox";if(!CONVOS[msg.dataset.msg]){const u=USERS.find(x=>x.id===msg.dataset.msg);CONVOS[u.id]={sellerId:u.id,sellerName:u.name,unread:0,messages:[]};}MSEL=msg.dataset.msg;$$("#mSeg button").forEach(x=>x.setAttribute("aria-pressed",x.dataset.s==="inbox"));drawMsgBody();return;}
  const approveC=t.closest("[data-approve]");if(approveC&&!approveC.disabled){const c=CAMPAIGNS.find(x=>x.id===approveC.dataset.approve);if(c){c.status="delivered";c.delivered=Math.round(c.recipients*0.94);c.read=Math.round(c.recipients*0.57);c.replied=Math.round(c.recipients*0.04);audit("broadcast.approve",`Approved & released "${c.name}"`,"critical","");drawCampaigns();toast("Broadcast approved & released","ok");}return;}
  const bulk=t.closest("[data-bulk]");if(bulk&&!bulk.disabled){const b=bulk.dataset.bulk;if(b==="clear"){LSEL.clear();drawListings();}else openBulkModal(b);return;}
  const rres=t.closest("[data-rresolve]");if(rres&&!rres.disabled){resolveReport(rres.dataset.rid,rres.dataset.rresolve);return;}
  const openL=t.closest("[data-open]");if(openL){openListing(openL.dataset.open);return;}
  const actB=t.closest("[data-act]");if(actB&&!actB.disabled){e.stopPropagation();doListingAction(actB.dataset.act,actB.dataset.id);return;}
  const uactB=t.closest("[data-uact]");if(uactB&&!uactB.disabled){doUserAction(uactB.dataset.uact,uactB.dataset.id);return;}
  const rev=t.closest("[data-reveal]");if(rev&&!rev.disabled){openReveal(rev.dataset.reveal);return;}
  const uo=t.closest("[data-uopen]");if(uo){openUser(uo.dataset.uopen);return;}
  const rowL=t.closest("#lBody tr[data-id]");if(rowL&&!t.closest(".rowacts")&&!t.closest(".selcol")){openListing(rowL.dataset.id);return;}
  const rowU=t.closest("#uBody tr[data-uid]");if(rowU&&!t.closest(".rowacts")){openUser(rowU.dataset.uid);return;}
});
document.addEventListener("change",e=>{const c=e.target.closest("[data-sel]");if(c){if(c.checked)LSEL.add(c.dataset.sel);else LSEL.delete(c.dataset.sel);renderBulkBar();const all=$("#lAll");if(all){const rows=LISTINGS.filter(listingMatch);all.checked=rows.length>0&&rows.every(r=>LSEL.has(r.id));}}});
document.addEventListener("keydown",e=>{if(e.key==="Escape"){closeModal();closeDrawer();}});

$("#roleSel").addEventListener("change",e=>{role=e.target.value;closeDrawer();closeModal();$("#who-name").textContent=ADMIN_NAME[role];toast("Now viewing as "+PERMS[role].label);const rb=$("#view-reports");rb&&(rb.dataset.built="");refreshCounts();if(currentView==="listings")drawListings();else if(currentView==="users")drawUsers();else if(currentView==="reports")renderReports();else if(currentView==="messaging")drawMsgBody();else if(currentView==="overview")renderOverview();else show(currentView);if(window.onRoleChange)window.onRoleChange();});
$("#menuBtn").addEventListener("click",()=>{$("#rail").classList.toggle("on");$("#scrim").classList.toggle("on");});
$("#globalSearch").addEventListener("input",e=>{const q=e.target.value;if(currentView==="listings"){LF.q=q.toLowerCase();$("#lSearch")&&($("#lSearch").value=q);drawListings();}else if(currentView==="users"){UF.q=q.toLowerCase();$("#uSearch")&&($("#uSearch").value=q);drawUsers();}});
$("#globalSearch").addEventListener("keydown",e=>{if(e.key==="Enter"&&currentView==="overview")show("listings");});
$("#globalSearch").addEventListener("input",e=>{if(currentView==="search"&&window.searchInput)window.searchInput(e.target.value);});

function setTheme(mode){try{document.documentElement.setAttribute("data-theme",mode);localStorage.setItem("luma-theme",mode);}catch(e){}updThemeIco();}
function updThemeIco(){const dark=matchMedia("(prefers-color-scheme:dark)").matches;const attr=document.documentElement.getAttribute("data-theme");const isDark=attr?attr==="dark":dark;$("#themeIco").innerHTML=isDark?'<circle cx="12" cy="12" r="4.5"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M19.1 4.9l-1.8 1.8M6.7 17.3l-1.8 1.8"/>':'<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"/>';}
$("#themeBtn").addEventListener("click",()=>{const cur=document.documentElement.getAttribute("data-theme")||(matchMedia("(prefers-color-scheme:dark)").matches?"dark":"light");setTheme(cur==="dark"?"light":"dark");});
(function initTheme(){try{const s=localStorage.getItem("luma-theme");if(s)document.documentElement.setAttribute("data-theme",s);}catch(e){}updThemeIco();})();
