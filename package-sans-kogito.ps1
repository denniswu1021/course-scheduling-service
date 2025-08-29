# package-sans-kogito.ps1
# 暫時將 src/main/resources 下會觸發 Kogito codegen 的檔案(.drl/.dmn/.bpmn*/.pmml*)改為 .off，打包後再還原
$ErrorActionPreference = 'Stop'
$root    = Get-Location
$mainRes = Join-Path $root 'src\main\resources'
if (-not (Test-Path $mainRes)) { Write-Host "找不到 $mainRes" -ForegroundColor Red; exit 1 }

# 1) 揪出可能觸發 codegen 的檔
$patterns = @('*.drl','*.dmn','*.bpmn','*.bpmn2','*.pmml','*.pmml.xml')
$files = @()
foreach($pat in $patterns){
  $files += Get-ChildItem -Path $mainRes -Recurse -File -Filter $pat -ErrorAction SilentlyContinue
}
$files = $files | Sort-Object -Property FullName -Unique

if ($files.Count -eq 0) {
  Write-Host "main 資源下沒有會觸發 Kogito 的檔案，直接打包..." -ForegroundColor Yellow
} else {
  Write-Host "將暫停下列檔案以避免 Kogito codegen：" -ForegroundColor Cyan
  $files | ForEach-Object { " - " + $_.FullName } | Write-Host
}

# 2) 逐一改名為 .off（若已是 .off 就跳過）
$renamed = @()
foreach($f in $files){
  $off = $f.FullName + '.off'
  if (-not (Test-Path $off)) {
    Rename-Item -LiteralPath $f.FullName -NewName ($f.Name + '.off') -Force
    $renamed += [pscustomobject]@{ Off=$off; Orig=$f.FullName }
  }
}

# 3) 打包（略過測試）
try {
  Write-Host "`n== 開始打包（不跑測試） ==" -ForegroundColor Green
  $p = Start-Process -FilePath 'mvn' -ArgumentList '-q','-DskipTests','package' -NoNewWindow -PassThru -Wait
  if ($p.ExitCode -eq 0) {
    Write-Host "PACKAGE OK" -ForegroundColor Green
  } else {
    Write-Host "PACKAGE FAIL (exit $($p.ExitCode))" -ForegroundColor Red
  }
}
finally {
  # 4) 還原檔名
  if ($renamed.Count -gt 0) {
    Write-Host "`n還原先前改名的檔案..." -ForegroundColor Cyan
    foreach($r in $renamed){
      $origPath = $r.Orig
      $offPath  = $r.Off
      if (Test-Path $offPath) {
        $dir = Split-Path $origPath -Parent
        $name = Split-Path $origPath -Leaf
        Rename-Item -LiteralPath $offPath -NewName $name -Force
      }
    }
    Write-Host "還原完成。" -ForegroundColor Green
  }
  # 顯示成品位置（兩種 Quarkus 產物擇一會存在）
  $fatJar = Join-Path $root 'target\course-scheduling-service-1.0.0-SNAPSHOT.jar'
  $runner = Join-Path $root 'target\quarkus-app\quarkus-run.jar'
  if (Test-Path $runner) {
    Write-Host "`n可執行：java -jar target\quarkus-app\quarkus-run.jar" -ForegroundColor Yellow
  } elseif (Test-Path $fatJar) {
    Write-Host "`n可執行：java -jar target\course-scheduling-service-1.0.0-SNAPSHOT.jar" -ForegroundColor Yellow
  } else {
    Write-Host "`n找不到可執行產物，請把上方紅字貼給我。" -ForegroundColor Red
  }
}
