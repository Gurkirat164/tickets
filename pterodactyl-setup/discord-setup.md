# Discord Bot Setup Checklist

## 1. Create Discord Application
- Go to https://discord.com/developers/applications
- Create new application
- Note the Application ID (this is your BOT_ID)

## 2. Create Bot User
- Go to Bot section
- Click "Add Bot"
- Copy the bot token (this is your SHARDER_TOKEN/PUBLIC_TOKEN)
- Enable "Message Content Intent" if your bot needs to read message content

## 3. Get Public Key
- Go to General Information
- Copy the Public Key (this is your PUBLIC_PUBLIC_KEY)

## 4. Configure OAuth2
- Go to OAuth2 > URL Generator
- Select scopes: bot, applications.commands
- Select bot permissions based on your bot's needs
- Use the generated URL to invite your bot to test servers

## 5. Set up Interactions Endpoint URL
- Go to General Information
- Set Interactions Endpoint URL to: https://your-domain.com/interactions
- This should point to your HTTP Gateway service

## Required Environment Variables:
BOT_ID=your_application_id
SHARDER_TOKEN=your_bot_token
PUBLIC_TOKEN=your_bot_token
PUBLIC_PUBLIC_KEY=your_public_key
PUBLIC_BOT_ID=your_application_id
