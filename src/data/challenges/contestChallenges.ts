import type { Challenge } from '../../types/game';

export const contestChallenges: Challenge[] = [
  {
    id: 'cn_oura_sleep_score',
    name: 'Oura Sleep Score Contest',
    tier: 1,
    duration: 7,
    category: 'Contests',
    description: `Achieve the highest average weekly Sleep Score from your Oura Ring app.

In every Contest:

The top 10% performer(s) share 75% of the available reward pool, which could mean:

- 8 players: 6 Credits for top player (6X return)
- 20 players: 6 Credits each for top 2 players (6X return)
- 50 players: 6 Credits each for top 5 players (6X return)

Plus: Score in the top 50% and get your credit back. All other credits are forfeited.`,
    expertReference: 'Health Rocket Team - Gamifying Health to Increase HealthSpan',
    learningObjectives: [
      'Master sleep optimization',
      'Develop consistent sleep tracking',
      'Build sleep-focused habits'
    ],
    requirements: [
      {
        description: 'Daily sleep score verification (75% of score)',
        verificationMethod: 'verification_posts',
        weight: 75
      },
      {
        description: 'Weekly sleep score average verification (25% of score)',
        verificationMethod: 'verification_posts',
        weight: 25
      }
    ],
    implementationProtocol: {
      week1: 'Track and post your daily sleep score from the Oura Ring app each day. On the final day, post your weekly sleep score average from the Oura Ring app.'
    },
    howToPlay: {
      description: 'Join this Contest to compete for prizes while optimizing your sleep quality:',
      steps: [
        'Register with $75 entry fee or 1 Contest Entry Credit to secure your spot',
        'Post daily sleep score screenshots in the Challenge Chat',
        'Post your weekly sleep score average on the final day',
        'Track your progress on the leaderboard',
        'Top 10% share 75% of prize pool, top 50% get entry fee back'
      ]
    },
    relatedCategories: ["Sleep"],
    successMetrics: [
      'Daily verification posts (0/7)',
      'Weekly average verification post (0/1)', 
      'Daily Sleep boosts (0/7)'
    ],
    expertTips: [
      'Maintain consistent sleep/wake times',
      'Optimize bedroom temperature (65-67°F)',
      'Limit blue light exposure before bed',
      'Practice relaxation techniques',
      'Track and optimize your sleep latency'
    ],
    fuelPoints: 50,
    status: 'available',
    isPremium: true,
    entryFee: 1,
    minPlayers: 4,
    startDate: '2025-05-11T04:00:00.000Z',  // 12:00 AM EDT = 4:00 AM UTC
    requiresDevice: false,
    challenge_id: 'cn_oura_sleep_score'
  },
  {
    id: 'cn_oura_sleep_score_2',
    name: 'Oura Sleep Score Contest 2',
    tier: 1,
    duration: 7,
    category: 'Contests',
    description: `Achieve the highest average weekly Sleep Score from your Oura Ring app.

In every Contest:

The top 10% performer(s) share 75% of the available reward pool, which could mean:

- 8 players: 6 Credits for top player (6X return)
- 20 players: 6 Credits each for top 2 players (6X return)
- 50 players: 6 Credits each for top 5 players (6X return)

Plus: Score in the top 50% and get your credit back. All other credits are forfeited.`,
    expertReference: 'Health Rocket Team - Gamifying Health to Increase HealthSpan',
    learningObjectives: [
      'Master sleep optimization',
      'Develop consistent sleep tracking',
      'Build sleep-focused habits'
    ],
    requirements: [
      {
        description: 'Daily sleep score verification (75% of score)',
        verificationMethod: 'verification_posts',
        weight: 75
      },
      {
        description: 'Weekly sleep score average verification (25% of score)',
        verificationMethod: 'verification_posts',
        weight: 25
      }
    ],
    implementationProtocol: {
      week1: 'Track and post your daily sleep score from the Oura Ring app each day. On the final day, post your weekly sleep score average from the Oura Ring app.'
    },
    howToPlay: {
      description: 'Join this Contest to compete for prizes while optimizing your sleep quality:',
      steps: [
        'Register with 1 Contest Entry Credit to secure your spot',
        'Post daily sleep score screenshots in the Challenge Chat',
        'Post your weekly sleep score average on the final day',
        'Track your progress on the leaderboard',
        'Top 10% share 75% of prize pool, top 50% get credit back'
      ]
    },
    relatedCategories: ["Sleep"],
    successMetrics: [
      'Daily verification posts (0/7)',
      'Weekly average verification post (0/1)', 
      'Daily Sleep boosts (0/7)'
    ],
    expertTips: [
      'Maintain consistent sleep/wake times',
      'Optimize bedroom temperature (65-67°F)',
      'Limit blue light exposure before bed',
      'Practice relaxation techniques',
      'Track and optimize your sleep latency'
    ],
    fuelPoints: 50,
    status: 'available',
    isPremium: true,
    entryFee: 1,
    minPlayers: 4,
    startDate: '2025-05-18T04:00:00.000Z',  // 12:00 AM EDT = 4:00 AM UTC
    requiresDevice: false,
    challenge_id: 'cn_oura_sleep_score_2'
  }
];