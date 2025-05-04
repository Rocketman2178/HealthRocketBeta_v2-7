import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useUserDevices } from './useUserDevices';
import { useContestRegistrations } from './useContestRegistrations';

export function useCompletedRecommendations(userId: string | undefined) {
  const [completedRecommendations, setCompletedRecommendations] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const { connectedDevices } = useUserDevices(userId);
  const { registeredContests } = useContestRegistrations(userId);
  const [completedBoosts, setCompletedBoosts] = useState<string[]>([]);

  // Fetch completed boosts
  useEffect(() => {
    if (!userId) return;

    const fetchCompletedBoosts = async () => {
      const today = new Date().toISOString().split('T')[0];
      const { data, error } = await supabase
        .from('completed_boosts')
        .select('boost_id')
        .eq('user_id', userId)
        .eq('completed_date', today);

      if (error) {
        console.error('Error fetching completed boosts:', error);
        return;
      }

      setCompletedBoosts(data.map(b => b.boost_id));
    };

    fetchCompletedBoosts();

    // Subscribe to boost completions
    const subscription = supabase
      .channel('completed_boosts')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'completed_boosts',
        filter: `user_id=eq.${userId}`
      }, () => {
        fetchCompletedBoosts();
      })
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [userId]);

  useEffect(() => {
    if (!userId) {
      setLoading(false);
      return;
    }

    const fetchCompletedRecommendations = async () => {
      try {
        const { data, error } = await supabase
          .from('completed_recommendations')
          .select('recommendation_id')
          .eq('user_id', userId);

        if (error) throw error;

        setCompletedRecommendations(data.map(r => r.recommendation_id));
      } catch (err) {
        console.error('Error fetching completed recommendations:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchCompletedRecommendations();
  }, [userId]);

  // Check if recommendation is completed based on actual user actions
  const isRecommendationCompleted = (recommendationId: string): boolean => {
    // Check boost recommendations
    if (recommendationId === 'daily_boost') {
      return completedBoosts.length >= 1;
    }

    // Check device connection recommendations
    if (recommendationId.startsWith('connect_devices')) {
      return connectedDevices.length > 0;
    }
    
    // Check contest recommendations
    if (recommendationId.startsWith('contests')) {
      return registeredContests.length > 0;
    }
    
    return false;
  };

  // Mark recommendation complete if actual completion criteria is met
  const markRecommendationComplete = async (recommendationId: string) => {
    if (!userId || !isRecommendationCompleted(recommendationId)) return;
    
    try {
      const { error } = await supabase
        .from('completed_recommendations')
        .insert({
          user_id: userId,
          recommendation_id: recommendationId
        })
        .single();

      if (error) {
        // If already completed, ignore unique constraint violation
        if (error.code !== '23505') {
          throw error;
        }
        return;
      }

      setCompletedRecommendations(prev => [...prev, recommendationId]);
    } catch (err) {
      console.error('Error marking recommendation complete:', err);
    }
  };

  return {
    completedRecommendations,
    loading,
    markRecommendationComplete,
    isRecommendationCompleted
  };
}