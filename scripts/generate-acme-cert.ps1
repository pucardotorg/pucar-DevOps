<#
.SYNOPSIS
  Issue a Let's Encrypt certificate for an oncourts environment using the
  acme-challenge pod's HTTP-01 webroot, then pull the resulting cert files
  down to this machine.

.DESCRIPTION
  1. Prompts you to pick an environment (pucar-stg / pucar-prod)
  2. Validates that an Ingress in that namespace routes
     /.well-known/acme-challenge to the acme-challenge Service/pod
  3. Runs `certbot certonly --webroot` inside the acme-challenge pod's
     certbot container (non-interactively, via kubectl exec - there's no
     way to script keystrokes into an -it shell, so this runs the same
     certbot command directly instead of exec'ing into "sh" first)
  4. certbot's live/<domain>/*.pem files are symlinks into ../../archive/,
     which would dangle if copied as-is without that archive tree. So
     inside the pod we first dereference them (cp -L) into a flat
     directory, then copy just that flat directory out.
  5. Saves cert.pem as both cert.pem and cert.crt, then prints/opens the
     local output folder.

.NOTES
  Requirements: kubectl (pointed at the right cluster/context)
  Env overrides: $env:CERTBOT_EMAIL (default: test@gmail.com)
                 $env:OUT_DIR       (default: ./certs)

.USAGE
  ./generate-acme-cert.ps1
#>

$ErrorActionPreference = "Stop"

$CertbotEmail      = if ($env:CERTBOT_EMAIL) { $env:CERTBOT_EMAIL } else { "test@gmail.com" }
$OutDir            = if ($env:OUT_DIR) { $env:OUT_DIR } else { "./certs" }
$ChallengePath     = "/.well-known/acme-challenge"
$Container         = "certbot"
$RemoteCertbotDir  = "/tmp/letsencrypt"
$RemoteExportDir   = "/tmp/cert-export"

$Environments = @{
  "1" = @{ Namespace = "backbone-stg";  Domain = "oncourts-staging.kerala.gov.in"; Label = "pucar-stg" }
  "2" = @{ Namespace = "backbone-prod"; Domain = "oncourts.kerala.gov.in";         Label = "pucar-prod" }
}

function Die($msg) {
  Write-Host "❌ $msg" -ForegroundColor Red
  exit 1
}

function Require-Cmd($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Die "'$cmd' is required but not found on PATH"
  }
}

function Open-Folder($dir) {
  if ($env:OS -eq "Windows_NT") {
    Start-Process explorer.exe $dir
  } elseif (Get-Command xdg-open -ErrorAction SilentlyContinue) {
    Start-Process xdg-open -ArgumentList $dir
  } elseif (Get-Command open -ErrorAction SilentlyContinue) {
    Start-Process open -ArgumentList $dir
  } else {
    Write-Host "ℹ️  Open this folder manually: $dir"
  }
}

Require-Cmd kubectl

# --- 1. environment selection -------------------------------------------------
Write-Host "Select environment:"
Write-Host "  1. pucar-stg   (oncourts-staging.kerala.gov.in)"
Write-Host "  2. pucar-prod  (oncourts.kerala.gov.in)"
$choice = Read-Host "Enter choice [1-2]"

if (-not $Environments.ContainsKey($choice)) { Die "Invalid choice: $choice" }

$envInfo   = $Environments[$choice]
$Namespace = $envInfo.Namespace
$Domain    = $envInfo.Domain
$EnvName   = $envInfo.Label

Write-Host ""
Write-Host "Environment  : $EnvName"
Write-Host "Namespace    : $Namespace"
Write-Host "Domain       : $Domain"
$currentCtx = (kubectl config current-context) 2>$null
Write-Host "kube context : $currentCtx"
$confirm = Read-Host "Proceed with this kube context/namespace? [y/N]"
if ($confirm -notmatch '^[Yy]$') { Die "Aborted by user" }

# --- 2. validate ingress -> service -> pod ------------------------------------
Write-Host ""
Write-Host "🔍 Looking for an Ingress routing $ChallengePath ..."

$ingressJson = kubectl get ingress -n $Namespace -o json | ConvertFrom-Json

$match = $null
foreach ($ing in $ingressJson.items) {
  foreach ($rule in $ing.spec.rules) {
    foreach ($p in $rule.http.paths) {
      if ($p.path -eq $ChallengePath -or ($p.path -and $p.path.StartsWith($ChallengePath))) {
        $match = [PSCustomObject]@{
          Ingress = $ing.metadata.name
          Host    = $rule.host
          Service = $p.backend.service.name
        }
        break
      }
    }
    if ($match) { break }
  }
  if ($match) { break }
}

if (-not $match) { Die "No Ingress in namespace '$Namespace' routes $ChallengePath. Deploy the acme-challenge chart first." }

$svcJson = kubectl get svc $match.Service -n $Namespace -o json | ConvertFrom-Json
$selectorPairs = $svcJson.spec.selector.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }
$selector = $selectorPairs -join ","
if (-not $selector) { Die "Service '$($match.Service)' has no selector" }

$podName = (kubectl get pods -n $Namespace -l $selector -o jsonpath='{.items[0].metadata.name}')
if (-not $podName) { Die "No pod found behind service '$($match.Service)' (selector: $selector)" }

$podPhase = (kubectl get pod $podName -n $Namespace -o jsonpath='{.status.phase}')
if ($podPhase -ne "Running") { Die "Pod '$podName' is not Running (phase: $podPhase)" }

$containers = (kubectl get pod $podName -n $Namespace -o jsonpath='{.spec.containers[*].name}') -split ' '
if ($containers -notcontains $Container) { Die "Pod '$podName' has no '$Container' container" }

Write-Host "✅ Ingress '$($match.Ingress)' (host: $($match.Host)) routes $ChallengePath -> Service '$($match.Service)' -> Pod '$podName' (Running)"

# --- 3. run certbot inside the pod --------------------------------------------
Write-Host ""
Write-Host "🔐 Requesting certificate for $Domain via certbot in pod '$podName'..."

kubectl exec $podName -n $Namespace -c $Container -- certbot certonly `
  --webroot `
  -w /acme `
  -d $Domain `
  --config-dir $RemoteCertbotDir `
  --work-dir $RemoteCertbotDir `
  --logs-dir $RemoteCertbotDir `
  --key-type rsa `
  --email $CertbotEmail `
  --agree-tos `
  --no-eff-email `
  --non-interactive

if ($LASTEXITCODE -ne 0) { Die "certbot failed inside pod '$podName'" }

Write-Host "✅ Certificate issued in pod at ${RemoteCertbotDir}/live/${Domain}/"

# --- 4. flatten symlinks, then copy files locally -----------------------------
Write-Host ""
Write-Host "📦 Flattening symlinked cert files inside the pod..."
kubectl exec $podName -n $Namespace -c $Container -- sh -c "mkdir -p '$RemoteExportDir' && cp -L '$RemoteCertbotDir/live/$Domain'/*.pem '$RemoteExportDir/'"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$localDir = Join-Path $OutDir "$Domain-$timestamp"
New-Item -ItemType Directory -Force -Path $localDir | Out-Null

Write-Host ""
Write-Host "📥 Copying certificate files to $localDir ..."
kubectl cp "${Namespace}/${podName}:${RemoteExportDir}" $localDir -c $Container

$certPem = Join-Path $localDir "cert.pem"
if (Test-Path $certPem) {
  Copy-Item $certPem (Join-Path $localDir "cert.crt")
  Write-Host "✅ Saved cert.pem as cert.crt"
} else {
  Write-Host "⚠️  cert.pem not found in copied output — check $localDir"
}

# --- 5. done -------------------------------------------------------------------
Write-Host ""
Write-Host "🎉 Done. Certificate files:"
Get-ChildItem $localDir | Format-Table Name, Length

Write-Host ""
Write-Host "📂 $localDir"
Open-Folder $localDir
