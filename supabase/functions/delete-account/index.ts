// delete-account: removes the signed-in auth user.
// Profile, pets, conversations, messages, read markers and push rows cascade.
// Deploy with Verify JWT ON. The function also checks the bearer token itself.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const url = Deno.env.get("SUPABASE_URL");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !service || !anon) return new Response("misconfigured", { status: 500 });

  const header = req.headers.get("Authorization") ?? "";
  if (!header.startsWith("Bearer ")) return new Response("unauthorized", { status: 401 });

  const userClient = createClient(url, anon, { global: { headers: { Authorization: header } } });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return new Response("unauthorized", { status: 401 });

  const admin = createClient(url, service);
  const { error: delError } = await admin.auth.admin.deleteUser(user.id);
  if (delError) {
    console.error("delete user", delError.code ?? "error");
    return new Response("delete failed", { status: 500 });
  }
  return new Response(JSON.stringify({ deleted: true }), {
    headers: { "content-type": "application/json" },
  });
});
