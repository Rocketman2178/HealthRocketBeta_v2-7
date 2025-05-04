/*
  # Add Oura Sleep Score Contest 2

  1. New Contest
    - Add a second Oura Sleep Score Contest to the contests table
    - Same parameters as the original contest but with a different ID and name
    - Set start date one month later than the original contest
    
  2. Security
    - Maintain existing RLS policies
*/

-- Insert the new contest into the contests table
INSERT INTO public.contests (
  id,
  entry_fee,
  min_players,
  max_players,
  start_date,
  registration_end_date,
  prize_pool,
  status,
  health_category,
  name,
  description,
  requirements,
  expert_reference,
  how_to_play,
  implementation_protocol,
  success_metrics,
  expert_tips,
  fuel_points,
  duration,
  requires_device,
  challenge_id
)
SELECT 
  gen_random_uuid(), -- Generate a new UUID for the contest
  entry_fee,
  min_players,
  max_players,
  '2025-05-20 04:00:00.000Z'::timestamptz, -- One month later
  '2025-05-19 04:00:00.000Z'::timestamptz, -- One day before start
  prize_pool,
  status,
  health_category,
  'Oura Sleep Score Contest 2', -- New name
  description,
  requirements,
  expert_reference,
  how_to_play,
  implementation_protocol,
  success_metrics,
  expert_tips,
  fuel_points,
  duration,
  requires_device,
  'cn_oura_sleep_score_2' -- New challenge_id
FROM public.contests
WHERE challenge_id = 'cn_oura_sleep_score'
LIMIT 1;

-- Create function to check if the new contest exists
CREATE OR REPLACE FUNCTION check_contest_exists()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  -- Check if the contest already exists
  SELECT COUNT(*) INTO v_count
  FROM public.contests
  WHERE challenge_id = 'cn_oura_sleep_score_2';
  
  -- If it doesn't exist, insert it
  IF v_count = 0 THEN
    INSERT INTO public.contests (
      id,
      entry_fee,
      min_players,
      max_players,
      start_date,
      registration_end_date,
      prize_pool,
      status,
      health_category,
      name,
      description,
      requirements,
      expert_reference,
      how_to_play,
      implementation_protocol,
      success_metrics,
      expert_tips,
      fuel_points,
      duration,
      requires_device,
      challenge_id
    )
    SELECT 
      gen_random_uuid(), -- Generate a new UUID for the contest
      entry_fee,
      min_players,
      max_players,
      '2025-05-20 04:00:00.000Z'::timestamptz, -- One month later
      '2025-05-19 04:00:00.000Z'::timestamptz, -- One day before start
      prize_pool,
      status,
      health_category,
      'Oura Sleep Score Contest 2', -- New name
      description,
      requirements,
      expert_reference,
      how_to_play,
      implementation_protocol,
      success_metrics,
      expert_tips,
      fuel_points,
      duration,
      requires_device,
      'cn_oura_sleep_score_2' -- New challenge_id
    FROM public.contests
    WHERE challenge_id = 'cn_oura_sleep_score'
    LIMIT 1;
  END IF;
END;
$$;

-- Execute the function to ensure the contest exists
SELECT check_contest_exists();

-- Drop the function after use
DROP FUNCTION check_contest_exists();