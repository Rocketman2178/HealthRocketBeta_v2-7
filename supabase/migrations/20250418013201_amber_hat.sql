/*
  # Check and Update Clay's Contest Credits

  1. Changes
    - Create a function to check Clay's contest credits
    - Set credits to exactly 1 if not already set
    - Log the result for verification
    
  2. Security
    - Use security definer function
    - Restrict to specific user
*/

-- Create function to check and update Clay's contest credits
CREATE OR REPLACE FUNCTION check_clay_contest_credits()
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
  IF v_user_id IS NOT NULL THEN
    -- Get current credits
    SELECT contest_credits INTO v_current_credits
    FROM users
    WHERE id = v_user_id;
    
    -- Update to exactly 1 credit if different
    IF v_current_credits IS NULL OR v_current_credits != 1 THEN
      UPDATE users
      SET contest_credits = 1
      WHERE id = v_user_id;
      
      RETURN jsonb_build_object(
        'success', true,
        'message', format('Updated contest credits for %s from %s to 1', v_email, v_current_credits),
        'previous_credits', v_current_credits,
        'new_credits', 1
      );
    ELSE
      RETURN jsonb_build_object(
        'success', true,
        'message', format('User %s already has 1 contest credit', v_email),
        'credits', 1
      );
    END IF;
  ELSE
    RETURN jsonb_build_object(
      'success', false,
      'message', format('User %s not found', v_email)
    );
  END IF;
END;
$$;

-- Execute the function and store the result
DO $$
DECLARE
  result jsonb;
BEGIN
  SELECT check_clay_contest_credits() INTO result;
  RAISE NOTICE 'Result: %', result;
END
$$;

-- Drop the function after use
DROP FUNCTION check_clay_contest_credits();

-- Create a function to get a user's contest credits
CREATE OR REPLACE FUNCTION get_user_contest_credits(
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_credits integer;
  v_plan text;
  v_email text;
BEGIN
  -- Get user's credits, plan and email
  SELECT 
    u.contest_credits,
    u.plan,
    au.email
  INTO 
    v_credits,
    v_plan,
    v_email
  FROM users u
  JOIN auth.users au ON u.id = au.id
  WHERE u.id = p_user_id;
  
  -- Return credits info
  RETURN jsonb_build_object(
    'credits_remaining', COALESCE(v_credits, 0),
    'has_credits', COALESCE(v_credits > 0, false),
    'is_preview', v_plan = 'Preview Access',
    'email', v_email
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION get_user_contest_credits(uuid) TO public;