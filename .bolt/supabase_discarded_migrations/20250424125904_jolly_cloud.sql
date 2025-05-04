/*
  # Create Support Messages Table

  1. New Table
    - `support_messages` - Stores user support requests and feedback
    - Includes fields for tracking email delivery status
    - Includes fields for tracking resolution status
    
  2. Security
    - Enable RLS on the table
    - Add policies for users to create and view their own messages
*/

-- Create support messages table
CREATE TABLE IF NOT EXISTS public.support_messages (
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