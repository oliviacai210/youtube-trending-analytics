-- ============================================================================
-- top_channels.sql
-- ----------------------------------------------------------------------------
-- Top channels per region by total peak views. We compute peak per video
-- first (cumulative metric semantics), then aggregate to channel level.
-- Filtered to channels with at least 2 trending appearances to reduce noise
-- from one-hit videos.
--
-- Grain:    1 row per (channel_title, region)
-- Used by:  Tableau "Top 10 Channels" bar
-- Scan:     ~5 MB Parquet
-- ============================================================================
WITH video_peak AS (
    SELECT
        video_id,
        region,
        channel_title,
        MAX(views)         AS peak_views,
        MAX(likes)         AS peak_likes,
        MAX(comment_count) AS peak_comments
    FROM final_analytics
    WHERE video_error_or_removed = false
    GROUP BY video_id, region, channel_title
)
SELECT
    channel_title,
    region,
    COUNT(*)                                                                  AS trending_videos,
    SUM(peak_views)                                                           AS total_views,
    ROUND(AVG(peak_views), 0)                                                 AS avg_views_per_video,
    ROUND(AVG(peak_likes), 0)                                                 AS avg_likes_per_video
FROM video_peak
GROUP BY channel_title, region
HAVING COUNT(*) >= 2          -- only channels with 2+ trending appearances
ORDER BY total_views DESC
LIMIT 200;
