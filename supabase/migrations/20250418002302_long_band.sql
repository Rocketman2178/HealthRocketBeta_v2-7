/*
  # Add Contest Players Function

  1. New Functions
    - `get_contest_players` - Retrieves players registered for a specific contest
    - Handles both active_contests and challenges tables for backward compatibility
    
  2. Security
    - Uses security definer to ensure proper access control
    - Returns only necessary player information
*/

-- Create function to get players registered for a contest
CREATE OR REPLACE FUNCTION get_contest_players(
  p_challenge_id text
)
RETURNS TABLE (
  user_id uuid,
  name text,
  avatar_url text,
  level integer,
  plan text,
  health_score numeric,
  healthspan_years numeric,
  created_at timestamptz,
  burn_streak integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- First check active_contests table
  RETURN QUERY
  SELECT 
    u.id,
    u.name,
    u.avatar_url,
    u.level,
    u.plan,
    u.health_score,
    u.healthspan_years,
    u.created_at,
    u.burn_streak
  FROM active_contests ac
  JOIN users u ON ac.user_id = u.id
  WHERE ac.challenge_id = p_challenge_id
  
  UNION
  
  -- Then check challenges table for backward compatibility
  SELECT 
    u.id,
    u.name,
    u.avatar_url,
    u.level,
    u.plan,
    u.health_score,
    u.healthspan_years,
    u.created_at,
    u.burn_streak
  FROM challenges c
  JOIN users u ON c.user_id = u.id
  WHERE c.challenge_id = p_challenge_id
    AND c.category = 'Contests';
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION get_contest_players(text) TO public;