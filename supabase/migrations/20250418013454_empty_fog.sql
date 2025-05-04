/*
  # Fix Contest Registration with Credits

  1. Changes
    - Update register_contest_with_credits function to properly check for credits
    - Add check for credits in startContest function
    - Ensure users with credits are not redirected to Stripe
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create or replace function to register for contests using credits
CREATE OR REPLACE FUNCTION register_contest_with_credits(
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
  v_plan text;
  v_is_preview boolean;
BEGIN
  -- Get contest ID from challenge_id
  SELECT id INTO v_contest_id
  FROM contests
  WHERE challenge_id = p_challenge_id;
  
  IF v_contest_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Check if already registered
  IF EXISTS (
    SELECT 1 FROM active_contests 
    WHERE user_id = p_user_id AND challenge_id = p_challenge_id
  ) OR EXISTS (
    SELECT 1 FROM contest_registrations
    WHERE user_id = p_user_id AND contest_id = v_contest_id
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Already registered for this contest'
    );
  END IF;
  
  -- Check if user has credits and is on Preview Access
  SELECT 
    contest_credits,
    plan
  INTO 
    v_credits,
    v_plan
  FROM users
  WHERE id = p_user_id;
  
  v_is_preview := (v_plan = 'Preview Access');
  
  IF (v_credits IS NULL OR v_credits <= 0) AND v_is_preview THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No contest credits available'
    );
  END IF;
  
  -- Only deduct credits for Preview Access users
  IF v_is_preview AND v_credits > 0 THEN
    -- Deduct one credit
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
    started_at
  ) VALUES (
    p_user_id,
    v_contest_id,
    p_challenge_id,
    'active',
    now()
  )
  RETURNING id INTO v_active_contest_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'active_contest_id', v_active_contest_id,
    'used_credits', v_is_preview AND v_credits > 0
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION register_contest_with_credits(uuid, text) TO public;

-- Create a function to check if a user should use credits for a contest
CREATE OR REPLACE FUNCTION should_use_credits_for_contest(
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
  v_plan text;
  v_is_preview boolean;
BEGIN
  -- Get contest details
  SELECT 
    c.id,
    c.entry_fee
  INTO v_contest
  FROM contests c
  WHERE c.challenge_id = p_challenge_id;
  
  IF v_contest IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Check if user has credits and is on Preview Access
  SELECT 
    contest_credits,
    plan
  INTO 
    v_credits,
    v_plan
  FROM users
  WHERE id = p_user_id;
  
  v_is_preview := (v_plan = 'Preview Access');
  
  -- Determine if credits should be used
  RETURN jsonb_build_object(
    'success', true,
    'should_use_credits', v_is_preview AND v_credits > 0 AND v_contest.entry_fee > 0,
    'is_free_contest', v_contest.entry_fee = 0,
    'has_credits', COALESCE(v_credits > 0, false),
    'is_preview', v_is_preview,
    'credits_remaining', COALESCE(v_credits, 0)
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION should_use_credits_for_contest(uuid, text) TO public;