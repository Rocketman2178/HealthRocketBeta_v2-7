/*
  # Update Morning Basics Challenge Category

  1. Changes
    - Update the category for challenge_id 'mb0' from 'Contest' to 'Challenge'
    - Update the category in both the database and challenge library
    
  2. Security
    - Maintain existing RLS policies
*/

-- Update the category in the challenges table
UPDATE public.challenges
SET category = 'Challenge'
WHERE challenge_id = 'mb0';

-- Update the category in the challenge_library table
UPDATE public.challenge_library
SET category = 'Challenge'
WHERE id = 'mb0';

-- Create a function to update any existing challenges for users
CREATE OR REPLACE FUNCTION update_mb0_challenge_category()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update all existing Morning Basics challenges
  UPDATE public.challenges
  SET category = 'Challenge',
      challenge_id = 'mb0'
  WHERE challenge_id = 'tc0';
  
  -- Update the challenge_library table
  UPDATE public.challenge_library
  SET id = 'mb0'
  WHERE id = 'tc0';
END;
$$;

-- Execute the function to update existing challenges
SELECT update_mb0_challenge_category();

-- Drop the function after use
DROP FUNCTION update_mb0_challenge_category();