# Launching PetNeighbor

App id: `com.imexglobalintl.petneighbor`  
Display name: **PetNeighbor**  
Publisher: **IMEX Global**  
Support: hellopawfend@gmail.com

The iOS team id `6388ACWLTQ` is already set on the Xcode target with automatic signing. You still need the accounts and keys below. This repository does not contain them.

## What you have to create

1. A **Supabase** project (free tier is enough to start). Steps are in `SETUP.md`. Run the current `supabase/schema.sql`. It is not the same file as the first import: pet notes are owner-only, push rows have a platform, and chat timestamps cannot be forged.
2. An **Apple Developer** membership for team `6388ACWLTQ`, so Xcode can sign and App Store Connect will accept the upload.
3. A **Google Play Console** developer account (one-time registration fee). The debug APK in this repo is not what you upload.
4. A new **VAPID** key pair. The public key in `config.js` has no private key here. See SETUP.md step 5.
5. For **native push** (the App Store and Play apps do not use browser push):
   - Apple: an APNs Auth Key (`.p8`), its Key ID, and team id `6388ACWLTQ`.
   - Google: a Firebase project, an Android app with this package id, `google-services.json` in `android/app/`, and a Firebase service-account JSON.
   - Put the secrets on the `send-push` function (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY`, `APNS_BUNDLE_ID`, `FCM_SERVICE_ACCOUNT`). Until they exist, web push can still work and native tokens are stored but not delivered.

You do not commit: the service-role key, the VAPID private key, the APNs `.p8`, the Firebase service account, `google-services.json` if it contains more than the client config you are comfortable publishing, or the Android release keystore.

## Web build and Capacitor sync

From the repo root, with Node 22:

```bash
npm install
npm run icons
npm run build
npx cap sync
```

`npm run build` copies the site into `www/`. `www/` is gitignored. Run the build before every sync, archive, or bundle.

Open the site locally with any static server (for example `npx serve .`) and open `index.html`. With an empty `config.js` it is the demo.

## iOS archive and upload

On a Mac, after `npx cap sync`. Capacitor 8 uses Swift Package Manager (`ios/App/CapApp-SPM`). There is no CocoaPods workspace and no `pod install` step. Archive the Xcode project:

```bash
cd ios/App
xcodebuild -project App.xcodeproj -scheme App -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/App.xcarchive" \
  archive \
  DEVELOPMENT_TEAM=6388ACWLTQ \
  CODE_SIGN_STYLE=Automatic
```

`ExportOptions.plist` is in `ios/App/`. Upload needs an App Store Connect API key (Users and Access → Integrations → App Store Connect API):

```bash
xcodebuild -exportArchive \
  -archivePath "$PWD/build/App.xcarchive" \
  -exportPath "$PWD/build/export" \
  -exportOptionsPlist ExportOptions.plist

xcrun altool --upload-app --type ios \
  -f "$PWD/build/export/App.ipa" \
  --apiKey "YOUR_KEY_ID" \
  --apiIssuer "YOUR_ISSUER_UUID"
```

The `.p8` for that API key must be in `~/.appstoreconnect/private_keys/AuthKey_YOUR_KEY_ID.p8`, or pass `--p8-file-path`. Transporter.app can upload the same IPA.

The target requests only **location when in use**, and only after a walk or visit is started. Push uses the `aps-environment` entitlement (`development` on Debug, `production` on Release). There is no camera, photo, microphone, contacts, tracking, or always-on location string.

In App Store Connect, set the account-deletion URL to the in-app path as well: the app deletes the account under Me → Account → Delete account. That calls the `delete-account` edge function.

## Android release AAB and signing

Debug (no keystore):

```bash
export ANDROID_HOME="$HOME/android-sdk"   # or your SDK path
npm run cap:sync
cd android && ./gradlew assembleDebug
```

The debug APK is `android/app/build/outputs/apk/debug/app-debug.apk`.

Release keystore, **outside git** (the filename below is gitignored if you keep it in the repo root; do not `git add` it):

```bash
keytool -genkeypair -v \
  -keystore petneighbor-release.keystore \
  -alias petneighbor \
  -keyalg RSA -keysize 2048 -validity 10000
```

Answer the prompts with IMEX Global as the organization. Store the keystore and both passwords somewhere you can still find in five years. Losing them means you cannot update the Play listing.

```bash
cp keystore.properties.example android/keystore.properties
```

Edit `android/keystore.properties` so `storeFile` points at the keystore, and fill the passwords. That file is gitignored.

```bash
cd android && ./gradlew bundleRelease
```

The bundle is `android/app/build/outputs/bundle/release/app-release.aab`. Upload it in Play Console → Production or an internal testing track.

Before the release build, put `google-services.json` from Firebase into `android/app/` or native Android notifications will not register.

## Store listing

Use the same facts on both stores. Category: **Lifestyle**. Age: **12+** on Apple and **Teen** on Google, because members can send each other unrestricted text. There is no payment, no advertising, and no unrestricted web browser.

### Name

PetNeighbor

### Subtitle (Apple, 30 characters)

Neighborhood pet care

Korean localization subtitle: `동네 반려동물 돌봄`

### Short description (Google, 80 characters)

Pet care with neighbors: profiles, pets, and chat.

Korean: `동네 이웃과 반려동물 돌봄. 프로필, 우리 아이, 채팅.`

### Description

```
PetNeighbor (멍냥이웃) helps neighbors care for each other's pets.

With an account you can:
• Create a profile with your name, a neighborhood you pick, and a short bio
• List the services you offer and your prices
• Add your pets (name, species, breed, age, and private notes)
• Message another member and get a notification when they reply

Community posts, place recommendations, care requests, bookings, reviews, and walk maps are saved on your phone in this version. People marked "Example" are samples, not real members.

PetNeighbor does not take payment. It does not read your contacts, camera, microphone, or photos.

Delete your account any time under Me → Account → Delete account. That removes your profile, pets, and chats.

Published by IMEX Global.
Questions: hellopawfend@gmail.com
Privacy: the in-app Privacy Policy.
```

Korean description:

```
멍냥이웃 PetNeighbor는 동네 이웃끼리 반려동물 돌봄을 주고받는 앱입니다.

계정을 만들면 다음을 할 수 있습니다.
• 이름, 직접 고른 동네, 짧은 소개가 있는 프로필
• 제공할 돌봄과 가격
• 반려동물 등록 (이름, 종류, 품종, 나이, 본인만 보는 특이사항)
• 다른 회원과 채팅, 답장이 오면 알림

커뮤니티 글, 추천 장소, 돌봄 요청, 예약, 후기, 산책 지도는 이 버전에서 휴대폰 안에만 저장됩니다. "예시"라고 표시된 사람은 실제 회원이 아닙니다.

결제는 없습니다. 연락처, 카메라, 마이크, 사진은 보지 않습니다.

계정은 내 정보 → 계정 → 계정 삭제에서 바로 지울 수 있습니다. 프로필, 반려동물, 대화가 함께 삭제됩니다.

게시자 IMEX Global.
문의 hellopawfend@gmail.com
```

### Keywords (Apple, 100 characters)

```
pet,dog,cat,walk,sitter,neighbor,care,chat,반려동물,산책,펫시터
```

### Apple age-rating answers

- Cartoon or fantasy violence, realistic violence, sexual content, nudity, horror, alcohol, tobacco, gambling, contests: **None**
- Profanity or crude humor: **None** from the developer. Members can type freely in chat.
- Mature/suggestive themes, horror: **None**
- Medical/treatment: **None** (pet notes are not a medical service)
- Unrestricted web access: **No**
- User-generated content: **Yes** (chat). Messaging between users: **Yes**
- Age assurance / parental controls: none built in. The terms say under 13 may not sign up.
- Result to select: **12+**

### Apple privacy nutrition labels

Data is linked to the user’s identity. It is not used for tracking. It is not used for third-party advertising.

| Data type | Collected | Notes |
| --- | --- | --- |
| Email address | Yes | Email login. Kakao email only if they consent and the Kakao app is a business app. |
| Name | Yes | Display name. |
| User ID | Yes | Account UUID. |
| Other user content | Yes | Bio, pet name/breed/age, pet notes (notes visible only to the owner), chat messages. |
| Device ID | Yes | Web-push endpoint or native push token. |
| Precise location | No | GPS is used on the device during an active walk and is not uploaded. |
| Coarse location | No | The neighborhood is a name the member picks, not a coordinate. |
| Photos, contacts, audio, purchases, health, financial, browsing, search history, diagnostics | No | |

### Google Play data safety

- Data is collected and encrypted in transit.
- Users can request deletion in the app (Me → Account → Delete account) or by email to hellopawfend@gmail.com.
- Data is not sold.
- Shared with service providers only to run the app: Supabase (account, database, functions) and Apple/Google push (message preview up to 120 characters, so the phone can show it).
- Collected: name, email address, user-generated messages and profile text, app-generated user id, device push token.
- Not collected: precise or approximate GPS, photos, videos, audio, contacts, calendar, files, financial info, health info, web browsing, crash logs, advertising id.

### Permission declarations

- iOS location when in use: shown only when a walk or visit starts. Purpose string is in `Info.plist`.
- Android location (fine and coarse) and notifications (`POST_NOTIFICATIONS`).
- No background location.

## After the first upload

1. Paste the Supabase URL and anon key into `config.js`, then `npm run build && npx cap sync`, and archive again. An empty `config.js` ships a demo.
2. Deploy `send-push` (Verify JWT **off**) and `delete-account` (Verify JWT **on**).
3. Create the database webhook described in SETUP.md.
4. In App Store Connect and Play Console, set the privacy policy URL to the hosted `privacy.html` and the support URL to `support.html` (or a page that shows hellopawfend@gmail.com).
