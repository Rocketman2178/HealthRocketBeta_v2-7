import { supabase } from './supabase';

export async function submitSupportMessage(
  userId: string, 
  message: string, 
  category: string = 'general'
) {
  try {
    // First submit message to database
    const { data, error: dbError } = await supabase.rpc('submit_user_support', {
      p_user_id: userId,
      p_category: category,
      p_feedback: message,
      p_rating: null,
      p_context: {}
    });

    if (dbError) throw dbError;
    if (!data?.success) throw new Error('Failed to save message');

    // Get user details for email
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError) throw authError;

    // Call edge function to send email
    const response = await fetch(
      `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-support-email`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          messageId: data.message_id,
          message,
          category,
          userName: user?.user_metadata?.name || user?.email?.split('@')[0] || 'Unknown User',
          userEmail: user?.email,
          userId
        })
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to send email');
    }

    return { success: true, messageId: data.message_id };
  } catch (err) {
    console.error('Error submitting support message:', err);
    throw err;
  }
}