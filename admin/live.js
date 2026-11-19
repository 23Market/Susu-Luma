"use strict";
/* Live mode: real Supabase sign-in (password + TOTP MFA), roles/permissions from the database, data loaded
   under row-level security, and privileged actions executed by SECURITY DEFINER functions.
   The browser is untrusted: everything below only *requests*; Postgres decides and audits.
   Activated only when admin/config.js contains a project URL and publishable key. */
window.LIVE = { on: false, actions: {} };
(function () {
  const cfg = window.SUSU_ADMIN_CONFIG || {};
  if (!cfg.supabaseUrl || !cfg.publishableKey) return;
  if (!window.supabase) { console.error("supabase-js failed to load"); return; }
  LIVE.on = true;
  const sb = window.supabase.createClient(cfg.supabaseUrl, cfg.publishableKey, { auth: { persistSession: true, autoRefreshToken: true } });
  LIVE.client = sb;
  const M = window.__mod;
  const sh = (id, p) => p + String(id).replace(/-/g, "").slice(0, 8).toUpperCase();
  const T = x => (x ? Date.parse(x) : null);
  const ERR = { permission_denied: "Not permitted for your role — the attempt was logged.", reason_required: "A reason of at least 8 characters is required.", checklist_incomplete: "Checklist incomplete — verify every item first.", invalid_state: "Not possible in the record's current state.", out_of_scope: "Outside your category scope — the attempt was logged.", reference_required: "A valid provider/bank reference is required.", amount_required: "Enter the amount shown in the external evidence.", scope_and_validity_required: "Scope and validity are required.", not_found: "Record not found.", already_confirmed: "Already confirmed." };

  /* ---------- sign-in gate (password → TOTP MFA → admin role) ---------- */
  const gate = html => { let g = document.getElementById("liveGate"); if (!g) { g = document.createElement("div"); g.id = "liveGate"; document.body.appendChild(g); } g.hidden = false; g.innerHTML = `<div class="gatebox"><div class="logo">Susu Luma <small>Master Admin</small></div>${html}</div>`; return g; };
  const hideGate = () => { const g = document.getElementById("liveGate"); if (g) g.hidden = true; };
  const msg = (g, t) => { const m = g.querySelector(".gmsg"); if (m) m.textContent = t || ""; };
  const form = (g, fn) => { g.querySelector("form").onsubmit = async e => { e.preventDefault(); const b = g.querySelector("button"); b.disabled = true; try { await fn(new FormData(e.target)); } catch (err) { msg(g, err.message || String(err)); } b.disabled = false; }; };

  async function step(done) {
    const { data: { session } } = await sb.auth.getSession();
    if (!session) return login(done);
    const { data: lvl } = await sb.auth.mfa.getAuthenticatorAssuranceLevel();
    if (lvl.currentLevel !== "aal2") return mfa(done);
    return profile(done);
  }
  function login(done) {
    const g = gate(`<h1>Sign in</h1><p class="muted">Staff accounts require a password and a one-time code.</p><form><label>Email<input name="email" type="email" autocomplete="username" required></label><label>Password<input name="password" type="password" autocomplete="current-password" required></label><button class="btn pri">Continue</button><p class="gmsg" role="alert"></p></form>`);
    form(g, async f => { const { error } = await sb.auth.signInWithPassword({ email: f.get("email"), password: f.get("password") }); if (error) return msg(g, "Email or password is incorrect."); await step(done); });
  }
  async function mfa(done) {
    const { data: fac } = await sb.auth.mfa.listFactors();
    const verified = (fac.totp || []).find(x => x.status === "verified");
    let factorId, extra = "";
    if (verified) factorId = verified.id;
    else {
      for (const f of (fac.all || []).filter(x => x.factor_type === "totp" && x.status !== "verified")) await sb.auth.mfa.unenroll({ factorId: f.id });
      const { data, error } = await sb.auth.mfa.enroll({ factorType: "totp", friendlyName: "Susu Luma admin" });
      if (error) { const g = gate(`<h1>MFA setup failed</h1><p class="gmsg"></p><button class="btn" id="so">Sign out</button>`); msg(g, error.message); g.querySelector("#so").onclick = signOut; return; }
      factorId = data.id; extra = `<p class="muted">Scan this QR code with an authenticator app, or enter the secret manually.</p><img alt="TOTP QR code" src="${data.totp.qr_code}" width="168" height="168"><p class="mono" style="word-break:break-all">${data.totp.secret}</p>`;
    }
    const g = gate(`<h1>${verified ? "Enter your code" : "Set up two-factor"}</h1>${extra}<form><label>6-digit code<input name="code" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" required></label><button class="btn pri">Verify</button><p class="gmsg" role="alert"></p></form><button class="btn ghost" id="so" type="button">Sign out</button>`);
    g.querySelector("#so").onclick = signOut;
    form(g, async f => {
      const { data: ch, error: e1 } = await sb.auth.mfa.challenge({ factorId }); if (e1) return msg(g, e1.message);
      const { error: e2 } = await sb.auth.mfa.verify({ factorId, challengeId: ch.id, code: f.get("code") });
      if (e2) return msg(g, "That code was not accepted."); await step(done);
    });
  }
  async function signOut() { await sb.auth.signOut(); location.reload(); }
  LIVE.signOut = signOut;
  async function profile(done) {
    const { data: me } = await sb.from("admin_users").select("user_id,role_code,display_name").maybeSingle();
    if (!me) { const g = gate(`<h1>Not an administrator</h1><p>This account has no active admin role. Ask a Super Admin to grant one.</p><button class="btn" id="so">Sign out</button>`); g.querySelector("#so").onclick = signOut; return; }
    const [r, p, s] = await Promise.all([sb.from("admin_roles").select("code,label,all_permissions").eq("code", me.role_code).single(), sb.from("admin_role_permissions").select("permission_code").eq("role_code", me.role_code), sb.from("admin_role_scopes").select("category_id").eq("role_code", me.role_code)]);
    Object.keys(PERMS).forEach(k => delete PERMS[k]);
    PERMS[me.role_code] = { label: r.data.label, all: r.data.all_permissions, perms: (p.data || []).map(x => x.permission_code), scope: (s.data || []).length ? s.data.map(x => x.category_id) : null };
    role = me.role_code; ADMIN_NAME[role] = me.display_name; LIVE.userId = me.user_id;
    gate(`<h1>Loading…</h1>`); await reload(); hideGate(); done();
  }
  LIVE.start = () => new Promise(res => step(res));

  /* ---------- load: map rows onto the shapes the modules already render ---------- */
  const fill = (a, rows) => { a.length = 0; a.push(...rows); };
  const get = async (t, cols = "*", o) => { let q = sb.from(t).select(cols); if (o) q = q.order(o.by, { ascending: !!o.asc }).limit(o.limit || 1000); const r = await q; if (r.error) console.warn(t, r.error.message); return r.data || []; };
  async function reload() {
    const [orgs, mem, lst, rfq, itm, rec, qt, ql, ord, ev, pay, pev, ver, aud, cat] = await Promise.all([get("organizations"), get("organization_memberships"), get("listings"), get("rfqs"), get("rfq_items"), get("rfq_recipients"), get("quotes"), get("quote_lines"), get("orders"), get("delivery_events"), get("payment_records"), get("payment_events"), get("admin_verification_queue"), get("audit_events", "*", { by: "id", asc: false, limit: 500 }), get("categories")]);
    const OSH = {}; orgs.forEach(o => OSH[o.id] = sh(o.id, "ORG-"));
    const so = id => OSH[id] || sh(id, "ORG-");
    const oname = id => (orgs.find(o => o.id === id) || {}).display_name || sh(id, "ORG-");

    cat.forEach(c => { CATNAME[c.id] = c.name; if (!CATS.some(x => x[0] === c.id)) CATS.push([c.id, c.name]); });
    M.TAX.cats.length = 0;
    cat.forEach(c => M.TAX.cats.push({ id: c.id, name: c.name, parent: c.parent_id ? ((cat.find(x => x.id === c.parent_id) || {}).name || "") : "", attrs: c.attributes || [], unit: c.required_unit, pre: c.pre_moderate, status: "published", draft: null }));
    M.TAX.version = 1;

    const vmap = {}; ver.forEach(v => { (vmap[v.organization_id] = vmap[v.organization_id] || []).push(v); });
    const vstat = id => { const l = (vmap[id] || []).sort((a, b) => T(b.submitted_at) - T(a.submitted_at))[0]; return !l ? "none" : l.status === "approved" ? "verified" : ["rejected", "suspended"].includes(l.status) ? "rejected" : ["expired"].includes(l.status) ? "none" : "pending"; };
    fill(USERS, orgs.map(o => ({ id: so(o.id), _id: o.id, name: o.display_name, type: o.organization_type === "supplier" ? "business" : "buyer", status: o.status === "suspended" ? "suspended" : "active", verification: o.organization_type === "supplier" ? vstat(o.id) : "none", joined: T(o.created_at), lastActive: T(o.updated_at), email: "", phone: "", area: o.district || "—", reports: 0, flags: [], consent: {}, marketingOptIn: false })));
    fill(M.ORGS, orgs.filter(o => o.organization_type === "buyer").map(o => ({ id: so(o.id), _id: o.id, name: o.display_name, sector: "—", owner: "—", district: o.district || "—", status: o.status, joined: T(o.created_at), members: mem.filter(m => m.organization_id === o.id).map(m => ({ name: sh(m.user_id, "USR-"), role: m.member_role })), invites: 0, history: [{ at: T(o.created_at), text: "Organisation created" }] })));
    const LS = { pending_review: "pending", published: "active", paused: "paused", rejected: "rejected", archived: "removed", draft: "draft" };
    fill(LISTINGS, lst.map(l => ({ id: sh(l.id, "LST-"), _id: l.id, title: l.title, unit: l.quantity_unit, cat: l.category, sellerId: so(l.organization_id), sellerName: oname(l.organization_id), price: Number(l.price_amount || 0), status: LS[l.status] || l.status, promoted: null, flags: [], reports: 0, created: T(l.created_at), views: 0 })));
    fill(REPORTS, []); fill(CAMPAIGNS, []); Object.keys(CONVOS).forEach(k => delete CONVOS[k]); fill(M.CASES, []); fill(M.REVIEWS, []); fill(M.PRIV, []);

    fill(M.VERIFS, ver.map(v => ({ id: sh(v.id, "VER-"), _id: v.id, user: so(v.organization_id), status: v.status === "pending" ? "submitted" : v.status, type: "Supplier", submitted: T(v.submitted_at), risk: "Standard", checklist: (v.checklist || []).map(c => ({ c: c.item, done: !!c.done })), reviewer: v.assigned_reviewer ? (v.assigned_reviewer === LIVE.userId ? ADMIN_NAME[role] : "Assigned reviewer") : "", evidence: v.evidence_object_paths || [], decided: T(v.reviewed_at), expires: T(v.expires_at), scope: v.verification_scope || "", history: (v.history || []).map(h => ({ at: T(h.at), text: h.text })), notes: "" })));

    const iBy = {}; itm.forEach(i => (iBy[i.rfq_id] = iBy[i.rfq_id] || []).push(i));
    const quotesByRfq = {}; qt.forEach(q => (quotesByRfq[q.rfq_id] = quotesByRfq[q.rfq_id] || []).push(q));
    const RS = r => r.status === "open" ? ((Date.now() - T(r.created_at) < 2 * 864e5) ? "new" : "awaiting") : r.status === "closed" ? "expired" : r.status === "draft" ? "new" : r.status;
    fill(M.RFQS, rfq.map(r => ({ id: sh(r.id, "RFQ-"), _id: r.id, ref: r.reference_code, buyer: so(r.buyer_organization_id), created: T(r.created_at), status: RS(r), items: (iBy[r.id] || []).map(i => ({ listingId: i.listing_id, title: i.product_title, cat: "", qty: Number(i.quantity), unit: i.quantity_unit })), dest: r.destination_district || "—", target: T(r.target_delivery_date), invites: rec.filter(x => x.rfq_id === r.id).map(x => ({ sid: so(x.supplier_organization_id), routedAt: T(x.routed_at), state: (quotesByRfq[r.id] || []).some(q => q.supplier_organization_id === x.supplier_organization_id) ? "quoted" : "no_response" })), notes: [], flagged: false, operator: "" })));
    const grp = {}; qt.forEach(q => (grp[q.rfq_id + "|" + q.supplier_organization_id] = grp[q.rfq_id + "|" + q.supplier_organization_id] || []).push(q));
    const itemOf = id => itm.find(i => i.id === id) || {};
    const totOf = q => ql.filter(l => l.quote_id === q.id).reduce((s, l) => s + Number(l.unit_price) * Number(itemOf(l.rfq_item_id).quantity || 0), 0);
    const QS = q => q.status === "submitted" ? ((q.validity_until && T(q.validity_until) < Date.now()) ? "expired" : "awaiting") : q.status;
    const ordByQuote = {}; ord.forEach(o => ordByQuote[o.accepted_quote_id] = o);
    fill(M.QUOTES, Object.values(grp).map(g => { const vs = g.sort((a, b) => a.version - b.version), q = vs[vs.length - 1]; return { id: sh(q.id, "QT-"), _id: q.id, rfq: sh(q.rfq_id, "RFQ-"), supplier: so(q.supplier_organization_id), version: q.version, versions: vs.map(v => ({ v: v.version, total: totOf(v), at: T(v.submitted_at) })), lines: ql.filter(l => l.quote_id === q.id).map(l => ({ item: itemOf(l.rfq_item_id).product_title || "", qty: Number(itemOf(l.rfq_item_id).quantity || 0), unit: l.quantity_unit, unitPrice: Number(l.unit_price) })), currency: q.currency_code, total: totOf(q), submitted: T(q.submitted_at), valid: T(q.validity_until), lead: q.lead_time_days || 0, terms: q.terms || "", status: QS(q), flagged: false, acceptedAt: ordByQuote[q.id] ? T(ordByQuote[q.id].created_at) : null }; }));
    const OS = s => s === "awaiting_seller_confirmation" ? "awaiting_confirmation" : s;
    const FUL = { ready: "ready_for_dispatch", partial_delivery: "partially_delivered" };
    const payByOrder = {}; pay.forEach(p => payByOrder[p.order_id] = p);
    fill(M.ORDERS, ord.map(o => { const snap = o.accepted_quote_snapshot || {}, es = ev.filter(e => e.order_id === o.id).sort((a, b) => T(a.created_at) - T(b.created_at)), last = es[es.length - 1], r = rfq.find(x => x.id === o.rfq_id), p = payByOrder[o.id];
      return { id: sh(o.id, "ORD-"), _id: o.id, rfq: sh(o.rfq_id, "RFQ-"), quote: sh(o.accepted_quote_id, "QT-"), buyer: so(o.buyer_organization_id), supplier: so(o.supplier_organization_id), at: T(o.created_at), currency: snap.currency_code || "SLE", total: Number(snap.total || 0), status: OS(o.status), expected: r ? T(r.target_delivery_date) : null, noteLog: [],
        events: es.map(e => ({ type: e.event_type === "ready" ? "ready_for_dispatch" : e.event_type, at: T(e.created_at), actor: "Participant", org: "", qty: Number(e.quantity || 0), unit: e.quantity_unit || "", mode: "", evid: e.evidence_object_path || "", exc: e.event_type === "exception" ? (e.note || "") : "" })),
        fulfil: o.status === "awaiting_seller_confirmation" || o.status === "cancelled" ? "none" : !last ? "none" : (FUL[last.event_type] || last.event_type), arrangement: p && p.arrangement ? p.arrangement : null, payment: o.payment_status, exception: o.status === "disputed" ? ((es.filter(e => e.event_type === "exception").pop() || {}).note || "Dispute open") : "" }; }));
    fill(M.PAYS, pay.map(p => ({ id: sh(p.id, "PAY-"), _id: p.id, order: sh(p.order_id, "ORD-"), amount: Number(p.expected_amount), currency: p.currency_code, arrangement: p.arrangement || "Not yet arranged", ref: p.provider_reference || "", status: p.status, updated: T(p.updated_at), recon: p.reconciliation, events: pev.filter(e => e.payment_id === p.id).map(e => ({ at: T(e.created_at), text: e.body, kind: e.kind })), evidence: p.evidence_object_paths || [] })));
    fill(AUDIT, aud.map(a => ({ id: "AUD-" + a.id, at: T(a.created_at), actor: a.actor_user_id ? sh(a.actor_user_id, "USR-") : "system", role: a.actor_role || "user", sev: a.severity, action: a.action, summary: a.action + (a.entity_id ? " " + sh(a.entity_id, "") : ""), reason: a.reason || "", ref: a.request_ref || "—", key: a.idempotency_key || "—" })));
  }
  LIVE.reload = reload;
  function redraw() { refreshCounts(); if (M.redraw) M.redraw(); if (currentView === "listings") drawListings(); else if (currentView === "users") drawUsers(); else if (currentView === "overview") renderOverview(); }
  LIVE.redraw = redraw;

  /* ---------- actions: ask the database; it decides, enforces and audits ---------- */
  LIVE.act = async (fn, params, okMsg) => {
    const { data, error } = await sb.rpc(fn, params);
    if (error) { toast(error.message, "bad"); return false; }
    if (data && data.ok === false) { toast(ERR[data.error] || data.error, "bad"); await reload(); redraw(); return false; }
    if (data && data.outcome === "mismatch") toast("Amount/currency mismatch — payment NOT confirmed, flagged for review", "bad");
    else toast(okMsg || "Done", "ok");
    await reload(); redraw(); return true;
  };
  LIVE.evidence = async (caseUuid, path) => {
    const { data, error } = await sb.rpc("admin_request_evidence_access", { p_case: caseUuid, p_path: path });
    if (error || !data || !data.ok) { toast((data && ERR[data.error]) || (error && error.message) || "Refused", "bad"); await reload(); redraw(); return; }
    const s = await sb.storage.from("evidence").createSignedUrl(path, 60);
    if (s.error) { toast("Could not sign a link: " + s.error.message, "bad"); return; }
    window.open(s.data.signedUrl, "_blank", "noopener"); toast("Short-lived link opened · access logged", "ok");
  };

  const F = () => M.form, R = () => M.REASON;
  LIVE.actions.verification = v => {
    const A = [], open = ["submitted", "in_review", "info_required"].includes(v.status), done = v.checklist.filter(c => c.done).length;
    const call = (p, extra, ok) => LIVE.act("admin_verification_action", Object.assign({ p_case: v._id, p_action: p }, extra), ok);
    if (v.status === "submitted") A.push({ label: "Start review", cls: "pri", perm: "verification.assign", fn: () => call("start_review", {}, "Review started") });
    if (["in_review", "info_required"].includes(v.status)) A.push({ label: "Assign to me", perm: "verification.assign", fn: () => call("assign", {}, "Assigned") });
    if (v.status === "in_review") A.push({ label: "Request information", perm: "verification.decide", fn: () => F()({ title: "Request more information", fields: [{ id: "note", label: "What is needed", type: "textarea", req: true, min: 8 }], ok: "Send request", onSubmit: f => { call("request_information", { p_reason: f.note }, "Information requested"); } }) });
    if (["in_review", "info_required"].includes(v.status)) {
      A.push({ label: "Approve…", cls: "good", perm: "verification.decide", fn: () => { if (done < v.checklist.length) { toast(`Checklist incomplete (${done}/${v.checklist.length}) — verify every item first.`, "bad"); return; } F()({ title: "Approve verification", intro: "Scoped and time-limited. Confirms evidence reviewed — not any product or transaction.", fields: [{ id: "scope", label: "Scope", type: "select", options: ["Business registration", "Registration + premises", "Registration + premises + financial account"] }, { id: "months", label: "Valid for", type: "select", options: [["6", "6 months"], ["12", "12 months"], ["24", "24 months"]] }, R()], ok: "Approve", onSubmit: f => { call("approve", { p_scope: f.scope, p_valid_months: +f.months, p_reason: f.reason }, "Verified"); } }); } });
      A.push({ label: "Reject…", cls: "danger", perm: "verification.decide", fn: () => F()({ title: "Reject verification", fields: [{ id: "code", label: "Reason code", type: "select", options: ["Documents unreadable", "Registration not found", "Identity mismatch", "Insufficient evidence", "Other"] }, R()], ok: "Reject", danger: true, onSubmit: f => { call("reject", { p_reason: f.code + " — " + f.reason }, "Rejected"); } }) });
    }
    if (v.status === "approved") A.push({ label: "Suspend…", cls: "danger", perm: "verification.suspend", fn: () => F()({ title: "Suspend verification", fields: [R()], ok: "Suspend", danger: true, onSubmit: f => { call("suspend", { p_reason: f.reason }, "Suspended"); } }) });
    if (["rejected", "suspended", "expired"].includes(v.status)) A.push({ label: "Reopen review", perm: "verification.assign", fn: () => call("reopen", {}, "Reopened") });
    return A;
  };
  LIVE.actions.payments = p => [{ label: "Reconcile…", cls: "pri", perm: "payments.reconcile", fn: () => F()({ title: "Reconcile " + p.id, intro: `Expected <b>${p.currency} ${Math.round(p.amount).toLocaleString("en-US")}</b>. Confirmation needs a provider/bank reference and an exactly matching amount and currency. The database decides.`, fields: [{ id: "dec", label: "Decision", type: "select", options: [["confirm", "Confirm — external evidence matches"], ["failed", "Record as failed"], ["reversed", "Record as reversed"]] }, { id: "amt", label: "Amount per external evidence" }, { id: "cur", label: "Currency per evidence", type: "select", options: ["SLE", "USD"] }, { id: "ref", label: "Provider / bank reference (required to confirm)" }, R()], ok: "Record decision", onSubmit: f => { LIVE.act("admin_reconcile_payment", { p_payment: p._id, p_decision: f.dec, p_amount: f.amt ? Number(f.amt.replace(/,/g, "")) : null, p_currency: f.cur, p_reference: f.ref || null, p_reason: f.reason }, "Recorded"); } }) }];
  LIVE.actions.orders = o => { const A = []; const PAY = M.PAYS.find(p => p.order === o.id);
    if (PAY) A.push({ label: "Open payment", perm: "payments.view", fn: () => M.jump("payments", PAY.id) });
    if (!["disputed", "cancelled", "awaiting_confirmation"].includes(o.status)) A.push({ label: "Open dispute…", cls: "danger", perm: "orders.investigate", fn: () => F()({ title: "Open dispute on " + o.id, intro: "Fulfilment and payment statuses are unchanged by a dispute.", fields: [R()], ok: "Open dispute", danger: true, onSubmit: f => { LIVE.act("admin_order_action", { p_order: o._id, p_action: "open_dispute", p_outcome: null, p_reason: f.reason }, "Dispute opened"); } }) });
    if (o.status === "disputed") A.push({ label: "Resolve dispute…", cls: "good", perm: "orders.investigate", fn: () => F()({ title: "Resolve dispute on " + o.id, fields: [{ id: "to", label: "Outcome", type: "select", options: [["in_fulfilment", "Resume fulfilment"], ["delivered", "Confirm delivered"], ["cancelled", "Cancel order"]] }, R()], ok: "Resolve", onSubmit: f => { LIVE.act("admin_order_action", { p_order: o._id, p_action: "resolve_dispute", p_outcome: f.to, p_reason: f.reason }, "Dispute resolved"); } }) });
    return A; };

  LIVE.afterBoot = () => {
    const sel = document.getElementById("roleSel"); if (sel) sel.disabled = true;
    const lab = document.querySelector('label[for="roleSel"]'); if (lab) lab.textContent = "Your role";
    const pill = document.querySelector(".env-pill"); if (pill) { pill.textContent = "Live"; pill.title = "Connected to " + cfg.supabaseUrl; pill.classList.add("live"); }
    const who = document.getElementById("who-name"); if (who && who.parentElement && !document.getElementById("so-live")) { const b = document.createElement("button"); b.id = "so-live"; b.className = "btn sm"; b.textContent = "Sign out"; b.onclick = signOut; who.parentElement.appendChild(b); }
    // Modules with no database backing yet show the honest "not connected" shell instead of demo data.
    ["cases", "reviews", "privacy", "imports", "system", "analytics", "locations", "ads"].forEach(id => { if (window.MODULE_RENDER) delete MODULE_RENDER[id]; if (MODULES[id]) MODULES[id].st = "api"; });
    ["reports", "messaging"].forEach(id => { const m = MODULES[id]; delete m.legacy; m.st = "api"; m.blurb = "Not connected to the database yet in live mode."; m.kpis = m.kpis || ["Open"]; m.cols = m.cols || ["Item"]; m.perms = m.perms || [m.perm]; m.api = m.api || []; });
    NEEDS_REASON.pause = 1; NEEDS_REASON.restore = 1;
    buildNav(); refreshCounts();
  };

  // The demo overview contains invented figures (enquiries, system status, alerts); replace them with real ones.
  const prevExtra = window.overviewExtra;
  window.overviewExtra = () => {
    if (prevExtra) prevExtra();
    const v = document.getElementById("view-overview"); if (!v) return;
    v.querySelectorAll(".panel-h h3").forEach(h => { if (h.textContent === "System status") h.closest(".panel").remove(); });
    v.querySelectorAll(".kpi").forEach(k => { const l = k.querySelector(".lab"); if (l && l.textContent === "New enquiries") { l.textContent = "Open RFQs"; k.querySelector(".val").textContent = M.RFQS.filter(r => ["new", "awaiting"].includes(r.status)).length; k.querySelector(".sub").textContent = "awaiting a quotation"; } });
    const al = document.getElementById("alerts");
    if (al) { const pend = LISTINGS.filter(l => l.status === "pending").length, ver = M.VERIFS.filter(x => ["submitted", "in_review", "info_required"].includes(x.status)).length, dis = M.ORDERS.filter(o => o.status === "disputed").length;
      const rows = [[pend, "Listings awaiting review", "listings"], [ver, "Verification dossiers open", "verification"], [dis, "Disputed orders", "orders"]].filter(r => r[0]);
      al.innerHTML = rows.length ? rows.map(([n, t, go]) => `<div class="qrow" data-goto="${go}" role="button" tabindex="0"><div class="qt"><b>${n} · ${t}</b><span>from the database</span></div><span class="go">›</span></div>`).join("") : '<div class="qrow"><div class="qt"><b>No alerts</b><span>nothing needs attention</span></div></div>'; }
  };
})();
