// Get appropriate days display text
   const getDaysDisplay = () => {
     if (startDate && !hasStarted) {
-      const estNow = new Date(formatInTimeZone(new Date(), 'America/New_York', 'yyyy-MM-dd HH:mm:ssXXX'));
      // If we have explicit days until start from the database, use that
      if (contest.daysUntilStart !== undefined && contest.daysUntilStart !== null) {
        return `${contest.daysUntilStart} Days Until Start`;
      } else {
        // Otherwise calculate from start date
        const now = new Date(); 
        const daysUntilStart = Math.ceil((startDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
        return `${daysUntilStart} Days Until Start`;
      }
    }
    return `${contest.daysRemaining} Days Left`;
  }