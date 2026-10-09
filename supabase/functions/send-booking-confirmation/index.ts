import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
// Remplacé par le nom du secret que vous venez de définir dans le terminal
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY");

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record;

    // Déclenche l'envoi uniquement si le statut est "accepted" ou "confirmed"
    if (record && (record.status === "accepted" || record.status === "confirmed")) {
      let email = record.email || record.customer_email;
      let name = record.name || record.customer_name || "Client";

      // Si pas d'email direct, recherche via user_id dans auth.users
      if (!email && record.user_id && SUPABASE_URL && SERVICE_ROLE_KEY) {
        const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
        const { data: userData, error: userError } = await supabaseAdmin.auth.admin.getUserById(record.user_id);
        
        if (!userError && userData?.user) {
          email = userData.user.email;
          name = userData.user.user_metadata?.full_name || userData.user.user_metadata?.name || name;
        }
      }

      if (email) {
        const response = await fetch("https://api.brevo.com/v3/smtp/email", {
          method: "POST",
          headers: {
            "accept": "application/json",
            "api-key": BREVO_API_KEY || "",
            "content-type": "application/json",
          },
          body: JSON.stringify({
            sender: { name: "Savora", email: "no-reply@savora.com" },
            to: [{ email: email, name: name }],
            subject: "Confirmation de votre réservation Savora",
            htmlContent: `<html><body><h2>Réservation confirmée !</h2><p>Bonjour ${name}, votre réservation pour le ${record.reservation_date || ''} à ${record.reservation_time || ''} a bien été acceptée.</p></body></html>`,
          }),
        });

        const data = await response.json();
        return new Response(JSON.stringify({ success: true, data }), {
          headers: { "Content-Type": "application/json" },
          status: 200,
        });
      }
    }

    return new Response(JSON.stringify({ message: "Événement ignoré ou email introuvable" }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});