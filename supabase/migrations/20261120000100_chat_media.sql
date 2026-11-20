-- Chat media: photos and voice notes inside buyer/supplier threads.
--
-- NOT APPLIED to any shared or production database by this change. It runs only in CI (plain PostgreSQL)
-- and on a local database until the independent database/security review and Security/Legal sign-off
-- recorded in docs/CHAT_MEDIA.md are complete.
--
-- Design:
--   * Files live in a PRIVATE storage bucket, keyed '<thread_id>/<uuid>.<ext>'. Only members of the
--     thread's two organisations can upload to or read from that folder. No update/delete policy exists,
--     so clients cannot overwrite or remove evidence of what was sent.
--   * The message row carries the metadata. Clients cannot insert messages directly (existing revoke);
--     they call send_media_message, which re-checks membership, kind, MIME type, size, duration, path
--     shape and (where the storage schema exists) that the object was really uploaded.
--   * Retention, moderation and reporting rules are open decisions (see docs/CHAT_MEDIA.md).

alter table public.messages
  add column attachment_kind text check (attachment_kind in ('image', 'voice')),
  add column attachment_path text,
  add column attachment_mime text,
  add column attachment_bytes integer,
  add column attachment_seconds integer;

-- Text messages keep the old rule (1..4000 characters). Attachment messages may have an empty caption.
alter table public.messages drop constraint if exists messages_body_check;
alter table public.messages add constraint messages_content_check check (
  (attachment_kind is null and attachment_path is null and attachment_mime is null
     and attachment_bytes is null and attachment_seconds is null
     and length(trim(body)) between 1 and 4000)
  or
  (attachment_kind is not null and attachment_path is not null and attachment_mime is not null
     and length(body) <= 4000
     and ((attachment_kind = 'image' and attachment_seconds is null
             and attachment_bytes between 1 and 5242880)
       or (attachment_kind = 'voice' and attachment_seconds between 1 and 60
             and attachment_bytes between 1 and 2097152)))
);

create function public.is_thread_member(p_thread uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.threads t
     where t.id = p_thread
       and (public.is_org_member(t.buyer_organization_id) or public.is_org_member(t.supplier_organization_id)))
$$;

create function public.send_media_message(
  p_thread uuid, p_kind text, p_path text, p_mime text, p_bytes integer, p_seconds integer,
  p_caption text default ''
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_t public.threads; v_org uuid; v_id uuid; v_found boolean;
begin
  select * into v_t from public.threads where id = p_thread;
  if not found then raise exception 'not_permitted' using errcode = '42501'; end if;
  v_org := case when public.is_org_member(v_t.buyer_organization_id) then v_t.buyer_organization_id
                when public.is_org_member(v_t.supplier_organization_id) then v_t.supplier_organization_id end;
  if v_org is null then raise exception 'not_permitted' using errcode = '42501'; end if;

  if p_kind is null or p_kind not in ('image', 'voice')
     or p_mime is null or p_bytes is null or p_path is null
     or length(coalesce(p_caption, '')) > 4000 then
    raise exception 'media_invalid' using errcode = '22023';
  end if;
  if p_kind = 'image' and (p_mime not in ('image/jpeg', 'image/png', 'image/webp')
                           or p_bytes not between 1 and 5242880 or p_seconds is not null) then
    raise exception 'media_invalid' using errcode = '22023';
  end if;
  if p_kind = 'voice' and (p_mime not in ('audio/mp4', 'audio/aac', 'audio/webm', 'audio/ogg')
                           or p_bytes not between 1 and 2097152
                           or p_seconds is null or p_seconds not between 1 and 60) then
    raise exception 'media_invalid' using errcode = '22023';
  end if;
  -- The object must sit in this thread's own folder, with a generated name and a known extension.
  if p_path !~ ('^' || p_thread::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp|m4a|webm|ogg)$') then
    raise exception 'media_invalid' using errcode = '22023';
  end if;
  -- Where Supabase storage exists, the file must really have been uploaded to the private bucket.
  if to_regclass('storage.objects') is not null then
    execute 'select exists (select 1 from storage.objects where bucket_id = $1 and name = $2)'
      into v_found using 'chat-media', p_path;
    if not v_found then raise exception 'media_not_uploaded' using errcode = '22023'; end if;
  end if;

  insert into public.messages (thread_id, sender_user_id, sender_organization_id, body,
                               attachment_kind, attachment_path, attachment_mime, attachment_bytes, attachment_seconds)
  values (p_thread, (select auth.uid()), v_org, trim(coalesce(p_caption, '')),
          p_kind, p_path, p_mime, p_bytes, p_seconds)
  returning id into v_id;
  perform public.notify_org(
    case when v_org = v_t.buyer_organization_id then v_t.supplier_organization_id else v_t.buyer_organization_id end,
    'message.received', 'New message', case p_kind when 'image' then 'Photo' else 'Voice note' end,
    'thread', p_thread);
  return v_id;
end $$;

revoke all on function public.is_thread_member(uuid),
  public.send_media_message(uuid, text, text, text, integer, integer, text) from public, anon;
grant execute on function public.is_thread_member(uuid),
  public.send_media_message(uuid, text, text, text, integer, integer, text) to authenticated;

-- Private bucket + policies. Skipped automatically where the Supabase storage schema does not exist
-- (plain PostgreSQL CI), exactly like the evidence bucket migration.
do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice 'storage schema not present; skipping chat-media bucket';
    return;
  end if;

  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('chat-media', 'chat-media', false, 5242880,
          array['image/jpeg', 'image/png', 'image/webp', 'audio/mp4', 'audio/aac', 'audio/webm', 'audio/ogg'])
  on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

  create policy chat_media_member_upload on storage.objects for insert to authenticated
    with check (bucket_id = 'chat-media'
      and case when (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
               then public.is_thread_member(((storage.foldername(name))[1])::uuid) else false end);
  create policy chat_media_member_read on storage.objects for select to authenticated
    using (bucket_id = 'chat-media'
      and case when (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
               then public.is_thread_member(((storage.foldername(name))[1])::uuid) else false end);
end $$;
