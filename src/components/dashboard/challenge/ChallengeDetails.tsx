import React, { useState } from 'react';
import { X, Award, Zap, Clock, Brain, Moon, Activity, Apple, Database, Target, Calendar, MessageCircle, ChevronRight, Users, Trophy, Info, ChevronDown, ChevronUp } from 'lucide-react';
import { getChatPath } from '../../../lib/utils/chat';
import { formatInTimeZone } from 'date-fns-tz';
import { challenges } from '../../../data';
import type { Challenge } from '../../../types/dashboard';
import { useSupabase } from '../../../contexts/SupabaseContext';

interface CurrentChallenge {
  challenge_id: string;
  status: string;
}
import { useNavigate } from 'react-router-dom';

interface ChallengeDetailsProps {
  challenge: Challenge;
  onClose: () => void;
  onStart: () => Promise<void>;
  activeChallengesCount: number;
  maxChallenges: number;
  currentChallenges: CurrentChallenge[];
  hasCompletedTier0?: boolean;
  daysUntilStart?: number | null;
  isContest?: boolean;
  fetchActiveContests?: () => Promise<void>; // Add this prop
  hasCredits?: boolean;
}

export function ChallengeDetails({ 
  challenge, 
  onClose, 
  onStart,
  activeChallengesCount,
  maxChallenges,
  currentChallenges,
  hasCompletedTier0 = false,
  daysUntilStart = null,
  isContest = false,
  fetchActiveContests, // Add this prop
  hasCredits = true
}: ChallengeDetailsProps) {
  const navigate = useNavigate();
  const { session } = useSupabase();
  const isAlreadyActive = currentChallenges.some(c => 
    c.challenge_id === challenge?.id || c.challenge_id === challenge?.challenge_id
  );
  const [loading, setLoading] = useState(false);
  const isPremiumRegistered = currentChallenges.some(c => 
    (c.challenge_id === challenge?.id || c.challenge_id === challenge?.challenge_id) && c.status === 'registered'
  );
  const isPremiumChallenge = challenge?.isPremium ?? false;
  const requiresTier0 = challenge?.tier === 1 && !hasCompletedTier0 && !challenge?.isPremium;
  const nonPremiumChallengesCount = currentChallenges.filter(c => 
    !challenges.find(ch => ch.id === c.challenge_id)?.isPremium
  ).length;
  const entryFee = challenge?.entryFee ?? 0;
  const isFreeContest = challenge?.category === 'Contests' && entryFee === 0;
  const isRegistered = currentChallenges.some(c => c.challenge_id === challenge?.id || c.challenge_id === challenge?.challenge_id);

  const [showSmallContestRules, setShowSmallContestRules] = useState(false);

  // If challenge is undefined, show loading state
  if (!challenge) {
    return (
      <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
        <div className="bg-gray-800 rounded-lg p-8">
          <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-orange-500 mx-auto" />
          <p className="text-gray-400 mt-4">Loading challenge details...</p>
        </div>
      </div>
    );
  }

  const handleStartChallenge = async () => {
    if (loading) return;
    setLoading(true);
    
    try {
      // If this is a contest with an entry fee, handle payment
      if (challenge.category === 'Contests' && challenge.entryFee > 0) {
        const response = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/create-premium-challenge-session`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${session}`,
              'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY
            },
            body: JSON.stringify({ 
              challengeId: challenge.challenge_id || challenge.id,
              entryFee: challenge.entryFee
            })
          }
        );

        const data = await response.json();
        if (data.sessionUrl) {
          window.location.href = data.sessionUrl;
          return;
        }
      }

      // For free challenges or contests, start immediately
      await onStart();
      
      // If this is a contest, refresh the contests list and dispatch an event
      if (challenge.category === 'Contests' || isContest) {
        if (fetchActiveContests) {
          await fetchActiveContests();
        }
        window.dispatchEvent(new CustomEvent('dashboardUpdate', { 
          detail: { contestRegistered: true, challengeId: challenge.challenge_id || challenge.id }
        }));
      }
    } catch (err) {
      console.error('Error starting challenge:', err);
    } finally {
      setLoading(false);
    }
  };

  // Check if contest has started
  const isContestStarted = () => {
    if (challenge.category !== 'Contests' || !challenge.startDate) {
      return true; // Not a contest or no start date, consider it started
    }
    
    const startDate = new Date(challenge.startDate);
    return startDate <= new Date();
  };
  
  // Get days display text
  const getDaysDisplay = () => {
    // If we have explicit days until start from the database, use that
    if (daysUntilStart !== null && !isContestStarted()) {
      return `${daysUntilStart} Days Until Start`;
    }
    
    // Otherwise calculate from start date
    if (challenge.startDate && !isContestStarted()) {
      const startDate = new Date(challenge.startDate);
      const now = new Date();
      const daysUntil = Math.ceil((startDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      return `${daysUntil} Days Until Start`;
    }
    
    // For active contests, show days remaining
    return `${challenge.daysRemaining} Days Left`;
  };

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-gray-800 rounded-lg max-w-2xl w-full flex flex-col max-h-[85vh] overflow-y-auto">
        <div className="bg-gray-900 p-4 border-b border-gray-700">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              {isContest || challenge.category === 'Contests' ? (
                <Trophy className="text-orange-500" size={24} />
              ) : (
                <Award className="text-orange-500" size={24} />
              )}
              <div>
                <h3 className="text-lg font-semibold text-white flex items-center gap-2">
                  <span>{challenge.name}</span>
                </h3>
                <div className="flex items-center gap-2 mt-1">
                  {(challenge.category === 'Contests' || isContest) && (
                    <span className={`text-xs px-2 py-0.5 rounded ${
                      challenge.entryFee ? 'bg-orange-500 text-white' : 'bg-lime-500/20 text-lime-500'
                    }`}>
                      {challenge.entryFee ? `1 Credit` : 'Free Entry'}
                    </span>
                  )}
                  <span className="text-sm text-orange-500">+{challenge.fuelPoints} FP</span>
                </div>
              </div>
            </div>
            <button 
              onClick={() => {
                // If this is a contest, navigate to the contests tab first
                if (challenge.category === 'Contests') {
                  // Dispatch an event to set the active tab to 'contests' before closing
                  window.dispatchEvent(new CustomEvent('setActiveTab', { detail: { tab: 'contests' } }));
                  setTimeout(() => {
                    onClose();
                  }, 50);
                } else {
                  onClose();
                }
              }}
              className="text-gray-400 hover:text-gray-300"
            >
              <X size={20} />
            </button>
          </div>
          <div className="flex items-center justify-between mt-4">
            <div className="flex items-center gap-2">
              <Clock size={16} className="text-orange-500" />
              <span className="text-sm text-gray-400">
                {isContestStarted() ? 'Started: ' : 'Start Date: '}
                {challenge.startDate ? formatInTimeZone(new Date(challenge.startDate), 'America/New_York', 'M/d/yyyy') : 'Immediate'}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <Calendar size={16} className="text-orange-500" />
              <span className="text-sm text-gray-400">{getDaysDisplay()}</span>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 p-4 space-y-6">
          {/* Note for Contest Challenges that require a device */}
          {challenge.category === 'Contests' && challenge.isPremium && challenge.requires_device && (
            <div className="text-orange-500 italic text-xs mb-4">
              Note: This Challenge requires the specific use of the Oura Ring to participate
            </div>
          )}

          {/* How To Win (for Contest Challenges) */}
          {(challenge.category === 'Contests' || isContest) && (
            <div>
              <h4 className="text-sm font-medium text-white mb-2">How To Win</h4>
              <div className="bg-gray-700/50 rounded-lg p-3">
                <p className="text-sm text-gray-300">Achieve the highest average weekly Sleep Score from your Oura Ring app.</p>
              </div>
            </div>
          )}

          {challenge.expertReference && (
            <div>
              <h4 className="text-sm font-medium text-white mb-2">Reference Experts</h4>
              <div className="flex items-start gap-2 bg-gray-700/50 p-3 rounded-lg">
                <Award size={16} className="text-orange-500 mt-0.5 shrink-0" />
                <p className="text-sm text-gray-300">{challenge.expertReference}</p>
              </div>
            </div>
          )}

          {/* How To Play (for Contest Challenges) */}
          {(challenge.category === 'Contests' || isContest) && challenge.howToPlay && (
            <div className="border border-orange-500/20 rounded-lg p-4 bg-orange-500/5">
              <h4 className="text-sm font-medium text-white mb-2">How To Play</h4>
              <p className="text-sm text-gray-300 mb-3">{challenge.howToPlay.description.replace(/Challenge/g, 'Contest')}</p>
              <ul className="space-y-2">
                {challenge.howToPlay.steps.map((step, index) => (
                  <li key={index} className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="text-orange-500 mt-1">•</span>
                    <span>{step.replace(/Challenge/g, 'Contest')}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Rewards (for Contest Challenges) */}
          {(challenge.category === 'Contests' || isContest) && (
            <div>
              <h4 className="text-sm font-medium text-white mb-2">Rewards</h4>
              <div className="bg-gray-700/50 rounded-lg p-4">
                <p className="text-sm text-gray-300 mb-3">In every Contest:</p>
                <div className="space-y-3">
                  <div className="bg-orange-500/10 p-3 rounded-lg">
                    <p className="text-sm text-white font-medium mb-2">Top 10% of Players</p>
                    <p className="text-sm text-gray-300">Share 75% of the available reward pool, which could mean:</p>
                    <ul className="mt-2 space-y-1 ml-4">
                      <li className="flex items-start gap-2 text-sm text-gray-300">
                        <span className="text-orange-500 mt-1">•</span>
                        <span>8 players: $450 for top player (6X return)</span>
                      </li>
                      <li className="flex items-start gap-2 text-sm text-gray-300">
                        <span className="text-orange-500 mt-1">•</span>
                        <span>20 players: $450 each for top 2 players (6X return)</span>
                      </li>
                      <li className="flex items-start gap-2 text-sm text-gray-300">
                        <span className="text-orange-500 mt-1">•</span>
                        <span>50 players: $450 each for top 5 players (6X return)</span>
                      </li>
                    </ul>
                  </div>
                  
                  <div className="bg-lime-500/10 p-3 rounded-lg">
                    <p className="text-sm text-white font-medium">Top 50% of Players</p>
                    <p className="text-sm text-gray-300">Get your credit back</p>
                  </div>
                  
                  <div className="bg-gray-700/50 p-3 rounded-lg">
                    <p className="text-sm text-white font-medium">All Other Players</p>
                    <p className="text-sm text-gray-300">Credits are forfeited</p>
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
                          <span><strong>1 player:</strong> Player earns a return of their credit if they complete all contest requirements</span>
                        </li>
                        <li className="flex items-start gap-2 text-sm text-gray-300">
                          <span className="text-orange-500 mt-1">•</span>
                          <span><strong>2 players:</strong> Winner earns both credits minus 20% admin fee (160% of credit value)</span>
                        </li>
                        <li className="flex items-start gap-2 text-sm text-gray-300">
                          <span className="text-orange-500 mt-1">•</span>
                          <span><strong>3 players:</strong> Winner earns prize pool minus admin fee and second place credit (140% of credit value), second place gets credit back</span>
                        </li>
                        <li className="flex items-start gap-2 text-sm text-gray-300">
                          <span className="text-orange-500 mt-1">•</span>
                          <span>Contests start on the scheduled date regardless of player count</span>
                        </li>
                      </ul>
                    </div>
                  )}
                  
                  <div className="bg-gray-700/50 p-3 rounded-lg">
                    <p className="text-xs text-gray-400 italic">Note: Credits used for Contests are non-refundable. Apple is not a sponsor of, or involved in, the contest in any manner.</p>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Only show Description for non-Contest challenges */}
          {challenge.category !== 'Contests' && !isContest && (
            <div>
              <h4 className="text-sm font-medium text-white mb-2">Description</h4>
              <div className="bg-gray-700/50 rounded-lg p-3">
                <div className="text-sm text-gray-300" dangerouslySetInnerHTML={{ 
                  __html: challenge.tier === 0 
                    ? "Establish a simple but powerful morning routine that touches all five health categories"
                    : challenge.description
                }} />
              </div>
            </div>
          )}

          {!challenge.isPremium && !isContest && (
            <div>
              <h4 className="text-sm font-medium text-white mb-2">Actions</h4>
              <div className="space-y-2">
                {challenge.tier === 0 ? (
                  <>
                    <div className="bg-gray-700/50 rounded-lg p-4 border-2 border-orange-500/50">
                      <ul className="space-y-2 text-sm text-gray-300">
                        <li className="flex items-start gap-2 text-sm text-gray-300">
                          <span>Complete at least 3 of these actions DAILY within 2 hours of waking:</span>
                        </li>
                        <li className="flex items-start gap-2 ml-4">
                          <Brain size={16} className="text-orange-500 mt-1 shrink-0" />
                          <span>Mindset: 2-minute gratitude reflection</span>
                        </li>
                        <li className="flex items-start gap-2 ml-4">
                          <Moon size={16} className="text-orange-500 mt-1 shrink-0" />
                          <span>Sleep: Record total sleep time or sleep quality score</span>
                        </li>
                        <li className="flex items-start gap-2 ml-4">
                          <Activity size={16} className="text-orange-500 mt-1 shrink-0" />
                          <span>Exercise: 5-minute stretch</span>
                        </li>
                        <li className="flex items-start gap-2 ml-4">
                          <Apple size={16} className="text-orange-500 mt-1 shrink-0" />
                          <span>Nutrition: Glass of water</span>
                        </li>
                        <li className="flex items-start gap-2 ml-4">
                          <Database size={16} className="text-orange-500 mt-1 shrink-0" />
                          <span>Biohacking: 5 minutes of morning sunlight exposure</span>
                        </li>
                      </ul>
                    </div>
                  </>
                ) : (
                  <div className="space-y-4">
                    {challenge.implementationProtocol && Object.entries(challenge.implementationProtocol).map(([week, protocol]) => (
                      <div key={week} className="space-y-1">
                        <div className="text-sm text-orange-500 font-medium">
                          {week.replace(/(\d+)/, ' $1')}:
                        </div>
                        <p className="text-sm text-gray-300 whitespace-pre-line">{protocol}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          <div>
            <h4 className="text-sm font-medium text-white mb-2">Requirements to Complete</h4>
            <ul className="space-y-2">
              {challenge.tier === 0 ? (
                <>
                  <li className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="mt-1.5">•</span>
                    <span>Submit Verification Posts in Challenge Chat</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-gray-300 ml-4">
                    <span className="mt-1.5">•</span>
                    <span><span className="text-orange-500">Week 1:</span> Selfie with morning sunlight exposure</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-gray-300 ml-4">
                    <span className="mt-1.5">•</span>
                    <span><span className="text-orange-500">Week 2:</span> Screenshot of weekly sleep score or time log</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-gray-300 ml-4">
                    <span className="mt-1.5">•</span>
                    <span><span className="text-orange-500">Week 3:</span> Three takeaway thoughts from this Challenge</span>
                  </li>
                </>
              ) : challenge.category === 'Contests' ? (
                <>
                  <li className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="mt-1.5">•</span>
                    <span>Post a screenshot of your Oura Sleep Score for each day of the Contest</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="mt-1.5">•</span>
                    <span>Post a screenshot of your Weekly Avrg Sleep Score from Oura on the last day of the Contest</span>
                  </li>
                  <li className="flex items-start gap-2 text-sm text-gray-300 mt-4 italic text-orange-400">
                    <span className="mt-1.5">*</span>
                    <span>Note: players who do not complete all of the requirements will not be eligible for any rewards.</span>
                  </li>
                </>
              ) : (
                challenge.requirements.map((req, index) => (
                  <li key={index} className="flex items-start gap-2 text-sm text-gray-300">
                    <span className="mt-1.5">•</span>
                    <span>
                      {typeof req === 'string' ? (
                        req
                      ) : (
                        <>
                          {req.description.replace(/\((\d+)% of score\)/, '(')}
                          <span className="text-orange-500">
                            {req.description.match(/(\d+)% of score/)?.[1]}%
                          </span>
                          <span> of score</span>
                        </>
                      )}
                    </span>
                  </li>
                ))
              )}
            </ul>
          </div>

          {challenge.tier !== 0 && <div>
            <h4 className="text-sm font-medium text-white mb-2">Verification Method</h4>
            <div className="bg-gray-700/50 rounded-lg p-3">
              <p className="text-sm text-gray-300">{
                challenge.verificationMethod
                  ? typeof challenge.verificationMethod === 'string'
                    ? challenge.verificationMethod
                    : challenge.verificationMethod.description || 'Complete daily tracking and verification logs'
                  : 'Complete daily tracking and verification logs'
              }</p>
            </div>
          </div>}

          {challenge.expertTips && (
            <div>
              <h4 className="text-sm font-medium text-white mb-2">Expert Tips</h4>
              <div className="bg-gray-700/50 rounded-lg p-3">
                <ul className="space-y-2">
                  {challenge.expertTips.map((tip, index) => (
                    <li key={index} className="flex items-start gap-2">
                      <Brain size={16} className="text-lime-500 mt-0.5 shrink-0" />
                      <span className="text-sm text-gray-300">{tip}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          )}
          
          <div className="text-xs text-gray-400">
            {challenge.id === 'mb0' || challenge.challenge_id === 'mb0'
              ? 'Complete Morning Basics to Unlock Tier 1 Challenges'
              : !challenge.isPremium && 'Complete this challenge to progress your active Quest' || ''
            }
          </div>
        </div>

        {/* Chat Button */}
        {isAlreadyActive && (
          <div className="mt-6 flex justify-center pb-4">
            {challenge.category === 'Contests' && !isContestStarted() ? (
              <button
                onClick={() => {
                  const chatId = challenge.challenge_id || challenge.id;
                  if (chatId) {
                    navigate(getChatPath(chatId));
                  }
                }}
                className="flex items-center gap-2 px-6 py-3 bg-orange-500 hover:bg-orange-600 text-white rounded-lg transition-colors"
              >
                <MessageCircle size={20} />
                <span>Go to Contest Page</span>
              </button>
            ) : (
              <button
                onClick={() => {
                  const chatId = challenge.challenge_id || challenge.id;
                  if (chatId) {
                    navigate(getChatPath(chatId));
                  }
                }}
                className="flex items-center gap-2 px-6 py-3 bg-orange-500 hover:bg-orange-600 text-white rounded-lg transition-colors"
              >
                <MessageCircle size={20} />
                <span>Access the {challenge.category === 'Contests' ? 'Contest' : 'Challenge'} Chat</span>
              </button>
            )}
          </div>
        )}

        {/* Fixed Footer */}
        <div className="flex items-center justify-between p-4 border-t border-gray-700 bg-gray-800">
          {(challenge.category === 'Contests' || isContest) && !isContestStarted() && (
            <div className="flex items-center gap-2 text-xs text-gray-400">
              <Clock size={14} className="text-orange-500" />
              <span>Contest starts on {new Date(challenge.startDate!).toLocaleDateString()}</span>
            </div>
          )}
          {(challenge.category === 'Contests' || isContest) && (
            <button
              onClick={() => {
                const chatId = challenge.challenge_id || challenge.id;
                if (chatId) {
                  navigate(getChatPath(chatId));
                }
              }}
              className="text-sm text-gray-400 hover:text-white flex items-center gap-2"
            >
              <Users size={16} />
              <span>View Players</span>
            </button>
          )}
          {!challenge.category || (challenge.category !== 'Contests' && !isContest) && (
            <div className="flex-1"></div>
          )}
          <div className="flex items-center gap-3">
            {challenge.tier === 2 && (
              <button
                className="px-4 py-1.5 bg-gray-600 text-gray-400 rounded-lg text-sm font-medium cursor-not-allowed whitespace-nowrap"
              >
                Unlocks with Tier 2 Quest
              </button>
            )}
            {challenge.tier === 1 && !hasCompletedTier0 && !challenge.isPremium ? (
              <button
                className="px-4 py-1.5 bg-gray-600 text-gray-400 rounded-lg text-sm font-medium cursor-not-allowed whitespace-nowrap"
              >
                Complete Tier 0 First
              </button>
            ) : ((challenge.tier === 0) || (challenge.tier === 1 && (hasCompletedTier0 || challenge.isPremium)) || isContest) && (
              <button
                onClick={handleStartChallenge}
                disabled={(!challenge.isPremium && nonPremiumChallengesCount >= maxChallenges) || isRegistered || loading}
                className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                  (!challenge.isPremium && nonPremiumChallengesCount >= maxChallenges) || isRegistered || (challenge.entryFee > 0 && !hasCredits)
                    ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                    : 'bg-orange-500 text-white hover:bg-orange-600 cursor-pointer flex items-center gap-2 group'
                } ${isRegistered ? 'text-xs px-3' : ''}`}
              >
                {isRegistered 
                  ? 'Already Registered' 
                  : (!challenge.isPremium && nonPremiumChallengesCount >= maxChallenges)
                    ? 'No Slots Available'
                    : loading
                      ? 'Processing...'
                      : (challenge.category === 'Contests' || isContest) 
                        ? (challenge.entryFee > 0 && !hasCredits)
                          ? 'No Credits'
                          : 'Register for Contest'
                        : 'Start Challenge'}
                {!(challenge.entryFee > 0 && !hasCredits) && (
                  <ChevronRight size={16} className="group-hover:translate-x-0.5 transition-transform ml-1" />
                )}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}