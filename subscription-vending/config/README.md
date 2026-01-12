# Subscription Configuration

This directory contains subscription configuration files for the subscription vending machine.

## Files

- **`subscriptions.json.example`** - Template file with placeholder values. Copy this to `subscriptions.json` and fill in your actual billing scope information.
- **`subscriptions.json`** - Your actual subscription configuration (not committed to git, contains sensitive billing information).

## Setup

1. Copy the example file:
   ```bash
   cp subscriptions.json.example subscriptions.json
   ```

2. Edit `subscriptions.json` and replace the placeholder billing scope values with your actual Azure billing account information:
   - `YOUR-BILLING-ACCOUNT-ID` - Your Azure billing account ID
   - `YOUR-BILLING-PROFILE-ID` - Your billing profile ID
   - `YOUR-INVOICE-SECTION-ID` - Your invoice section ID

3. You can find your billing scope by running:
   ```bash
   az billing account list --output table
   az billing profile list --account-name <account-name> --output table
   az billing invoice-section list --account-name <account-name> --profile-name <profile-name> --output table
   ```

## Security Note

The `subscriptions.json` file contains sensitive billing information and is excluded from version control via `.gitignore`. Never commit this file to the repository.
