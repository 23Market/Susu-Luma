-- Owners may submit drafts for review, but cannot publish or impersonate admins.
drop policy listing_insert_member on public.listings;
create policy listing_insert_member on public.listings
  for insert to authenticated with check (
    created_by = (select auth.uid())
    and status in ('draft', 'pending_review')
    and published_at is null
    and exists (
      select 1 from public.organization_memberships m
      where m.organization_id = listings.organization_id
        and m.user_id = (select auth.uid())
        and m.member_role in ('owner', 'admin', 'seller')
    )
  );

-- Onboarding must create an organization and owner membership atomically.
-- Disable the partial client path until an authorized transactional RPC exists.
drop policy organization_create_self on public.organizations;
