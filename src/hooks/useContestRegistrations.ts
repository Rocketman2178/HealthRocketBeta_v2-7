import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

interface ContestRegistration {
  id: string;
  contest_id: string;
  payment_status: string;
  registered_at: string;
}

export function useContestRegistrations(userId: string | undefined) {
  const [registeredContests, setRegisteredContests] = useState<ContestRegistration[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!userId) {
      setLoading(false);
      return;
    }

    const fetchRegistrations = async () => {
      try {
        const { data, error } = await supabase
          .from('contest_registrations')
          .select('*')
          .eq('user_id', userId)
          .eq('payment_status', 'paid');

        if (error) throw error;
        setRegisteredContests(data || []);
      } catch (err) {
        console.error('Error fetching contest registrations:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchRegistrations();

    // Subscribe to registration changes
    const subscription = supabase
      .channel('contest_registrations')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'contest_registrations',
        filter: `user_id=eq.${userId}`
      }, () => {
        fetchRegistrations();
      })
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [userId]);

  return {
    registeredContests,
    loading
  };
}