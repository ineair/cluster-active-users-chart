#===============================================
# Script Name   : GetClusterPublicActiveUserCnt.ps1
# Description   : Clusterのパブリックアクティブユーザー数を取得してdata.jsonに追記する
# Developer     : inea
#===============================================

# リクエストURL
$url1 = "https://api.cluster.mu/v1/live_activity/spaces/hots"
$url2 = "https://api.cluster.mu/v1/events/in_session?pageSize=100"
$url3 = "https://api.cluster.mu/v1/events/"
$deleteAfterDays = 90
$dataFile = Join-Path $PSScriptRoot "..\data.json"

# ヘッダー
$headers = @{
    "x-cluster-app-version"    = "3.55.2510011744"
    "x-cluster-build-version"  = "2510101302"
    "x-cluster-device"         = "Web"
    "x-cluster-platform"       = "Web"
}

$time = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# =============================
# Cluster APIからユーザー数取得
# =============================
try {
    # パブリックスペース
    $spaceUserCnt = 0
    $response = Invoke-RestMethod -Uri $url1 -Method GET -Headers $headers
    $spaceUserCnt = ($response.contents.playerCount | Measure-Object -Sum).Sum

    # イベントセッション
    $eventUserCnt = 0
    $response = Invoke-RestMethod -Uri $url2 -Method GET -Headers $headers
    $eventIds = $response.events.summary.id
    foreach ($eventId in $eventIds) {
        $eventDetail = Invoke-RestMethod -Uri ($url3 + $eventId) -Method GET -Headers $headers
        $eventUserCnt += $eventDetail.liveEntry.users.Count
    }

    $userCnt = $spaceUserCnt + $eventUserCnt
}
catch {
    Write-Host "API取得エラー: $($_.Exception.Message)"
    exit 1
}

# =============================
# data.jsonの読み込み／作成
# =============================
if (Test-Path $dataFile) {
    $data = Get-Content $dataFile -Raw | ConvertFrom-Json
    if($null -eq $data){
        $data = @()
    }
} else {
    $data = @()
}

# =============================
# 古いデータを削除
# =============================
$threshold = (Get-Date).AddDays(-$deleteAfterDays)
$tmp = @()
$tmp += $data | Where-Object { 
    (Get-Date $_.time) -ge $threshold 
}
$data = $tmp

# =============================
# 新データを追加
# =============================
$newEntry = [PSCustomObject]@{
    time   = $time
    value  = $userCnt
}
$data += $newEntry

# =============================
# JSONに保存
# =============================
ConvertTo-Json -InputObject $data -Depth 3 | Set-Content -Encoding UTF8 $dataFile

Write-Host "[$time] ユーザー数: $userCnt 件を data.json に追記しました。"
