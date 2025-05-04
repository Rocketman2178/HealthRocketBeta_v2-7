/*
  # Update Contest Boost Tracking for All Categories

  1. Changes
    - Modify the update_contest_boost_count trigger function to handle all categories
    - Update the sync_contest_boost_counts function to work with any category
    - Ensure boost count is updated for active contests based on their health category
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create or replace the update_contest_boost_count trigger function
CREATE OR REPLACE FUNCTION update_contest_boost_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_boost_category text;
  v_active_contests record;
  v_today date := current_date;
  v_updated_count integer := 0;
BEGIN
  -- Get the category of the completed boost
  SELECT get_boost_category(NEW.boost_id) INTO v_boost_category;
  
  -- Find all active contests for this user that match the boost category
  FOR v_active_contests IN (
    -- First check active_contests table
    SELECT ac.id, ac.challenge_id, ac.boost_count, ac.last_daily_boost_completed_date
    FROM active_contests ac
    JOIN contests c ON ac.contest_id = c.id
    WHERE ac.user_id = NEW.user_id
      AND ac.status = 'active'
      AND LOWER(c.health_category) = LOWER(v_boost_category)
    
    UNION ALL
    
    -- Then check challenges table (legacy)
    SELECT c.id, c.challenge_id, c.boost_count, c.last_daily_boost_completed_date
    FROM challenges c
    JOIN contests ct ON c.challenge_id = ct.challenge_id
    WHERE c.user_id = NEW.user_id
      AND c.status = 'active'
      AND c.category = 'Contests'
      AND LOWER(ct.health_category) = LOWER(v_boost_category)
  ) LOOP
    -- Check if boost already completed today for this contest
    IF v_active_contests.last_daily_boost_completed_date IS NULL OR 
       v_active_contests.last_daily_boost_completed_date < v_today THEN
      
      -- Try to update in active_contests first
      UPDATE active_contests
      SET 
        boost_count = COALESCE(boost_count, 0) + 1,
        last_daily_boost_completed_date = v_today
      WHERE id = v_active_contests.id
      RETURNING id;
      
      -- If no rows affected, try challenges table
      IF NOT FOUND THEN
        UPDATE challenges
        SET 
          boost_count = COALESCE(boost_count, 0) + 1,
          last_daily_boost_completed_date = v_today
        WHERE id = v_active_contests.id;
      END IF;
      
      v_updated_count := v_updated_count + 1;
      
      -- Log the update
      INSERT INTO boost_processing_logs (
        processed_at,
        boosts_processed,
        details
      ) VALUES (
        now(),
        1,
        jsonb_build_object(
          'operation', 'update_contest_boost_count',
          'user_id', NEW.user_id,
          'boost_id', NEW.boost_id,
          'boost_category', v_boost_category,
          'contest_id', v_active_contests.challenge_id,
          'previous_count', v_active_contests.boost_count,
          'new_count', COALESCE(v_active_contests.boost_count, 0) + 1,
          'timestamp', now()
        )
      );
    END IF;
  END LOOP;
  
  -- Dispatch event to update UI
  PERFORM pg_notify(
    'contest_boost_updated',
    jsonb_build_object(
      'user_id', NEW.user_id,
      'boost_category', v_boost_category,
      'updated_count', v_updated_count
    )::text
  );
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_contest_boost_count_trigger ON public.completed_boosts;

-- Create trigger to update contest boost count when a boost is completed
CREATE TRIGGER update_contest_boost_count_trigger
  AFTER INSERT ON public.completed_boosts
  FOR EACH ROW
  EXECUTE FUNCTION update_contest_boost_count();

-- Create function to manually sync contest boost counts for any category
CREATE OR REPLACE FUNCTION sync_contest_boost_counts(
  p_user_id uuid,
  p_category text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := current_date;
  v_boosts_today integer;
  v_active_contests record;
  v_updated_count integer := 0;
  v_result jsonb;
  v_category text := LOWER(p_category);
BEGIN
  -- If no category specified, default to checking all categories
  IF v_category IS NULL THEN
    -- Count all boosts completed today
    SELECT COUNT(*) INTO v_boosts_today
    FROM completed_boosts cb
    WHERE cb.user_id = p_user_id
      AND cb.completed_date = v_today;
      
    -- Find all active contests for this user
    FOR v_active_contests IN (
      -- First check active_contests table
      SELECT 
        ac.id, 
        ac.challenge_id, 
        ac.boost_count, 
        ac.last_daily_boost_completed_date,
        LOWER(c.health_category) as category
      FROM active_contests ac
      JOIN contests c ON ac.contest_id = c.id
      WHERE ac.user_id = p_user_id
        AND ac.status = 'active'
      
      UNION ALL
      
      -- Then check challenges table (legacy)
      SELECT 
        c.id, 
        c.challenge_id, 
        c.boost_count, 
        c.last_daily_boost_completed_date,
        LOWER(ct.health_category) as category
      FROM challenges c
      JOIN contests ct ON c.challenge_id = ct.challenge_id
      WHERE c.user_id = p_user_id
        AND c.status = 'active'
        AND c.category = 'Contests'
    ) LOOP
      -- Check if any boost of the contest's category was completed today
      IF EXISTS (
        SELECT 1
        FROM completed_boosts cb
        WHERE cb.user_id = p_user_id
          AND cb.completed_date = v_today
          AND get_boost_category(cb.boost_id) = v_active_contests.category
      ) THEN
        -- Check if boost already completed today for this contest
        IF v_active_contests.last_daily_boost_completed_date IS NULL OR 
           v_active_contests.last_daily_boost_completed_date < v_today THEN
          
          -- Try to update in active_contests first
          UPDATE active_contests
          SET 
            boost_count = COALESCE(boost_count, 0) + 1,
            last_daily_boost_completed_date = v_today
          WHERE id = v_active_contests.id
          RETURNING id;
          
          -- If no rows affected, try challenges table
          IF NOT FOUND THEN
            UPDATE challenges
            SET 
              boost_count = COALESCE(boost_count, 0) + 1,
              last_daily_boost_completed_date = v_today
            WHERE id = v_active_contests.id;
          END IF;
          
          v_updated_count := v_updated_count + 1;
          
          -- Log the update
          INSERT INTO boost_processing_logs (
            processed_at,
            boosts_processed,
            details
          ) VALUES (
            now(),
            1,
            jsonb_build_object(
              'operation', 'sync_contest_boost_counts',
              'user_id', p_user_id,
              'contest_id', v_active_contests.challenge_id,
              'category', v_active_contests.category,
              'previous_count', v_active_contests.boost_count,
              'new_count', COALESCE(v_active_contests.boost_count, 0) + 1,
              'timestamp', now()
            )
          );
        END IF;
      END IF;
    END LOOP;
  ELSE
    -- Count boosts of the specified category completed today
    SELECT COUNT(*) INTO v_boosts_today
    FROM completed_boosts cb
    WHERE cb.user_id = p_user_id
      AND cb.completed_date = v_today
      AND get_boost_category(cb.boost_id) = v_category;
    
    -- If no boosts of the specified category completed today, return early
    IF v_boosts_today = 0 THEN
      RETURN jsonb_build_object(
        'success', true,
        'message', 'No ' || v_category || ' boosts completed today',
        'updated_contests', 0
      );
    END IF;
    
    -- Find all active contests for this user matching the specified category
    FOR v_active_contests IN (
      -- First check active_contests table
      SELECT ac.id, ac.challenge_id, ac.boost_count, ac.last_daily_boost_completed_date
      FROM active_contests ac
      JOIN contests c ON ac.contest_id = c.id
      WHERE ac.user_id = p_user_id
        AND ac.status = 'active'
        AND LOWER(c.health_category) = v_category
      
      UNION ALL
      
      -- Then check challenges table (legacy)
      SELECT c.id, c.challenge_id, c.boost_count, c.last_daily_boost_completed_date
      FROM challenges c
      JOIN contests ct ON c.challenge_id = ct.challenge_id
      WHERE c.user_id = p_user_id
        AND c.status = 'active'
        AND c.category = 'Contests'
        AND LOWER(ct.health_category) = v_category
    ) LOOP
      -- Check if boost already completed today for this contest
      IF v_active_contests.last_daily_boost_completed_date IS NULL OR 
         v_active_contests.last_daily_boost_completed_date < v_today THEN
        
        -- Try to update in active_contests first
        UPDATE active_contests
        SET 
          boost_count = COALESCE(boost_count, 0) + 1,
          last_daily_boost_completed_date = v_today
        WHERE id = v_active_contests.id
        RETURNING id;
        
        -- If no rows affected, try challenges table
        IF NOT FOUND THEN
          UPDATE challenges
          SET 
            boost_count = COALESCE(boost_count, 0) + 1,
            last_daily_boost_completed_date = v_today
          WHERE id = v_active_contests.id;
        END IF;
        
        v_updated_count := v_updated_count + 1;
        
        -- Log the update
        INSERT INTO boost_processing_logs (
          processed_at,
          boosts_processed,
          details
        ) VALUES (
          now(),
          1,
          jsonb_build_object(
            'operation', 'sync_contest_boost_counts',
            'user_id', p_user_id,
            'contest_id', v_active_contests.challenge_id,
            'category', v_category,
            'previous_count', v_active_contests.boost_count,
            'new_count', COALESCE(v_active_contests.boost_count, 0) + 1,
            'timestamp', now()
          )
        );
      END IF;
    END LOOP;
  END IF;
  
  -- Return result
  v_result := jsonb_build_object(
    'success', true,
    'message', 'Contest boost counts synced successfully',
    'category', v_category,
    'boosts_today', v_boosts_today,
    'updated_contests', v_updated_count
  );
  
  RETURN v_result;
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION sync_contest_boost_counts(uuid, text) TO public;

-- Update the complete_boost function to include category in the response
CREATE OR REPLACE FUNCTION complete_boost(
  p_user_id uuid,
  p_boost_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fp_value integer;
  v_completed_id uuid;
  v_today date := current_date;
  v_boost_category text;
  v_result jsonb;
BEGIN
  -- Get FP value for the boost
  SELECT fp_value, category INTO v_fp_value, v_boost_category
  FROM boost_fp_values
  WHERE boost_id = p_boost_id;
  
  -- Default to 1 FP if not found
  v_fp_value := COALESCE(v_fp_value, 1);
  
  -- If category not found, try to determine from boost_id
  IF v_boost_category IS NULL THEN
    v_boost_category := get_boost_category(p_boost_id);
  END IF;
  
  -- Check if already completed today
  IF EXISTS (
    SELECT 1
    FROM completed_boosts
    WHERE user_id = p_user_id
      AND boost_id = p_boost_id
      AND completed_date = v_today
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Boost already completed today',
      'fp_earned', 0
    );
  END IF;
  
  -- Insert completed boost
  INSERT INTO completed_boosts (
    user_id,
    boost_id,
    completed_at,
    completed_date
  ) VALUES (
    p_user_id,
    p_boost_id,
    now(),
    v_today
  )
  RETURNING id INTO v_completed_id;
  
  -- Update daily FP
  PERFORM update_daily_fp(
    p_user_id,
    v_today,
    v_fp_value,
    1, -- boosts_completed
    0, -- challenges_completed
    0  -- quests_completed
  );
  
  -- Return success with FP earned and category
  RETURN jsonb_build_object(
    'success', true,
    'completed_id', v_completed_id,
    'fp_earned', v_fp_value,
    'boost_category', v_boost_category
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION complete_boost(uuid, text) TO public;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'update_all_category_contest_tracking',
    'description', 'Updated contest boost tracking to work with all categories, not just sleep',
    'timestamp', now()
  )
);