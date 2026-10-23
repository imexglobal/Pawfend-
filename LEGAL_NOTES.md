# Legal notes for PetNeighbor (Pawfend)

**This is a draft for the operator, IMEX Global. It is not legal advice. A Korean lawyer must review the terms, the privacy policy, the location wording, and the product itself before public launch.** Do not treat this file, `terms.html`, or `privacy.html` as a finished opinion. The notes below are written in original wording for this app. They are not copied from another company’s terms.

Contact used in the drafts: IMEX Global, hellopawfend@gmail.com. Effective date used in the drafts: 2026-10-23. If the Korean and English texts ever differ, the Korean text governs.

Build 1.0 (1) already uploaded to App Store Connect does **not** contain the sign-up checkboxes, the consent rows, the report and block controls, or the first-booking acknowledgement. Those controls are in this branch and belong in the next binary.

---

## What a Korean lawyer should check before launch

1. **동물위탁관리업 registration.** The Animal Protection Act treats “위탁관리업” as a business that takes an owner’s animal and temporarily raises, trains, or protects it at a business premises, and that business must register with the local government. A neighbor who walks a dog, or who sits a pet in the owner’s home, may not be that business. IMEX Global does not itself keep animals. The draft tells caregivers who offer sitting or boarding **as a business** to hold any registration the law requires, and it says the platform does not check. Counsel should decide whether the operator must register, whether it must refuse caregivers who lack a registration, and whether occasional neighbor help is outside the statute.
2. **Insurance.** Nothing found in the research clearly forces a pure intermediary to buy pet-care liability insurance. Counsel should decide whether IMEX Global, caregivers, or both should carry insurance before real bookings go live, and whether the terms may mention insurance without implying that a policy exists.
3. **전자상거래법 article 20, before any payment exists.** The statute’s intermediary duties attach to a person who arranges a distance sale, including by letting people use a cybermall. This version does not take payment and does not hold money. Counsel should confirm whether article 20 already applies to a free introduction app. If it does, the home screen and the booking sheet now say IMEX Global is not a party. The app still does **not** collect the other party’s phone number, business-registration number, or mail-order report number. If caregivers are businesses, article 20(2) identity information has to be collected and shown before the consumer’s offer. If they are not businesses, the enforcement decree still expects a way for the two people to see each other’s name and phone. Add those fields before paid consumer bookings.
4. **The KRW 100,000 cap.** The draft limits ordinary-negligence damages to fees the member actually paid IMEX Global in the prior 12 months, or KRW 100,000 if they paid nothing. It does not cap intent or gross negligence (고의 또는 중과실). Counsel should decide whether that cap is a “상당한 이유” under article 7(2) of the Act on the Regulation of Terms and Conditions. If it is not, that sentence is void and the rest of the terms should still stand.
5. **Court venue.** The draft chooses Korean law and the Seoul Central District Court, and it yields where a mandatory consumer-venue rule gives the member their local court. Counsel should confirm that fallback is enough. An exclusive Seoul clause against a consumer who lives elsewhere is risky.
6. **Changes to the terms.** The product asks the member to check the box again when the version string changes. The draft does not treat silence as acceptance of a change that cuts the member’s rights or widens a waiver. The 7-day / 30-day notice periods come from a government shopping-mall Q&A, not from the terms statute itself. Counsel should confirm they are the right periods for a free intermediary, and whether an email plus an in-app checkbox is enough “individual notice.”
7. **Age without a date of birth.** Accounts require a declaration of age 14 or older (PIPA’s guardian-consent line). Offering care requires a separate declaration of age 19 or older (Civil Act majority). The app does not collect a birth date. Counsel should say whether a declaration is enough, and whether a minor’s paid booking must be blocked in software rather than only described as cancellable.
8. **Store age rating.** `LAUNCH.md` still tells the operator to answer **12+** on Apple and **Teen** on Google, because chat is free text. The in-app gate is stricter (14+). Counsel and the store questionnaires should be aligned. A 12+ listing with a 14+ gate is stricter than the listing, but the questionnaire sentence that used to say “under 13” is now wrong and has been updated.
9. **위치정보법.** In this version, GPS is read only after a walk or visit starts, the coordinates stay on that device, and they are not sent to IMEX Global or to the other member. Counsel should confirm that the operator is therefore not yet a location-based service business and does not yet have to file under article 9. The sign-up screen still asks for a separate location-terms consent, because the app can read device location. A later version that uploads or shares a trail needs a new consent, and it may need the article 9 filing **before** that feature is turned on. Do not add always-on location.
10. **Overseas transfer and Supabase.** The setup guide tells the operator to create the project in Northeast Asia (Seoul). The privacy policy does not promise that the live project is in Seoul. Supabase, Inc. is a United States company, so support access can be an overseas processing issue even if the database region is Seoul. The draft relies on PIPA article 28-8(1)(3) (necessary for the membership contract, with the transfer items published in the privacy policy) and does not add a third checkbox. Counsel should confirm that basis, or require a separate overseas-transfer consent. Counsel should also name the privacy officer. The drafts use “IMEX Global 대표” and hellopawfend@gmail.com because no personal name is in the repository.
11. **Report retention.** The privacy policy says user reports are deleted within one year. There is no scheduled job. The operator has to delete them. Consent rows are deleted with the account because the foreign key cascades. Counsel may prefer to keep consent records for a statutory period. Do not keep them unless there is a design that survives account deletion.
12. **Kakao login.** Email one-time codes are the primary sign-in. Kakao inside the native web view still needs a URL scheme before it is a reliable path. Do not describe Kakao as required.
13. **Misleading UI that this branch removes.** Demo profiles used to show a “인증 / Verified” badge. The product does not do a background check, so the badge is no longer rendered. The booking sheet used to say the app holds payment until care is finished. It does not. Both sentences were false and would have undermined the “no vetting” and “no payment” terms.
14. **Have the lawyer read the Korean terms before they are shown to the public.** Publishing `terms.html` as binding terms without that review is the operator’s decision, not this draft’s recommendation.

---

## How the draft is built

The terms try to protect IMEX Global as far as the statutes below allow, and they give back what those statutes will not let a business waive. In particular, every limitation says it does not apply to the company’s own intent or gross negligence. A clause that waives that liability is void, so leaving it in would weaken the rest of the document.

The product facts the draft depends on:

- IMEX Global provides software that lets members publish a profile, list care they offer, and message each other. It is not the caregiver and it is not a party to the care arrangement.
- Caregivers are independent. The app does not employ them, train them, or set their prices.
- This version does not take payment and does not hold funds. Any money is arranged between the two members.
- The app does not verify identity, licenses, animal-care registration, insurance, criminal record, or health.
- Example profiles shipped with the demo are not real members.
- Community posts, places, care requests, applications, bookings, reviews, and walk logs are stored on the device in this version. Accounts, profiles, pets, services, chat, push tokens, consent rows, booking acknowledgements, blocks, and reports are what a configured Supabase project stores.
- Walk GPS is requested only after the member starts a walk or visit. Coordinates are not uploaded in this version.
- There is no advertising SDK and no sale of personal information.

---

## Research

### 1. Act on the Regulation of Terms and Conditions (약관의 규제에 관한 법률)

Source: Korea Ministry of Government Legislation, statute text, Act No. 20239, effective 7 August 2024. https://www.law.go.kr/법령/약관의규제에관한법률

What the draft takes from it, in summary:

- A business must disclose important terms and explain them. The sign-up screen uses unchecked boxes and links, not a “by continuing you agree” line.
- A clause is void if it violates good faith and is unfair. Unfairness is presumed when a clause is unduly unfavorable, when the customer would not expect it, or when it restricts an essential right so the contract’s purpose fails.
- A clause is void if it excludes liability of the business, its agent, or its employee for **intent or gross negligence**.
- A clause that limits damages, or that shifts risk onto the customer, is void unless there is a substantial reason.
- A clause that unreasonably takes away the customer’s right to sue, or that shifts the burden of proof, is void. That is why the venue clause yields to a mandatory consumer forum.
- If one clause is void, the rest remains, unless what remains cannot achieve the contract’s purpose or is unduly one-sided. The draft says that expressly.
- The statute does not itself set a 7-day or 30-day notice period.

The 7-day notice, and 30 days when the change is unfavorable, is the period described in a government easylaw answer about shopping-mall terms: https://www.easylaw.go.kr/CSP/OnhunqueansInfoRetrieve.laf?onhunqnaAstSeq=91&onhunqueSeq=6646 (retrieved for this draft). The app uses those periods because the operator asked for them. The lawyer should confirm they fit this service. For an unfavorable change, the app also requires a new checkbox. Silence is not acceptance of a new waiver.

### 2. Act on Consumer Protection in Electronic Commerce (전자상거래법)

Source: statute text, Act No. 21312, effective 21 July 2026. https://www.law.go.kr/법령/전자상거래등에서의소비자보호에관한법률

What the draft takes from it:

- A mail-order **intermediary** (통신판매중개) includes a person who arranges a distance transaction, including by letting people use an online marketplace.
- The mail-order **business report** (통신판매업 신고) sits on the seller, not automatically on a pure intermediary. The Korea Fair Trade Commission has described that distinction on the consumer portal: https://www.consumer.go.kr/user/bbs/consumer/380/940/bbsDataView/3582.do
- Before the transaction, the intermediary must say, in the way the enforcement rule specifies, that it is not a party to the sale. The enforcement rule (시행규칙 제11조의2, confirm the current numbering) expects that notice on the marketplace’s first screen and again at the order-confirmation step when the intermediary provides the ordering method. The home screen and the booking sheet carry that notice. There is no in-app payment step in this version.
- If the seller is a business, the intermediary must check and show identity information before the consumer’s offer. If the seller is not a business, the parties still need a way to see the counterpart’s name and phone. **This app does not collect those fields yet.** See the lawyer list above.
- If the “not a party” notice is missing, the intermediary can be jointly liable for the seller’s intent or negligence. If identity information is missing or false, joint liability follows unless the intermediary used reasonable care. The notices are there so that this consequence is not triggered by silence. They are not a guarantee that article 20 already applies before payment exists.
- The intermediary must have a way to receive complaints, publish how disputes are handled, tell the consumer the progress within 3 business days, and tell them the result or the plan within 10 business days. The terms state those clocks for complaints **about the platform**. A dispute about the pet, the price, or the quality of care stays between the two members. The operator may pass a report along. It does not decide that dispute.

### 3. Personal Information Protection Act (개인정보 보호법)

Source: statute text, Act No. 21445, effective 11 September 2026, and the earlier amended text under Act No. 20897. https://www.law.go.kr/법령/개인정보보호법

What the privacy policy is built to cover:

- A child under 14 needs a guardian’s consent. The account floor is therefore 14, not 13. The app does not offer a guardian-consent flow, so people under 14 may not sign up.
- Personal information is destroyed when the purpose is finished. The policy states retention in plain periods. Account data, including consent rows, ends when the account is deleted. Reports are kept up to one year and then must be deleted by the operator. There is no deletion cron.
- The member can ask for access, correction, deletion, and suspension, and can withdraw consent. The practical path in the app is Me → Account → Delete account, or an email to hellopawfend@gmail.com. The policy also names the Personal Information Protection Commission (privacy.go.kr) and the Personal Information Dispute Mediation Committee.
- A privacy officer is required. Below the decree’s size threshold, the representative is the officer. The policy names the representative of IMEX Global at hellopawfend@gmail.com and leaves the legal name for counsel to insert.
- Overseas transfer is prohibited unless one of the statutory grounds applies. The grounds include a separate consent that states the items, the country and the method and the time, the recipient’s name and contact, the purpose and retention, and how to refuse and what refusal means. Another ground is that the transfer is necessary to perform the contract **and** those items are in the privacy policy (or are otherwise notified). The enforcement decree expects the transfer basis to appear in the privacy policy. A contract with a processor cannot waive the Act.
- This draft uses the contract ground (article 28-8(1)(3)) for Supabase, Apple, and Google push, and it prints the items in the policy. It does not add a third sign-up checkbox. Counsel may still want a separate consent, especially if the Supabase region is not in Korea.
- “Neighborhood” is a district name the member picks from a list. It is not GPS. Precise location is not a category the server collects in this version.

### 4. Location Information Act (위치정보의 보호 및 이용 등에 관한 법률)

Source: https://www.law.go.kr/법령/위치정보의보호및이용등에관한법률

What the draft takes from it:

- A location-based service business that handles **personal location information** must file with the Korea Communications Commission (방송미디어통신위원회) before starting: name, office, type of business, and a description of the location system. A service that does not aim at personal location information is outside that duty.
- Before using personal location information, the terms must state the operator’s contact, the person’s rights, what the service does, how long use and provision records are kept and why, and how long the location information itself is kept and why. If location is given to a third party the person named, notice of the recipient, the time, and the purpose is required each time, or in a batch of up to 30 days if the person agreed.
- Location terms are published on the first screen or a screen linked from it. A business that is actually a location-based service business files the terms 30 days before starting and 10 days before a change (the filing portal referenced in public guidance is emsit.go.kr). Confirm the current portal with counsel.
- Under 14, location use needs a guardian. This app does not take accounts under 14, and it does not upload location.
- Because this version never sends coordinates to the operator or the other member, the draft’s position is that IMEX Global is not yet handling personal location information as a location-based service business. The separate consent is still collected, and the location section of the terms says what the device does, that refusal of the **phone permission** leaves the rest of the app usable, and that a future sharing feature needs a new consent and possibly the filing first.

### 5. Animal Protection Act (동물보호법), as it touches pet sitting

Source: https://www.law.go.kr/법령/동물보호법 and the enforcement rule https://www.law.go.kr/법령/동물보호법시행규칙

Article 73(1) and enforcement rule article 42(2) describe 동물위탁관리업 as a business that takes an owner’s animal and temporarily raises, trains, or protects it at a business premises. Registration is with the local mayor or district office. The government24 civil-petition number published for that registration is 15430000204 (fee 10,000 won, processing on the order of 15 days, as published on the petition page). Facility and staff standards are in the rule’s attached tables (별표 11 for standards, 별표 12 for compliance rules). Education under article 82 is published as 3 hours within the year before registration and then annually, through the animal-protection education system (apms.epis.or.kr). The Ministry of Agriculture, Food and Rural Affairs pet-industry line published for this topic is 044-201-2661 (반려산업동물의료팀). Confirm every one of these operational details before telling a caregiver to rely on them. They change.

A walk or a home sit by a neighbor is not automatically “영업,” and it is not automatically care at a business premises. The platform does not keep the animal. The draft therefore does not say IMEX Global is the registrant. It does say a caregiver who offers sitting or boarding as a business must hold whatever registration applies, and that the app does not verify it. That is a risk allocation, not a legal conclusion. See item 1 in the lawyer list.

### 6. Civil Act age (민법)

Source: https://www.law.go.kr/법령/민법

Majority is 19 (article 4). A minor’s contract can be cancelled (article 5). The draft uses 14 for an account, because that is the PIPA line and the app has no guardian flow, and 19 for offering care, because a paid care contract by a minor is cancellable. People under 19 are told not to offer care. A booking made by someone under 19 may be cancelled by that person or their guardian. The app does not collect a birth date.

### 7. Apple App Store, Guideline 1.2 (user-generated content)

Sources: App Store Review Guidelines, section 1.2, as updated in the 16 October 2026 revision. https://developer.apple.com/app-store/review/guidelines/ and the update notes https://developer.apple.com/news/?id=92th7e5i and https://developer.apple.com/news/?id=vvzx6cul

Guideline 1.2 requires an app with user-generated content to:

- filter objectionable material,
- provide a way to report offensive content and to respond in a timely way,
- let people block abusive users,
- publish contact information.

The developer must also remove violating content after notice and act on non-consensual intimate imagery. Review practice has long expected a published EULA with a zero-tolerance rule and a response on the order of 24 hours (remove the content and eject the user who provided it). The current guideline text says “timely” rather than a fixed number of hours. The terms still promise review of a user-content report within 24 hours, because reviewers look for that commitment. Separately, the e-commerce clocks of 3 and 10 business days apply to complaints about the platform, not as a substitute for the 24-hour content review.

This branch adds report and block on profiles, chats, and posts, a blocked-user list with unblock, a server-side block that rejects new messages between a blocked pair, and a small on-device filter for clear threats, sexual-service offers, sexual content involving a minor, and animal abuse. That filter is not a claim of complete moderation. The server checks message length. It does not keyword-filter message bodies. A human still has to read reports.

### 8. Google Play user-generated content

Sources: Google Play Developer Program Policy on user-generated content. https://support.google.com/googleplay/android-developer/answer/9876937 and the policy center linked from that page.

Play expects the app to:

- require acceptance of terms that define and prohibit objectionable content and behavior before the user creates or uploads that content,
- offer an in-app way to report content and users,
- offer a way to block users in one-to-one interaction and in public content,
- act on reports,
- and not monetize in a way that encourages objectionable behavior.

The policy also requires sexually explicit content that is incidental to be hidden by default, or removed from the app. This app prohibits sexual content instead of hosting it. There is no payment, so there is no monetization of that content.

The sign-up checkboxes are how the terms are accepted before an account, and therefore before chat, exists. Demo mode has no account. Report, block, and the first-booking acknowledgement still exist in the demo so the controls can be tested, and so a store reviewer who opens the demo can find them on a profile.

### 9. How pet-care marketplaces usually allocate risk

This is a description of a common structure, written for this project. It is not a quotation from Rover, Wag, or any other company, and it must not be turned into one.

Operators of pet-care marketplaces typically say all of the following, and the draft does the same in its own words:

- The operator runs a venue. The care contract is between the pet owner and the caregiver.
- The caregiver is an independent person, not an employee or agent of the operator.
- The operator does not guarantee identity, a license, insurance, or the quality of care, even if it offers optional badges or optional checks. This app offers neither, and it no longer shows a verified badge.
- The owner and the caregiver accept the risk that an animal may be injured, become ill, escape, or damage property.
- A dispute about the booking is between those two people. The operator may remove content and may suspend an account. It does not sit as the judge of the care dispute.
- The operator’s own liability for its own intent or gross negligence is left in place, because Korean terms law voids a clause that removes it. Marketplaces in other countries often use a broader waiver. Copying that broader waiver into a Korean terms document would create a void clause.

---

## What the app now records

| Event | Where | Version |
| --- | --- | --- |
| Terms, privacy policy, and location terms, plus a declaration of age 14+ | `legal_consents` | `2026-10-23` |
| Declaration of age 19+ before caregiver services are saved | a later `legal_consents` row with `caregiver_age_19` | same |
| First booking, care request, or application | `booking_acknowledgements` | terms version |
| Block | `user_blocks`, and on the device | — |
| Report | `user_reports` when the reported person is a real account, and on the device | — |

The version constant lives in `index.html` as `LEGAL`. Bump it when the text changes, or existing members will not be asked again.

Fresh databases get the tables from the bottom of `supabase/schema.sql`. A database that already ran an older `schema.sql` needs `supabase/legal.sql` as well. See `SETUP.md`.
