-- Private storage for verification and delivery evidence. Skipped automatically where the Supabase
-- storage schema does not exist (e.g. plain PostgreSQL CI). Objects are keyed '<organization_id>/<file>'.
do $$
begin
  if to_regclass('storage.buckets') is null then
    raise notice 'storage schema not present; skipping storage policies';
    return;
  end if;

  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('evidence', 'evidence', false, 10485760, array['application/pdf', 'image/jpeg', 'image/png'])
  on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

  -- Members of an organisation may upload and read under their own prefix.
  create policy evidence_member_upload on storage.objects for insert to authenticated
    with check (bucket_id = 'evidence'
      and public.is_org_member(((storage.foldername(name))[1])::uuid, array['owner', 'admin', 'seller']));
  create policy evidence_member_read on storage.objects for select to authenticated
    using (bucket_id = 'evidence' and public.is_org_member(((storage.foldername(name))[1])::uuid));
  -- Staff need an MFA session and the evidence permission (and the access is logged by admin_request_evidence_access).
  create policy evidence_admin_read on storage.objects for select to authenticated
    using (bucket_id = 'evidence' and (public.has_admin_permission('verification.evidence.view')
                                       or public.has_admin_permission('payments.evidence.view')
                                       or public.has_admin_permission('fulfilment.evidence.view')));
end $$;
