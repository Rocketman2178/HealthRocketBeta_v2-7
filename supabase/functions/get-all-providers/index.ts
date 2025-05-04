import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
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
    const vitalClient = new VitalClient({
      apiKey: Deno.env.get("VITAL_API_KEY")!,
      environment: VitalEnvironment.Sandbox,
    });
    const allProviders = await vitalClient.providers.getAll();

    return new Response(
      JSON.stringify({
        success: true,
        providers: allProviders,
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
