import { useEffect, useState } from 'react';
import { PlanCard } from './PlanCard';
import { supabase } from '../../lib/supabase';

interface Plan {
  id: string;
  name: string;
  description: string;
  price: number;
  interval: string;
  features: string[];
  price_id: string;
  is_active: boolean;
}

export function PlansGrid() {
  const [plans, setPlans] = useState<Plan[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentPlanId, setCurrentPlanId] = useState<string | null>(null);

  useEffect(() => {
    const fetchPlans = async () => {
      try {
        setLoading(true);
        
        // Fetch plans from database
        const { data, error } = await supabase
          .from('plans')
          .select('*')
          .eq('is_active', true)
          .order('price');

        if (error) throw error;
        
        // Fetch current subscription
        const { data: subscription } = await supabase
          .from('subscriptions')
          .select('plan_id')
          .single();
          
        if (subscription?.plan_id) {
          setCurrentPlanId(subscription.plan_id);
        }
        
        setPlans(data || []);
      } catch (err) {
        console.error('Error fetching plans:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchPlans();
  }, []);

  if (loading) {
    return (
      <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
        {[...Array(3)].map((_, i) => (
          <div key={i} className="h-[500px] bg-gray-800/50 rounded-xl animate-pulse" />
        ))}
      </div>
    );
  }

  // If no plans are available from the database, use default plans
  const defaultPlans = [
    {
      id: 'free_plan',
      name: 'Free Plan',
      description: 'Basic access to Health Rocket',
      price: 0,
      interval: 'month',
      features: [
        'Access to all basic features',
        'Daily boosts and challenges',
        'Health tracking',
        'Community access',
        'Prize Pool Rewards not included'
      ],
      price_id: 'price_free',
      is_active: true
    },
    {
      id: 'pro_plan',
      name: 'Pro Plan',
      description: 'Full access to all features',
      price: 59.95,
      interval: 'month',
      features: [
        'All Free Plan features',
        'Premium challenges and quests',
        'Prize pool eligibility',
        'Advanced health analytics', 
        '60-day free trial'
      ],
      price_id: 'price_1Qt7jVHPnFqUVCZdutw3mSWN',
      is_active: true
    },
    {
      id: 'family_plan',
      name: 'Pro + Family',
      description: 'Share with up to 5 family members',
      price: 89.95,
      interval: 'month',
      features: [
        'All Pro Plan features',
        'Up to 5 family members',
        'Family challenges and competitions',
        'Family leaderboard',
        'Shared progress tracking'
      ],
      price_id: 'price_1Qt7lXHPnFqUVCZdlpS1vrfs',
      is_active: true
    }
  ];

  const displayPlans = plans.length > 0 ? plans : defaultPlans;

  return (
    <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
      {displayPlans.map((plan) => (
        <PlanCard
          key={plan.id}
          id={plan.price_id}
          name={plan.name}
          description={plan.description}
          price={plan.price}
          interval={plan.interval}
          features={plan.features}
          isPopular={plan.id === 'pro_plan' || plan.name === 'Pro Plan'}
          isCurrentPlan={plan.id === currentPlanId}
          trialDays={plan.name === 'Pro Plan' ? 60 : 0} // 60-day trial for Pro Plan
          promoCode={plan.name.includes('Family') || plan.name.includes('Team')}
        />
      ))}
    </div>
  );
}