import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Award, Zap, Ban, Users, Trophy } from 'lucide-react';
import { formatInTimeZone } from 'date-fns-tz';
import { getChatPath } from '../../../lib/utils/chat';
import { Card } from '../../ui/card';
import { Progress } from '../../ui/progress';
import { ChallengeMessageButton } from '../challenge/ChallengeMessageButton';
import { ChallengeCancelConfirm } from '../challenge/ChallengeCancelConfirm';
import type { Challenge } from '../../../types/dashboard';
import { supabase } from '../../../lib/supabase';

interface ContestCardProps {
  userId: string | undefined;
  contest: Challenge;
  onCancel?: (id: string) => void;
}

export function ContestCard({ userId, contest, onCancel }: ContestCardProps) {
  const [showCancelConfirm, setShowCancelConfirm] = useState(false);
  const [playerCount, setPlayerCount] = useState<number>(0);
  const navigate = useNavigate();
  const startDate = contest.startDate ? new Date(contest.startDate) : null;
  const hasStarted = startDate ? startDate <= new Date() : true;
  const isFutureContest = startDate && startDate > new Date();
  const entryFee = contest.entryFee || 0;

  // Get appropriate days display text
  const getDaysDisplay = () => {
    // If we have explicit days until start from the database, use that
    if (contest.daysUntilStart !== undefined && contest.daysUntilStart !== null && !hasStarted) {
      return `${contest.daysUntilStart} Days Until Start`;
    }
    // Otherwise calculate from start date
    else if (isFutureContest) {
      // Use current date for comparison
      const now = new Date(); 
      const daysUntilStart = Math.ceil((startDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      return `${daysUntilStart} Days Until Start`;
    }
    
    // For active contests or fallback
    return `${contest.daysRemaining} Days Left`;
  };


  useEffect(() => {
    // Empty useEffect - removed boost handling
  }, []);

  // Fetch active players
  useEffect(() => {
    const fetchActivePlayers = async () => {
      try {
        const { data: count, error } = await supabase.rpc(
          'get_challenge_players_count',
          { p_challenge_id: contest.challenge_id }
        );

        if (error) throw error;
        setPlayerCount(count || 0);
      } catch (err) {
        console.error('Error fetching players:', err);
      }
    };

    fetchActivePlayers();
  }, [contest.challenge_id]);

  const handleCancel = async () => {
    if (onCancel) {
      await onCancel(contest.challenge_id);
      window.dispatchEvent(new CustomEvent('contestCanceled'));
    }
  };

  return (
    <>
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
            <div className="flex items-center gap-1">
              <Trophy className="text-orange-500" size={24} />
              <div className="min-w-0">
                <h3 className="font-bold text-white truncate">{contest.name}</h3>
                <div className="flex items-center gap-2 mt-1">
                  <span className={`text-xs px-2 py-0.5 rounded ${contest.entryFee ? 'bg-orange-500/10 text-orange-500' : 'bg-lime-500/10 text-lime-500'}`}>
                    {contest.entryFee ? `Entry Fee: 1 Credit` : 'Free Entry'}
                  </span>
                  <span className="text-sm text-orange-500">+{contest.fuelPoints} FP</span>
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <ChallengeMessageButton challengeId={contest.challenge_id} size={24} hideCount />
            </div>
          </div>
          <div className="space-y-2">
            <div className="flex items-center justify-between mb-1">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  navigate(getChatPath(contest.challenge_id));
                }}
                className="flex items-center gap-2 text-sm text-gray-400 hover:text-white transition-colors"
              >
                <Users size={14} />
                <span>{playerCount} Players</span>
              </button>
              <div className="flex items-center gap-4">
                <div className="flex flex-col items-end">
                  {startDate && !hasStarted && (
                    <div className="flex flex-col items-end text-right">
                      <span className="text-[10px] text-gray-400">Start Date</span>
                      <span className="text-xs text-orange-500">{startDate.toLocaleDateString()}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-1 text-sm mt-1">
                    <span className="text-orange-500 font-medium">{getDaysDisplay().split(' ')[0]}</span>
                    <span className="text-gray-400 whitespace-nowrap">{getDaysDisplay().split(' ').slice(1).join(' ')}</span>
                  </div>
                </div>
              </div>
            </div>
            <Progress 
              value={contest.progress}
              max={100}
              className="bg-gray-700 h-2"
            />
            <div className="flex justify-between text-xs mt-1">
              <div className="flex items-center gap-3">
                <div className="flex items-center gap-1 text-lime-500">
                  <Users size={12} /> 
                  <span>{contest.verification_count || 0}/8 Verified</span>
                </div>
              </div>
              <div className="flex items-center gap-1">
                <Zap className="text-orange-500" size={14} />
                <span className="text-orange-500">+{contest.fuelPoints} FP</span>
              </div>
            </div>
          </div>
        </div>
      </Card>

      {showCancelConfirm && (
        <ChallengeCancelConfirm
          onConfirm={handleCancel}
          onClose={() => setShowCancelConfirm(false)}
        />
      )}
    </>
  );
}