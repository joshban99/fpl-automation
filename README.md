# Fantasy Premier League Analysis Script

This PowerShell script analyzes Fantasy Premier League (FPL) gameweek data for a workplace league and generates an AI-powered summary using Azure OpenAI.

## Features

- Fetches league standings and team data from the FPL API
- Analyzes player performances, captain choices, and transfers
- Calculates chip impact (Triple Captain, Bench Boost, Free Hit, Wildcard)
- Generates detailed JSON output with team analysis
- Creates an AI-powered summary using Azure OpenAI
- Copies the summary to clipboard for easy sharing

## Prerequisites

- PowerShell 5.1 or later
- Azure PowerShell module (`Az` module)
- Valid Azure subscription with OpenAI service deployed
- Internet connection to access FPL API

## Quick Start

1. **Login to Azure**:
   ```powershell
   Connect-AzAccount
   ```

2. **Run the script**:
   ```powershell
   .\fpl.ps1
   ```

3. **Get your summary** - it will be copied to your clipboard automatically!

## How to Find Your League ID

1. Go to your FPL league page in a web browser
2. The URL will look like: `https://fantasy.premierleague.com/leagues/XXXXXX/standings/c`
3. The number (XXXXXX) is your League ID

## Authentication

The script uses Azure PowerShell authentication. Make sure you're logged in:
```powershell
Connect-AzAccount
```

The script will automatically obtain an access token for Azure Cognitive Services.

## Usage

1. **Configure the script** with your league ID and Azure OpenAI details
2. **Set the current gameweek** number
3. **Run the script** from PowerShell:
   ```powershell
   .\fpl.ps1
   ```

## Output

**AI Summary** - Copied to clipboard, includes:
   - Top performers of the gameweek
   - Biggest rank changes
   - Popular captain choices and their performance
   - Transfer highlights
   - Chip usage and impact
   - Fun facts and workplace-friendly banter

## Data Included in Analysis

- **Manager Performance**: Points earned, rank changes, total points
- **Team Selection**: Squad composition, captain/vice-captain choices
- **Transfers**: Players bought and sold, transfer costs
- **Chips**: Usage of Triple Captain, Bench Boost, Free Hit, Wildcard
- **Bench Analysis**: Points left on bench, automatic substitutions
- **Historical Comparison**: Changes from previous gameweek

## Chip Logic

The script properly handles all FPL chips:

- **Triple Captain**: Captain gets 3x points instead of 2x
- **Bench Boost**: All bench players' points are included
- **Free Hit**: Team reverts next week (noted in analysis)
- **Wildcard**: Unlimited transfers (noted in analysis)

## Sample AI Summary Output

The AI generates workplace-friendly summaries like:

> **Gameweek 15 Summary**
> 
> Top performers this week were John (85 pts), Sarah (78 pts), and Mike (72 pts). 
> Captain Salah was the popular choice, rewarding his backers with 24 points. 
> Jane's triple captain on Haaland paid off massively with 42 points! 
> Smart transfer of the week goes to Tom who brought in Wilson just in time for his brace.

## Troubleshooting

- **Authentication errors**: Ensure you're logged into Azure with `Connect-AzAccount`
- **API rate limits**: The FPL API has rate limits; add delays if needed
- **JSON file size**: Large leagues may generate large JSON files
- **Network issues**: Script requires internet access for FPL API calls

## Customization

You can modify the AI prompt in the script to change the summary style:
- Adjust the tone (more/less competitive)
- Change the summary length
- Focus on different aspects of the data
- Add custom analysis points

## Security Notes

- Keep your Azure OpenAI endpoint URLs private
- Don't share the generated access tokens
- Consider the sensitivity of league data when sharing summaries

## License

This script is provided as-is for personal/workplace use. Please respect FPL's terms of service when using their API.
