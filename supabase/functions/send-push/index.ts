// send-push: sends a phone notification when a new chat message is saved.
// Called by a Database Webhook on INSERT into public.messages.
// Secrets to set (Edge Functions → Secrets): VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT, WEBHOOK_SECRET.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase automatically.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
webpush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT")!,
  Deno.env.get("VAPID_PUBLIC_KEY")!,
  Deno.env.get("VAPID_PRIVATE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("WEBHOOK_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const { record } = await req.json();
  if (!record?.id) return new Response("no record", { status: 400 });

  // Re-read the message instead of trusting the request body.
  const { data: msg } = await admin.from("messages")
    .select("id, body, sender_id, conversation_id, conversations(user_a, user_b), profiles(name)")
    .eq("id", record.id).single();
  if (!msg) return new Response("message not found", { status: 404 });

  const conv = msg.conversations as { user_a: string; user_b: string };
  const recipient = conv.user_a === msg.sender_id ? conv.user_b : conv.user_a;
  const senderName = (msg.profiles as { name: string } | null)?.name ?? "멍냥이웃";

  const { data: devices } = await admin.from("push_subscriptions")
    .select("endpoint, p256dh, auth").eq("user_id", recipient);

  const payload = JSON.stringify({
    title: senderName,
    body: msg.body.length > 120 ? msg.body.slice(0, 117) + "…" : msg.body,
    tag: `chat-${msg.conversation_id}`,
    url: `./#chat=${msg.sender_id}`,
  });

  let sent = 0;
  await Promise.all((devices ?? []).map(async (d) => {
    try {
      await webpush.sendNotification({ endpoint: d.endpoint, keys: { p256dh: d.p256dh, auth: d.auth } }, payload, { TTL: 3600 });
      sent++;
    } catch (err) {
      // 404/410: the phone unsubscribed or the app was removed, so forget the device.
      const status = (err as { statusCode?: number }).statusCode;
      if (status === 404 || status === 410) await admin.from("push_subscriptions").delete().eq("endpoint", d.endpoint);
      else console.error("push failed", status, err);
    }
  }));

  return new Response(JSON.stringify({ sent }), { headers: { "Content-Type": "application/json" } });
});
