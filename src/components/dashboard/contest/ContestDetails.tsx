@@ .. @@
 import { formatInTimeZone } from 'date-fns-tz';
 import { getChatPath } from '../../../lib/utils/chat';
 import { useSupabase } from '../../../contexts/SupabaseContext';
-import { supabase } from '../../../lib/supabase';
+import { supabase } from '../../../lib/supabase';
 import { Progress } from '../../ui/progress';
 import type { Challenge } from '../../../types/dashboard';
 import { useNavigate, useParams } from 'react-router-dom';
+import { challenges, tier0Challenge, contestChallenges } from '../../../data/challenges';
@@ .. @@
           challengeDetails = tier0Challenge;
         } else {
           // Check if this is a contest challenge
-          const isContestChallenge = challengeId.startsWith('cn_') || challengeId.startsWith('tc_');
+          const isContestChallenge = challengeId?.startsWith('cn_') || challengeId?.startsWith('tc_');
           setIsContest(isContestChallenge);
           
           // Check regular challenges first
-          challenge = challenges.find(c => c.challenge_id === challengeId || c.id === challengeId);
+          challengeDetails = challenges.find(c => c.challenge_id === challengeId || c.id === challengeId);
           
           // If not found, check contest challenges
           if (!challengeDetails) {