@@ .. @@
      <Card>
        <div 
          onClick={() => {
            // Set active tab to contests before navigating
            window.dispatchEvent(new CustomEvent('setActiveTab', { detail: { tab: 'contests' } }));
            setTimeout(() => {
              navigate(`/challenge/${contest.challenge_id}`);
            }, 50);
          }}
          className="cursor-pointer"
        >
          <div className="flex items-center justify-between mb-3">

  const incrementBoost = async () => {
    try {
      const { data, error: dbError } = await supabase.rpc(
        "sync_contest_boost_counts", 
        { 
          p_user_id: userId,
          p_category: contest.relatedCategories?.[0]?.toLowerCase() || contest.category.toLowerCase()
        }
      );
  
      if (dbError) {
        console.error("Error syncing contest boost counts for category:", 
          contest.relatedCategories?.[0]?.toLowerCase() || contest.category.toLowerCase(), 
          dbError);
        return;
      }
  
      // Refresh contest data to get updated boost count
      const { data: contestData, error: contestError } = await supabase
        .from(contest.id ? "active_contests" : "challenges")
        .select("boost_count, last_daily_boost_completed_date")
        .eq("user_id", userId)
        .eq("challenge_id", contest.challenge_id)
        .maybeSingle();

      if (contestError) {
        console.error("Error fetching updated contest data:", contestError);
        return;
      }

      if (contestData) {
        setBoostCount(contestData.boost_count || 0);
        setDailyCompletedDate(contestData.last_daily_boost_completed_date);
      }
    } catch (err) {
      console.error("Unexpected error in incrementBoost:", err);
    }
  };