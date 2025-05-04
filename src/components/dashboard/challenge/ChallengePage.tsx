import  { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ChallengeDetails } from './ChallengeDetails';
import { challenges, tier0Challenge, contestChallenges } from '../../../data/challenges';
import { supabase } from '../../../lib/supabase';
import { useSupabase } from '../../../contexts/SupabaseContext';
import type { Challenge } from '../../../types/dashboard';

export function ChallengePage() {
  const { challengeId } = useParams();
  const navigate = useNavigate();
  const { user } = useSupabase();
  const [loading, setLoading] = useState(true);
  const [challenge, setChallenge] = useState<Challenge | null>(null);
  const [isContest, setIsContest] = useState(false);
  const [daysUntilStart, setDaysUntilStart] = useState<number | null>(null);
  const [hasCredits, setHasCredits] = useState<boolean>(true);
  
  useEffect(() => {
    if (challengeId) {
      const fetchChallenge = async () => {
        setLoading(true);
        
        // Look for challenge in tier 0, regular challenges, and contest challenges
        let challengeDetails;
        
        if (challengeId === 'mb0') {
          challengeDetails = tier0Challenge;
        } else {
          // Check if this is a contest challenge
          const isContestChallenge = challengeId.startsWith('cn_') || challengeId.startsWith('tc_');
          setIsContest(isContestChallenge);

          // Check regular challenges
          challengeDetails = challenges.find(c => c.challenge_id === challengeId || c.id === challengeId);

          // If not found, check contest challenges
          if (!challengeDetails) {
            challengeDetails = contestChallenges.find(c => c.challenge_id === challengeId || c.id === challengeId);
          }

          // If still not found, try to get from database
          if (!challengeDetails && (challengeId.startsWith('cn_') || challengeId.startsWith('tc_'))) {
            try {
              // First get contest days info
              const { data: daysInfo, error: daysError } = await supabase.rpc('get_contest_days_info', {
                p_challenge_id: challengeId
              });
              
              if (!daysError && daysInfo?.success) {
                setDaysUntilStart(daysInfo.days_until_start);
              }

              // Check if user has credits
              if (user?.id && data.entry_fee > 0) {
                const { data: creditsData, error: creditsError } = await supabase.rpc(
                  'get_user_contest_credits',
                  { p_user_id: user.id }
                );
                
                if (!creditsError) {
                  setHasCredits(creditsData?.has_credits || false);
                }
              }
              
              // Then get full contest details
              const { data, error } = await supabase.rpc('get_contest_details', {
                p_challenge_id: challengeId
              });
              
              // Check if user has credits
              if (user?.id && data?.entry_fee > 0) {
                const { data: creditsData, error: creditsError } = await supabase.rpc(
                  'get_user_contest_credits',
                  { p_user_id: user.id }
                );
                
                if (!creditsError) {
                  setHasCredits(creditsData?.has_credits || false);
                }
              }
              
              if (!error && data?.success) {
                challengeDetails = {
                  id: data.challenge_id,
                  challenge_id: data.challenge_id,
                  name: data.name,
                  category: 'Contests',
                  description: data.description,
                  expertReference: data.expert_reference,
                  requirements: data.requirements || [],
                  verificationMethod: null,
                  expertTips: data.expert_tips || [],
                  fuelPoints: data.fuel_points || 50,
                  duration: data.duration || 7,
                  progress: 0,
                  daysRemaining: 0,
                  isPremium: true,
                  entryFee: data.entry_fee,
                  minPlayers: data.min_players,
                  startDate: data.start_date,
                  howToPlay: data.how_to_play,
                  daysUntilStart: daysInfo?.days_until_start
                };
              }
            } catch (err) {
              console.error('Error fetching contest details:', err);
            }
          }
        }
        
        setChallenge(challengeDetails || null);
        setLoading(false);
      };
      
      fetchChallenge();
    }
  }, [challengeId]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-900">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-orange-500" />
      </div>
    );
  }
  
  if (!challenge) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-900">
        <div className="text-center">
          <h2 className="text-xl font-bold text-white mb-2">Challenge Not Found</h2>
          <button
            onClick={() => navigate('/')}
            className="text-orange-500 hover:text-orange-400"
          >
            Return to Dashboard
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900">
      <ChallengeDetails
        challenge={challenge}
        isContest={isContest}
        daysUntilStart={daysUntilStart}
        activeChallengesCount={1}
        maxChallenges={2}
        currentChallenges={[{
          challenge_id: challenge.id || challenge.challenge_id,
          status: 'active'
        }]}
        hasCompletedTier0={true}
        hasCredits={hasCredits}
        onClose={() => {
          // If this is a contest, navigate to the contests tab
          if (challenge.category === 'Contests') {
            // First dispatch an event to set the active tab to 'contests'
            window.dispatchEvent(new CustomEvent('setActiveTab', { detail: { tab: 'contests' } }));
            // Add a small delay to ensure the event is processed
            setTimeout(() => {
              navigate('/');
            }, 50);
          } else {
            // For regular challenges, just navigate to the dashboard
            navigate('/');
          }
        }}
        onStart={() => {}}
      />
    </div>
  );
}