/*
  # Fix Contest Registration System

  1. Changes
    - Create active_contests table with proper constraints
    - Add functions to handle contest registration with active_contests
    - Fix the relationship between contest_id and challenge_id
    - Migrate existing contest challenges to active_contests
    
  2. Security
    - Maintain existing RLS policies
*/

-- Create active_contests table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.active_contests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  contest_id uuid REFERENCES public.contests(id) ON DELETE CASCADE NOT NULL,
  challenge_id text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  progress numeric(5,2) DEFAULT 0,
  started_at timestamptz NOT NULL,
  completed_at timestamptz,
  verification_count integer DEFAULT 0,
  verifications_required integer DEFAULT 3,
  boost_count integer DEFAULT 0,
  last_daily_boost_completed_date date,
  user_name text,
  verification_requirements jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Add unique constraint if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'active_contests_user_id_challenge_id_key'
  ) THEN
    ALTER TABLE public.active_contests 
    ADD CONSTRAINT active_contests_user_id_challenge_id_key UNIQUE (user_id, challenge_id);
  END IF;
END $$;

-- Enable RLS if not already enabled
ALTER TABLE public.active_contests ENABLE ROW LEVEL SECURITY;

-- Create RLS policies if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'active_contests' AND policyname = 'Users can view own active contests'
  ) THEN
    CREATE POLICY "Users can view own active contests"
      ON public.active_contests
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'active_contests' AND policyname = 'Users can update own active contests'
  ) THEN
    CREATE POLICY "Users can update own active contests"
      ON public.active_contests
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- Create function to get active contests
CREATE OR REPLACE FUNCTION get_user_active_contests(
  p_user_id uuid
)
RETURNS TABLE (
  id uuid,
  contest_id uuid,
  challenge_id text,
  status text,
  progress numeric,
  started_at timestamptz,
  completed_at timestamptz,
  verification_count integer,
  verifications_required integer,
  boost_count integer,
  last_daily_boost_completed_date date,
  user_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ac.id,
    ac.contest_id,
    ac.challenge_id,
    ac.status,
    ac.progress,
    ac.started_at,
    ac.completed_at,
    ac.verification_count,
    ac.verifications_required,
    ac.boost_count,
    ac.last_daily_boost_completed_date,
    ac.user_name
  FROM active_contests ac
  WHERE ac.user_id = p_user_id
    AND ac.status = 'active'
  ORDER BY ac.started_at DESC;
END;
$$;

-- Create function to get contest players
CREATE OR REPLACE FUNCTION get_active_contest_players(
  p_challenge_id text
)
RETURNS TABLE (
  user_id uuid,
  name text,
  created_at timestamptz,
  level integer,
  burn_streak integer,
  avatar_url text,
  health_score numeric,
  healthspan_years numeric,
  plan text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    u.created_at,
    u.level,
    u.burn_streak,
    u.avatar_url,
    u.health_score,
    u.healthspan_years,
    u.plan
  FROM active_contests ac
  JOIN users u ON ac.user_id = u.id
  WHERE ac.challenge_id = p_challenge_id
  AND ac.status = 'active';
END;
$$;

-- Create function to get contest players count
CREATE OR REPLACE FUNCTION get_active_contest_players_count(
  p_challenge_id text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM active_contests
  WHERE challenge_id = p_challenge_id
    AND status = 'active';
  
  RETURN v_count;
END;
$$;

-- Create function to register for a contest with credits
CREATE OR REPLACE FUNCTION register_contest_with_active_contests(
  p_user_id uuid,
  p_challenge_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_eligibility jsonb;
  v_registration_id uuid;
  v_contest_record record;
  v_active_contest_id uuid;
  v_user_name text;
BEGIN
  -- Check eligibility first
  SELECT check_contest_eligibility(p_user_id, p_challenge_id) INTO v_eligibility;

  -- Validate eligibility
  IF NOT (v_eligibility->>'eligible')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_eligibility->>'error'
    );
  END IF;

  -- Verify credits
  IF NOT (v_eligibility->>'has_credits')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No contest credits available'
    );
  END IF;

  -- Verify device connection if required
  IF (v_eligibility->>'requires_device')::boolean AND NOT (v_eligibility->>'device_connected')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Required device not connected: ' || (v_eligibility->>'required_device')
    );
  END IF;

  -- Get contest details to use start_date
  SELECT * INTO v_contest_record
  FROM contests
  WHERE id = (v_eligibility->>'contest_id')::uuid;

  -- Get user's name
  SELECT name INTO v_user_name
  FROM users
  WHERE id = p_user_id;

  -- Use credit and create registration
  UPDATE users
  SET contest_credits = contest_credits - 1
  WHERE id = p_user_id;

  -- Create registration with paid status
  INSERT INTO contest_registrations (
    contest_id,
    user_id,
    payment_status,
    registered_at,
    paid_at
  ) VALUES (
    (v_eligibility->>'contest_id')::uuid,
    p_user_id,
    'paid',
    now(),
    now()
  )
  RETURNING id INTO v_registration_id;

  -- Create active contest entry
  INSERT INTO active_contests (
    user_id,
    contest_id,
    challenge_id,
    status,
    progress,
    started_at,
    user_name,
    verification_requirements
  ) VALUES (
    p_user_id,
    (v_eligibility->>'contest_id')::uuid,
    p_challenge_id,
    'active',
    0,
    v_contest_record.start_date,
    v_user_name,
    jsonb_build_object(
      'week1', jsonb_build_object('required', 1, 'completed', 0, 'deadline', v_contest_record.start_date + interval '7 days'),
      'week2', jsonb_build_object('required', 1, 'completed', 0, 'deadline', v_contest_record.start_date + interval '14 days'),
      'week3', jsonb_build_object('required', 1, 'completed', 0, 'deadline', v_contest_record.start_date + interval '21 days'),
      'week4', jsonb_build_object('required', 1, 'completed', 0, 'deadline', v_contest_record.start_date + interval '28 days')
    )
  )
  RETURNING id INTO v_active_contest_id;

  -- Delete any existing challenge entry for this contest
  DELETE FROM challenges
  WHERE user_id = p_user_id
  AND challenge_id = p_challenge_id;

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', v_registration_id,
    'active_contest_id', v_active_contest_id,
    'credits_used', true,
    'credits_remaining', (v_eligibility->>'credits_remaining')::integer - 1
  );
END;
$$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_active_contests_user_id ON public.active_contests(user_id);
CREATE INDEX IF NOT EXISTS idx_active_contests_challenge_id ON public.active_contests(challenge_id);
CREATE INDEX IF NOT EXISTS idx_active_contests_contest_id ON public.active_contests(contest_id);

-- Create function to fix existing registrations
CREATE OR REPLACE FUNCTION fix_clay_contest_registration()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_challenge_id text;
  v_contest_id uuid;
  v_user_name text;
BEGIN
  -- Find the user with email clay@healthrocket.life
  SELECT id, name INTO v_user_id, v_user_name
  FROM users
  WHERE email = 'clay@healthrocket.life';
  
  -- If user found
  IF v_user_id IS NOT NULL THEN
    -- Check if they have a challenge for cn_oura_sleep_score
    v_challenge_id := 'cn_oura_sleep_score';
    
    -- Find the contest ID
    SELECT id INTO v_contest_id
    FROM contests
    WHERE challenge_id = v_challenge_id
    LIMIT 1;
    
    -- If contest found
    IF v_contest_id IS NOT NULL THEN
      -- Check if there's an entry in challenges but not in active_contests
      IF EXISTS (
        SELECT 1 
        FROM challenges 
        WHERE user_id = v_user_id 
        AND challenge_id = v_challenge_id
      ) AND NOT EXISTS (
        SELECT 1 
        FROM active_contests 
        WHERE user_id = v_user_id 
        AND challenge_id = v_challenge_id
      ) THEN
        -- Get the challenge details
        DECLARE
          v_challenge record;
        BEGIN
          SELECT * INTO v_challenge
          FROM challenges
          WHERE user_id = v_user_id
          AND challenge_id = v_challenge_id;
          
          -- Create registration if it doesn't exist
          INSERT INTO contest_registrations (
            contest_id,
            user_id,
            payment_status,
            registered_at,
            paid_at
          )
          SELECT
            v_contest_id,
            v_user_id,
            'paid',
            now(),
            now()
          WHERE NOT EXISTS (
            SELECT 1 
            FROM contest_registrations 
            WHERE user_id = v_user_id 
            AND contest_id = v_contest_id
          );
          
          -- Create active_contest entry
          INSERT INTO active_contests (
            user_id,
            contest_id,
            challenge_id,
            status,
            progress,
            started_at,
            completed_at,
            verification_count,
            verifications_required,
            boost_count,
            last_daily_boost_completed_date,
            user_name,
            verification_requirements
          )
          VALUES (
            v_user_id,
            v_contest_id,
            v_challenge_id,
            v_challenge.status,
            v_challenge.progress,
            v_challenge.started_at,
            v_challenge.completed_at,
            v_challenge.verification_count,
            v_challenge.verifications_required,
            v_challenge.boost_count,
            v_challenge.last_daily_boost_completed_date,
            v_user_name,
            v_challenge.verification_requirements
          )
          ON CONFLICT (user_id, challenge_id) DO NOTHING;
        END;
      END IF;
    END IF;
  END IF;
END;
$$;

-- Run the fix function
SELECT fix_clay_contest_registration();

-- Drop the fix function after use
DROP FUNCTION fix_clay_contest_registration();