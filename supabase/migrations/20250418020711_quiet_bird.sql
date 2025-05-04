-- First drop the existing function if it exists
DROP FUNCTION IF EXISTS is_user_registered_for_contest(uuid, text);

-- Create a more robust function to check if a user is registered for a contest
CREATE OR REPLACE FUNCTION is_user_registered_for_contest(
  p_user_id uuid,
  p_challenge_id text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contest_id uuid;
  v_is_registered boolean := false;
BEGIN
  -- Get contest ID from challenge_id
  SELECT id INTO v_contest_id
  FROM contests
  WHERE challenge_id = p_challenge_id;
  
  IF v_contest_id IS NULL THEN
    RETURN false;
  END IF;
  
  -- Check active_contests table
  SELECT EXISTS (
    SELECT 1 
    FROM active_contests 
    WHERE user_id = p_user_id AND challenge_id = p_challenge_id
  ) INTO v_is_registered;
  
  -- If not found in active_contests, check challenges table
  IF NOT v_is_registered THEN
    SELECT EXISTS (
      SELECT 1 
      FROM challenges
      WHERE user_id = p_user_id AND challenge_id = p_challenge_id
    ) INTO v_is_registered;
  END IF;
  
  -- Log the check for debugging
  INSERT INTO contest_registration_logs (
    user_id,
    contest_id,
    is_registered,
    checked_at
  ) VALUES (
    p_user_id,
    'check_' || p_challenge_id,
    v_is_registered,
    now()
  );
  
  RETURN v_is_registered;
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION is_user_registered_for_contest(uuid, text) TO public;

-- First drop the existing function if it exists
DROP FUNCTION IF EXISTS check_contest_eligibility_credits(uuid, text);

-- Update the check_contest_eligibility_credits function to use the new check
CREATE OR REPLACE FUNCTION check_contest_eligibility_credits(
  p_user_id uuid,
  p_challenge_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contest record;
  v_credits integer;
  v_is_registered boolean;
BEGIN
  -- Use the new function to check if already registered
  SELECT is_user_registered_for_contest(p_user_id, p_challenge_id) INTO v_is_registered;
  
  IF v_is_registered THEN
    RETURN jsonb_build_object(
      'success', true,
      'is_eligible', false,
      'reason', 'Already registered',
      'has_credits', false,
      'credits_remaining', 0,
      'already_registered', true
    );
  END IF;

  -- Get contest details
  SELECT 
    c.id,
    c.entry_fee,
    c.name,
    c.start_date,
    c.requires_device,
    c.required_device
  INTO v_contest
  FROM contests c
  WHERE c.challenge_id = p_challenge_id;
  
  IF v_contest IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Check if user has credits
  SELECT contest_credits INTO v_credits
  FROM users
  WHERE id = p_user_id;
  
  -- Log the eligibility check
  INSERT INTO contest_registration_logs (
    user_id,
    contest_id,
    is_registered,
    checked_at
  ) VALUES (
    p_user_id,
    v_contest.id::text,
    false,
    now()
  );
  
  -- If contest is free, user is eligible
  IF v_contest.entry_fee = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'is_eligible', true,
      'reason', 'Free contest',
      'has_credits', COALESCE(v_credits > 0, false),
      'credits_remaining', COALESCE(v_credits, 0),
      'contest_name', v_contest.name,
      'start_date', v_contest.start_date,
      'requires_device', v_contest.requires_device,
      'required_device', v_contest.required_device
    );
  END IF;
  
  -- If contest requires entry fee, check if user has credits
  IF v_contest.entry_fee > 0 AND (v_credits IS NULL OR v_credits <= 0) THEN
    RETURN jsonb_build_object(
      'success', true,
      'is_eligible', false,
      'reason', 'No credits available',
      'has_credits', false,
      'credits_remaining', 0,
      'contest_name', v_contest.name,
      'start_date', v_contest.start_date,
      'requires_device', v_contest.requires_device,
      'required_device', v_contest.required_device
    );
  END IF;
  
  -- User is eligible
  RETURN jsonb_build_object(
    'success', true,
    'is_eligible', true,
    'reason', 'Has credits',
    'has_credits', true,
    'credits_remaining', v_credits,
    'contest_name', v_contest.name,
    'start_date', v_contest.start_date,
    'requires_device', v_contest.requires_device,
    'required_device', v_contest.required_device
  );
END;
$$;

-- First drop the existing function if it exists
DROP FUNCTION IF EXISTS register_for_contest_with_credits(uuid, text);

-- Update the register_for_contest_with_credits function to use the new check
CREATE OR REPLACE FUNCTION register_for_contest_with_credits(
  p_user_id uuid,
  p_challenge_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contest_id uuid;
  v_credits integer;
  v_active_contest_id uuid;
  v_verification_requirements jsonb;
  v_is_registered boolean;
  v_contest_entry_fee numeric(10,2);
BEGIN
  -- Use the new function to check if already registered
  SELECT is_user_registered_for_contest(p_user_id, p_challenge_id) INTO v_is_registered;
  
  IF v_is_registered THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Already registered for this contest'
    );
  END IF;

  -- Get contest ID and entry fee from challenge_id
  SELECT id, entry_fee INTO v_contest_id, v_contest_entry_fee
  FROM contests
  WHERE challenge_id = p_challenge_id;
  
  IF v_contest_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Check if user has credits
  SELECT contest_credits INTO v_credits
  FROM users
  WHERE id = p_user_id;
  
  -- If contest requires entry fee and user has no credits, return error
  IF v_contest_entry_fee > 0 AND (v_credits IS NULL OR v_credits <= 0) THEN
    -- Log the failed attempt
    INSERT INTO contest_registration_logs (
      user_id,
      contest_id,
      is_registered,
      checked_at
    ) VALUES (
      p_user_id,
      v_contest_id::text,
      false,
      now()
    );
    
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No contest credits available',
      'credits_required', true
    );
  END IF;
  
  -- Create verification requirements
  v_verification_requirements := jsonb_build_object(
    'week1', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '7 days')::text),
    'week2', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '14 days')::text),
    'week3', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '21 days')::text)
  );
  
  -- If contest requires entry fee, deduct one credit
  IF v_contest_entry_fee > 0 AND v_credits > 0 THEN
    UPDATE users
    SET contest_credits = contest_credits - 1
    WHERE id = p_user_id;
  END IF;
  
  -- Create contest registration
  INSERT INTO contest_registrations (
    contest_id,
    user_id,
    payment_status,
    registered_at
  ) VALUES (
    v_contest_id,
    p_user_id,
    'paid',
    now()
  );
  
  -- Insert into active_contests
  INSERT INTO active_contests (
    user_id,
    contest_id,
    challenge_id,
    status,
    started_at,
    verification_requirements
  ) VALUES (
    p_user_id,
    v_contest_id,
    p_challenge_id,
    'active',
    now(),
    v_verification_requirements
  )
  RETURNING id INTO v_active_contest_id;
  
  -- Log the successful registration
  INSERT INTO contest_registration_logs (
    user_id,
    contest_id,
    is_registered,
    checked_at
  ) VALUES (
    p_user_id,
    v_contest_id::text,
    true,
    now()
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'active_contest_id', v_active_contest_id,
    'credits_used', CASE WHEN v_contest_entry_fee > 0 AND v_credits > 0 THEN 1 ELSE 0 END,
    'credits_remaining', CASE WHEN v_contest_entry_fee > 0 AND v_credits > 0 THEN v_credits - 1 ELSE v_credits END,
    'used_credits', v_contest_entry_fee > 0 AND v_credits > 0
  );
END;
$$;

-- Grant execute permissions to public
GRANT EXECUTE ON FUNCTION is_user_registered_for_contest(uuid, text) TO public;
GRANT EXECUTE ON FUNCTION check_contest_eligibility_credits(uuid, text) TO public;
GRANT EXECUTE ON FUNCTION register_for_contest_with_credits(uuid, text) TO public;

-- Reset Clay's contest credits to exactly 1
DO $$
DECLARE
  v_user_id uuid;
  v_current_credits integer;
  v_email text := 'clay@healthrocket.life';
BEGIN
  -- Get user ID for clay@healthrocket.life
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = v_email;
  
  -- If user exists, update credits
  IF v_user_id IS NOT NULL THEN
    -- Get current credits
    SELECT contest_credits INTO v_current_credits
    FROM users
    WHERE id = v_user_id;
    
    -- Update to exactly 1 credit
    UPDATE users
    SET contest_credits = 1
    WHERE id = v_user_id;
    
    -- Log the update
    INSERT INTO contest_registration_logs (
      user_id,
      contest_id,
      is_registered,
      checked_at
    ) VALUES (
      v_user_id,
      'credit_reset',
      false,
      now()
    );
    
    RAISE NOTICE 'Reset contest credits for % from % to 1', v_email, v_current_credits;
  ELSE
    RAISE NOTICE 'User % not found', v_email;
  END IF;
END $$;

-- Also check for any lingering registrations and remove them
DO $$
DECLARE
  v_user_id uuid;
  v_email text := 'clay@healthrocket.life';
  v_challenge_id text := 'cn_oura_sleep_score_2';
  v_contest_id uuid;
BEGIN
  -- Get user ID for clay@healthrocket.life
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = v_email;
  
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
    
    -- Log the cleanup
    INSERT INTO contest_registration_logs (
      user_id,
      contest_id,
      is_registered,
      checked_at
    ) VALUES (
      v_user_id,
      'cleanup_' || v_challenge_id,
      false,
      now()
    );
    
    RAISE NOTICE 'Cleaned up any existing registrations for % in contest %', v_email, v_challenge_id;
  END IF;
END $$;