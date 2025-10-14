# Payment API Specification

This document outlines the API endpoints required for the Medito payment system using Stripe.

## Authentication

All endpoints require Bearer token authentication:
```
Authorization: Bearer <DONATION_TOKEN>
```

The token is stored in the environment configuration and passed in the request headers.

---

## Endpoint 1: Create Payment Intent

### `POST /payment-intents`

Creates a Stripe payment intent for either one-time donations or subscription payments.

### Request Headers
```
Authorization: Bearer <DONATION_TOKEN>
Content-Type: application/json
```

### Request Body

```json
{
  "amount": 500,
  "currency": "usd",
  "paymentMethod": "google_pay",
  "paymentType": "one_time",
  "subscriptionInterval": "month",
  "metadata": {}
}
```

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `amount` | integer | Yes | Amount in smallest currency unit (e.g., cents for USD). Example: 500 = $5.00 |
| `currency` | string | Yes | Three-letter ISO currency code (lowercase). Example: "usd", "gbp", "eur" |
| `paymentMethod` | string | Yes | Payment method type. Allowed values: `"google_pay"`, `"apple_pay"`, `"card"`, `"paypal"`, `"bank_transfer"` |
| `paymentType` | string | Yes | Type of payment. Allowed values: `"one_time"`, `"subscription"` |
| `subscriptionInterval` | string | Conditional | Required if `paymentType` is `"subscription"`. Allowed values: `"month"`, `"year"` |
| `metadata` | object | No | Optional key-value pairs for storing additional information |

#### Validation Rules

1. All required fields must be present and non-empty
2. `amount` must be a positive integer
3. `currency` must be a valid ISO 4217 currency code
4. `paymentMethod` must be one of the allowed values
5. `paymentType` must be either `"one_time"` or `"subscription"`
6. If `paymentType` is `"subscription"`, `subscriptionInterval` is required
7. If `paymentType` is `"one_time"`, `subscriptionInterval` should be ignored/null

### Response

#### Success Response (200 OK)

```json
{
  "success": true,
  "data": {
    "id": "pi_1234567890abcdef",
    "clientSecret": "pi_1234567890abcdef_secret_xyz123",
    "status": "requires_payment_method",
    "amount": 500,
    "currency": "usd",
    "paymentMethodId": null,
    "lastPaymentError": null,
    "subscriptionId": "sub_1234567890",
    "interval": "month"
  }
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Indicates if the request was successful |
| `data.id` | string | Stripe Payment Intent ID |
| `data.clientSecret` | string | Client secret for confirming the payment on the client side |
| `data.status` | string | Stripe payment intent status (e.g., "requires_payment_method", "requires_confirmation") |
| `data.amount` | integer | Amount in smallest currency unit |
| `data.currency` | string | Three-letter ISO currency code |
| `data.paymentMethodId` | string or null | Payment method ID if attached |
| `data.lastPaymentError` | string or null | Error message from last payment attempt, if any |
| `data.subscriptionId` | string or null | Subscription ID if this is a subscription payment |
| `data.interval` | string or null | Subscription interval if applicable ("month" or "year") |

#### Error Response (400 Bad Request)

```json
{
  "success": false,
  "error": {
    "message": "Missing required fields: amount, currency, paymentMethod, paymentType"
  }
}
```

#### Error Response (500 Internal Server Error)

```json
{
  "success": false,
  "error": {
    "message": "Failed to create payment intent: <stripe error message>"
  }
}
```

### Implementation Notes

1. **For One-Time Payments:**
   - Create a Stripe Payment Intent with the specified amount
   - Set `setup_future_usage` to null
   - Return the payment intent details

2. **For Subscription Payments:**
   - Create a Stripe Customer (or retrieve existing customer)
   - Create a Stripe Subscription with the specified interval
   - Set up the payment intent for the first payment
   - Return both payment intent and subscription details
   - Include `subscriptionId` and `interval` in the response

3. **Payment Method Handling:**
   - The payment method will be attached during the client-side confirmation
   - No need to attach payment methods at this stage

4. **Metadata Storage:**
   - Store any provided metadata in both the Payment Intent and Subscription (if applicable)
   - This can be used for tracking purposes, analytics, etc.

---

## Endpoint 2: Confirm Payment Intent

### `POST /payment-intents/confirm`

Backend confirmation endpoint for additional business logic processing after the client has successfully confirmed the payment with Stripe.

**Important:** The actual payment confirmation is handled by the Stripe SDK on the client side. This endpoint is for backend business logic only (e.g., updating database records, sending notifications, triggering webhooks).

### Request Headers
```
Authorization: Bearer <DONATION_TOKEN>
Content-Type: application/json
```

### Request Body

```json
{
  "paymentIntentId": "pi_1234567890abcdef",
  "paymentMethodId": "",
  "customerId": "cus_1234567890",
  "metadata": {}
}
```

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `paymentIntentId` | string | Yes | The Stripe Payment Intent ID |
| `paymentMethodId` | string | Yes | Empty string - backend retrieves actual value from Stripe |
| `customerId` | string | No | Stripe Customer ID if available |
| `metadata` | object | No | Optional additional metadata for business logic |

#### Validation Rules

1. `paymentIntentId` must be present and valid
2. Backend should retrieve the payment intent from Stripe using `paymentIntentId`
3. Verify the payment intent status is successful before processing

### Response

#### Success Response (200 OK)

```json
{
  "success": true,
  "data": {
    "message": "Payment confirmed successfully",
    "paymentIntentId": "pi_1234567890abcdef",
    "processed": true
  }
}
```

#### Error Response (400 Bad Request)

```json
{
  "success": false,
  "error": {
    "message": "paymentIntentId is required"
  }
}
```

#### Error Response (404 Not Found)

```json
{
  "success": false,
  "error": {
    "message": "Payment intent not found"
  }
}
```

#### Error Response (500 Internal Server Error)

```json
{
  "success": false,
  "error": {
    "message": "Failed to process payment confirmation"
  }
}
```

### Implementation Notes

1. **Payment Status Verification:**
   - Retrieve the payment intent from Stripe using `paymentIntentId`
   - Verify the status is `succeeded` or `processing`
   - Do NOT attempt to confirm the payment again (client already did this)

2. **Payment Method Retrieval:**
   - The client sends `paymentMethodId` as empty string
   - Backend retrieves the actual payment method from Stripe:
     ```typescript
     const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
     const paymentMethodId = paymentIntent.payment_method;
     ```
   - This is more secure and reliable than trusting client data

3. **Business Logic Processing:**
   - Update database records (donations table, user records, etc.)
   - Send confirmation emails
   - Update analytics/metrics
   - Trigger any webhooks or third-party integrations
   - Handle subscription setup if applicable

4. **Idempotency:**
   - This endpoint may be called multiple times for the same payment
   - Implement idempotency to prevent duplicate processing
   - Use `paymentIntentId` as the idempotency key

5. **Error Handling:**
   - If business logic fails, log the error but don't return failure to client
   - The payment has already succeeded with Stripe
   - Retry failed business logic operations asynchronously
   - Client logging shows: "Backend confirmation failed, but payment succeeded"

6. **Subscription Handling:**
   - If this is a subscription payment, ensure:
     - Customer is created/updated in your database
     - Subscription record is stored
     - First payment is recorded
     - Webhooks are set up to handle future subscription events

---

## Error Handling

### HTTP Status Codes

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 400 | Bad Request (validation errors, missing fields) |
| 401 | Unauthorized (invalid or missing auth token) |
| 404 | Not Found (payment intent doesn't exist) |
| 500 | Internal Server Error (Stripe errors, database errors) |

### Error Response Format

All error responses follow this format:
```json
{
  "success": false,
  "error": {
    "message": "Human-readable error message"
  }
}
```

---

## Example Flows

### Flow 1: One-Time Donation with Google Pay

1. **Client calls** `POST /payment-intents`:
```json
{
  "amount": 1000,
  "currency": "usd",
  "paymentMethod": "google_pay",
  "paymentType": "one_time"
}
```

2. **Backend responds** with payment intent:
```json
{
  "success": true,
  "data": {
    "id": "pi_abc123",
    "clientSecret": "pi_abc123_secret_xyz",
    "status": "requires_payment_method",
    "amount": 1000,
    "currency": "usd",
    "paymentMethodId": null,
    "lastPaymentError": null,
    "subscriptionId": null,
    "interval": null
  }
}
```

3. **Client confirms payment** with Stripe SDK using the `clientSecret`

4. **Client calls** `POST /payment-intents/confirm`:
```json
{
  "paymentIntentId": "pi_abc123",
  "paymentMethodId": ""
}
```

5. **Backend processes** business logic and responds:
```json
{
  "success": true,
  "data": {
    "message": "Payment confirmed successfully",
    "paymentIntentId": "pi_abc123",
    "processed": true
  }
}
```

### Flow 2: Monthly Subscription with Apple Pay

1. **Client calls** `POST /payment-intents`:
```json
{
  "amount": 500,
  "currency": "gbp",
  "paymentMethod": "apple_pay",
  "paymentType": "subscription",
  "subscriptionInterval": "month"
}
```

2. **Backend responds** with payment intent and subscription:
```json
{
  "success": true,
  "data": {
    "id": "pi_def456",
    "clientSecret": "pi_def456_secret_abc",
    "status": "requires_payment_method",
    "amount": 500,
    "currency": "gbp",
    "paymentMethodId": null,
    "lastPaymentError": null,
    "subscriptionId": "sub_xyz789",
    "interval": "month"
  }
}
```

3. **Client confirms payment** with Stripe SDK

4. **Client calls** `POST /payment-intents/confirm` (same as one-time flow)

---

## Database Schema Recommendations

### Donations Table
```sql
CREATE TABLE donations (
    id UUID PRIMARY KEY,
    payment_intent_id VARCHAR(255) UNIQUE NOT NULL,
    customer_id VARCHAR(255),
    amount INTEGER NOT NULL,
    currency VARCHAR(3) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    status VARCHAR(50) NOT NULL,
    subscription_id VARCHAR(255),
    subscription_interval VARCHAR(10),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### Subscriptions Table
```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY,
    stripe_subscription_id VARCHAR(255) UNIQUE NOT NULL,
    customer_id VARCHAR(255) NOT NULL,
    amount INTEGER NOT NULL,
    currency VARCHAR(3) NOT NULL,
    interval VARCHAR(10) NOT NULL,
    status VARCHAR(50) NOT NULL,
    current_period_start TIMESTAMP NOT NULL,
    current_period_end TIMESTAMP NOT NULL,
    canceled_at TIMESTAMP,
    ended_at TIMESTAMP,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

---

## Testing

### Test Cases for Create Payment Intent

1. **Valid one-time payment** ✓
2. **Valid monthly subscription** ✓
3. **Valid yearly subscription** ✓
4. **Missing amount** → 400 error
5. **Missing currency** → 400 error
6. **Invalid payment method** → 400 error
7. **Subscription without interval** → 400 error
8. **Invalid currency code** → 400 error
9. **Negative amount** → 400 error
10. **Stripe API failure** → 500 error

### Test Cases for Confirm Payment Intent

1. **Valid confirmation** ✓
2. **Missing payment intent ID** → 400 error
3. **Invalid payment intent ID** → 404 error
4. **Duplicate confirmation (idempotency)** ✓
5. **Payment intent not succeeded** → 400 error

---

## Security Considerations

1. **Authentication:** All endpoints require Bearer token authentication
2. **Validation:** Validate all input fields before processing
3. **Rate Limiting:** Implement rate limiting to prevent abuse
4. **Idempotency:** Use idempotency keys for payment operations
5. **Logging:** Log all payment attempts (success and failure) for audit trails
6. **PCI Compliance:** Never store raw card data; use Stripe's secure handling
7. **HTTPS Only:** All API calls must use HTTPS in production
8. **Environment Variables:** Store sensitive keys (Stripe secret key) in environment variables

---

## Webhook Recommendations

Set up Stripe webhooks to handle:
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

This ensures the backend stays in sync with Stripe for all payment events.

