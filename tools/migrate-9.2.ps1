#Requires -Version 5.1
param(
  [string]$SRC8 = "C:\Users\dennwu\Course_Scheduling",
  [string]$SRC9 = "C:\Users\dennwu\course-920\course-scheduling-service"
)

$ErrorActionPreference = "Stop"
$reports = Join-Path $SRC9 "tools\reports"
New-Item -ItemType Directory -Force -Path $reports | Out-Null

function Write-Gray($msg){ Write-Host $msg -ForegroundColor DarkGray }
function Write-Good($msg){ Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg){ Write-Host $msg -ForegroundColor Yellow }
function Write-Bad ($msg){ Write-Host $msg -ForegroundColor Red }

function Assert-Dir($p){
  if(-not (Test-Path $p)){ throw "目錄不存在：$p" }
}

function Remove-Bom($path){
  $bytes = [System.IO.File]::ReadAllBytes($path)
  if($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF){
    Write-Gray "移除 BOM: $path"
    $new = New-Object byte[] ($bytes.Length-3)
    [Array]::Copy($bytes,3,$new,0,$new.Length)
    [System.IO.File]::WriteAllBytes($path,$new)
  }
}

function Scan-Bom($root){
  $targets = @("*.drl","*.java","*.properties","*.yml","*.yaml")
  foreach($pat in $targets){
    Get-ChildItem -Path $root -Recurse -Filter $pat | ForEach-Object {
      Remove-Bom $_.FullName
    }
  }
}

function New-Csv([string]$file, [Object[]]$rows){
  if($rows.Count -gt 0){ $rows | Export-Csv -Path $file -NoTypeInformation -Encoding UTF8 }
  else { "" | Out-File -FilePath $file -Encoding UTF8 }
  Write-Good "輸出：$file"
}

function Git-Checkpoint($root){
  Push-Location $root
  try{
    git rev-parse --is-inside-work-tree *> $null
  } catch {
    Write-Warn "此路徑非 Git repo：$root，略過 commit/tag"
    Pop-Location; return
  }

  try{
    git add -A
    git commit -m "chore: BAMOE 9.2 boot baseline (buildable & rules smoke OK)" 2>$null
  } catch {
    Write-Gray "無變更或 commit 失敗（可能已乾淨）：$($_.Exception.Message)"
  }

  $tag = "bamoe-9.2-boot"
  $exists = (git tag -l $tag) -ne ""
  if(-not $exists){
    git tag -a $tag -m "Baseline after boot on BAMOE 9.2"
    Write-Good "打上 tag：$tag"
  } else {
    Write-Gray "tag 已存在：$tag"
  }
  Pop-Location
}

function Scan-LhsRisk($root){
  $rows = @()
  $drls = Get-ChildItem -Path $root -Recurse -Filter *.drl
  foreach($f in $drls){
    $lines = Get-Content -LiteralPath $f.FullName
    for($i=0;$i -lt $lines.Count;$i++){
      $line = $lines[$i]

      # 1) eval(...)
      if($line -match '\beval\s*\('){
        $rows += [pscustomobject]@{
          File=$f.FullName; LineNo=$i+1; Pattern="eval(...)"
          Suggestion="改寫成 Pattern 條件，或以 from/屬性比對取代 eval"
          Snippet=$line.Trim()
        }
      }

      # 2) 直接判空（== null / != null）
      if($line -match '\b[!=]=\s*null'){
        $rows += [pscustomobject]@{
          File=$f.FullName; LineNo=$i+1; Pattern="null 判斷"
          Suggestion="改在 Pattern 內處理：Fact( field != null )；或上游先過濾來源"
          Snippet=$line.Trim()
        }
      }

      # 3) $x: field 綁定（RHS 小寫開頭 → 高風險）
      if($line -match '^\s*\$[A-Za-z_]\w*\s*:\s*[a-z]\w*([ \t\)]|$)'){
        $rows += [pscustomobject]@{
          File=$f.FullName; LineNo=$i+1; Pattern="$x: field 綁定"
          Suggestion="以 Pattern 屬性比對或 from 改寫。如：Lecture( teacher != null, teacher.name == ... )；或 Teacher(...) from lecture.teacher"
          Snippet=$line.Trim()
        }
      }
    }
  }
  return $rows
}

function Scan-DuplicateRules($root){
  $map = @{}
  $locs = @()
  $drls = Get-ChildItem -Path $root -Recurse -Filter *.drl
  foreach($f in $drls){
    $lines = Get-Content -LiteralPath $f.FullName
    for($i=0;$i -lt $lines.Count;$i++){
      $line = $lines[$i]
      if($line -match '^\s*rule\s+"([^"]+)"'){
        $name = $matches[1]
        if(-not $map.ContainsKey($name)){ $map[$name] = 0 }
        $map[$name]++
        $locs += [pscustomobject]@{ Rule=$name; File=$f.FullName; LineNo=$i+1 }
      }
    }
  }
  $dups = $map.GetEnumerator() | Where-Object { $_.Value -gt 1 } | ForEach-Object { $_.Key }
  $rows = @()
  foreach($d in $dups){
    $rows += $locs | Where-Object { $_.Rule -eq $d }
  }
  return $rows
}

function Scan-Getters($root){
  $required = @{
    "Lecture" = @("getTeacher","getPeriod","getRoom","getCourse")
    "Course"  = @("getCurriculum","getStudentSize","getMinWorkingDaySize")
    "Period"  = @("getDay")
    "Room"    = @("getCapacity")
  }
  $src = Join-Path $root "src\main\java"
  $rows = @()

  foreach($cls in $required.Keys){
    $file = Get-ChildItem -Path $src -Recurse -Filter *.java | `
      Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match "class\s+$cls\b" } | Select-Object -First 1
    if(-not $file){
      $rows += [pscustomobject]@{ Class=$cls; Missing="Class not found"; File="-" }
      continue
    }
    $code = Get-Content -LiteralPath $file.FullName -Raw
    foreach($m in $required[$cls]){
      if($code -notmatch [regex]::Escape($m) + "\s*\("){
        $rows += [pscustomobject]@{ Class=$cls; Missing=$m; File=$file.FullName }
      }
    }
  }
  return $rows
}

function Scan-ScoreHolderShim($root){
  $rows = @()
  $drls = Get-ChildItem -Path $root -Recurse -Filter *.drl
  $hasGlobal = $false
  foreach($f in $drls){
    $content = Get-Content -LiteralPath $f.FullName -Raw
    if($content -match '^\s*global\s+[\w\.\$]+\s+ScoreHolderShim\b'm){
      $hasGlobal = $true
    }
  }
  $shim = Get-ChildItem -Path $root -Recurse -Filter ScoreHolderShim.java | Select-Object -First 1
  [pscustomobject]@{
    ScoreHolderShim_Class_Exists = [bool]$shim
    Global_In_DRL_Present       = $hasGlobal
    Shim_Path                   = $shim?.FullName
  }
}

try{
  Assert-Dir $SRC9
  Write-Host "=== BAMOE 9.2 升級助手 ===" -ForegroundColor Cyan
  Write-Gray  "專案路徑：$SRC9"

  Write-Host "`n[1/6] 去除 BOM..." -ForegroundColor Cyan
  Scan-Bom $SRC9

  Write-Host "`n[2/6] 產生 LHS 風險報告..." -ForegroundColor Cyan
  $lhs = Scan-LhsRisk $SRC9
  New-Csv (Join-Path $reports "lhs_risky_patterns.csv") $lhs

  Write-Host "`n[3/6] 檢查重名 rule..." -ForegroundColor Cyan
  $dups = Scan-DuplicateRules $SRC9
  New-Csv (Join-Path $reports "duplicate_rules.csv") $dups

  Write-Host "`n[4/6] 檢查必要 getters..." -ForegroundColor Cyan
  $miss = Scan-Getters $SRC9
  New-Csv (Join-Path $reports "missing_getters.csv") $miss

  Write-Host "`n[5/6] 檢查 ScoreHolderShim/global..." -ForegroundColor Cyan
  $shim = Scan-ScoreHolderShim $SRC9
  $shim | Export-Csv -Path (Join-Path $reports "scoreholder_shim_check.csv") -NoTypeInformation -Encoding UTF8
  Write-Good "輸出：$(Join-Path $reports "scoreholder_shim_check.csv")"

  Write-Host "`n[6/6] 建立基線 commit + tag..." -ForegroundColor Cyan
  Git-Checkpoint $SRC9

  Write-Host "`n完成。報告位於：" -ForegroundColor Green
  Write-Host $reports -ForegroundColor Green
}
catch{
  Write-Bad "腳本失敗：$($_.Exception.Message)"
  exit 1
}
