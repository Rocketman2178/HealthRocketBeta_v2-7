import React from 'react';
import { Trophy, Clock, ChevronRight } from 'lucide-react';

interface PreviewAccessProps {
  onContinue: () => void;
}

export function PreviewAccess({ onContinue }: PreviewAccessProps) {
  return (
    <div className="bg-gray-800 rounded-lg p-6 shadow-xl">
      <div className="flex justify-center mb-6">
        <div className="w-20 h-20 bg-orange-500/20 rounded-full flex items-center justify-center">
          <Trophy className="text-orange-500" size={32} />
        </div>
      </div>

      <h2 className="text-2xl font-bold text-white text-center mb-2">
        Preview Access
      </h2>
      
      <p className="text-gray-300 text-center mb-6">
        Enjoy 60 days of free Preview Access and $150 of Contest entry credits
      </p>

      <div className="space-y-4">
        <div className="space-y-4">
          <div className="bg-gray-700/50 rounded-lg p-4">
            <div className="flex items-center gap-3 mb-3">
              <Trophy className="text-orange-500" size={20} />
              <h3 className="text-lg font-medium text-white">Contest Credits</h3>
            </div>
            <p className="text-sm text-gray-400">
              Get $150 worth of free Contest entry credits to compete for cash prizes
            </p>
          </div>

          <div className="bg-gray-700/50 rounded-lg p-4">
            <div className="flex items-center gap-3 mb-3">
              <Clock className="text-orange-500" size={20} />
              <h3 className="text-lg font-medium text-white">60 Days Free</h3>
            </div>
            <p className="text-sm text-gray-400">
              Try all Pro features free for 60 days with no commitment
            </p>
          </div>
        </div>

        <button 
          onClick={onContinue}
          className="w-full px-4 py-2 bg-orange-500 text-white rounded-lg font-medium hover:bg-orange-600 flex items-center justify-center gap-2 group"
        >
          <span>Continue</span>
          <ChevronRight size={16} className="group-hover:translate-x-0.5 transition-transform" />
        </button>
      </div>
    </div>
  );
}