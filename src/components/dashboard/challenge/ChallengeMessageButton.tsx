import React, { useState, useEffect } from 'react';
import { MessageCircle, X, Clock, Users } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../../lib/supabase';

interface ChallengeMessageButtonProps extends React.HTMLAttributes<HTMLButtonElement> {
  challengeId: string;
  size?: number;
  hideCount?: boolean;
}

export function ChallengeMessageButton({ challengeId, size = 16, hideCount = false, ...props }: ChallengeMessageButtonProps) {
  const [playerCount, setPlayerCount] = useState(0);
  const [contestStartDate, setContestStartDate] = useState<Date | null>(null);
  const [hasStarted, setHasStarted] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchPlayerCount = async () => {
      const { data: challengeData } = await supabase
        .from('challenges')
        .select('user_id')
        .eq('challenge_id', challengeId)
        .eq('status', 'active');

      setPlayerCount(challengeData?.length || 0);
    };

    fetchPlayerCount();
    
    // Check if this is a contest and get its start date
    const fetchContestDetails = async () => {
      // First check if this is a contest by checking if it starts with cn_ or tc_
      if (challengeId.startsWith('cn_') || challengeId.startsWith('tc_')) {
        const { data, error } = await supabase.rpc(
          'get_contest_days_info',
          { p_challenge_id: challengeId }
        );
          
        if (!error && data?.success) {
          if (data.start_date) {
            setContestStartDate(new Date(data.start_date));
          }
          setHasStarted(data.has_started);
        }
      }
    };
    
    fetchContestDetails();
  }, [challengeId]);

  const handleClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    
    if (hasStarted) {
      // If contest has started, navigate to chat
      navigate(`/chat/${challengeId}`);
    } else {
      // If contest hasn't started, just show player list
      setShowPlayerList(true);
    }
  };

  const [showPlayerList, setShowPlayerList] = useState(false);

  return (
    <div>
      <button
        onClick={handleClick}
        className={`relative p-2 text-white transition-colors rounded-lg hover:bg-gray-700/50 flex items-center gap-2 ${
          hasStarted ? 'ring-1 ring-orange-500' : 'ring-1 ring-gray-600'
        }`}
        {...props}
      >
        {hasStarted ? (
          <MessageCircle size={size} className="text-white" />
        ) : (
          <Clock size={size} className="text-gray-400" />
        )}
        {!hideCount && <span className="text-sm">{playerCount} Players</span>}
        
        {!hasStarted && contestStartDate && (
          <div className="absolute -top-8 left-1/2 transform -translate-x-1/2 bg-gray-800 text-xs text-gray-300 px-2 py-1 rounded whitespace-nowrap opacity-0 hover:opacity-100 transition-opacity z-10">
            <div className="flex items-center gap-1">
              <Clock size={10} />
              <span>Starts {contestStartDate.toLocaleDateString()}</span>
            </div>
          </div>
        )}
      </button>
      
      {showPlayerList && !hasStarted && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-gray-800 rounded-lg max-w-md w-full p-4">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Users className="text-orange-500" size={20} />
                <h3 className="text-lg font-semibold text-white">Registered Players</h3>
              </div>
              <button
                onClick={() => setShowPlayerList(false)}
                className="text-gray-400 hover:text-gray-300"
              >
                <X size={20} />
              </button>
            </div>
            
            <div className="mb-4 bg-gray-700/50 p-3 rounded-lg">
              <div className="flex items-center gap-2 text-gray-300">
                <Clock size={16} className="text-orange-500" />
                <span>
                  Contest chat will be available when the contest starts on{' '}
                  {contestStartDate?.toLocaleDateString()}
                </span>
              </div>
            </div>
            
            <div className="max-h-60 overflow-y-auto">
              {playerCount > 0 ? (
                <div className="space-y-2">
                  {Array.from({ length: playerCount }).map((_, i) => (
                    <div key={i} className="flex items-center gap-3 p-2 bg-gray-700/50 rounded-lg">
                      <div className="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center">
                        <Users size={16} className="text-gray-400" />
                      </div>
                      <div>
                        <div className="text-sm text-white">Player {i + 1}</div>
                        <div className="text-xs text-gray-400">Registered</div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-4 text-gray-400">
                  No players registered yet
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}