/*
  # Add Support Messages Table

  1. New Tables
    - `support_messages` - Stores user support requests and feedback
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `user_name` (text)
      - `user_email` (text)
      - `message` (text)
      - `category` (text)
      - `created_at` (timestamptz)
      - `resolved` (boolean)
      - `resolved_at` (timestamptz)
      - `resolved_by` (text)
      - `resolution_notes` (text)
      - `email_sent` (boolean)
      - `email_sent_at` (timestamptz)
      - `email_id` (text)
    
  2. Security
    - Enable RLS on the table
    - Add policies for users to insert and view their own messages
*/

-- Create support_messages table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user_name text NOT NULL,
  user_email text NOT NULL,
  message text NOT NULL,
  category text DEFAULT 'general',
  created_at timestamptz DEFAULT now() NOT NULL,
  resolved boolean DEFAULT false,
  resolved_at timestamptz,
  resolved_by text,
  resolution_notes text,
  email_sent boolean DEFAULT false,
  email_sent_at timestamptz,
  email_id text
);

-- Enable RLS if not already enabled
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'support_messages' AND policyname = 'Users can create support messages'
  ) THEN
    DROP POLICY "Users can create support messages" ON public.support_messages;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'support_messages' AND policyname = 'Users can view their own support messages'
  ) THEN
    DROP POLICY "Users can view their own support messages" ON public.support_messages;
  END IF;
END
$$;

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

-- Create or replace function to submit support message
CREATE OR REPLACE FUNCTION submit_support_message(
  p_user_id uuid,
  p_message text,
  p_category text DEFAULT 'general',
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
    v_user_name,
    v_user_email,
    p_message,
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
GRANT EXECUTE ON FUNCTION submit_support_message(uuid, text, text, jsonb) TO public;