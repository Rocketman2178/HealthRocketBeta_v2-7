/*
  # Run All User Insights Generation

  1. Changes
    - Manually trigger the generate_all_user_insights() function
    - Force regeneration of insights for today
    - Return detailed results for verification including lifetime totals
*/

-- First, delete today's insights to force regeneration
DELETE FROM public.all_user_insights
WHERE date = current_date;

-- Run the generate_all_user_insights function and store the result
DO $$
DECLARE
  result jsonb;
BEGIN
  SELECT generate_all_user_insights() INTO result;
  
  -- Log the result
  RAISE NOTICE 'All user insights generation result: %', result;
  
  -- Also insert a log entry for reference
  INSERT INTO public.boost_processing_logs (
    processed_at,
    boosts_processed,
    details
  ) VALUES (
    now(),
    0,
    jsonb_build_object(
      'operation', 'generate_all_user_insights',
      'result', result,
      'timestamp', now()
    )
  );
END $$;

-- Verify the new columns have data
SELECT 
  date,
  total_users,
  active_users,
  total_healthspan_years,
  total_lifetime_fp,
  average_level,
  highest_level,
  total_boosts_completed,
  total_lifetime_boosts,
  total_challenges_completed,
  total_lifetime_challenges,
  total_quests_completed,
  total_lifetime_quests,
  total_chat_messages,
  total_lifetime_chat_messages,
  total_verification_posts,
  total_lifetime_verification_posts
FROM public.all_user_insights
WHERE date = current_date;