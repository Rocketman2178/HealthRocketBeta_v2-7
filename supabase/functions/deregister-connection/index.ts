import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

import {
  VitalClient,
  VitalEnvironment,
} from "https://esm.sh/@tryvital/vital-node@3.1.216";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // HANDLE CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // CREATE SUPABASE CLIENT
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const vitalClient = new VitalClient({
      apiKey: Deno.env.get("VITAL_API_KEY")!,
      environment: VitalEnvironment.Sandbox,
    });
    const { vital_user_id, user_id, provider } = await req.json();
    const data = await vitalClient.user.deregisterProvider(
      vital_user_id,
      provider
    );
    if (data?.success) {
      const { error } = await supabase
        .from("user_devices")
        .delete()
        .eq("user_id", user_id)
        .eq("provider", provider);
      if (error) throw error;
    }
    return new Response(
      JSON.stringify({
        success: true,
        data,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
