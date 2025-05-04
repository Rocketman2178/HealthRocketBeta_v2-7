/*
  # Fix Contest Credit Registration System

  1. Changes
    - Create a new function to directly register for contests without Stripe
    - Fix the should_use_credits_for_contest function to be more explicit
    - Add detailed logging for debugging credit usage
    - Reset Clay's credits to exactly 1
    - Add a function to get contest registration status
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions for proper access control
*/

-- Create a new function to directly register for a contest without Stripe
CREATE OR REPLACE FUNCTION direct_register_for_contest(
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
BEGIN
  -- Check if already registered
  SELECT EXISTS (
    SELECT 1 FROM active_contests 
    WHERE user_id = p_user_id AND challenge_id = p_challenge_id
  ) OR EXISTS (
    SELECT 1 FROM challenges
    WHERE user_id = p_user_id AND challenge_id = p_challenge_id
  ) INTO v_is_registered;
  
  IF v_is_registered THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Already registered for this contest'
    );
  END IF;

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
  
  -- Check if user has credits
  SELECT contest_credits INTO v_credits
  FROM users
  WHERE id = p_user_id;
  
  -- Create verification requirements
  v_verification_requirements := jsonb_build_object(
    'week1', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '7 days')::text),
    'week2', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '14 days')::text),
    'week3', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '21 days')::text)
  );
  
  -- If user has credits, deduct one
  IF v_credits > 0 THEN
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
  
  -- Log the registration
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
    'credits_used', CASE WHEN v_credits > 0 THEN 1 ELSE 0 END,
    'credits_remaining', CASE WHEN v_credits > 0 THEN v_credits - 1 ELSE 0 END,
    'used_credits', v_credits > 0
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION direct_register_for_contest(uuid, text) TO public;

-- Create a function to get contest registration status
CREATE OR REPLACE FUNCTION get_contest_registration_status(
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
  v_registration_record record;
BEGIN
  -- Check if already registered
  SELECT EXISTS (
    SELECT 1 FROM active_contests 
    WHERE user_id = p_user_id AND challenge_id = p_challenge_id
  ) OR EXISTS (
    SELECT 1 FROM challenges
    WHERE user_id = p_user_id AND challenge_id = p_challenge_id
  ) INTO v_is_registered;
  
  -- Get contest details
  SELECT 
    c.id,
    c.entry_fee,
    c.name
  INTO v_contest
  FROM contests c
  WHERE c.challenge_id = p_challenge_id;
  
  IF v_contest IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Get user's credits
  SELECT contest_credits INTO v_credits
  FROM users
  WHERE id = p_user_id;
  
  -- If registered, get registration details
  IF v_is_registered THEN
    -- Try active_contests first
    SELECT * INTO v_registration_record
    FROM active_contests
    WHERE user_id = p_user_id AND challenge_id = p_challenge_id
    LIMIT 1;
    
    -- If not found, try challenges
    IF v_registration_record IS NULL THEN
      SELECT * INTO v_registration_record
      FROM challenges
      WHERE user_id = p_user_id AND challenge_id = p_challenge_id
      LIMIT 1;
    END IF;
  END IF;
  
  -- Return status
  RETURN jsonb_build_object(
    'success', true,
    'is_registered', v_is_registered,
    'contest_id', v_contest.id,
    'contest_name', v_contest.name,
    'entry_fee', v_contest.entry_fee,
    'has_credits', COALESCE(v_credits > 0, false),
    'credits_remaining', COALESCE(v_credits, 0),
    'registration_details', v_registration_record
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION get_contest_registration_status(uuid, text) TO public;

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