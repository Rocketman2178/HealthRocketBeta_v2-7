/*
  # Fix Sleep Boost Completion

  1. Changes
    - Ensure all sleep boosts are properly registered in the boost_fp_values table
    - Fix the complete_boost function to properly handle sleep boosts
    - Ensure consistent key naming in the response JSON
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- First, check if we have sleep boosts in the boost_fp_values table
DO $$
DECLARE
  v_sleep_boost_count integer;
BEGIN
  -- Count sleep boosts
  SELECT COUNT(*) INTO v_sleep_boost_count
  FROM boost_fp_values
  WHERE LOWER(category) = 'sleep';
  
  -- If no sleep boosts found, insert them
  IF v_sleep_boost_count = 0 THEN
    -- Insert tier 1 sleep boosts
    INSERT INTO boost_fp_values (boost_id, fp_value, category)
    VALUES 
      ('sleep-t1-1', 1, 'sleep'),
      ('sleep-t1-2', 2, 'sleep'),
      ('sleep-t1-3', 3, 'sleep'),
      ('sleep-t1-4', 4, 'sleep'),
      ('sleep-t1-5', 5, 'sleep'),
      ('sleep-t1-6', 6, 'sleep');
      
    -- Insert tier 2 sleep boosts
    INSERT INTO boost_fp_values (boost_id, fp_value, category)
    VALUES
      ('sleep-t2-1', 7, 'sleep'),
      ('sleep-t2-2', 8, 'sleep'),
      ('sleep-t2-3', 9, 'sleep');
    
    -- Log the insertion
    INSERT INTO boost_processing_logs (
      processed_at,
      boosts_processed,
      details
    ) VALUES (
      now(),
      9,
      jsonb_build_object(
        'operation', 'insert_sleep_boosts',
        'description', 'Added missing sleep boosts to boost_fp_values table',
        'timestamp', now()
      )
    );
  END IF;
END $$;

-- Create or replace the complete_boost function to properly handle the return value
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
  v_boost_category text;
BEGIN
  -- Get FP value for the boost
  SELECT fp_value, category INTO v_fp_value, v_boost_category
  FROM boost_fp_values
  WHERE boost_id = p_boost_id;
  
  -- Default to 1 FP if not found
  v_fp_value := COALESCE(v_fp_value, 1);
  
  -- If category not found, try to determine from boost_id
  IF v_boost_category IS NULL THEN
    -- Extract category from boost_id format (e.g., 'sleep-t1-1' -> 'sleep')
    v_boost_category := split_part(p_boost_id, '-', 1);
  END IF;
  
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
  
  -- Return success with FP earned and boost_category
  RETURN jsonb_build_object(
    'success', true,
    'completed_id', v_completed_id,
    'fp_earned', v_fp_value,
    'boost_category', v_boost_category
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION complete_boost(uuid, text) TO public;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'fix_sleep_boost_completion',
    'description', 'Fixed sleep boost completion by adding missing boost entries and fixing the complete_boost function',
    'timestamp', now()
  )
);