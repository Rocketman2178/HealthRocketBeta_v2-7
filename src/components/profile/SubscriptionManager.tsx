import { useState, useEffect } from "react";
import {
  X,
  Shield,
  Users,
  Building2,
  Rocket,
  Gift,
  CreditCard,
} from "lucide-react";
import StripeCheckout from "../stripe/StripeCheckout";
import { BillingPortal } from "../subscription/BillingPortal";
import { useStripe } from "../../hooks/useStripe";
import type { User } from "../../types/user";

interface Plan {
  id: string;
  name: string;
  description: string;
  price: number;
  interval: string;
  features: string[];
  price_id: string;
  is_active: boolean;
  icon: React.ComponentType<any>;
  comingSoon: boolean;
  trialDays?: number;
  promoCode?: boolean;
}

interface SubscriptionManagerProps {
  onClose: () => void;
  userData: User | null;
}

export function SubscriptionManager({
  onClose,
  userData,
}: SubscriptionManagerProps) {
  const [activeTab, setActiveTab] = useState<"plans" | "billing">("plans");
  const [isSubscriptionOpen, setIsSubscriptionOpen] = useState(false);
  const [selectedPlan, setSelectedPlan] = useState<Plan | null>(null);
  const [daysLeft, setDaysLeft] = useState<number | null>(null);
  const [paymentModal, setPaymentModal] = useState<boolean>(false);
  const [loading, setLoading] = useState(false);
  const { createSubscription, loading: stripeLoading } = useStripe();

  const plans: Plan[] = [
    {
      id: "free_plan",
      name: "Free Plan",
      description: "Basic access to Health Rocket",
      price: 0,
      interval: "month",
      features: [
        "Access to all basic features",
        "Daily boosts and challenges",
        "Health tracking",
        "Community access",
        "Prize Pool Rewards not included",
      ],
      price_id: "price_free",
      is_active: true,
      icon: Rocket,
      comingSoon: false,
    },
    {
      id: "pro_plan",
      name: "Pro Plan",
      description: "Full access to all features",
      price: 59.95,
      interval: "month",
      features: [
        "All Free Plan features",
        "Premium challenges and quests",
        "Prize pool eligibility",
        "Advanced health analytics",
        "60-day free trial",
      ],
      price_id: "price_1Qt7jVHPnFqUVCZdutw3mSWN",
      is_active: true,
      icon: Shield,
      comingSoon: false,
    },
    {
      id: "family_plan",
      name: "Pro + Family",
      description: "Share with up to 5 family members",
      price: 89.95,
      interval: "month",
      features: [
        "All Pro Plan features",
        "Up to 5 family members",
        "Family challenges and competitions",
        "Family leaderboard",
        "Shared progress tracking",
      ],
      price_id: "price_1Qt7lXHPnFqUVCZdlpS1vrfs",
      is_active: true,
      icon: Users,
      comingSoon: true,
    },
    {
      id: "team_plan",
      name: "Pro + Team",
      description: "For teams and organizations",
      price: 149.95,
      interval: "month",
      features: [
        "All Pro Plan features",
        "Up to 20 team members",
        "Team challenges and competitions",
        "Team analytics dashboard",
        "Admin controls and reporting",
      ],
      price_id: "price_1Qt7mVHPnFqUVCZdqvWROuTD",
      is_active: true,
      icon: Building2,
      comingSoon: true,
    },
  ];

  // Get current plan name
  const currentPlanName = userData?.plan || "Free Plan";

  // Calculate days left in trial
  useEffect(() => {
    if (!userData?.subscription_start_date) return;

    const startDate = new Date(userData.subscription_start_date);
    const trialEndDate = new Date(startDate);
    trialEndDate.setDate(trialEndDate.getDate() + 60); // 60-day trial

    const now = new Date();
    const remainingDays = Math.ceil(
      (trialEndDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
    );

    if (remainingDays > 0) {
      setDaysLeft(remainingDays);
    }
  }, [userData?.subscription_start_date]);

  const handlePlanClick = async (plan: Plan | null) => {
    if (!plan) return;

    try {
      setLoading(true);
      // Create subscription session with Stripe
      const result = await createSubscription(
        plan.price_id,
        plan.trialDays || 0,
        plan.promoCode || false
      );

      if ("error" in result) {
        console.error("Error creating subscription:", result.error);
        // Fall back to payment modal
        setSelectedPlan(plan);
        setPaymentModal(true);
      } else {
        // Redirect to Stripe checkout
        window.location.href = result.sessionUrl;
      }
    } catch (err) {
      console.error("Error handling plan selection:", err);
      // Fall back to payment modal
      setSelectedPlan(plan);
      setPaymentModal(true);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full max-w-4xl bg-gray-800 rounded-lg my-8 max-h-[90vh] overflow-y-auto relative z-[201]">
      <div className="flex items-center justify-between p-4 border-b border-gray-700">
        <div>
          <h2 className="text-xl font-bold text-white">
            Subscription Management
          </h2>
          <div className="flex items-center gap-2 mt-1">
            <div className="flex items-center gap-1 text-orange-500">
              <Shield size={14} />
              <span className="text-sm font-medium">
                {userData?.plan || "Free Plan"}
              </span>
            </div>
            {daysLeft && (
              <span className="text-xs text-gray-400">
                ({daysLeft} days left in trial)
              </span>
            )}
          </div>
        </div>
        <button onClick={onClose} className="text-gray-400 hover:text-gray-300">
          <X size={20} />
        </button>
      </div>

      <div className="p-4 border-b border-gray-700">
        <div className="flex space-x-4">
          <button
            onClick={() => setActiveTab("plans")}
            className={`px-4 py-2 rounded-lg transition-colors ${
              activeTab === "plans"
                ? "bg-orange-500 text-white"
                : "bg-gray-700 text-gray-300 hover:bg-gray-600"
            }`}
          >
            Subscription Plans
          </button>
          <button
            onClick={() => setActiveTab("billing")}
            className={`px-4 py-2 rounded-lg transition-colors ${
              activeTab === "billing"
                ? "bg-orange-500 text-white"
                : "bg-gray-700 text-gray-300 hover:bg-gray-600"
            }`}
          >
            Billing Information
          </button>
        </div>
      </div>

      <div className="p-6 overflow-y-auto">
        {activeTab === "plans" ? (
          <div className="space-y-6">
            <div className="mb-6">
              <h3 className="text-lg font-semibold text-white mb-2">
                Available Plans
              </h3>
              <p className="text-gray-300 mb-6">
                {daysLeft && userData?.plan === "Pro Plan"
                  ? `You have ${daysLeft} days left in your trial. Upgrade now to continue your Pro benefits.`
                  : "Choose the plan that best fits your health optimization journey"}
              </p>

              {/* Trial Banner */}
              {daysLeft && userData?.plan === "Pro Plan" && (
                <div className="bg-orange-500/10 border border-orange-500/20 p-4 rounded-lg mb-6">
                  <div className="flex items-start gap-3">
                    <Shield className="text-orange-500 mt-1" size={20} />
                    <div>
                      <h4 className="text-white font-medium mb-1">
                        Pro Plan Trial
                      </h4>
                      <p className="text-sm text-gray-300 mb-2">
                        Your trial ends in{" "}
                        <span className="text-orange-500 font-medium">
                          {daysLeft} days
                        </span>
                        .
                      </p>

                      <button
                        key={plans[1].id}
                        onClick={() => handlePlanClick(plans[1])}
                        disabled={stripeLoading}
                        className="px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                      >
                        {stripeLoading ? (
                          <div className="flex items-center gap-2">
                            <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                            <span>Processing...</span>
                          </div>
                        ) : (
                          "Upgrade Now"
                        )}
                      </button>
                    </div>
                  </div>
                </div>
              )}

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {plans.map((plan) => {
                  const isCurrentPlan = userData?.plan === plan.name;
                  const isComingSoon =
                    plan.name === "Pro + Family" || plan.name === "Pro + Team";

                  return (
                    <div
                      key={plan.id}
                      className={`relative flex flex-col p-6 bg-gray-800 rounded-xl border ${
                        isCurrentPlan ? "border-orange-500" : "border-gray-700"
                      }`}
                    >
                      {plan.id === "pro_plan" && (
                        <div className="absolute -top-3 left-1/2 -translate-x-1/2 z-10">
                          <span className="px-3 py-1 text-xs font-medium text-white bg-orange-500 rounded-full">
                            Most Popular
                          </span>
                        </div>
                      )}

                      <div className="mb-5">
                        <div className="flex items-center gap-2">
                          <plan.icon className="text-orange-500" size={20} />
                          <h3 className="text-xl font-bold text-white">
                            {plan.name}
                          </h3>
                        </div>
                        <p className="mt-2 text-sm text-gray-400">
                          {plan.description}
                        </p>
                      </div>

                      <div className="mb-5">
                        <div className="flex items-baseline">
                          <span className="text-3xl font-bold text-white">
                            ${plan.price}
                          </span>
                          <span className="ml-1 text-gray-400">
                            /{plan.interval}
                          </span>
                        </div>
                      </div>

                      <ul className="mb-8 space-y-3 flex-grow">
                        {plan.features.map((feature, index) => (
                          <li key={index} className="flex items-start gap-3">
                            <Gift
                              className={`w-5 h-5 ${
                                feature.includes("not included")
                                  ? "text-gray-500"
                                  : "text-orange-500"
                              } shrink-0`}
                            />
                            <span
                              className={`text-sm ${
                                feature.includes("not included")
                                  ? "text-gray-500"
                                  : "text-gray-300"
                              }`}
                            >
                              {feature}
                            </span>
                          </li>
                        ))}
                      </ul>

                      <div className="mt-auto">
                        {isCurrentPlan ? (
                          <button
                            disabled
                            className="w-full px-4 py-2 text-sm font-medium text-white bg-gray-700 rounded-lg opacity-50 cursor-not-allowed"
                          >
                            Current Plan
                          </button>
                        ) : isComingSoon ? (
                          <button
                            disabled
                            className="w-full px-4 py-2 text-sm font-medium text-white bg-gray-700 rounded-lg opacity-50 cursor-not-allowed"
                          >
                            Coming Soon
                          </button>
                        ) : (
                          <button
                            onClick={() => handlePlanClick(plan)}
                            className="w-full px-4 py-2 text-sm font-medium text-white bg-orange-500 rounded-lg hover:bg-orange-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-orange-500"
                          >
                            Select
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="bg-orange-500/10 p-4 rounded-lg border border-orange-500/20">
              <div className="flex items-start gap-3">
                <Gift className="text-orange-500 mt-1" size={20} />
                <div>
                  <h4 className="text-white font-medium mb-1">
                    Pro Plan Benefits
                  </h4>
                  <ul className="space-y-2 text-sm text-gray-300">
                    <li>• Access to premium challenges and quests</li>
                    <li>• Tier 2 boosts for advanced health optimization</li>
                    <li>• Prize pool eligibility for monthly rewards</li>
                    <li>• Advanced health analytics and insights</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            <BillingPortal />

            <div className="bg-gray-700/50 p-4 rounded-lg">
              <h3 className="text-lg font-semibold text-white mb-3">
                Billing Information
              </h3>
              <p className="text-gray-300 mb-4">
                Manage your payment methods and view billing history.
              </p>

              <div className="space-y-4">
                <div className="flex items-center justify-between p-3 bg-gray-700 rounded-lg">
                  <div className="flex items-center gap-3">
                    <CreditCard className="text-orange-500" size={20} />
                    <div>
                      <div className="text-white">Payment Method</div>
                      <div className="text-sm text-gray-400">
                        Update your card information
                      </div>
                    </div>
                  </div>
                  <button className="px-3 py-1.5 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors text-sm">
                    Update
                  </button>
                </div>

                {userData?.plan === "Pro Plan" && daysLeft !== null && (
                  <div className="flex items-center justify-between p-3 bg-gray-700 rounded-lg">
                    <div className="flex items-center gap-3">
                      <Shield className="text-orange-500" size={20} />
                      <div>
                        <div className="text-white">
                          {userData?.plan || "Pro Plan"}
                        </div>
                        <div className="text-sm text-gray-400">
                          {daysLeft
                            ? `Trial ends in ${daysLeft} days`
                            : "Active subscription"}
                        </div>
                      </div>
                    </div>
                    {daysLeft ? (
                      <button
                        onClick={() =>
                          handlePlanClick(
                            plans.find((p) => p.id === "pro_plan") || null
                          )
                        }
                        className="px-3 py-1.5 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
                      >
                        {stripeLoading ? (
                          <div className="flex items-center gap-2">
                            <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                            <span>Processing...</span>
                          </div>
                        ) : (
                          "Upgrade Now"
                        )}
                      </button>
                    ) : (
                      <button className="px-3 py-1.5 bg-gray-600 text-white rounded-lg hover:bg-gray-500 transition-colors text-sm">
                        Cancel
                      </button>
                    )}
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
      {paymentModal && selectedPlan && (
        <div className="fixed inset-0 z-[300] flex items-center justify-center">
          <div
            className="absolute inset-0 bg-black/80 backdrop-blur-sm z-[301]"
            onClick={() => setPaymentModal(false)}
          ></div>
          <StripeCheckout
            priceId={selectedPlan.price_id}
            trialDays={selectedPlan.trialDays || 0}
            promoCode={!!selectedPlan.promoCode || false}
            onClose={() => setPaymentModal(false)}
          />
        </div>
      )}
    </div>
  );
}
