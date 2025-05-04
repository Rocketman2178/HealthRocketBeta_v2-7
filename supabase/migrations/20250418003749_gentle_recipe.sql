/*
  # Update Contest Credits for Clay

  1. Changes
    - Check and update contest credits for user clay@healthrocket.life
    - Ensure they have exactly 1 credit remaining
    - Only update if the user exists and has a different number of credits
    
  2. Security
    - Use security definer function
    - Drop function after use
*/

-- Create function to update Clay's contest credits
CREATE OR REPLACE FUNCTION update_clay_contest_credits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_current_credits integer;
BEGIN
  -- Get user ID for clay@healthrocket.life
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'clay@healthrocket.life';
  
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
      
      RAISE NOTICE 'Updated contest credits for clay@healthrocket.life from % to 1', v_current_credits;
    ELSE
      RAISE NOTICE 'User clay@healthrocket.life already has 1 contest credit';
    END IF;
  ELSE
    RAISE NOTICE 'User clay@healthrocket.life not found';
  END IF;
END;
$$;

-- Execute the function
SELECT update_clay_contest_credits();

-- Drop the function after use
DROP FUNCTION update_clay_contest_credits();

-- Create a function to check contest credits for any user
CREATE OR REPLACE FUNCTION check_contest_credits(
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
  v_is_preview boolean;
BEGIN
  -- Get user's credits and plan
  SELECT 
    contest_credits,
    plan
  INTO 
    v_credits,
    v_plan
  FROM users
  WHERE id = p_user_id;
  
  -- Determine if user is on preview access
  v_is_preview := (v_plan = 'Preview Access');
  
  -- Return credits info
  RETURN jsonb_build_object(
    'credits_remaining', COALESCE(v_credits, 0),
    'has_credits', COALESCE(v_credits > 0, false),
    'is_preview', v_is_preview
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION check_contest_credits(uuid) TO public;