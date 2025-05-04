import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { Resend } from "https://esm.sh/resend@2.0.0";

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') || 're_Wnz8vEJr_BT6CLSZ41TdY5mphBcf3mqFF';
const SUPPORT_EMAIL = 'support@healthrocket.life';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

interface SupportMessage {
  messageId?: string;
  message: string;
  category: string;
  userName: string;
  userEmail: string;
  userId: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json'
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Missing required environment variables');
    }

    // Initialize Supabase client
    const supabase = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY
    );

    // Initialize Resend
    const resend = new Resend(RESEND_API_KEY);
    
    // Get message data from request
    const { message, category, userName, userEmail, userId, messageId }: SupportMessage = await req.json();

    // Validate required data
    if (!message || !userName || !userEmail || !userId) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields',
          details: {
            message: !message,
            userName: !userName,
            userEmail: !userEmail,
            userId: !userId
          }
        }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Insert support message into database if no messageId provided
    let dbMessageId = messageId;
    if (!dbMessageId) {
      const { data: messageData, error: dbError } = await supabase
        .from('support_messages')
        .insert({
          user_id: userId,
          user_name: userName,
          user_email: userEmail,
          message,
          category
        })
        .select()
        .single();

      if (dbError) {
        console.error('Database error:', dbError);
        return new Response(
          JSON.stringify({ 
            error: 'Failed to save message', 
            details: dbError.message,
            code: dbError.code 
          }),
          { status: 500, headers: corsHeaders }
        );
      }
      
      dbMessageId = messageData.id;
    }

    // Send email using Resend
    const { data: emailData, error: emailError } = await resend.emails.send({
      from: 'Health Rocket <onboarding@resend.dev>',
      to: SUPPORT_EMAIL,
      subject: `Support Request: ${category} from ${userName}`,
      html: `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
          <h2 style="color: #FF6B00;">Support Request</h2>
          <p><strong>From:</strong> ${userName} (${userEmail})</p>
          <p><strong>Category:</strong> ${category}</p>
          <p><strong>Message ID:</strong> ${dbMessageId}</p>
          <p><strong>Sent:</strong> ${new Date().toLocaleString()}</p>
          <div style="margin-top: 20px; padding: 15px; background-color: #f5f5f5; border-radius: 5px;">
            <p><strong>Message:</strong></p>
            <p>${message.replace(/\n/g, '<br>')}</p>
          </div>
        </div>
      `
    });

    if (emailError) {
      console.error('Email error:', emailError);
      // Update the message to indicate email failure but message was saved
      const { error: updateError } = await supabase
        .from('support_messages')
        .update({
          email_sent: false,
          email_sent_at: new Date().toISOString(),
          resolution_notes: `Email delivery failed: ${emailError.message}`
        })
        .eq('id', dbMessageId);
      
      if (updateError) {
        console.error('Error updating support message:', updateError);
      }

      return new Response(
        JSON.stringify({ 
          success: true, 
          warning: 'Support message saved but email delivery failed',
          error: emailError.message,
          messageId: dbMessageId
        }),
        { status: 200, headers: corsHeaders }
      );
    }

    // Update support message with email status
    const { error: updateError } = await supabase
      .from('support_messages')
      .update({
        email_sent: true,
        email_sent_at: new Date().toISOString(),
        email_id: emailData?.id
      })
      .eq('id', dbMessageId);

    if (updateError) {
      console.error('Error updating email status:', updateError);
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        messageId: dbMessageId,
        emailId: emailData?.id
      }),
      { status: 200, headers: corsHeaders }
    );
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({ 
        error: 'An unexpected error occurred',
        details: error.message
      }),
      { status: 500, headers: corsHeaders }
    );
  }
});