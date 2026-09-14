-- The approved photo feed (PhotoFeedService) subscribes to `media` so a
-- photo released by the office in the internal approval view shows up on a
-- homeowner's phone without them reopening the app.
--
-- Realtime respects RLS, and `media_self` already requires
-- approved_for_customer = true, so a crew-only row never reaches a client
-- even though the table is in the publication.
--
-- REPLICA IDENTITY FULL is required for UPDATE events here: approval is an
-- UPDATE flipping approved_for_customer, and under the default replica
-- identity the old row image carries only the primary key, which is not
-- enough for Realtime to evaluate the RLS policy against the change.
alter publication supabase_realtime add table public.media;
alter table public.media replica identity full;
