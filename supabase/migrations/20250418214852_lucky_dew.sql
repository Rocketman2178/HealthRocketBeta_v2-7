/*
  # Add Lifetime Total Columns to All User Insights

  1. New Columns
    - `total_lifetime_boosts` - Total number of boosts completed across all time
    - `total_lifetime_challenges` - Total number of challenges completed across all time
    - `total_lifetime_quests` - Total number of quests completed across all time
    - `total_lifetime_chat_messages` - Total number of chat messages sent across all time
    - `total_lifetime_verification_posts` - Total number of verification posts across all time
    
  2. Updated Functions
    - Update generate_all_user_insights() to populate the new columns
    - Update get_all_user_insights() to return the new columns
    - Update get_all_user_insights_trends() to include the new columns in trends
*/

-- Add new lifetime total columns to all_user_insights table
ALTER TABLE public.all_user_insights 
  ADD COLUMN IF NOT EXISTS total_lifetime_boosts integer,
  ADD COLUMN IF NOT EXISTS total_lifetime_challenges integer,
  ADD COLUMN IF NOT EXISTS total_lifetime_quests integer,
  ADD COLUMN IF NOT EXISTS total_lifetime_chat_messages integer,
  ADD COLUMN IF NOT EXISTS total_lifetime_verification_posts integer;

-- Drop existing functions to avoid return type errors
DROP FUNCTION IF EXISTS generate_all_user_insights();
DROP FUNCTION IF EXISTS get_all_user_insights(date, date);
DROP FUNCTION IF EXISTS get_all_user_insights_trends(integer);

-- Create the updated generate_all_user_insights function
CREATE OR REPLACE FUNCTION generate_all_user_insights()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := current_date;
  v_total_users integer;
  v_active_users integer;
  v_avg_health_score numeric(4,2);
  v_avg_healthspan_years numeric(4,2);
  v_total_healthspan_years numeric(8,2);
  v_category_averages jsonb;
  v_total_fp_earned integer;
  v_total_lifetime_fp integer;
  v_avg_fp_per_user numeric(8,2);
  v_average_level numeric(4,2);
  v_highest_level integer;
  v_total_boosts_completed integer;
  v_total_challenges_completed integer;
  v_total_quests_completed integer;
  v_total_contests_active integer;
  v_total_chat_messages integer;
  v_total_verification_posts integer;
  v_total_lifetime_boosts integer;
  v_total_lifetime_challenges integer;
  v_total_lifetime_quests integer;
  v_total_lifetime_chat_messages integer;
  v_total_lifetime_verification_posts integer;
  v_device_connection_stats jsonb;
  v_metadata jsonb;
  v_result jsonb;
BEGIN
  -- Skip if already generated for today
  IF EXISTS (
    SELECT 1 FROM all_user_insights
    WHERE date = v_today
  ) THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Insights already generated for today',
      'date', v_today
    );
  END IF;
  
  -- Get total users
  SELECT COUNT(*) INTO v_total_users
  FROM users;
  
  -- Get active users (users who earned FP today)
  SELECT COUNT(DISTINCT user_id) INTO v_active_users
  FROM daily_fp
  WHERE date = v_today;
  
  -- Get average health score and healthspan years
  SELECT 
    AVG(health_score),
    AVG(healthspan_years),
    SUM(healthspan_years)
  INTO 
    v_avg_health_score,
    v_avg_healthspan_years,
    v_total_healthspan_years
  FROM users
  WHERE health_score > 0;
  
  -- Get category averages
  SELECT jsonb_build_object(
    'mindset', AVG(mindset_score),
    'sleep', AVG(sleep_score),
    'exercise', AVG(exercise_score),
    'nutrition', AVG(nutrition_score),
    'biohacking', AVG(biohacking_score)
  ) INTO v_category_averages
  FROM (
    SELECT 
      user_id,
      mindset_score,
      sleep_score,
      exercise_score,
      nutrition_score,
      biohacking_score
    FROM health_assessments
    WHERE (user_id, created_at) IN (
      SELECT user_id, MAX(created_at)
      FROM health_assessments
      GROUP BY user_id
    )
  ) latest_assessments;
  
  -- Get total FP earned today
  SELECT COALESCE(SUM(fp_earned), 0) INTO v_total_fp_earned
  FROM daily_fp
  WHERE date = v_today;
  
  -- Get total lifetime FP
  SELECT COALESCE(SUM(fuel_points), 0) INTO v_total_lifetime_fp
  FROM users;
  
  -- Get average and highest level
  SELECT 
    AVG(level),
    MAX(level)
  INTO 
    v_average_level,
    v_highest_level
  FROM users;
  
  -- Calculate average FP per user
  v_avg_fp_per_user := CASE WHEN v_active_users > 0 
                           THEN v_total_fp_earned::numeric / v_active_users 
                           ELSE 0 
                       END;
  
  -- Get total boosts completed today
  SELECT COUNT(*) INTO v_total_boosts_completed
  FROM completed_boosts
  WHERE completed_date = v_today;
  
  -- Get total lifetime boosts
  SELECT COUNT(*) INTO v_total_lifetime_boosts
  FROM completed_boosts;
  
  -- Get total challenges completed today
  SELECT COUNT(*) INTO v_total_challenges_completed
  FROM completed_challenges
  WHERE DATE(completed_at) = v_today;
  
  -- Get total lifetime challenges
  SELECT COUNT(*) INTO v_total_lifetime_challenges
  FROM completed_challenges;
  
  -- Get total quests completed today
  SELECT COUNT(*) INTO v_total_quests_completed
  FROM completed_quests
  WHERE DATE(completed_at) = v_today;
  
  -- Get total lifetime quests
  SELECT COUNT(*) INTO v_total_lifetime_quests
  FROM completed_quests;
  
  -- Get total active contests
  SELECT COUNT(*) INTO v_total_contests_active
  FROM active_contests
  WHERE status = 'active';
  
  -- Get total chat messages today
  SELECT COUNT(*) INTO v_total_chat_messages
  FROM chat_messages
  WHERE DATE(created_at) = v_today;
  
  -- Get total lifetime chat messages
  SELECT COUNT(*) INTO v_total_lifetime_chat_messages
  FROM chat_messages;
  
  -- Get total verification posts today
  SELECT COUNT(*) INTO v_total_verification_posts
  FROM chat_messages
  WHERE is_verification = true
    AND DATE(created_at) = v_today;
  
  -- Get total lifetime verification posts
  SELECT COUNT(*) INTO v_total_lifetime_verification_posts
  FROM chat_messages
  WHERE is_verification = true;
  
  -- Get device connection stats
  SELECT jsonb_build_object(
    'total_connected_devices', COUNT(*),
    'providers', (
      SELECT jsonb_object_agg(provider, count)
      FROM (
        SELECT provider, COUNT(*) as count
        FROM user_devices
        WHERE status = 'active'
        GROUP BY provider
      ) provider_counts
    )
  ) INTO v_device_connection_stats
  FROM user_devices
  WHERE status = 'active';
  
  -- Build additional metadata
  v_metadata := jsonb_build_object(
    'burn_streak_average', (SELECT AVG(burn_streak) FROM users WHERE burn_streak > 0),
    'level_distribution', (
      SELECT jsonb_object_agg(level, count)
      FROM (
        SELECT level, COUNT(*) as count
        FROM users
        GROUP BY level
        ORDER BY level
      ) level_counts
    ),
    'plan_distribution', (
      SELECT jsonb_object_agg(plan, count)
      FROM (
        SELECT plan, COUNT(*) as count
        FROM users
        GROUP BY plan
      ) plan_counts
    ),
    'new_users_today', (
      SELECT COUNT(*)
      FROM users
      WHERE DATE(created_at) = v_today
    )
  );
  
  -- Insert aggregated insights
  INSERT INTO all_user_insights (
    date,
    total_users,
    active_users,
    average_health_score,
    average_healthspan_years,
    total_healthspan_years,
    category_averages,
    total_fp_earned,
    total_lifetime_fp,
    average_fp_per_user,
    average_level,
    highest_level,
    total_boosts_completed,
    total_lifetime_boosts,
    total_challenges_completed,
    total_lifetime_challenges,
    total_quests_completed,
    total_lifetime_quests,
    total_contests_active,
    total_chat_messages,
    total_lifetime_chat_messages,
    total_verification_posts,
    total_lifetime_verification_posts,
    device_connection_stats,
    metadata
  ) VALUES (
    v_today,
    v_total_users,
    v_active_users,
    v_avg_health_score,
    v_avg_healthspan_years,
    v_total_healthspan_years,
    v_category_averages,
    v_total_fp_earned,
    v_total_lifetime_fp,
    v_avg_fp_per_user,
    v_average_level,
    v_highest_level,
    v_total_boosts_completed,
    v_total_lifetime_boosts,
    v_total_challenges_completed,
    v_total_lifetime_challenges,
    v_total_quests_completed,
    v_total_lifetime_quests,
    v_total_contests_active,
    v_total_chat_messages,
    v_total_lifetime_chat_messages,
    v_total_verification_posts,
    v_total_lifetime_verification_posts,
    v_device_connection_stats,
    v_metadata
  );
  
  -- Return success
  v_result := jsonb_build_object(
    'success', true,
    'message', 'All user insights generated successfully',
    'date', v_today,
    'total_users', v_total_users,
    'active_users', v_active_users,
    'total_healthspan_years', v_total_healthspan_years,
    'total_lifetime_fp', v_total_lifetime_fp,
    'average_level', v_average_level,
    'highest_level', v_highest_level,
    'total_lifetime_boosts', v_total_lifetime_boosts,
    'total_lifetime_challenges', v_total_lifetime_challenges,
    'total_lifetime_quests', v_total_lifetime_quests,
    'total_lifetime_chat_messages', v_total_lifetime_chat_messages,
    'total_lifetime_verification_posts', v_total_lifetime_verification_posts
  );
  
  RETURN v_result;
END;
$$;

-- Create the updated get_all_user_insights function
CREATE OR REPLACE FUNCTION get_all_user_insights(
  p_start_date date DEFAULT (current_date - interval '30 days')::date,
  p_end_date date DEFAULT current_date
)
RETURNS TABLE (
  date date,
  total_users integer,
  active_users integer,
  average_health_score numeric(4,2),
  average_healthspan_years numeric(4,2),
  total_healthspan_years numeric(8,2),
  category_averages jsonb,
  total_fp_earned integer,
  total_lifetime_fp integer,
  average_fp_per_user numeric(8,2),
  average_level numeric(4,2),
  highest_level integer,
  total_boosts_completed integer,
  total_lifetime_boosts integer,
  total_challenges_completed integer,
  total_lifetime_challenges integer,
  total_quests_completed integer,
  total_lifetime_quests integer,
  total_contests_active integer,
  total_chat_messages integer,
  total_lifetime_chat_messages integer,
  total_verification_posts integer,
  total_lifetime_verification_posts integer,
  device_connection_stats jsonb,
  metadata jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    aui.date,
    aui.total_users,
    aui.active_users,
    aui.average_health_score,
    aui.average_healthspan_years,
    aui.total_healthspan_years,
    aui.category_averages,
    aui.total_fp_earned,
    aui.total_lifetime_fp,
    aui.average_fp_per_user,
    aui.average_level,
    aui.highest_level,
    aui.total_boosts_completed,
    aui.total_lifetime_boosts,
    aui.total_challenges_completed,
    aui.total_lifetime_challenges,
    aui.total_quests_completed,
    aui.total_lifetime_quests,
    aui.total_contests_active,
    aui.total_chat_messages,
    aui.total_lifetime_chat_messages,
    aui.total_verification_posts,
    aui.total_lifetime_verification_posts,
    aui.device_connection_stats,
    aui.metadata
  FROM all_user_insights aui
  WHERE aui.date BETWEEN p_start_date AND p_end_date
  ORDER BY aui.date;
END;
$$;

-- Create the updated get_all_user_insights_trends function
CREATE OR REPLACE FUNCTION get_all_user_insights_trends(
  p_days integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start_date date := current_date - (p_days || ' days')::interval;
  v_end_date date := current_date;
  v_result jsonb;
BEGIN
  -- Get trends for key metrics
  WITH daily_data AS (
    SELECT
      date,
      total_fp_earned,
      total_lifetime_fp,
      active_users,
      average_health_score,
      average_healthspan_years,
      total_healthspan_years,
      average_level,
      highest_level,
      total_boosts_completed,
      total_lifetime_boosts,
      total_challenges_completed,
      total_lifetime_challenges,
      total_quests_completed,
      total_lifetime_quests,
      total_chat_messages,
      total_lifetime_chat_messages,
      total_verification_posts,
      total_lifetime_verification_posts
    FROM all_user_insights
    WHERE date BETWEEN v_start_date AND v_end_date
    ORDER BY date
  ),
  weekly_averages AS (
    SELECT
      date_trunc('week', date)::date as week_start,
      ROUND(AVG(total_fp_earned), 2) as avg_fp,
      MAX(total_lifetime_fp) as total_lifetime_fp,
      ROUND(AVG(active_users), 2) as avg_active_users,
      ROUND(AVG(average_health_score), 2) as avg_health_score,
      ROUND(AVG(average_healthspan_years), 2) as avg_healthspan,
      MAX(total_healthspan_years) as total_healthspan,
      ROUND(AVG(average_level), 2) as avg_level,
      MAX(highest_level) as highest_level,
      ROUND(AVG(total_boosts_completed), 2) as avg_boosts,
      MAX(total_lifetime_boosts) as total_lifetime_boosts,
      ROUND(AVG(total_challenges_completed), 2) as avg_challenges,
      MAX(total_lifetime_challenges) as total_lifetime_challenges,
      ROUND(AVG(total_quests_completed), 2) as avg_quests,
      MAX(total_lifetime_quests) as total_lifetime_quests,
      ROUND(AVG(total_chat_messages), 2) as avg_messages,
      MAX(total_lifetime_chat_messages) as total_lifetime_messages,
      ROUND(AVG(total_verification_posts), 2) as avg_verifications,
      MAX(total_lifetime_verification_posts) as total_lifetime_verifications
    FROM daily_data
    GROUP BY week_start
    ORDER BY week_start
  )
  SELECT
    jsonb_build_object(
      'period_days', p_days,
      'start_date', v_start_date,
      'end_date', v_end_date,
      'weekly_trends', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'week_start', week_start,
            'avg_fp', avg_fp,
            'total_lifetime_fp', total_lifetime_fp,
            'avg_active_users', avg_active_users,
            'avg_health_score', avg_health_score,
            'avg_healthspan', avg_healthspan,
            'total_healthspan', total_healthspan,
            'avg_level', avg_level,
            'highest_level', highest_level,
            'avg_boosts', avg_boosts,
            'total_lifetime_boosts', total_lifetime_boosts,
            'avg_challenges', avg_challenges,
            'total_lifetime_challenges', total_lifetime_challenges,
            'avg_quests', avg_quests,
            'total_lifetime_quests', total_lifetime_quests,
            'avg_messages', avg_messages,
            'total_lifetime_messages', total_lifetime_messages,
            'avg_verifications', avg_verifications,
            'total_lifetime_verifications', total_lifetime_verifications
          )
        )
        FROM weekly_averages
      ),
      'growth_rates', (
        SELECT jsonb_build_object(
          'fp_growth', CASE 
            WHEN MIN(total_fp_earned) = 0 THEN NULL
            ELSE ROUND(((MAX(total_fp_earned) - MIN(total_fp_earned))::numeric / NULLIF(MIN(total_fp_earned), 0) * 100), 2)
          END,
          'lifetime_fp_growth', CASE 
            WHEN MIN(total_lifetime_fp) = 0 THEN NULL
            ELSE ROUND(((MAX(total_lifetime_fp) - MIN(total_lifetime_fp))::numeric / NULLIF(MIN(total_lifetime_fp), 0) * 100), 2)
          END,
          'active_users_growth', CASE 
            WHEN MIN(active_users) = 0 THEN NULL
            ELSE ROUND(((MAX(active_users) - MIN(active_users))::numeric / NULLIF(MIN(active_users), 0) * 100), 2)
          END,
          'health_score_growth', CASE 
            WHEN MIN(average_health_score) = 0 THEN NULL
            ELSE ROUND(((MAX(average_health_score) - MIN(average_health_score))::numeric / NULLIF(MIN(average_health_score), 0) * 100), 2)
          END,
          'healthspan_growth', CASE 
            WHEN MIN(average_healthspan_years) = 0 THEN NULL
            ELSE ROUND(((MAX(average_healthspan_years) - MIN(average_healthspan_years))::numeric / NULLIF(MIN(average_healthspan_years), 0) * 100), 2)
          END,
          'total_healthspan_growth', CASE 
            WHEN MIN(total_healthspan_years) = 0 THEN NULL
            ELSE ROUND(((MAX(total_healthspan_years) - MIN(total_healthspan_years))::numeric / NULLIF(MIN(total_healthspan_years), 0) * 100), 2)
          END,
          'level_growth', CASE 
            WHEN MIN(average_level) = 0 THEN NULL
            ELSE ROUND(((MAX(average_level) - MIN(average_level))::numeric / NULLIF(MIN(average_level), 0) * 100), 2)
          END,
          'lifetime_boosts_growth', CASE 
            WHEN MIN(total_lifetime_boosts) = 0 THEN NULL
            ELSE ROUND(((MAX(total_lifetime_boosts) - MIN(total_lifetime_boosts))::numeric / NULLIF(MIN(total_lifetime_boosts), 0) * 100), 2)
          END,
          'lifetime_challenges_growth', CASE 
            WHEN MIN(total_lifetime_challenges) = 0 THEN NULL
            ELSE ROUND(((MAX(total_lifetime_challenges) - MIN(total_lifetime_challenges))::numeric / NULLIF(MIN(total_lifetime_challenges), 0) * 100), 2)
          END,
          'lifetime_quests_growth', CASE 
            WHEN MIN(total_lifetime_quests) = 0 THEN NULL
            ELSE ROUND(((MAX(total_lifetime_quests) - MIN(total_lifetime_quests))::numeric / NULLIF(MIN(total_lifetime_quests), 0) * 100), 2)
          END,
          'lifetime_messages_growth', CASE 
            WHEN MIN(total_lifetime_chat_messages) = 0 THEN NULL
            ELSE ROUND(((MAX(total_lifetime_chat_messages) - MIN(total_lifetime_chat_messages))::numeric / NULLIF(MIN(total_lifetime_chat_messages), 0) * 100), 2)
          END,
          'lifetime_verifications_growth', CASE 
            WHEN MIN(total_lifetime_verification_posts) = 0 THEN NULL
            ELSE ROUND(((MAX(total_lifetime_verification_posts) - MIN(total_lifetime_verification_posts))::numeric / NULLIF(MIN(total_lifetime_verification_posts), 0) * 100), 2)
          END
        )
        FROM daily_data
        WHERE total_fp_earned > 0 OR active_users > 0
      )
    ) INTO v_result
  FROM daily_data;
  
  RETURN COALESCE(v_result, jsonb_build_object(
    'period_days', p_days,
    'start_date', v_start_date,
    'end_date', v_end_date,
    'weekly_trends', '[]'::jsonb,
    'growth_rates', '{}'::jsonb,
    'message', 'No data available for the specified period'
  ));
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_all_user_insights() TO postgres;
GRANT EXECUTE ON FUNCTION get_all_user_insights(date, date) TO postgres;
GRANT EXECUTE ON FUNCTION get_all_user_insights_trends(integer) TO postgres;

-- Generate updated insights for today
SELECT generate_all_user_insights();