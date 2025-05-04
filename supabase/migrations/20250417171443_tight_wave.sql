/*
  # Add Complete Challenge Function

  1. Changes
    - Create a function to mark a challenge as completed
    - Move challenge data to completed_challenges table
    - Remove the challenge from the challenges table
    - Award FP for completing the challenge
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer function
*/

-- Create or replace function to mark a challenge as completed
CREATE OR REPLACE FUNCTION mark_challenge_completed(
  p_user_id uuid,
  p_challenge_id text
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
  v_fp_earned integer;
  v_challenge_details record;
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
  
  -- Get FP reward from challenge_library
  SELECT fuel_points INTO v_challenge_details
  FROM challenge_library
  WHERE id = p_challenge_id;
  
  -- Default to 50 FP if not found
  v_fp_earned := COALESCE(v_challenge_details.fuel_points, 50);
  
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
    v_fp_earned,
    v_days_to_complete,
    v_challenge.progress,
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
    'fp_earned', v_fp_earned
  );
END;
$$;

-- Create function to automatically complete challenges when verification requirements are met
CREATE OR REPLACE FUNCTION check_challenge_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge record;
  v_challenge_details record;
  v_fp_earned integer;
  v_completed_id uuid;
  v_days_to_complete integer;
BEGIN
  -- Only proceed if this is a verification update
  IF NEW.verification_count > OLD.verification_count THEN
    -- Check if verification requirements are met
    IF NEW.verification_count >= NEW.verifications_required THEN
      -- Get challenge details from challenge_library
      SELECT fuel_points INTO v_challenge_details
      FROM challenge_library
      WHERE id = NEW.challenge_id;
      
      -- Default to 50 FP if not found
      v_fp_earned := COALESCE(v_challenge_details.fuel_points, 50);
      
      -- Calculate days to complete
      v_days_to_complete := EXTRACT(DAY FROM (now() - NEW.started_at));
      
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
        now(),
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
      
      -- Return NULL to cancel the update since we've deleted the row
      RETURN NULL;
    END IF;
  END IF;
  
  -- If verification requirements not met, proceed with the update
  RETURN NEW;
END;
$$;

-- Create trigger for auto-completing challenges
DROP TRIGGER IF EXISTS check_challenge_completion_trigger ON public.challenges;
CREATE TRIGGER check_challenge_completion_trigger
  BEFORE UPDATE OF verification_count ON public.challenges
  FOR EACH ROW
  EXECUTE FUNCTION check_challenge_completion();