import { useState, useEffect, useCallback } from "react";
import { supabase } from "../lib/supabase";
import { fixBoostCompletionFunction } from "../lib/utils/fixBoostFunction";
import type { BoostState } from "../types/dashboard";

export function useBoostState(userId: string | undefined) {
  const [selectedBoosts, setSelectedBoosts] = useState<BoostState[]>([]);
  const [weeklyBoosts, setWeeklyBoosts] = useState<BoostState[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [daysUntilReset, setDaysUntilReset] = useState<number>(7);
  const [weekStartDate, setWeekStartDate] = useState<Date>(new Date());
  const [todayStats, setTodayStats] = useState<{
    boostsCompleted: number;
    boostsRemaining: number;
    fpEarned: number;
    burnStreak: number;
  }>({
    boostsCompleted: 0,
    boostsRemaining: 3,
    fpEarned: 0,
    burnStreak: 0
  });

  const getTodayStats = useCallback(async () => {
    if (!userId) return;

    // Get today's stats from RPC function
    const { data: stats, error: statsError } = await supabase.rpc(
      "get_today_stats",
      {
        p_user_id: userId,
      }
    );

    if (statsError) {
      console.error("Error getting today's stats:", statsError);
      return;
    }

    // Set today's stats
    setTodayStats({
      boostsCompleted: stats.boosts_completed || 0,
      boostsRemaining: stats.boosts_remaining || 3,
      fpEarned: stats.fp_earned || 0,
      burnStreak: stats.burn_streak || 0
    });

    // Get today's completed boosts and set them
    const today = new Date().toISOString().split("T")[0];
    try {
      const { data: todayBoosts, error: boostsError } = await supabase
        .from("completed_boosts")
        .select("*")
        .eq("user_id", userId)
        .eq("completed_date", today);
  
      if (boostsError) {
        console.error("Error getting today's boosts:", boostsError);
        return;
      }
  
      // Set today's completed boosts
      setSelectedBoosts(
        todayBoosts?.map((boost) => ({
          id: boost.boost_id,
          completedAt: new Date(boost.completed_at),
          weekStartDate: weekStartDate,
        })) || []
      );
    } catch (err) {
      console.error("Error fetching today's boosts:", err);
    }
  }, [userId, weekStartDate]);

  // Get today's completed boosts count
  const getTodayBoostCount = useCallback(async () => {
    if (!userId) return 0;
    const today = new Date().toISOString().split("T")[0];

    try {
      const { data, error } = await supabase
        .from("completed_boosts")
        .select("*")
        .eq("user_id", userId)
        .eq("completed_date", today);

      if (error) {
        console.error("Error getting today's boosts:", error);
        return 0;
      }

      return data?.length || 0;
    } catch (err) {
      console.error("Error counting today's boosts:", err);
      return 0;
    }
  }, [userId]);

  // Initialize today's stats on mount
  useEffect(() => {
    if (userId) {
      getTodayStats();
    }
  }, [userId, getTodayStats]);

  // Fetch completed boosts for current week
  useEffect(() => {
    if (!userId) return;

    const fetchCompletedBoosts = async () => {
      try {
        // Calculate week start
        const weekStart = new Date();
        weekStart.setDate(weekStart.getDate() - weekStart.getDay());
        weekStart.setHours(0, 0, 0, 0);

        // Fetch completed boosts for this week
        const { data: completedBoosts, error } = await supabase
          .from("completed_boosts")
          .select("*")
          .eq("user_id", userId)
          .gte("completed_date", weekStart.toISOString().split("T")[0]);

        if (error) throw error;

        // Update weekly boosts state
        if (completedBoosts) {
          setWeeklyBoosts(
            completedBoosts.map((boost) => ({
              id: boost.boost_id,
              completedAt: new Date(boost.completed_at),
              weekStartDate: weekStart,
            }))
          );
        }
      } catch (err) {
        console.error("Error fetching completed boosts:", err);
      }
    };

    fetchCompletedBoosts();
  }, [userId]);

  useEffect(() => {
    if (!userId) return;

    const initializeBoosts = async () => {
      const weekStart = new Date();
      weekStart.setDate(weekStart.getDate() - weekStart.getDay());
      weekStart.setHours(0, 0, 0, 0);
      setWeekStartDate(weekStart);

      // Clear all boost states at the start of a new week
      if (daysUntilReset === 7) {
        setWeeklyBoosts([]);
        setSelectedBoosts([]);
      }

      setIsLoading(false);
    };

    initializeBoosts();
  }, [userId, daysUntilReset]);

  // Calculate days until reset
  useEffect(() => {
    const calculateDaysUntilReset = () => {
      if (userId === "91@gmail.com" || userId === "test25@gmail.com") {
        setDaysUntilReset(7);
        return;
      }

      const now = new Date();
      const nextSunday = new Date(now);
      const daysUntilSunday = 7 - now.getDay();
      nextSunday.setDate(now.getDate() + daysUntilSunday);
      nextSunday.setHours(0, 0, 0, 0);

      const diffTime = nextSunday.getTime() - now.getTime();
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      setDaysUntilReset(diffDays);
    };

    calculateDaysUntilReset();
    const interval = setInterval(calculateDaysUntilReset, 1000 * 60 * 60);

    return () => clearInterval(interval);
  }, [userId]);

  // Schedule sync at midnight
  useEffect(() => {
    if (!userId || isLoading) return;

    // Reset selected boosts at start of new week
    const now = new Date();
    if (now >= weekStartDate) {
      setSelectedBoosts([]);
      setWeeklyBoosts([]);
    }

    // Refresh stats every minute
    const interval = setInterval(getTodayStats, 60000);
    return () => clearInterval(interval);
  }, [userId, weekStartDate, isLoading]);

  const completeBoost = async (boostId: string,category:string) => {
    try {
      // Check if already at daily limit
      if (todayStats.boostsRemaining <= 0) {
        console.warn("Daily boost limit reached");
        return;
      }

      let data, error;
      
      try {
        // Try to complete the boost
        const result = await supabase.rpc("complete_boost", {
          p_user_id: userId,
          p_boost_id: boostId,
        });
        
        data = result.data;
        error = result.error;
        
        // If we get the specific error about "no destination for result data"
        if (error && error.message && error.message.includes("no destination for result data")) {
          console.log("Detected boost function error, attempting to fix...");
          
          // Try to fix the function
          const fixResult = await fixBoostCompletionFunction();
          
          if (fixResult.success) {
            // Try again after fixing
            console.log("Function fixed, retrying boost completion...");
            const retryResult = await supabase.rpc("complete_boost", {
              p_user_id: userId,
              p_boost_id: boostId,
            });
            
            data = retryResult.data;
            error = retryResult.error;
          }
        }
      } catch (err) {
        console.error("Error in boost completion process:", err);
        error = err;
      }
      
      if (error) throw error;
      
      // Dispatch dashboard update event with FP earned
      window.dispatchEvent(
        new CustomEvent("dashboardUpdate", {
          detail: { 
            fpEarned: data.fp_earned, 
            updatedPart: "boost", 
            category: data.boost_category || category 
          },
        })
      );

      // Refresh data after successful completion
      const { data: completedBoosts, error: fetchError } = await supabase
        .from("completed_boosts")
        .select("boost_id, completed_at")
        .eq("user_id", userId)
        .gte("completed_date", weekStartDate.toISOString().split("T")[0]);

      if (fetchError) throw fetchError;

      // Update weekly boosts state
      if (completedBoosts) {
        setWeeklyBoosts(
          completedBoosts.map((boost) => ({
            id: boost.boost_id,
            completedAt: new Date(boost.completed_at),
            weekStartDate: weekStartDate,
          }))
        );

        // Update today's stats
        await getTodayStats();
        
        // Log success for debugging
        console.log(`Boost ${boostId} completed successfully. FP earned: ${data.fp_earned}`);
        
        return data.fp_earned;
      }
    } catch (err) {
      console.error("Error completing boost:", err);
      throw err;
    }
  };

  return {
    selectedBoosts,
    todayStats,
    weeklyBoosts,
    daysUntilReset,
    completeBoost,
    isLoading,
  };
}
