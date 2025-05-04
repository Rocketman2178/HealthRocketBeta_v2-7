/*
  # Fix Contest Days Display

  1. Changes
    - Create a function to get contest details including start date
    - Ensure proper display of days until start for upcoming contests
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create function to get contest details
CREATE OR REPLACE FUNCTION get_contest_details(
  p_challenge_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contest record;
BEGIN
  -- Get contest details
  SELECT 
    c.id,
    c.name,
    c.description,
    c.entry_fee,
    c.min_players,
    c.max_players,
    c.start_date,
    c.registration_end_date,
    c.prize_pool,
    c.status,
    c.health_category,
    c.expert_reference,
    c.how_to_play,
    c.implementation_protocol,
    c.success_metrics,
    c.expert_tips,
    c.fuel_points,
    c.duration,
    c.requires_device,
    c.required_device,
    c.challenge_id
  INTO v_contest
  FROM contests c
  WHERE c.challenge_id = p_challenge_id;
  
  IF v_contest IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Return contest details
  RETURN jsonb_build_object(
    'success', true,
    'id', v_contest.id,
    'name', v_contest.name,
    'description', v_contest.description,
    'entry_fee', v_contest.entry_fee,
    'min_players', v_contest.min_players,
    'max_players', v_contest.max_players,
    'start_date', v_contest.start_date,
    'registration_end_date', v_contest.registration_end_date,
    'prize_pool', v_contest.prize_pool,
    'status', v_contest.status,
    'health_category', v_contest.health_category,
    'expert_reference', v_contest.expert_reference,
    'how_to_play', v_contest.how_to_play,
    'implementation_protocol', v_contest.implementation_protocol,
    'success_metrics', v_contest.success_metrics,
    'expert_tips', v_contest.expert_tips,
    'fuel_points', v_contest.fuel_points,
    'duration', v_contest.duration,
    'requires_device', v_contest.requires_device,
    'required_device', v_contest.required_device,
    'challenge_id', v_contest.challenge_id
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION get_contest_details(text) TO public;

-- Create function to get days until contest start
CREATE OR REPLACE FUNCTION get_days_until_contest_start(
  p_challenge_id text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start_date timestamptz;
  v_days_until_start integer;
BEGIN
  -- Get contest start date
  SELECT start_date INTO v_start_date
  FROM contests
  WHERE challenge_id = p_challenge_id;
  
  IF v_start_date IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Calculate days until start
  v_days_until_start := CEIL(EXTRACT(EPOCH FROM (v_start_date - now())) / 86400);
  
  RETURN v_days_until_start;
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION get_days_until_contest_start(text) TO public;