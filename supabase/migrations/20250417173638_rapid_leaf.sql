/*
  # Add Monthly Rank Column to Monthly FP Totals

  1. New Column
    - `rank` - Integer column to store user's monthly rank in their community
    - Allows for displaying rank history and tracking progress over time
    
  2. New Function
    - `update_monthly_fp_rank` - Updates rank based on community leaderboard position
    - Automatically runs when monthly totals are updated
    
  3. Security
    - Maintain existing RLS policies
*/

-- Add rank column to monthly_fp_totals table
ALTER TABLE public.monthly_fp_totals
ADD COLUMN IF NOT EXISTS rank integer;

-- Create function to update monthly rank
CREATE OR REPLACE FUNCTION update_monthly_fp_rank()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_community_id uuid;
  v_rank integer;
BEGIN
  -- Get user's primary community
  SELECT community_id INTO v_community_id
  FROM community_memberships
  WHERE user_id = NEW.user_id
    AND is_primary = true
  LIMIT 1;
  
  -- If no primary community, rank will remain NULL
  IF v_community_id IS NOT NULL THEN
    -- Calculate rank within community for this month/year
    WITH community_rankings AS (
      SELECT 
        mft.user_id,
        mft.total_fp,
        ROW_NUMBER() OVER (ORDER BY mft.total_fp DESC) AS rank
      FROM monthly_fp_totals mft
      JOIN community_memberships cm ON mft.user_id = cm.user_id
      WHERE cm.community_id = v_community_id
        AND mft.year = NEW.year
        AND mft.month = NEW.month
    )
    SELECT rank INTO v_rank
    FROM community_rankings
    WHERE user_id = NEW.user_id;
    
    -- Update the rank
    NEW.rank := v_rank;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to update rank when monthly totals are updated
DROP TRIGGER IF EXISTS update_monthly_rank_trigger ON public.monthly_fp_totals;
CREATE TRIGGER update_monthly_rank_trigger
  BEFORE INSERT OR UPDATE OF total_fp ON public.monthly_fp_totals
  FOR EACH ROW
  EXECUTE FUNCTION update_monthly_fp_rank();

-- Create function to get user's monthly rank history
CREATE OR REPLACE FUNCTION get_monthly_rank_history(
  p_user_id uuid,
  p_limit integer DEFAULT 12
)
RETURNS TABLE (
  year integer,
  month integer,
  total_fp integer,
  rank integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mft.year,
    mft.month,
    mft.total_fp,
    mft.rank
  FROM monthly_fp_totals mft
  WHERE mft.user_id = p_user_id
    AND mft.rank IS NOT NULL
  ORDER BY mft.year DESC, mft.month DESC
  LIMIT p_limit;
END;
$$;

-- Update existing monthly totals with ranks
DO $$
DECLARE
  v_record record;
  v_community_id uuid;
  v_rank integer;
BEGIN
  -- Loop through all monthly totals
  FOR v_record IN (
    SELECT mft.id, mft.user_id, mft.year, mft.month
    FROM monthly_fp_totals mft
    WHERE mft.rank IS NULL
  ) LOOP
    -- Get user's primary community
    SELECT community_id INTO v_community_id
    FROM community_memberships
    WHERE user_id = v_record.user_id
      AND is_primary = true
    LIMIT 1;
    
    -- If user has a primary community, calculate rank
    IF v_community_id IS NOT NULL THEN
      -- Calculate rank within community for this month/year
      WITH community_rankings AS (
        SELECT 
          mft.user_id,
          mft.total_fp,
          ROW_NUMBER() OVER (ORDER BY mft.total_fp DESC) AS rank
        FROM monthly_fp_totals mft
        JOIN community_memberships cm ON mft.user_id = cm.user_id
        WHERE cm.community_id = v_community_id
          AND mft.year = v_record.year
          AND mft.month = v_record.month
      )
      SELECT rank INTO v_rank
      FROM community_rankings
      WHERE user_id = v_record.user_id;
      
      -- Update the rank
      IF v_rank IS NOT NULL THEN
        UPDATE monthly_fp_totals
        SET rank = v_rank
        WHERE id = v_record.id;
      END IF;
    END IF;
  END LOOP;
END $$;