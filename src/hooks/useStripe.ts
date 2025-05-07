import { useState } from 'react';
import { supabase } from '../lib/supabase';

export interface StripeCheckoutResult {
  sessionId: string;
  sessionUrl: string;
}

export interface StripeError {
  error: string;
}

export type StripeResult = StripeCheckoutResult | StripeError;

export function useStripe() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const createSubscription = async (priceId: string, trialDays: number = 0, promoCode: boolean = false): Promise<StripeResult> => {
    try {
      setLoading(true);
      setError(null);
      
      // Get the Supabase session for authentication
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        throw new Error("User not authenticated");
      }
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-subscription`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${session.access_token}`,
          },
          body: JSON.stringify({ priceId, trialDays, promoCode }),
        }
      );

      const data = await response.json();

      console.log("Stripe session response:", data);

      if (!response.ok || data.error) {
        throw new Error(data.error || "Failed to create Stripe session");
      }
    
      return {
        sessionUrl: data.sessionUrl,
        sessionId: data.sessionId,
      };
      
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create subscription');
      return { error: err instanceof Error ? err.message : 'Failed to create subscription' };
    } finally {
      setLoading(false);
    }
  };
  
  const cancelSubscription = async (): Promise<{ success: boolean; error?: string }> => {
    try {
      setLoading(true);
      setError(null);
      
      // Call the Supabase RPC function to cancel subscription
      const { data, error } = await supabase.rpc('cancel_subscription');
      
      if (error) throw error;
      
      return { success: data?.success || false, error: data?.error };
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to cancel subscription');
      return { success: false, error: err instanceof Error ? err.message : 'Failed to cancel subscription' };
    } finally {
      setLoading(false);
    }
  };
  
  const updatePaymentMethod = async (): Promise<StripeResult> => {
    try {
      setLoading(true);
      setError(null);
      
      // Call the Supabase RPC function to get Stripe portal URL
      const { data, error } = await supabase.rpc('get_stripe_portal_url');
      
      if (error) throw error;
      
      if (!data?.success) {
        throw new Error(data?.error || 'Failed to get portal URL');
      }
      
      return { url: data.url };
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update payment method');
      return { error: err instanceof Error ? err.message : 'Failed to update payment method' };
    } finally {
      setLoading(false);
    }
  };
  
  return {
    loading,
    error,
    createSubscription,
    cancelSubscription,
    updatePaymentMethod
  };
}