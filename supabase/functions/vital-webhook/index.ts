import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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

    const { client_user_id, data, event_type, team_id, user_id } =
      await req.json();

    // Handle provider connection events
    if (event_type === 'provider.connection.created') {
      const { error: deviceError } = await supabase
        .rpc('handle_vital_webhook', {
          payload: jsonb_build_object(
            'user_id', client_user_id,
            'provider', data.provider,
            'status', 'active'
          )
        });

      if (deviceError) throw deviceError;
    }

    // Handle different webhook events
    switch (event_type) {
      case "daily.data.profile.created":
      case "historical.data.profile.created": {
        // Process new health data
        const { data: metrics, error: metricsError } = await supabase
          .from("health_metrics")
          .insert({
            user_id,
            ...data,
            source: "vital",
          });

        if (metricsError) throw metricsError;
        break;
      }

      // Add more event handlers as needed
    }

    return new Response(JSON.stringify({ success: true, event: event_type }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});