-- Extra records left in the database after the access tests so tools (and the live-mode UI test) have
-- something to act on: a pending listing, an open verification dossier, a payable order in fulfilment.
do $$
declare
  s1 uuid := '00000000-0000-0000-0000-0000000000a1'; b1 uuid := '00000000-0000-0000-0000-0000000000b1';
  orgS uuid := (select organization_id from public.organization_memberships where user_id = '00000000-0000-0000-0000-0000000000a1' limit 1);
  orgA uuid := (select organization_id from public.organization_memberships where user_id = '00000000-0000-0000-0000-0000000000b1' limit 1);
  s3 uuid := '00000000-0000-0000-0000-0000000000a3'; orgU uuid;
  lst uuid; rfq uuid; item uuid; q uuid; ord uuid; ver uuid;
begin
  insert into auth.users (id, email) values (s3, 's3@t');
  perform t.login(s3);
  orgU := public.create_organization('U Agro Cooperative','U Agro Cooperative','supplier','Bo','Bo Town');
  perform public.submit_verification(orgU, 'Business registration', array[orgU::text || '/coop-registration.pdf']);
  perform t.logout();
  perform t.login(s1);
  insert into public.listings (organization_id, title, category, quantity_unit, price_mode, created_by)
    values (orgS, 'Concrete mixer 350 L', 'equipment', 'unit', 'quote_only', s1) returning id into lst;
  -- equipment is a pre-moderated category, so this lands in the moderation queue
  perform public.submit_listing_for_review(lst);
  perform t.logout();
  perform t.login(b1);
  rfq := public.create_rfq(orgA, 'Western Area Urban', 'Aberdeen', current_date + 20, null,
          jsonb_build_array(jsonb_build_object('listing_id', null, 'product_title', 'Iron rods 12 mm', 'quantity', 80, 'quantity_unit', 'length')), array[orgS]);
  perform t.logout();
  select id into item from public.rfq_items where rfq_id = rfq;
  perform t.login(s1);
  q := public.submit_quote(rfq, orgS, 'SLE', 5, now() + interval '10 days', null, null, jsonb_build_array(jsonb_build_object('rfq_item_id', item, 'unit_price', 185)));
  perform t.logout();
  perform t.login(b1); ord := public.accept_quote(q); perform t.logout();
  perform t.login(s1); perform public.confirm_order(ord); perform public.add_delivery_event(ord, 'dispatched', 'Truck left', null, null, null); perform t.logout();
end $$;
