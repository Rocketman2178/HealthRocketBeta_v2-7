/*
  # Fix Chat Message RLS Policy for Contest Chats

  1. Changes
    - Update the chat_messages_insert policy to check both challenges and active_contests tables
    - Allow users to post in contest chats (cn_ and tc_ prefixes)
    - Maintain existing RLS policies for regular challenges
    - Fix the uid() function by using auth.uid() instead
    
  2. Security
    - Maintain proper user authorization
    - Ensure users can only post in chats for contests they're registered for
*/

-- Drop the existing insert policy
DROP POLICY IF EXISTS chat_messages_insert ON public.chat_messages;

-- Create a new insert policy that checks both challenges and active_contests tables
CREATE POLICY chat_messages_insert ON public.chat_messages
  FOR INSERT
  WITH CHECK (
    (auth.uid() = user_id) AND (
      -- For regular challenges (c_ prefix)
      (
        SUBSTRING(chat_id FROM 1 FOR 2) = 'c_' AND
        EXISTS (
          SELECT 1
          FROM challenges c
          WHERE c.challenge_id = SUBSTRING(chat_id FROM 3)
            AND c.user_id = auth.uid()
            AND c.status = 'active'
        )
      )
      OR
      -- For contest challenges (cn_ or tc_ prefix)
      (
        (SUBSTRING(chat_id FROM 1 FOR 3) = 'c_c' OR SUBSTRING(chat_id FROM 1 FOR 3) = 'c_t') AND
        EXISTS (
          SELECT 1
          FROM active_contests ac
          WHERE ac.challenge_id = SUBSTRING(chat_id FROM 3)
            AND ac.user_id = auth.uid()
            AND ac.status = 'active'
        )
      )
    )
  );

-- Log the policy update
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'update_chat_messages_insert_policy',
    'description', 'Updated chat_messages_insert policy to support contest chats',
    'timestamp', now()
  )
);