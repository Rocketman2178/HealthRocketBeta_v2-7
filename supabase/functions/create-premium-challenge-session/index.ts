import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import Stripe from 'https://esm.sh/stripe@14.14.0'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Get the authorization header from the request
    const authHeader = req.headers.get('Authorization')?.split(' ')[1]
    if (!authHeader) {
      console.error('Missing authorization header')
      throw new Error('No authorization header');
    }

    // Get the user from Supabase auth
    try {
      const { data: { user }, error: userError } = await supabase.auth.getUser(authHeader)
      if (userError) {
        console.error('Auth error:', userError.message);
        throw new Error('Invalid user');
      }
      if (!user) {
        console.error('No user found with provided token');
        throw new Error('Invalid user');
      }

      // This function is now disabled - we only use credits
      return new Response(
        JSON.stringify({ 
          error: 'Stripe checkout is disabled. Please use contest credits to register.',
          credits_required: true
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      );
    } catch (authError) {
      console.error('Authentication error:', authError)
      throw new Error(`Authentication error: ${authError.message}`)
    }
  } catch (error) {
    console.error('Error in create-premium-challenge-session:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})