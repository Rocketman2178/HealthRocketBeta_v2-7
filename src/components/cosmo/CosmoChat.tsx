import React, { useState, useEffect } from 'react';
import { Send, Radio, Zap, Trophy, Target, Heart, Info, ChevronRight, ChevronLeft, X, Flame, MessageSquare, Rocket, Brain, Moon, Activity, Apple, Database } from 'lucide-react';
import { useLevelRecommendations, LevelInfo } from '../../hooks/useLevelRecommendations';
import { usePlayerStats } from '../../hooks/usePlayerStats';
import { useSupabase } from '../../contexts/SupabaseContext';
import { scrollToSection } from '../../lib/utils';
import { SupportForm } from '../profile/SupportForm';

// Credentials for n8n authentication
const username = 'secret';
const password = '__n8n_BLANK_VALUE_e5362baf-c777-4d57-a609-6eaf1f9e87f6';
const credentials = btoa(`${username}:${password}`);

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

interface CosmoMessage {
  id: string;
  content: string;
  isUser: boolean;
  loading?: boolean;
}

interface CosmoChatProps {
  onClose: () => void;
  setActiveTab: (tab: string) => void;
}

export function CosmoChat({ onClose, setActiveTab }: CosmoChatProps) {
  const [messages, setMessages] = useState<CosmoMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedTopic, setSelectedTopic] = useState<string | null>(null); 
  const [showSupportForm, setShowSupportForm] = useState(false);
  const { user } = useSupabase();
  const { stats } = usePlayerStats(user);
  const { recommendations, levelInfo, loading: loadingRecommendations } = useLevelRecommendations(stats.level);
  const [currentSlide, setCurrentSlide] = useState(0);

  useEffect(() => {
    setMessages([{
    id: 'welcome',
    content: "Hi! I'm Cosmo, your Health Rocket guide. How can I help you optimize your health journey?",
    isUser: false,
    loading: false
    }]);
  }, []);

  const handleSend = async () => {
    if (!input.trim()) return;

    // Add user message
    const userMessage: CosmoMessage = {
      id: crypto.randomUUID(),
      content: input,
      isUser: true
    };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    
    // Add loading message
    const loadingId = crypto.randomUUID();
    const loadingMessage: CosmoMessage = {
      id: loadingId,
      content: "...",
      isUser: false,
      loading: true
    };
    setMessages(prev => [...prev, loadingMessage]);
    setIsLoading(true);

    try {
      // Call the n8n.io webhook with authentication and Key parameter
      const response = await fetch('https://healthrocket.app.n8n.cloud/webhook/9aa19401-f6f3-4833-b632-e8ebc3f0bbef/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${credentials}`,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          message: input,
          userId: user?.id || 'anonymous',
          userName: user?.user_metadata?.name || 'User',
          Key: user?.id || 'anonymous' // Required by n8n for session tracking
        })
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error('Error response from n8n webhook:', errorText);
        throw new Error(`Failed to get response from AI agent: ${errorText}`);
      }

      const data = await response.json();
      console.log('Response from n8n webhook:', data);
      
      // Extract and format the response content
      const formattedResponse = extractAndFormatResponse(data);
      
      setMessages(prev => prev.map(msg => 
        msg.id === loadingId 
          ? { 
              id: loadingId, 
              content: formattedResponse,
              isUser: false,
              loading: false
            } 
          : msg
      ));
    } catch (error) {
      console.error('Error fetching from webhook:', error);
      
      // Log detailed error for debugging
      if (error instanceof Error) {
        console.error('Error details:', error.message);
      }
      
      // Replace loading message with a user-friendly error message
      setMessages(prev => prev.map(msg => 
        msg.id === loadingId 
          ? { 
              id: loadingId, 
              content: "I'm having trouble connecting right now. Please try again later.",
              isUser: false,
              loading: false
            } 
          : msg
      ));
    } finally {
      setIsLoading(false);
    }
  };

  // Function to extract and format response from various data structures
  const extractAndFormatResponse = (data: any): string => {
    // If data is null or undefined, return a fallback message
    if (!data) {
      return "I'm having trouble understanding the response. Please try again.";
    }
    
    // If data is already a string, format it directly
    if (typeof data === 'string') {
      return formatResponseText(data);
    }
    
    // If data is an object, try to extract the response content
    if (typeof data === 'object') {
      // Common response fields in order of priority
      const possibleFields = ['response', 'output', 'text', 'message', 'result', 'answer', 'content'];
      
      // Try each field in order
      for (const field of possibleFields) {
        if (data[field] !== undefined) {
          const content = data[field];
          
          // If the content is a string, format it
          if (typeof content === 'string') {
            return formatResponseText(content);
          }
          
          // If the content is an object, stringify it
          if (typeof content === 'object') {
            try {
              return formatResponseText(JSON.stringify(content));
            } catch (e) {
              console.error('Error stringifying object:', e);
            }
          }
        }
      }
      
      // If no fields matched, try to stringify the entire object
      try {
        return formatResponseText(JSON.stringify(data));
      } catch (e) {
        console.error('Error stringifying data:', e);
      }
    }
    
    // Fallback message if all else fails
    return "I'm having trouble understanding the response. Please try again.";
  };

  // Function to format response text with markdown-like syntax
  const formatResponseText = (text: string): string => {
    if (!text) return '';

    let formatted = text;
    
    // Try to parse JSON strings
    if (typeof text === 'string' && 
        (text.trim().startsWith('{') && text.trim().endsWith('}')) || 
        (text.trim().startsWith('[') && text.trim().endsWith(']'))) {
      try {
        const jsonData = JSON.parse(text);
        
        // If it's an array, format each item
        if (Array.isArray(jsonData)) {
          return jsonData.map(item => 
            typeof item === 'string' ? item : JSON.stringify(item)
          ).join('<br /><br />');
        }
        
        // Extract content from common JSON fields
        const possibleFields = ['output', 'response', 'text', 'message', 'content', 'answer'];
        for (const field of possibleFields) {
          if (jsonData[field]) {
            formatted = typeof jsonData[field] === 'string' 
              ? jsonData[field] 
              : JSON.stringify(jsonData[field]);
            break;
          }
        }
      } catch (e) {
        // If parsing fails, continue with original text
        console.log("Not valid JSON, continuing with text formatting");
      }
    }

    // Check if the text already has HTML-like formatting
    if (formatted.includes('<') && formatted.includes('>')) {
      return formatted; // Return as is if it already has HTML
    } else if (formatted.includes('\n\n')) {
      // If text has paragraph breaks, format them as divs
      const paragraphs = formatted.split('\n\n');
      return paragraphs.map(p => `<div class="mb-3">${formatParagraph(p)}</div>`).join('');
    }
    
    return formatParagraph(formatted);
  };
  
  // Helper function to format a single paragraph
  const formatParagraph = (text: string): string => {
    let formatted = text;
    
    // Format headings (lines ending with : or starting with # followed by space)
    formatted = formatted.replace(/^(.+):\s*$/gm, '<strong class="text-orange-500">$1:</strong>');
    formatted = formatted.replace(/^#\s+(.+)$/gm, '<h3 class="text-lg font-medium text-orange-500 mb-2">$1</h3>');
    
    // Format lists (lines starting with - or •)
    formatted = formatted.replace(/^[-•]\s+(.+)$/gm, '<div class="flex items-start gap-2 my-1"><div class="w-1.5 h-1.5 rounded-full bg-orange-500/50 mt-2 flex-shrink-0"></div><span>$1</span></div>');
    
    // Format numbered lists (lines starting with 1., 2., etc.)
    formatted = formatted.replace(/^(\d+)\.\s+(.+)$/gm, '<div class="flex items-start gap-2 my-1"><span class="text-orange-500 font-medium">$1.</span><span>$2</span></div>');
    
    // Format bold text (text between ** or __)
    formatted = formatted.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    formatted = formatted.replace(/__(.+?)__/g, '<strong>$1</strong>');
    
    // Format italic text (text between * or _)
    formatted = formatted.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    formatted = formatted.replace(/_([^_]+)_/g, '<em>$1</em>');
    
    // Format code blocks (text between ` or ```)
    formatted = formatted.replace(/```(.+?)```/gs, '<pre class="bg-gray-800 p-2 rounded my-2 overflow-x-auto"><code>$1</code></pre>');
    formatted = formatted.replace(/`([^`]+)`/g, '<code class="bg-gray-800 px-1 rounded">$1</code>');
    
    // Format single newlines
    formatted = formatted.replace(/\n/g, '<br />');
    
    return formatted;
  };

  return (
    <div className="space-y-6">
      {/* Chat Section */}
      <div className="bg-gray-800/50 rounded-lg overflow-hidden">
        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.map(message => (
            <div
              key={`${message.id}-${message.loading}`}
              className={`flex ${message.isUser ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-[80%] rounded-lg px-4 py-2 ${
                  message.isUser
                    ? 'bg-orange-500 text-white'
                    : 'bg-gray-700 text-gray-100'
                }`}
              >
                {message.loading ? (
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-pulse"></div>
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-pulse delay-150"></div>
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-pulse delay-300"></div>
                  </div>
                ) : (
                  <div dangerouslySetInnerHTML={{ __html: message.content }} />
                )}
              </div>
            </div>
          ))}
        </div>

        {/* Input */}
        <div className="p-4 border-t border-gray-700">
          <div className="flex gap-2">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && !isLoading && handleSend()}
              placeholder="Ask Cosmo anything..."
              className="flex-1 bg-gray-700 text-white rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500"
            />
            <button
              onClick={handleSend}
              disabled={!input.trim() || isLoading}
              className="p-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoading ? (
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
              ) : (
                <Send size={20} />
              )}
            </button>
          </div>
        </div>
      </div>
      
      {/* Welcome Message */}
      <div className="text-gray-300 text-sm">
        I can help you Level Up, Earn Fuel Points, and Increase your HealthSpan.
      </div>

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
                <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-orange-500" />
              </div>
            ) : (
              <div 
                className="flex transition-transform duration-300 ease-in-out"
                style={{ transform: `translateX(-${currentSlide * 100}%)` }}
              >
                {recommendations.map(rec => (
                  <div
                    key={rec.id}
                    className="w-full flex-shrink-0 px-2 cursor-pointer"
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
                        window.location.href = '/connect-device';
                      }
                    }}
                  >
                    <div className="w-full p-4 rounded-lg bg-gray-800/95 backdrop-blur-sm border border-orange-500/20 shadow-lg text-left relative hover:border-orange-500/30 transition-colors">
                      <div className="flex items-start gap-3">
                        <div className="text-orange-500">
                          {getIconForCategory(rec.category)}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="mb-8">
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
                <ChevronRight size={20} className="rotate-180" />
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
      
      {/* Topic Details Modal */}
      {selectedTopic && (
        <div className="fixed inset-0 bg-black/90 backdrop-blur-lg z-50 flex items-center justify-center p-4">
          <div className="bg-gray-800/70 rounded-lg max-w-md w-full shadow-xl border border-gray-700/50 max-h-[85vh] flex flex-col">
            <div className="flex items-center justify-between p-4 border-b border-gray-700">
              <div className="flex items-center gap-3">
                {helpTopics.find(t => t.id === selectedTopic)?.icon}
                <h2 className="text-lg font-semibold text-white">
                  {helpTopics.find(t => t.id === selectedTopic)?.title}
                </h2>
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
                {helpTopics.find(t => t.id === selectedTopic)?.content.split('\n\n').map((section, i) => {
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
      )}
      
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