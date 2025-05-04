import { useState, useEffect } from "react";
import { Shield } from "lucide-react";
import StripeCheckout from '../stripe/StripeCheckout';
import { useStripe } from '../../hooks/useStripe';
import type { User } from "../../types/user";

interface Plan {
  name: string;
  priceId: string;
  price: number;
  features: string[];
  trialDays?: number;
  promoCode?: string;
}

interface SubscriptionDetailsProps {
  onOpenChange?: (isOpen: boolean) => void;
  userData: User | null;
}

export function SubscriptionDetails({ onOpenChange, userData }: SubscriptionDetailsProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [paymentModal, setPaymentModal] = useState<boolean>(false);
  const [selectedPlan, setSelectedPlan] = useState<Plan | null>(null);
  const [daysLeft, setDaysLeft] = useState<number | null>(null);
  const { createSubscription, loading: stripeLoading } = useStripe();
  const { createSubscription } = useStripe();
  
  const plans: Plan[] = [
    {
      name: "Free Plan",
      priceId: "price_free",
      price: 0,
      features: [
        "Basic features",
        "Community support",
        "Limited usage"
      ]
    },
    {
      name: "Pro Plan",
      priceId: "price_pro",
      price: 10,
      features: [
        "All Free features",
        "Priority support",
        "Unlimited usage",
        "Advanced features"
      ]
    }
  ];

  useEffect(() => {
    onOpenChange?.(isOpen);
  }, [isOpen, onOpenChange]);
  
  // Calculate days left in trial
  useEffect(() => {
    if (!userData?.subscription_start_date) return;
    
    const startDate = new Date(userData.subscription_start_date);
    const trialEndDate = new Date(startDate);
    trialEndDate.setDate(trialEndDate.getDate() + 60); // 60-day trial
    
    const now = new Date();
    const remainingDays = Math.ceil((trialEndDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
    
    if (remainingDays > 0) {
      setDaysLeft(remainingDays);
    }
  }, [userData?.subscription_start_date]);

  const handleUpgradeNow = async () => {
    try {
      // Use the Pro Plan for upgrade
      const proPlan = plans.find(p => p.name === 'Pro Plan');
      if (!proPlan) {
        throw new Error('Pro Plan not found');
      }
      
      // Create subscription session
      const result = await createSubscription(proPlan.priceId, 0, false);
      
      if ('error' in result) {
        console.error('Error creating subscription:', result.error);
        // Fall back to opening the payment modal
        setSelectedPlan(proPlan);
        setPaymentModal(true);
      } else {
        // Redirect to checkout
        window.location.href = result.sessionUrl;
      }
    } catch (err) {
      console.error('Error upgrading subscription:', err);
      // Fall back to opening the payment modal with Pro Plan
      const proPlan = plans.find(p => p.name === 'Pro Plan');
      if (proPlan) {
        setSelectedPlan(proPlan);
        setPaymentModal(true);
      }
    }
  };
  
  return (
    <>
      <div className="flex items-center justify-between">
        <div className="flex items-center">
          <Shield className="w-5 h-5 text-gray-500" />
          <span className="ml-2 text-sm font-medium">
            {userData?.plan || 'Free Plan'}
          </span>
        </div>
        
        {/* Trial days remaining indicator */}
        {userData?.plan === 'Pro Plan' && daysLeft !== null && daysLeft > 0 && (
          <div className="text-xs text-gray-400 mt-1 flex items-center">
            <span>{daysLeft} days left in trial</span>
            <button 
              onClick={handleUpgradeNow}
              className="ml-2 px-3 py-1 text-xs bg-orange-500 text-white rounded hover:bg-orange-600 transition-colors"
            >
              Upgrade Now
            </button>
          </div>
        )}
      </div>
      
      {paymentModal && selectedPlan && (
        <StripeCheckout
          priceId={selectedPlan.priceId}
          trialDays={selectedPlan.trialDays}
          promoCode={selectedPlan.promoCode}
          onClose={() => setPaymentModal(false)}
        />
      )}
    </>
  );
}