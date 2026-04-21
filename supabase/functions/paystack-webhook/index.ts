// Paystack Webhook Handler
// Handles: charge.success (subscriptions + deals), subscription.charge (auto-renewal),
//          invoice.payment_failed, subscription.disable
//
// SECURITY: Verifies webhook signatures using HMAC SHA-512 with the Paystack secret key.
// RECOVERY: Acts as a safety net when the app is killed mid-payment.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-paystack-signature',
}

// ── HMAC SHA-512 signature verification ──────────────────────────────
async function verifySignature(
    rawBody: string,
    signature: string,
    secretKey: string,
): Promise<boolean> {
    const encoder = new TextEncoder()
    const key = await crypto.subtle.importKey(
        'raw',
        encoder.encode(secretKey),
        { name: 'HMAC', hash: 'SHA-512' },
        false,
        ['sign'],
    )
    const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(rawBody))
    const hashHex = Array.from(new Uint8Array(sig))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('')
    return hashHex === signature
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    // Read the raw body BEFORE parsing JSON (needed for signature verification)
    const rawBody = await req.text()

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const paystackSecretKeyRaw = Deno.env.get('PAYSTACK_SECRET_KEY') ?? ''
        const paystackSecretKey = paystackSecretKeyRaw.trim()

        // ── Signature verification ────────────────────────────
        const signature = req.headers.get('x-paystack-signature')

        if (!signature) {
            console.error('REJECTED: Missing x-paystack-signature header')
            return new Response(JSON.stringify({ error: 'Missing signature' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        if (!paystackSecretKey) {
            console.error('REJECTED: PAYSTACK_SECRET_KEY not configured')
            return new Response(JSON.stringify({ error: 'Server misconfigured' }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        const isValid = await verifySignature(rawBody, signature, paystackSecretKey)
        if (!isValid) {
            console.error('REJECTED: Invalid HMAC signature')
            return new Response(JSON.stringify({ error: 'Invalid signature' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // ── Parse & dispatch ──────────────────────────────────
        const supabase = createClient(supabaseUrl, supabaseServiceKey)
        const webhookData = JSON.parse(rawBody)
        const event = webhookData.event
        const data = webhookData.data

        console.log(`Webhook OK: ${event} ref=${data?.reference ?? 'n/a'}`)

        if (!data) {
            return new Response(JSON.stringify({ error: 'No data' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        switch (event) {
            case 'charge.success':
                await handleChargeSuccess(supabase, data)
                break
            case 'subscription.create':
                await handleSubscriptionCreate(supabase, data)
                break
            case 'subscription.charge':
                await handleSubscriptionCharge(supabase, data)
                break
            case 'invoice.payment_failed':
                await handlePaymentFailed(supabase, data)
                break
            case 'subscription.disable':
                await handleSubscriptionDisable(supabase, data)
                break
            default:
                console.log('Unhandled event:', event)
        }

        return new Response(JSON.stringify({ status: 'success' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })
    } catch (error) {
        console.error('Webhook error:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})

// ═══════════════════════════════════════════════════════════════════════
// charge.success — dispatches to subscription OR deal payment recovery
// ═══════════════════════════════════════════════════════════════════════
async function handleChargeSuccess(supabase: any, data: any) {
    const reference = data.reference
    const amount = data.amount
    const metadata = data.metadata || {}
    const userId = metadata.user_id
    const paymentType = metadata.payment_type || 'unknown'

    console.log(`charge.success ref=${reference} type=${paymentType} user=${userId}`)

    if (!userId) {
        console.warn('charge.success: no user_id in metadata, skipping')
        return
    }

    // ── Subscription payment ──────────────────────────────
    if (paymentType === 'subscription') {
        await recoverSubscriptionPayment(supabase, userId, reference, amount, metadata)
        return
    }

    // ── Deal / one-time payment ───────────────────────────
    if (paymentType === 'one_time_payment') {
        await recoverDealPayment(supabase, userId, reference, amount, metadata)
        return
    }

    console.log(`charge.success: unrecognized payment_type "${paymentType}", skipping`)
}

// ── Subscription payment recovery ─────────────────────────────────────
async function recoverSubscriptionPayment(
    supabase: any,
    userId: string,
    reference: string,
    amount: number,
    metadata: any,
) {
    console.log(`Recovering subscription payment for user ${userId}`)

    // Check if already processed (idempotent)
    const { data: existingSub } = await supabase
        .from('subscriptions')
        .select('id, status, expires_at, current_period_end')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

    // If subscription is already active, this was handled by the app
    if (existingSub?.status === 'active') {
        console.log('Subscription already active, skipping')
        return
    }

    // Calculate expiry: 30 days from now (or from current expiry if still valid)
    const now = new Date()
    let baseDate = now
    const expiresAt = existingSub?.expires_at || existingSub?.current_period_end
    if (expiresAt) {
        const existing = new Date(expiresAt)
        if (existing > now) baseDate = existing
    }
    const newExpiry = new Date(baseDate.getTime() + 30 * 24 * 60 * 60 * 1000)

    // Update subscription
    if (existingSub) {
        await supabase
            .from('subscriptions')
            .update({
                status: 'active',
                current_period_end: newExpiry.toISOString(),
                updated_at: now.toISOString(),
            })
            .eq('id', existingSub.id)
    } else {
        // Create new subscription
        await supabase.from('subscriptions').insert({
            user_id: userId,
            status: 'active',
            current_period_start: now.toISOString(),
            current_period_end: newExpiry.toISOString(),
            created_at: now.toISOString(),
            updated_at: now.toISOString(),
        })
    }

    // Activate profile
    await supabase
        .from('profiles')
        .update({
            subscription: 'active',
            subscription_status: 'active',
            updated_at: now.toISOString(),
        })
        .eq('id', userId)

    // Ensure user has an active QR code
    await ensureActiveQRCode(supabase, userId)

    // Notification
    await supabase.from('notifications').insert({
        user_id: userId,
        title: 'Subscription Activated',
        message: `Your Local Lekker subscription is active until ${newExpiry.toLocaleDateString('en-ZA')}.`,
        type: 'subscription_renewal',
        is_read: false,
        data: {
            reference,
            expires_at: newExpiry.toISOString(),
            amount: amount / 100,
            source: 'webhook',
        },
    })

    console.log(`Subscription activated for ${userId} until ${newExpiry.toISOString()}`)
}

// ── Deal payment recovery ─────────────────────────────────────────────
// Safety net: if the app was killed after Paystack charged the card but
// before _handlePaymentSuccess ran, the deal stays in 'approved' state.
// This webhook marks it 'completed' so the member isn't charged but stuck.
async function recoverDealPayment(
    supabase: any,
    userId: string,
    reference: string,
    amount: number,
    metadata: any,
) {
    const dealAuthId = metadata.deal_authorization_id
    console.log(`Recovering deal payment user=${userId} deal=${dealAuthId ?? 'unknown'} ref=${reference}`)

    let deal: any = null

    // Strategy 1: Use deal_authorization_id from metadata (preferred)
    if (dealAuthId) {
        const { data } = await supabase
            .from('deal_authorizations')
            .select('id, status, payment_completed_at')
            .eq('id', dealAuthId)
            .single()
        deal = data
    }

    // Strategy 2: Find the most recent non-completed deal for this user
    if (!deal) {
        const { data } = await supabase
            .from('deal_authorizations')
            .select('id, status, payment_completed_at')
            .eq('member_id', userId)
            .in('status', ['approved', 'pending_payment'])
            .is('payment_completed_at', null)
            .order('created_at', { ascending: false })
            .limit(1)
            .single()
        deal = data
    }

    if (!deal) {
        console.log('No pending deal found for this payment (app probably handled it)')
        return
    }

    // Already completed? Skip (idempotent)
    if (deal.status === 'completed' && deal.payment_completed_at) {
        console.log(`Deal ${deal.id} already completed, skipping`)
        return
    }

    const now = new Date().toISOString()

    // Mark deal as completed
    const { error } = await supabase
        .from('deal_authorizations')
        .update({
            status: 'completed',
            payment_completed_at: now,
            payment_reference: reference,
            updated_at: now,
        })
        .eq('id', deal.id)

    if (error) {
        console.error(`Failed to complete deal ${deal.id}:`, error.message)
        return
    }

    // Notify user
    await supabase.from('notifications').insert({
        user_id: userId,
        title: 'Payment Confirmed',
        message: `Your deal payment of R${(amount / 100).toFixed(2)} has been confirmed.`,
        type: 'deal_payment',
        is_read: false,
        data: {
            deal_authorization_id: deal.id,
            reference,
            amount: amount / 100,
            source: 'webhook',
        },
    })

    console.log(`Deal ${deal.id} recovered and marked completed`)
}

// ═══════════════════════════════════════════════════════════════════════
// subscription.create — Paystack created a subscription after plan payment
// Saves the subscription_code to the subscriptions table for webhook matching
// ═══════════════════════════════════════════════════════════════════════
async function handleSubscriptionCreate(supabase: any, data: any) {
    const subscriptionCode = data.subscription_code
    const customer = data.customer
    const plan = data.plan
    const status = data.status

    console.log(`subscription.create sub=${subscriptionCode} status=${status}`)

    if (!subscriptionCode) {
        console.warn('subscription.create: no subscription_code, skipping')
        return
    }

    // Find user by customer_code or email
    let userId: string | null = null

    if (customer?.customer_code) {
        const { data: profileByCode } = await supabase
            .from('profiles')
            .select('id')
            .eq('paystack_customer_code', customer.customer_code)
            .single()

        if (profileByCode) {
            userId = profileByCode.id
        }
    }

    if (!userId && customer?.email) {
        const { data: profileByEmail } = await supabase
            .from('profiles')
            .select('id')
            .eq('email', customer.email)
            .single()
        userId = profileByEmail?.id
    }

    if (!userId) {
        console.error(`subscription.create: User not found for customer: ${customer?.customer_code} / ${customer?.email}`)
        return
    }

    // Find the user's most recent subscription and save the Paystack subscription code
    const { data: existingSub } = await supabase
        .from('subscriptions')
        .select('id, paystack_subscription_code')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

    if (existingSub) {
        // Only update if not already set (avoid overwriting with stale data)
        if (!existingSub.paystack_subscription_code) {
            await supabase
                .from('subscriptions')
                .update({
                    paystack_subscription_code: subscriptionCode,
                    updated_at: new Date().toISOString(),
                })
                .eq('id', existingSub.id)

            console.log(`Saved subscription_code ${subscriptionCode} for user ${userId}`)
        } else {
            console.log(`Subscription already has code ${existingSub.paystack_subscription_code}, skipping`)
        }
    } else {
        console.warn(`No subscription record found for user ${userId} to attach subscription_code`)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// subscription.charge — auto-renewal after initial subscription
// ═══════════════════════════════════════════════════════════════════════
async function handleSubscriptionCharge(supabase: any, data: any) {
    const subscriptionCode = data.subscription?.subscription_code || data.subscription_code
    const customer = data.customer
    const amount = data.amount
    const status = data.status
    const reference = data.reference

    console.log(`subscription.charge ref=${reference} status=${status}`)

    if (status !== 'success') {
        console.log('Charge not successful, skipping')
        return
    }

    // Find user by customer code, fallback to email
    let userId: string | null = null

    if (customer?.customer_code) {
        const { data: profileByCode } = await supabase
            .from('profiles')
            .select('id')
            .eq('paystack_customer_code', customer.customer_code)
            .single()

        if (profileByCode) {
            userId = profileByCode.id
        }
    }

    if (!userId && customer?.email) {
        const { data: profileByEmail } = await supabase
            .from('profiles')
            .select('id')
            .eq('email', customer.email)
            .single()
        userId = profileByEmail?.id
    }

    if (!userId) {
        console.error(`User not found for customer: ${customer?.customer_code} / ${customer?.email}`)
        return
    }

    // Get current subscription to compute new expiry
    const { data: currentSub } = await supabase
        .from('subscriptions')
        .select('id, expires_at, current_period_end')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

    const now = new Date()
    let baseDate = now
    const expiresAt = currentSub?.expires_at || currentSub?.current_period_end
    if (expiresAt) {
        const existing = new Date(expiresAt)
        if (existing > now) baseDate = existing
    }

    const newExpiry = new Date(baseDate.getTime() + 30 * 24 * 60 * 60 * 1000)

    // Update subscription
    if (currentSub) {
        await supabase
            .from('subscriptions')
            .update({
                status: 'active',
                current_period_end: newExpiry.toISOString(),
                paystack_subscription_code: subscriptionCode,
                updated_at: now.toISOString(),
            })
            .eq('id', currentSub.id)
    }

    // Reactivate profile
    await supabase
        .from('profiles')
        .update({
            subscription: 'active',
            subscription_status: 'active',
            updated_at: now.toISOString(),
        })
        .eq('id', userId)

    // Ensure QR code is active
    await ensureActiveQRCode(supabase, userId)

    // Notification
    await supabase.from('notifications').insert({
        user_id: userId,
        title: 'Subscription Renewed',
        message: `Your subscription has been automatically renewed until ${newExpiry.toLocaleDateString('en-ZA')}.`,
        type: 'subscription_renewal',
        is_read: false,
        data: {
            reference,
            expires_at: newExpiry.toISOString(),
            amount: amount / 100,
            subscription_code: subscriptionCode,
            source: 'webhook',
        },
    })

    console.log(`Subscription renewal processed for ${userId} until ${newExpiry.toISOString()}`)
}

// ═══════════════════════════════════════════════════════════════════════
// invoice.payment_failed
// ═══════════════════════════════════════════════════════════════════════
async function handlePaymentFailed(supabase: any, data: any) {
    const subscriptionCode = data.subscription_code
    console.log(`payment_failed sub=${subscriptionCode}`)

    // Find user by subscription code
    const { data: subscription } = await supabase
        .from('subscriptions')
        .select('user_id')
        .eq('paystack_subscription_code', subscriptionCode)
        .single()

    if (!subscription) {
        console.error('Subscription not found:', subscriptionCode)
        return
    }

    const userId = subscription.user_id
    const now = new Date().toISOString()

    // Mark subscription as payment_failed
    await supabase
        .from('subscriptions')
        .update({ status: 'payment_failed', updated_at: now })
        .eq('paystack_subscription_code', subscriptionCode)

    // Deactivate QR codes
    await supabase
        .from('user_qr_codes')
        .update({ is_active: false, updated_at: now })
        .eq('user_id', userId)
        .eq('is_active', true)

    // Update profile
    await supabase
        .from('profiles')
        .update({ subscription: 'payment_failed', updated_at: now })
        .eq('id', userId)

    // Notification
    await supabase.from('notifications').insert({
        user_id: userId,
        title: 'Payment Failed',
        message: 'Your subscription payment failed. Please update your payment method to keep enjoying Local Lekker benefits.',
        type: 'payment_failure',
        is_read: false,
        data: {
            subscription_code: subscriptionCode,
            failed_at: now,
            action_required: 'update_payment_method',
            source: 'webhook',
        },
    })

    console.log(`Payment failed handled for ${userId}`)
}

// ═══════════════════════════════════════════════════════════════════════
// subscription.disable — voluntary cancellation
// ═══════════════════════════════════════════════════════════════════════
async function handleSubscriptionDisable(supabase: any, data: any) {
    const subscriptionCode = data.subscription_code
    console.log(`subscription.disable sub=${subscriptionCode}`)

    // Find subscription
    const { data: subscription } = await supabase
        .from('subscriptions')
        .select('user_id')
        .eq('paystack_subscription_code', subscriptionCode)
        .single()

    if (!subscription) {
        console.error('Subscription not found:', subscriptionCode)
        return
    }

    const userId = subscription.user_id
    const now = new Date().toISOString()

    await supabase
        .from('subscriptions')
        .update({ status: 'cancelled', updated_at: now })
        .eq('paystack_subscription_code', subscriptionCode)

    // Don't deactivate QR right away — let current period expire naturally
    // The app's checkAndHandleExpiredSubscription() handles expiry

    console.log(`Subscription cancelled for ${userId}`)
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════
async function ensureActiveQRCode(supabase: any, userId: string) {
    const { data: existingQR } = await supabase
        .from('user_qr_codes')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .single()

    if (existingQR) {
        console.log('User already has active QR code')
        return
    }

    const now = new Date()
    const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000)

    await supabase.from('user_qr_codes').insert({
        user_id: userId,
        qr_code: `QR_${userId}_${now.getTime()}`,
        is_active: true,
        expires_at: expiresAt.toISOString(),
        created_at: now.toISOString(),
        updated_at: now.toISOString(),
    })

    console.log(`Created QR code for ${userId}`)
}
