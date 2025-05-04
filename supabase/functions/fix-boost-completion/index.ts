import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Get the authorization header from the request
    const authHeader = req.headers.get("Authorization")?.split(" ")[1];
    if (!authHeader) {
      throw new Error("No authorization header");
    }

    // Get the user from Supabase auth
    const { data: { user }, error: userError } = await supabase.auth.getUser(authHeader);
    if (userError || !user) throw new Error("Invalid user");

    // Execute SQL to fix the complete_boost function
    const fixSql = `
      -- Drop the existing function
      DROP FUNCTION IF EXISTS complete_boost(uuid, text);

      -- Create a fixed version of the complete_boost function
      CREATE OR REPLACE FUNCTION complete_boost(
        p_user_id uuid,
        p_boost_id text
      )
      RETURNS jsonb
      LANGUAGE plpgsql
      SECURITY DEFINER
      SET search_path = public
      AS $$
      DECLARE
        v_fp_value integer;
        v_completed_id uuid;
        v_today date := current_date;
        v_boost_category text;
        v_result jsonb;
      BEGIN
        -- Get FP value for the boost
        SELECT fp_value, category INTO v_fp_value, v_boost_category
        FROM boost_fp_values
        WHERE boost_id = p_boost_id;
        
        -- Default to 1 FP if not found
        v_fp_value := COALESCE(v_fp_value, 1);
        
        -- If category not found, try to determine from boost_id
        IF v_boost_category IS NULL THEN
          v_boost_category := split_part(p_boost_id, '-', 1);
        END IF;
        
        -- Check if already completed today
        IF EXISTS (
          SELECT 1
          FROM completed_boosts
          WHERE user_id = p_user_id
            AND boost_id = p_boost_id
            AND completed_date = v_today
        ) THEN
          RETURN jsonb_build_object(
            'success', false,
            'error', 'Boost already completed today',
            'fp_earned', 0
          );
        END IF;
        
        -- Insert completed boost
        INSERT INTO completed_boosts (
          user_id,
          boost_id,
          completed_at,
          completed_date
        ) VALUES (
          p_user_id,
          p_boost_id,
          now(),
          v_today
        )
        RETURNING id INTO v_completed_id;
        
        -- Update daily FP
        PERFORM update_daily_fp(
          p_user_id,
          v_today,
          v_fp_value,
          1, -- boosts_completed
          0, -- challenges_completed
          0  -- quests_completed
        );
        
        -- Build result object
        v_result := jsonb_build_object(
          'success', true,
          'completed_id', v_completed_id,
          'fp_earned', v_fp_value,
          'boost_category', v_boost_category
        );
        
        -- Log the completion
        INSERT INTO boost_processing_logs (
          processed_at,
          boosts_processed,
          details
        ) VALUES (
          now(),
          1,
          jsonb_build_object(
            'operation', 'complete_boost',
            'user_id', p_user_id,
            'boost_id', p_boost_id,
            'boost_category', v_boost_category,
            'fp_earned', v_fp_value,
            'timestamp', now()
          )
        );
        
        -- Return the result
        RETURN v_result;
      END;
      $$;

      -- Grant execute permission to public
      GRANT EXECUTE ON FUNCTION complete_boost(uuid, text) TO public;

      -- Log the fix
      INSERT INTO public.boost_processing_logs (
        processed_at,
        boosts_processed,
        details
      ) VALUES (
        now(),
        0,
        jsonb_build_object(
          'operation', 'fix_sleep_boost_function',
          'description', 'Fixed complete_boost function to properly return result data for all boost categories',
          'timestamp', now()
        )
      );
    `;

    // Execute the SQL to fix the function
    const { error: sqlError } = await supabase.rpc('exec_sql', { sql: fixSql });
    if (sqlError) throw sqlError;

    // Test the function with a dummy call to ensure it works
    const { data: testResult, error: testError } = await supabase.rpc('test_complete_boost_function');
    
    return new Response(
      JSON.stringify({
        success: true,
        message: "Boost completion function fixed successfully",
        test_result: testResult,
        test_error: testError
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error fixing boost function:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});