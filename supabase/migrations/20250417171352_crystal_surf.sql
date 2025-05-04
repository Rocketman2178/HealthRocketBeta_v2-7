/*
  # Update Challenge Completion Process

  1. Changes
    - Create a function to handle challenge completion
    - Move completed challenges to completed_challenges table
    - Remove completed challenges from challenges table
    - Allow users to restart completed challenges
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create or replace function to handle challenge completion
CREATE OR REPLACE FUNCTION complete_challenge(
  p_user_id uuid,
  p_challenge_id text,
  p_fp_earned integer,
  p_final_progress numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge record;
  v_completed_id uuid;
  v_days_to_complete integer;
BEGIN
  -- Get challenge details
  SELECT * INTO v_challenge
  FROM challenges
  WHERE user_id = p_user_id
    AND challenge_id = p_challenge_id
    AND status = 'active';
    
  IF v_challenge IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Challenge not found or not active'
    );
  END IF;
  
  -- Calculate days to complete
  v_days_to_complete := EXTRACT(DAY FROM (now() - v_challenge.started_at));
  
  -- Insert into completed_challenges
  INSERT INTO completed_challenges (
    user_id,
    challenge_id,
    completed_at,
    fp_earned,
    days_to_complete,
    final_progress,
    status,
    started_at,
    verification_count
  ) VALUES (
    p_user_id,
    p_challenge_id,
    now(),
    p_fp_earned,
    v_days_to_complete,
    p_final_progress,
    'completed',
    v_challenge.started_at,
    v_challenge.verification_count
  )
  RETURNING id INTO v_completed_id;
  
  -- Delete from challenges table
  DELETE FROM challenges
  WHERE id = v_challenge.id;
  
  -- Return success
  RETURN jsonb_build_object(
    'success', true,
    'completed_id', v_completed_id,
    'days_to_complete', v_days_to_complete,
    'fp_earned', p_fp_earned
  );
END;
$$;

-- Create or replace function to handle automatic challenge completion
CREATE OR REPLACE FUNCTION auto_complete_challenge()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fp_earned integer;
  v_challenge_details record;
  v_completed_id uuid;
  v_days_to_complete integer;
BEGIN
  -- Get challenge details from challenge_library
  SELECT fuel_points INTO v_fp_earned
  FROM challenge_library
  WHERE id = NEW.challenge_id;
  
  -- Default to 50 FP if not found
  v_fp_earned := COALESCE(v_fp_earned, 50);
  
  -- Calculate days to complete
  v_days_to_complete := EXTRACT(DAY FROM (NEW.completed_at - NEW.started_at));
  
  -- Insert into completed_challenges
  INSERT INTO completed_challenges (
    user_id,
    challenge_id,
    completed_at,
    fp_earned,
    days_to_complete,
    final_progress,
    status,
    started_at,
    verification_count
  ) VALUES (
    NEW.user_id,
    NEW.challenge_id,
    NEW.completed_at,
    v_fp_earned,
    v_days_to_complete,
    NEW.progress,
    'completed',
    NEW.started_at,
    NEW.verification_count
  )
  RETURNING id INTO v_completed_id;
  
  -- Delete from challenges table
  DELETE FROM challenges
  WHERE id = NEW.id;
  
  RETURN NULL; -- This is an INSTEAD OF trigger
END;
$$;

-- Create trigger for auto-completing challenges
DROP TRIGGER IF EXISTS auto_complete_challenge_trigger ON public.challenges;
CREATE TRIGGER auto_complete_challenge_trigger
  BEFORE UPDATE OF status ON public.challenges
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status = 'active')
  EXECUTE FUNCTION auto_complete_challenge();

-- Create function to check if a challenge is completed
CREATE OR REPLACE FUNCTION is_challenge_completed(
  p_user_id uuid,
  p_challenge_id text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_completed boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM completed_challenges
    WHERE user_id = p_user_id
      AND challenge_id = p_challenge_id
      AND status = 'completed'
  ) INTO v_is_completed;
  
  RETURN v_is_completed;
END;
$$;

-- Create function to get completed challenges
CREATE OR REPLACE FUNCTION get_user_completed_challenges(
  p_user_id uuid
)
RETURNS TABLE (
  id uuid,
  challenge_id text,
  completed_at timestamptz,
  fp_earned integer,
  days_to_complete integer,
  final_progress numeric,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cc.id,
    cc.challenge_id,
    cc.completed_at,
    cc.fp_earned,
    cc.days_to_complete,
    cc.final_progress,
    cc.status
  FROM completed_challenges cc
  WHERE cc.user_id = p_user_id
    AND cc.status = 'completed'
  ORDER BY cc.completed_at DESC;
END;
$$;