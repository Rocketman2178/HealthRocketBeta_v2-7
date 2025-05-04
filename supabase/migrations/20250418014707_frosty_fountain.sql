/*
  # Fix Contest Credit Registration

  1. Changes
    - Update the should_use_credits_for_contest function to properly check credits
    - Improve the register_contest_with_credits function to handle registration correctly
    - Add detailed logging for credit usage
    - Fix the issue where users with credits are being redirected to Stripe
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions for proper access control
*/

-- Create or replace function to check if credits should be used
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
  v_is_registered boolean;
  v_contest_id uuid;
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
      'success', true,
      'should_use_credits', false,
      'is_free_contest', false,
      'has_credits', false,
      'is_preview', false,
      'credits_remaining', 0,
      'already_registered', true
    );
  END IF;

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
  
  -- Store contest ID for logging
  v_contest_id := v_contest.id;
  
  -- Check if user has credits
  SELECT 
    contest_credits,
    plan
  INTO 
    v_credits,
    v_plan
  FROM users
  WHERE id = p_user_id;
  
  v_is_preview := (v_plan = 'Preview Access');
  
  -- Log the credit check
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
  
  -- If contest is free, no need to use credits
  IF v_contest.entry_fee = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'should_use_credits', false,
      'is_free_contest', true,
      'has_credits', COALESCE(v_credits > 0, false),
      'is_preview', v_is_preview,
      'credits_remaining', COALESCE(v_credits, 0),
      'contest_id', v_contest_id
    );
  END IF;
  
  -- Determine if credits should be used - any user with credits can use them
  RETURN jsonb_build_object(
    'success', true,
    'should_use_credits', COALESCE(v_credits > 0, false),
    'is_free_contest', false,
    'has_credits', COALESCE(v_credits > 0, false),
    'is_preview', v_is_preview,
    'credits_remaining', COALESCE(v_credits, 0),
    'contest_id', v_contest_id
  );
END;
$$;

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
  v_is_registered boolean;
  v_verification_requirements jsonb;
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
  SELECT 
    contest_credits,
    plan
  INTO 
    v_credits,
    v_plan
  FROM users
  WHERE id = p_user_id;
  
  IF v_credits IS NULL OR v_credits <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No contest credits available'
    );
  END IF;
  
  -- Create verification requirements
  v_verification_requirements := jsonb_build_object(
    'week1', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '7 days')::text),
    'week2', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '14 days')::text),
    'week3', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '21 days')::text)
  );
  
  -- Deduct one credit
  UPDATE users
  SET contest_credits = contest_credits - 1
  WHERE id = p_user_id;
  
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
  
  -- Log the credit usage
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
    'credits_used', 1,
    'credits_remaining', v_credits - 1
  );
END;
$$;

-- Reset Clay's contest credits to 1
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
  
  -- If user exists, check and update credits
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
      true,
      now()
    );
    
    RAISE NOTICE 'Reset contest credits for % from % to 1', v_email, v_current_credits;
  ELSE
    RAISE NOTICE 'User % not found', v_email;
  END IF;
END $$;