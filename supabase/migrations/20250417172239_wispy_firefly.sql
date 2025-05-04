/*
  # Fix Contest Category in Challenges Table

  1. Changes
    - Update all contest challenges to have category = 'Contests'
    - Ensure Morning Basics challenge has category = 'Challenge'
    - Add migration to fix existing challenges
    
  2. Security
    - Maintain existing RLS policies
*/

-- Update all contest challenges to have category = 'Contests'
UPDATE public.challenges
SET category = 'Contests'
WHERE challenge_id LIKE 'cn\\_%' OR challenge_id LIKE 'tc\\_%';

-- Make sure Morning Basics challenge has category = 'Challenge'
UPDATE public.challenges
SET category = 'Challenge'
WHERE challenge_id = 'tc0';

-- Create function to fix existing challenges
CREATE OR REPLACE FUNCTION fix_challenge_categories()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update all contest challenges to have category = 'Contests'
  UPDATE public.challenges
  SET category = 'Contests'
  WHERE (challenge_id LIKE 'cn\\_%' OR challenge_id LIKE 'tc\\_%')
  AND challenge_id != 'tc0';
  
  -- Make sure Morning Basics challenge has category = 'Challenge'
  UPDATE public.challenges
  SET category = 'Challenge'
  WHERE challenge_id = 'tc0';
  
  -- Update any challenges for Clay specifically
  UPDATE public.challenges
  SET category = 'Contests'
  WHERE user_id = (SELECT id FROM auth.users WHERE email = 'clay@healthrocket.life')
  AND (challenge_id LIKE 'cn\\_%' OR challenge_id LIKE 'tc\\_%')
  AND challenge_id != 'tc0';
END;
$$;

-- Run the fix function
SELECT fix_challenge_categories();

-- Drop the function after use
DROP FUNCTION fix_challenge_categories();