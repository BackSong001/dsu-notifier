-- This migration is not applied yet.
-- The schema change to allow both pinned and regular versions is pending
-- review. The current unique constraint on (board_code, source_idx) remains.

-- The UI will be updated to show pinned notices in a separate section
-- while keeping the main list showing all notices sorted by (is_notice DESC, published_at DESC).