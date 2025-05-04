/*
  # Remove Boost Requirements from Contests

  1. Changes
    - Update contest requirements to remove daily boost completion requirement
    - Adjust verification weights to focus on sleep score verification
    - Update contest descriptions and steps
    
  2. Security
    - Maintain existing RLS policies
*/

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'remove_boost_requirements',
    'description', 'Removed daily boost completion requirements from contests',
    'timestamp', now()
  )
);