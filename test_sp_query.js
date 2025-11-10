const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://unannygymdwpuadscqjl.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVuYW5ueWd5bWR3cHVhZHNjcWpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNzQyNDAsImV4cCI6MjA3Njg1MDI0MH0.6oGARbFfxPRLEeMhcAu8d1Q1GlJcue2BXXQE704uqGg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function inspectSP() {
  try {
    console.log('Inspecting sp_gettop5balances(\'2\', null)...');

    const { data, error } = await supabase.rpc('sp_gettop5balances', {
      p_accountcode: '2',
      p_accounttype: null
    });

    if (error) {
      console.error('Error:', error);
      return;
    }

    console.log('Result:');
    console.log(JSON.stringify(data, null, 2));

    if (Array.isArray(data)) {
      console.log(`\nReturned ${data.length} records`);
      if (data.length > 0) {
        console.log('First record structure:', Object.keys(data[0]));
      }
    }

  } catch (err) {
    console.error('Exception:', err);
  }
}

inspectSP();