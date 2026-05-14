// =============================================================================
// SUPABASE EDGE FUNCTION — send-push
// =============================================================================
// Fichier à déployer : supabase/functions/send-push/index.ts
// Commande : supabase functions deploy send-push --no-verify-jwt
//
// Cette fonction est appelée par un Database Webhook Supabase configuré sur
// la table `notifications` (event = INSERT). Elle :
//   1. Reçoit le payload de la notif insérée
//   2. Récupère toutes les push_subscriptions du destinataire (notif.user_id)
//   3. Envoie un push Web (Web Push Protocol + VAPID) à chaque device
//   4. Supprime les subscriptions expirées (HTTP 410)
//
// Variables d'environnement à set (Supabase Dashboard → Edge Functions → Secrets) :
//   VAPID_PUBLIC_KEY   = clé publique générée (collée aussi dans index.html)
//   VAPID_PRIVATE_KEY  = clé privée (jamais exposée au client)
//   VAPID_SUBJECT      = "mailto:chouaib.serir.pro@gmail.com" (ou URL https://noname.agency)
//   SUPABASE_URL       = injecté automatiquement
//   SUPABASE_SERVICE_ROLE_KEY = injecté automatiquement
// =============================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

// Configure VAPID (une fois au cold-start)
webpush.setVapidDetails(
  Deno.env.get('VAPID_SUBJECT') || 'mailto:noname@example.com',
  Deno.env.get('VAPID_PUBLIC_KEY')!,
  Deno.env.get('VAPID_PRIVATE_KEY')!
);

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

interface NotifRow {
  id: string;
  user_id: string;
  actor_id: string | null;
  type: string;
  message: string;
  link_table: string | null;
  link_id: string | null;
  is_read: boolean;
  created_at: string;
}

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  schema: string;
  record: NotifRow;
  old_record: NotifRow | null;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch (e) {
    return new Response('Invalid JSON', { status: 400 });
  }

  // On ne réagit qu'aux INSERT sur la table notifications
  if (payload.type !== 'INSERT' || payload.table !== 'notifications') {
    return new Response('Ignored', { status: 200 });
  }

  const notif = payload.record;

  // 1. Récupère les subscriptions du destinataire
  const { data: subs, error: subsErr } = await supabase
    .from('push_subscriptions')
    .select('id, endpoint, p256dh, auth_key')
    .eq('user_id', notif.user_id);

  if (subsErr) {
    console.error('[send-push] fetch subs error:', subsErr);
    return new Response('Subs fetch failed', { status: 500 });
  }
  if (!subs || subs.length === 0) {
    return new Response('No subscriptions for user', { status: 200 });
  }

  // 2. Construit le payload du push
  const title = titleForType(notif.type);
  const body = notif.message;
  const url = linkFor(notif);
  const pushPayload = JSON.stringify({
    title,
    body,
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: `notif-${notif.id}`,
    url,
    notifId: notif.id
  });

  // 3. Envoie en parallèle à chaque device
  const results = await Promise.allSettled(subs.map((s) =>
    webpush.sendNotification(
      { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth_key } },
      pushPayload,
      { TTL: 60 * 60 * 24 } // 24h de validité
    ).then(() => ({ ok: true, sub: s }))
      .catch((err) => ({ ok: false, sub: s, err }))
  ));

  // 4. Supprime les subs expirées (410 Gone) ou invalides
  const toDelete: string[] = [];
  for (const r of results) {
    if (r.status === 'fulfilled' && !r.value.ok) {
      const status = (r.value as any).err?.statusCode;
      if (status === 404 || status === 410) toDelete.push((r.value as any).sub.id);
    }
  }
  if (toDelete.length > 0) {
    await supabase.from('push_subscriptions').delete().in('id', toDelete);
    console.log(`[send-push] cleaned ${toDelete.length} expired subs`);
  }

  const sent = results.filter(r => r.status === 'fulfilled' && (r.value as any).ok).length;
  return new Response(JSON.stringify({ sent, total: subs.length }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  });
});

// ---- Helpers ---------------------------------------------------------------

function titleForType(type: string): string {
  switch (type) {
    case 'event_added':       return 'Nouvel événement';
    case 'event_updated':     return 'Événement mis à jour';
    case 'todo_urgent':       return 'Tâche urgente';
    case 'todo_added':        return 'Nouvelle tâche';
    case 'todo_completed':    return 'Tâche terminée';
    case 'todo_assigned':     return 'Tâche assignée';
    case 'inspiration_added': return 'Nouvelle inspiration';
    case 'track_added':       return 'Nouveau morceau';
    case 'track_released':    return 'Sortie programmée';
    case 'mention':           return 'Mention';
    default:                  return 'Noname';
  }
}

function linkFor(notif: NotifRow): string {
  switch (notif.link_table) {
    case 'events':       return '/?view=calendrier';
    case 'todos':        return '/?view=todos';
    case 'tracks':       return '/?view=catalogue';
    case 'inspirations': return '/?view=inspirations';
    case 'team_members': return '/?view=equipe';
    default:             return '/';
  }
}
