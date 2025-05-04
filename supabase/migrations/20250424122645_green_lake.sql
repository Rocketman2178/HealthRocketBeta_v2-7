/*
  # Fix Support Messages Table

  1. Changes
    - Drop existing table if it exists to avoid conflicts
    - Create support_messages table with proper structure
    - Add RLS policies using auth.uid() instead of uid()
    - Create submit_support_message function
    
  2. Security
    - Enable RLS on support_messages table
    - Add policies for users to insert and view their own messages
*/

-- Drop existing table if it exists
DROP TABLE IF EXISTS public.support_messages;

-- Create support_messages table
CREATE TABLE public.support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_name text NOT NULL,
  user_email text NOT NULL,
  message text NOT NULL,
  category text DEFAULT 'general',
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved boolean DEFAULT false,
  resolved_at timestamptz,
  resolved_by text,
  resolution_notes text,
  email_sent boolean DEFAULT false,
  email_sent_at timestamptz,
  email_id text
);

-- Enable RLS
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can create support messages"
  ON public.support_messages
  FOR INSERT
  TO public
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own support messages"
  ON public.support_messages
  FOR SELECT
  TO public
  USING (auth.uid() = user_id);

-- Create function to submit support message
CREATE OR REPLACE FUNCTION submit_user_support(
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
GRANT EXECUTE ON FUNCTION submit_user_support(uuid, text, text, integer, jsonb) TO public;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'fix_support_messages_table',
    'description', 'Fixed support messages table and created support submission function',
    'timestamp', now()
  )
);