/*
  # Fix Contest Registration Process

  1. Changes
    - Create a function to register for contests using active_contests table
    - Remove dependencies on premium_challenges table
    - Ensure contest registration works with credits
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create or replace function to register for contests using active_contests
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
  v_contest_id uuid;
  v_contest_data record;
  v_active_contest_id uuid;
  v_credits integer;
BEGIN
  -- Get contest details
  SELECT id, entry_fee, min_players, max_players, start_date, health_category
  INTO v_contest_data
  FROM contests
  WHERE challenge_id = p_challenge_id;
  
  IF v_contest_data IS NULL THEN
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
    SELECT 1 FROM challenges
    WHERE user_id = p_user_id AND challenge_id = p_challenge_id
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Already registered for this contest'
    );
  END IF;
  
  -- Check if user has credits (for free contests or if using credits)
  SELECT contest_credits INTO v_credits
  FROM users
  WHERE id = p_user_id;
  
  -- For free contests, no credits needed
  IF v_contest_data.entry_fee = 0 OR v_credits > 0 THEN
    -- If using credits, deduct one
    IF v_contest_data.entry_fee > 0 AND v_credits > 0 THEN
      UPDATE users
      SET contest_credits = contest_credits - 1
      WHERE id = p_user_id;
    END IF;
    
    -- Insert into active_contests
    INSERT INTO active_contests (
      user_id,
      contest_id,
      challenge_id,
      status,
      progress,
      started_at,
      verification_requirements
    ) VALUES (
      p_user_id,
      v_contest_data.id,
      p_challenge_id,
      'active',
      0,
      now(),
      jsonb_build_object(
        'week1', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '7 days')::text),
        'week2', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '14 days')::text),
        'week3', jsonb_build_object('required', 1, 'completed', 0, 'deadline', (now() + interval '21 days')::text)
      )
    )
    RETURNING id INTO v_active_contest_id;
    
    -- Create contest registration record
    INSERT INTO contest_registrations (
      contest_id,
      user_id,
      payment_status,
      registered_at
    ) VALUES (
      v_contest_data.id,
      p_user_id,
      CASE WHEN v_contest_data.entry_fee = 0 THEN 'paid' ELSE 'credit' END,
      now()
    );
    
    RETURN jsonb_build_object(
      'success', true,
      'active_contest_id', v_active_contest_id,
      'used_credits', v_contest_data.entry_fee > 0 AND v_credits > 0
    );
  ELSE
    -- Not enough credits and not a free contest
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Payment required for this contest'
    );
  END IF;
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION register_contest_with_active_contests(uuid, text) TO public;

-- Create function to check contest eligibility
CREATE OR REPLACE FUNCTION check_contest_eligibility(
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
  v_has_device boolean;
  v_device_connected boolean;
BEGIN
  -- Get contest details
  SELECT 
    c.id,
    c.entry_fee,
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
  
  -- Check if user has required device connected
  IF v_contest.requires_device THEN
    SELECT EXISTS (
      SELECT 1
      FROM user_devices
      WHERE user_id = p_user_id
        AND provider = LOWER(v_contest.required_device)
        AND status = 'active'
    ) INTO v_device_connected;
  ELSE
    v_device_connected := true;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'has_credits', COALESCE(v_credits > 0, false),
    'credits_remaining', COALESCE(v_credits, 0),
    'requires_device', v_contest.requires_device,
    'required_device', v_contest.required_device,
    'device_connected', v_device_connected,
    'entry_fee', v_contest.entry_fee
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION check_contest_eligibility(uuid, text) TO public;