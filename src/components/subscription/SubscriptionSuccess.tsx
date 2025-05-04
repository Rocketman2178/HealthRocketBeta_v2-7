import React, { useEffect } from 'react';
import { Check, X, Rocket, Trophy, Gift } from 'lucide-react';
import { useSupabase } from '../../contexts/SupabaseContext';
import { supabase } from '../../lib/supabase';

interface SubscriptionSuccessProps {
  onClose: () => void;
  trialDays?: number;
}

export function SubscriptionSuccess({ onClose, trialDays = 0 }: SubscriptionSuccessProps) {
  const { user } = useSupabase();

  // Prevent background scrolling when modal is open
  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, []);
  
  // Update user's plan to Pro Plan
  useEffect(() => {
    const updateUserPlan = async () => {
      if (!user) return;
      
      try {
        // Update user's plan to Pro Plan
        await supabase
          .from('users')
          .update({ 
            plan: 'Pro Plan',
            subscription_start_date: new Date().toISOString()
          })
          .eq('id', user.id);
      } catch (err) {
        console.error('Error updating user plan:', err);
      }
    };
    
    updateUserPlan();
  }, [user]);

  // Render modal through portal to avoid DOM hierarchy constraints
  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-sm z-[200] flex items-start justify-center p-4 pt-16">
      <div className="w-full max-w-md bg-gray-800 rounded-lg shadow-2xl border border-orange-500/20">
        <div className="p-6">
          {/* Header */}
          <div className="flex items-center justify-between mb-4">
            <div className="flex flex-col items-center w-full">
              <div className="w-16 h-16 bg-lime-500/20 rounded-full flex items-center justify-center mx-auto">
                <Check className="text-lime-500" size={32} />
              </div>
              <h2 className="text-xl font-bold text-white mt-4">Welcome to Pro Plan!</h2>
              {trialDays > 0 && (
                <p className="text-orange-500 mt-2">
                  Your {trialDays}-day free trial has started
                </p>
              )}
            </div>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-white transition-colors"
            >
              <X size={24} />
            </button>
          </div>

          {/* Rocket and Stats */}
          <div className="bg-gray-700/50 p-4 rounded-lg mb-6">
            <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
              <Trophy className="text-orange-500" size={20} />
              <span>Pro Benefits Activated</span>
            </h3>
            <ul className="space-y-3">
              <li className="flex items-center gap-2 text-gray-300">
                <Gift size={16} className="text-orange-500 shrink-0" />
                <span>Prize Pool Eligibility</span>
              </li>
              <li className="flex items-center gap-2 text-gray-300">
                <Rocket size={16} className="text-orange-500 shrink-0" />
                <span>Tier 2 Boosts & Challenges</span>
              </li>
              <li className="flex items-center gap-2 text-gray-300">
                <Trophy size={16} className="text-orange-500 shrink-0" />
                <span>Premium Contest Challenges</span>
              </li>
            </ul>
          </div>
          
          {trialDays > 0 && (
            <div className="bg-orange-500/10 p-4 rounded-lg mb-6 border border-orange-500/20">
              <h3 className="text-lg font-semibold text-white mb-2">Your Free Trial</h3>
              <p className="text-gray-300 mb-2">
                You won't be charged until your {trialDays}-day free trial ends. You can cancel anytime before then.
              </p>
              <p className="text-gray-300">
                Trial end date: <span className="text-orange-500 font-medium">
                  {new Date(Date.now() + trialDays * 24 * 60 * 60 * 1000).toLocaleDateString('en-US', {
                    month: 'long',
                    day: 'numeric',
                    year: 'numeric'
                  })}
                </span>
              </p>
            </div>
          )}

          {/* Additional Info */}
          <button
            onClick={onClose}
            className="w-full px-6 py-3 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors"
          >
            Continue to Game
          </button>
        </div>
      </div>
    </div>
  );
}