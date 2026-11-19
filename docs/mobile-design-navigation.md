# Mobile design and navigation update

- Buyer and supplier headers identify the selected workspace and business.
- Main workspace content is centered and limited to 960 logical pixels on wide screens.
- Category tiles allow two lines and additional space rather than truncating names to one line.
- Discovery retains its text controller across tab changes; a single clear action resets query and category.
- Empty search results provide a Show all products action; the keyboard Search action dismisses the keyboard.
- Listing counts distinguish live mode from the sample demo.

Verification: narrow-screen tab continuity and search recovery widget tests are included. CI must pass before demo publication. No local Flutter pass is claimed because command execution is unavailable in this session.

Publication: merge only the reviewed, passing candidate into main. The existing GitHub Pages workflow builds demo mode without Supabase credentials and publishes /app/ and /admin/. No live backend or payment integration is enabled by this change.
