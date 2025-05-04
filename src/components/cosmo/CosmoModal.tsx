import React, { useState } from 'react';
import { X, Radio, Zap, Trophy, Target, Brain, Moon, Activity, Apple, Database, ChevronLeft, ChevronRight, Heart, Rocket, Flame, Loader2, Check, Info } from 'lucide-react';
import { useCosmo } from '../../contexts/CosmoContext';
import { useSupabase } from '../../contexts/SupabaseContext';
import { usePlayerStats } from '../../hooks/usePlayerStats';
import { useLevelRecommendations, LevelInfo } from '../../hooks/useLevelRecommendations';
import { useNavigate } from 'react-router-dom';
import { scrollToSection } from '../../lib/utils';
import { useCompletedRecommendations } from '../../hooks/useCompletedRecommendations'; 
import { SupportForm } from '../profile/SupportForm';
import { CosmoChat } from './CosmoChat';

export function CosmoModal() {
  const { state, hideCosmo } = useCosmo();
  const { user } = useSupabase();
  const { stats } = usePlayerStats(user);
  const { recommendations, levelInfo, loading: loadingRecommendations } = useLevelRecommendations(stats.level);
  const { isRecommendationCompleted, markRecommendationComplete } = useCompletedRecommendations(user?.id);
  const navigate = useNavigate();
  const [selectedTopic, setSelectedTopic] = useState<string | null>(null);
  const [currentSlide, setCurrentSlide] = useState(0);
  const [showSupportForm, setShowSupportForm] = useState(false);

  if (state.isMinimized) {
    return null;
  }
  
  // If selectedTopic is set, show the topic details modal
  if (selectedTopic) {
    const topic = helpTopics.find(t => t.id === selectedTopic);
    return (
      <div className="fixed inset-0 bg-black/90 backdrop-blur-lg z-50 flex items-center justify-center p-4">
        <div className="bg-gray-800/70 rounded-lg max-w-md w-full shadow-xl border border-gray-700/50 max-h-[85vh] flex flex-col">
          <div className="flex items-center justify-between p-4 border-b border-gray-700">
            <div className="flex items-center gap-3">
              {topic?.icon}
              <h2 className="text-lg font-semibold text-white">{topic?.title}</h2>
            </div>
            <button
              onClick={() => setSelectedTopic(null)}
              className="p-2 text-gray-400 hover:text-gray-300 rounded-lg hover:bg-gray-700/50 transition-colors"
            >
              <X size={20} />
            </button>
          </div>
          <div className="p-6 space-y-6 overflow-y-auto min-h-0">
            <div className="space-y-8">
              {topic?.content.split('\n\n').map((section, i) => {
                const [title, ...content] = section.split('\n');
                return (
                  <div key={i} className="space-y-3">
                    <h4 className="text-orange-500 font-medium flex items-center gap-2">
                      {getTopicIcon(title)}
                      <span>{title}</span>
                    </h4>
                    <div className="space-y-2 pl-6">
                      {content.map((line, j) => (
                        <div key={j} className="flex items-start gap-2 text-gray-300">
                          <div className="w-1.5 h-1.5 rounded-full bg-orange-500/50 mt-2 flex-shrink-0" />
                          <span>{line.replace('• ', '')}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                );
              })}
              <button
                onClick={() => setSelectedTopic(null)}
                className="flex items-center gap-2 px-4 py-2 bg-black/20 text-orange-500 hover:text-orange-400 rounded-lg hover:bg-black/40 transition-all mt-8 w-full"
              >
                <ChevronLeft size={16} />
                <span>Back to Topics</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center p-4 overflow-y-auto">
      {/* Semi-transparent overlay */}
      <div className="absolute inset-0 bg-black/40 backdrop-blur-[2px] pointer-events-auto" />

      {/* Content */}
      <div className="bg-gray-800 rounded-lg max-w-md w-full border border-orange-500/30 shadow-[0_0_15px_rgba(255,107,0,0.15)] relative mt-24 mb-8">
        {/* Header - now has its own stacking context */}
        <div className="flex items-center justify-between p-4 border-b border-orange-500/20 bg-gray-900 relative z-10">
          <div className="flex items-center gap-3">
            <Radio className="text-orange-500 animate-radio-wave" size={24} />
            <h2 className="text-lg font-semibold text-white flex-1 pr-4">I'm Cosmo, Your AI Health Rocket Guide</h2>
          </div>
          <div className="flex flex-col items-end gap-2">
            <button
              onClick={hideCosmo}
              className="p-2 text-gray-400 hover:text-gray-300 rounded-lg hover:bg-gray-700/50 transition-colors cursor-pointer"
            >
              <X size={20} />
            </button>
          </div>
        </div>
        
        <div className="p-4 space-y-6 relative">
          {/* Welcome Message */}
          <CosmoChat onClose={hideCosmo} setActiveTab={setActiveTab} />

          {/* Level Recommendations */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-medium text-white flex items-center gap-2">
                <Rocket className="text-orange-500" size={16} />
                <span>Level {stats.level} Recommendations</span>
              </h3>
              {levelInfo?.description && (
                <div className="relative group">
                  <Info size={14} className="text-gray-400 hover:text-gray-300 cursor-pointer" />
                  <div className="absolute right-0 w-64 p-2 mt-2 text-xs bg-gray-800 rounded-lg shadow-xl border border-gray-700 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all z-10">
                    {levelInfo.description}
                  </div>
                </div>
              )}
            </div>
            <div className="relative">
              <div className="overflow-hidden">
                {loadingRecommendations ? (
                  <div className="flex items-center justify-center py-8">
                    <Loader2 className="w-8 h-8 text-orange-500 animate-spin" />
                  </div>
                ) : (
                <div 
                  className="flex transition-transform duration-300 ease-in-out"
                  style={{ transform: `translateX(-${currentSlide * 100}%)` }}
                >
                  {recommendations.map(rec => (
                    <div
                      key={rec.id}
                      className="w-full flex-shrink-0 px-2"
                      onClick={() => {
                        if (rec.scroll_target) {
                          scrollToSection(rec.scroll_target);
                        }
                        if (rec.action === 'openContestArena') {
                          setActiveTab('contests');
                        } else if (rec.action === 'openBoosts') {
                          setActiveTab('boosts');
                        } else if (rec.action === 'openChallengeLibrary') {
                          window.dispatchEvent(new CustomEvent('openChallengeLibrary'));
                        } else if (rec.action === 'connectDevice') {
                          navigate('/connect-device');
                        }
                        hideCosmo();
                      }}
                    >
                      <div className="w-full p-4 rounded-lg bg-gray-800/95 backdrop-blur-sm border border-orange-500/20 shadow-lg text-left relative hover:border-orange-500/30 transition-colors cursor-pointer">
                        <div className="flex items-start gap-3">
                          <div className="text-orange-500">
                            {getIconForCategory(rec.category)}
                          </div>
                          <div className="flex-1 min-w-0">
                            <div>
                              <h3 className="text-sm font-medium text-white">{rec.title}</h3>
                              <p className="text-xs text-gray-300 mt-1">{rec.description}</p>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
                )}
              </div>
              {/* Navigation Buttons */}
              <div className="flex flex-col items-center gap-2 mt-4">
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setCurrentSlide(prev => Math.max(0, prev - 1))}
                    disabled={currentSlide === 0}
                    className="p-2 text-gray-400 hover:text-white disabled:opacity-50 hover:bg-gray-700/50 rounded-lg transition-all"
                  >
                    <ChevronLeft size={20} />
                  </button>
                  <div className="flex gap-1">
                    {recommendations.map((_, index) => (
                      <button
                        key={index}
                        onClick={() => setCurrentSlide(index)}
                        className={`w-2 h-2 rounded-full transition-colors ${
                          currentSlide === index 
                            ? 'bg-orange-500' 
                            : 'bg-gray-600 hover:bg-gray-500'
                        }`}
                      />
                    ))}
                  </div>
                  <button
                    onClick={() => setCurrentSlide(prev => Math.min(recommendations.length - 1, prev + 1))}
                    disabled={currentSlide === recommendations.length - 1}
                    className="p-2 text-gray-400 hover:text-white disabled:opacity-50 hover:bg-gray-700/50 rounded-lg transition-all"
                  >
                    <ChevronRight size={20} />
                  </button>
                </div>
                <div className="text-xs text-gray-500">
                  {currentSlide + 1} of {recommendations.length}
                </div>
              </div>
            </div>
          </div>
          
          {/* Support & Feedback */}
          <div>
            <h3 className="text-sm font-medium text-white mb-3 flex items-center gap-2">
              <MessageSquare className="text-orange-500" size={16} />
              <span>Support & Feedback</span>
            </h3>
            <button
              onClick={() => setShowSupportForm(true)}
              className="w-full p-4 rounded-lg bg-gray-800/95 backdrop-blur-sm border border-orange-500/20 shadow-lg text-left hover:border-orange-500/30 transition-colors flex items-center gap-3"
            >
              <div className="w-10 h-10 bg-orange-500/20 rounded-full flex items-center justify-center">
                <MessageSquare className="text-orange-500" size={20} />
              </div>
              <div>
                <h3 className="text-sm font-medium text-white">Contact Support</h3>
                <p className="text-xs text-gray-300 mt-1">Get help or share feedback about your experience</p>
              </div>
            </button>
          </div>
          
          {/* Help Topics */}
          <div>
            <h3 className="text-sm font-medium text-white mb-3 flex items-center gap-2">
              <Radio className="text-orange-500" size={16} />
              <span>I can also help you learn about:</span>
            </h3>
            <div className="grid grid-cols-2 gap-3">
              {helpTopics.map(topic => (
                <button
                  key={topic.id}
                  onClick={() => setSelectedTopic(topic.id)}
                  className="flex flex-col gap-2 p-3 bg-gray-800/95 backdrop-blur-sm border border-orange-500/20 rounded-lg text-left hover:bg-gray-700 hover:border-orange-500/30 hover:scale-[1.02] active:scale-[0.98] transition-all duration-300 shadow-lg hover:shadow-orange-500/10"
                >
                  <div className="text-orange-500">{topic.icon}</div>
                  <div>
                    <div className="text-sm font-medium text-white">{topic.title}</div>
                    <div className="text-xs text-gray-300 mt-0.5">{topic.description}</div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
      
      {/* Support Form Modal */}
      {showSupportForm && (
        <div className="fixed inset-0 bg-black/90 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-gray-800 rounded-lg max-w-md w-full p-6 shadow-xl">
            <SupportForm onClose={() => setShowSupportForm(false)} />
          </div>
        </div>
      )}
    </div>
  );
}

const helpTopics = [
  {
    id: 'how-to-play',
    icon: <Rocket size={16} />,
    title: 'Game Basics',
    description: 'Learn how to play and earn rewards',
    content: `Your Mission:
• Add 20+ years of healthy life!
• Create your profile and set your health baseline
• Earn Fuel Points through daily healthy actions
• Launch your Health Rocket to level up

Health Categories:
• Mindset
• Sleep
• Exercise
• Nutrition
• Biohacking

Track Progress:
• Track your +HealthSpan and HealthScore progress with monthly updates
• Win prizes and climb the leaderboard`
  },
  {
    id: 'fuel-points',
    icon: <Zap size={16} />,
    title: 'Fuel Points',
    description: 'Learn about FP and leveling up',
    content: `Earn Fuel Points (FP):
• Daily Boosts (1-9 FP each)
• Challenges (50 FP)
• Quests (150 FP)

Level Up System:
• Level 2 requires 20 FP
• Each new level needs 41.4% more FP

Unlock Features:
• New challenges
• Additional quest slots
• Special prizes`
  },
  {
    id: 'boosts',
    icon: <Activity size={16} />,
    title: 'Daily Boosts',
    description: 'Learn about boosts and streaks',
    content: `Daily Actions:
• Complete up to 3 Daily Boosts
• Each boost has a 7-day cooldown

Burn Streak Bonuses:
• 3 days: +5 FP
• 7 days: +10 FP
• 21 days: +100 FP

Pro Features:
• Pro Plan unlocks Tier 2 Boosts
• Maintain streaks to unlock challenges`
  },
  {
    id: 'challenges',
    icon: <Target size={16} />,
    title: 'Challenges & Quests',
    description: 'Learn about long-term goals',
    content: `Challenges:
• 21-day duration
• Earn 50 FP each
• Unlock after 3-day streak
• Chat with other challengers
• Required verification posts

Quests:
• 90-day duration
• Earn 150 FP each
• Complete 2-3 related challenges
• Quest group chat support
• Verification milestones required

Pro Content:
• Pro Plan unlocks Tier 2 content`
  },
  {
    id: 'health',
    icon: <Heart size={16} />,
    title: 'Health Tracking',
    description: 'Learn about health metrics',
    content: `HealthScore Categories:
• Mindset (20%)
• Sleep (20%)
• Exercise (20%)
• Nutrition (20%)
• Biohacking (20%)

Progress Tracking:
• Update score monthly (every 30 days)
• +HealthSpan shows added years of healthy life
• Track progress toward 20+ year goal`
  },
  {
    id: 'prizes',
    icon: <Trophy size={16} />,
    title: 'Prize Pool',
    description: 'Learn about rewards',
    content: `Monthly Status Ranks:
• Commander (All players)
• Hero (Top 50%) - 2X prize chances
• Legend (Top 10%) - 5X prize chances

Prize System:
• Monthly prize pools with draws every 30 days
• Win products from health partners
• Pro Plan required for prizes`
  }
];

// Helper function to get appropriate icon for category
function getIconForCategory(category: string | undefined) {
  if (!category) return <Rocket size={16} />;
  
  const category_lower = category.toLowerCase();
  if (category_lower === 'mindset') {
    return <Brain size={16} />;
  } else if (category_lower === 'sleep') {
    return <Moon size={16} />;
  } else if (category_lower === 'exercise') {
    return <Activity size={16} />;
  } else if (category_lower === 'nutrition') {
    return <Apple size={16} />;
  } else if (category_lower === 'biohacking') {
    return <Database size={16} />;
  } else if (category_lower === 'contests') {
    return <Trophy size={16} />;
  } else {
    return <Rocket size={16} />;
  }
}

// Helper function to get icon for topic titles
function getTopicIcon(title: string) {
  const iconMap: Record<string, React.ReactNode> = {
    'Your Mission': <Rocket size={18} />,
    'Health Categories': <Heart size={18} />,
    'Track Progress': <Target size={18} />,
    'Earn Fuel Points (FP)': <Zap size={18} />,
    'Level Up System': <Trophy size={18} />,
    'Unlock Features': <ChevronRight size={18} />,
    'Daily Actions': <Activity size={18} />,
    'Burn Streak Bonuses': <Flame size={18} />,
    'Pro Features': <Trophy size={18} />,
    'Challenges': <Target size={18} />,
    'Quests': <Trophy size={18} />,
    'Pro Content': <ChevronRight size={18} />,
    'HealthScore Categories': <Heart size={18} />,
    'Progress Tracking': <Target size={18} />,
    'Monthly Status Ranks': <Trophy size={18} />,
    'Prize System': <Trophy size={18} />,
    'Mindset Experts': <Brain size={18} className="text-orange-500" />,
    'Sleep Experts': <Brain size={18} className="text-blue-500" />,
    'Exercise Experts': <Brain size={18} className="text-lime-500" />,
    'Nutrition Experts': <Brain size={18} className="text-yellow-500" />,
    'Biohacking Experts': <Brain size={18} className="text-purple-500" />
  };

  return iconMap[title] || <ChevronRight size={18} />;
}