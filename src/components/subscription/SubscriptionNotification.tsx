import { useState, useEffect } from 'react';
import { Shield, X } from 'lucide-react';
import { useSupabase } from '../../contexts/SupabaseContext';
import { useUser } from '../../hooks/useUser';
import { SubscriptionManager } from '../profile/SubscriptionManager';

export function SubscriptionNotification() {
  const { user } = useSupabase();
  const { userData } = useUser(user?.id);
  const [daysLeft, setDaysLeft] = useState<number | null>(null);
  const [dismissed, setDismissed] = useState(false);
  const [isSubscriptionOpen, setIsSubscriptionOpen] = useState(false);

  useEffect(() => {
    if (!userData) return;
    
    // Check if user is on Pro Plan
    const isProPlan = userData.plan === 'Pro Plan';
    
    if (isProPlan) {
      // Check if subscription has a trial period
      const subscriptionCreatedAt = new Date(userData.subscription_start_date || userData.created_at);
      const trialEndDate = new Date(subscriptionCreatedAt);
      trialEndDate.setDate(trialEndDate.getDate() + 60); // 60-day trial
      
      const now = new Date();
      const remainingDays = Math.ceil((trialEndDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      
      if (remainingDays > 0 && remainingDays <= 10) {
        setDaysLeft(remainingDays);
        
        // Check if notification was dismissed today
        const lastDismissed = localStorage.getItem('trial_notification_dismissed');
        if (lastDismissed) {
          const dismissedDate = new Date(lastDismissed);
          const today = new Date();
          if (dismissedDate.toDateString() === today.toDateString()) {
            setDismissed(true);
          }
        }
      } else {
        setDaysLeft(null);
      }
    }
  }, [userData]);

  const handleDismiss = () => {
    setDismissed(true);
    localStorage.setItem('trial_notification_dismissed', new Date().toISOString());
  };

  if (!daysLeft || daysLeft > 10 || dismissed) {
    return null;
  }

  return (
    <div className="fixed bottom-4 right-4 z-50 max-w-md bg-gray-800 rounded-lg shadow-lg border border-orange-500/30 p-4 animate-[bounceIn_0.5s_ease-out]">
      <div className="flex items-start gap-3">
        <div className="p-2 bg-orange-500/20 rounded-full">
          <Shield className="text-orange-500" size={20} />
        </div>
        <div className="flex-1">
          <div className="flex justify-between items-start">
            <h3 className="text-white font-semibold">Pro Plan Trial Ending Soon</h3>
            <button 
              onClick={handleDismiss}
              className="text-gray-400 hover:text-gray-300"
            >
              <X size={16} />
            </button>
          </div>
          <p className="text-sm text-gray-300 mt-1">
            Your Pro Plan trial ends in <span className="text-orange-500 font-medium">{daysLeft} {daysLeft === 1 ? 'day' : 'days'}</span>. 
            Upgrade now to keep your premium benefits.
          </p>
          <button
            onClick={() => setIsSubscriptionOpen(true)}
            className="ml-2 px-3 py-1 text-xs bg-orange-500 text-white rounded hover:bg-orange-600 transition-colors"
          >
            Upgrade Now
          </button>
        </div>
      </div>
      
      {isSubscriptionOpen && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-[300] flex items-start justify-center p-4 overflow-y-auto">
          <div className="absolute inset-0 z-[301]" onClick={() => setIsSubscriptionOpen(false)}></div>
          <SubscriptionManager
            onClose={() => setIsSubscriptionOpen(false)}
            userData={userData}
          />
        </div>
      )}
    </div>
  );
}