<#
.SYNOPSIS
  Apply a previously-generated Let's Encrypt certificate to the OpenShift
  edge Route that terminates TLS for an oncourts environment, backing up
  whatever certificate/key/CA the Route currently has before overwriting it.

.DESCRIPTION
  Route mapping:
    pucar-stg  -> Route 'oncourts-staging' in namespace 'backbone-stg'
    pucar-prod -> Route 'oncourts'         in namespace 'backbone-prod'

  Field mapping (Route spec.tls.* <- local file, in the directory you point
  this script at):
    certificate   <- cert.pem
    key           <- privkey.pem
    caCertificate <- fullchain.pem

  The patch is written to a temp file and applied via --patch-file rather
  than -p '<json>' on the command line, since a cert+chain payload can be
  several KB and inline args get unwieldy.

.NOTES
  Requirements: kubectl (pointed at the right cluster/context)
  Env overrides: $env:BACKUP_DIR (default: ./certs-backup)

.USAGE
  ./update-route-cert.ps1
#>

$ErrorActionPreference = "Stop"

$BackupDir = if ($env:BACKUP_DIR) { $env:BACKUP_DIR } else { "./certs-backup" }

$Environments = @{
  "1" = @{ Namespace = "backbone-stg";  RouteName = "oncourts-staging"; Label = "pucar-stg" }
  "2" = @{ Namespace = "backbone-prod"; RouteName = "oncourts";         Label = "pucar-prod" }
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

Require-Cmd kubectl

# --- 1. environment selection -------------------------------------------------
Write-Host "Select environment:"
Write-Host "  1. pucar-stg   (Route 'oncourts-staging' in namespace backbone-stg)"
Write-Host "  2. pucar-prod  (Route 'oncourts' in namespace backbone-prod)"
$choice = Read-Host "Enter choice [1-2]"

if (-not $Environments.ContainsKey($choice)) { Die "Invalid choice: $choice" }

$envInfo   = $Environments[$choice]
$Namespace = $envInfo.Namespace
$RouteName = $envInfo.RouteName
$EnvName   = $envInfo.Label

Write-Host ""
Write-Host "Environment  : $EnvName"
Write-Host "Namespace    : $Namespace"
Write-Host "Route        : $RouteName"
$currentCtx = (kubectl config current-context) 2>$null
Write-Host "kube context : $currentCtx"

kubectl get route $RouteName -n $Namespace *> $null
if ($LASTEXITCODE -ne 0) { Die "Route '$RouteName' not found in namespace '$Namespace'" }

$confirm = Read-Host "Proceed with this kube context/namespace/route? [y/N]"
if ($confirm -notmatch '^[Yy]$') { Die "Aborted by user" }

# --- 2. path to generated certs -----------------------------------------------
Write-Host ""
$CertDir = Read-Host "Path to the generated certificate directory (contains cert.pem, privkey.pem, fullchain.pem)"

if (-not (Test-Path $CertDir -PathType Container)) { Die "Directory not found: $CertDir" }

$CertFile = Join-Path $CertDir "cert.pem"
$KeyFile  = Join-Path $CertDir "privkey.pem"
$CaFile   = Join-Path $CertDir "fullchain.pem"

foreach ($f in @($CertFile, $KeyFile, $CaFile)) {
  if (-not (Test-Path $f -PathType Leaf)) { Die "Missing expected file: $f" }
}

Write-Host "✅ Found cert.pem, privkey.pem, fullchain.pem in $CertDir"

# --- 3. back up the route's current certificate --------------------------------
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $BackupDir "$RouteName-$timestamp"
New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

Write-Host ""
Write-Host "💾 Backing up current Route certificate to $backupPath ..."
(kubectl get route $RouteName -n $Namespace -o jsonpath='{.spec.tls.certificate}')   | Set-Content -NoNewline (Join-Path $backupPath "cert.pem")
(kubectl get route $RouteName -n $Namespace -o jsonpath='{.spec.tls.key}')           | Set-Content -NoNewline (Join-Path $backupPath "privkey.pem")
(kubectl get route $RouteName -n $Namespace -o jsonpath='{.spec.tls.caCertificate}') | Set-Content -NoNewline (Join-Path $backupPath "fullchain.pem")

if ((Get-Item (Join-Path $backupPath "cert.pem")).Length -eq 0) {
  Write-Host "⚠️  Route had no existing certificate to back up (file is empty)."
}
Write-Host "✅ Backed up old certificate to $backupPath"

# --- 4. apply the new certificate -----------------------------------------------
Write-Host ""
Write-Host "🔐 Applying new certificate to Route '$RouteName'..."

$certContent = Get-Content -Raw $CertFile
$keyContent  = Get-Content -Raw $KeyFile
$caContent   = Get-Content -Raw $CaFile

$patchObj = @{ spec = @{ tls = @{ certificate = $certContent; key = $keyContent; caCertificate = $caContent } } }
$patchFile = New-TemporaryFile
try {
  $patchObj | ConvertTo-Json -Depth 10 | Set-Content -NoNewline $patchFile

  kubectl patch route $RouteName -n $Namespace --type=merge --patch-file=$patchFile
  if ($LASTEXITCODE -ne 0) { Die "kubectl patch failed for Route '$RouteName'" }
} finally {
  Remove-Item $patchFile -ErrorAction SilentlyContinue
}

Write-Host "✅ Route '$RouteName' updated"

# --- 5. done ---------------------------------------------------------------------
Write-Host ""
Write-Host "🎉 Done."
Write-Host "Route host        : $(kubectl get route $RouteName -n $Namespace -o jsonpath='{.spec.host}')"
Write-Host "Backup of old cert: $backupPath"
