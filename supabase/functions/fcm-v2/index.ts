// supabase/functions/fcm-v2/index.ts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SERVICE_ACCOUNT_STR = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

// --- Yardımcı: PEM Anahtar Dönüştürücü ---
function pemToBinary(pem: string) {
  const b64 = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s/g, "");
  const binaryStr = atob(b64);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }
  return bytes.buffer;
}

// --- Yardımcı: Google Token Alıcı ---
async function getAccessToken(serviceAccount: any) {
  try {
    const privateKeyStr = serviceAccount.private_key.replace(/\\n/g, "\n");
    const binaryKey = pemToBinary(privateKeyStr);
    const key = await crypto.subtle.importKey(
      "pkcs8", binaryKey, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, true, ["sign"]
    );
    const jwt = await create(
      { alg: "RS256", typ: "JWT" },
      {
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        exp: Math.floor(Date.now() / 1000) + 3600,
        iat: Math.floor(Date.now() / 1000),
      }, key
    );
    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
    });
    const data = await res.json();
    return data.access_token;
  } catch (e) {
    return null;
  }
}

// --- ANA SUNUCU FONKSİYONU ---
serve(async (req) => {
  try {
    const payload = await req.json();

    // 1. Secret Kontrolü
    if (!SERVICE_ACCOUNT_STR) return new Response(JSON.stringify({ error: "Secret Yok" }), { status: 500 });
    const SERVICE_ACCOUNT = JSON.parse(SERVICE_ACCOUNT_STR);

    // 2. Token Al (Firebase İletişimi İçin)
    const accessToken = await getAccessToken(SERVICE_ACCOUNT);
    if (!accessToken) throw new Error("Google Token alınamadı");
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${SERVICE_ACCOUNT.project_id}/messages:send`;

    // ---------------------------------------------------------
    // SENARYO 1: BROADCAST (TOPLU ACİL BİLDİRİM)
    // AdminDashboard'dan gelen istek buraya düşer.
    // ---------------------------------------------------------
    if (payload.type === 'broadcast') {
        const { topic, title, body } = payload;

        console.log(`📢 Broadcast İsteği: ${topic} - ${title}`);

        const messagePayload = {
            message: {
                topic: topic, // Örn: 'emergency_channel'
                notification: { 
                    title: `🚨 ${title}`, // Acil emojisi ekle
                    body: body 
                },
                android: {
                    priority: "high",
                    notification: {
                        channel_id: "emergency_channel",
                        sound: "default",
                        default_vibrate_timings: true,
                        color: "#DC2626" // Kırmızı renk (Acil)
                    }
                },
                data: {
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                    is_broadcast: "true"
                }
            }
        };

        const fcmRes = await fetch(fcmUrl, {
            method: "POST",
            headers: { "Authorization": `Bearer ${accessToken}`, "Content-Type": "application/json" },
            body: JSON.stringify(messagePayload)
        });

        const result = await fcmRes.json();
        return new Response(JSON.stringify(result), {headers:{"Content-Type":"application/json"}});
    }

    // ---------------------------------------------------------
    // SENARYO 2: VERİTABANI TETİKLEYİCİLERİ (Insert/Update)
    // Normal arıza bildirimleri buraya düşer.
    // ---------------------------------------------------------
    
    const { table, record, old_record } = payload;
    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
    const userId = record.user_id;

    if (!userId) return new Response(JSON.stringify({ msg: "User ID Yok" }), { headers: { "Content-Type": "application/json" } });

    // --- SENARYO 2-A: FAULTS Tablosu (Bildirim Kaydı Oluşturma) ---
    if (table !== 'notifications') {
      
      // Çift Bildirim Engelleme: Status değişmediyse atla
      if (old_record && old_record.status === record.status) {
           return new Response(JSON.stringify({ msg: "Status değişmediği için bildirim atlanıyor." }), {headers:{"Content-Type":"application/json"}});
      }

      // Tarihi Formatla (TR Saati)
      let tarihMetni = "";
      if (record.created_at) {
          const tarih = new Date(record.created_at);
          tarih.setHours(tarih.getHours() + 3);
          tarihMetni = tarih.toLocaleDateString("tr-TR", { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
      }
      
      const orjinalBaslik = record.title || "Arıza Talebi";
      let notificationTitle = "Durum Güncellendi 📢";
      
      // Acil Başlık Kontrolü
      if ((orjinalBaslik && orjinalBaslik.toUpperCase().includes('ACİL')) || (record.category && record.category.toUpperCase().includes('ACİL'))) {
          notificationTitle = `🚨 ACİL: ${record.status}`;
      } else {
          notificationTitle = `Durum: ${record.status}`;
      }

      const notificationBody = `${tarihMetni} - "${orjinalBaslik}" talebiniz güncellendi.`;

      // Notifications tablosuna ekle (Bu işlem SENARYO 2-B'yi tetikler)
      const { error } = await supabase.from('notifications').insert({
          user_id: userId,
          fault_id: record.id,
          title: notificationTitle,
          body: notificationBody,
          is_read: false
      });

      if (error) throw error;
      return new Response(JSON.stringify({ msg: "Bildirim kuyruğa eklendi." }), { headers: { "Content-Type": "application/json" } });
    }

    // --- SENARYO 2-B: NOTIFICATIONS Tablosu (Kişiye Özel Firebase Gönderimi) ---

    // Kullanıcı Token ve Ayarını Çek
    const { data: profile } = await supabase
      .from("profiles")
      .select("fcm_token, notification_level")
      .eq("id", userId)
      .single();

    if (!profile?.fcm_token) return new Response(JSON.stringify({ msg: "Token Yok" }), { headers: { "Content-Type": "application/json" } });

    let notificationTitle = record.title || "Yeni Bildirim";
    let notificationBody = record.body || "";

    if (notificationTitle.toUpperCase().includes('ACİL') || notificationTitle.toUpperCase().includes('UYARI')) {
      if (!notificationTitle.includes('🚨')) notificationTitle = `🚨 ${notificationTitle}`;
    }

    const customData = {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      route: "/notifications",
      fault_id: record.fault_id ? String(record.fault_id) : ""
    };

    // Kullanıcı Bildirim Ayarı Kontrolü
    if (profile.notification_level === 'none') {
      return new Response(JSON.stringify({ message: "User disabled notifications" }), { status: 200, headers: { "Content-Type": "application/json" } });
    }
    if (profile.notification_level === 'urgent') {
      const titleUpper = notificationTitle.toUpperCase();
      const isEmergency = titleUpper.includes('ACİL') || titleUpper.includes('UYARI') || titleUpper.includes('🚨');
      if (!isEmergency) {
        return new Response(JSON.stringify({ message: "Skipped: Not urgent" }), { status: 200, headers: { "Content-Type": "application/json" } });
      }
    }

    // Firebase'e Gönder (Kişisel)
    const messagePayload = {
      message: {
        token: profile.fcm_token,
        data: customData,
        notification: {
          title: notificationTitle,
          body: notificationBody
        },
        android: {
          priority: "high",
          notification: {
            channel_id: "emergency_channel",
            default_sound: true,
            default_vibrate_timings: true
          }
        }
      }
    };

    const fcmRes = await fetch(fcmUrl, {
      method: "POST",
      headers: { "Authorization": `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify(messagePayload)
    });

    const result = await fcmRes.json();
    return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" } });

  } catch (e) {
    const errorMessage = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: errorMessage }), { status: 500 });
  }
});