/*
  # Add Contest Verification Functions

  1. New Functions
    - get_contest_verification_requirements: Gets verification requirements for a contest
    - update_contest_verification_count: Updates verification count for a contest
    - check_contest_completion: Checks if a contest is complete
    
  2. Changes
    - Add functions to track verification posts for contests
    - Add functions to track daily boost completion for contests
    - Add function to check contest completion criteria
*/

-- Create function to get contest verification requirements
CREATE OR REPLACE FUNCTION get_contest_verification_requirements(
  p_challenge_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contest record;
  v_requirements jsonb;
BEGIN
  -- Get contest details
  SELECT * INTO v_contest
  FROM contests
  WHERE challenge_id = p_challenge_id;
  
  IF v_contest IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Build verification requirements
  v_requirements := jsonb_build_object(
    'daily_verifications', jsonb_build_object(
      'required', v_contest.duration,
      'completed', 0
    ),
    'weekly_verification', jsonb_build_object(
      'required', 1,
      'completed', 0
    ),
    'daily_boosts', jsonb_build_object(
      'required', v_contest.duration,
      'completed', 0
    )
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'requirements', v_requirements
  );
END;
$$;

-- Create function to update contest verification count
CREATE OR REPLACE FUNCTION update_contest_verification_count(
  p_user_id uuid,
  p_challenge_id text,
  p_verification_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challenge record;
  v_requirements jsonb;
  v_updated_requirements jsonb;
BEGIN
  -- Get challenge record
  SELECT * INTO v_challenge
  FROM challenges
  WHERE user_id = p_user_id
    AND challenge_id = p_challenge_id;
    
  IF v_challenge IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Challenge not found'
    );
  END IF;
  
  -- Get current verification requirements
  v_requirements := v_challenge.verification_requirements;
  
  -- Update the appropriate verification count
  IF p_verification_type = 'daily' THEN
    v_updated_requirements := jsonb_set(
      v_requirements,
      '{daily_verifications,completed}',
      to_jsonb(
        (v_requirements->'daily_verifications'->>'completed')::int + 1
      )
    );
  ELSIF p_verification_type = 'weekly' THEN
    v_updated_requirements := jsonb_set(
      v_requirements,
      '{weekly_verification,completed}',
      to_jsonb(1)
    );
  ELSIF p_verification_type = 'boost' THEN
    v_updated_requirements := jsonb_set(
      v_requirements,
      '{daily_boosts,completed}',
      to_jsonb(
        (v_requirements->'daily_boosts'->>'completed')::int + 1
      )
    );
  ELSE
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid verification type'
    );
  END IF;
  
  -- Update challenge with new verification requirements
  UPDATE challenges
  SET verification_requirements = v_updated_requirements
  WHERE id = v_challenge.id;
  
  -- Calculate progress percentage
  UPDATE challenges
  SET progress = (
    (
      ((v_updated_requirements->'daily_verifications'->>'completed')::numeric / 
       (v_updated_requirements->'daily_verifications'->>'required')::numeric) * 50 +
      ((v_updated_requirements->'weekly_verification'->>'completed')::numeric / 
       (v_updated_requirements->'weekly_verification'->>'required')::numeric) * 25 +
      ((v_updated_requirements->'daily_boosts'->>'completed')::numeric / 
       (v_updated_requirements->'daily_boosts'->>'required')::numeric) * 25
    )
  )
  WHERE id = v_challenge.id;
  
  RETURN jsonb_build_object(
    'success', true,
    'requirements', v_updated_requirements
  );
END;
$$;

-- Create function to check contest completion
CREATE OR REPLACE FUNCTION check_contest_completion(
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
  v_contest record;
  v_requirements jsonb;
  v_is_complete boolean;
BEGIN
  -- Get challenge record
  SELECT * INTO v_challenge
  FROM challenges
  WHERE user_id = p_user_id
    AND challenge_id = p_challenge_id;
    
  IF v_challenge IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Challenge not found'
    );
  END IF;
  
  -- Get contest details
  SELECT * INTO v_contest
  FROM contests
  WHERE challenge_id = p_challenge_id;
  
  IF v_contest IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Contest not found'
    );
  END IF;
  
  -- Get verification requirements
  v_requirements := v_challenge.verification_requirements;
  
  -- Check if all requirements are met
  v_is_complete := 
    (v_requirements->'daily_verifications'->>'completed')::int >= (v_requirements->'daily_verifications'->>'required')::int AND
    (v_requirements->'weekly_verification'->>'completed')::int >= (v_requirements->'weekly_verification'->>'required')::int AND
    (v_requirements->'daily_boosts'->>'completed')::int >= (v_requirements->'daily_boosts'->>'required')::int;
  
  -- If complete, mark as completed
  IF v_is_complete AND v_challenge.status != 'completed' THEN
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
      v_contest.fuel_points,
      EXTRACT(DAY FROM (now() - v_challenge.started_at)),
      v_challenge.progress,
      'completed',
      v_challenge.started_at,
      (v_requirements->'daily_verifications'->>'completed')::int + 
      (v_requirements->'weekly_verification'->>'completed')::int
    );
    
    -- Update challenge status
    UPDATE challenges
    SET 
      status = 'completed',
      completed_at = now()
    WHERE id = v_challenge.id;
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'is_complete', v_is_complete,
    'progress', v_challenge.progress
  );
END;
$$;

-- Create trigger function to update contest verification count when a message is posted
CREATE OR REPLACE FUNCTION update_challenge_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_challenge_id text;
  v_verification_type text;
BEGIN
  -- Only process verification posts
  IF NOT NEW.is_verification THEN
    RETURN NEW;
  END IF;
  
  -- Extract challenge ID from chat_id (format: c_CHALLENGE_ID)
  v_challenge_id := SUBSTRING(NEW.chat_id FROM 3);
  
  -- Determine verification type based on content
  IF NEW.content ILIKE '%weekly%average%' OR NEW.content ILIKE '%week%average%' THEN
    v_verification_type := 'weekly';
  ELSE
    v_verification_type := 'daily';
  END IF;
  
  -- Update verification count
  PERFORM update_contest_verification_count(
    NEW.user_id,
    v_challenge_id,
    v_verification_type
  );
  
  -- Check if contest is complete
  PERFORM check_contest_completion(
    NEW.user_id,
    v_challenge_id
  );
  
  RETURN NEW;
END;
$$;

-- Create or replace the trigger on chat_messages
DROP TRIGGER IF EXISTS update_verification_count ON public.chat_messages;
CREATE TRIGGER update_verification_count
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  WHEN (NEW.is_verification = true)
  EXECUTE FUNCTION update_challenge_verification();