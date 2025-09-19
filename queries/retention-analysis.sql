-- Player Retention & Cohort Analysis
-- Business Context: Analyzing player drop-off patterns to optimize onboarding
-- Key Metrics: D1/D7/D30 retention, cohort LTV, churn prediction

-- -- ============================================================================
-- PLAYER RETENTION & COHORT ANALYSIS
-- ============================================================================
-- Business Context: Analyzing player drop-off patterns to optimize onboarding
-- Key Metrics: D1/D7/D30 retention, cohort LTV, churn prediction
-- Author: Ana Trbić | Gaming Analytics Portfolio
-- ============================================================================

-- DATA MODEL ASSUMPTIONS:
-- players: player_id, install_date, platform, country, acquisition_source
-- sessions: session_id, player_id, session_date, session_duration_min
-- transactions: transaction_id, player_id, transaction_date, amount_usd

-- ============================================================================
-- 1. COHORT RETENTION ANALYSIS
-- ============================================================================

WITH player_install_cohorts AS (
    -- Define install cohorts by week
    SELECT 
        player_id,
        install_date,
        DATE_FORMAT(install_date, '%Y-%u') as install_week,
        platform,
        acquisition_source
    FROM players
),

player_activity AS (
    -- Track all player activity sessions
    SELECT 
        p.player_id,
        p.install_date,
        p.install_week,
        s.session_date,
        DATEDIFF(s.session_date, p.install_date) as days_since_install
    FROM player_install_cohorts p
    JOIN sessions s ON p.player_id = s.player_id
),

retention_metrics AS (
    -- Calculate retention flags for each player
    SELECT 
        player_id,
        install_date,
        install_week,
        MAX(CASE WHEN days_since_install = 1 THEN 1 ELSE 0 END) as returned_d1,
        MAX(CASE WHEN days_since_install = 7 THEN 1 ELSE 0 END) as returned_d7,
        MAX(CASE WHEN days_since_install = 30 THEN 1 ELSE 0 END) as returned_d30
    FROM player_activity
    GROUP BY player_id, install_date, install_week
)

-- FINAL COHORT RETENTION REPORT
SELECT 
    install_week,
    COUNT(DISTINCT rm.player_id) as cohort_size,
    
    -- Retention rates
    ROUND(AVG(returned_d1) * 100, 2) as d1_retention_pct,
    ROUND(AVG(returned_d7) * 100, 2) as d7_retention_pct,
    ROUND(AVG(returned_d30) * 100, 2) as d30_retention_pct,
    
    -- Absolute numbers
    SUM(returned_d1) as d1_retained_players,
    SUM(returned_d7) as d7_retained_players,
    SUM(returned_d30) as d30_retained_players

FROM retention_metrics rm
GROUP BY install_week
ORDER BY install_week DESC;

-- ============================================================================
-- 2. RETENTION BY ACQUISITION SOURCE
-- ============================================================================

SELECT 
    pic.acquisition_source,
    COUNT(DISTINCT pic.player_id) as total_players,
    
    -- Retention performance by source
    ROUND(AVG(rm.returned_d1) * 100, 2) as d1_retention_pct,
    ROUND(AVG(rm.returned_d7) * 100, 2) as d7_retention_pct,
    ROUND(AVG(rm.returned_d30) * 100, 2) as d30_retention_pct,
    
    -- Quality score (weighted retention)
    ROUND(
        (AVG(rm.returned_d1) * 0.3 + 
         AVG(rm.returned_d7) * 0.5 + 
         AVG(rm.returned_d30) * 0.2) * 100, 2
    ) as retention_quality_score

FROM player_install_cohorts pic
JOIN retention_metrics rm ON pic.player_id = rm.player_id
GROUP BY pic.acquisition_source
ORDER BY retention_quality_score DESC;

-- ============================================================================
-- 3. REVENUE-COHORT ANALYSIS
-- ============================================================================

WITH revenue_cohorts AS (
    SELECT 
        pic.player_id,
        pic.install_week,
        rm.returned_d7,
        rm.returned_d30,
        COALESCE(SUM(t.amount_usd), 0) as total_revenue,
        COUNT(t.transaction_id) as total_transactions
    FROM player_install_cohorts pic
    JOIN retention_metrics rm ON pic.player_id = rm.player_id
    LEFT JOIN transactions t ON pic.player_id = t.player_id
    GROUP BY pic.player_id, pic.install_week, rm.returned_d7, rm.returned_d30
)

SELECT 
    install_week,
    
    -- Revenue metrics
    ROUND(AVG(total_revenue), 2) as avg_revenue_per_user,
    ROUND(AVG(CASE WHEN total_revenue > 0 THEN total_revenue END), 2) as avg_revenue_per_payer,
    ROUND(AVG(CASE WHEN returned_d7 = 1 THEN total_revenue END), 2) as avg_revenue_d7_retained,
    
    -- Conversion rates
    ROUND(AVG(CASE WHEN total_revenue > 0 THEN 1 ELSE 0 END) * 100, 2) as conversion_rate_pct,
    
    -- Retention-Revenue correlation
    ROUND(AVG(CASE WHEN returned_d7 = 1 AND total_revenue > 0 THEN 1 ELSE 0 END) * 100, 2) as d7_payer_rate

FROM revenue_cohorts
GROUP BY install_week
ORDER BY install_week DESC;

-- ============================================================================
-- 4. CHURN RISK PREDICTION
-- ============================================================================

SELECT 
    pic.player_id,
    pic.install_date,
    DATEDIFF(CURRENT_DATE, MAX(s.session_date)) as days_since_last_session,
    COUNT(DISTINCT s.session_date) as total_session_days,
    AVG(s.session_duration_min) as avg_session_duration,
    COALESCE(SUM(t.amount_usd), 0) as total_spent,
    
    -- Churn risk classification
    CASE 
        WHEN DATEDIFF(CURRENT_DATE, MAX(s.session_date)) > 14 THEN 'High Risk'
        WHEN DATEDIFF(CURRENT_DATE, MAX(s.session_date)) > 7 THEN 'Medium Risk'
        WHEN DATEDIFF(CURRENT_DATE, MAX(s.session_date)) > 3 THEN 'Low Risk'
        ELSE 'Active'
    END as churn_risk_category

FROM player_install_cohorts pic
LEFT JOIN sessions s ON pic.player_id = s.player_id
LEFT JOIN transactions t ON pic.player_id = t.player_id
GROUP BY pic.player_id, pic.install_date
HAVING total_session_days > 0
ORDER BY days_since_last_session DESC, total_spent DESC;

-- ============================================================================
-- BUSINESS INSIGHTS SUMMARY
-- ============================================================================
-- 
-- KEY FINDINGS (Based on Analysis):
-- 1. Cohort retention trends identify best/worst performing install periods
-- 2. Acquisition source quality reveals optimal marketing channel allocation  
-- 3. Revenue-retention correlation shows LTV impact of retention improvements
-- 4. Churn risk segmentation enables proactive re-engagement campaigns
--
-- ACTIONABLE RECOMMENDATIONS:
-- - Focus marketing spend on highest-retention acquisition sources
-- - Implement targeted onboarding for cohorts with <X% D1 retention
-- - Deploy re-engagement campaigns for "Medium Risk" churn segment
-- - Optimize early monetization for D7+ retained players
--
-- ============================================================================
