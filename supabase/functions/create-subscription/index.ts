import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import Stripe from "https://esm.sh/stripe@14.14.0";

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Get the authorization header from the request
    const authHeader = req.headers.get('Authorization')?.split(' ')[1];
    if (!authHeader) {
      throw new Error('Authorization header is required');
    }

    // Get the user from Supabase auth
    const { data: { user }, error: userError } = await supabase.auth.getUser(authHeader);
    
    if (userError) {
      console.error('Auth error:', userError);
      throw new Error('Authentication failed');
    }
    
    if (!user) {
      throw new Error('User not found');
    }

    // Get the price ID from the request
    const { priceId, trialDays, promoCode } = await req.json();
    if (!priceId) throw new Error('Price ID is required');

    // Get user profile to ensure required data exists
    const { data: userData, error: profileError } = await supabase
      .from('users')
      .select('email, name')
      .eq('id', user.id)
      .single();

    if (profileError || !userData) {
      console.error('Profile error:', profileError);
      throw new Error('User profile not found');
    }

    if (!userData.email) {
      throw new Error('User email is required');
    }

    // Get or create Stripe customer
    const { data: customers, error: customerError } = await supabase
      .from('subscriptions')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (customerError) {
      console.error('Customer lookup error:', customerError);
      throw new Error('Failed to lookup customer');
    }

    let customerId = customers?.stripe_customer_id;

    if (!customerId) {
      try {
        // Create Stripe customer
        const customer = await stripe.customers.create({
          email: userData.email,
          name: userData.name || undefined,
          metadata: {
            supabaseUUID: user.id,
          },
        });

        customerId = customer.id;
      } catch (stripeError) {
        console.error('Stripe customer creation error:', stripeError);
        throw new Error('Failed to create customer');
      }
    }
    
    // Create Stripe checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      payment_method_collection: 'if_required',
      ...(promoCode && {allow_promotion_codes: true}),
      mode: 'subscription',
      ...(trialDays > 0 && { subscription_data: { trial_period_days: trialDays } }),
      success_url: `${req.headers.get('origin')}/settings?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${req.headers.get('origin')}/settings`,
      metadata: {
        userId: user.id
      }
    });

    // Update user's plan
    const { error: updateError } = await supabase
      .from('users')
      .update({ 
        plan: priceId === 'price_1Qt7haHPnFqUVCZdl33y9bET' ? 'Free Plan' : 'Pro Plan',
        subscription_start_date: new Date().toISOString()
      })
      .eq('id', user.id);

    if (updateError) {
      console.error('User update error:', updateError);
      throw new Error('Failed to update user plan');
    }

    return new Response(
      JSON.stringify({ sessionId: session.id, sessionUrl: session.url }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('Function error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});