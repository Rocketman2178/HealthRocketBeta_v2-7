/*
  # Add Premium Challenges Table

  1. New Tables
    - `premium_challenges`
      - `id` (uuid, primary key)
      - `challenge_id` (text, unique)
      - `entry_fee` (numeric)
      - `min_players` (integer)
      - `max_players` (integer)
      - `start_date` (timestamp)
      - `registration_end_date` (timestamp)
      - `prize_pool` (numeric)
      - `status` (text)
      - `is_free` (boolean)
      - `health_category` (text)
      - `name` (text)
      - `description` (text)
      - `requirements` (jsonb)
      - `expert_reference` (text)
      - `how_to_play` (jsonb)
      - `implementation_protocol` (jsonb)
      - `success_metrics` (jsonb)
      - `expert_tips` (jsonb)
      - `fuel_points` (integer)
      - `duration` (integer)
      - `requires_device` (boolean)
      - `required_device` (text)
      - Timestamps: created_at, updated_at

  2. Security
    - Enable RLS on `premium_challenges` table
    - Add policy for public read access to active challenges
*/

-- Create premium challenges table
CREATE TABLE IF NOT EXISTS public.premium_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id text UNIQUE NOT NULL,
  entry_fee numeric(10,2) DEFAULT 0 NOT NULL,
  min_players integer NOT NULL,
  max_players integer,
  start_date timestamp with time zone NOT NULL,
  registration_end_date timestamp with time zone NOT NULL,
  prize_pool numeric(10,2) DEFAULT 0 NOT NULL,
  status text DEFAULT 'pending' NOT NULL,
  is_free boolean DEFAULT false,
  health_category text NOT NULL,
  name text,
  description text,
  requirements jsonb,
  expert_reference text,
  how_to_play jsonb,
  implementation_protocol jsonb,
  success_metrics jsonb,
  expert_tips jsonb,
  fuel_points integer,
  duration integer DEFAULT 30,
  requires_device boolean DEFAULT false,
  required_device text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  
  -- Add constraints
  CONSTRAINT valid_health_category CHECK (
    health_category = ANY (ARRAY['Mindset', 'Sleep', 'Exercise', 'Nutrition', 'Biohacking'])
  ),
  CONSTRAINT valid_status CHECK (
    status = ANY (ARRAY['pending', 'active', 'failed', 'completed'])
  )
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_premium_challenges_health_category ON public.premium_challenges(health_category);
CREATE INDEX IF NOT EXISTS idx_premium_challenges_status ON public.premium_challenges(status);
CREATE INDEX IF NOT EXISTS idx_premium_challenges_start_date ON public.premium_challenges(start_date);

-- Enable RLS
ALTER TABLE public.premium_challenges ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Anyone can view active premium challenges"
  ON public.premium_challenges
  FOR SELECT
  TO public
  USING (true);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_premium_challenge_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_premium_challenge_timestamp
  BEFORE UPDATE ON public.premium_challenges
  FOR EACH ROW
  EXECUTE FUNCTION update_premium_challenge_timestamp();