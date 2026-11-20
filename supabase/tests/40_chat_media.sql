-- Chat media (photos and voice notes). Runs after 10/20 on plain PostgreSQL, so it relies on their
-- personas: b1 = buyer owner, s1 = supplier owner, s2 and xx = people outside the thread.
-- Part 1 runs without a storage schema (existence check skipped); part 2 adds a minimal storage.objects
-- stand-in to prove the "object must really be uploaded" rule. Not meant for a real Supabase project.
do $$
declare
  b1 uuid := '00000000-0000-0000-0000-0000000000b1'; s1 uuid := '00000000-0000-0000-0000-0000000000a1';
  s2 uuid := '00000000-0000-0000-0000-0000000000a2'; xx uuid := '00000000-0000-0000-0000-0000000000ee';
  orgA uuid := (select organization_id from public.organization_memberships where user_id = '00000000-0000-0000-0000-0000000000b1' limit 1);
  orgS uuid := (select organization_id from public.organization_memberships where user_id = '00000000-0000-0000-0000-0000000000a1' limit 1);
  thr uuid; other uuid := gen_random_uuid(); m1 uuid; m2 uuid; n int;
  img text; vox text; stray text;
begin
  perform t.login(b1);
  thr := public.open_thread(orgA, orgS, null, 'Chat media test');
  perform t.logout();
  create temp table chat_media_ctx (thr uuid);
  insert into chat_media_ctx values (thr);
  img := thr::text || '/' || gen_random_uuid()::text || '.jpg';
  vox := thr::text || '/' || gen_random_uuid()::text || '.m4a';
  stray := other::text || '/' || gen_random_uuid()::text || '.jpg';

  ---------------------------------------------------------------- who may attach
  perform t.login(b1);
  perform t.ok(public.is_thread_member(thr), 'a thread member is recognised');
  m1 := public.send_media_message(thr, 'image', img, 'image/jpeg', 180000, null, 'Site photo');
  perform t.ok(m1 is not null, 'buyer can send a photo with a caption');
  perform t.logout();

  perform t.login(s1);
  m2 := public.send_media_message(thr, 'voice', vox, 'audio/mp4', 48000, 12);
  perform t.ok(m2 is not null, 'supplier can send a 12 second voice note without a caption');
  select count(*) into n from public.messages where thread_id = thr and attachment_kind is not null;
  perform t.ok(n = 2, 'both members see both attachment messages');
  perform t.logout();

  perform t.login(xx);
  perform t.ok(not public.is_thread_member(thr), 'an outsider is not a thread member');
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/jpeg', 1000, null)$q$, thr, img),
    'an outsider cannot attach to the thread', 'not_permitted');
  select count(*) into n from public.messages where thread_id = thr;
  perform t.ok(n = 0, 'an outsider cannot read the thread messages');
  perform t.logout();

  perform t.login(s2);
  perform t.denied(format($q$select public.send_media_message(%L, 'voice', %L, 'audio/mp4', 1000, 5)$q$, thr, vox),
    'another business cannot attach to the thread', 'not_permitted');
  perform t.logout();

  perform t.anon();
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/jpeg', 1000, null)$q$, thr, img),
    'signed-out callers cannot attach');
  perform t.logout();

  ---------------------------------------------------------------- server-side validation
  perform t.login(b1);
  perform t.denied(format($q$select public.send_media_message(%L, 'video', %L, 'video/mp4', 1000, 5)$q$, thr, img),
    'unknown media kind is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/jpeg', 5242881, null)$q$, thr, img),
    'photo over 5 MB is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/gif', 1000, null)$q$, thr, img),
    'photo with a disallowed type is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'audio/mp4', 1000, null)$q$, thr, img),
    'photo labelled as audio is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'voice', %L, 'audio/mp4', 1000, 61)$q$, thr, vox),
    'voice note over 60 seconds is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'voice', %L, 'audio/mp4', 1000, 0)$q$, thr, vox),
    'empty voice note is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'voice', %L, 'audio/mp4', 2097153, 30)$q$, thr, vox),
    'voice note over 2 MB is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'voice', %L, 'audio/mp4', 1000, null)$q$, thr, vox),
    'voice note without a duration is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/jpeg', 1000, null)$q$, thr, stray),
    'a file in another thread folder is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/jpeg', 1000, null)$q$, thr, thr::text || '/../x.jpg'),
    'path tricks are refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/jpeg', 1000, null)$q$, thr, thr::text || '/' || gen_random_uuid()::text || '.exe'),
    'unknown file extension is refused', 'media_invalid');
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/jpeg', 1000, null, %L)$q$, thr, img, repeat('x', 4001)),
    'caption over 4000 characters is refused', 'media_invalid');
  perform t.denied(format($q$insert into public.messages (thread_id, sender_user_id, sender_organization_id, body, attachment_kind, attachment_path, attachment_mime, attachment_bytes) values (%L, %L, %L, '', 'image', %L, 'image/jpeg', 10)$q$, thr, b1, orgA, img),
    'clients cannot insert message rows directly');
  perform t.logout();

  ---------------------------------------------------------------- row rules (as table owner)
  perform t.denied(format($q$insert into public.messages (thread_id, sender_user_id, sender_organization_id, body) values (%L, %L, %L, '   ')$q$, thr, b1, orgA),
    'a text message still cannot be empty', 'messages_content_check');
  perform t.denied(format($q$insert into public.messages (thread_id, sender_user_id, sender_organization_id, body, attachment_kind, attachment_path, attachment_mime, attachment_bytes, attachment_seconds) values (%L, %L, %L, '', 'voice', 'p', 'audio/mp4', 10, 0)$q$, thr, b1, orgA),
    'a voice row needs a duration of 1 to 60 seconds', 'messages_content_check');
  perform t.denied(format($q$insert into public.messages (thread_id, sender_user_id, sender_organization_id, body, attachment_path) values (%L, %L, %L, 'hello', 'stray/path.jpg')$q$, thr, b1, orgA),
    'attachment columns cannot be half-filled', 'messages_content_check');
end $$;

-- Part 2: with a storage stand-in, the object must exist before the message is accepted.
do $$
declare
  b1 uuid := '00000000-0000-0000-0000-0000000000b1';
  orgA uuid := (select organization_id from public.organization_memberships where user_id = '00000000-0000-0000-0000-0000000000b1' limit 1);
  orgS uuid := (select organization_id from public.organization_memberships where user_id = '00000000-0000-0000-0000-0000000000a1' limit 1);
  thr uuid; img text; m uuid;
begin
  if to_regclass('storage.objects') is null then
    create schema if not exists storage;
    create table storage.objects (bucket_id text not null, name text not null);
    grant usage on schema storage to authenticated;
  end if;
  select c.thr into thr from chat_media_ctx c;
  img := thr::text || '/' || gen_random_uuid()::text || '.png';

  perform t.login(b1);
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/png', 1000, null)$q$, thr, img),
    'a message is refused when the file was never uploaded', 'media_not_uploaded');
  perform t.logout();

  insert into storage.objects (bucket_id, name) values ('chat-media', img);
  perform t.login(b1);
  m := public.send_media_message(thr, 'image', img, 'image/png', 1000, null);
  perform t.ok(m is not null, 'a message is accepted once the file exists in the chat-media bucket');
  perform t.logout();

  insert into storage.objects (bucket_id, name) values ('evidence', thr::text || '/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa.png');
  perform t.login(b1);
  perform t.denied(format($q$select public.send_media_message(%L, 'image', %L, 'image/png', 1000, null)$q$, thr, thr::text || '/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa.png'),
    'a file in a different bucket does not count', 'media_not_uploaded');
  perform t.logout();
end $$;
