$ErrorActionPreference = "Stop"

$root = Get-Location
$pomPath = Join-Path $root "pom.xml"
if (-not (Test-Path $pomPath)) { Write-Host "找不到 pom.xml" -ForegroundColor Red; exit 1 }

# 備份
$bak = "$pomPath.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item $pomPath $bak -Force

# 載入 POM
[xml]$pom = Get-Content -Raw -LiteralPath $pomPath
$ns = $pom.project.NamespaceURI

function New-PomElem([string]$name) {
  return $pom.CreateElement($name, $ns)
}

# 取得 <dependencies>
$depsNode = $pom.project.dependencies
if ($null -eq $depsNode) {
  Write-Host "POM 沒有 <dependencies>，應該不是 Kogito 觸發產碼的情況。" -ForegroundColor Yellow
  $depsNode = New-PomElem 'dependencies'
  $pom.project.AppendChild($depsNode) | Out-Null
}

# 找出要搬走的依賴（Kogito）
$allDeps = @($depsNode.dependency)  # 單/多項都可枚舉
$toMove  = @()
foreach ($d in $allDeps) {
  $gid = [string]$d.groupId
  $aid = [string]$d.artifactId
  if (($gid -eq 'org.kie.kogito') -or ($aid -like '*kogito-*')) {
    $toMove += $d
  }
}

# 準備 <profiles>/<profile id="kogito">
$profiles = $pom.project.profiles
if ($null -eq $profiles) {
  $profiles = New-PomElem 'profiles'
  $pom.project.AppendChild($profiles) | Out-Null
}

$kogitoProfile = $null
foreach ($p in @($profiles.profile)) {
  if ([string]$p.id -eq 'kogito') { $kogitoProfile = $p; break }
}
if ($null -eq $kogitoProfile) {
  $kogitoProfile = New-PomElem 'profile'
  $id = New-PomElem 'id'; $id.InnerText = 'kogito'; $kogitoProfile.AppendChild($id) | Out-Null
  $act = New-PomElem 'activation'
  $abd = New-PomElem 'activeByDefault'; $abd.InnerText = 'false'
  $act.AppendChild($abd) | Out-Null
  $kogitoProfile.AppendChild($act) | Out-Null
  $profiles.AppendChild($kogitoProfile) | Out-Null
}

$pDeps = $kogitoProfile.dependencies
if ($null -eq $pDeps) { $pDeps = New-PomElem 'dependencies'; $kogitoProfile.AppendChild($pDeps) | Out-Null }

# 搬移
foreach ($d in $toMove) {
  $clone = $d.Clone()
  [void]$pDeps.AppendChild($clone)
  [void]$depsNode.RemoveChild($d)
}
Write-Host ("已移動 {0} 個 Kogito 依賴到 <profile id=""kogito"">" -f $toMove.Count) -ForegroundColor Green

# 存檔
$pom.Save($pomPath)

# 顯示摘要
Write-Host "`n== 目前預設 <dependencies> 仍存在的依賴 ==" -ForegroundColor Cyan
foreach($d in @($pom.project.dependencies.dependency)){ "{0}:{1}" -f $d.groupId,$d.artifactId | Write-Host }

Write-Host "`n== <profile id=""kogito""> 內的依賴 ==" -ForegroundColor Cyan
foreach($p in @($pom.project.profiles.profile)){
  if ([string]$p.id -eq "kogito" -and $p.dependencies){
    foreach($d in @($p.dependencies.dependency)){ "{0}:{1}" -f $d.groupId,$d.artifactId | Write-Host }
  }
}

# 追加停用 Kogito 產碼的 flags（雙保險）
$propsPath = Join-Path $root 'src\main\resources\application.properties'
if (-not (Test-Path $propsPath)) { New-Item -ItemType File -Path $propsPath -Force | Out-Null }
$props = Get-Content -Raw -LiteralPath $propsPath
if ($null -eq $props) { $props = '' }
$EOL = "`r`n"
$need = @(
  'quarkus.kogito.generate.rules=false',
  'quarkus.kogito.generate.processes=false',
  'quarkus.kogito.generate.decisions=false',
  'quarkus.kogito.generate.predictions=false',
  'quarkus.kogito.generate.usertasks=false'
)
foreach($ln in $need){
  if ($props -notmatch [regex]::Escape($ln)) {
    if ([string]::IsNullOrWhiteSpace($props)) { $props = $ln + $EOL }
    else { $props = $props.TrimEnd() + $EOL + $ln + $EOL }
  }
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($propsPath, $props, $utf8)
Write-Host "`n已更新 application.properties（停用 Kogito 產碼）" -ForegroundColor Green

# 試打包
Write-Host "`n開始嘗試打包（不跑測試）..." -ForegroundColor Cyan
cmd /c "mvn -q -DskipTests package && echo PACKAGE OK || echo PACKAGE FAIL"
