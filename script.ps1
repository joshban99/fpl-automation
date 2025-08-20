# Fantasy Premier League Analysis Script with Chip Logic
# Enhanced to properly handle Triple Captain and other chips

# Config
$leagueId = "YOUR_LEAGUE_ID_HERE"
$gameweek = 1
$azureOpenAIEndpoint = "https://YOUR-OPENAI-SERVICE.cognitiveservices.azure.com"
$deploymentName = "YOUR-DEPLOYMENT-NAME"
$apiVersion = "2025-01-01-preview"

Write-Host "Analyzing FPL Gameweek $gameweek for League $leagueId..." -ForegroundColor Green

# Function to get chip description
function Get-ChipDescription {
    param($chipCode)
    switch ($chipCode) {
        "3xc" { return "Triple Captain" }
        "bboost" { return "Bench Boost" }
        "freehit" { return "Free Hit" }
        "wildcard" { return "Wildcard" }
        default { return "None" }
    }
}

# Function to calculate chip impact
function Get-ChipImpact {
    param($squad, $chipUsed, $benchPoints)
    
    $impact = [PSCustomObject]@{
        ChipUsed    = Get-ChipDescription $chipUsed
        ExtraPoints = 0
        Description = ""
    }
    
    switch ($chipUsed) {
        "3xc" { 
            $captain = $squad | Where-Object { $_.IsCaptain }
            if ($captain) {
                $impact.ExtraPoints = $captain[0].BasePoints  # Extra points from 3x vs 2x
                $impact.Description = "Captain ($($captain[0].Name)) scored $($captain[0].BasePoints) base points, earning an extra $($impact.ExtraPoints) from Triple Captain"
            }
        }
        "bboost" { 
            # For bench boost, calculate actual bench player points
            $benchPlayers = $squad | Where-Object { $_.IsSub }
            $actualBenchPoints = ($benchPlayers | Measure-Object -Property BasePoints -Sum).Sum
            $impact.ExtraPoints = $actualBenchPoints
            $benchPlayerNames = $benchPlayers | ForEach-Object { "$($_.Name) ($($_.BasePoints)pts)" }
            $impact.Description = "Bench Boost added $actualBenchPoints points from bench: $($benchPlayerNames -join ', ')"
        }
        "freehit" { 
            $impact.Description = "Free Hit used - team reverts next week"
        }
        "wildcard" { 
            $impact.Description = "Wildcard used - unlimited free transfers"
        }
        default { 
            $impact.Description = "No chip used"
        }
    }
    
    return $impact
}

# Get league standings (managers + entry IDs)
$leagueUrl = "https://fantasy.premierleague.com/api/leagues-classic/$leagueId/standings/"
$leagueData = Invoke-RestMethod -Uri $leagueUrl

# Load player dictionary (for names/positions)
$players = Invoke-RestMethod -Uri "https://fantasy.premierleague.com/api/bootstrap-static/"

# Create team name lookup from the API data
$teamLookup = @{}
foreach ($team in $players.teams) {
    $teamLookup[$team.id] = $team.name
}

# Loop through each team in the league
# Get live player points for the gameweek
$liveUrl = "https://fantasy.premierleague.com/api/event/$gameweek/live/"
$liveData = Invoke-RestMethod -Uri $liveUrl
$playerPointsMap = @{}
foreach ($element in $liveData.elements) {
    $playerPointsMap[$element.id] = $element.stats.total_points
}

$expandedResults = @()
foreach ($team in $leagueData.standings.results) {
    $entryId = $team.entry
    $manager = $team.player_name
    $teamName = $team.entry_name
    $totalPoints = $team.total
    $rank = $team.rank
    $prevRank = $team.last_rank
    $rankChange = $rank - $prevRank

    # Get team picks for the current gameweek
    $teamUrl = "https://fantasy.premierleague.com/api/entry/$entryId/event/$gameweek/picks/"
    $picksData = Invoke-RestMethod -Uri $teamUrl

    # Get team picks for previous gameweek
    $prevGw = $gameweek - 1
    $prevPicksData = $null
    if ($prevGw -ge 1) {
        $prevTeamUrl = "https://fantasy.premierleague.com/api/entry/$entryId/event/$prevGw/picks/"
        try { $prevPicksData = Invoke-RestMethod -Uri $prevTeamUrl } catch { $prevPicksData = $null }
    }

    # Get transfer info
    $transfersUrl = "https://fantasy.premierleague.com/api/entry/$entryId/transfers/"
    $transfersData = Invoke-RestMethod -Uri $transfersUrl
    $gwTransfers = $transfersData | Where-Object { $_.event -eq $gameweek }

    # Extract chip used
    $chipUsed = if ($picksData.active_chip) { $picksData.active_chip } else { "-" }
    $prevChipUsed = if ($prevPicksData -and $prevPicksData.active_chip) { $prevPicksData.active_chip } else { "-" }

    # Extract captain and vice for current and previous week
    $captain = $null; $viceCaptain = $null
    foreach ($pick in $picksData.picks) {
        if ($pick.is_captain -eq $true) { $captain = $pick.element }
        if ($pick.is_vice_captain -eq $true) { $viceCaptain = $pick.element }
    }
    $captainName = ($players.elements | Where-Object { $_.id -eq $captain }).web_name
    $viceName = ($players.elements | Where-Object { $_.id -eq $viceCaptain }).web_name

    $prevCaptain = $null; $prevViceCaptain = $null
    if ($prevPicksData) {
        foreach ($pick in $prevPicksData.picks) {
            if ($pick.is_captain -eq $true) { $prevCaptain = $pick.element }
            if ($pick.is_vice_captain -eq $true) { $prevViceCaptain = $pick.element }
        }
    }
    $prevCaptainName = ($players.elements | Where-Object { $_.id -eq $prevCaptain }).web_name
    $prevViceName = ($players.elements | Where-Object { $_.id -eq $prevViceCaptain }).web_name

    # Squad details for current and previous week
    $squad = @()
    foreach ($pick in $picksData.picks) {
        $player = $players.elements | Where-Object { $_.id -eq $pick.element }
        # Get player points for the gameweek from live data
        $playerPoints = $playerPointsMap[$pick.element]
            
        # Calculate points based on chip used and captain status
        $finalPoints = $playerPoints
        if ($pick.is_captain) {
            if ($chipUsed -eq "3xc") {
                # Triple Captain chip - captain gets 3x points
                $finalPoints = $playerPoints * 3
            }
            else {
                # Normal captain - 2x points
                $finalPoints = $playerPoints * 2
            }
        }
            
        $squad += [PSCustomObject]@{
            Name          = $player.web_name
            Position      = $player.element_type
            Team          = $teamLookup[$player.team]  # Convert team ID to team name
            IsCaptain     = $pick.is_captain
            IsViceCaptain = $pick.is_vice_captain
            IsStarter     = $pick.position -le 11
            IsSub         = $pick.position -gt 11
            Points        = $finalPoints
            BasePoints    = $playerPoints  # Original points before captain multiplier
        }
    }
    $prevSquad = @()
    if ($prevPicksData) {
        # Get live player points for previous gameweek
        $prevLiveUrl = "https://fantasy.premierleague.com/api/event/$prevGw/live/"
        $prevPlayerPointsMap = @{}
        try {
            $prevLiveData = Invoke-RestMethod -Uri $prevLiveUrl
            foreach ($element in $prevLiveData.elements) {
                $prevPlayerPointsMap[$element.id] = $element.stats.total_points
            }
        }
        catch {}
        foreach ($pick in $prevPicksData.picks) {
            $player = $players.elements | Where-Object { $_.id -eq $pick.element }
            $playerPoints = $prevPlayerPointsMap[$pick.element]
                
            # Calculate points based on previous week's chip and captain status
            $finalPoints = $playerPoints
            if ($pick.is_captain) {
                if ($prevChipUsed -eq "3xc") {
                    # Triple Captain chip - captain gets 3x points
                    $finalPoints = $playerPoints * 3
                }
                else {
                    # Normal captain - 2x points
                    $finalPoints = $playerPoints * 2
                }
            }
                
            $prevSquad += [PSCustomObject]@{
                Name          = $player.web_name
                Position      = $player.element_type
                Team          = $teamLookup[$player.team]  # Convert team ID to team name
                IsCaptain     = $pick.is_captain
                IsViceCaptain = $pick.is_vice_captain
                IsStarter     = $pick.position -le 11
                IsSub         = $pick.position -gt 11
                Points        = $finalPoints
                BasePoints    = $playerPoints  # Original points before captain multiplier
            }
        }
    }

    # Bench points and autosubs
    $benchPoints = $picksData.entry_history.points_on_bench
    $autosubs = $picksData.automatic_subs

    # Transfers summary
    $transfersSummary = @()
    foreach ($t in $gwTransfers) {
        $inPlayer = ($players.elements | Where-Object { $_.id -eq $t.element_in }).web_name
        $outPlayer = ($players.elements | Where-Object { $_.id -eq $t.element_out }).web_name
        $transfersSummary += [PSCustomObject]@{
            In   = $inPlayer
            Out  = $outPlayer
            Cost = $t.cost
        }
    }

    # Calculate changes
    $squadIn = @(); $squadOut = @()
    if ($prevSquad.Count -gt 0) {
        $currNames = $squad | ForEach-Object { $_.Name }
        $prevNames = $prevSquad | ForEach-Object { $_.Name }
        $squadIn = $currNames | Where-Object { $prevNames -notcontains $_ }
        $squadOut = $prevNames | Where-Object { $currNames -notcontains $_ }
    }

    # Calculate captain points based on chip used
    $captainPlayer = $squad | Where-Object { $_.IsCaptain }
    $viceCaptainPlayer = $squad | Where-Object { $_.IsViceCaptain }
    
    $captainPoints = if ($captainPlayer) { $captainPlayer[0].Points } else { 0 }
    $viceCaptainPoints = if ($viceCaptainPlayer) { $viceCaptainPlayer[0].BasePoints } else { 0 }
    
    # Enhanced chip analysis
    $chipImpact = Get-ChipImpact -squad $squad -chipUsed $chipUsed -benchPoints $benchPoints
    
    $chipAnalysis = [PSCustomObject]@{
        ChipUsed            = $chipUsed
        ChipName            = Get-ChipDescription $chipUsed
        IsTripleCaptain     = ($chipUsed -eq "3xc")
        IsBenchBoost        = ($chipUsed -eq "bboost")
        IsFreeHit           = ($chipUsed -eq "freehit")
        IsWildcard          = ($chipUsed -eq "wildcard")
        CaptainMultiplier   = if ($chipUsed -eq "3xc") { 3 } elseif ($captainPlayer) { 2 } else { 1 }
        ExtraPointsFromChip = $chipImpact.ExtraPoints
        ImpactDescription   = $chipImpact.Description
    }

    # Create simplified squad - only essential data
    $simplifiedSquad = $squad | ForEach-Object {
        [PSCustomObject]@{
            Name    = $_.Name
            Team    = $_.Team
            Points  = $_.Points
            Captain = if ($_.IsCaptain) { "C" } elseif ($_.IsViceCaptain) { "VC" } else { "" }
            Starter = $_.IsStarter
        }
    }

    $expandedResults += [PSCustomObject]@{
        Manager           = $manager
        TeamName          = $teamName
        Gameweek          = $gameweek
        GWPoints          = $team.event_total
        Captain           = $captainName
        ViceCaptain       = $viceName
        ChipUsed          = $chipUsed
        ChipAnalysis      = $chipAnalysis
        TotalPoints       = $totalPoints
        Rank              = $rank
        RankChange        = $rankChange
        Squad             = $simplifiedSquad  # Use simplified squad instead
        BenchPoints       = $benchPoints
        Autosubs          = $autosubs
        Transfers         = $transfersSummary
        CaptainPoints     = $captainPoints
        ViceCaptainPoints = $viceCaptainPoints
        PreviousWeek      = [PSCustomObject]@{
            Gameweek    = $prevGw
            Captain     = $prevCaptainName
            ViceCaptain = $prevViceName
            ChipUsed    = $prevChipUsed
            # Squad data removed to reduce JSON size
        }
        SquadIn           = $squadIn
        SquadOut          = $squadOut
    }
}

# Simplified output - removed separate analysis sections to reduce size
$finalOutput = [PSCustomObject]@{
    LeagueInfo  = [PSCustomObject]@{
        LeagueId     = $leagueId
        Gameweek     = $gameweek
        AnalysisDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    ManagerData = $expandedResults
}

# Output as JSON for ChatGPT analysis
$finalOutput | ConvertTo-Json -Depth 6
Write-Host "Data exported to fpl.json" -ForegroundColor Green

# Get Azure access token and call OpenAI
Write-Host "Generating AI summary..." -ForegroundColor Green
$accessToken = (Get-AzAccessToken -ResourceUrl "https://cognitiveservices.azure.com/").token
$headers = @{
    "Authorization" = "Bearer $accessToken"
}

$messages = @()
$messages += @{
    role    = 'system'
    content = "You are an AI assistant designed to analyze and summarize Fantasy Premier League (FPL) gameweek data for a workplace league. You will be provided with a JSON file containing detailed information about team performances, player points, transfers, captain choices, and rankings.
Your task is to generate a concise, engaging, and informative summary of the gameweek. The summary should include:
Top Performers: Highlight the top 3 managers based on points earned this gameweek.
Biggest Climbers: Mention any significant changes in overall rankings.
Captain Choices: Note popular captain picks and how they performed, mention the top 3 most popular captains.
Transfer Impact: Identify any smart transfers that paid off.
Bench Boosts or Chips Used: Mention if any chips (e.g., Triple Captain, Bench Boost) were used and their impact.
Fun Fact or Banter: Add a light-hearted comment or stat (e.g., lowest score, unlucky benching, etc.) to keep the tone engaging.
Tone: Friendly, slightly competitive, and suitable for a workplace audience. Avoid overly technical jargon and keep the summary under 500 words."
}
$messages += @{
    role    = 'user'
    content = "Analyze this Fantasy Premier League gameweek data focusing on the managers/people: $($finalOutput | ConvertTo-Json -Depth 4 -Compress)"
}

$body = [ordered]@{
    messages = $messages
} | ConvertTo-Json
 
$url = "$azureOpenAIEndpoint/openai/deployments/$deploymentName/chat/completions?api-version=$apiVersion"
 
$response = Invoke-RestMethod -Uri $url -Headers $headers -Body $body -Method Post -ContentType 'application/json'

$response.choices.message.content | Clip
Write-Host "AI summary copied to clipboard!" -ForegroundColor Green
Write-Host "Analysis complete. Check fpl.json for detailed data." -ForegroundColor Green
