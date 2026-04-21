// Paystack API Proxy - Routes all secret-key Paystack calls through server-side
// The PAYSTACK_SECRET_KEY never leaves this Edge Function.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Whitelist of allowed Paystack API path prefixes.
// Any request whose path does NOT start with one of these is rejected.
const ALLOWED_PATH_PREFIXES = [
    '/transaction/initialize',
    '/transaction/verify/',
    '/transaction/charge_authorization',
    '/plan',
    '/subscription',
    '/customer',
    '/transferrecipient',
    '/charge',
    '/subaccount',
    '/bank/resolve',
]

// Special diagnostic path (does NOT call Paystack, just checks config)
const HEALTH_CHECK_PATH = '/__health'

function isAllowedPath(path: string): boolean {
    return ALLOWED_PATH_PREFIXES.some(prefix => path.startsWith(prefix))
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // ── Auth ──────────────────────────────────────────────
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(
                JSON.stringify({ error: 'Missing authorization header' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            )
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
        const paystackSecretKeyRaw = Deno.env.get('PAYSTACK_SECRET_KEY') ?? ''
        const paystackSecretKey = paystackSecretKeyRaw.trim()

        if (!paystackSecretKey) {
            console.error('PAYSTACK_SECRET_KEY is not configured')
            return new Response(
                JSON.stringify({ error: 'Payment service not configured' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            )
        }

        // Verify JWT by creating a Supabase client with the caller's token
        const supabase = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } },
        })
        const { data: { user }, error: authError } = await supabase.auth.getUser()
        if (authError || !user) {
            return new Response(
                JSON.stringify({ error: 'Invalid or expired token' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            )
        }

        // ── Parse request ─────────────────────────────────────
        const { path, method, body } = await req.json()

        if (!path || typeof path !== 'string') {
            return new Response(
                JSON.stringify({ error: 'Missing "path" in request body' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            )
        }

        // ── Health check (diagnose key configuration) ─────────
        if (path === HEALTH_CHECK_PATH) {
            const keyLength = paystackSecretKey.length
            const keyPrefix = paystackSecretKey.substring(0, 8) // e.g. sk_live_ or sk_test_
            const isLiveKey = paystackSecretKey.startsWith('sk_live_')
            const isTestKey = paystackSecretKey.startsWith('sk_test_')
            const keyLooksValid = (isLiveKey || isTestKey) && keyLength > 20

            // Optionally do a quick Paystack balance check to validate the key
            let paystackReachable = false
            let paystackKeyValid = false
            let paystackError = ''
            try {
                const testResp = await fetch('https://api.paystack.co/balance', {
                    method: 'GET',
                    headers: {
                        'Authorization': `Bearer ${paystackSecretKey}`,
                        'Content-Type': 'application/json',
                    },
                })
                paystackReachable = true
                paystackKeyValid = testResp.status === 200
                if (!paystackKeyValid) {
                    const errBody = await testResp.text()
                    paystackError = `HTTP ${testResp.status}: ${errBody.substring(0, 200)}`
                }
            } catch (e) {
                paystackError = `Network error: ${e.message}`
            }

            console.log(`Health check: keyPrefix=${keyPrefix} keyLength=${keyLength} valid=${paystackKeyValid}`)

            return new Response(
                JSON.stringify({
                    status: 'ok',
                    proxy_version: '2.0',
                    key_configured: keyLength > 0,
                    key_length: keyLength,
                    key_prefix: keyPrefix,
                    key_is_live: isLiveKey,
                    key_is_test: isTestKey,
                    key_looks_valid: keyLooksValid,
                    paystack_reachable: paystackReachable,
                    paystack_key_accepted: paystackKeyValid,
                    paystack_error: paystackError || undefined,
                    user_id: user.id,
                    timestamp: new Date().toISOString(),
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            )
        }

        // ── Validate path ─────────────────────────────────────
        if (!isAllowedPath(path)) {
            console.error(`BLOCKED: user=${user.id} path=${path}`)
            return new Response(
                JSON.stringify({ error: 'Path not allowed' }),
                { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
            )
        }

        const httpMethod = (method || 'GET').toUpperCase()
        const paystackUrl = `https://api.paystack.co${path}`

        // Log key diagnostics on every request for debugging
        console.log(`proxy ${httpMethod} ${path} user=${user.id} keyLen=${paystackSecretKey.length} keyPrefix=${paystackSecretKey.substring(0, 8)}`)

        // ── Forward to Paystack ───────────────────────────────
        const fetchOptions: RequestInit = {
            method: httpMethod,
            headers: {
                'Authorization': `Bearer ${paystackSecretKey}`,
                'Content-Type': 'application/json',
            },
        }

        // Attach body for POST / PUT (not GET / DELETE)
        if (body && httpMethod !== 'GET' && httpMethod !== 'DELETE') {
            fetchOptions.body = JSON.stringify(body)
        }

        const paystackResponse = await fetch(paystackUrl, fetchOptions)
        const responseText = await paystackResponse.text()

        // Return Paystack's response as-is (status code + body)
        return new Response(responseText, {
            status: paystackResponse.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })

    } catch (error) {
        console.error('Paystack proxy error:', error)
        return new Response(
            JSON.stringify({ error: error.message || 'Internal proxy error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )
    }
})
