/*
  # Fix Contest Days Calculation

  1. Changes
    - Create a function to calculate days until contest start
    - Create a function to calculate days remaining for active contests
    - Ensure proper display of days for both upcoming and active contests
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create function to calculate days until contest start
CREATE OR REPLACE FUNCTION calculate_days_until_contest_start(
  p_start_date timestamptz
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_days_until_start integer;
BEGIN
  -- Calculate days until start
  v_days_until_start := CEIL(EXTRACT(EPOCH FROM (p_start_date - now())) / 86400);
  
  -- Return days until start (can be negative if start date is in the past)
  RETURN v_days_until_start;
END;
$$;

-- Create function to calculate days remaining for active contests
CREATE OR REPLACE FUNCTION calculate_contest_days_remaining(
  p_start_date timestamptz,
  p_duration integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_days_until_start integer;
  v_days_passed integer;
  v_days_remaining integer;
BEGIN
  -- Calculate days until start
  v_days_until_start := calculate_days_until_contest_start(p_start_date);
  
  -- If contest hasn't started yet, return days until start
  IF v_days_until_start > 0 THEN
    RETURN v_days_until_start;
  END IF;
  
  -- Calculate days passed since start
  v_days_passed := ABS(v_days_until_start);
  
  -- Calculate days remaining
  v_days_remaining := GREATEST(0, p_duration - v_days_passed);
  
  RETURN v_days_remaining;
END;
$$;

-- Create function to get contest days information
CREATE OR REPLACE FUNCTION get_contest_days_info(
  p_challenge_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contest record;
  v_days_until_start integer;
  v_days_remaining integer;
  v_has_started boolean;
BEGIN
  -- Get contest details
  SELECT 
    start_date,
    duration
  INTO v_contest
  FROM contests
  WHERE challenge_id = p_challenge_id;
  
  IF v_contest IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Calculate days until start
  v_days_until_start := calculate_days_until_contest_start(v_contest.start_date);
  
  -- Determine if contest has started
  v_has_started := v_days_until_start <= 0;
  
  -- Calculate days remaining if started
  IF v_has_started THEN
    v_days_remaining := calculate_contest_days_remaining(v_contest.start_date, v_contest.duration);
  ELSE
    v_days_remaining := v_days_until_start;
  END IF;
  
  -- Return contest days info
  RETURN jsonb_build_object(
    'success', true,
    'days_until_start', v_days_until_start,
    'days_remaining', v_days_remaining,
    'has_started', v_has_started,
    'start_date', v_contest.start_date,
    'duration', v_contest.duration
  );
END;
$$;

-- Grant execute permissions to public
GRANT EXECUTE ON FUNCTION calculate_days_until_contest_start(timestamptz) TO public;
GRANT EXECUTE ON FUNCTION calculate_contest_days_remaining(timestamptz, integer) TO public;
GRANT EXECUTE ON FUNCTION get_contest_days_info(text) TO public;