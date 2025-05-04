/*
  # Fix Complete Boost Function

  1. Changes
    - Update the complete_boost function to properly return data
    - Fix the SQL syntax error causing "query has no destination for result data"
    - Ensure the function returns the FP earned for the boost
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer function
*/

-- Create or replace the complete_boost function to properly return data
CREATE OR REPLACE FUNCTION complete_boost(
  p_user_id uuid,
  p_boost_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fp_value integer;
  v_completed_id uuid;
  v_today date := current_date;
  v_result jsonb;
BEGIN
  -- Get FP value for the boost
  SELECT fp_value INTO v_fp_value
  FROM boost_fp_values
  WHERE boost_id = p_boost_id;
  
  -- Default to 1 FP if not found
  v_fp_value := COALESCE(v_fp_value, 1);
  
  -- Check if already completed today
  IF EXISTS (
    SELECT 1
    FROM completed_boosts
    WHERE user_id = p_user_id
      AND boost_id = p_boost_id
      AND completed_date = v_today
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Boost already completed today',
      'fp_earned', 0
    );
  END IF;
  
  -- Insert completed boost
  INSERT INTO completed_boosts (
    user_id,
    boost_id,
    completed_at,
    completed_date
  ) VALUES (
    p_user_id,
    p_boost_id,
    now(),
    v_today
  )
  RETURNING id INTO v_completed_id;
  
  -- Update daily FP
  PERFORM update_daily_fp(
    p_user_id,
    v_today,
    v_fp_value,
    1, -- boosts_completed
    0, -- challenges_completed
    0  -- quests_completed
  );
  
  -- Return success with FP earned
  RETURN jsonb_build_object(
    'success', true,
    'completed_id', v_completed_id,
    'fp_earned', v_fp_value
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION complete_boost(uuid, text) TO public;

-- Create or replace the update_daily_fp function if it doesn't exist
CREATE OR REPLACE FUNCTION update_daily_fp(
  p_user_id uuid,
  p_date date,
  p_fp_earned integer,
  p_boosts_completed integer,
  p_challenges_completed integer,
  p_quests_completed integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert or update daily FP record
  INSERT INTO daily_fp (
    user_id,
    date,
    fp_earned,
    boosts_completed,
    challenges_completed,
    quests_completed
  ) VALUES (
    p_user_id,
    p_date,
    p_fp_earned,
    p_boosts_completed,
    p_challenges_completed,
    p_quests_completed
  )
  ON CONFLICT (user_id, date) DO UPDATE SET
    fp_earned = daily_fp.fp_earned + p_fp_earned,
    boosts_completed = daily_fp.boosts_completed + p_boosts_completed,
    challenges_completed = daily_fp.challenges_completed + p_challenges_completed,
    quests_completed = daily_fp.quests_completed + p_quests_completed;
    
  -- Update user's fuel points
  UPDATE users
  SET fuel_points = fuel_points + p_fp_earned
  WHERE id = p_user_id;
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION update_daily_fp(uuid, date, integer, integer, integer, integer) TO public;