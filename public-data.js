// 當 admin-config.js 有 Supabase 設定後，粉絲網站改為讀取線上行程與簡介。
(async function(){
  const cfg=window.NAIGUO_SUPABASE||{};
  if(!cfg.url||!cfg.anonKey||!window.supabase)return;
  const db=window.supabase.createClient(cfg.url,cfg.anonKey);
  try{
    const {data:events,error}=await db.from('stream_events').select('id,event_date,event_time,title,description,is_published').eq('is_published',true).order('event_date',{ascending:true});
    if(error)throw error;
    renderEvents(events||[]);
  }catch(error){console.warn('奶鍋行程資料暫時無法載入',error)}
  try{
    const {data,error}=await db.from('site_settings').select('*').eq('id','main').maybeSingle();
    if(error)throw error;
    if(data)renderSettings(data);
  }catch(error){console.warn('奶鍋簡介設定暫時無法載入',error)}
  function renderEvents(events){
    const title=document.querySelector('#calendar .card-title strong');
    const grid=document.getElementById('calendar-grid');
    const special=document.querySelector('.special-event');
    if(!title||!grid)return;
    let year=2026,month=9;
    function draw(){
      title.textContent=`${year} 年 ${month+1} 月`;
      const first=new Date(year,month,1).getDay(),count=new Date(year,month+1,0).getDate();
      const weekdays=['日','一','二','三','四','五','六'];
      const monthEvents=events.filter(e=>{const d=new Date(`${e.event_date}T00:00:00`);return d.getFullYear()===year&&d.getMonth()===month});
      const byDay=new Map(monthEvents.map(e=>[Number(e.event_date.slice(8,10)),e]));
      grid.innerHTML=weekdays.map(d=>`<div class="weekday">${d}</div>`).join('')+Array.from({length:first},()=>'<div class="day dim"></div>').join('')+Array.from({length:count},(_,i)=>{const d=i+1,weekday=new Date(year,month,d).getDay(),event=byDay.get(d),live=weekday>=1&&weekday<=5||Boolean(event);return `<div class="day ${live?'marked':''} ${event?'special':''}">${d}${event?`<small>${escapeHtml(event.title)}</small>`:''}</div>`}).join('');
      if(special){special.innerHTML=monthEvents.length?monthEvents.map(e=>`<span>🎃</span><div><strong>${String(e.event_date).slice(5).replace('-','/')}・${escapeHtml(e.title)}</strong><small>${escapeHtml((e.event_time||'21:00').slice(0,5))} 開播${e.description?'，'+escapeHtml(e.description):''}</small></div><b>特別直播</b>`).join(''):'<span>✧</span><div><strong>本月尚未公布特別直播</strong><small>每週一至週五晚上 21:00 固定開播</small></div>'}
    }
    document.querySelectorAll('#calendar [data-month]').forEach(nav=>nav.onclick=()=>{month+=Number(nav.dataset.month);if(month<0){month=11;year--}if(month>11){month=0;year++}draw()});
    draw();
  }
  function renderSettings(s){
    const profile=document.querySelector('#profile .hero-copy');
    if(profile){const eyebrow=profile.querySelector('.eyebrow'),bio=profile.querySelector('p');if(eyebrow)eyebrow.textContent=`✿ 嗨，我是${s.profile_name||'奶鍋'}`;if(bio&&s.bio)bio.textContent=s.bio}
    const tagline=document.querySelector('.side .tagline');if(tagline&&s.profile_name)tagline.textContent=`${s.profile_name}的秘密基地`;
    const socials=document.querySelector('#profile .grid .card:last-child p');
    if(socials&&s.social_url){let url;try{url=new URL(s.social_url)}catch{}if(url&&['http:','https:'].includes(url.protocol))socials.innerHTML=`${escapeHtml(s.stream_label||'直播')}　・　<a href="${url.href}" target="_blank" rel="noopener noreferrer">前往奶鍋社群 ↗</a>`}
  }
  function escapeHtml(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
})();
