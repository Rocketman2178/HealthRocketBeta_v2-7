/*
  # Fix Subscription Function for Production

  1. Changes
    - Update create_subscription_session function to use Stripe API directly
    - Remove mock session IDs and URLs
    - Fix the http_header function error
    - Ensure proper error handling
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create extension if it doesn't exist
CREATE EXTENSION IF NOT EXISTS http;

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
  v_user_email text;
  v_user_name text;
  v_customer_id text;
  v_stripe_url text := 'https://api.stripe.com/v1/checkout/sessions';
  v_stripe_key text := current_setting('app.settings.stripe_secret_key', true);
  v_supabase_url text := current_setting('app.settings.supabase_url', true);
  v_response jsonb;
  v_session_url text;
  v_session_id text;
BEGIN
  -- Get user ID from auth context
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not authenticated'
    );
  END IF;
  
  -- Get user details
  SELECT u.name, au.email
  INTO v_user_name, v_user_email
  FROM users u
  JOIN auth.users au ON u.id = au.id
  WHERE u.id = v_user_id;
  
  -- Check if user already has a subscription
  SELECT stripe_customer_id INTO v_customer_id
  FROM subscriptions
  WHERE user_id = v_user_id
  LIMIT 1;
  
  -- Call Stripe API directly
  SELECT 
    content::jsonb INTO v_response
  FROM 
    http((
      'POST',
      v_stripe_url,
      ARRAY[
        ('Authorization', 'Bearer ' || v_stripe_key),
        ('Content-Type', 'application/x-www-form-urlencoded')
      ],
      'mode=subscription&line_items[0][price]=' || p_price_id || 
      '&line_items[0][quantity]=1' ||
      '&success_url=' || urlencode(v_supabase_url || '/settings?session_id={CHECKOUT_SESSION_ID}') ||
      '&cancel_url=' || urlencode(v_supabase_url || '/settings') ||
      '&customer_email=' || urlencode(v_user_email) ||
      CASE WHEN v_customer_id IS NOT NULL THEN '&customer=' || v_customer_id ELSE '' END ||
      CASE WHEN p_trial_days > 0 THEN '&subscription_data[trial_period_days]=' || p_trial_days::text ELSE '' END ||
      CASE WHEN p_promo_code THEN '&allow_promotion_codes=true' ELSE '' END ||
      '&metadata[user_id]=' || v_user_id::text,
      NULL
    ));
  
  -- Check for errors in the response
  IF v_response ? 'error' THEN
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
        'error', v_response->'error'->>'message',
        'timestamp', now()
      )
    );
    
    RETURN jsonb_build_object(
      'success', false,
      'error', v_response->'error'->>'message'
    );
  END IF;
  
  -- Extract session URL and ID
  v_session_url := v_response->>'url';
  v_session_id := v_response->>'id';
  
  -- Log the successful session creation
  INSERT INTO boost_processing_logs (
    processed_at,
    boosts_processed,
    details
  ) VALUES (
    now(),
    0,
    jsonb_build_object(
      'operation', 'create_subscription_session',
      'user_id', v_user_id,
      'price_id', p_price_id,
      'session_id', v_session_id,
      'timestamp', now()
    )
  );
  
  -- Return success with session URL and ID
  RETURN jsonb_build_object(
    'success', true,
    'session_url', v_session_url,
    'session_id', v_session_id
  );
EXCEPTION
  WHEN OTHERS THEN
    -- Log the exception
    INSERT INTO boost_processing_logs (
      processed_at,
      boosts_processed,
      details
    ) VALUES (
      now(),
      0,
      jsonb_build_object(
        'operation', 'create_subscription_session_exception',
        'user_id', v_user_id,
        'price_id', p_price_id,
        'error', SQLERRM,
        'timestamp', now()
      )
    );
    
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Failed to create subscription session: ' || SQLERRM
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
    'description', 'Updated create_subscription_session function to use Stripe API directly',
    'timestamp', now()
  )
);