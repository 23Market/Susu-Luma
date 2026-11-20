# Chat media: photos and voice notes (DRAFT, not approved)

Owner decision D9 (17 Nov): "Keep it local with voice notes and English as the official. Simplistic like WhatsApp."
This change adds **photos** and **voice notes** to buyer/supplier messages. It is a draft for review.
It is **not** applied to any shared or production database and carries **no G0/G1/G2 approval**.

## What people see
- In a chat: a photo button, a microphone button, and send.
- Photo: pick from gallery or take one. Shrunk on the phone (max 1600 px, quality 80) to save data.
- Voice note: tap the microphone, record, then send or cancel. Stops by itself at 60 seconds.
- Bubbles show the photo (tap to enlarge) or a play/stop button with the length.
- The conversation list shows "Photo" or "Voice note" when there is no text.

## Limits (checked on the phone and again on the server)
| | Limit |
|---|---|
| Photo type | JPEG, PNG, WebP (read from the file bytes, not the name) |
| Photo size | 5 MB |
| Voice note length | 1 to 60 seconds |
| Voice note size | 2 MB |
| Caption | optional, up to 4000 characters |

## Security design
- Files go to a **private** storage bucket `chat-media`, path `<thread id>/<random uuid>.<ext>`.
- Only members of the thread's two organisations can upload to or read from that folder (storage policies).
- There is **no update or delete policy**: nobody can overwrite or remove a sent file from the app.
- Clients cannot insert messages directly. `send_media_message` re-checks membership, kind, type, size,
  duration, path shape, and (where Supabase storage exists) that the file was really uploaded.
- Photos are shown through short-lived signed links (1 hour, reused for 45 minutes).
- No service-role key is used or needed in the app.

## Evidence (real results only)
- SQL: `supabase/tests/40_chat_media.sql`, 27 assertions. Run locally on PostgreSQL 16 together with all
  existing SQL tests: **ALL SQL TESTS PASSED**. CI runs the same suite.
- App: unit, widget and live-store tests in `test/chat_media_test.dart` and `test/live_store_test.dart`.
  Results are posted on the PR from CI (no Flutter SDK is available where this was written).
- Not tested: a real phone, a real microphone/camera, a real Supabase project, real storage policies
  (CI uses plain PostgreSQL, so the storage policy block is skipped there).

## Open decisions and gates (nobody has signed these)
1. **Security/Legal review** of storing photos and voice recordings of business users in Sierra Leone.
2. **Retention (D10):** how long files are kept, and who may delete. Nothing deletes files today.
3. **Moderation and reporting:** abuse/illegal-content handling. PR #85 adds block and rate-limit for text
   messages. **Merge PR #85 first, then add the same block and rate-limit checks to `send_media_message`.**
   Until then a blocked thread could still receive media if this migration were applied.
4. **Independent database/security reviewer** (none named). Passing CI is not independent approval.
5. **Approved Luma-only Supabase dev project** to try it end to end (cost owner and secret custodian).
6. Krio: voice notes carry whatever language the speaker uses. No transcription or translation is offered.

## Merge order and conflicts
- Touches `lib/screens/common.dart` (ChatScreen) and `lib/models.dart`, like PR #85 and PR #83.
  Expect small, mechanical conflicts; rebase after #85.
- Android: adds `INTERNET` (release builds had none, so live mode could not connect) and `RECORD_AUDIO`.
- New packages: `image_picker`, `record`, `audioplayers`, `path_provider`.
