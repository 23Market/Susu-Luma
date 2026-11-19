-- Synthetic personas; transaction rolls fixtures back.
begin;
do $$
declare
 u uuid := '99000000-0000-0000-0000-000000000001';
 v uuid := '99000000-0000-0000-0000-000000000002';
 w uuid := '99000000-0000-0000-0000-000000000003';
 a uuid := '99000000-0000-0000-0000-000000000004';
 b uuid; s uuid; other_org uuid; p uuid; p2 uuid; thr uuid; ticket uuid; msg uuid;
begin
 insert into auth.users(id,email) values(u,'module-b@test'),(v,'module-s@test'),(w,'module-x@test'),(a,'module-admin@test');
 insert into public.admin_users(user_id,role_code,display_name) values(a,'support','Module Support');
 perform t.login(u); b := public.create_organization('Module Buyer','Module Buyer','buyer','Bo',null); perform t.logout();
 perform t.login(v); s := public.create_organization('Module Supplier','Module Supplier','supplier','Bo',null); perform t.logout();
 perform t.login(w); other_org := public.create_organization('Module Other','Module Other','buyer','Bo',null); perform t.logout();
 insert into public.listings(organization_id,title,category,quantity_unit,status,created_by,district,availability)
 values(s,'Module discovery cement','construction','bag','published',v,'Bo','in_stock') returning id into p;
 insert into public.listings(organization_id,title,category,quantity_unit,status,created_by,district,availability)
 values(s,'Module discovery sand','construction','load','published',v,'Bo','out_of_stock') returning id into p2;
 perform t.login(u);
 perform t.ok((select count(*) from public.discover_listings('Module discovery','construction','Bo',null,null,1))=1,'discovery page limit');
 perform t.ok((select count(*) from public.discover_listings('Module discovery','construction','Bo','in_stock',null,20))=1,'availability filter');
 perform t.ok((select count(*) from public.discover_listings('Module discovery','construction','Kenema',null,null,20))=0,'district filter');
 perform t.ok((select count(*) from public.discover_listings('Module discovery',null,null,null,greatest(p,p2),20))=0,'cursor excludes earlier rows');
 perform public.set_saved_product(p,true); perform public.set_saved_product(p,true);
 perform t.ok((select count(*) from public.saved_products)=1,'saving is persistent and idempotent');
 thr := public.open_thread(b,s,null,'Module conversation');
 msg := public.send_message(thr,'Please confirm stock');
 ticket := public.create_support_case(b,'Delivery complaint','Please investigate this delivery',thr);
 perform public.reply_support_case(ticket,'Further details from the buyer',false);
 perform t.denied(format('select public.reply_support_case(%L,%L,true)',ticket,'Internal spoof'),'customer cannot create internal notes','not_permitted');
 perform t.logout();
 perform t.login(w);
 perform t.ok((select count(*) from public.saved_products)=0,'saved products isolated between accounts');
 perform t.ok((select count(*) from public.support_cases where id=ticket)=0,'support cases isolated');
 perform t.denied(format('select public.send_message(%L,%L)',thr,'Intruder'),'message send participant-only','not_permitted');
 perform t.denied(format('select public.set_thread_block(%L,true)',thr),'block participant-only','not_permitted');
 perform t.denied(format('select public.create_support_case(%L,%L,%L,null)',b,'Spoof case','Spoof description'),'cannot create case for another organization','not_permitted');
 perform t.logout();
 perform t.login(v); perform public.set_thread_block(thr,true); perform t.logout();
 perform t.login(u);
 perform t.denied(format('select public.send_message(%L,%L)',thr,'Blocked message'),'block prevents messages from either party','conversation_blocked');
 perform t.denied(format('select public.send_message(%L,%L)',thr,''),'empty message rejected','message_invalid');
 perform t.denied(format('select public.admin_transition_support_case(%L,%L,null,%L)',ticket,'resolved','Customer resolving own case'),'customers cannot resolve cases','not_permitted');
 perform t.logout();
 perform t.login(a,'aal1');
 perform t.denied(format('select public.admin_transition_support_case(%L,%L,null,%L)',ticket,'resolved','MFA not completed'),'staff requires MFA','not_permitted');
 perform t.logout();
 perform t.login(a,'aal2');
 perform public.admin_transition_support_case(ticket,'assigned',a,'Assigned to support reviewer');
 perform public.reply_support_case(ticket,'Private investigation note',true);
 perform public.reply_support_case(ticket,'We are investigating your complaint',false);
 perform public.admin_transition_support_case(ticket,'escalated',null,'Escalation requires investigation');
 perform public.admin_transition_support_case(ticket,'resolved',null,'Complaint investigated and resolved');
 perform t.ok((select status from public.support_cases where id=ticket)='resolved','staff assignment escalation resolution');
 perform t.logout();
 perform t.login(u);
 perform t.ok((select count(*) from public.support_replies where case_id=ticket)=2,'internal notes never leak to customer');
 perform public.set_saved_product(p,false);
 perform t.ok((select count(*) from public.saved_products)=0,'remove saved product');
 perform t.logout();
end $$;
rollback;
