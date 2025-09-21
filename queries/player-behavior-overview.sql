-- ============================================================================
-- GAMING ANALYTICS - PLAYER BEHAVIOR ANALYSIS
-- ============================================================================
-- Business Context: Understanding player demographics, engagement, and revenue patterns
-- Data Source: Simulated gaming data based on industry experience
-- Author: Ana Rajić | Gaming Analytics Portfolio
-- ============================================================================

-- DATA MODEL:
-- players: player_id, install_date, platform, country, acquisition_source
-- sessions: session_id, player_id, session_date, session_duration_min
-- transactions: transaction_id, player_id, transaction_date, amount_usd

-- ============================================================================
-- 1. PLAYER DEMOGRAPHICS OVERVIEW
-- ============================================================================

SELECT 
    COUNT(DISTINCT player_id) as total_players,
    COUNT(DISTINCT platform) as platforms_used,
    COUNT(DISTINCT country) as countries,
    COUNT(DISTINCT acquisition_source) as marketing_channels,
    MIN(install_date) as first_install,
    MAX(install_date) as most_recent_install
FROM dbo.players;

-- ============================================================================
-- 2. PLATFORM DISTRIBUTION ANALYSIS
-- ============================================================================

SELECT platform,
	COUNT(*) AS player_count
FROM dbo.players
GROUP BY platform
ORDER BY player_count DESC;

-- ============================================================================
-- 3. ACQUISITION SOURCE PERFORMANCE
-- ============================================================================

SELECT 
    acquisition_source,
    COUNT(*) as total_players,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM players), 2) as percentage_share
FROM players
GROUP BY acquisition_source
ORDER BY total_players DESC;

-- ============================================================================
-- 4. PLAYER ENGAGEMENT ANALYSIS
-- ============================================================================

SELECT 
	p.player_id,
	p.platform,
	p.acquisition_source,
	COUNT(s.session_id) AS total_sessions,
	ROUND(AVG(s.session_duration_min), 1) AS avg_session_duration,
	MIN(s.session_date) AS first_session,
	MAX(s.session_date) AS last_session,
	DATEDIFF(DAY, MIN(s.session_date), MAX(s.session_date)) AS days_active
FROM dbo.players p
JOIN dbo.sessions s ON p.player_id = s.player_id
GROUP BY p.player_id, p.platform, p.acquisition_source
ORDER BY total_sessions DESC, avg_session_duration DESC;

-- ============================================================================
-- 5. REVENUE ANALYSIS BY PLAYER
-- ============================================================================

SELECT 
    p.player_id,
    p.platform,
    p.acquisition_source,
    COUNT(t.transaction_id) as total_purchases,
    COALESCE(SUM(t.amount_usd), 0) as total_revenue,
    CASE 
        WHEN SUM(t.amount_usd) > 0 THEN 'Paying Player'
        ELSE 'Free Player'
    END as player_type
FROM players p
LEFT JOIN transactions t ON p.player_id = t.player_id
GROUP BY p.player_id, p.platform, p.acquisition_source
ORDER BY total_revenue DESC;

-- ============================================================================
-- 6. PLATFORM VS REVENUE COMPARISON
-- ============================================================================

SELECT 
    p.platform,
    COUNT(DISTINCT p.player_id) AS total_players,
    COUNT(DISTINCT t.player_id) AS paying_players,
    COALESCE(SUM(t.amount_usd), 0) AS total_revenue,
    ROUND(COALESCE(SUM(t.amount_usd), 0) / COUNT(DISTINCT p.player_id), 2) AS revenue_per_user,
    ROUND(CAST(COUNT(DISTINCT t.player_id) AS FLOAT) * 100.0 / COUNT(DISTINCT p.player_id), 2) AS conversion_rate_pct
FROM dbo.players p
LEFT JOIN dbo.transactions t ON p.player_id = t.player_id
GROUP BY p.platform
ORDER BY revenue_per_user DESC;

-- ============================================================================
-- 7. ACQUISITION SOURCE QUALITY
-- ============================================================================

SELECT
	p.acquisition_source,
	COUNT(DISTINCT p.player_id) AS players_acquired,
	COUNT(DISTINCT s.player_id) AS active_players,
	COUNT(DISTINCT t.player_id) AS paying_players,
	CAST(COUNT(DISTINCT s.player_id) AS FLOAT) * 100.0 / COUNT(DISTINCT p.player_id) AS activity_rate_pct,
	CAST(COUNT(DISTINCT t.player_id) AS FLOAT) * 100.0 / COUNT(DISTINCT p.player_id) AS conversion_rate_pct
FROM dbo.players p
LEFT JOIN dbo.sessions s ON p.player_id = s.player_id
LEFT JOIN dbo.transactions t ON p.player_id = t.player_id
GROUP BY p.acquisition_source
ORDER BY conversion_rate_pct DESC; 

-- ============================================================================
-- BUSINESS INSIGHTS & RECOMMENDATIONS
-- ============================================================================
--
-- Key Questions Answered:
-- 1. What is our player base composition by platform and geography?
-- 2. Which acquisition sources bring the most players?
-- 3. How engaged are players across different platforms?
-- 4. What is the revenue performance by platform and acquisition source?
-- 5. Which marketing channels deliver highest quality (paying) players?
--
-- Actionable Recommendations:
-- • Focus marketing budget on acquisition sources with highest conversion rates
-- • Optimize monetization strategies for platforms showing lower revenue per user
-- • Investigate why certain acquisition sources have low activity rates
-- • Develop platform-specific engagement strategies based on usage patterns
--
-- Business Impact:
-- • Better marketing budget allocation based on source quality metrics
-- • Platform-optimized monetization strategies
-- • Improved player acquisition efficiency
-- ============================================================================
