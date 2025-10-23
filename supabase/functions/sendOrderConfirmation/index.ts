// Edge Function: sendOrderConfirmation
// Responsável por montar e enviar email de confirmação de pedido.
// Passos:
// 1) Valida o método e o corpo (orderId)
// 2) Busca o pedido em v_customer_orders
// 3) Gera conteúdo do email
// 4) Envia via serviço externo (se configurado) ou retorna o conteúdo para teste
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface OrderConfirmationRequest {
  orderId: string;
}

interface OrderDetails {
  id: string;
  status: string;
  total_cents: number;
  created_at: string;
  customer_name: string;
  customer_email: string;
  items: Array<{
    product_name: string;
    quantity: number;
    price_cents: number;
  }>;
}

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Validate request method
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { 
          status: 405, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Parse request body
  const { orderId } = await req.json() as OrderConfirmationRequest

    if (!orderId) {
      return new Response(
        JSON.stringify({ error: 'orderId is required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch order details with customer and items
    const { data: orderData, error: orderError } = await supabaseClient
      .from('v_customer_orders')
      .select('*')
      .eq('order_id', orderId)
      .single()

    if (orderError || !orderData) {
      return new Response(
        JSON.stringify({ error: 'Order not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Format order details
    const orderDetails: OrderDetails = {
      id: orderData.order_id,
      status: orderData.status,
      total_cents: orderData.total_cents,
      created_at: orderData.order_date,
      customer_name: orderData.customer_name,
      customer_email: orderData.email,
      items: orderData.items || []
    }

    // Format total price
    const totalPrice = (orderDetails.total_cents / 100).toFixed(2)

    // Generate email content
    const emailSubject = `Confirmação do Pedido #${orderDetails.id.slice(0, 8)}`
    
    const itemsList = orderDetails.items
      .map(item => {
        const itemPrice = (item.price_cents / 100).toFixed(2)
        const itemTotal = ((item.price_cents * item.quantity) / 100).toFixed(2)
        return `- ${item.product_name} (Qtd: ${item.quantity}) - R$ ${itemPrice} cada = R$ ${itemTotal}`
      })
      .join('\n')

    const emailBody = `
Olá ${orderDetails.customer_name},

Seu pedido foi confirmado com sucesso!

Detalhes do Pedido:
- Número: #${orderDetails.id.slice(0, 8)}
- Status: ${orderDetails.status}
- Data: ${new Date(orderDetails.created_at).toLocaleDateString('pt-BR')}

Itens:
${itemsList}

Total: R$ ${totalPrice}

Obrigado pela sua compra!

Atenciosamente,
Equipe E-commerce
    `.trim()

    // Send email using configured mail service
    const mailApiUrl = Deno.env.get('MAIL_API_URL')
    const mailApiKey = Deno.env.get('MAIL_API_KEY')

    if (mailApiUrl && mailApiKey) {
      try {
        const mailResponse = await fetch(mailApiUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${mailApiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            to: orderDetails.customer_email,
            subject: emailSubject,
            text: emailBody,
            from: 'noreply@ecommerce.com'
          })
        })

        if (!mailResponse.ok) {
          throw new Error(`Mail service error: ${mailResponse.status}`)
        }

        const mailResult = await mailResponse.json()
        
        return new Response(
          JSON.stringify({ 
            success: true, 
            message: 'Order confirmation email sent successfully',
            orderId: orderDetails.id,
            emailSent: true,
            mailResult
          }),
          { 
            status: 200, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )

      } catch (mailError: unknown) {
        console.error('Mail service error:', mailError)
        
        return new Response(
          JSON.stringify({ 
            success: true, 
            message: 'Order processed but email failed to send',
            orderId: orderDetails.id,
            emailSent: false,
            error: mailError instanceof Error ? mailError.message : 'Unknown mail error',
            emailContent: { subject: emailSubject, body: emailBody }
          }),
          { 
            status: 200, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        )
      }
    } else {
      // Mail service not configured - return email content for testing
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Order confirmation processed (mail service not configured)',
          orderId: orderDetails.id,
          emailSent: false,
          emailContent: { subject: emailSubject, body: emailBody }
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

  } catch (error: unknown) {
    console.error('Function error:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        details: error instanceof Error ? error.message : 'Unknown error' 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})