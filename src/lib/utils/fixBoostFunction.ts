import { supabase } from '../supabase/client';

/**
 * Fixes the boost completion function in the database
 * This is a one-time fix for the "query has no destination for result data" error
 */
export async function fixBoostCompletionFunction() {
  try {
    const { data, error } = await supabase.functions.invoke('fix-boost-completion');
    
    if (error) {
      console.error('Error fixing boost function:', error);
      throw error;
    }
    
    console.log('Boost function fix result:', data);
    return { success: true, data };
  } catch (err) {
    console.error('Failed to fix boost completion function:', err);
    return { success: false, error: err };
  }
}

/**
 * Alternative fix that directly executes SQL to fix the function
 * Only used if the edge function approach fails
 */
export async function fixBoostCompletionFunctionDirect() {
  try {
    // This is a fallback method that requires admin privileges
    // It's better to use the edge function approach above
    const { data, error } = await supabase.rpc('fix_boost_completion_function');
    
    if (error) {
      console.error('Error fixing boost function directly:', error);
      throw error;
    }
    
    console.log('Direct boost function fix result:', data);
    return { success: true, data };
  } catch (err) {
    console.error('Failed to fix boost completion function directly:', err);
    return { success: false, error: err };
  }
}