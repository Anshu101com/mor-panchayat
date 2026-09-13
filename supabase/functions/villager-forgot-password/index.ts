import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const admin = createClient(
  supabaseUrl,
  serviceRoleKey,
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

async function sha256(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);

  const hash = await crypto.subtle.digest(
    "SHA-256",
    data,
  );

  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function generateOtp(): string {
  const array = new Uint32Array(1);

  crypto.getRandomValues(array);

  return (100000 + (array[0] % 900000)).toString();
}

function normalize(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase();
}

function isExpired(expiresAt: string): boolean {
  return new Date(expiresAt).getTime() < Date.now();
}

async function createChallenge(
  userId: string,
  mobile: string,
) {
  const otp = generateOtp();

  const otpHash = await sha256(otp);

  const expiresAt = new Date(
    Date.now() + 5 * 60 * 1000,
  ).toISOString();

  const { data, error } = await admin
    .from("password_reset_challenges")
    .insert({
      user_id: userId,
      mobile,
      otp_hash: otpHash,
      expires_at: expiresAt,
      attempts: 0,
      verified: false,
    })
    .select("id")
    .single();

  if (error) {
    console.error(
      "Challenge creation error:",
      error,
    );

    throw new Error(
      "Could not create recovery challenge.",
    );
  }

  return {
    challengeId: data.id,
    otp,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const body = await req.json();

    const action = String(
      body.action ?? "",
    ).trim();

    // =========================================================
    // 1. VERIFY VILLAGER DETAILS
    // =========================================================

    if (action === "verify_details") {
      const mobile = String(
        body.mobile ?? "",
      ).trim();

      const name = String(
        body.name ?? "",
      ).trim();

      const fatherName = String(
        body.father_name ?? "",
      ).trim();

      const dateOfBirth = String(
        body.date_of_birth ?? "",
      ).trim();

      if (
        !mobile ||
        !name ||
        !fatherName ||
        !dateOfBirth
      ) {
        return json({
          success: false,
          message: "Missing required information.",
        }, 400);
      }

      const { data: profile, error } = await admin
        .from("profiles")
        .select(
          "user_id,name,mobile,father_name,date_of_birth,role",
        )
        .eq("mobile", mobile)
        .eq("role", "villager")
        .maybeSingle();

      if (error) {
        console.error(
          "Profile lookup error:",
          error,
        );

        return json({
          success: false,
          message: "Unable to verify account.",
        }, 500);
      }

      if (!profile) {
        return json({
          success: false,
          message: "Details do not match.",
        }, 400);
      }

      if (!profile.user_id) {
        console.error(
          "Villager profile has no user_id:",
          profile,
        );

        return json({
          success: false,
          message: "Villager account is not configured correctly.",
        }, 500);
      }

      const storedDob = String(
        profile.date_of_birth ?? "",
      ).trim();

      const detailsMatch =
        normalize(profile.name) === normalize(name) &&
        normalize(profile.father_name) === normalize(fatherName) &&
        storedDob === dateOfBirth;

      if (!detailsMatch) {
        return json({
          success: false,
          message: "Details do not match.",
        }, 400);
      }

      // Delete previous unused recovery challenges
      await admin
        .from("password_reset_challenges")
        .delete()
        .eq("user_id", profile.user_id)
        .eq("verified", false);

      const {
        challengeId,
        otp,
      } = await createChallenge(
        profile.user_id,
        mobile,
      );

      return json({
        success: true,
        challenge_id: challengeId,
        otp: otp,
        expires_in: 300,
      });
    }

    // =========================================================
    // 2. RESEND OTP
    // =========================================================

    if (action === "resend_otp") {
      const challengeId = String(
        body.challenge_id ?? "",
      ).trim();

      if (!challengeId) {
        return json({
          success: false,
          message: "Missing recovery challenge.",
        }, 400);
      }

      const { data: oldChallenge, error } =
        await admin
          .from("password_reset_challenges")
          .select("*")
          .eq("id", challengeId)
          .maybeSingle();

      if (
        error ||
        !oldChallenge
      ) {
        return json({
          success: false,
          message: "Invalid recovery request.",
        }, 400);
      }

      if (oldChallenge.verified) {
        return json({
          success: false,
          message: "Recovery request already completed.",
        }, 400);
      }

      // Delete old challenge
      await admin
        .from("password_reset_challenges")
        .delete()
        .eq("id", challengeId);

      // Create new challenge
      const {
        challengeId: newChallengeId,
        otp,
      } = await createChallenge(
        oldChallenge.user_id,
        oldChallenge.mobile,
      );

      return json({
        success: true,
        challenge_id: newChallengeId,
        otp: otp,
        expires_in: 300,
      });
    }

    // =========================================================
    // 3. VERIFY OTP
    // =========================================================

    if (action === "verify_otp") {
      const challengeId = String(
        body.challenge_id ?? "",
      ).trim();

      const otp = String(
        body.otp ?? "",
      ).trim();

      if (
        !challengeId ||
        !otp
      ) {
        return json({
          success: false,
          message: "Missing OTP.",
        }, 400);
      }

      if (!/^\d{6}$/.test(otp)) {
        return json({
          success: false,
          message: "Invalid OTP.",
        }, 400);
      }

      const { data: challenge, error } =
        await admin
          .from("password_reset_challenges")
          .select("*")
          .eq("id", challengeId)
          .maybeSingle();

      if (
        error ||
        !challenge
      ) {
        return json({
          success: false,
          message: "Invalid recovery request.",
        }, 400);
      }

      if (challenge.verified) {
        return json({
          success: false,
          message: "OTP has already been used.",
        }, 400);
      }

      if (
        isExpired(challenge.expires_at)
      ) {
        return json({
          success: false,
          message: "OTP has expired.",
        }, 400);
      }

      const attempts =
        Number(challenge.attempts ?? 0);

      if (attempts >= 5) {
        return json({
          success: false,
          message: "Too many attempts.",
        }, 400);
      }

      const otpHash = await sha256(otp);

      if (
        otpHash !== challenge.otp_hash
      ) {
        await admin
          .from("password_reset_challenges")
          .update({
            attempts: attempts + 1,
          })
          .eq("id", challengeId);

        return json({
          success: false,
          message: "Invalid OTP.",
        }, 400);
      }

      await admin
        .from("password_reset_challenges")
        .update({
          verified: true,
        })
        .eq("id", challengeId);

      return json({
        success: true,
      });
    }

    // =========================================================
    // 4. UPDATE PASSWORD
    // =========================================================

    if (action === "update_password") {
      const challengeId = String(
        body.challenge_id ?? "",
      ).trim();

      const newPassword = String(
        body.new_password ?? "",
      );

      if (
        !challengeId ||
        newPassword.length < 6
      ) {
        return json({
          success: false,
          message: "Invalid password.",
        }, 400);
      }

      const { data: challenge, error } =
        await admin
          .from("password_reset_challenges")
          .select("*")
          .eq("id", challengeId)
          .maybeSingle();

      if (
        error ||
        !challenge
      ) {
        return json({
          success: false,
          message: "Invalid recovery request.",
        }, 400);
      }

      if (!challenge.verified) {
        return json({
          success: false,
          message: "OTP has not been verified.",
        }, 400);
      }

      if (
        isExpired(challenge.expires_at)
      ) {
        return json({
          success: false,
          message: "Recovery request has expired.",
        }, 400);
      }

      const {
        error: updateError,
      } = await admin.auth.admin.updateUserById(
        challenge.user_id,
        {
          password: newPassword,
        },
      );

      if (updateError) {
        console.error(
          "Password update error:",
          updateError,
        );

        return json({
          success: false,
          message: "Unable to update password.",
        }, 500);
      }

      // Delete completed challenge
      await admin
        .from("password_reset_challenges")
        .delete()
        .eq("id", challengeId);

      return json({
        success: true,
      });
    }

    // =========================================================
    // INVALID ACTION
    // =========================================================

    return json({
      success: false,
      message: "Invalid action.",
    }, 400);

  } catch (error) {
    console.error(
      "Edge Function error:",
      error,
    );

    return json({
      success: false,
      message: "Server error.",
    }, 500);
  }
});