-- Create a function to check eligibility for a specific user and contest
CREATE OR REPLACE FUNCTION check_specific_eligibility()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_challenge_id text := 'cn_oura_sleep_score_2';
  v_result jsonb;
  v_is_registered boolean;
  v_credits integer;
  v_contest record;
BEGIN
  -- Get user ID for clay@healthrocket.life
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'clay@healthrocket.life';
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found'
    );
  END IF;
  
  -- Check if already registered
  SELECT is_user_registered_for_contest(v_user_id, v_challenge_id) INTO v_is_registered;
  
  -- Get contest details
  SELECT 
    c.id,
    c.name,
    c.entry_fee
  INTO v_contest
  FROM contests c
  WHERE c.challenge_id = v_challenge_id;
  
  -- Get user's credits
  SELECT contest_credits INTO v_credits
  FROM users
  WHERE id = v_user_id;
  
  -- Return detailed eligibility info
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'challenge_id', v_challenge_id,
    'contest_name', v_contest.name,
    'is_registered', v_is_registered,
    'has_credits', COALESCE(v_credits > 0, false),
    'credits_remaining', COALESCE(v_credits, 0),
    'entry_fee', v_contest.entry_fee,
    'is_eligible', NOT v_is_registered AND (v_contest.entry_fee = 0 OR COALESCE(v_credits > 0, false))
  );
END;
$$;

-- Execute the function and log the result
DO $$
DECLARE
  result jsonb;
BEGIN
  SELECT check_specific_eligibility() INTO result;
  RAISE NOTICE 'Eligibility check result: %', result;
  
  -- Insert the result into logs for reference
  INSERT INTO contest_registration_logs (
    user_id,
    contest_id,
    is_registered,
    checked_at
  ) VALUES (
    (SELECT id FROM auth.users WHERE email = 'clay@healthrocket.life'),
    'eligibility_check_cn_oura_sleep_score_2',
    false,
    now()
  );
END $$;

-- Drop the function after use
DROP FUNCTION check_specific_eligibility();

-- Also clean up any existing registrations for this contest
DO $$
DECLARE
  v_user_id uuid;
  v_challenge_id text := 'cn_oura_sleep_score_2';
  v_contest_id uuid;
BEGIN
  -- Get user ID for clay@healthrocket.life
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'clay@healthrocket.life';
  
  -- Get contest ID
  SELECT id INTO v_contest_id
  FROM contests
  WHERE challenge_id = v_challenge_id;
  
  -- If both exist, clean up any registrations
  IF v_user_id IS NOT NULL AND v_contest_id IS NOT NULL THEN
    -- Delete from active_contests
    DELETE FROM active_contests
    WHERE user_id = v_user_id AND challenge_id = v_challenge_id;
    
    -- Delete from contest_registrations
    DELETE FROM contest_registrations
    WHERE user_id = v_user_id AND contest_id = v_contest_id;
    
    -- Delete from challenges (legacy)
    DELETE FROM challenges
    WHERE user_id = v_user_id AND challenge_id = v_challenge_id;
    
    RAISE NOTICE 'Cleaned up any existing registrations for contest %', v_challenge_id;
  END IF;
END $$;