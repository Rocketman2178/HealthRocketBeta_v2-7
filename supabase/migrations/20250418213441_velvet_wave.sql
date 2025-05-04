/*
  # Create All User Insights Table

  1. New Tables
    - `all_user_insights` - Stores daily aggregated anonymous data across all users
      - `id` (uuid, primary key)
      - `date` (date)
      - `total_users` (integer)
      - `active_users` (integer)
      - `average_health_score` (numeric)
      - `average_healthspan_years` (numeric)
      - `category_averages` (jsonb)
      - `total_fp_earned` (integer)
      - `average_fp_per_user` (numeric)
      - `total_boosts_completed` (integer)
      - `total_challenges_completed` (integer)
      - `total_quests_completed` (integer)
      - `total_contests_active` (integer)
      - `total_chat_messages` (integer)
      - `total_verification_posts` (integer)
      - `device_connection_stats` (jsonb)
      - `metadata` (jsonb)
      - `created_at` (timestamptz)
  
  2. Security
    - No RLS needed as this table contains only anonymous aggregated data
    
  3. Functions
    - `generate_all_user_insights()` - Aggregates data across all users daily
    - `get_all_user_insights()` - Retrieves aggregated insights within a date range
*/

-- Create all_user_insights table
CREATE TABLE IF NOT EXISTS public.all_user_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  date date NOT NULL UNIQUE,
  total_users integer DEFAULT 0,
  active_users integer DEFAULT 0,
  average_health_score numeric(4,2),
  average_healthspan_years numeric(4,2),
  category_averages jsonb,
  total_fp_earned integer DEFAULT 0,
  average_fp_per_user numeric(8,2) DEFAULT 0,
  total_boosts_completed integer DEFAULT 0,
  total_challenges_completed integer DEFAULT 0,
  total_quests_completed integer DEFAULT 0,
  total_contests_active integer DEFAULT 0,
  total_chat_messages integer DEFAULT 0,
  total_verification_posts integer DEFAULT 0,
  device_connection_stats jsonb DEFAULT '{}'::jsonb,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Create function to generate all user insights
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
  v_category_averages jsonb;
  v_total_fp_earned integer;
  v_avg_fp_per_user numeric(8,2);
  v_total_boosts_completed integer;
  v_total_challenges_completed integer;
  v_total_quests_completed integer;
  v_total_contests_active integer;
  v_total_chat_messages integer;
  v_total_verification_posts integer;
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
    AVG(healthspan_years)
  INTO 
    v_avg_health_score,
    v_avg_healthspan_years
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
  
  -- Calculate average FP per user
  v_avg_fp_per_user := CASE WHEN v_active_users > 0 
                           THEN v_total_fp_earned::numeric / v_active_users 
                           ELSE 0 
                       END;
  
  -- Get total boosts completed today
  SELECT COUNT(*) INTO v_total_boosts_completed
  FROM completed_boosts
  WHERE completed_date = v_today;
  
  -- Get total challenges completed today
  SELECT COUNT(*) INTO v_total_challenges_completed
  FROM completed_challenges
  WHERE DATE(completed_at) = v_today;
  
  -- Get total quests completed today
  SELECT COUNT(*) INTO v_total_quests_completed
  FROM completed_quests
  WHERE DATE(completed_at) = v_today;
  
  -- Get total active contests
  SELECT COUNT(*) INTO v_total_contests_active
  FROM active_contests
  WHERE status = 'active';
  
  -- Get total chat messages today
  SELECT COUNT(*) INTO v_total_chat_messages
  FROM chat_messages
  WHERE DATE(created_at) = v_today;
  
  -- Get total verification posts today
  SELECT COUNT(*) INTO v_total_verification_posts
  FROM chat_messages
  WHERE is_verification = true
    AND DATE(created_at) = v_today;
  
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
    category_averages,
    total_fp_earned,
    average_fp_per_user,
    total_boosts_completed,
    total_challenges_completed,
    total_quests_completed,
    total_contests_active,
    total_chat_messages,
    total_verification_posts,
    device_connection_stats,
    metadata
  ) VALUES (
    v_today,
    v_total_users,
    v_active_users,
    v_avg_health_score,
    v_avg_healthspan_years,
    v_category_averages,
    v_total_fp_earned,
    v_avg_fp_per_user,
    v_total_boosts_completed,
    v_total_challenges_completed,
    v_total_quests_completed,
    v_total_contests_active,
    v_total_chat_messages,
    v_total_verification_posts,
    v_device_connection_stats,
    v_metadata
  );
  
  -- Return success
  v_result := jsonb_build_object(
    'success', true,
    'message', 'All user insights generated successfully',
    'date', v_today,
    'total_users', v_total_users,
    'active_users', v_active_users
  );
  
  RETURN v_result;
END;
$$;

-- Create function to get all user insights
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
  category_averages jsonb,
  total_fp_earned integer,
  average_fp_per_user numeric(8,2),
  total_boosts_completed integer,
  total_challenges_completed integer,
  total_quests_completed integer,
  total_contests_active integer,
  total_chat_messages integer,
  total_verification_posts integer,
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
    aui.category_averages,
    aui.total_fp_earned,
    aui.average_fp_per_user,
    aui.total_boosts_completed,
    aui.total_challenges_completed,
    aui.total_quests_completed,
    aui.total_contests_active,
    aui.total_chat_messages,
    aui.total_verification_posts,
    aui.device_connection_stats,
    aui.metadata
  FROM all_user_insights aui
  WHERE aui.date BETWEEN p_start_date AND p_end_date
  ORDER BY aui.date;
END;
$$;

-- Create function to get trend analysis from all user insights
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
  v_fp_trend numeric[];
  v_active_users_trend numeric[];
  v_health_score_trend numeric[];
  v_healthspan_trend numeric[];
  v_boosts_trend numeric[];
  v_challenges_trend numeric[];
  v_messages_trend numeric[];
BEGIN
  -- Get trends for key metrics
  WITH daily_data AS (
    SELECT
      date,
      total_fp_earned,
      active_users,
      average_health_score,
      average_healthspan_years,
      total_boosts_completed,
      total_challenges_completed,
      total_chat_messages
    FROM all_user_insights
    WHERE date BETWEEN v_start_date AND v_end_date
    ORDER BY date
  ),
  weekly_averages AS (
    SELECT
      date_trunc('week', date)::date as week_start,
      ROUND(AVG(total_fp_earned), 2) as avg_fp,
      ROUND(AVG(active_users), 2) as avg_active_users,
      ROUND(AVG(average_health_score), 2) as avg_health_score,
      ROUND(AVG(average_healthspan_years), 2) as avg_healthspan,
      ROUND(AVG(total_boosts_completed), 2) as avg_boosts,
      ROUND(AVG(total_challenges_completed), 2) as avg_challenges,
      ROUND(AVG(total_chat_messages), 2) as avg_messages
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
            'avg_active_users', avg_active_users,
            'avg_health_score', avg_health_score,
            'avg_healthspan', avg_healthspan,
            'avg_boosts', avg_boosts,
            'avg_challenges', avg_challenges,
            'avg_messages', avg_messages
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

-- Create a cron job to generate all user insights daily
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    -- Use proper syntax for cron.schedule
    BEGIN
      PERFORM cron.schedule(
        'generate-all-user-insights',
        '30 0 * * *',  -- Run at 12:30 AM every day (after user insights)
        'SELECT generate_all_user_insights()'
      );
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not create cron job: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'pg_cron extension not available. Please set up an external cron job to call generate_all_user_insights() daily.';
  END IF;
END
$$;

-- Generate initial insights for today
SELECT generate_all_user_insights();