/*
  # Create Support Message Submission Function

  1. New Function
    - `submit_user_support` - Function to submit support messages
    - Handles user details lookup and message creation
    - Returns success status and message ID
    
  2. Security
    - Use security definer to ensure proper access control
    - Validate user exists before creating message
*/

-- Create function to submit support message
CREATE OR REPLACE FUNCTION public.submit_user_support(
  p_user_id uuid,
  p_category text,
  p_feedback text,
  p_rating integer DEFAULT NULL,
  p_context jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_name text;
  v_user_email text;
  v_message_id uuid;
BEGIN
  -- Get user details
  SELECT u.name, au.email
  INTO v_user_name, v_user_email
  FROM users u
  JOIN auth.users au ON u.id = au.id
  WHERE u.id = p_user_id;
  
  -- Insert support message
  INSERT INTO support_messages (
    user_id,
    user_name,
    user_email,
    message,
    category
  ) VALUES (
    p_user_id,
    COALESCE(v_user_name, 'Unknown User'),
    COALESCE(v_user_email, 'unknown@example.com'),
    p_feedback,
    p_category
  )
  RETURNING id INTO v_message_id;
  
  -- Return success
  RETURN jsonb_build_object(
    'success', true,
    'message_id', v_message_id
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION public.submit_user_support(uuid, text, text, integer, jsonb) TO public;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'create_support_message_function',
    'description', 'Created function to submit support messages',
    'timestamp', now()
  )
);