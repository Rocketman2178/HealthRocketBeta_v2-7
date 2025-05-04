/*
  # Add Subscription Management Functions

  1. New Functions
    - `create_subscription_session` - Creates a Stripe checkout session for subscription
    - `cancel_subscription` - Cancels a user's subscription
    - `get_stripe_portal_url` - Gets a URL to the Stripe customer portal
    
  2. Security
    - Use security definer functions
    - Ensure proper user authentication
*/

-- Create function to create a subscription session
CREATE OR REPLACE FUNCTION create_subscription_session(
  p_price_id text
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
  v_session_url text;
  v_result jsonb;
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
  
  -- Return mock session URL for development
  v_session_url := 'https://checkout.stripe.com/c/pay/mock_session_' || gen_random_uuid();
  
  -- Log the subscription session creation
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
      'customer_id', v_customer_id,
      'timestamp', now()
    )
  );
  
  -- Return success with session URL
  RETURN jsonb_build_object(
    'success', true,
    'session_url', v_session_url
  );
END;
$$;

-- Create function to cancel subscription
CREATE OR REPLACE FUNCTION cancel_subscription()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_subscription_id text;
BEGIN
  -- Get user ID from auth context
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not authenticated'
    );
  END IF;
  
  -- Get subscription ID
  SELECT stripe_subscription_id INTO v_subscription_id
  FROM subscriptions
  WHERE user_id = v_user_id
  LIMIT 1;
  
  IF v_subscription_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No active subscription found'
    );
  END IF;
  
  -- Update subscription to cancel at period end
  UPDATE subscriptions
  SET cancel_at_period_end = true
  WHERE user_id = v_user_id;
  
  -- Log the subscription cancellation
  INSERT INTO boost_processing_logs (
    processed_at,
    boosts_processed,
    details
  ) VALUES (
    now(),
    0,
    jsonb_build_object(
      'operation', 'cancel_subscription',
      'user_id', v_user_id,
      'subscription_id', v_subscription_id,
      'timestamp', now()
    )
  );
  
  -- Return success
  RETURN jsonb_build_object(
    'success', true
  );
END;
$$;

-- Create function to get Stripe portal URL
CREATE OR REPLACE FUNCTION get_stripe_portal_url()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_customer_id text;
  v_portal_url text;
BEGIN
  -- Get user ID from auth context
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not authenticated'
    );
  END IF;
  
  -- Get customer ID
  SELECT stripe_customer_id INTO v_customer_id
  FROM subscriptions
  WHERE user_id = v_user_id
  LIMIT 1;
  
  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No customer found'
    );
  END IF;
  
  -- Return mock portal URL for development
  v_portal_url := 'https://billing.stripe.com/p/mock_portal_' || gen_random_uuid();
  
  -- Log the portal URL request
  INSERT INTO boost_processing_logs (
    processed_at,
    boosts_processed,
    details
  ) VALUES (
    now(),
    0,
    jsonb_build_object(
      'operation', 'get_stripe_portal_url',
      'user_id', v_user_id,
      'customer_id', v_customer_id,
      'timestamp', now()
    )
  );
  
  -- Return success with portal URL
  RETURN jsonb_build_object(
    'success', true,
    'url', v_portal_url
  );
END;
$$;

-- Grant execute permissions to public
GRANT EXECUTE ON FUNCTION create_subscription_session(text) TO public;
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
    'operation', 'add_subscription_functions',
    'description', 'Added functions for subscription management',
    'timestamp', now()
  )
);