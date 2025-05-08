import { useState, useEffect } from 'react';
import { Download, X } from 'lucide-react';

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

export function PWAInstallPrompt() {
  const [installPrompt, setInstallPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [showPrompt, setShowPrompt] = useState(false);
  const [isIOS, setIsIOS] = useState(false);

  useEffect(() => {
    // Check if on iOS
    const isIOSDevice = /iPad|iPhone|iPod/.test(navigator.userAgent) && !(window as any).MSStream;
    setIsIOS(isIOSDevice);

    // For non-iOS devices, listen for the beforeinstallprompt event
    if (!isIOSDevice) {
      const handleBeforeInstallPrompt = (e: Event) => {
        // Prevent Chrome 67 and earlier from automatically showing the prompt
        e.preventDefault();
        // Stash the event so it can be triggered later
        setInstallPrompt(e as BeforeInstallPromptEvent);
        // Show our custom install prompt
        setShowPrompt(true);
      };

      window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);

      return () => {
        window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
      };
    } else {
      // For iOS, check if the app is already installed
      const isInStandaloneMode = window.matchMedia('(display-mode: standalone)').matches || 
                                (window.navigator as any).standalone;
      
      // Only show the iOS instructions if not already in standalone mode
      if (!isInStandaloneMode) {
        // Show iOS-specific instructions after a delay
        const timer = setTimeout(() => {
          setShowPrompt(true);
        }, 3000);
        
        return () => clearTimeout(timer);
      }
    }
  }, []);

  const handleInstall = async () => {
    if (!installPrompt) return;
    
    // Show the native install prompt
    await installPrompt.prompt();
    
    // Wait for the user to respond to the prompt
    const choiceResult = await installPrompt.userChoice;
    
    // User accepted the install
    if (choiceResult.outcome === 'accepted') {
      console.log('User accepted the install prompt');
    } else {
      console.log('User dismissed the install prompt');
    }
    
    // Clear the saved prompt since it can't be used again
    setInstallPrompt(null);
    setShowPrompt(false);
  };

  const handleDismiss = () => {
    setShowPrompt(false);
    // Save to localStorage to avoid showing again in this session
    localStorage.setItem('pwaPromptDismissed', 'true');
  };

  // Don't show if user has dismissed or we're already in standalone mode
  if (!showPrompt || 
      localStorage.getItem('pwaPromptDismissed') === 'true' || 
      window.matchMedia('(display-mode: standalone)').matches || 
      (window.navigator as any).standalone) {
    return null;
  }

  return (
    <div className="fixed bottom-4 left-4 right-4 z-50 bg-gray-800 rounded-lg shadow-lg border border-orange-500/30 p-4 animate-bounceIn">
      <button 
        onClick={handleDismiss}
        className="absolute top-2 right-2 text-gray-400 hover:text-gray-300"
      >
        <X size={18} />
      </button>
      
      <div className="flex items-center gap-3">
        <div className="bg-orange-500/20 p-2 rounded-full">
          <Download className="text-orange-500" size={24} />
        </div>
        
        <div className="flex-1">
          <h3 className="text-white font-medium text-sm">Install Health Rocket</h3>
          {isIOS ? (
            <p className="text-gray-300 text-xs mt-1">
              Tap the share button and then "Add to Home Screen" to install
            </p>
          ) : (
            <p className="text-gray-300 text-xs mt-1">
              Install our app for the best experience
            </p>
          )}
        </div>
        
        {!isIOS && (
          <button
            onClick={handleInstall}
            className="bg-orange-500 text-white px-3 py-1.5 rounded-lg text-sm font-medium hover:bg-orange-600 transition-colors"
          >
            Install
          </button>
        )}
      </div>
    </div>
  );
}