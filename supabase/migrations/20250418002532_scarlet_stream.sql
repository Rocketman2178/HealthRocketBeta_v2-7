/*
  # Fix Contest Players Function

  1. Changes
    - Drop existing function to avoid conflicts
    - Create improved get_contest_players function
    - Handle both active_contests and challenges tables
    - Return complete player information
    
  2. Security
    - Uses security definer to ensure proper access control
    - Returns only necessary player information
*/

-- Drop existing function if it exists to avoid conflicts
DROP FUNCTION IF EXISTS get_contest_players(text);

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

-- Create a test function to verify if a user is registered for a contest
CREATE OR REPLACE FUNCTION is_registered_for_contest(
  p_user_id uuid,
  p_challenge_id text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_registered boolean;
BEGIN
  -- Check in active_contests
  SELECT EXISTS (
    SELECT 1
    FROM active_contests
    WHERE user_id = p_user_id
      AND challenge_id = p_challenge_id
  ) INTO v_is_registered;
  
  -- If not found, check in challenges
  IF NOT v_is_registered THEN
    SELECT EXISTS (
      SELECT 1
      FROM challenges
      WHERE user_id = p_user_id
        AND challenge_id = p_challenge_id
        AND category = 'Contests'
    ) INTO v_is_registered;
  END IF;
  
  RETURN v_is_registered;
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION is_registered_for_contest(uuid, text) TO public;