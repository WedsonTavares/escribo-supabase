// Edge Function: exportOrderCsv
// Gera um CSV com todos os pedidos de um cliente (com filtros opcionais de data).
// Passos:
// 1) Valida método e corpo (customerId, datas)
// 2) Consulta v_customer_orders com filtros
// 3) Monta CSV em memória e retorna com cabeçalhos adequados
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ExportRequest {
  customerId: string;
  startDate?: string;
  endDate?: string;
}

interface OrderData {
  order_id: string;
  status: string;
  total_cents: number;
  order_date: string;
  customer_name: string;
  email: string;
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
  const { customerId, startDate, endDate } = await req.json() as ExportRequest

    if (!customerId) {
      return new Response(
        JSON.stringify({ error: 'customerId is required' }),
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

    // Build query with optional date filters
    let query = supabaseClient
      .from('v_customer_orders')
      .select('*')
      .eq('customer_id', customerId)
      .order('order_date', { ascending: false })

    if (startDate) {
      query = query.gte('order_date', startDate)
    }

    if (endDate) {
      query = query.lte('order_date', endDate)
    }

    // Fetch orders data
    const { data: ordersData, error: ordersError } = await query

    if (ordersError) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch orders', details: ordersError.message }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    if (!ordersData || ordersData.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No orders found for this customer' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Generate CSV content
    const csvHeader = [
      'Order ID',
      'Order Date',
      'Status',
      'Customer Name',
      'Customer Email',
      'Product Name',
      'Quantity',
      'Unit Price (R$)',
      'Item Total (R$)',
      'Order Total (R$)'
    ].join(',')

    const csvRows: string[] = [csvHeader]

    ordersData.forEach((order: OrderData) => {
      const orderDate = new Date(order.order_date).toLocaleDateString('pt-BR')
      const orderTotal = (order.total_cents / 100).toFixed(2)

      if (order.items && order.items.length > 0) {
        order.items.forEach(item => {
          const unitPrice = (item.price_cents / 100).toFixed(2)
          const itemTotal = ((item.price_cents * item.quantity) / 100).toFixed(2)

          const row = [
            `"${order.order_id.slice(0, 8)}"`,
            `"${orderDate}"`,
            `"${order.status}"`,
            `"${order.customer_name}"`,
            `"${order.email}"`,
            `"${item.product_name}"`,
            item.quantity.toString(),
            unitPrice,
            itemTotal,
            orderTotal
          ].join(',')

          csvRows.push(row)
        })
      } else {
        // Order without items (shouldn't happen but handle gracefully)
        const row = [
          `"${order.order_id.slice(0, 8)}"`,
          `"${orderDate}"`,
          `"${order.status}"`,
          `"${order.customer_name}"`,
          `"${order.email}"`,
          '""',
          '0',
          '0.00',
          '0.00',
          orderTotal
        ].join(',')

        csvRows.push(row)
      }
    })

    const csvContent = csvRows.join('\n')

    // Generate filename with timestamp
    const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-')
    const filename = `orders_${customerId.slice(0, 8)}_${timestamp}.csv`

    // Return CSV file
    return new Response(csvContent, {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length': csvContent.length.toString(),
      }
    })

  } catch (error) {
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