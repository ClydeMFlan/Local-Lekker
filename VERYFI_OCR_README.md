# Veryfi OCR API Integration

This document explains how to set up Veryfi OCR API for superior receipt scanning accuracy.

## What is Veryfi?

Veryfi is a specialized OCR service designed specifically for receipt and invoice processing. Unlike generic OCR services, Veryfi can:

- Automatically extract line items, prices, and quantities
- Identify merchant names and locations
- Parse dates, subtotals, taxes, and totals
- Handle various receipt formats and layouts
- Provide structured JSON output

## Setup Instructions

### 1. Create a Veryfi Account

1. Go to [https://veryfi.com/](https://veryfi.com/)
2. Sign up for a developer account
3. Choose a pricing plan that fits your needs

### 2. Get API Credentials

After creating your account, you'll receive:
- **Client ID**
- **Client Secret**
- **Username**
- **API Key**

### 3. Configure Environment Variables

Update your `.env` file with your Veryfi credentials:

```env
# Veryfi OCR API Configuration
VERYFI_CLIENT_ID=your_actual_client_id_here
VERYFI_CLIENT_SECRET=your_actual_client_secret_here
VERYFI_USERNAME=your_actual_username_here
VERYFI_API_KEY=your_actual_api_key_here
```

### 4. Test the Integration

1. Run the app
2. Open the receipt scanner
3. Point camera at a receipt
4. The app will automatically use Veryfi OCR if credentials are configured
5. Check console logs for "Processing receipt with Veryfi OCR API..."

## How It Works

### Primary Method: Veryfi OCR
- When Veryfi credentials are configured, the app uses Veryfi API first
- Veryfi returns structured data including line items, totals, merchant info
- Much more accurate than generic OCR + custom parsing

### Fallback Method: Google ML Kit
- If Veryfi credentials are missing or API fails, falls back to Google ML Kit
- Uses the existing text recognition with custom parsing logic
- Still functional but less accurate for complex receipts

### Benefits of Veryfi Integration

1. **Higher Accuracy**: Veryfi is trained specifically on receipt data
2. **Structured Output**: Returns properly categorized line items, not just text
3. **Better Merchant Recognition**: Identifies store names and locations
4. **Automatic Calculations**: Handles taxes, subtotals, and totals correctly
5. **Multiple Formats**: Works with thermal receipts, laser prints, handwritten items

## API Usage & Costs

- Veryfi charges per document processed
- Check their pricing page for current rates
- Free tier available for testing
- API has rate limits depending on your plan

## Troubleshooting

### Veryfi API Errors
- Check that all 4 credentials are correctly set in `.env`
- Verify your Veryfi account is active and has credits
- Check console logs for specific error messages

### Fallback Behavior
- If Veryfi fails, the app automatically falls back to ML Kit
- You'll see "Veryfi OCR failed, falling back to ML Kit" in logs
- The scanner will still work, just with reduced accuracy

### Common Issues
- **401 Unauthorized**: Check Client ID and Client Secret
- **403 Forbidden**: Verify API Key and Username
- **429 Too Many Requests**: You've hit rate limits
- **500 Server Error**: Temporary Veryfi service issue

## Development Notes

The Veryfi integration includes:
- Automatic fallback to ML Kit if Veryfi is unavailable
- 30-second timeout to prevent hanging
- Comprehensive error handling and logging
- Structured data parsing from Veryfi's JSON response</content>
<parameter name="filePath">c:\Users\clyde\local_lekker\VERYFI_OCR_README.md