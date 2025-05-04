-- Add a unique constraint on challenge_id if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'contests_challenge_id_key') THEN
        ALTER TABLE public.contests ADD CONSTRAINT contests_challenge_id_key UNIQUE (challenge_id);
    END IF;
END $$;

-- Insert Oura Sleep Score Contest
INSERT INTO public.contests (
  challenge_id,
  name,
  description,
  entry_fee,
  min_players,
  max_players,
  start_date,
  registration_end_date,
  prize_pool,
  status,
  is_free,
  health_category,
  requirements,
  expert_reference,
  how_to_play,
  implementation_protocol,
  success_metrics,
  expert_tips,
  fuel_points,
  duration,
  requires_device,
  required_device
) VALUES (
  'tc_oura_sleep_score',
  'Oura Sleep Score Contest',
  'Achieve the highest average weekly Sleep Score from your Oura Ring app.

In every Contest:

The top 10% performer(s) share 75% of the available reward pool, which could mean:

- 8 players: $450 for top player (6X return)
- 20 players: $450 each for top 2 players (6X return)
- 50 players: $450 each for top 5 players (6X return)

Plus: Score in the top 50% and earn your entry fee back. All other entry fees are forfeited.',
  75.00,
  4,
  null,
  '2025-04-20 04:00:00+00', -- 12:00 AM EDT = 4:00 AM UTC
  '2025-04-19 03:59:59+00', -- 11:59 PM EDT = 3:59 AM UTC
  0.00, -- Will be calculated based on registrations
  'pending',
  false,
  'Sleep',
  '[
    {"weight": 50, "description": "Daily sleep score verification (50% of score)", "verificationMethod": "verification_posts"},
    {"weight": 25, "description": "Weekly sleep score average verification (25% of score)", "verificationMethod": "verification_posts"},
    {"weight": 25, "description": "Daily Sleep boost completion (25% of score)", "verificationMethod": "boost_completion"}
  ]'::jsonb,
  'Health Rocket Team - Gamifying Health to Increase HealthSpan',
  '{
    "description": "Join this Contest to compete for prizes while optimizing your sleep quality:",
    "steps": [
      "Register with $75 entry fee or 1 Contest Entry Credit to secure your spot",
      "Post daily sleep score screenshots in the Challenge Chat",
      "Complete at least one Sleep category boost daily",
      "Post your weekly sleep score average on the final day",
      "Track your progress on the leaderboard",
      "Top 10% share 75% of prize pool, top 50% get entry fee back"
    ]
  }'::jsonb,
  '{
    "week1": "Track and post your daily sleep score from the Oura Ring app each day. Complete at least one Sleep category boost daily. On the final day, post your weekly sleep score average from the Oura Ring app."
  }'::jsonb,
  '["Daily verification posts (0/7)", "Weekly average verification post (0/1)", "Daily Sleep boosts (0/7)"]'::jsonb,
  '["Maintain consistent sleep/wake times", "Optimize bedroom temperature (65-67°F)", "Limit blue light exposure before bed", "Practice relaxation techniques", "Track and optimize your sleep latency"]'::jsonb,
  50,
  7,
  false,
  null
);

-- Create a table to log contest registration checks and rescheduling if it doesn't exist
CREATE TABLE IF NOT EXISTS public.contest_registration_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  challenge_id text NOT NULL,
  is_registered boolean NOT NULL,
  checked_at timestamptz NOT NULL DEFAULT now()
);