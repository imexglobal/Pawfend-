// send-push: phone notification when a new chat message is saved.
// Called by a Database Webhook on INSERT into public.messages.
// Turn Verify JWT OFF. This function checks WEBHOOK_SECRET itself.
//
// Secrets (Edge Functions → Secrets):
//   WEBHOOK_SECRET          required
//   VAPID_PUBLIC_KEY        web push
//   VAPID_PRIVATE_KEY       web push
//   VAPID_SUBJECT           mailto: address, e.g. mailto:hellopawfend@gmail.com
//   APNS_KEY_ID             iOS native push (Apple key id)
//   APNS_TEAM_ID            iOS native push (Apple team id)
//   APNS_KEY                iOS native push (contents of the AuthKey .p8 file)
//   APNS_BUNDLE_ID          defaults to com.imexglobalintl.petneighbor
//   FCM_SERVICE_ACCOUNT     Android native push (Firebase service-account JSON)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const MAX_BODY = 100_000;
const MAX_AGE_MS = 5 * 60 * 1000;
const BUNDLE = "com.imexglobalintl.petneighbor";

let vapidReady = false;
let apnsCache: { jwt: string; exp: number } | null = null;
let fcmCache: { token: string; project: string; exp: number } | null = null;

function b64url(data: string | ArrayBuffer | Uint8Array): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function pemToBuf(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const raw = atob(b64);
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}

function safeEqual(a: string, b: string): boolean {
  const aa = new TextEncoder().encode(a);
  const bb = new TextEncoder().encode(b);
  const n = Math.max(aa.length, bb.length);
  let v = aa.length ^ bb.length;
  for (let i = 0; i < n; i++) v |= (aa[i] ?? 0) ^ (bb[i] ?? 0);
  return v === 0;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function ensureVapid(): boolean {
  if (vapidReady) return true;
  const subject = Deno.env.get("VAPID_SUBJECT");
  const pub = Deno.env.get("VAPID_PUBLIC_KEY");
  const priv = Deno.env.get("VAPID_PRIVATE_KEY");
  if (!subject || !pub || !priv) return false;
  webpush.setVapidDetails(subject, pub, priv);
  vapidReady = true;
  return true;
}

async function apnsJwt(): Promise<string | null> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const pem = Deno.env.get("APNS_KEY");
  if (!keyId || !teamId || !pem) return null;
  const now = Math.floor(Date.now() / 1000);
  if (apnsCache && apnsCache.exp > now + 60) return apnsCache.jwt;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBuf(pem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = b64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const payload = b64url(JSON.stringify({ iss: teamId, iat: now }));
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  );
  const jwt = `${header}.${payload}.${b64url(sig)}`;
  apnsCache = { jwt, exp: now + 50 * 60 };
  return jwt;
}

async function fcmAccess(): Promise<{ token: string; project: string } | null> {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) return null;
  const now = Math.floor(Date.now() / 1000);
  if (fcmCache && fcmCache.exp > now + 60) return fcmCache;
  const sa = JSON.parse(raw) as { client_email: string; private_key: string; project_id: string };
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBuf(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  );
  const assertion = `${header}.${payload}.${b64url(sig)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    console.error("fcm oauth", res.status);
    return null;
  }
  const body = await res.json() as { access_token?: string };
  if (!body.access_token) return null;
  fcmCache = { token: body.access_token, project: sa.project_id, exp: now + 50 * 60 };
  return fcmCache;
}

type Device = { endpoint: string; p256dh: string; auth: string; platform: string };

async function forget(admin: any, endpoint: string) {
  await admin.from("push_subscriptions").delete().eq("endpoint", endpoint);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const secret = Deno.env.get("WEBHOOK_SECRET") ?? "";
  const given = req.headers.get("x-webhook-secret") ?? "";
  if (!secret || !safeEqual(given, secret)) return new Response("forbidden", { status: 403 });

  const len = Number(req.headers.get("content-length") || 0);
  if (len > MAX_BODY) return new Response("too large", { status: 413 });

  let record: { id?: number | string } | undefined;
  try {
    const body = await req.json();
    record = body?.record;
  } catch {
    return new Response("bad json", { status: 400 });
  }
  if (record?.id == null || record.id === "") return new Response("no record", { status: 400 });

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return new Response("misconfigured", { status: 500 });
  const admin = createClient(url, key);

  // Re-read the message. The webhook body is not trusted.
  const { data: msg, error } = await admin.from("messages")
    .select("id, body, sender_id, conversation_id, created_at, conversations(user_a, user_b), profiles(name)")
    .eq("id", record.id)
    .single();
  if (error || !msg) {
    console.error("message lookup", error?.code ?? "missing");
    return new Response("message not found", { status: 404 });
  }

  const age = Date.now() - new Date(msg.created_at).getTime();
  if (!Number.isFinite(age) || age > MAX_AGE_MS || age < -60_000) {
    return json({ sent: 0, skipped: "stale" });
  }

  const convRaw = msg.conversations as { user_a: string; user_b: string } | { user_a: string; user_b: string }[] | null;
  const conv = Array.isArray(convRaw) ? convRaw[0] : convRaw;
  if (!conv?.user_a || !conv?.user_b) return new Response("no conversation", { status: 422 });
  const recipient = conv.user_a === msg.sender_id ? conv.user_b : conv.user_a;
  const profileRaw = msg.profiles as { name: string } | { name: string }[] | null;
  const profile = Array.isArray(profileRaw) ? profileRaw[0] : profileRaw;
  const senderName = profile?.name || "멍냥이웃";
  const text = String(msg.body ?? "");
  const preview = text.length > 120 ? text.slice(0, 117) + "…" : text;
  const chatUrl = `#chat=${msg.sender_id}`;

  const { data: devices, error: devErr } = await admin.from("push_subscriptions")
    .select("endpoint, p256dh, auth, platform")
    .eq("user_id", recipient);
  if (devErr) {
    console.error("devices", devErr.code);
    return new Response("devices", { status: 500 });
  }

  let sent = 0;
  await Promise.all((devices as Device[] | null ?? []).map(async (d) => {
    try {
      const platform = d.platform || "web";
      if (platform === "ios") {
        const jwt = await apnsJwt();
        if (!jwt) return;
        const res = await fetch(`https://api.push.apple.com/3/device/${encodeURIComponent(d.endpoint)}`, {
          method: "POST",
          headers: {
            authorization: `bearer ${jwt}`,
            "apns-topic": Deno.env.get("APNS_BUNDLE_ID") || BUNDLE,
            "apns-push-type": "alert",
            "apns-priority": "10",
          },
          body: JSON.stringify({
            aps: { alert: { title: senderName, body: preview }, sound: "default" },
            url: chatUrl,
            tag: `chat-${msg.conversation_id}`,
          }),
        });
        if (res.status === 410 || res.status === 400) await forget(admin, d.endpoint);
        else if (!res.ok) console.error("apns", res.status);
        else sent++;
        return;
      }
      if (platform === "android") {
        const fcm = await fcmAccess();
        if (!fcm) return;
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${fcm.project}/messages:send`, {
          method: "POST",
          headers: { authorization: `Bearer ${fcm.token}`, "content-type": "application/json" },
          body: JSON.stringify({
            message: {
              token: d.endpoint,
              notification: { title: senderName, body: preview },
              data: { url: chatUrl, tag: `chat-${msg.conversation_id}` },
              android: { priority: "HIGH" },
            },
          }),
        });
        if (res.status === 404 || res.status === 400) await forget(admin, d.endpoint);
        else if (!res.ok) console.error("fcm", res.status);
        else sent++;
        return;
      }
      if (!ensureVapid()) return;
      const payload = JSON.stringify({
        title: senderName,
        body: preview,
        tag: `chat-${msg.conversation_id}`,
        url: `./${chatUrl}`,
      });
      await webpush.sendNotification(
        { endpoint: d.endpoint, keys: { p256dh: d.p256dh, auth: d.auth } },
        payload,
        { TTL: 3600 },
      );
      sent++;
    } catch (err) {
      const status = (err as { statusCode?: number }).statusCode;
      if (status === 404 || status === 410) await forget(admin, d.endpoint);
      else console.error("push failed", status ?? "error");
    }
  }));

  return json({ sent });
});
