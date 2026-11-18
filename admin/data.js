// Susu Luma admin prototype — ILLUSTRATIVE SAMPLE DATA ONLY. No real businesses, people or transactions.
// Shapes mirror supabase/migrations/20261017000100_marketplace_foundation.sql.
window.SEED = () => {
  const d = (days, h = 9) => new Date(Date.UTC(2026, 10, 18 - days, h, 0)).toISOString();
  return {
    version: 1,
    orgs: [
      { id: 'o1', display_name: 'Freetown Building Supply', legal_name: 'Freetown Building Supply Ltd', type: 'supplier', district: 'Western Area Urban', locality: 'Kissy', created_at: d(60) },
      { id: 'o2', display_name: 'Kono Produce Traders', legal_name: 'Kono Produce Traders Cooperative', type: 'supplier', district: 'Kono', locality: 'Koidu', created_at: d(45) },
      { id: 'o3', display_name: 'Salone Steel & Hardware', legal_name: 'Salone Steel and Hardware Ltd', type: 'supplier', district: 'Western Area Urban', locality: 'Wellington', created_at: d(30) },
      { id: 'o4', display_name: 'Bo Agro Cooperative', legal_name: 'Bo Agro Cooperative Society', type: 'supplier', district: 'Bo', locality: 'Bo Town', created_at: d(12) },
      { id: 'o5', display_name: 'Makeni Equipment Hire', legal_name: 'Makeni Equipment Hire Ltd', type: 'supplier', district: 'Bombali', locality: 'Makeni', created_at: d(5) },
      { id: 'o6', display_name: 'Aberdeen Construction', legal_name: 'Aberdeen Construction Ltd', type: 'buyer', district: 'Western Area Urban', locality: 'Aberdeen', created_at: d(50) },
      { id: 'o7', display_name: 'Hill Station Catering', legal_name: 'Hill Station Catering Ltd', type: 'buyer', district: 'Western Area Rural', locality: 'Hill Station', created_at: d(20) },
      { id: 'o8', display_name: 'Kenema Wholesale', legal_name: 'Kenema Wholesale Traders', type: 'buyer', district: 'Kenema', locality: 'Kenema City', created_at: d(9) },
    ],
    verifications: [
      { id: 'v1', org: 'o1', status: 'approved', scope: 'Business registration + premises', reviewer: 'Amara (Reviewer)', reason: 'Registration and premises evidence matched.', submitted_at: d(55), reviewed_at: d(52), expires_at: d(-300), evidence: ['business-registration.pdf', 'premises-photo.jpg'] },
      { id: 'v2', org: 'o2', status: 'approved', scope: 'Business registration', reviewer: 'Amara (Reviewer)', reason: 'Cooperative certificate verified.', submitted_at: d(40), reviewed_at: d(37), expires_at: d(-320), evidence: ['coop-certificate.pdf'] },
      { id: 'v3', org: 'o3', status: 'in_review', scope: '', reviewer: 'Amara (Reviewer)', reason: '', submitted_at: d(6), reviewed_at: null, expires_at: null, evidence: ['registration.pdf', 'tax-clearance.pdf', 'warehouse-photo.jpg'] },
      { id: 'v4', org: 'o4', status: 'pending', scope: '', reviewer: '', reason: '', submitted_at: d(3), reviewed_at: null, expires_at: null, evidence: ['coop-registration.pdf'] },
      { id: 'v5', org: 'o5', status: 'pending', scope: '', reviewer: '', reason: '', submitted_at: d(1), reviewed_at: null, expires_at: null, evidence: ['registration.pdf', 'insurance.pdf'] },
    ],
    listings: [
      { id: 'l1', org: 'o1', title: 'Portland Cement 50 kg', category: 'Construction', unit: 'bag', price_mode: 'quote_only', price: null, currency: null, district: 'Western Area Urban', status: 'published', lead_days: 3, created_at: d(50) },
      { id: 'l2', org: 'o2', title: 'Fresh Cocoa Beans', category: 'Agriculture', unit: 'kg', price_mode: 'quote_only', price: null, currency: null, district: 'Kono', status: 'published', lead_days: 7, created_at: d(35) },
      { id: 'l3', org: 'o3', title: 'Iron Rods 12 mm', category: 'Metals', unit: 'length', price_mode: 'indicative', price: 185, currency: 'SLE', district: 'Western Area Urban', status: 'pending_review', lead_days: 5, created_at: d(4) },
      { id: 'l4', org: 'o4', title: 'Cassava Flour 25 kg sack', category: 'Agriculture', unit: 'sack', price_mode: 'indicative', price: 420, currency: 'SLE', district: 'Bo', status: 'pending_review', lead_days: 4, created_at: d(3) },
      { id: 'l5', org: 'o5', title: 'Mini excavator hire (per day)', category: 'Equipment', unit: 'day', price_mode: 'quote_only', price: null, currency: null, district: 'Bombali', status: 'pending_review', lead_days: 2, created_at: d(1) },
      { id: 'l6', org: 'o3', title: 'Roofing sheets 3 m', category: 'Construction', unit: 'sheet', price_mode: 'fixed', price: 95, currency: 'SLE', district: 'Western Area Urban', status: 'published', lead_days: 2, created_at: d(25) },
      { id: 'l7', org: 'o4', title: 'Guaranteed returns investment pool', category: 'Agriculture', unit: 'unit', price_mode: 'fixed', price: 1000, currency: 'SLE', district: 'Bo', status: 'pending_review', lead_days: 0, created_at: d(1, 14) },
      { id: 'l8', org: 'o1', title: 'Sand (tipper load)', category: 'Construction', unit: 'load', price_mode: 'quote_only', price: null, currency: null, district: 'Western Area Urban', status: 'paused', lead_days: 1, created_at: d(40) },
    ],
    rfqs: [
      { id: 'r1', ref: 'SL-4F2A91C0B7', buyer: 'o6', status: 'quoted', district: 'Western Area Urban', target: '2026-12-05', notes: 'Site delivery, Aberdeen. Unloading by buyer.', submitted_at: d(8), items: [{ title: 'Portland Cement 50 kg', qty: 400, unit: 'bag' }], recipients: ['o1'] },
      { id: 'r2', ref: 'SL-9C07E15D22', buyer: 'o7', status: 'open', district: 'Western Area Rural', target: '2026-12-01', notes: '', submitted_at: d(2), items: [{ title: 'Cassava Flour 25 kg sack', qty: 60, unit: 'sack' }], recipients: ['o4'] },
      { id: 'r3', ref: 'SL-1B88D3A4F6', buyer: 'o8', status: 'accepted', district: 'Kenema', target: '2026-11-28', notes: 'Weekly standing need, first delivery.', submitted_at: d(14), items: [{ title: 'Fresh Cocoa Beans', qty: 1200, unit: 'kg' }], recipients: ['o2'] },
      { id: 'r4', ref: 'SL-77E0C2B913', buyer: 'o6', status: 'accepted', district: 'Western Area Urban', target: '2026-11-25', notes: '', submitted_at: d(18), items: [{ title: 'Roofing sheets 3 m', qty: 150, unit: 'sheet' }, { title: 'Iron Rods 12 mm', qty: 80, unit: 'length' }], recipients: ['o3'] },
    ],
    quotes: [
      { id: 'q1', rfq: 'r1', supplier: 'o1', version: 1, status: 'submitted', currency: 'SLE', total: 112000, lead_days: 3, validity: d(-7), terms: 'Delivery within Freetown included.', exclusions: 'Offloading' },
      { id: 'q2', rfq: 'r3', supplier: 'o2', version: 2, status: 'accepted', currency: 'SLE', total: 66000, lead_days: 7, validity: d(-2), terms: 'Bagged in 50 kg.', exclusions: 'Transport beyond Kenema depot' },
      { id: 'q3', rfq: 'r4', supplier: 'o3', version: 1, status: 'accepted', currency: 'SLE', total: 26000, lead_days: 5, validity: d(1), terms: 'Delivery to site.', exclusions: '' },
    ],
    orders: [
      { id: 'ord1', ref: 'ORD-0001', rfq: 'r3', quote: 'q2', buyer: 'o8', supplier: 'o2', status: 'in_fulfilment', payment: 'pending_unverified', payment_evidence: '', created_at: d(10), events: [{ at: d(9), type: 'ready', note: 'Beans bagged and weighed.' }, { at: d(7), type: 'dispatched', note: 'Truck left Koidu.' }] },
      { id: 'ord2', ref: 'ORD-0002', rfq: 'r4', quote: 'q3', buyer: 'o6', supplier: 'o3', status: 'awaiting_seller_confirmation', payment: 'pending_unverified', payment_evidence: '', created_at: d(1), events: [] },
      { id: 'ord3', ref: 'ORD-0003', rfq: 'r1', quote: 'q1', buyer: 'o6', supplier: 'o1', status: 'delivered', payment: 'externally_confirmed', payment_evidence: 'Bank statement ref (sample) BK-2026-1180', created_at: d(30), events: [{ at: d(26), type: 'dispatched', note: '' }, { at: d(24), type: 'delivered', note: 'Signed by site foreman.' }] },
    ],
    tickets: [
      { id: 't1', subject: 'Supplier did not respond to RFQ', org: 'o7', order: null, status: 'open', priority: 'normal', assignee: '', created_at: d(2), notes: [] },
      { id: 't2', subject: 'Quantity delivered short by 10 bags', org: 'o6', order: 'ord3', status: 'in_progress', priority: 'high', assignee: 'Isatu (Support)', created_at: d(4), notes: [{ by: 'Isatu (Support)', at: d(3), text: 'Asked supplier for delivery note.' }] },
      { id: 't3', subject: 'Report: listing uses misleading claims', org: 'o4', order: null, status: 'open', priority: 'high', assignee: '', created_at: d(1), notes: [] },
      { id: 't4', subject: 'How do I update my business address?', org: 'o8', order: null, status: 'resolved', priority: 'low', assignee: 'Isatu (Support)', created_at: d(9), notes: [{ by: 'Isatu (Support)', at: d(8), text: 'Explained profile edit flow.' }] },
    ],
    settings: {
      categories: ['Construction', 'Agriculture', 'Metals', 'Equipment', 'Food & Beverage'],
      prohibited: ['guaranteed returns', 'investment', 'weapon', 'ivory', 'wallet', 'escrow'],
    },
    audit: [
      { id: 'a1', at: d(52), actor: 'Amara (Reviewer)', action: 'verification.approve', entity: 'v1', reason: 'Registration and premises evidence matched.' },
      { id: 'a2', at: d(37), actor: 'Amara (Reviewer)', action: 'verification.approve', entity: 'v2', reason: 'Cooperative certificate verified.' },
    ],
    users: [
      { id: 'u1', name: 'Fatmata (Admin)', role: 'admin' },
      { id: 'u2', name: 'Amara (Reviewer)', role: 'reviewer' },
      { id: 'u3', name: 'Isatu (Support)', role: 'support' },
    ],
  };
};
