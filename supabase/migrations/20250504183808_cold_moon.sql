/*
  # Fix Subscription Function

  1. Changes
    - Update the create_subscription_session function to call the edge function
    - Ensure proper parameters are passed to the edge function
    - Fix the return value to match the expected format
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create or replace function to create a subscription session
CREATE OR REPLACE FUNCTION create_subscription_session(
  p_price_id text,
  p_trial_days integer DEFAULT 0,
  p_promo_code boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_response jsonb;
  v_error text;
BEGIN
  -- Get user ID from auth context
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not authenticated'
    );
  END IF;
  
  -- Call the edge function to create a subscription session
  BEGIN
    SELECT
      content::jsonb INTO v_response
    FROM
      http((
        'POST',
        concat(current_setting('app.settings.supabase_url'), '/functions/v1/create-subscription'),
        ARRAY[
          http_header('Authorization', concat('Bearer ', current_setting('request.jwt.claim.access_token'))),
          http_header('Content-Type', 'application/json')
        ],
        jsonb_build_object(
          'priceId', p_price_id,
          'trialDays', p_trial_days,
          'promoCode', p_promo_code
        )::text,
        NULL
      ));
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
      
      -- Log the error
      INSERT INTO boost_processing_logs (
        processed_at,
        boosts_processed,
        details
      ) VALUES (
        now(),
        0,
        jsonb_build_object(
          'operation', 'create_subscription_session_error',
          'user_id', v_user_id,
          'price_id', p_price_id,
          'error', v_error,
          'timestamp', now()
        )
      );
      
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to create subscription session: ' || v_error
      );
  END;
  
  -- Check for errors in the response
  IF v_response ? 'error' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_response->>'error'
    );
  END IF;
  
  -- Return success with session URL and ID
  RETURN jsonb_build_object(
    'success', true,
    'session_url', v_response->>'sessionUrl',
    'session_id', v_response->>'sessionId'
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION create_subscription_session(text, integer, boolean) TO public;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'fix_subscription_function',
    'description', 'Updated create_subscription_session function to call the edge function',
    'timestamp', now()
  )
);