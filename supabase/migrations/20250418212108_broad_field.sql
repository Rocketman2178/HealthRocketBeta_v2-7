/*
  # Create User Insights Table

  1. New Tables
    - `user_insights` - Stores daily aggregated user activity and health data
      - `id` (uuid, primary key)
      - `user_id` (uuid, references users)
      - `date` (date)
      - `health_score` (numeric)
      - `healthspan_years` (numeric)
      - `category_scores` (jsonb)
      - `fuel_points_earned` (integer)
      - `burn_streak` (integer)
      - `active_challenges_count` (integer)
      - `active_quests_count` (integer)
      - `active_contests_count` (integer)
      - `chat_messages_count` (integer)
      - `verification_posts_count` (integer)
      - `metadata` (jsonb)
      - `created_at` (timestamptz)
  
  2. Security
    - Enable RLS on the table
    - Add policy for users to view their own insights
    
  3. Functions
    - `generate_user_insights()` - Collects daily data for all active users
    - `get_user_insights()` - Retrieves insights for a specific user within a date range
*/

-- Create user_insights table
CREATE TABLE IF NOT EXISTS public.user_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  date date NOT NULL,
  health_score numeric(4,2),
  healthspan_years numeric(4,2),
  category_scores jsonb,
  fuel_points_earned integer DEFAULT 0,
  burn_streak integer DEFAULT 0,
  active_challenges_count integer DEFAULT 0,
  active_quests_count integer DEFAULT 0,
  active_contests_count integer DEFAULT 0,
  chat_messages_count integer DEFAULT 0,
  verification_posts_count integer DEFAULT 0,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, date)
);

-- Enable RLS
ALTER TABLE public.user_insights ENABLE ROW LEVEL SECURITY;

-- Create policy for users to view their own insights
CREATE POLICY "Users can view their own insights"
  ON public.user_insights
  FOR SELECT
  USING (auth.uid() = user_id);

-- Create function to generate user insights
CREATE OR REPLACE FUNCTION generate_user_insights()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user record;
  v_today date := current_date;
  v_count integer := 0;
  v_category_scores jsonb;
  v_health_score numeric(4,2);
  v_healthspan_years numeric(4,2);
  v_metadata jsonb;
  v_active_challenges integer;
  v_active_quests integer;
  v_active_contests integer;
  v_chat_messages integer;
  v_verification_posts integer;
  v_daily_fp integer;
BEGIN
  -- Loop through all active users
  FOR v_user IN (
    SELECT id FROM users
    WHERE onboarding_completed = true
  ) LOOP
    -- Skip if already generated for today
    IF EXISTS (
      SELECT 1 FROM user_insights
      WHERE user_id = v_user.id AND date = v_today
    ) THEN
      CONTINUE;
    END IF;
    
    -- Get latest health assessment data
    SELECT 
      health_score,
      healthspan_years,
      jsonb_build_object(
        'mindset', mindset_score,
        'sleep', sleep_score,
        'exercise', exercise_score,
        'nutrition', nutrition_score,
        'biohacking', biohacking_score
      )
    INTO 
      v_health_score,
      v_healthspan_years,
      v_category_scores
    FROM health_assessments
    WHERE user_id = v_user.id
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Get active challenges count
    SELECT COUNT(*) INTO v_active_challenges
    FROM challenges
    WHERE user_id = v_user.id AND status = 'active';
    
    -- Get active quests count
    SELECT COUNT(*) INTO v_active_quests
    FROM quests
    WHERE user_id = v_user.id AND status = 'active';
    
    -- Get active contests count
    SELECT COUNT(*) INTO v_active_contests
    FROM active_contests
    WHERE user_id = v_user.id AND status = 'active';
    
    -- Get chat messages count for today
    SELECT COUNT(*) INTO v_chat_messages
    FROM chat_messages
    WHERE user_id = v_user.id 
      AND DATE(created_at) = v_today;
    
    -- Get verification posts count for today
    SELECT COUNT(*) INTO v_verification_posts
    FROM chat_messages
    WHERE user_id = v_user.id 
      AND is_verification = true
      AND DATE(created_at) = v_today;
    
    -- Get daily FP earned
    SELECT fp_earned INTO v_daily_fp
    FROM daily_fp
    WHERE user_id = v_user.id AND date = v_today;
    
    -- Build metadata
    v_metadata := jsonb_build_object(
      'level', (SELECT level FROM users WHERE id = v_user.id),
      'total_fuel_points', (SELECT fuel_points FROM users WHERE id = v_user.id),
      'plan', (SELECT plan FROM users WHERE id = v_user.id),
      'boosts_completed', (
        SELECT COUNT(*) 
        FROM completed_boosts 
        WHERE user_id = v_user.id AND completed_date = v_today
      ),
      'total_challenges_completed', (
        SELECT COUNT(*) 
        FROM completed_challenges 
        WHERE user_id = v_user.id
      ),
      'total_quests_completed', (
        SELECT COUNT(*) 
        FROM completed_quests 
        WHERE user_id = v_user.id
      ),
      'device_connections', (
        SELECT COUNT(*) 
        FROM user_devices 
        WHERE user_id = v_user.id AND status = 'active'
      )
    );
    
    -- Insert insights
    INSERT INTO user_insights (
      user_id,
      date,
      health_score,
      healthspan_years,
      category_scores,
      fuel_points_earned,
      burn_streak,
      active_challenges_count,
      active_quests_count,
      active_contests_count,
      chat_messages_count,
      verification_posts_count,
      metadata
    ) VALUES (
      v_user.id,
      v_today,
      v_health_score,
      v_healthspan_years,
      v_category_scores,
      COALESCE(v_daily_fp, 0),
      (SELECT burn_streak FROM users WHERE id = v_user.id),
      v_active_challenges,
      v_active_quests,
      v_active_contests,
      v_chat_messages,
      v_verification_posts,
      v_metadata
    );
    
    v_count := v_count + 1;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- Create function to get user insights
CREATE OR REPLACE FUNCTION get_user_insights(
  p_user_id uuid,
  p_start_date date DEFAULT (current_date - interval '30 days')::date,
  p_end_date date DEFAULT current_date
)
RETURNS TABLE (
  date date,
  health_score numeric(4,2),
  healthspan_years numeric(4,2),
  category_scores jsonb,
  fuel_points_earned integer,
  burn_streak integer,
  active_challenges_count integer,
  active_quests_count integer,
  active_contests_count integer,
  chat_messages_count integer,
  verification_posts_count integer,
  metadata jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ui.date,
    ui.health_score,
    ui.healthspan_years,
    ui.category_scores,
    ui.fuel_points_earned,
    ui.burn_streak,
    ui.active_challenges_count,
    ui.active_quests_count,
    ui.active_contests_count,
    ui.chat_messages_count,
    ui.verification_posts_count,
    ui.metadata
  FROM user_insights ui
  WHERE ui.user_id = p_user_id
    AND ui.date BETWEEN p_start_date AND p_end_date
  ORDER BY ui.date;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_user_insights() TO postgres;
GRANT EXECUTE ON FUNCTION get_user_insights(uuid, date, date) TO public;

-- Create a cron job to generate insights daily (if pg_cron is available)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    -- Fix: Use proper syntax for cron.schedule
    BEGIN
      PERFORM cron.schedule(
        'generate-user-insights',
        '0 0 * * *',  -- Run at midnight every day
        'SELECT generate_user_insights()'
      );
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not create cron job: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'pg_cron extension not available. Please set up an external cron job to call generate_user_insights() daily.';
  END IF;
END
$$;

-- Generate initial insights for today
SELECT generate_user_insights();