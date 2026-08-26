Write-Host "==========================================="
Write-Host " Git Reset To Specific Commit Started"
Write-Host "==========================================="

# Commit you want to keep
# $CommitId = "b14d2e2e5c93b05430cf0348e61c415254ecc4ed"

# Get current branch name
$BranchName = git branch --show-current

if ([string]::IsNullOrWhiteSpace($BranchName))
{
    Write-Host "ERROR: You are in detached HEAD state." 
    Write-Host "Checkout your branch first:"
    Write-Host "git checkout main"
    exit 1
}

Write-Host "Current Branch: $BranchName"
Write-Host "Target Commit : $CommitId"

# Fetch latest refs
git fetch origin

if ($LASTEXITCODE -ne 0)
{
    Write-Host "Git fetch failed."
    exit 1
}

# Reset local branch
git reset --hard $CommitId


if ($LASTEXITCODE -ne 0)
{
    Write-Host "Git reset failed."
    exit 1
}

# Force push to remote
git push origin $BranchName --force

if ($LASTEXITCODE -ne 0)
{
    Write-Host "Git push failed."
    exit 1
}

Write-Host ""
Write-Host "==========================================="
Write-Host " SUCCESS"
Write-Host " Branch : $BranchName"
Write-Host " HEAD    : $CommitId"
Write-Host " Newer commits removed locally and remotely"
Write-Host "==========================================="