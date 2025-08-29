# patch-drl-main.ps1  一鍵修正 DRL + 關閉 Kogito 規則 codegen + 驗證
$ErrorActionPreference = 'Stop'
$root = Get-Location
$utf8 = [System.Text.UTF8Encoding]::new($false)
$EOL  = "`r`n"

function Ensure-Text([string]$txt){ if($null -eq $txt){ "" } else { $txt } }

function Patch-Drl([string]$path) {
  $txt = Ensure-Text (Get-Content $path -Raw -ErrorAction SilentlyContinue)

  # 1) package
  if ($txt -notmatch '^\s*package\s+[A-Za-z0-9_\.]+') {
    $txt = "package curriculumcourse.curriculumcourse${EOL}${txt}"
  }
  # 2) dialect
  if ($txt -notmatch '^\s*dialect\s+"java"') {
    $txt = $txt -replace '^(package[^\r\n]*\r?\n)', ("`$1dialect ""java""${EOL}")
  }
  # 3) imports
  if ($txt -notmatch '^\s*import\s+java\.util\.Set')     { $txt = $txt -replace '^(package.*?\r?\n(?:\s*dialect.*?\r?\n)?)', ("`$1import java.util.Set${EOL}") }
  if ($txt -notmatch '^\s*import\s+java\.util\.HashSet') { $txt = $txt -replace '^(package.*?\r?\n(?:\s*dialect.*?\r?\n)?(?:\s*import[^\r\n]*\r?\n)*)', ("`$1import java.util.HashSet${EOL}") }

  # 4) function：避免在 result 寫 .size()
  if ($txt -notmatch 'function\s+int\s+countInt\s*\(') {
    $txt = $txt.TrimEnd() + $EOL + 'function int countInt(Set s) { return s.size(); }' + $EOL
  }

  # 5) 無點號版本 Minimum working days（巢狀屬性在 pattern 綁定；action/result 不呼叫方法）
  $newRule = @"
rule "Minimum working days"
when
  `$course : Course( `$min : minimumWorkingDays )
  Number( `$distinct : intValue ) from accumulate(
     // 綁定 day；action/result 不做點號呼叫
     Lecture( course == `$course, `$day : period.day ),
     init( Set days = new HashSet(); ),
     action( days.add( `$day ); ),
     reverse( ),
     result( countInt(days) )
  )
  eval( `$distinct < `$min )
then
  scoreHolder.addSoftPenalty(kcontext, `$min - `$distinct);
end
"@

  $rx = [regex]::new('(^|\r?\n)\s*rule\s*"Minimum working days".*?\bend\b','Singleline')
  if ($rx.IsMatch($txt)) { $txt = $rx.Replace($txt, "${EOL}$newRule${EOL}", 1) }
  else                   { $txt = $txt.TrimEnd() + "${EOL}${EOL}$newRule${EOL}" }

  [System.IO.File]::WriteAllText($path, $txt, $utf8)
}

# 找到所有 constraints.drl（main + test）
$targets = @()
$mainGood = Join-Path $root 'src\main\resources\curriculumcourse\curriculumcourse\constraints.drl'
if (Test-Path $mainGood) { $targets += $mainGood }
$targets += (Get-ChildItem -Path (Join-Path $root 'src\main\resources') -Recurse -Filter constraints.drl -EA SilentlyContinue | Select-Object -Expand FullName)
$targets += (Get-ChildItem -Path (Join-Path $root 'src\test\resources') -Recurse -Filter constraints.drl -EA SilentlyContinue | Select-Object -Expand FullName)
$targets = $targets | Sort-Object -Unique
if ($targets.Count -eq 0) { Write-Host "找不到任何 constraints.drl" -ForegroundColor Red; exit 1 }

# 先備份再 patch
foreach ($p in $targets) {
  $bak = "$p.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item $p $bak -Force
  Patch-Drl $p
  Write-Host "patched $p (備份: $bak)" -ForegroundColor Green
}

# 顯示主檔片段（規則附近 30 行）
$show = $targets | Where-Object { $_ -like "*\src\main\resources\*" } | Select-Object -First 1
if (-not $show) { $show = $targets[0] }
$lines = Get-Content $show
$hit   = ($lines | Select-String -Pattern '^\s*rule\s*"Minimum working days"').LineNumber
if ($hit) {
  $from = [Math]::Max(1, $hit - 3); $to = [Math]::Min($lines.Count, $hit + 27)
  Write-Host "`n=== $show (行 $hit 附近) ===" -ForegroundColor Cyan
  for($i=$from; $i -le $to; $i++){ "{0,5}: {1}" -f $i, $lines[$i-1] | Write-Host }
}

# 關閉 Kogito 規則 codegen（避免 Quarkus build 解析 DRL）
$appProps = Join-Path $root 'src\main\resources\application.properties'
if (-not (Test-Path $appProps)) { New-Item -ItemType File -Path $appProps -Force | Out-Null }
$appTxt = Ensure-Text (Get-Content $appProps -Raw)
$need = @(
  'quarkus.kogito.generate.rules=false',
  'quarkus.kogito.generate.processes=false',
  'quarkus.kogito.generate.decisions=false',
  'quarkus.kogito.generate.predictions=false',
  'quarkus.kogito.generate.usertasks=false'
)
foreach($ln in $need){
  if ($appTxt -notmatch [regex]::Escape($ln)) { $appTxt = ($appTxt.TrimEnd() + "${EOL}$ln${EOL}") }
}
[System.IO.File]::WriteAllText($appProps, $appTxt, $utf8)
Write-Host "`n已更新 $appProps 以略過 Kogito 規則 codegen。" -ForegroundColor Yellow

# 驗證
Write-Host "`n== 1) Drools 單元測試 ==" -ForegroundColor Cyan
cmd /c "mvn -q -Dtest=ConstraintsDrl* -Ddrools.wiring=dynamic test && echo TESTS OK || echo TESTS FAIL"

Write-Host "`n== 2) Quarkus 打包（略過測試） ==" -ForegroundColor Cyan
cmd /c "mvn -q -DskipTests package && echo PACKAGE OK || echo PACKAGE FAIL"
