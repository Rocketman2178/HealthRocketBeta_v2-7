/*
  # Remove Contest Boost Requirements

  1. Changes
    - Update contest requirements to remove boost requirements
    - Remove special handling of boosts connected to Contests
    - Simplify contest verification to focus on sleep score verification
    
  2. Security
    - Maintain existing RLS policies
*/

-- Update all contests to remove boost requirements directly
UPDATE public.contests
SET 
  requirements = jsonb_build_array(
    jsonb_build_object(
      'description', 'Daily sleep score verification (100% of score)',
      'verificationMethod', 'verification_posts',
      'weight', 100
    )
  ),
  success_metrics = jsonb_build_array(
    'Daily verification posts (0/7)',
    'Weekly average verification post (0/1)'
  )
WHERE health_category = 'Sleep';

-- Update how_to_play steps to remove boost requirements
UPDATE public.contests
SET how_to_play = jsonb_set(
  how_to_play,
  '{steps}',
  (
    SELECT jsonb_agg(
      CASE 
        WHEN jsonb_array_element::text LIKE '%Daily Sleep boost%' 
        THEN jsonb_build_string('Post daily sleep score screenshots in the Challenge Chat')
        ELSE jsonb_array_element
      END
    )
    FROM jsonb_array_elements(how_to_play->'steps') AS jsonb_array_element
  )
)
WHERE health_category = 'Sleep';

-- Log the update
INSERT INTO boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'update_contest_requirements',
    'description', 'Removed boost requirements from contests',
    'timestamp', now()
  )
);

-- Drop the update_contest_boost_count trigger function
DROP FUNCTION IF EXISTS update_contest_boost_count() CASCADE;

-- Drop the sync_contest_boost_counts function
DROP FUNCTION IF EXISTS sync_contest_boost_counts(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS sync_contest_boost_counts(uuid) CASCADE;

-- Create a new version of the complete_boost function that doesn't handle contest boosts
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
    'operation', 'remove_contest_boost_handling',
    'description', 'Removed special boost handling for contests',
    'timestamp', now()
  )
);