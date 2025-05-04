/*
  # Add details column to contest_registration_logs table

  1. Changes
    - Add JSONB details column to contest_registration_logs table
    - Set default value to empty JSON object
    - Make column nullable
*/

ALTER TABLE contest_registration_logs 
ADD COLUMN IF NOT EXISTS details JSONB DEFAULT '{}'::jsonb;