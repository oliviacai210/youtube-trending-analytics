-- ============================================================================
-- videos_master.sql
-- ----------------------------------------------------------------------------
-- Fact table for the Tableau dashboard. One row per (video, region) with the
-- latest snapshot per video plus derived metrics (days_to_trending,
-- engagement_rate_pct, like_share_pct).
--
-- Grain:    1 row per (video_id, region)
-- Notes:    YouTube view counts are cumulative; day 5 of trending includes
--           day 1's views. We pick the latest snapshot per video via
--           ROW_NUMBER() rather than aggregating. The other queries in this
--           directory use MAX(views) explicitly to get peak metrics.
-- Used by:  Tableau "Days to Trending vs Peak Views" scatter, "Top 10
--           Trending Videos" bar, KPI tiles
-- Scan:     ~5 MB Parquet (partition pruning via region in downstream filters)
-- ============================================================================
WITH ranked AS (
    SELECT
        video_id,
        title,
        channel_title,
        category_id,
        snippet_title AS category_name,
        region,
        TRY(DATE_PARSE(trending_date, '%y.%d.%m'))                            AS trending_date,
        TRY(DATE_PARSE(SUBSTR(publish_time, 1, 19), '%Y-%m-%dT%H:%i:%s'))     AS publish_time,
        views,
        likes,
        dislikes,
        comment_count,
        tags,
        thumbnail_link,
        ratings_disabled,
        comments_disabled,
        -- Pick latest snapshot per video: most recent trending_date wins,
        -- with views as the tiebreaker (cumulative metric, higher = later).
        ROW_NUMBER() OVER (
            PARTITION BY video_id, region
            ORDER BY TRY(DATE_PARSE(trending_date, '%y.%d.%m')) DESC, views DESC
        ) AS rn
    FROM final_analytics
    WHERE video_error_or_removed = false
)
SELECT
    video_id,
    region,
    title,
    channel_title,
    category_id,
    category_name,
    publish_time,
    trending_date,
    DATE_DIFF('day', publish_time, trending_date)                             AS days_to_trending,
    views,
    likes,
    dislikes,
    comment_count,
    -- Engagement rate = (likes + comments) / views, as a percent
    CASE
        WHEN views > 0
            THEN ROUND(100.0 * (likes + comment_count) / views, 4)
    END                                                                       AS engagement_rate_pct,
    -- Share of positive reactions among rated users
    CASE
        WHEN (likes + dislikes) > 0
            THEN ROUND(100.0 * likes / (likes + dislikes), 2)
    END                                                                       AS like_share_pct,
    thumbnail_link
FROM ranked
WHERE rn = 1;
