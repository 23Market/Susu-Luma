-- Susu Luma: admin read access and privileged operations.
-- Every function checks permission + MFA (aal2) via admin_guard(), requires a reason where policy demands one,
-- changes state and writes the audit event in ONE transaction. Refusals and validation failures are returned
-- as {"ok": false, "error": "..."} (not raised) so the refusal audit entry is not rolled back.

------------------------------------------------------------------------------------------
-- 1. Admin read access (additive to tenant policies; all require an MFA session)
------------------------------------------------------------------------------------------
create policy admin_read_orgs on public.organizations for select to authenticated using (public.has_admin_permission('organisations.view'));
create policy admin_read_members on public.organization_memberships for select to authenticated using (public.has_admin_permission('organisations.members.view'));
create policy admin_read_listings on public.listings for select to authenticated using (public.has_admin_permission('listings.view'));
create policy admin_read_rfqs on public.rfqs for select to authenticated using (public.has_admin_permission('rfqs.view'));
create policy admin_read_rfq_items on public.rfq_items for select to authenticated using (public.has_admin_permission('rfqs.view'));
create policy admin_read_rfq_recipients on public.rfq_recipients for select to authenticated using (public.has_admin_permission('rfqs.routing.view'));
create policy admin_read_quotes on public.quotes for select to authenticated using (public.has_admin_permission('quotes.view'));
create policy admin_read_quote_lines on public.quote_lines for select to authenticated using (public.has_admin_permission('quotes.view'));
create policy admin_read_orders on public.orders for select to authenticated using (public.has_admin_permission('orders.view'));
create policy admin_read_delivery on public.delivery_events for select to authenticated using (public.has_admin_permission('fulfilment.view'));
create policy admin_read_payments on public.payment_records for select to authenticated using (public.has_admin_permission('payments.view'));
create policy admin_read_payment_events on public.payment_events for select to authenticated using (public.has_admin_permission('payments.view'));

-- Verification dossiers are read through a view so evidence paths are only revealed to roles that hold
-- verification.evidence.view (row-level security cannot hide a single column).
create view public.admin_verification_queue as
  select c.id, c.organization_id, o.display_name as organization_name, o.district, c.status,
         c.verification_scope, c.assigned_reviewer, c.decision_reason, c.checklist, c.history,
         c.submitted_at, c.reviewed_at, c.expires_at,
         cardinality(c.evidence_object_paths) as evidence_count,
         case when public.has_admin_permission('verification.evidence.view') then c.evidence_object_paths end as evidence_object_paths
  from public.supplier_verification_cases c
  join public.organizations o on o.id = c.organization_id
  where public.has_admin_permission('verification.view');
grant select on public.admin_verification_queue to authenticated;
revoke all on public.admin_verification_queue from anon;

------------------------------------------------------------------------------------------
-- 2. Verification
------------------------------------------------------------------------------------------
create function public.admin_verification_action(
  p_case uuid, p_action text, p_scope text default null, p_valid_months integer default null, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_c public.supplier_verification_cases; v_perm text; v_uid uuid := (select auth.uid());
  v_needs_reason boolean := p_action in ('request_information', 'approve', 'reject', 'suspend');
  v_hist jsonb;
begin
  v_perm := case p_action
    when 'start_review' then 'verification.assign' when 'assign' then 'verification.assign' when 'reopen' then 'verification.assign'
    when 'request_information' then 'verification.decide' when 'approve' then 'verification.decide'
    when 'reject' then 'verification.decide' when 'suspend' then 'verification.suspend' end;
  if v_perm is null then return jsonb_build_object('ok', false, 'error', 'unknown_action'); end if;
  if not public.admin_guard(v_perm, 'verification.' || p_action, 'verification_case', p_case) then
    return jsonb_build_object('ok', false, 'error', 'permission_denied');
  end if;
  if v_needs_reason and length(trim(coalesce(p_reason, ''))) < 8 then return jsonb_build_object('ok', false, 'error', 'reason_required'); end if;
  select * into v_c from public.supplier_verification_cases where id = p_case for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  v_hist := jsonb_build_object('at', now(), 'by', v_uid, 'text', p_action || coalesce(': ' || p_reason, ''));

  if p_action = 'start_review' then
    if v_c.status <> 'pending' then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
    update public.supplier_verification_cases set status = 'in_review', assigned_reviewer = v_uid, history = history || v_hist where id = p_case;
  elsif p_action = 'assign' then
    if v_c.status not in ('in_review', 'info_required') then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
    update public.supplier_verification_cases set assigned_reviewer = v_uid, history = history || v_hist where id = p_case;
  elsif p_action = 'request_information' then
    if v_c.status <> 'in_review' then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
    update public.supplier_verification_cases set status = 'info_required', history = history || v_hist where id = p_case;
    perform public.notify_org(v_c.organization_id, 'verification.info_required', 'More information needed', p_reason, 'verification_case', p_case);
  elsif p_action = 'approve' then
    if v_c.status not in ('in_review', 'info_required') or v_c.assigned_reviewer is null then
      return jsonb_build_object('ok', false, 'error', 'invalid_state');
    end if;
    if exists (select 1 from jsonb_array_elements(v_c.checklist) e where coalesce((e ->> 'done')::boolean, false) = false) then
      perform public.write_audit('verification.approve_refused', 'verification_case', p_case, 'Checklist incomplete', 'warn');
      return jsonb_build_object('ok', false, 'error', 'checklist_incomplete');
    end if;
    if coalesce(length(trim(p_scope)), 0) < 3 or p_valid_months is null or p_valid_months not between 1 and 36 then
      return jsonb_build_object('ok', false, 'error', 'scope_and_validity_required');
    end if;
    update public.supplier_verification_cases set status = 'approved', verification_scope = trim(p_scope), reviewer_id = v_uid,
      decision_reason = p_reason, reviewed_at = now(), expires_at = now() + make_interval(months => p_valid_months),
      history = history || v_hist where id = p_case;
    perform public.notify_org(v_c.organization_id, 'verification.approved', 'Verification approved', trim(p_scope), 'verification_case', p_case);
  elsif p_action = 'reject' then
    if v_c.status not in ('in_review', 'info_required') then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
    update public.supplier_verification_cases set status = 'rejected', reviewer_id = v_uid, decision_reason = p_reason,
      reviewed_at = now(), history = history || v_hist where id = p_case;
    perform public.notify_org(v_c.organization_id, 'verification.rejected', 'Verification not approved', p_reason, 'verification_case', p_case);
  elsif p_action = 'suspend' then
    if v_c.status <> 'approved' then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
    update public.supplier_verification_cases set status = 'suspended', decision_reason = p_reason, history = history || v_hist where id = p_case;
    perform public.notify_org(v_c.organization_id, 'verification.suspended', 'Verification suspended', p_reason, 'verification_case', p_case);
  elsif p_action = 'reopen' then
    if v_c.status not in ('rejected', 'suspended', 'expired') then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
    update public.supplier_verification_cases set status = 'in_review', assigned_reviewer = v_uid, history = history || v_hist where id = p_case;
  end if;
  perform public.write_audit('verification.' || p_action, 'verification_case', p_case, p_reason,
                             case when p_action in ('suspend') then 'critical' when p_action = 'reject' then 'warn' else 'info' end);
  return jsonb_build_object('ok', true);
end $$;

create function public.admin_set_checklist(p_case uuid, p_index integer, p_done boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_c public.supplier_verification_cases;
begin
  if not public.admin_guard('verification.decide', 'verification.checklist', 'verification_case', p_case) then
    return jsonb_build_object('ok', false, 'error', 'permission_denied');
  end if;
  select * into v_c from public.supplier_verification_cases where id = p_case for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_c.status not in ('in_review', 'info_required') then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
  if p_index < 0 or p_index >= jsonb_array_length(v_c.checklist) then return jsonb_build_object('ok', false, 'error', 'index_out_of_range'); end if;
  update public.supplier_verification_cases
     set checklist = jsonb_set(checklist, array[p_index::text, 'done'], to_jsonb(p_done)) where id = p_case;
  perform public.write_audit('verification.checklist', 'verification_case', p_case, null, 'info',
                             jsonb_build_object('index', p_index, 'done', p_done));
  return jsonb_build_object('ok', true);
end $$;

-- Evidence is opened in two steps: this call authorises + logs, then the console signs a short-lived URL
-- (storage policy in the next migration also requires the same permission).
create function public.admin_request_evidence_access(p_case uuid, p_path text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_c public.supplier_verification_cases;
begin
  if not public.admin_guard('verification.evidence.view', 'verification.evidence.view', 'verification_case', p_case) then
    return jsonb_build_object('ok', false, 'error', 'permission_denied');
  end if;
  select * into v_c from public.supplier_verification_cases where id = p_case;
  if not found or not (p_path = any (v_c.evidence_object_paths)) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  perform public.write_audit('verification.evidence.view', 'verification_case', p_case, 'Evidence opened', 'warn', jsonb_build_object('path', p_path));
  return jsonb_build_object('ok', true, 'path', p_path);
end $$;

------------------------------------------------------------------------------------------
-- 3. Listing moderation (category-scoped)
------------------------------------------------------------------------------------------
create function public.admin_moderate_listing(p_listing uuid, p_action text, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_l public.listings; v_perm text; v_new public.listing_status;
begin
  v_perm := case p_action when 'approve' then 'listings.moderate' when 'reject' then 'listings.moderate'
    when 'pause' then 'listings.moderate' when 'resume' then 'listings.moderate'
    when 'remove' then 'listings.remove' when 'restore' then 'listings.restore' end;
  if v_perm is null then return jsonb_build_object('ok', false, 'error', 'unknown_action'); end if;
  if not public.admin_guard(v_perm, 'listing.' || p_action, 'listing', p_listing) then
    return jsonb_build_object('ok', false, 'error', 'permission_denied');
  end if;
  select * into v_l from public.listings where id = p_listing for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.admin_in_scope(v_l.category) then
    perform public.write_audit('access.denied', 'listing', p_listing, 'Category out of role scope: ' || v_l.category, 'warn',
                               jsonb_build_object('attempted', 'listing.' || p_action));
    return jsonb_build_object('ok', false, 'error', 'out_of_scope');
  end if;
  if p_action in ('reject', 'pause', 'remove', 'restore') and length(trim(coalesce(p_reason, ''))) < 8 then
    return jsonb_build_object('ok', false, 'error', 'reason_required');
  end if;
  v_new := case
    when p_action = 'approve' and v_l.status = 'pending_review' then 'published'
    when p_action = 'reject' and v_l.status = 'pending_review' then 'rejected'
    when p_action = 'pause' and v_l.status = 'published' then 'paused'
    when p_action = 'resume' and v_l.status = 'paused' then 'published'
    when p_action = 'remove' and v_l.status in ('published', 'paused') then 'archived'
    when p_action = 'restore' and v_l.status in ('rejected', 'archived') then 'pending_review' end;
  if v_new is null then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
  update public.listings set status = v_new, moderation_reason = nullif(trim(p_reason), ''),
    published_at = case when v_new = 'published' then coalesce(published_at, now()) else published_at end, updated_at = now()
   where id = p_listing;
  perform public.notify_org(v_l.organization_id, 'listing.' || p_action, 'Listing ' || v_new::text, v_l.title || coalesce(' — ' || p_reason, ''), 'listing', p_listing);
  perform public.write_audit('listing.' || p_action, 'listing', p_listing, p_reason,
                             case p_action when 'remove' then 'critical' when 'reject' then 'warn' else 'info' end);
  return jsonb_build_object('ok', true, 'status', v_new);
end $$;

------------------------------------------------------------------------------------------
-- 4. Payment reconciliation: status follows EXTERNAL evidence only
------------------------------------------------------------------------------------------
create function public.admin_reconcile_payment(
  p_payment uuid, p_decision text, p_amount numeric default null, p_currency text default null,
  p_reference text default null, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_p public.payment_records; v_order_status public.payment_status;
begin
  if not public.admin_guard('payments.reconcile', 'payment.reconcile', 'payment', p_payment) then
    return jsonb_build_object('ok', false, 'error', 'permission_denied');
  end if;
  if p_decision not in ('confirm', 'failed', 'reversed') then return jsonb_build_object('ok', false, 'error', 'unknown_decision'); end if;
  if length(trim(coalesce(p_reason, ''))) < 8 then return jsonb_build_object('ok', false, 'error', 'reason_required'); end if;
  select * into v_p from public.payment_records where id = p_payment for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_p.status = 'externally_confirmed' and p_decision = 'confirm' then return jsonb_build_object('ok', false, 'error', 'already_confirmed'); end if;

  if p_decision = 'confirm' then
    if p_reference is null or p_reference !~ '^[A-Za-z]{2,5}-[A-Za-z0-9-]{4,}$' then
      return jsonb_build_object('ok', false, 'error', 'reference_required');
    end if;
    if p_amount is null or p_amount <= 0 or p_currency is null then return jsonb_build_object('ok', false, 'error', 'amount_required'); end if;
    if p_amount <> v_p.expected_amount or p_currency <> v_p.currency_code then
      update public.payment_records set status = 'under_review', reconciliation = 'exception', updated_at = now() where id = p_payment;
      update public.orders set payment_status = 'under_review' where id = v_p.order_id;
      insert into public.payment_events (payment_id, kind, body, created_by)
      values (p_payment, 'recon', format('Mismatch: evidence shows %s %s vs expected %s %s — NOT confirmed.',
              p_currency, p_amount, v_p.currency_code, v_p.expected_amount), (select auth.uid()));
      perform public.write_audit('payment.recon_mismatch', 'payment', p_payment, p_reason, 'warn');
      return jsonb_build_object('ok', true, 'outcome', 'mismatch');
    end if;
    update public.payment_records set status = 'externally_confirmed', reconciliation = 'matched',
      provider_reference = upper(p_reference), updated_at = now() where id = p_payment;
    update public.orders set payment_status = 'externally_confirmed' where id = v_p.order_id;
    insert into public.payment_events (payment_id, kind, body, created_by)
    values (p_payment, 'recon', 'Confirmed against external reference ' || upper(p_reference), (select auth.uid()));
    perform public.write_audit('payment.reconcile_confirm', 'payment', p_payment, p_reason, 'critical');
    return jsonb_build_object('ok', true, 'outcome', 'confirmed');
  end if;

  update public.payment_records set status = p_decision, reconciliation = 'exception', updated_at = now() where id = p_payment;
  v_order_status := 'under_review';
  update public.orders set payment_status = v_order_status where id = v_p.order_id;
  insert into public.payment_events (payment_id, kind, body, created_by)
  values (p_payment, 'recon', 'Recorded as ' || p_decision, (select auth.uid()));
  perform public.write_audit('payment.reconcile_' || p_decision, 'payment', p_payment, p_reason, 'critical');
  return jsonb_build_object('ok', true, 'outcome', p_decision);
end $$;

------------------------------------------------------------------------------------------
-- 5. Order disputes (payment and fulfilment stay independent)
------------------------------------------------------------------------------------------
create function public.admin_order_action(p_order uuid, p_action text, p_outcome text default null, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_o public.orders; v_new public.order_status;
begin
  if not public.admin_guard('orders.investigate', 'order.' || coalesce(p_action, '?'), 'order', p_order) then
    return jsonb_build_object('ok', false, 'error', 'permission_denied');
  end if;
  if p_action not in ('open_dispute', 'resolve_dispute') then return jsonb_build_object('ok', false, 'error', 'unknown_action'); end if;
  if length(trim(coalesce(p_reason, ''))) < 8 then return jsonb_build_object('ok', false, 'error', 'reason_required'); end if;
  select * into v_o from public.orders where id = p_order for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if p_action = 'open_dispute' then
    if v_o.status in ('disputed', 'cancelled', 'awaiting_seller_confirmation') then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
    update public.orders set status = 'disputed', updated_at = now() where id = p_order;
    insert into public.delivery_events (order_id, event_type, note, created_by) values (p_order, 'exception', 'Dispute opened by Susu Luma: ' || left(p_reason, 800), (select auth.uid()));
    perform public.write_audit('order.dispute', 'order', p_order, p_reason, 'critical');
  else
    if v_o.status <> 'disputed' then return jsonb_build_object('ok', false, 'error', 'invalid_state'); end if;
    if p_outcome not in ('in_fulfilment', 'delivered', 'cancelled') then return jsonb_build_object('ok', false, 'error', 'outcome_invalid'); end if;
    v_new := p_outcome::public.order_status;
    update public.orders set status = v_new, updated_at = now(),
      payment_status = case when v_new = 'cancelled' and payment_status <> 'externally_confirmed' then 'not_applicable' else payment_status end
     where id = p_order;
    insert into public.delivery_events (order_id, event_type, note, created_by) values (p_order, 'exception', 'Dispute resolved (' || p_outcome || '): ' || left(p_reason, 800), (select auth.uid()));
    perform public.write_audit('order.dispute_resolve', 'order', p_order, p_reason, 'warn', jsonb_build_object('outcome', p_outcome));
  end if;
  perform public.notify_org(v_o.buyer_organization_id, 'order.dispute', 'Order dispute update', null, 'order', p_order);
  perform public.notify_org(v_o.supplier_organization_id, 'order.dispute', 'Order dispute update', null, 'order', p_order);
  return jsonb_build_object('ok', true);
end $$;

revoke all on function
  public.admin_verification_action(uuid, text, text, integer, text), public.admin_set_checklist(uuid, integer, boolean),
  public.admin_request_evidence_access(uuid, text), public.admin_moderate_listing(uuid, text, text),
  public.admin_reconcile_payment(uuid, text, numeric, text, text, text), public.admin_order_action(uuid, text, text, text)
from public, anon;
grant execute on function
  public.admin_verification_action(uuid, text, text, integer, text), public.admin_set_checklist(uuid, integer, boolean),
  public.admin_request_evidence_access(uuid, text), public.admin_moderate_listing(uuid, text, text),
  public.admin_reconcile_payment(uuid, text, numeric, text, text, text), public.admin_order_action(uuid, text, text, text)
to authenticated;
