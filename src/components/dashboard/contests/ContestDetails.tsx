import { useState, useEffect } from 'react';
import { X, Award, Zap, Clock, Users, Trophy, AlertTriangle, Check, Target, Info, DollarSign, ChevronDown, ChevronUp } from 'lucide-react';
import { formatInTimeZone } from 'date-fns-tz';
import { getChatPath } from '../../../lib/utils/chat';
import { useSupabase } from '../../../contexts/SupabaseContext';
import { supabase } from '../../../lib/supabase';
import { Progress } from '../../ui/progress';
import type { Challenge } from '../../../types/dashboard';
import { useNavigate, useParams } from 'react-router-dom';

export function ContestDetails() {
  const { challengeId } = useParams();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [challenge, setChallenge] = useState<Challenge | null>(null);
  const [isContest, setIsContest] = useState(false);
  const [showSmallContestRules, setShowSmallContestRules] = useState(false);
  
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
          
          // Check regular challenges first
          challenge = challenges.find(c => c.challenge_id === challengeId || c.id === challengeId);
          
          // If not found, check contest challenges
          if (!challengeDetails) {
            challengeDetails = contestChallenges.find(c => c.challenge_id === challengeId || c.id === challengeId);
          }
          
          // If still not found, try to get from database
          if (!challengeDetails && (challengeId.startsWith('cn_') || challengeId.startsWith('tc_'))) {
            try {
              const { data, error } = await supabase.rpc('get_contest_details', {
                p_challenge_id: challengeId
              });
              
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
                  howToPlay: data.how_to_play,
                  relatedCategories: [data.health_category]
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
    <div className="min-h-screen bg-gray-900 flex items-center justify-center overflow-y-auto py-8 px-4">
      <div className="w-full max-w-2xl">
      {isContest ? (
        <div>
          <div className="space-y-3">
            <div className="bg-orange-500/10 p-3 rounded-lg">
              <p className="text-sm text-white font-medium mb-2">Top 10% of Players</p>
              <p className="text-sm text-gray-300">Share 75% of the available reward pool</p>
            </div>
            
            <div className="bg-lime-500/10 p-3 rounded-lg">
              <p className="text-sm text-white font-medium">Top 50% of Players</p>
              <p className="text-sm text-gray-300">Get your entry fee back</p>
            </div>
            
            <div className="bg-gray-700/50 p-3 rounded-lg">
              <p className="text-sm text-white font-medium">All Other Players</p>
              <p className="text-sm text-gray-300">Entry fees are forfeited</p>
            </div>
            
            <button 
              onClick={() => setShowSmallContestRules(!showSmallContestRules)}
              className="flex items-center justify-between w-full p-3 bg-gray-700/70 rounded-lg hover:bg-gray-700 transition-colors"
            >
              <div className="flex items-center gap-2">
                <Info size={16} className="text-orange-500" />
                <span className="text-sm text-gray-300">View details for Contests with less than 4 players</span>
              </div>
              {showSmallContestRules ? (
                <ChevronUp size={16} className="text-gray-400" />
              ) : (
                <ChevronDown size={16} className="text-gray-400" />
              )}
            </button>
            
            {showSmallContestRules && (
              <div className="bg-gray-700/50 p-3 rounded-lg space-y-3 mt-2">
                <div className="flex items-center gap-2 mb-2">
                  <Trophy size={16} className="text-orange-500" />
                  <p className="text-sm text-white font-medium">Reward Distribution for Small Contests</p>
                </div>
                <ul className="space-y-2">
                  <li className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="text-orange-500 mt-1">•</span>
                    <span><strong>1 player:</strong> Player earns a return of their entry fee if they complete all contest requirements</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="text-orange-500 mt-1">•</span>
                    <span><strong>2 players:</strong> Winner earns both entry fees minus 20% admin fee (160% of entry fee)</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="text-orange-500 mt-1">•</span>
                    <span><strong>3 players:</strong> Winner earns prize pool minus admin fee and second place entry (140% of entry fee), second place gets entry fee back</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="text-orange-500 mt-1">•</span>
                    <span>Contests start on the scheduled date regardless of player count</span>
                  </li>
                </ul>
              </div>
            )}
            <div className="bg-gray-700/50 p-3 rounded-lg">
              <p className="text-xs text-gray-400 italic">Note: Entry fees for Contests are non-refundable. Apple is not a sponsor of, or involved in, the contest in any manner.</p>
            </div>
          </div>
        </div>
      ) : (
        <div>Challenge Details Component</div>
      )}
      </div>
    </div>
  );
}