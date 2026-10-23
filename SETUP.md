# Turning on real accounts, chat and notifications

Right now `config.js` is empty, so the app runs as a demo with simulated neighbors.
Follow these steps once and it switches to real mode:

- Login is required (email code now, Kakao once you set it up).
- Profiles, pets and caregiver services are saved to the database.
- Chat between real members is live.
- New messages send a notification to the other person's phone.

It takes about 45 minutes. Everything here is free to start.

What is real in this first phase: **accounts, profiles, pets, caregiver services, chat, notifications.**
Still demo for now: example caregivers (marked "Example"), requests, bookings, reviews, walk tracking, community and places.
Those move to the database in the next phase.

---

## 1. Create the Supabase project (5 min)

1. Sign up at **supabase.com** and click **New project**.
2. Name: `petneighbor`. Region: **Northeast Asia (Seoul)**. Save the database password somewhere safe.
3. When it's ready, open **Project Settings → API** (or **API Keys**) and copy:
   - **Project URL** (looks like `https://abcd1234.supabase.co`)
   - **anon / publishable key**. Never use the `service_role` / secret key in the app.
4. Paste both into `config.js`:

   ```js
   supabaseUrl: 'https://abcd1234.supabase.co',
   supabaseAnonKey: 'eyJ... or sb_publishable_...',
   ```

## 2. Create the database tables (2 min)

1. Open **SQL Editor → New query**.
2. Paste the whole of `supabase/schema.sql` and click **Run**. You should see "Success. No rows returned".

This creates the tables and the access rules. For example, only the two people in a chat can read it, and only you can edit your profile.

## 3. Email login (5 min)

1. **Authentication → Sign In / Providers → Email**: make sure Email is enabled.
2. **Authentication → Emails → Templates → Magic Link**: replace the message body with:

   ```html
   <h2>멍냥이웃 로그인 코드</h2>
   <p>앱에 아래 6자리 코드를 입력해 주세요: <strong>{{ .Token }}</strong></p>
   <p>Enter this 6-digit code in the app: <strong>{{ .Token }}</strong></p>
   ```

   The app asks for this code. It works better than a link on phones, because a link opens Safari instead of the Home Screen app.
3. **Authentication → URL Configuration**: after step 6, set **Site URL** to your app's address and add it under **Redirect URLs**.

Supabase's built-in email only sends a few messages per hour. That's fine for testing. Before launch, connect a real email sender under **Authentication → Emails → SMTP Settings**.

## 4. Kakao login (15 min, can be done later)

1. Go to **developers.kakao.com → 내 애플리케이션 → 애플리케이션 추가하기** and create the app.
2. **앱 설정 → 플랫폼 → Web**: add your app's address from step 6.
3. **제품 설정 → 카카오 로그인**: turn it **ON**. Under **Redirect URI** add
   `https://<your-project>.supabase.co/auth/v1/callback`
4. **카카오 로그인 → 동의항목**: set 닉네임 (profile_nickname) and 프로필 사진 (profile_image).
   - 카카오계정(이메일) needs a business app (비즈 앱 전환).
   - Without it, turn on **Allow users without an email** in Supabase's Kakao settings, if your dashboard shows that option.
5. **보안 → Client Secret**: generate it and set its status to **사용함**.
6. In Supabase, open **Authentication → Sign In / Providers → Kakao** and enable it.
   - **Client ID** = the app's **REST API 키** (앱 키 page).
   - **Client Secret** = the secret from step 5.
7. In `config.js`, set `kakao: true`. The yellow **카카오로 시작하기** button appears on the login screen.

## 5. Notifications (10 min)

The public key in `config.js` has no private key in this repository. That file was never committed. Generate a new pair and replace the public key:

```bash
npx web-push generate-vapid-keys
```

Put the public key in `config.js` as `vapidPublicKey`. Keep the private key for the secret below. Do not commit it.

1. **Edge Functions → Deploy a new function → Via editor**. Name it **`send-push`**.
2. Replace the sample code with all of `supabase/functions/send-push/index.ts` and deploy.
3. Open the function's **Details / Settings** and turn **Verify JWT** (Enforce JWT verification) **off**. The function checks its own secret instead.
4. **Edge Functions → Secrets**:
   - `VAPID_PUBLIC_KEY` — the public key you just generated
   - `VAPID_PRIVATE_KEY` — the private key (never put this in the app)
   - `VAPID_SUBJECT` — `mailto:hellopawfend@gmail.com` (or another mailbox you read)
   - `WEBHOOK_SECRET` — a long random string you invent, for example `openssl rand -hex 32`
5. **Database → Webhooks → Create a new hook**:
   - Name: `new-message-push`
   - Table: `messages`, Events: **Insert**
   - Type: **Supabase Edge Functions**, function **send-push**, method POST
   - HTTP Headers: add `x-webhook-secret` with the `WEBHOOK_SECRET` value

## 6. Put the app online (5 min)

Phones only allow notifications and GPS for sites served over **https**.
The simplest option is **Netlify**:

1. Sign up at **netlify.com** and choose **Add new site → Deploy manually**.
2. Drag the site files (`index.html`, `config.js`, `sw.js`, `manifest.webmanifest`, the icons, `privacy.html`, `terms.html`, `support.html`). Do not upload a keystore or a secrets file. There is no secrets file in this repo.
3. You get an address like `https://petneighbor-123.netlify.app`. Use it in steps 3 and 4.

To update the app later, drag the folder in again on the site's **Deploys** page.

## 7. Try it with two phones

1. **iPhone:** open the address in **Safari**, tap **Share → Add to Home Screen**, then open 멍냥이웃 from the home screen icon. iOS 16.4 or newer is required for notifications.
   **Android:** open it in Chrome. Adding it to the home screen is optional.
2. Log in, set up your profile, then go to **Me → Message notifications → Turn on** and allow.
3. On a second phone or computer, log in with a different email. Make that account a caregiver: **Me → Become a caregiver**.
4. On the first phone, find that caregiver in **Find care** and tap **💬 Message**.
5. Lock the second phone and send a message. A notification should appear. Tapping it opens the chat.

## If something doesn't work

- **Login code email never arrives:** check spam. The built-in sender is rate limited, so wait a few minutes or set up SMTP (step 3).
- **"Couldn't log in":** check that the URL and key in `config.js` are right and that you ran `schema.sql`.
- **No notification:**
  - Check **Edge Functions → send-push → Logs**.
  - `403` means the webhook header doesn't match `WEBHOOK_SECRET`.
  - `sent: 0` means the other phone hasn't turned notifications on yet.
- **iPhone shows no "Turn on" button:** the app must be opened from the Home Screen icon, not from Safari.

## 8. Account deletion (required for the App Store)

1. **Edge Functions → Deploy a new function → Via editor**. Name it **`delete-account`**.
2. Paste `supabase/functions/delete-account/index.ts` and deploy.
3. Leave **Verify JWT ON** for this function. It deletes only the user in the bearer token. Profile, pets, chats, messages and push rows are removed by foreign keys.

In the app this is **내 정보 → 계정 → 계정 삭제**.

## 9. iOS and Android

Store builds, signing, native push (APNs and FCM), and the store listing text are in **LAUNCH.md**. Dragging the folder to Netlify is still the web path above.

## Before a public launch

- **Location data:** a neighborhood name is chosen by the member. GPS during a walk stays on the device in this version and is not uploaded. If a later version uploads location, confirm with a lawyer whether Korea's 위치정보법 requires registration as a 위치기반서비스사업자 with the Korea Communications Commission (방송통신위원회).
- **Terms and privacy:** `terms.html` and `privacy.html` describe this version. Have a lawyer review them before a public launch.
- **Email sender:** set up custom SMTP (step 3).
