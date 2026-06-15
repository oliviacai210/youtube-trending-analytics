-- ============================================================================
-- country_summary.sql
-- ----------------------------------------------------------------------------
-- KPI tile data: unique videos, total views, average views/likes, and average
-- engagement rate per region. Peak metrics computed per video before
-- aggregation (cumulative metric semantics).
--
-- Grain:    1 row per region
-- Used by:  Tableau KPI tiles (Trending Videos Analyzed, Total Views, Avg
--           Engagement Rate, Countries Covered) and the "Country Comparison"
--           bar charts
-- Scan:     ~5 MB Parquet
-- ============================================================================
WITH video_peak AS (
    SELECT
        video_id,
        region,
        MAX(views)         AS peak_views,
        MAX(likes)         AS peak_likes,
        MAX(comment_count) AS peak_comments
    FROM final_analytics
    WHERE video_error_or_removed = false
    GROUP BY video_id, region
)
SELECT
    region,
    COUNT(DISTINCT video_id)                                                  AS unique_videos,
    SUM(peak_views)                                                           AS total_views,
    ROUND(AVG(peak_views), 0)                                                 AS avg_views,
    ROUND(AVG(peak_likes), 0)                                                 AS avg_likes,
    ROUND(
        AVG(
            CASE
                WHEN peak_views > 0
                    THEN 100.0 * (peak_likes + peak_comments) / peak_views
            END
        ),
        4
    )                                                                         AS avg_engagement_rate_pct
FROM video_peak
GROUP BY region
ORDER BY total_views DESC;
