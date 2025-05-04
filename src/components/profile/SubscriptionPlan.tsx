import { useState, useRef, useEffect, Dispatch, SetStateAction } from "react";
import { Shield, ChevronDown, ChevronUp, Users, Building2, Rocket, Gift, CreditCard, X, DivideIcon as LucideIcon } from "lucide-react";
import { useSupabase } from "../../contexts/SupabaseContext";
import { useUser } from "../../hooks/useUser";
import { SubscriptionManager } from "./SubscriptionManager";

interface Plan {
  name: string;
  price: string;
  priceId: string;
  icon: React.ComponentType<any>;
  description: string;
  prizeEligible: boolean;
  trialDays: number;
  promoCode: boolean;
}

interface SubscriptionPlanProps {
  onOpenChange: Dispatch<SetStateAction<boolean>>;
}

export function SubscriptionPlan({ onOpenChange }: SubscriptionPlanProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [showSubscriptionManager, setShowSubscriptionManager] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const { user } = useSupabase();
  const { userData } = useUser(user?.id);
  const [currentPlan, setCurrentPlan] = useState<Plan | null>(null);

  const plans = [
    {
      name: "Preview Access",
      price: "$0/month",
      priceId: "price_1Qt7haHPnFqUVCZdl33y9bET",
      comingSoon: false,
      icon: Rocket,
      description: "Free access and $150 contest entry credits",
      prizeEligible: true,
      trialDays: 0,
      promoCode: false
    },
    {
      name: "Pro Plan",
      price: "$59.95/month",
      priceId: "price_1Qt7jVHPnFqUVCZdutw3mSWN",
      comingSoon: true,
      icon: Shield,
      description: "Level up with prizes and premium features",
      prizeEligible: true,
      trialDays: 60,
      promoCode: false
    },
    {
      name: "Pro + Family",
      price: "$89.95/month",
      priceId: "price_1Qt7lXHPnFqUVCZdlpS1vrfs",
      comingSoon: true,
      icon: Users,
      description: "Gamify health for your entire family",
      prizeEligible: true,
      trialDays: 0,
      promoCode: true
    },
    {
      name: "Pro + Team",
      price: "$149.95/month",
      priceId: "price_1Qt7mVHPnFqUVCZdqvWROuTD",
      comingSoon: true,
      icon: Building2,
      description: "Optimize and gamify health for your entire team",
      prizeEligible: true,
      trialDays: 0,
      promoCode: true
    },
  ];

  useEffect(() => {
    onOpenChange?.(isOpen);
  }, [isOpen, onOpenChange]);

  // Set current plan based on user data
  useEffect(() => {
    if (userData?.plan) {
      const matchingPlan = plans.find(p => p.name === userData.plan);
      setCurrentPlan(matchingPlan || plans[0]);
    } else {
      setCurrentPlan(plans[0]);
    }
  }, [userData]);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    }

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <>
      <div className="relative" ref={dropdownRef}>
        <button
          onClick={() => setIsOpen(!isOpen)}
          className="flex items-center gap-2 text-orange-500 font-medium hover:text-orange-400 transition-colors relative z-10"
        >
          <Shield size={16} />
          <span>{userData?.plan || 'Free Plan'}</span>
          {isOpen ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
        </button>

        {isOpen && (
          <div className="fixed inset-0 z-[200]">
            {/* Backdrop */}
            <div
              className="fixed inset-0 bg-black/80 backdrop-blur-sm"
              onClick={() => setIsOpen(false)}
            />

            {/* Dropdown Content */}
            <div className="fixed inset-0 flex items-center justify-center p-4">
              <div className="w-full max-w-sm bg-gray-800 rounded-lg shadow-lg border border-gray-700 overflow-hidden">
                {/* Header */}
                <div className="px-4 py-3 text-sm border-b border-gray-700 flex justify-between items-center">
                  <span className="text-gray-400">
                    Select a Plan to View or Change
                  </span>
                  <button
                    onClick={() => setIsOpen(false)}
                    className="text-gray-400 hover:text-gray-300 transition-colors"
                  >
                    <X size={18} />
                  </button>
                </div>

                {/* Plans */}
                <div className="max-h-[60vh] overflow-y-auto">
                  {plans.map((plan) => {
                    const Icon = plan.icon;
                    const isCurrentPlan = userData?.plan === plan.name;
                    const isComingSoon = plan.name === 'Pro + Family' || plan.name === 'Pro + Team';
                    
                    return (
                      <div
                        key={plan.name}
                        className={`w-full px-4 py-3 text-sm text-left hover:bg-gray-700 transition-colors ${
                          isCurrentPlan
                            ? "bg-gray-700/50"
                            : ""
                        }`}
                        onClick={() => {
                          setIsOpen(false);
                          setShowSubscriptionManager(true);
                        }}
                      >
                        <div className="flex items-center gap-2 mb-1">
                          <Icon
                            size={16}
                            className={
                              isCurrentPlan
                                ? "text-orange-500"
                                : "text-gray-400"
                            }
                          />
                          <div className="font-medium text-white">
                            {plan.name}
                          </div>
                          {isComingSoon && (
                            <span className="text-xs bg-gray-700 px-2 py-0.5 rounded text-gray-400">
                              Coming Soon
                            </span>
                          )}
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="text-orange-500 font-medium">
                            {plan.price}
                          </span>
                        </div>
                        <div className="text-xs text-gray-400">
                          {plan.description}
                        </div>
                        {plan.prizeEligible && (
                          <div className="flex items-center gap-1 mt-2 text-xs text-lime-500">
                            <Gift size={12} />
                            <span>Eligible for Prize Pool Rewards</span>
                          </div>
                        )}
                        {isCurrentPlan && (
                          <div className="mt-2 text-xs text-orange-500">
                            Current Plan
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>

                {/* Divider */}
                <div className="border-t border-gray-700"></div>

                {/* Billing Management */}
                <div className="w-full px-4 py-3 text-sm text-left flex items-center gap-2 text-gray-500">
                  <CreditCard size={16} />
                  <span>Subscription management coming soon</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
      {showSubscriptionManager && (
        <SubscriptionManager 
          onClose={() => setShowSubscriptionManager(false)}
          userData={userData}
        />
      )}
    </>
  );
}