/*
  # Fix Complete Boost Function

  1. Changes
    - Update the get_boost_category function to properly handle boost categories
    - Fix the complete_boost function to ensure it has a proper destination for result data
    - Add proper error handling for missing boost categories
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create a function to get boost category from boost_id if not found in boost_fp_values
CREATE OR REPLACE FUNCTION get_boost_category(p_boost_id text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category text;
BEGIN
  -- First try to get from boost_fp_values
  SELECT category INTO v_category
  FROM boost_fp_values
  WHERE boost_id = p_boost_id;
  
  -- If not found, try to extract from boost_id (e.g., 'mindset-t1-1')
  IF v_category IS NULL THEN
    -- Extract category from boost_id format (e.g., 'mindset-t1-1' -> 'mindset')
    v_category := split_part(p_boost_id, '-', 1);
    
    -- Validate that it's a known category
    IF v_category NOT IN ('mindset', 'sleep', 'exercise', 'nutrition', 'biohacking') THEN
      -- Default to 'general' if unknown
      v_category := 'general';
    END IF;
  END IF;
  
  RETURN v_category;
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION get_boost_category(text) TO public;

-- Update the complete_boost function to fix the "query has no destination for result data" error
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
  v_result jsonb;
BEGIN
  -- Get FP value for the boost
  SELECT fp_value, category INTO v_fp_value, v_boost_category
  FROM boost_fp_values
  WHERE boost_id = p_boost_id;
  
  -- Default to 1 FP if not found
  v_fp_value := COALESCE(v_fp_value, 1);
  
  -- If category not found, try to determine from boost_id
  IF v_boost_category IS NULL THEN
    v_boost_category := get_boost_category(p_boost_id);
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
  
  -- Return success with FP earned and category
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
    'operation', 'fix_complete_boost_function',
    'description', 'Fixed complete_boost function to properly handle result data and boost categories',
    'timestamp', now()
  )
);