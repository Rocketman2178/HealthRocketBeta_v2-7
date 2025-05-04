/*
  # Update Contest Rules and Reward Distribution

  1. Changes
    - Remove minimum player requirement for contests to start
    - Add new rules for contests with 1-3 players
    - Update contest start logic to always start on scheduled date
    - Add reward distribution rules based on player count
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create function to determine contest rewards based on player count
CREATE OR REPLACE FUNCTION calculate_contest_rewards(
  p_contest_id uuid,
  p_player_count integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_entry_fee numeric(10,2);
  v_total_pool numeric(10,2);
  v_admin_fee numeric(10,2);
  v_winner_reward numeric(10,2);
  v_second_place_reward numeric(10,2);
BEGIN
  -- Get contest entry fee
  SELECT entry_fee INTO v_entry_fee
  FROM contests
  WHERE id = p_contest_id;
  
  -- If free contest, return empty rewards
  IF v_entry_fee = 0 THEN
    RETURN jsonb_build_object(
      'is_free_contest', true,
      'entry_fee', 0,
      'total_pool', 0,
      'admin_fee', 0,
      'winner_reward', 0,
      'second_place_reward', 0,
      'player_count', p_player_count
    );
  END IF;
  
  -- Calculate total pool
  v_total_pool := v_entry_fee * p_player_count;
  
  -- Calculate admin fee (20%)
  v_admin_fee := v_total_pool * 0.2;
  
  -- Calculate rewards based on player count
  CASE
    -- 1 player: return entry fee
    WHEN p_player_count = 1 THEN
      v_winner_reward := v_entry_fee;
      v_second_place_reward := 0;
    
    -- 2 players: winner gets total minus admin fee
    WHEN p_player_count = 2 THEN
      v_winner_reward := v_total_pool - v_admin_fee;
      v_second_place_reward := 0;
    
    -- 3 players: winner gets total minus admin fee and second place entry
    WHEN p_player_count = 3 THEN
      v_winner_reward := v_total_pool - v_admin_fee - v_entry_fee;
      v_second_place_reward := v_entry_fee;
    
    -- 4+ players: top 10% get 75% of pool, top 50% get entry fee back
    ELSE
      -- These are placeholder calculations - actual distribution happens elsewhere
      v_winner_reward := (v_total_pool - v_admin_fee) * 0.75;
      v_second_place_reward := v_entry_fee;
  END CASE;
  
  RETURN jsonb_build_object(
    'is_free_contest', false,
    'entry_fee', v_entry_fee,
    'total_pool', v_total_pool,
    'admin_fee', v_admin_fee,
    'winner_reward', v_winner_reward,
    'second_place_reward', v_second_place_reward,
    'player_count', p_player_count
  );
END;
$$;

-- Create function to get contest reward rules
CREATE OR REPLACE FUNCTION get_contest_reward_rules(
  p_contest_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_entry_fee numeric(10,2);
  v_min_players integer;
  v_player_count integer;
  v_reward_rules jsonb;
BEGIN
  -- Get contest details
  SELECT 
    c.entry_fee,
    c.min_players,
    COUNT(cr.user_id) as player_count
  INTO 
    v_entry_fee,
    v_min_players,
    v_player_count
  FROM contests c
  LEFT JOIN contest_registrations cr ON c.id = cr.contest_id
  WHERE c.id = p_contest_id
  GROUP BY c.id, c.entry_fee, c.min_players;
  
  -- Build reward rules
  v_reward_rules := jsonb_build_object(
    'entry_fee', v_entry_fee,
    'min_players', v_min_players,
    'current_players', v_player_count,
    'admin_fee_percentage', 20,
    'reward_tiers', jsonb_build_array(
      jsonb_build_object(
        'player_count', 1,
        'description', 'Player earns a return of their entry fee if they complete the contest',
        'winner_gets', '100% of entry fee',
        'second_place_gets', 'N/A',
        'others_get', 'N/A'
      ),
      jsonb_build_object(
        'player_count', 2,
        'description', 'Winner earns both entry fees minus 20% admin fee',
        'winner_gets', '160% of entry fee',
        'second_place_gets', 'Nothing (forfeits entry fee)',
        'others_get', 'N/A'
      ),
      jsonb_build_object(
        'player_count', 3,
        'description', 'Winner earns prize pool minus admin fee and second place entry',
        'winner_gets', '140% of entry fee',
        'second_place_gets', '100% of entry fee',
        'others_get', 'Nothing (forfeits entry fee)'
      ),
      jsonb_build_object(
        'player_count', '4+',
        'description', 'Top 10% share 75% of prize pool, top 50% get entry fee back',
        'winner_gets', 'Share of 75% of prize pool',
        'second_place_gets', 'Share of 75% of prize pool or entry fee back',
        'others_get', 'Entry fee back (top 50%) or nothing (bottom 50%)'
      )
    ),
    'notes', jsonb_build_array(
      'Entry fees for Contests are not refundable',
      'Contests start on the scheduled date regardless of player count',
      'Players must complete all requirements to be eligible for rewards',
      'Admin fee is 20% of total prize pool'
    )
  );
  
  RETURN v_reward_rules;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION calculate_contest_rewards(uuid, integer) TO public;
GRANT EXECUTE ON FUNCTION get_contest_reward_rules(uuid) TO public;

-- Update the contest start logic to remove minimum player requirement
CREATE OR REPLACE FUNCTION start_contest_on_schedule()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contest record;
  v_started_count integer := 0;
BEGIN
  -- Find contests that should start today
  FOR v_contest IN (
    SELECT 
      c.id,
      c.challenge_id,
      c.start_date,
      COUNT(cr.user_id) as player_count
    FROM contests c
    LEFT JOIN contest_registrations cr ON c.id = cr.contest_id
    WHERE 
      c.status = 'pending' AND
      c.start_date <= now() AND
      c.start_date > now() - interval '1 day'
    GROUP BY c.id, c.challenge_id, c.start_date
  ) LOOP
    -- Only start if at least one player registered
    IF v_contest.player_count > 0 THEN
      -- Update contest status to active
      UPDATE contests
      SET status = 'active'
      WHERE id = v_contest.id;
      
      -- Log the contest start
      INSERT INTO boost_processing_logs (
        processed_at,
        boosts_processed,
        details
      ) VALUES (
        now(),
        0,
        jsonb_build_object(
          'operation', 'start_contest_on_schedule',
          'contest_id', v_contest.id,
          'challenge_id', v_contest.challenge_id,
          'player_count', v_contest.player_count,
          'start_date', v_contest.start_date,
          'timestamp', now()
        )
      );
      
      v_started_count := v_started_count + 1;
    END IF;
  END LOOP;
  
  RETURN v_started_count;
END;
$$;

-- Create a cron job to start contests on schedule
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    BEGIN
      PERFORM cron.schedule(
        'start-contests-on-schedule',
        '0 * * * *',  -- Run every hour
        'SELECT start_contest_on_schedule()'
      );
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not create cron job: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'pg_cron extension not available. Please set up an external cron job to call start_contest_on_schedule() hourly.';
  END IF;
END
$$;

-- Update contests table to remove min_players requirement
ALTER TABLE public.contests ALTER COLUMN min_players DROP NOT NULL;

-- Update existing contests to set min_players to 1
UPDATE public.contests
SET min_players = 1
WHERE min_players > 1;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'update_contest_rules',
    'description', 'Updated contest rules to remove minimum player requirement and add new reward distribution rules',
    'timestamp', now()
  )
);