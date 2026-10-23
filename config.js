// Fill these in to switch the app from demo mode to real accounts, chat and notifications.
// All three values are safe to publish: the database rules decide what each member can see.
// The VAPID public key below has no matching private key in this repo (it was never committed).
// Generate a new pair with `npx web-push generate-vapid-keys` and replace vapidPublicKey.
// Put the private key only in Supabase Edge Function secrets. See LAUNCH.md.
window.PN_CONFIG = {
  supabaseUrl: '',      // Supabase → Project Settings → API → Project URL, e.g. https://abcd1234.supabase.co
  supabaseAnonKey: '',  // same page: the "anon" / publishable key (never the service_role / secret key)
  kakao: false,         // set to true once Kakao login is set up in Supabase (see SETUP.md step 4)
  vapidPublicKey: 'BBSe_1cSrkg3XpoWfT089X6Gu7x3fM0yXPVHQvnEaum1Z3m7MQGZhxl1ylFkoAmz1fgTFzlgrUak9EjwKfyn2MQ',
};
