/*
  # Fix get_upcoming_contests Function

  1. Changes
    - Fix the get_upcoming_contests function to use challenge_id instead of contest_id
    - Ensure proper column references in the function
    
  2. Security
    - Maintain existing RLS policies
*/

-- Create or replace function to get upcoming contests with correct column references
CREATE OR REPLACE FUNCTION get_upcoming_contests(
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  id uuid,
  challenge_id text,
  name text,
  description text,
  entry_fee numeric,
  min_players integer,
  max_players integer,
  start_date timestamptz,
  registration_end_date timestamptz,
  prize_pool numeric,
  status text,
  is_free boolean,
  health_category text,
  requirements jsonb,
  expert_reference text,
  how_to_play jsonb,
  implementation_protocol jsonb,
  success_metrics jsonb,
  expert_tips jsonb,
  fuel_points integer,
  duration integer,
  requires_device boolean,
  required_device text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.challenge_id,
    c.name,
    c.description,
    c.entry_fee,
    c.min_players,
    c.max_players,
    c.start_date,
    c.registration_end_date,
    c.prize_pool,
    c.status,
    c.is_free,
    c.health_category,
    c.requirements,
    c.expert_reference,
    c.how_to_play,
    c.implementation_protocol,
    c.success_metrics,
    c.expert_tips,
    c.fuel_points,
    c.duration,
    c.requires_device,
    c.required_device
  FROM contests c
  WHERE c.status = 'pending'
  AND c.registration_end_date > now()
  ORDER BY c.start_date ASC
  LIMIT p_limit;
END;
$$;