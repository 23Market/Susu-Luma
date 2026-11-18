-- Persona tests: every assertion runs as a real role with a simulated Supabase JWT.
create or replace function t.ok(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'FAIL: %', p_msg; end if;
  raise notice 'PASS: %', p_msg;
end $$;
-- Runs SQL expecting an error (optionally containing p_like); the failed statement is rolled back.
create or replace function t.denied(p_sql text, p_msg text, p_like text default null) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if p_like is not null and sqlerrm not ilike '%' || p_like || '%' then
      raise exception 'FAIL: % (wrong error: %)', p_msg, sqlerrm;
    end if;
    raise notice 'PASS: %', p_msg;
    return;
  end;
  raise exception 'FAIL: % (statement succeeded)', p_msg;
end $$;
grant usage on schema t to authenticated, anon;
grant execute on all functions in schema t to authenticated, anon;

do $$
declare
  b1 uuid := '00000000-0000-0000-0000-0000000000b1'; b2 uuid := '00000000-0000-0000-0000-0000000000b2';
  s1 uuid := '00000000-0000-0000-0000-0000000000a1'; s2 uuid := '00000000-0000-0000-0000-0000000000a2';
  xx uuid := '00000000-0000-0000-0000-0000000000ee';
  a_super uuid := '00000000-0000-0000-0000-000000000f01'; a_sup uuid := '00000000-0000-0000-0000-000000000f02';
  a_fin uuid := '00000000-0000-0000-0000-000000000f03'; a_trust uuid := '00000000-0000-0000-0000-000000000f04';
  orgA uuid; orgB uuid; orgS uuid; orgT uuid; l1 uuid; l2 uuid; rfq uuid; q1 uuid; q2 uuid; ord uuid; pay uuid;
  ver uuid; thr uuid; r jsonb; n int; items jsonb; item1 uuid;
begin
  -- fixtures (superuser)
  insert into auth.users (id, email) values (b1,'b1@t'),(b2,'b2@t'),(s1,'s1@t'),(s2,'s2@t'),(xx,'xx@t'),
    (a_super,'su@t'),(a_sup,'sp@t'),(a_fin,'fi@t'),(a_trust,'tr@t');
  insert into public.admin_users (user_id, role_code, display_name) values
    (a_super,'superadmin','Super Admin'),(a_sup,'support','Support Agent'),(a_fin,'finance','Finance Lead'),(a_trust,'trust','Trust Lead');

  ------------------------------------------------------------------ organisations
  perform t.login(b1); orgA := public.create_organization('A Construction Ltd','A Construction','buyer','Western Area Urban','Aberdeen');
  perform t.ok((select count(*) from public.organization_memberships where organization_id = orgA and member_role='owner') = 1, 'create_organization makes the caller the owner atomically');
  perform t.denied($q$insert into public.organizations (legal_name, display_name, organization_type, created_by) values ('Rogue Ltd','Rogue','buyer', auth.uid())$q$, 'clients cannot insert organisations directly');
  perform t.logout();
  perform t.login(b2); orgB := public.create_organization('B Traders Ltd','B Traders','buyer','Bo','Bo Town'); perform t.logout();
  perform t.login(s1); orgS := public.create_organization('S Supply Ltd','S Supply','supplier','Western Area Urban','Kissy'); perform t.logout();
  perform t.login(s2); orgT := public.create_organization('T Hardware Ltd','T Hardware','supplier','Bo','Bo Town'); perform t.logout();

  ------------------------------------------------------------------ listings
  perform t.login(s1);
  insert into public.listings (organization_id, title, category, quantity_unit, price_mode, created_by)
    values (orgS, 'Portland cement 50 kg', 'construction', 'bag', 'quote_only', s1) returning id into l1;
  perform t.ok(true, 'seller can create a draft listing');
  perform t.denied(format($q$insert into public.listings (organization_id, title, category, quantity_unit, status, created_by) values (%L,'Sneaky','construction','bag','published',%L)$q$, orgS, s1), 'seller cannot insert a pre-published listing');
  perform t.denied(format($q$update public.listings set status = 'published' where id = %L$q$, l1), 'seller cannot self-publish', 'server-controlled');
  perform t.denied($q$insert into public.listings (organization_id, title, category, quantity_unit, created_by) values ((select id from public.organizations limit 1),'x y z','nonexistent','bag', auth.uid())$q$, 'listings need a real category');
  perform t.ok(public.submit_listing_for_review(l1) = 'pending_review', 'unverified supplier listing goes to the moderation queue');
  insert into public.listings (organization_id, title, category, quantity_unit, price_mode, created_by)
    values (orgS, 'Frozen chicken 10 kg', 'food', 'carton', 'quote_only', s1) returning id into l2;
  perform public.submit_listing_for_review(l2);
  perform t.logout();
  perform t.login(xx);
  perform t.denied(format($q$select public.submit_listing_for_review(%L)$q$, l1), 'a stranger cannot submit someone else''s listing');
  perform t.ok((select count(*) from public.listings) = 0, 'a stranger sees no unpublished listings');
  perform t.logout();

  ------------------------------------------------------------------ admin gating: MFA, permission, scope
  perform t.login(a_trust, 'aal1');
  r := public.admin_moderate_listing(l1, 'approve');
  perform t.ok(r ->> 'error' = 'permission_denied', 'admin without an MFA session (aal1) is refused');
  perform t.ok((select count(*) from public.listings) = 0, 'admin without MFA reads nothing');
  perform t.logout();
  perform t.login(a_trust, 'aal2');
  r := public.admin_moderate_listing(l2, 'approve');
  perform t.ok(r ->> 'error' = 'out_of_scope', 'category-scoped moderator cannot touch an out-of-scope category (food)');
  r := public.admin_moderate_listing(l1, 'reject');
  perform t.ok(r ->> 'error' = 'reason_required', 'rejection requires a reason');
  r := public.admin_moderate_listing(l1, 'approve');
  perform t.ok((r ->> 'ok')::boolean and r ->> 'status' = 'published', 'in-scope moderator publishes the listing');
  perform t.logout();
  perform t.login(a_super, 'aal2');
  perform t.ok((select count(*) from public.audit_events where action = 'access.denied' and entity_id = l2) = 1, 'the scope refusal was written to the audit log');
  r := public.admin_moderate_listing(l2, 'approve');
  perform t.ok((r ->> 'ok')::boolean, 'Super Admin can moderate any category');
  perform t.logout();
  perform t.anon();
  perform t.ok((select count(*) from public.listings) = 2, 'anonymous visitors read published listings');
  perform t.denied($q$select * from public.rfqs$q$, 'anonymous visitors cannot read RFQs');
  perform t.logout();

  ------------------------------------------------------------------ RFQ -> quote -> order, tenant isolation
  perform t.login(b1);
  rfq := public.create_rfq(orgA, 'Western Area Urban', 'Aberdeen', current_date + 14, 'Site delivery',
    jsonb_build_array(jsonb_build_object('listing_id', l1, 'quantity', 400)), array[orgT]);
  perform t.ok((select count(*) from public.rfq_recipients where rfq_id = rfq) = 2, 'RFQ routed to the listing owner plus the chosen supplier');
  perform t.denied($q$update public.rfqs set status = 'accepted'$q$, 'buyer cannot write RFQ state directly');
  perform t.denied(format($q$select public.create_rfq(%L,'x','x',null,null,'[{"product_title":"Thing","quantity":-1,"quantity_unit":"bag"}]'::jsonb, array[%L]::uuid[])$q$, orgA, orgS), 'RFQ quantity must be positive', 'quantity_invalid');
  perform t.logout();
  perform t.login(b2);
  perform t.ok((select count(*) from public.rfqs) = 0, 'another buyer cannot see this RFQ');
  perform t.denied(format($q$select public.create_rfq(%L,'x','x',null,null,'[]'::jsonb, array[%L]::uuid[])$q$, orgA, orgS), 'cannot create an RFQ on behalf of another organisation', 'not_permitted');
  perform t.logout();
  select id into item1 from public.rfq_items where rfq_id = rfq;
  perform t.login(s1);
  perform t.ok((select count(*) from public.rfqs) = 1 and (select count(*) from public.rfq_recipients where rfq_id = rfq) = 1, 'a supplier sees the RFQ but only its own routing row (competitors hidden)');
  perform t.denied(format($q$select public.submit_quote(%L,%L,'SLE',3,now() + interval '7 days',null,null,'[]'::jsonb)$q$, rfq, orgS), 'a quote must price every item', 'every_item_must_be_priced_once');
  perform t.denied(format($q$select public.submit_quote(%L,%L,'sle',3,now() + interval '7 days',null,null,jsonb_build_array(jsonb_build_object('rfq_item_id', %L,'unit_price',280)))$q$, rfq, orgS, item1), 'currency must be an ISO code', 'currency_invalid');
  q1 := public.submit_quote(rfq, orgS, 'SLE', 3, now() + interval '7 days', 'Delivery included', null, jsonb_build_array(jsonb_build_object('rfq_item_id', item1, 'unit_price', 280)));
  perform t.ok((select quantity_unit from public.quote_lines where quote_id = q1) = 'bag', 'quote line unit is copied from the RFQ item (not client supplied)');
  q1 := public.submit_quote(rfq, orgS, 'SLE', 3, now() + interval '7 days', 'Revised', null, jsonb_build_array(jsonb_build_object('rfq_item_id', item1, 'unit_price', 270)));
  perform t.ok((select version from public.quotes where id = q1) = 2 and (select count(*) from public.quotes where status = 'revised') = 1, 'revising creates version 2 and marks version 1 revised');
  perform t.denied($q$update public.quote_lines set unit_price = 1$q$, 'quote lines cannot be edited by clients');
  perform t.logout();
  perform t.login(s2);
  q2 := public.submit_quote(rfq, orgT, 'USD', 5, now() + interval '7 days', null, null, jsonb_build_array(jsonb_build_object('rfq_item_id', item1, 'unit_price', 12)));
  perform t.ok((select count(*) from public.quotes) = 1, 'a supplier cannot see competitors'' quotes');
  perform t.logout();
  perform t.login(xx);
  perform t.denied(format($q$select public.submit_quote(%L,%L,'SLE',3,now() + interval '7 days',null,null,'[]'::jsonb)$q$, rfq, orgS), 'a non-recipient cannot quote', 'not_permitted');
  perform t.logout();
  perform t.login(b1);
  perform t.ok((select count(*) from public.quotes) = 3, 'the buyer sees every quote on their RFQ');
  perform t.denied(format($q$select public.accept_quote(%L)$q$, q1) || ';' || format($q$select public.accept_quote(%L)$q$, q1), 'accepting twice is refused', 'quote_not_acceptable');
  perform t.logout();
  perform t.login(s1);
  perform t.denied(format($q$select public.accept_quote(%L)$q$, q1), 'a supplier cannot accept its own quote', 'not_permitted');
  perform t.logout();
  perform t.login(b1);
  ord := public.accept_quote(q1);
  perform t.ok((select (accepted_quote_snapshot ->> 'total')::numeric from public.orders where id = ord) = 108000
     and (select accepted_quote_snapshot ->> 'currency_code' from public.orders where id = ord) = 'SLE', 'order snapshot freezes total (400 x 270) and currency');
  perform t.ok((select status from public.quotes where id = q2) = 'declined' and (select status from public.rfqs where id = rfq) = 'accepted', 'other quotes declined and RFQ accepted');
  perform t.ok((select status from public.payment_records where order_id = ord) = 'pending_unverified', 'payment starts pending_unverified');
  perform t.denied(format($q$select public.confirm_order(%L)$q$, ord), 'the buyer cannot confirm the supplier''s side', 'not_permitted');
  perform t.logout();
  perform t.login(s1);
  perform public.confirm_order(ord);
  perform t.denied(format($q$select public.add_delivery_event(%L,'partial_delivery',null,null,null,null)$q$, ord), 'partial delivery needs quantity and unit', 'quantity_and_unit_required');
  perform t.denied(format($q$select public.add_delivery_event(%L,'dispatched',null,null,null,'someone-else/pod.jpg')$q$, ord), 'evidence must sit under the supplier''s own prefix', 'evidence_path_invalid');
  perform public.add_delivery_event(ord, 'dispatched', 'Truck left Kissy', null, null, null);
  perform public.add_delivery_event(ord, 'partial_delivery', null, 150, 'bag', null);
  perform t.ok((select status from public.orders where id = ord) = 'partially_delivered', 'partial delivery keeps the order open');
  perform public.add_delivery_event(ord, 'delivered', null, 250, 'bag', null);
  perform t.ok((select status from public.orders where id = ord) = 'delivered', 'order reaches delivered');
  perform t.logout();
  perform t.login(b1);
  perform public.assert_payment_made(ord, 'Paid by bank transfer');
  perform t.ok((select status from public.payment_records where order_id = ord) = 'pending_unverified', 'a buyer''s payment claim never changes payment status');
  perform t.ok((select payment_status::text from public.orders where id = ord) = 'pending_unverified', 'order payment status also stays unverified');
  perform t.logout();

  ------------------------------------------------------------------ payment reconciliation (finance only)
  perform t.login(a_sup, 'aal2');
  select id into pay from public.payment_records where order_id = ord;
  r := public.admin_reconcile_payment(pay, 'confirm', 108000, 'SLE', 'BK-778812', 'Statement checked');
  perform t.ok(r ->> 'error' = 'permission_denied', 'Support cannot reconcile payments');
  perform t.logout();
  perform t.login(a_fin, 'aal2');
  r := public.admin_reconcile_payment(pay, 'confirm', 1, 'SLE', 'BK-778812', 'Statement checked');
  perform t.ok(r ->> 'outcome' = 'mismatch' and (select status from public.payment_records where id = pay) = 'under_review', 'wrong amount is flagged, never confirmed');
  r := public.admin_reconcile_payment(pay, 'confirm', 108000, 'USD', 'BK-778812', 'Statement checked');
  perform t.ok(r ->> 'outcome' = 'mismatch', 'wrong currency is flagged, never confirmed');
  r := public.admin_reconcile_payment(pay, 'confirm', 108000, 'SLE', 'bad', 'Statement checked');
  perform t.ok(r ->> 'error' = 'reference_required', 'a provider/bank reference is mandatory');
  r := public.admin_reconcile_payment(pay, 'confirm', 108000, 'SLE', 'BK-778812', 'Statement checked');
  perform t.ok(r ->> 'outcome' = 'confirmed' and (select payment_status::text from public.orders where id = ord) = 'externally_confirmed', 'exact external evidence confirms payment');
  perform t.ok((select count(*) from public.audit_events where action like 'payment.%') >= 3, 'finance can read payment audit entries');
  perform t.logout();
  perform t.login(a_sup, 'aal2');
  perform t.ok((select count(*) from public.audit_events) = 0, 'Support lacks audit.view and sees no audit rows');
  perform t.logout();

  ------------------------------------------------------------------ verification
  perform t.login(s1);
  perform t.denied(format($q$select public.submit_verification(%L,'Registration',array['other-org/reg.pdf'])$q$, orgS), 'evidence must be under the supplier''s own prefix', 'evidence_path_invalid');
  ver := public.submit_verification(orgS, 'Business registration', array[orgS::text || '/registration.pdf']);
  perform t.denied(format($q$select public.submit_verification(%L,'again',array[%L])$q$, orgS, orgS::text || '/x.pdf'), 'only one open dossier per supplier', 'verification_already_open');
  perform t.logout();
  perform t.login(a_super, 'aal2');
  r := public.admin_verification_action(ver, 'start_review');
  r := public.admin_verification_action(ver, 'approve', 'Business registration', 12, 'All evidence matched');
  perform t.ok(r ->> 'error' = 'checklist_incomplete', 'approval is refused until the checklist is complete');
  for n in 0..4 loop perform public.admin_set_checklist(ver, n, true); end loop;
  r := public.admin_verification_action(ver, 'approve', 'Business registration', 12, 'All evidence matched');
  perform t.ok((r ->> 'ok')::boolean and public.org_is_verified(orgS), 'approval with a complete checklist verifies the supplier (time-limited)');
  perform t.ok((select evidence_object_paths is not null from public.admin_verification_queue where id = ver), 'Super Admin sees evidence paths');
  perform t.logout();
  perform t.login(a_trust, 'aal2');
  perform t.ok((select evidence_count from public.admin_verification_queue where id = ver) = 1 and (select evidence_object_paths is null from public.admin_verification_queue where id = ver), 'a role without evidence permission sees only the count, not the paths');
  r := public.admin_request_evidence_access(ver, orgS::text || '/registration.pdf');
  perform t.ok(r ->> 'error' = 'permission_denied', 'evidence access is refused without the permission');
  perform t.logout();
  perform t.login(s1);
  perform t.ok((select count(*) from public.notifications where kind = 'verification.approved' and organization_id = orgS) = 1, 'the supplier is notified of the decision');
  perform t.ok((select verified from public.supplier_directory where id = orgS), 'public directory shows the verified badge');
  perform t.logout();

  ------------------------------------------------------------------ disputes keep payment independent
  perform t.login(a_super, 'aal2');
  r := public.admin_order_action(ord, 'open_dispute', null, 'Short delivery reported');
  perform t.ok((r ->> 'ok')::boolean and (select payment_status::text from public.orders where id = ord) = 'externally_confirmed', 'opening a dispute leaves payment status unchanged');
  r := public.admin_order_action(ord, 'resolve_dispute', 'delivered', 'Settled between parties');
  perform t.ok((select status::text from public.orders where id = ord) = 'delivered', 'dispute resolved');
  perform t.logout();

  ------------------------------------------------------------------ audit is append-only; role admin is Super-only; messaging
  perform t.login(a_super, 'aal2');
  perform t.denied($q$update public.audit_events set reason = 'tampered'$q$, 'clients cannot update audit events');
  perform t.denied($q$delete from public.audit_events$q$, 'clients cannot delete audit events');
  r := public.admin_grant_role(xx, 'analyst', 'Analyst X', 'Onboarding analyst');
  perform t.ok((r ->> 'ok')::boolean, 'Super Admin can grant a role');
  r := public.admin_revoke_role(a_super, 'Trying to lock myself out');
  perform t.ok(r ->> 'error' = 'cannot_revoke_self', 'a Super Admin cannot revoke themselves');
  perform t.logout();
  perform t.login(a_fin, 'aal2');
  r := public.admin_grant_role(b1, 'superadmin', 'Escalation', 'Privilege escalation attempt');
  perform t.ok(r ->> 'error' = 'permission_denied', 'only Super Admin can grant roles (no self-service escalation)');
  perform t.logout();
  perform t.login(xx, 'aal2');
  perform t.ok((select count(*) from public.admin_users) = 1, 'a user reads only their own admin row');
  perform t.logout();
  perform t.login(b2);
  perform t.denied($q$update public.admin_users set role_code = 'superadmin'$q$, 'a normal user cannot edit admin roles');
  perform t.logout();
  reset role;
  perform t.denied($q$update public.audit_events set reason = 'tampered'$q$, 'even the table owner is blocked by the append-only trigger', 'append-only');

  perform t.login(b1);
  thr := public.open_thread(orgA, orgS, rfq, 'Cement order');
  perform public.send_message(thr, 'Please confirm delivery date');
  perform t.logout();
  perform t.login(b2);
  perform t.ok((select count(*) from public.messages) = 0, 'other organisations cannot read the conversation');
  perform t.denied(format($q$select public.send_message(%L,'hi')$q$, thr), 'non-participants cannot post', 'not_permitted');
  perform t.logout();
  perform t.login(s1);
  perform t.ok((select count(*) from public.messages) = 1, 'the supplier reads the conversation');
  perform t.logout();
  raise notice 'ALL ASSERTIONS PASSED';
end $$;
