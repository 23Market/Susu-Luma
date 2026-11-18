"use strict";
(async()=>{
  if(window.LIVE&&LIVE.on)await LIVE.start(); // sign-in + MFA + data load; resolves when ready
  buildRoles();
  if(window.LIVE&&LIVE.on)LIVE.afterBoot();
  buildNav();refreshCounts();
  const h=(location.hash||"").replace("#","");
  show(MODULES[h]?h:"overview");
})();
