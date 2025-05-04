/*
  # Reset Clay's Contest Credits

  1. Changes
    - Reset Clay's contest credits to exactly 1
    - Ensure the user has the correct entry credits available
    - Log the update for auditing purposes
    
  2. Security
    - Use security definer function to ensure proper access control
    - Drop the function after use to prevent misuse
*/

-- Create function to reset Clay's contest credits
CREATE OR REPLACE FUNCTION reset_clay_contest_credits()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', format('User %s not found', v_email)
    );
  END IF;
  
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
  
  RETURN jsonb_build_object(
    'success', true,
    'message', format('Reset contest credits for %s from %s to 1', v_email, v_current_credits),
    'previous_credits', v_current_credits,
    'new_credits', 1
  );
END;
$$;

-- Execute the function and store the result
DO $$
DECLARE
  result jsonb;
BEGIN
  SELECT reset_clay_contest_credits() INTO result;
  RAISE NOTICE 'Result: %', result;
END
$$;

-- Drop the function after use
DROP FUNCTION reset_clay_contest_credits();