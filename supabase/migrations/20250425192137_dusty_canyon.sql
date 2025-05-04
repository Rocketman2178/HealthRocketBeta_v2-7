/*
  # Update Contest Start Dates

  1. Changes
    - Update Oura Sleep Score Contest start date to May 11, 2025
    - Update Oura Sleep Score Contest 2 start date to May 18, 2025
    - Update registration end dates to one day before start dates
    
  2. Security
    - Maintain existing RLS policies
*/

-- Update Oura Sleep Score Contest start date
UPDATE public.contests
SET 
  start_date = '2025-05-11 04:00:00.000Z'::timestamptz,
  registration_end_date = '2025-05-10 04:00:00.000Z'::timestamptz
WHERE challenge_id = 'cn_oura_sleep_score';

-- Update Oura Sleep Score Contest 2 start date
UPDATE public.contests
SET 
  start_date = '2025-05-18 04:00:00.000Z'::timestamptz,
  registration_end_date = '2025-05-17 04:00:00.000Z'::timestamptz
WHERE challenge_id = 'cn_oura_sleep_score_2';

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'update_contest_dates',
    'description', 'Updated contest start dates for Oura Sleep Score contests',
    'timestamp', now(),
    'changes', jsonb_build_object(
      'cn_oura_sleep_score', '2025-05-11',
      'cn_oura_sleep_score_2', '2025-05-18'
    )
  )
);