-- Parties to an RFQ, order or conversation may read each other's organisation row (name, district).
-- Competing suppliers on the same RFQ still cannot see each other.
create function public.is_counterparty_org(p_org uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.rfqs r
                 where r.buyer_organization_id = p_org and public.rfq_recipient_member(r.id))
      or exists (select 1 from public.rfq_recipients rr
                 where rr.supplier_organization_id = p_org and public.rfq_buyer_member(rr.rfq_id))
      or exists (select 1 from public.orders o
                 where (o.buyer_organization_id = p_org and public.is_org_member(o.supplier_organization_id))
                    or (o.supplier_organization_id = p_org and public.is_org_member(o.buyer_organization_id)))
      or exists (select 1 from public.threads t
                 where (t.buyer_organization_id = p_org and public.is_org_member(t.supplier_organization_id))
                    or (t.supplier_organization_id = p_org and public.is_org_member(t.buyer_organization_id)))
$$;
revoke execute on function public.is_counterparty_org(uuid) from public, anon;
grant execute on function public.is_counterparty_org(uuid) to authenticated;
create policy organizations_read_counterparty on public.organizations
  for select to authenticated using (public.is_counterparty_org(id));
