// Susu Luma operations console — front-end prototype. State lives in localStorage; no backend, no auth.
(() => {
  'use strict';
  const KEY = 'susuluma.admin.v1', SESSION = 'susuluma.admin.session';
  const $ = (s, r = document) => r.querySelector(s);
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const fmtDate = (iso) => iso ? new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC' }) : '—';
  const fmtDT = (iso) => iso ? new Date(iso).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'UTC' }) + ' UTC' : '—';
  const money = (n, cur) => `${cur} ${Number(n).toLocaleString('en-GB')}`;
  const label = (s) => String(s).replace(/_/g, ' ');

  let db, me = null, uid = 0;
  const load = () => { try { const raw = localStorage.getItem(KEY); if (raw) { const p = JSON.parse(raw); if (p.version === 1) return p; } } catch (_) {} return SEED(); };
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(db)); } catch (_) {} };
  const nid = (p) => `${p}${Date.now().toString(36)}${(uid++).toString(36)}`;
  const org = (id) => db.orgs.find((o) => o.id === id) || { display_name: 'Unknown', district: '' };
  const can = (perm) => ({ admin: ['verify', 'listings', 'orders', 'payments', 'tickets', 'rfqs', 'settings'], reviewer: ['verify', 'listings'], support: ['tickets'] }[me?.role] || []).includes(perm);

  function audit(action, entity, reason = '') { db.audit.unshift({ id: nid('a'), at: new Date().toISOString(), actor: me.name, action, entity, reason }); save(); }
  function toast(msg, bad) { const t = document.createElement('div'); t.className = 'toast' + (bad ? ' bad' : ''); t.textContent = msg; t.setAttribute('role', 'status'); $('#toasts').append(t); setTimeout(() => t.remove(), 3500); }

  // ---------- modal prompt ----------
  function ask({ title, intro = '', fields = [], confirm = 'Confirm', danger = false }) {
    return new Promise((resolve) => {
      const dlg = document.createElement('dialog');
      dlg.innerHTML = `<form method="dialog"><h3>${esc(title)}</h3><p class="muted">${esc(intro)}</p>${fields.map((f) => `<label>${esc(f.label)}${f.required ? ' *' : ''}${f.type === 'textarea' ? `<textarea name="${f.name}" rows="3" ${f.required ? 'required' : ''} minlength="${f.min || 0}" placeholder="${esc(f.placeholder || '')}"></textarea>` : f.type === 'select' ? `<select name="${f.name}">${f.options.map((o) => `<option>${esc(o)}</option>`).join('')}</select>` : `<input name="${f.name}" type="${f.type || 'text'}" value="${esc(f.value || '')}" ${f.required ? 'required' : ''} placeholder="${esc(f.placeholder || '')}">`}</label>`).join('')}<div class="row end"><button type="button" class="btn ghost" data-c>Cancel</button><button class="btn ${danger ? 'danger' : 'primary'}" value="ok">${esc(confirm)}</button></div></form>`;
      document.body.append(dlg);
      const finish = (v) => { dlg.close(); dlg.remove(); resolve(v); };
      $('[data-c]', dlg).onclick = () => finish(null);
      dlg.addEventListener('cancel', (e) => { e.preventDefault(); finish(null); });
      $('form', dlg).onsubmit = (e) => { e.preventDefault(); const fd = new FormData(e.target); finish(Object.fromEntries(fd.entries())); };
      dlg.showModal();
    });
  }
  const reasonField = { name: 'reason', label: 'Reason (recorded in the audit log)', type: 'textarea', required: true, min: 8, placeholder: 'At least 8 characters' };

  // ---------- UI helpers ----------
  const badge = (s) => `<span class="badge b-${esc(s)}">${esc(label(s))}</span>`;
  const perm = (p, html, why = 'Your role cannot perform this action') => can(p) ? html : html.replace('<button', `<button disabled title="${why}"`);
  const table = (head, rows, empty = 'Nothing to show') => rows.length ? `<div class="tw"><table><thead><tr>${head.map((h) => `<th>${h}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>` : `<p class="empty">${empty}</p>`;
  const kpi = (n, l, href, tone = '') => `<a class="kpi ${tone}" href="${href}"><b>${n}</b><span>${l}</span></a>`;
  const filters = (key, opts, cur) => `<div class="chips" role="group" aria-label="Filter">${opts.map((o) => `<button class="chip ${cur === o ? 'on' : ''}" data-filter="${key}" data-v="${o}">${esc(label(o))}</button>`).join('')}</div>`;
  const ui = { verify: 'all', listings: 'all', orders: 'all', rfqs: 'all', tickets: 'all', q: '', auditQ: '' };

  // ---------- pages ----------
  const pages = {};

  pages.dashboard = () => {
    const pendV = db.verifications.filter((v) => ['pending', 'in_review'].includes(v.status)).length;
    const pendL = db.listings.filter((l) => l.status === 'pending_review').length;
    const disp = db.orders.filter((o) => o.status === 'disputed').length;
    const payRev = db.orders.filter((o) => o.payment === 'pending_unverified' && o.status !== 'cancelled').length;
    const openT = db.tickets.filter((t) => t.status !== 'resolved').length;
    return `<h1>Overview</h1>
    <div class="kpis">${kpi(pendV, 'Verification cases awaiting decision', '#verification', pendV ? 'warn' : '')}${kpi(pendL, 'Listings awaiting review', '#listings', pendL ? 'warn' : '')}${kpi(openT, 'Open support cases', '#support')}${kpi(disp, 'Disputed orders', '#orders', disp ? 'bad' : '')}${kpi(payRev, 'Orders with payment unverified', '#orders')}${kpi(db.orgs.length, 'Organisations', '#orgs')}</div>
    <div class="grid2"><section class="card"><h2>Recent privileged actions</h2>${table(['When', 'Actor', 'Action', 'Entity'], db.audit.slice(0, 6).map((a) => `<tr><td class="nw">${fmtDT(a.at)}</td><td>${esc(a.actor)}</td><td>${esc(a.action)}</td><td>${esc(a.entity)}</td></tr>`), 'No actions yet')}<a href="#audit">View full audit log →</a></section>
    <section class="card"><h2>Marketplace funnel</h2><ul class="funnel">${[['RFQs submitted', db.rfqs.length], ['RFQs with quotes', db.rfqs.filter((r) => db.quotes.some((q) => q.rfq === r.id)).length], ['Quotes accepted', db.quotes.filter((q) => q.status === 'accepted').length], ['Orders delivered', db.orders.filter((o) => o.status === 'delivered').length]].map(([l, n]) => `<li><span>${l}</span><b>${n}</b></li>`).join('')}</ul>
    <p class="note">Sample data only. Payment settlement is outside the platform: payment status stays <em>pending unverified</em> unless external evidence is recorded by an administrator.</p></section></div>`;
  };

  pages.verification = () => {
    const rows = db.verifications.filter((v) => ui.verify === 'all' || v.status === ui.verify).map((v) => `<tr><td><a href="#verification/${v.id}">${esc(org(v.org).display_name)}</a></td><td>${badge(v.status)}</td><td>${esc(org(v.org).district)}</td><td>${fmtDate(v.submitted_at)}</td><td>${esc(v.reviewer || '—')}</td><td>${v.evidence.length} file(s)</td></tr>`);
    return `<h1>Supplier verification</h1><p class="muted">Approval is scoped, reasoned and time-limited. A "verified" badge never implies endorsement of any product or guarantee of performance.</p>${filters('verify', ['all', 'pending', 'in_review', 'approved', 'rejected', 'expired'], ui.verify)}${table(['Supplier', 'Status', 'District', 'Submitted', 'Reviewer', 'Evidence'], rows, 'No cases match this filter')}`;
  };
  pages['verification/:id'] = (id) => {
    const v = db.verifications.find((x) => x.id === id); if (!v) return notFound();
    const o = org(v.org), open = ['pending', 'in_review'].includes(v.status);
    return `<a href="#verification">← All cases</a><h1>${esc(o.display_name)} ${badge(v.status)}</h1>
    <div class="grid2"><section class="card"><h2>Organisation</h2><dl><dt>Legal name</dt><dd>${esc(o.legal_name)}</dd><dt>Location</dt><dd>${esc(o.locality)}, ${esc(o.district)}</dd><dt>Registered on platform</dt><dd>${fmtDate(o.created_at)}</dd><dt>Submitted</dt><dd>${fmtDT(v.submitted_at)}</dd></dl></section>
    <section class="card"><h2>Evidence (private storage)</h2><ul class="files">${v.evidence.map((f) => `<li>📄 ${esc(f)} <button class="btn ghost sm" data-act="view-evidence" data-id="${esc(f)}">Open signed link</button></li>`).join('')}</ul><p class="note">Production: short-lived signed URLs issued after server-side authorisation and access logging.</p></section></div>
    <section class="card"><h2>Decision</h2>${open ? `<div class="row">${v.status === 'pending' ? perm('verify', `<button class="btn" data-act="v-start" data-id="${v.id}">Start review (assign to me)</button>`) : ''}${perm('verify', `<button class="btn primary" data-act="v-approve" data-id="${v.id}">Approve…</button>`)}${perm('verify', `<button class="btn danger" data-act="v-reject" data-id="${v.id}">Reject…</button>`)}</div>` : `<dl><dt>Reviewer</dt><dd>${esc(v.reviewer)}</dd><dt>Scope</dt><dd>${esc(v.scope || '—')}</dd><dt>Reason</dt><dd>${esc(v.reason)}</dd><dt>Reviewed</dt><dd>${fmtDT(v.reviewed_at)}</dd><dt>Expires</dt><dd>${fmtDate(v.expires_at)}</dd></dl>`}</section>`;
  };

  const flagged = (l) => db.settings.prohibited.find((p) => `${l.title}`.toLowerCase().includes(p.toLowerCase()));
  pages.listings = () => {
    const rows = db.listings.filter((l) => ui.listings === 'all' || l.status === ui.listings).filter((l) => !ui.q || `${l.title} ${org(l.org).display_name}`.toLowerCase().includes(ui.q.toLowerCase())).map((l) => {
      const f = flagged(l);
      const acts = l.status === 'pending_review' ? `${perm('listings', `<button class="btn sm primary" data-act="l-approve" data-id="${l.id}">Approve</button>`)} ${perm('listings', `<button class="btn sm danger" data-act="l-reject" data-id="${l.id}">Reject…</button>`)}` : l.status === 'published' ? perm('listings', `<button class="btn sm" data-act="l-pause" data-id="${l.id}">Pause…</button>`) : l.status === 'paused' ? perm('listings', `<button class="btn sm" data-act="l-resume" data-id="${l.id}">Republish</button>`) : '';
      return `<tr><td><b>${esc(l.title)}</b>${f ? `<div class="flag">⚠ Matches prohibited term “${esc(f)}”</div>` : ''}</td><td>${esc(org(l.org).display_name)}${org(l.org).verified ? '' : ''}</td><td>${esc(l.category)}</td><td>${l.price_mode === 'quote_only' ? 'Quote only' : `${money(l.price, l.currency)} / ${esc(l.unit)} <small>(${esc(l.price_mode)})</small>`}</td><td>${badge(l.status)}</td><td class="act">${acts}</td></tr>`;
    });
    return `<h1>Listing moderation</h1><div class="row"><input class="search" type="search" placeholder="Search listings or suppliers" value="${esc(ui.q)}" data-search="q" aria-label="Search">${filters('listings', ['all', 'pending_review', 'published', 'paused', 'rejected'], ui.listings)}</div>${table(['Listing', 'Supplier', 'Category', 'Price', 'Status', ''], rows, 'No listings match')}<p class="note">Prohibited-goods terms are configured under Settings and are a screening aid only — a human decision is always required.</p>`;
  };

  pages.rfqs = () => {
    const rows = db.rfqs.filter((r) => ui.rfqs === 'all' || r.status === ui.rfqs).map((r) => `<tr><td><a href="#rfqs/${r.id}">${esc(r.ref)}</a></td><td>${esc(org(r.buyer).display_name)}</td><td>${r.items.map((i) => `${esc(i.title)} × ${i.qty} ${esc(i.unit)}`).join('<br>')}</td><td>${badge(r.status)}</td><td>${db.quotes.filter((q) => q.rfq === r.id).length}</td><td>${fmtDate(r.submitted_at)}</td></tr>`);
    return `<h1>RFQs &amp; quotes</h1>${filters('rfqs', ['all', 'open', 'quoted', 'accepted', 'closed', 'cancelled'], ui.rfqs)}${table(['Reference', 'Buyer', 'Items', 'Status', 'Quotes', 'Submitted'], rows, 'No RFQs match')}`;
  };
  pages['rfqs/:id'] = (id) => {
    const r = db.rfqs.find((x) => x.id === id); if (!r) return notFound();
    const qs = db.quotes.filter((q) => q.rfq === r.id);
    return `<a href="#rfqs">← All RFQs</a><h1>${esc(r.ref)} ${badge(r.status)}</h1><div class="grid2"><section class="card"><h2>Request</h2><dl><dt>Buyer</dt><dd>${esc(org(r.buyer).display_name)}</dd><dt>Destination</dt><dd>${esc(r.district)}</dd><dt>Target delivery</dt><dd>${esc(r.target)}</dd><dt>Notes</dt><dd>${esc(r.notes || '—')}</dd><dt>Routed to</dt><dd>${r.recipients.map((x) => esc(org(x).display_name)).join(', ')}</dd></dl>${table(['Item', 'Quantity', 'Unit'], r.items.map((i) => `<tr><td>${esc(i.title)}</td><td>${i.qty}</td><td>${esc(i.unit)}</td></tr>`))}</section>
    <section class="card"><h2>Quotes</h2>${table(['Supplier', 'v', 'Total', 'Lead time', 'Status'], qs.map((q) => `<tr><td>${esc(org(q.supplier).display_name)}</td><td>${q.version}</td><td>${money(q.total, q.currency)}</td><td>${q.lead_days} d</td><td>${badge(q.status)}</td></tr>`), 'No quotes yet')}${['open', 'quoted'].includes(r.status) ? perm('rfqs', `<button class="btn danger" data-act="r-close" data-id="${r.id}">Close RFQ (policy)…</button>`) : ''}</section></div>`;
  };

  const NEXT = { awaiting_seller_confirmation: [], confirmed: [], in_fulfilment: [], partially_delivered: [], delivered: [], disputed: ['in_fulfilment', 'delivered', 'cancelled'], cancelled: [] };
  pages.orders = () => {
    const rows = db.orders.filter((o) => ui.orders === 'all' || o.status === ui.orders).map((o) => `<tr><td><a href="#orders/${o.id}">${esc(o.ref)}</a></td><td>${esc(org(o.buyer).display_name)} ⇄ ${esc(org(o.supplier).display_name)}</td><td>${badge(o.status)}</td><td>${badge(o.payment)}</td><td>${fmtDate(o.created_at)}</td></tr>`);
    return `<h1>Orders</h1>${filters('orders', ['all', 'awaiting_seller_confirmation', 'in_fulfilment', 'delivered', 'disputed', 'cancelled'], ui.orders)}${table(['Order', 'Parties', 'Status', 'Payment', 'Created'], rows, 'No orders match')}`;
  };
  pages['orders/:id'] = (id) => {
    const o = db.orders.find((x) => x.id === id); if (!o) return notFound();
    const q = db.quotes.find((x) => x.id === o.quote);
    const canDispute = !['disputed', 'cancelled'].includes(o.status);
    return `<a href="#orders">← All orders</a><h1>${esc(o.ref)} ${badge(o.status)}</h1><div class="grid2"><section class="card"><h2>Accepted quote snapshot</h2><dl><dt>Buyer</dt><dd>${esc(org(o.buyer).display_name)}</dd><dt>Supplier</dt><dd>${esc(org(o.supplier).display_name)}</dd><dt>Total</dt><dd>${money(q.total, q.currency)} <small>(explicit currency, no conversion)</small></dd><dt>Lead time</dt><dd>${q.lead_days} days</dd><dt>Terms</dt><dd>${esc(q.terms || '—')}</dd><dt>Exclusions</dt><dd>${esc(q.exclusions || '—')}</dd></dl></section>
    <section class="card"><h2>Payment status ${badge(o.payment)}</h2><p class="muted">Payments happen outside Susu Luma. Status can only become <em>externally confirmed</em> with a recorded evidence reference from an approved source.</p>${o.payment_evidence ? `<p>Evidence: <b>${esc(o.payment_evidence)}</b></p>` : ''}<div class="row">${o.payment !== 'externally_confirmed' ? perm('payments', `<button class="btn primary" data-act="o-pay-confirm" data-id="${o.id}">Record external confirmation…</button>`) : ''}${o.payment === 'pending_unverified' ? perm('payments', `<button class="btn" data-act="o-pay-review" data-id="${o.id}">Flag under review…</button>`) : ''}</div></section></div>
    <section class="card"><h2>Delivery timeline</h2>${o.events.length ? `<ol class="timeline">${o.events.map((e) => `<li><b>${esc(label(e.type))}</b> <small>${fmtDT(e.at)}</small><div>${esc(e.note)}</div></li>`).join('')}</ol>` : '<p class="empty">No delivery events yet</p>'}</section>
    <section class="card"><h2>Dispute handling</h2><div class="row">${canDispute ? perm('orders', `<button class="btn danger" data-act="o-dispute" data-id="${o.id}">Open dispute…</button>`) : ''}${NEXT[o.status].map((n) => perm('orders', `<button class="btn" data-act="o-resolve" data-id="${o.id}" data-to="${n}">Resolve → ${label(n)}…</button>`)).join('')}${!canDispute && !NEXT[o.status].length ? '<span class="muted">No admin actions available in this state.</span>' : ''}</div></section>`;
  };

  pages.orgs = () => `<h1>Organisations</h1>${table(['Name', 'Type', 'Location', 'Verification', 'Joined'], db.orgs.map((o) => { const v = db.verifications.find((x) => x.org === o.id); return `<tr><td><b>${esc(o.display_name)}</b><div class="muted">${esc(o.legal_name)}</div></td><td>${esc(o.type)}</td><td>${esc(o.locality)}, ${esc(o.district)}</td><td>${o.type === 'supplier' ? (v ? `<a href="#verification/${v.id}">${badge(v.status)}</a>` : badge('pending')) : '—'}</td><td>${fmtDate(o.created_at)}</td></tr>`; }))}`;

  pages.support = () => {
    const rows = db.tickets.filter((t) => ui.tickets === 'all' || t.status === ui.tickets).map((t) => `<tr><td><a href="#support/${t.id}">${esc(t.subject)}</a></td><td>${esc(org(t.org).display_name)}</td><td>${badge(t.priority)}</td><td>${badge(t.status)}</td><td>${esc(t.assignee || 'Unassigned')}</td><td>${fmtDate(t.created_at)}</td></tr>`);
    return `<h1>Support &amp; reports</h1>${filters('tickets', ['all', 'open', 'in_progress', 'resolved'], ui.tickets)}${table(['Subject', 'From', 'Priority', 'Status', 'Assignee', 'Opened'], rows, 'No cases match')}`;
  };
  pages['support/:id'] = (id) => {
    const t = db.tickets.find((x) => x.id === id); if (!t) return notFound();
    return `<a href="#support">← All cases</a><h1>${esc(t.subject)} ${badge(t.status)}</h1><div class="grid2"><section class="card"><h2>Details</h2><dl><dt>From</dt><dd>${esc(org(t.org).display_name)}</dd><dt>Priority</dt><dd>${badge(t.priority)}</dd><dt>Assignee</dt><dd>${esc(t.assignee || 'Unassigned')}</dd><dt>Linked order</dt><dd>${t.order ? `<a href="#orders/${t.order}">${esc(db.orders.find((o) => o.id === t.order)?.ref)}</a>` : '—'}</dd></dl><div class="row">${t.assignee !== me.name && t.status !== 'resolved' ? perm('tickets', `<button class="btn" data-act="t-assign" data-id="${t.id}">Assign to me</button>`) : ''}${t.status !== 'resolved' ? perm('tickets', `<button class="btn primary" data-act="t-resolve" data-id="${t.id}">Resolve…</button>`) : perm('tickets', `<button class="btn" data-act="t-reopen" data-id="${t.id}">Reopen</button>`)}</div></section>
    <section class="card"><h2>Case notes</h2>${t.notes.length ? `<ul class="notes">${t.notes.map((n) => `<li><b>${esc(n.by)}</b> <small>${fmtDT(n.at)}</small><div>${esc(n.text)}</div></li>`).join('')}</ul>` : '<p class="empty">No notes</p>'}${perm('tickets', `<button class="btn" data-act="t-note" data-id="${t.id}">Add note…</button>`)}</section></div>`;
  };

  pages.audit = () => {
    const rows = db.audit.filter((a) => !ui.auditQ || JSON.stringify(a).toLowerCase().includes(ui.auditQ.toLowerCase())).map((a) => `<tr><td class="nw">${fmtDT(a.at)}</td><td>${esc(a.actor)}</td><td><code>${esc(a.action)}</code></td><td>${esc(a.entity)}</td><td>${esc(a.reason || '—')}</td></tr>`);
    return `<h1>Audit log</h1><p class="muted">Append-only in this prototype: entries cannot be edited or deleted from the console.</p><div class="row"><input class="search" type="search" placeholder="Filter log" value="${esc(ui.auditQ)}" data-search="auditQ" aria-label="Filter audit log"><button class="btn" data-act="audit-csv">Export CSV</button></div>${table(['When', 'Actor', 'Action', 'Entity', 'Reason'], rows, 'No matching entries')}`;
  };

  pages.settings = () => `<h1>Settings</h1><div class="grid2"><section class="card"><h2>Categories</h2><div class="chips">${db.settings.categories.map((c) => `<span class="tag">${esc(c)} ${can('settings') ? `<button aria-label="Remove ${esc(c)}" data-act="cat-del" data-id="${esc(c)}">×</button>` : ''}</span>`).join('')}</div>${perm('settings', '<button class="btn" data-act="cat-add">Add category…</button>')}</section>
    <section class="card"><h2>Prohibited-goods screening terms</h2><p class="muted">Validate the list with local counsel before pilot.</p><div class="chips">${db.settings.prohibited.map((c) => `<span class="tag">${esc(c)} ${can('settings') ? `<button aria-label="Remove ${esc(c)}" data-act="pro-del" data-id="${esc(c)}">×</button>` : ''}</span>`).join('')}</div>${perm('settings', '<button class="btn" data-act="pro-add">Add term…</button>')}</section></div>
    <section class="card"><h2>Prototype data</h2><p class="muted">All data is stored only in this browser.</p><button class="btn danger" data-act="reset">Reset sample data</button></section>`;

  const notFound = () => '<h1>Not found</h1><p><a href="#dashboard">Back to overview</a></p>';

  // ---------- actions ----------
  const actions = {
    async 'view-evidence'(id) { toast(`Signed link for ${id} would be issued and logged here (prototype).`); audit('evidence.view', id, 'Opened evidence (simulated)'); render(); },
    async 'v-start'(id) { const v = db.verifications.find((x) => x.id === id); v.status = 'in_review'; v.reviewer = me.name; audit('verification.start_review', id); toast('Review started'); },
    async 'v-approve'(id) {
      const f = await ask({ title: 'Approve supplier verification', intro: 'Approval is limited to the stated scope and expires on the date below.', confirm: 'Approve', fields: [{ name: 'scope', label: 'Verification scope', required: true, placeholder: 'e.g. Business registration + premises' }, { name: 'expires', label: 'Expires on', type: 'date', required: true }, reasonField] });
      if (!f) return; const v = db.verifications.find((x) => x.id === id);
      Object.assign(v, { status: 'approved', scope: f.scope, reason: f.reason, reviewer: me.name, reviewed_at: new Date().toISOString(), expires_at: new Date(f.expires).toISOString() });
      audit('verification.approve', id, f.reason); toast('Supplier approved');
    },
    async 'v-reject'(id) { const f = await ask({ title: 'Reject verification', confirm: 'Reject', danger: true, fields: [reasonField] }); if (!f) return; const v = db.verifications.find((x) => x.id === id); Object.assign(v, { status: 'rejected', reason: f.reason, reviewer: me.name, reviewed_at: new Date().toISOString() }); audit('verification.reject', id, f.reason); toast('Verification rejected'); },
    async 'l-approve'(id) { const l = db.listings.find((x) => x.id === id); const fl = flagged(l); if (fl) { const f = await ask({ title: 'Listing matches a prohibited term', intro: `“${fl}” was found. Approve only with a documented justification.`, confirm: 'Approve anyway', danger: true, fields: [reasonField] }); if (!f) return; audit('listing.approve_flagged', id, f.reason); } else audit('listing.approve', id); l.status = 'published'; toast('Listing published'); },
    async 'l-reject'(id) { const f = await ask({ title: 'Reject listing', confirm: 'Reject', danger: true, fields: [reasonField] }); if (!f) return; db.listings.find((x) => x.id === id).status = 'rejected'; audit('listing.reject', id, f.reason); toast('Listing rejected'); },
    async 'l-pause'(id) { const f = await ask({ title: 'Pause listing', confirm: 'Pause', fields: [reasonField] }); if (!f) return; db.listings.find((x) => x.id === id).status = 'paused'; audit('listing.pause', id, f.reason); toast('Listing paused'); },
    async 'l-resume'(id) { db.listings.find((x) => x.id === id).status = 'published'; audit('listing.republish', id); toast('Listing republished'); },
    async 'r-close'(id) { const f = await ask({ title: 'Close RFQ', intro: 'Closes the RFQ to further quotes.', confirm: 'Close RFQ', danger: true, fields: [reasonField] }); if (!f) return; db.rfqs.find((x) => x.id === id).status = 'closed'; audit('rfq.close', id, f.reason); toast('RFQ closed'); },
    async 'o-dispute'(id) { const f = await ask({ title: 'Open dispute', confirm: 'Open dispute', danger: true, fields: [reasonField] }); if (!f) return; const o = db.orders.find((x) => x.id === id); o.status = 'disputed'; o.events.push({ at: new Date().toISOString(), type: 'exception', note: `Dispute opened: ${f.reason}` }); audit('order.dispute', o.ref, f.reason); toast('Dispute opened'); },
    async 'o-resolve'(id, el) { const to = el.dataset.to; const f = await ask({ title: `Resolve dispute → ${label(to)}`, confirm: 'Resolve', fields: [reasonField] }); if (!f) return; const o = db.orders.find((x) => x.id === id); o.status = to; o.events.push({ at: new Date().toISOString(), type: to === 'delivered' ? 'delivered' : 'exception', note: `Dispute resolved: ${f.reason}` }); audit(`order.resolve_${to}`, o.ref, f.reason); toast('Dispute resolved'); },
    async 'o-pay-confirm'(id) { const f = await ask({ title: 'Record external payment confirmation', intro: 'Only record this with authoritative evidence (e.g. approved provider record or bank reconciliation). Susu Luma does not hold or move funds.', confirm: 'Record', fields: [{ name: 'evidence', label: 'Evidence reference', required: true, placeholder: 'Provider/bank reference' }, reasonField] }); if (!f) return; const o = db.orders.find((x) => x.id === id); o.payment = 'externally_confirmed'; o.payment_evidence = f.evidence; audit('order.payment_externally_confirmed', o.ref, `${f.evidence} — ${f.reason}`); toast('Payment status updated'); },
    async 'o-pay-review'(id) { const f = await ask({ title: 'Flag payment under review', confirm: 'Flag', fields: [reasonField] }); if (!f) return; const o = db.orders.find((x) => x.id === id); o.payment = 'under_review'; audit('order.payment_under_review', o.ref, f.reason); toast('Flagged'); },
    async 't-assign'(id) { const t = db.tickets.find((x) => x.id === id); t.assignee = me.name; if (t.status === 'open') t.status = 'in_progress'; audit('ticket.assign', id); toast('Assigned'); },
    async 't-resolve'(id) { const f = await ask({ title: 'Resolve case', confirm: 'Resolve', fields: [{ name: 'reason', label: 'Resolution summary', type: 'textarea', required: true, min: 8 }] }); if (!f) return; const t = db.tickets.find((x) => x.id === id); t.status = 'resolved'; t.notes.push({ by: me.name, at: new Date().toISOString(), text: `Resolved: ${f.reason}` }); audit('ticket.resolve', id, f.reason); toast('Case resolved'); },
    async 't-reopen'(id) { db.tickets.find((x) => x.id === id).status = 'open'; audit('ticket.reopen', id); toast('Reopened'); },
    async 't-note'(id) { const f = await ask({ title: 'Add case note', confirm: 'Add', fields: [{ name: 'text', label: 'Note', type: 'textarea', required: true }] }); if (!f) return; db.tickets.find((x) => x.id === id).notes.push({ by: me.name, at: new Date().toISOString(), text: f.text }); toast('Note added'); },
    async 'cat-add'() { const f = await ask({ title: 'Add category', fields: [{ name: 'v', label: 'Name', required: true }] }); if (!f) return; if (!db.settings.categories.includes(f.v.trim())) db.settings.categories.push(f.v.trim()); audit('settings.category_add', f.v.trim()); },
    async 'cat-del'(id) { db.settings.categories = db.settings.categories.filter((c) => c !== id); audit('settings.category_remove', id); },
    async 'pro-add'() { const f = await ask({ title: 'Add prohibited term', fields: [{ name: 'v', label: 'Term', required: true }] }); if (!f) return; db.settings.prohibited.push(f.v.trim().toLowerCase()); audit('settings.prohibited_add', f.v.trim()); },
    async 'pro-del'(id) { db.settings.prohibited = db.settings.prohibited.filter((c) => c !== id); audit('settings.prohibited_remove', id); },
    async 'audit-csv'() { const q = (s) => `"${String(s ?? '').replace(/"/g, '""')}"`; const csv = ['when,actor,action,entity,reason', ...db.audit.map((a) => [a.at, a.actor, a.action, a.entity, a.reason].map(q).join(','))].join('\n'); const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv' })); const a = Object.assign(document.createElement('a'), { href: url, download: 'susu-luma-audit.csv' }); a.click(); URL.revokeObjectURL(url); },
    async 'reset'() { const f = await ask({ title: 'Reset sample data?', intro: 'Discards all changes made in this browser.', confirm: 'Reset', danger: true }); if (!f) return; db = SEED(); toast('Sample data restored'); },
  };

  // ---------- shell ----------
  const NAV = [['dashboard', 'Overview'], ['verification', 'Verification'], ['listings', 'Listings'], ['rfqs', 'RFQs & quotes'], ['orders', 'Orders'], ['orgs', 'Organisations'], ['support', 'Support'], ['audit', 'Audit log'], ['settings', 'Settings']];
  function render() {
    const root = $('#app');
    if (!me) {
      root.innerHTML = `<main class="login"><div class="logo">susu luma</div><h1>Operations console</h1><p class="muted">Prototype sign-in. Choose a demo role — no password, no real authentication.</p><div class="personas">${db.users.map((u) => `<button class="persona" data-login="${u.id}"><b>${esc(u.name)}</b><span>${u.role === 'admin' ? 'Full access incl. payment evidence' : u.role === 'reviewer' ? 'Verification and listing moderation' : 'Support cases only'}</span></button>`).join('')}</div><p class="note">Production requires SSO + MFA, server-enforced roles and audit — see docs/architecture-security.md.</p></main>`;
      return;
    }
    const hash = location.hash.slice(1) || 'dashboard', [base, id] = hash.split('/');
    const fn = id ? pages[`${base}/:id`] : pages[base];
    const cur = base;
    root.innerHTML = `<div class="shell"><aside><div class="logo">susu luma <small>ops</small></div><nav aria-label="Main">${NAV.map(([k, l]) => `<a href="#${k}" class="${cur === k ? 'on' : ''}" ${cur === k ? 'aria-current="page"' : ''}>${l}</a>`).join('')}</nav><div class="who"><b>${esc(me.name)}</b><span>${esc(me.role)}</span><button class="btn ghost sm" data-act="logout">Sign out</button></div></aside><main id="main"><div class="banner">Prototype · sample data · stored in this browser only</div>${fn ? fn(id) : notFound()}</main></div>`;
  }

  document.addEventListener('click', async (e) => {
    const t = e.target.closest('button, a'); if (!t) return;
    if (t.dataset.login) { me = db.users.find((u) => u.id === t.dataset.login); try { sessionStorage.setItem(SESSION, me.id); } catch (_) {} location.hash = '#dashboard'; return render(); }
    if (t.dataset.filter) { ui[t.dataset.filter] = t.dataset.v; return render(); }
    const act = t.dataset.act; if (!act) return;
    if (act === 'logout') { me = null; try { sessionStorage.removeItem(SESSION); } catch (_) {} return render(); }
    if (t.disabled) return;
    if (actions[act]) { await actions[act](t.dataset.id, t); save(); render(); }
  });
  document.addEventListener('input', (e) => { const k = e.target.dataset?.search; if (!k) return; ui[k] = e.target.value; const pos = e.target.selectionStart; render(); const el = $(`[data-search="${k}"]`); el.focus(); el.setSelectionRange(pos, pos); });
  window.addEventListener('hashchange', render);

  db = load();
  try { const s = sessionStorage.getItem(SESSION); if (s) me = db.users.find((u) => u.id === s) || null; } catch (_) {}
  render();
})();
