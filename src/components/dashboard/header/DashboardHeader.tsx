import React, { useState, useEffect } from 'react';
import { Heart, Activity, Rocket, Info, Crown, Gift, Target, Palette, Trophy, X, Plus } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { MetricCard } from './MetricCard';
import { HealthDashboard } from '../../health/HealthDashboard';
import { VitalSetup } from '../../health/VitalSetup';
import { Tooltip } from '../../ui/tooltip';
import { useHealthAssessment } from '../../../hooks/useHealthAssessment';
import { useSupabase } from '../../../contexts/SupabaseContext';
import { useCosmo } from '../../../contexts/CosmoContext';

interface LevelUpModalProps {
  level: number;
  onClose: () => void;
}

function LevelUpModal({ level, onClose }: LevelUpModalProps) {
  return (
    <div className="fixed inset-0 bg-black/90 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-gray-800 rounded-lg max-w-lg w-full p-6 relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-white"
        >
          <X size={20} />
        </button>

        <div className="text-center mb-8">
          <div className="flex items-center justify-center gap-2 mb-2">
            <Crown className="text-orange-500" size={28} />
            <h2 className="text-2xl font-bold text-white">Blastoff!</h2>
          </div>
          <p className="text-lg text-gray-300">You've reached Level {level}</p>
        </div>

        <div>
          <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <Gift className="text-orange-500" size={20} />
            <span>Keep Earning FP to Unlock</span>
          </h3>
          <div className="grid grid-cols-1 gap-4">
            <div className="bg-gray-700/50 p-4 rounded-lg">
              <div className="space-y-4">
                <div className="flex items-start gap-3">
                  <Target size={18} className="text-orange-500 mt-1 shrink-0" />
                  <div>
                    <p className="text-white">New Features at Higher Levels</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <Palette size={18} className="text-orange-500 mt-1 shrink-0" />
                  <div>
                    <p className="text-white">Custom Rocket Colors, Decals & Effects</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <Trophy size={18} className="text-orange-500 mt-1 shrink-0" />
                  <div>
                    <p className="text-white">New Challenges & Quests</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

interface DashboardHeaderProps {
  healthSpanYears: number;
  healthScore: number;
  nextLevelPoints: number;
  level: number;
}

export function DashboardHeader({ 
  healthSpanYears, 
  healthScore, 
  nextLevelPoints,
  level
}: DashboardHeaderProps) {
  const navigate = useNavigate();
  const [showHealthDashboard, setShowHealthDashboard] = useState(false);
  const [showLevelModal, setShowLevelModal] = useState(false);
  const [hasSeenLevelModal, setHasSeenLevelModal] = useState(() => {
    return localStorage.getItem('hasSeenLevelModal') === 'true';
  });
  const { user } = useSupabase();
  const { showCosmo } = useCosmo();
  const { canUpdate } = useHealthAssessment(user?.id);
  const [showVitalSetup, setShowVitalSetup] = useState(false);
  const [currentVitalUserId, setCurrentVitalUserId] = useState(null);
  const [getVitalUserLoading, setGetVitalUserLoading] = useState(false);

  // CHECK EXISTING VITAL USER
  const checkExistingVitalUser = async () => {
    if (!user) return null;

    try {
      setGetVitalUserLoading(true);
      const { data: vitalData, error: vitalError } = await supabase.rpc(
        "get_vital_user",
        {
          p_user_id: user.id,
        }
      );

      if (vitalError) throw vitalError;

      if (vitalData?.vital_user_id) {
        setCurrentVitalUserId(vitalData?.vital_user_id);
      }

      const { error: syncError } = await supabase.rpc("sync_vital_user", {
        p_user_id: user.id,
      });

      if (syncError) throw syncError;
    } catch (err) {
      setCurrentVitalUserId(null);
    } finally {
      setGetVitalUserLoading(false);
    }
  };

  useEffect(() => {
    checkExistingVitalUser();
  }, [user?.id]);

  const handleDataTrackingClick = () => {
    if (!currentVitalUserId) {
      setShowVitalSetup(true);
    } else {
      navigate("/connect-device");
    }
  };

  const handleShowLevelModal = () => {
    setShowLevelModal(true);
    setHasSeenLevelModal(true);
    localStorage.setItem('hasSeenLevelModal', 'true');
  };

  return (
    <div  id="rocket">
      <div className="bg-gray-800 py-4 sm:py-5 border-b border-gray-700 relative">
        <div className="max-w-6xl mx-auto px-4 relative">
          <div className="flex flex-col gap-4">
            <div className="flex items-center justify-center gap-3 sm:gap-6">
            {/* Beta indicator */}
            <div className="absolute -top-5 right-4">
              <div className="bg-black/20 backdrop-blur-sm px-2 py-0.5 rounded text-xs font-medium text-orange-500 border border-orange-500/30">
                Preview v2.5
              </div>
            </div>
            <button 
              onClick={() => setShowHealthDashboard(true)}
              className="flex-1 max-w-[200px]"
            >
              <MetricCard
                icon={<Heart size={20} className="text-orange-500" />}
                label="+HealthSpan"
                value={`+${healthSpanYears.toFixed(1)} yrs`}
                showNotification={canUpdate}
              />
            </button>
            <button 
              onClick={() => setShowHealthDashboard(true)}
              className="flex-1 max-w-[200px]"
            >
              <MetricCard
                icon={<Activity size={20} className="text-lime-500" />}
                label="HealthScore"
                value={healthScore.toString()}
                showNotification={canUpdate}
              />
            </button>
            <button 
              onClick={handleShowLevelModal}
              className="flex-1 max-w-[200px]"
            >
              <MetricCard
                icon={<Rocket size={20} className="text-orange-500" />}
                label="Level"
                value={level.toString()}
                showClickIndicator={!hasSeenLevelModal}
              />
            </button>
            </div>
            
            <button 
              onClick={handleDataTrackingClick}
              className="flex items-center justify-center gap-2 text-sm text-orange-500 hover:text-orange-400 transition-colors"
            >
              <div className="w-5 h-5 bg-orange-500 rounded-full flex items-center justify-center animate-pulse">
                <Plus size={12} className="text-white" />
              </div>
              <span className="text-xs">Connect Devices for FP Bonus and HealthScore Level Ups</span>
            </button>
          </div>
        </div>
        
      </div>

      {showHealthDashboard && (
        <HealthDashboard
          healthSpanYears={healthSpanYears}
          healthScore={healthScore}
          nextLevelFP={nextLevelPoints}
          onClose={() => setShowHealthDashboard(false)}
        />
      )}
      {showLevelModal && (
        <LevelUpModal
          level={level}
          onClose={() => setShowLevelModal(false)}
        />
      )}
      
      {/* Vital Setup Modal */}
      {showVitalSetup && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-[60] flex items-start justify-center p-4 overflow-y-auto">
          <div className="bg-gray-800 rounded-lg max-w-4xl w-full my-8 shadow-xl">
            <VitalSetup
              onComplete={() => {
                setShowVitalSetup(false);
                navigate("/connect-device");
              }}
              onClose={() => setShowVitalSetup(false)}
            />
          </div>
        </div>
      )}
    </div>
  );
}