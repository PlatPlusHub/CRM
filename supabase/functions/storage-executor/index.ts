// WP-04-E -- the storage executor.
//
// WP-04-D established that the database cannot delete an object (`storage.protect_delete` refuses
// every SQL DELETE, and `pg_net` is not installed) and split the concern accordingly:
//
//     THE DATABASE OWNS THE DECISION.   THIS FUNCTION OWNS THE BYTES.
//
// This file is the second half. It decides NOTHING. Every question of whether an object may be
// destroyed -- retention configured, version still superseded, tenant not restricted -- is answered
// by `app.claim_storage_actions` before this code sees a row. That is deliberate: an executor that
// applied its own eligibility rules would be a second authorization system living outside the
// database, which canon 35 forbids and which is the reason WP-04-C rejected every non-Supabase
// object store.
//
// ------------------------------------------------------------------------------------------------
// WHY AN EDGE FUNCTION AND NOT AN n8n WORKFLOW -- decided on one property, as WP-04-C was.
//
//   The Supabase Edge runtime INJECTS `SUPABASE_SERVICE_ROLE_KEY` into this process itself. The
//   credential is never created by a human, never pasted anywhere, never stored in the repository,
//   never held in the database, and never passes through an agent. It cannot leak from a place it
//   was never put.
//
//   The n8n route requires the owner to create a Supabase service_role credential inside n8n by
//   hand (AGENTS.md §6: external credentials never pass through the agent). n8n's two existing
//   credentials are a `postgres` connection and a Google OAuth client -- neither can call the
//   Storage API, and the postgres one reaches a database that provably cannot delete objects. So
//   n8n would need a NEW long-lived platform-authority secret to exist in a second system, to do a
//   job the platform will hand its own runtime for free.
//
//   Rejected for the same reason: giving this function a direct Postgres connection instead of
//   PostgREST. That needs the database password -- another stored secret -- to reach functions the
//   service key already reaches.
//
// Cost, convenience and "n8n already exists" did not decide it. The number of new secrets did: one
// route needs zero, the other needs one that must live somewhere forever.
// ------------------------------------------------------------------------------------------------
//
// IDEMPOTENCY AND RETRY, and why there is no lease. The sequence is read -> delete -> report.
// Nothing is marked in flight, so a crash at any point leaves the finding exactly as it was and the
// next run retries it. Deleting an object that is already gone is a no-op at the Storage API, so the
// retry is safe. `app.claim_conversion_deliveries` needs a lease (PH8-1) precisely because it DOES
// mark rows in flight; copying that machinery here would introduce the stranding state the lease
// exists to escape.
//
// FAILURE STAYS DISCOVERABLE. A failed delete is reported as `failed`, which -- after FND-1, fixed
// in `202607055300` -- records an attempt and leaves the finding OPEN rather than resolving it.
// Nothing here can mark failed work as done, because this code cannot set `resolved_at` at all;
// only the database can, and it refuses to on `failed`.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET = "documents";

/**
 * Length-independent comparison. The caller's token is compared to the service key, and a naive
 * `===` on secrets leaks length and prefix through timing. Cheap to do correctly.
 */
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  let diff = ab.length ^ bb.length;
  const n = Math.max(ab.length, bb.length);
  for (let i = 0; i < n; i++) diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0);
  return diff === 0;
}

interface StorageAction {
  finding_id: string;
  tenant_id: string;
  storage_path: string;
  action_code: string;
  attempt_count: number;
}

Deno.serve(async (req: Request) => {
  // ----------------------------------------------------------------------------------------------
  // AUTHENTICATION. Edge Functions verify that SOME valid project JWT is present, and the anon key
  // is a valid project JWT -- so the platform's default check would let any visitor reach this. The
  // caller must present the service key itself.
  //
  // This function destroys customer documents. It is not a read endpoint with a permission check on
  // top; there is no caller identity it could usefully act on behalf of. Platform authority is the
  // only authority that makes sense here, exactly as `app.platform_*` functions are service_role
  // only inside the database. The two layers agree, which is the property SPEC-158 established.
  // ----------------------------------------------------------------------------------------------
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token || !safeEqual(token, SERVICE_ROLE_KEY)) {
    return new Response(JSON.stringify({ error: "forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // No path, tenant, bucket or finding id is ever read from the request body. This function takes
  // no input that could name an object -- the only object names it will ever see come back from
  // `claim_storage_actions`. That is what makes "never construct an object path from untrusted
  // caller input" structural rather than a rule someone has to remember.
  let limit = 50;
  try {
    const body = await req.json();
    if (typeof body?.limit === "number") limit = Math.max(1, Math.min(body.limit, 500));
  } catch {
    // No body is the normal case for a scheduled invocation.
  }

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: actions, error: claimError } = await db.rpc("claim_storage_actions", {
    p_limit: limit,
  });

  if (claimError) {
    return new Response(
      JSON.stringify({ error: "claim_failed", detail: claimError.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const summary = { claimed: (actions ?? []).length, deleted: 0, failed: 0, refused: 0 };
  const failures: Array<{ finding_id: string; reason: string }> = [];

  for (const action of (actions ?? []) as StorageAction[]) {
    // DEFENCE IN DEPTH, not distrust of the database. The path is system-derived
    // (`app.document_storage_path` = tenant/document/version) and the claim function already scopes
    // by tenant, so this can only fire on a database-side bug or a tampered row -- which is exactly
    // when an irreversible delete must not proceed. It is one string comparison against destroying
    // the wrong tenant's document.
    const prefix = action.storage_path.split("/")[0];
    if (prefix !== action.tenant_id) {
      summary.refused++;
      failures.push({ finding_id: action.finding_id, reason: "tenant prefix mismatch" });
      await db.rpc("resolve_storage_finding", {
        p_finding_id: action.finding_id,
        p_resolution_code: "failed",
        p_note: `refused: path prefix ${prefix} is not tenant ${action.tenant_id}`,
      });
      continue;
    }

    if (action.action_code !== "delete_object") {
      // An action code this build does not implement is a failure to report, never a no-op to
      // swallow. Swallowing it would leave the finding open with no attempt recorded and no reason,
      // which looks identical to "never picked up".
      summary.refused++;
      failures.push({ finding_id: action.finding_id, reason: `unknown action ${action.action_code}` });
      await db.rpc("resolve_storage_finding", {
        p_finding_id: action.finding_id,
        p_resolution_code: "failed",
        p_note: `unsupported action_code: ${action.action_code}`,
      });
      continue;
    }

    // THE SUPPORTED PATH. `storage.from(...).remove(...)` goes through the Storage service, which
    // deletes the S3 object AND its `storage.objects` row together. That is the operation
    // `storage.protect_delete` exists to insist upon; nothing here bypasses it.
    const { error: removeError } = await db.storage.from(BUCKET).remove([action.storage_path]);

    if (removeError) {
      summary.failed++;
      failures.push({ finding_id: action.finding_id, reason: removeError.message });
      await db.rpc("resolve_storage_finding", {
        p_finding_id: action.finding_id,
        p_resolution_code: "failed",
        p_note: removeError.message.slice(0, 500),
      });
      continue;
    }

    // Report success only AFTER the bytes are confirmed gone. This ordering is the whole contract:
    // the database removes the metadata that named the object only on the report that the object
    // itself no longer exists. Reporting first would leave an object no row names -- an orphan.
    const { error: resolveError } = await db.rpc("resolve_storage_finding", {
      p_finding_id: action.finding_id,
      p_resolution_code: "object_deleted",
      p_note: "destroyed by storage-executor",
    });

    if (resolveError) {
      // The bytes are gone and the database does not know. The finding stays open, so the next run
      // re-claims it, the delete is a harmless no-op, and the report is retried. Self-healing --
      // which is why the delete had to be the idempotent half of the pair.
      summary.failed++;
      failures.push({ finding_id: action.finding_id, reason: `resolve failed: ${resolveError.message}` });
      continue;
    }

    summary.deleted++;
  }

  return new Response(JSON.stringify({ ...summary, failures, ran_at: new Date().toISOString() }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
