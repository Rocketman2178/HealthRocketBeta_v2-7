import { Routes, Route } from 'react-router-dom';
import { CoreDashboard } from './components/dashboard/CoreDashboard';
import { ChallengePage } from './components/dashboard/challenge/ChallengePage';
import { ChatPage } from './components/chat/ChatPage';
import { VitalResponsePage } from './components/common/VitalResponePage';
import { DeviceConnection } from './components/health/DeviceConnection';


export function AppRoutes() {

  return (
    <>
      <Routes>
        <Route path="/" element={<CoreDashboard />} />
        <Route path="/challenge/:challengeId" element={<ChallengePage />} />
        <Route path="/chat/:chatId" element={<ChatPage />} />
        <Route path='/connect-device' element={<DeviceConnection/>}/>
        <Route path="/vital-response" element={<VitalResponsePage/>}/>
      </Routes>
    </>
  );
}