/*
  # Add Oura Sleep Score Contests

  1. New Contests
    - Add two Oura Sleep Score contests to the contests table
    - Set start date to May 10, 2025 for both contests
    - Configure contest parameters including entry fee, prize pool, and requirements
    
  2. Security
    - Maintain existing RLS policies
*/

-- Insert the Oura Sleep Score Contest
INSERT INTO public.contests (
  id,
  entry_fee,
  min_players,
  max_players,
  start_date,
  registration_end_date,
  prize_pool,
  status,
  health_category,
  name,
  description,
  requirements,
  expert_reference,
  how_to_play,
  implementation_protocol,
  success_metrics,
  expert_tips,
  fuel_points,
  duration,
  requires_device,
  challenge_id,
  created_at,
  updated_at
)
VALUES (
  gen_random_uuid(),
  1, -- Entry fee in credits
  1, -- Min players
  50, -- Max players
  '2025-05-10 04:00:00.000Z'::timestamptz, -- Start date: May 10, 2025
  '2025-05-09 04:00:00.000Z'::timestamptz, -- Registration ends one day before
  75, -- Prize pool
  'pending', -- Status
  'Sleep', -- Health category
  'Oura Sleep Score Contest', -- Name
  'Achieve the highest average weekly Sleep Score from your Oura Ring app. Compete with other players to win credits and improve your sleep quality.', -- Description
  jsonb_build_array(
    jsonb_build_object(
      'description', 'Daily sleep score verification (75% of score)',
      'verificationMethod', 'verification_posts',
      'weight', 75
    ),
    jsonb_build_object(
      'description', 'Weekly sleep score average verification (25% of score)',
      'verificationMethod', 'verification_posts',
      'weight', 25
    )
  ), -- Requirements
  'Health Rocket Team - Gamifying Health to Increase HealthSpan', -- Expert reference
  jsonb_build_object(
    'description', 'Join this Contest to compete for credits while optimizing your sleep quality:',
    'steps', jsonb_build_array(
      'Register with 1 Contest Entry Credit to secure your spot',
      'Post daily sleep score screenshots in the Challenge Chat',
      'Post your weekly sleep score average on the final day',
      'Track your progress on the leaderboard',
      'Top 10% share 75% of prize pool, top 50% get credit back'
    )
  ), -- How to play
  jsonb_build_object(
    'week1', 'Track and post your daily sleep score from the Oura Ring app each day. On the final day, post your weekly sleep score average from the Oura Ring app.'
  ), -- Implementation protocol
  jsonb_build_array(
    'Daily verification posts (0/7)',
    'Weekly average verification post (0/1)'
  ), -- Success metrics
  jsonb_build_array(
    'Maintain consistent sleep/wake times',
    'Optimize bedroom temperature (65-67°F)',
    'Limit blue light exposure before bed',
    'Practice relaxation techniques',
    'Track and optimize your sleep latency'
  ), -- Expert tips
  50, -- Fuel points
  7, -- Duration in days
  false, -- Requires device
  'cn_oura_sleep_score', -- Challenge ID
  now(), -- Created at
  now() -- Updated at
);

-- Insert the Oura Sleep Score Contest 2
INSERT INTO public.contests (
  id,
  entry_fee,
  min_players,
  max_players,
  start_date,
  registration_end_date,
  prize_pool,
  status,
  health_category,
  name,
  description,
  requirements,
  expert_reference,
  how_to_play,
  implementation_protocol,
  success_metrics,
  expert_tips,
  fuel_points,
  duration,
  requires_device,
  challenge_id,
  created_at,
  updated_at
)
VALUES (
  gen_random_uuid(),
  1, -- Entry fee in credits
  1, -- Min players
  50, -- Max players
  '2025-05-10 04:00:00.000Z'::timestamptz, -- Start date: May 10, 2025
  '2025-05-09 04:00:00.000Z'::timestamptz, -- Registration ends one day before
  75, -- Prize pool
  'pending', -- Status
  'Sleep', -- Health category
  'Oura Sleep Score Contest 2', -- Name
  'Achieve the highest average weekly Sleep Score from your Oura Ring app. Compete with other players to win credits and improve your sleep quality.', -- Description
  jsonb_build_array(
    jsonb_build_object(
      'description', 'Daily sleep score verification (75% of score)',
      'verificationMethod', 'verification_posts',
      'weight', 75
    ),
    jsonb_build_object(
      'description', 'Weekly sleep score average verification (25% of score)',
      'verificationMethod', 'verification_posts',
      'weight', 25
    )
  ), -- Requirements
  'Health Rocket Team - Gamifying Health to Increase HealthSpan', -- Expert reference
  jsonb_build_object(
    'description', 'Join this Contest to compete for credits while optimizing your sleep quality:',
    'steps', jsonb_build_array(
      'Register with 1 Contest Entry Credit to secure your spot',
      'Post daily sleep score screenshots in the Challenge Chat',
      'Post your weekly sleep score average on the final day',
      'Track your progress on the leaderboard',
      'Top 10% share 75% of prize pool, top 50% get credit back'
    )
  ), -- How to play
  jsonb_build_object(
    'week1', 'Track and post your daily sleep score from the Oura Ring app each day. On the final day, post your weekly sleep score average from the Oura Ring app.'
  ), -- Implementation protocol
  jsonb_build_array(
    'Daily verification posts (0/7)',
    'Weekly average verification post (0/1)'
  ), -- Success metrics
  jsonb_build_array(
    'Maintain consistent sleep/wake times',
    'Optimize bedroom temperature (65-67°F)',
    'Limit blue light exposure before bed',
    'Practice relaxation techniques',
    'Track and optimize your sleep latency'
  ), -- Expert tips
  50, -- Fuel points
  7, -- Duration in days
  false, -- Requires device
  'cn_oura_sleep_score_2', -- Challenge ID
  now(), -- Created at
  now() -- Updated at
);

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'add_oura_sleep_contests',
    'description', 'Added two Oura Sleep Score contests with May 10, 2025 start date',
    'timestamp', now()
  )
);