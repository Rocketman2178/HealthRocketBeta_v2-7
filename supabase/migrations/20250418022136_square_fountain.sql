/*
  # Reset Contest Registration and Credits

  1. Changes
    - Remove any existing registrations for the Oura Sleep Score Contest 2
    - Reset Clay's contest credits to exactly 1
    - Fix parameter naming in contest registration functions
    
  2. Security
    - Maintain existing RLS policies
*/

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS is_user_registered_for_contest(uuid, text);

-- Create a new version of the function with proper parameter names
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

-- Clean up any existing registrations for the Oura Sleep Score Contest 2
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