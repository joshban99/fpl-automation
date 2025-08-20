# FPL Analysis Script Configuration Template
# Copy this file to config.ps1 and update with your values

# FPL League Configuration
$leagueId = 5927        # Replace with your FPL league ID
$gameweek = 15          # Update to current gameweek

# Azure OpenAI Configuration
$azureOpenAIEndpoint = "https://your-openai-service.cognitiveservices.azure.com"
$deploymentName = "your-gpt-deployment-name"
$apiVersion = "2025-01-01-preview"

# How to find your League ID:
# 1. Go to your FPL league page
# 2. Look at the URL: https://fantasy.premierleague.com/leagues/XXXXXX/standings/c
# 3. The XXXXXX number is your League ID

# Azure OpenAI Setup:
# 1. Create an Azure OpenAI resource in Azure portal
# 2. Deploy a GPT model (e.g., gpt-4o-mini)
# 3. Get the endpoint URL from the Azure portal
# 4. Update the values above
