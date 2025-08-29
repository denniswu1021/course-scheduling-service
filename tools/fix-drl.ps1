param()

$ErrorActionPreference = "Stop"

$root   = "C:\Users\dennwu\course-920\course-scheduling-service"
$main   = Join-Path $root "src\main\resources\curriculumcourse\curriculumcourse\constraints.drl"
$test0  = Join-Path $root "src\test\resources\constraints.drl"
$test   = Join-Path $root "src\test\resources\curriculumcourse\curriculumcourse\constraints.drl"

# 1) 測試 DRL 放到套件對應資料夾（消 folder 警告），避免重複
if (Test-Path $test0) {
  New-Item -ItemType Directory -Force -Path (Split-Path $test) | Out-Null
  Move-Item -Force $test0 $test
  Write-Host ">> moved test constraints.drl -> $test"
}
# 同名多份時，只保留 $main / $test，其餘 .drl 改名 .off
$allDrl = Get-ChildItem -Path (Join-Path $root "src") -Recurse -Filter constraints.drl -Force
foreach($f in $allDrl){
  if ($f.FullName -ne $main -and $f.FullName -ne $test) {
    $off = $f.FullName + ".off"
    if (-not (Test-Path $off)) {
      Rename-Item -LiteralPath $f.FullName -NewName ($f.Name + ".off") -Force
      Write-Host ">> disabled duplicate: $($f.FullName)"
    }
  }
}

# 2) 消除 eval(...) 警告：改成 pattern 約束（主檔與測試檔都改）
$files = @($main, $test) | Where-Object { Test-Path $_ }

$roomRule = @"
rule "Room capacity"
when
  $l : Lecture( $r : room, $c : course )
  Room( this == $r, capacity < $c.studentSize )
then
  scoreHolder.addHardPenalty(kcontext, 1);
end
"@

$minRule = @"
rule "Minimum working days"
when
  $course : Course()
  Number( $distinct : intValue ) from accumulate (
     Lecture( course == $course, $p : period ),
     init( java.util.Set days = new java.util.HashSet(); ),
     action( days.add( $p.getDay() ); ),
     reverse( ),
     result( days.size() )
  )
  Course( this == $course, minimumWorkingDays > $distinct )
then
  scoreHolder.addSoftPenalty(kcontext, $course.getMinimumWorkingDays() - $distinct);
end
"@

foreach($f in $files){
  $txt = Get-Content $f -Raw
  $txt = [regex]::Replace($txt,'(?ms)^\s*rule\s*"Room capacity".*?^\s*end',$roomRule)
  $txt = [regex]::Replace($txt,'(?ms)^\s*rule\s*"Minimum working days".*?^\s*end',$minRule)
  [IO.File]::WriteAllText($f,$txt,[Text.UTF8Encoding]::new($false))
  Write-Host ">> patched $f"
}

# 3) 重新跑測試並統計警告
Set-Location $root
$log = cmd /c 'mvn -q "-Dtest=ConstraintsDrl*" "-Ddrools.wiring=dynamic" test' 2>&1
$log | Out-String | Set-Content (Join-Path $root "target\fix-drl-test.log")

$warn1 = ($log | Select-String "KieBuilderImpl].*File 'constraints.drl' is in folder ''").Count
$warn2 = ($log | Select-String "In an eval expression").Count
$tests = ($log | Select-String "BUILD SUCCESS").Count

Write-Host "`n== Summary ==" -ForegroundColor Cyan
Write-Host "BUILD: $([bool]$tests)"
Write-Host "Folder warnings: $warn1"
Write-Host "eval() warnings : $warn2"
Write-Host "Log saved to: target\fix-drl-test.log"