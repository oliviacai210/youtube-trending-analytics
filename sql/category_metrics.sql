-- ============================================================================
-- category_metrics.sql
-- ----------------------------------------------------------------------------
-- Pre-aggregated metrics by region × category. We compute peak metrics per
-- video first (MAX of cumulative columns), then average across videos within
-- each category to avoid double-counting cumulative growth across snapshots.
--
-- Grain:    1 row per (region, category_name)
-- Used by:  Tableau "Category Heatmap" + per-category drilldowns
-- Scan:     ~5 MB Parquet
-- ============================================================================
WITH video_peak AS (
    SELECT
        video_id,
        region,
        snippet_title AS category_name,
        MAX(views)         AS peak_views,
        MAX(likes)         AS peak_likes,
        MAX(dislikes)      AS peak_dislikes,
        MAX(comment_count) AS peak_comments
    FROM final_analytics
    WHERE video_error_or_removed = false
    GROUP BY video_id, region, snippet_title
)
SELECT
    region,
    category_name,
    COUNT(*)                                                                  AS num_videos,
    SUM(peak_views)                                                           AS total_views,
    ROUND(AVG(peak_views), 0)                                                 AS avg_views,
    ROUND(AVG(peak_likes), 0)                                                 AS avg_likes,
    ROUND(AVG(peak_comments), 0)                                              AS avg_comments,
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
GROUP BY region, category_name
ORDER BY region, total_views DESC;
