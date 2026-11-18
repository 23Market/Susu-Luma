"use strict";
buildRoles();buildNav();refreshCounts();
const h=(location.hash||"").replace("#","");
show(MODULES[h]?h:"overview");
