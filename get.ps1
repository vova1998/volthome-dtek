# VoltHome — перенесення бота на цей комп'ютер з резервної копії, без введення токенів і паролів.
# Запуск: PowerShell від імені адміністратора →  irm https://raw.githubusercontent.com/vova1998/volthome-dtek/main/get.ps1 | iex
# Потрібно: файл deye_backup_….zip з чату бота в папці «Завантаження». Секретів у цьому скрипті немає.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"
Write-Host "`n▶ VoltHome: перенесення з резервної копії" -ForegroundColor Green
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "Запустіть PowerShell від імені адміністратора (правою кнопкою → «Запуск від імені адміністратора»)." -ForegroundColor Red; return }
$dl = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
$all = @(Get-ChildItem $dl -Filter "deye_backup_*.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
if (-not $all) {
  Write-Host "У «Завантаженнях» немає файлу deye_backup_….zip." -ForegroundColor Red
  Write-Host "Відкрийте чат бота в Telegram → збережіть останню резервну копію → запустіть команду ще раз."; return }
$seen = @{}; $list = @()
foreach ($f in $all) {
  $site = $f.BaseName -replace '^deye_backup_', '' -replace '_?\d{4}-\d{2}-\d{2}$', ''
  if ($seen.ContainsKey("x$site")) { continue }; $seen["x$site"] = 1; $list += $f }
$b = $list[0]
if ($list.Count -gt 1) {
  Write-Host "Знайшов копії кількох об'єктів — який переносимо на цей комп'ютер?"
  for ($i = 0; $i -lt $list.Count; $i++) { Write-Host "  $($i+1). $($list[$i].Name)" }
  $k = [int](Read-Host "Номер"); $b = $list[$k - 1] }
Write-Host "   копія: $($b.Name)" -ForegroundColor Yellow
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::OpenRead($b.FullName); $t = ""
try {
  $e = $z.GetEntry("settings.json")
  if ($e) { $r = New-Object IO.StreamReader($e.Open(), [Text.Encoding]::UTF8); $st = $r.ReadToEnd() | ConvertFrom-Json; $r.Close()
            $t = "$($st.gh_token)"; if (-not $t) { $t = "$($st.gh_backup_token)" } }
} finally { $z.Dispose() }
if (-not $t) { Write-Host "У цій копії немає токена GitHub. На іншому об'єкті надішліть боту /move — там є інструкція." -ForegroundColor Red; return }
$copy = Join-Path $env:TEMP "volthome_restore.zip"; Copy-Item $b.FullName $copy -Force
$ps1 = Join-Path $env:TEMP "volthome_install.ps1"
Invoke-WebRequest -UseBasicParsing -Headers @{ Authorization = "Bearer $($t.Trim())"; Accept = "application/vnd.github.raw" } `
  "https://api.github.com/repos/vova1998/campi-deye-widget/contents/server/volthome_install.ps1" -OutFile $ps1
$env:GH_TOKEN = $t.Trim(); $env:VH_RESTORE = $copy
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ps1
Remove-Item $ps1 -Force -ErrorAction SilentlyContinue
