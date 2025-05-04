/*
  # Update Subscription Management Functions

  1. Changes
    - Create or replace functions for subscription management
    - Add functions to call edge functions for Stripe integration
    - Fix return values to match expected format
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create or replace function to cancel subscription
CREATE OR REPLACE FUNCTION cancel_subscription()
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
  
  -- Call the edge function to cancel subscription
  BEGIN
    SELECT
      content::jsonb INTO v_response
    FROM
      http((
        'POST',
        concat(current_setting('app.settings.supabase_url'), '/functions/v1/cancel-subscription'),
        ARRAY[
          http_header('Authorization', concat('Bearer ', current_setting('request.jwt.claim.access_token'))),
          http_header('Content-Type', 'application/json')
        ],
        '{}',
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
          'operation', 'cancel_subscription_error',
          'user_id', v_user_id,
          'error', v_error,
          'timestamp', now()
        )
      );
      
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to cancel subscription: ' || v_error
      );
  END;
  
  -- Check for errors in the response
  IF v_response ? 'error' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_response->>'error'
    );
  END IF;
  
  -- Return success
  RETURN jsonb_build_object(
    'success', true
  );
END;
$$;

-- Create or replace function to get Stripe portal URL
CREATE OR REPLACE FUNCTION get_stripe_portal_url()
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
  
  -- Call the edge function to get portal URL
  BEGIN
    SELECT
      content::jsonb INTO v_response
    FROM
      http((
        'POST',
        concat(current_setting('app.settings.supabase_url'), '/functions/v1/update-payment-method'),
        ARRAY[
          http_header('Authorization', concat('Bearer ', current_setting('request.jwt.claim.access_token'))),
          http_header('Content-Type', 'application/json')
        ],
        '{}',
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
          'operation', 'get_stripe_portal_url_error',
          'user_id', v_user_id,
          'error', v_error,
          'timestamp', now()
        )
      );
      
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Failed to get portal URL: ' || v_error
      );
  END;
  
  -- Check for errors in the response
  IF v_response ? 'error' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', v_response->>'error'
    );
  END IF;
  
  -- Return success with portal URL
  RETURN jsonb_build_object(
    'success', true,
    'url', v_response->>'url'
  );
END;
$$;

-- Grant execute permissions to public
GRANT EXECUTE ON FUNCTION cancel_subscription() TO public;
GRANT EXECUTE ON FUNCTION get_stripe_portal_url() TO public;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'update_subscription_functions',
    'description', 'Updated subscription management functions to call edge functions',
    'timestamp', now()
  )
);