/*
  # Fix Contest Registration Process

  1. Changes
    - Create a function to register for contests using credits
    - Ensure contest_id is properly set in contest_registrations
    - Add support for registering with credits
    
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
    SELECT 1 FROM contest_registrations 
    WHERE user_id = p_user_id AND contest_id = v_contest_id
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Already registered for this contest'
    );
  END IF;
  
  -- Check if user has credits
  SELECT contest_credits INTO v_credits
  FROM users
  WHERE id = p_user_id;
  
  IF v_credits IS NULL OR v_credits <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No contest credits available'
    );
  END IF;
  
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
    'active_contest_id', v_active_contest_id
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION register_contest_with_credits(uuid, text) TO public;

-- Create function to register for contests with active_contests
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
  v_active_contest_id uuid;
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
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Already registered for this contest'
    );
  END IF;
  
  -- Create contest registration for free contests
  INSERT INTO contest_registrations (
    contest_id,
    user_id,
    payment_status,
    registered_at
  ) VALUES (
    v_contest_id,
    p_user_id,
    'paid', -- Free contests are considered paid
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
    'active_contest_id', v_active_contest_id
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION register_contest_with_active_contests(uuid, text) TO public;