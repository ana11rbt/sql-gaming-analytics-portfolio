-- ============================================================================
-- PLAYER RETENTION ANALYSIS 
-- ============================================================================
-- Business Context: Analyzing player drop-off patterns to optimize onboarding
-- Data Source: Simulated gaming industry data based on mobile gaming benchmarks  
-- Author: Ana Trbić | Gaming Analytics Portfolio
-- ============================================================================

-- DATA MODEL:
-- players: player_id, install_date, platform, country, acquisition_source
-- sessions: session_id, player_id, session_date, session_duration_min
-- transactions: transaction_id, player_id, transaction_date, amount_usd

-- ============================================================================
-- 1. MONTHLY RETENTION OVERVIEW
-- ============================================================================

SELECT 
    DATE_FORMAT(p.install_date, '%Y-%m') as install_month,
    COUNT(DISTINCT p.player_id) as total_installs,
    
    -- Players who returned on Day 1
    COUNT(DISTINCT CASE 
        WHEN DATEDIFF(s.session_date, p.install_date) = 1 
        THEN p.player_id 
    END) as d1_returning_players,
    
    -- Players who returned on Day 7
    COUNT(DISTINCT CASE 
        WHEN DATEDIFF(s.session_date, p.install_date) = 7 
        THEN p.player_id 
    END) as d7_returning_players,
    
    -- Retention percentages
    ROUND(
        COUNT(DISTINCT CASE WHEN DATEDIFF(s.session_date, p.install_date) = 1 THEN p.player_id END) * 100.0 
        / COUNT(DISTINCT p.player_id), 2
    ) as d1_retention_pct,
    
    ROUND(
        COUNT(DISTINCT CASE WHEN DATEDIFF(s.session_date, p.install_date) = 7 THEN p.player_id END) * 100.0 
        / COUNT(DISTINCT p.player_id), 2
    ) as d7_retention_pct

FROM players p
LEFT JOIN sessions s ON p.player_id = s.player_id
GROUP BY DATE_FORMAT(p.install_date, '%Y-%m')
ORDER BY install_month DESC;

-- ============================================================================
-- 2. ACQUISITION SOURCE PERFORMANCE
-- ============================================================================

SELECT 
    p.acquisition_source,
    COUNT(DISTINCT p.player_id) as total_players,
    
    -- Week 1 activity (Days 1-7)
    COUNT(DISTINCT CASE 
        WHEN DATEDIFF(s.session_date, p.install_date) BETWEEN 1 AND 7 
        THEN p.player_id 
    END) as week1_active_players,
    
    -- Week 1 retention rate
    ROUND(
        COUNT(DISTINCT CASE WHEN DATEDIFF(s.session_date, p.install_date) BETWEEN 1 AND 7 THEN p.player_id END) * 100.0 
        / COUNT(DISTINCT p.player_id), 2
    ) as week1_retention_pct,
    
    -- Average sessions in first week
    ROUND(
        COUNT(CASE WHEN DATEDIFF(s.session_date, p.install_date) BETWEEN 0 AND 7 THEN s.session_id END) * 1.0
        / COUNT(DISTINCT p.player_id), 1
    ) as avg_sessions_week1

FROM players p
LEFT JOIN sessions s ON p.player_id = s.player_id
GROUP BY p.acquisition_source
ORDER BY week1_retention_pct DESC;

-- ============================================================================
-- 3. REVENUE CORRELATION WITH RETENTION
-- ============================================================================

SELECT 
    -- Player retention segments
    CASE 
        WHEN MAX(DATEDIFF(s.session_date, p.install_date)) >= 30 THEN '30+ Day Players'
        WHEN MAX(DATEDIFF(s.session_date, p.install_date)) >= 7 THEN '7-29 Day Players'
        WHEN MAX(DATEDIFF(s.session_date, p.install_date)) >= 1 THEN '1-6 Day Players'
        ELSE 'Day 0 Only'
    END as retention_segment,
    
    COUNT(DISTINCT p.player_id) as total_players,
    COUNT(DISTINCT t.player_id) as paying_players,
    COALESCE(SUM(t.amount_usd), 0) as total_revenue,
    
    -- Key metrics
    ROUND(COALESCE(SUM(t.amount_usd), 0) / COUNT(DISTINCT p.player_id), 2) as revenue_per_user,
    ROUND(COUNT(DISTINCT t.player_id) * 100.0 / COUNT(DISTINCT p.player_id), 2) as conversion_rate_pct

FROM players p
LEFT JOIN sessions s ON p.player_id = s.player_id
LEFT JOIN transactions t ON p.player_id = t.player_id
GROUP BY retention_segment
ORDER BY revenue_per_user DESC;

-- ============================================================================
-- 4. CHURN RISK IDENTIFICATION
-- ============================================================================

SELECT 
    p.player_id,
    p.install_date,
    p.acquisition_source,
    MAX(s.session_date) as last_session_date,
    DATEDIFF(CURRENT_DATE, MAX(s.session_date)) as days_since_last_session,
    COUNT(DISTINCT s.session_date) as total_active_days,
    COALESCE(SUM(t.amount_usd), 0) as total_revenue,
    
    -- Risk classification
    CASE 
        WHEN DATEDIFF(CURRENT_DATE, MAX(s.session_date)) > 30 THEN 'Churned'
        WHEN DATEDIFF(CURRENT_DATE, MAX(s.session_date)) > 14 THEN 'High Risk'
        WHEN DATEDIFF(CURRENT_DATE, MAX(s.session_date)) > 7 THEN 'Medium Risk'
        ELSE 'Active'
    END as churn_risk_level

FROM players p
LEFT JOIN sessions s ON p.player_id = s.player_id
LEFT JOIN transactions t ON p.player_id = t.player_id
GROUP BY p.player_id, p.install_date, p.acquisition_source
HAVING COUNT(s.session_id) > 0  -- Only players with at least one session
ORDER BY total_revenue DESC, days_since_last_session ASC;

-- ============================================================================
-- BUSINESS INSIGHTS & RECOMMENDATIONS
-- ============================================================================
--
-- Key Questions Answered:
-- 1. Which install periods show strongest/weakest retention trends?
-- 2. Which acquisition sources deliver highest-quality long-term players?
-- 3. How does player retention correlate with monetization success?
-- 4. Which players are at risk of churning and need re-engagement?
--
-- Actionable Recommendations:
-- • Reallocate marketing budget toward acquisition sources with highest Week 1 retention
-- • Implement onboarding improvements for install cohorts showing <X% D1 retention  
-- • Deploy targeted re-engagement campaigns for "Medium Risk" and "High Risk" players
-- • Analyze behavioral differences between "30+ Day Players" and shorter-term segments
-- • Focus early monetization efforts on players showing strong engagement patterns
--
-- Business Impact:
-- • Improved retention rates directly increase player LTV and reduce acquisition costs
-- • Churn prediction enables proactive retention campaigns vs reactive measures
-- • Acquisition source optimization maximizes ROI on marketing spend
-- ============================================================================
