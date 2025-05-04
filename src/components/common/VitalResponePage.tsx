import { useEffect, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { supabase } from "../../lib/supabase/client";
import { useSupabase } from "../../contexts/SupabaseContext";
import LoadingSpinner from "./LoadingSpinner";

export const VitalResponsePage = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  
  const [state, setState] = useState<string>("");
  const [provider, setProvider] = useState<string>("");
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState<string | null>(null);
  
  const { user } = useSupabase();

  useEffect(() => {
    const processStatus = async () => {
      setLoading(true);

      const stateParam = searchParams.get("state");
      const providerParam = searchParams.get("provider");

      if (stateParam === "success" && providerParam) {
        try {
          // Update status to "active"
          const { error } = await supabase
            .from("user_devices")
            .update({ status: "active" })
            .eq("user_id", user?.id)
            .eq("provider", providerParam);

          if (error) throw error;

          setState(stateParam);
          setProvider(providerParam);
          setMessage("Device successfully linked!");
        } catch (error) {
          setMessage("An error occurred while updating your device status.");
        }
      } else {
        setMessage("Invalid request or missing parameters.");
      }

      setLoading(false);

      // Redirect after 3 seconds
      setTimeout(() => {
        navigate("/");
      }, 3000);
    };

    processStatus();
  }, [searchParams, user?.id]);

  if (loading) {
    return <LoadingSpinner />;
  }

  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <div className="bg-white p-6 rounded-lg shadow-lg text-center">
        {state === "success" && provider ? (
          <h2 className="text-green-600 font-semibold text-xl">{message}</h2>
        ) : (
          <h2 className="text-red-600 font-semibold text-xl">{message}</h2>
        )}
        <p className="text-gray-600 mt-2">Redirecting...</p>
      </div>
    </div>
  );
};
