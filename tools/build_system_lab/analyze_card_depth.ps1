param(
    [Parameter(Mandatory)][string]$Report,
    [int]$ExpectedCases = 30
)
$ErrorActionPreference = 'Stop'
$data = Get-Content -LiteralPath $Report -Raw | ConvertFrom-Json
if ($data.cases.Count -ne $ExpectedCases -or $data.errors.Count -gt 0) {
    throw 'Rapport incomplet ou contenant des erreurs.'
}
$classes = @($data.cases | Where-Object class)
$combats = @($classes | ForEach-Object { $_.combats })
$hero = @{}
$enemy = @{}
foreach ($combat in $combats) {
    foreach ($entry in $combat.hero_casts.psobject.Properties) { $hero[$entry.Name] += $entry.Value }
    foreach ($entry in $combat.enemy_casts.psobject.Properties) { $enemy[$entry.Name] += $entry.Value }
}
$rows = @($data.cases | ForEach-Object {
    $last = $_.combats[-1]
    [ordered]@{
        class = $(if ($_.class) { $_.class } else { $_.weapon })
        seed = $_.seed
        outcome = $_.outcome
        final_depth = $last.depth
        starter_copies_at_last_combat = $(if ($_.class) {
            @($last.deck_entry.active_families | Where-Object { $_ -like 's_*' -or $_ -like 'i_*' }).Count
        } else { $null })
        owned_copies_at_last_combat = $last.deck_entry.owned_copies
    }
})
$summary = [ordered]@{
    source = (Resolve-Path -LiteralPath $Report).Path
    source_sha256 = (Get-FileHash -LiteralPath $Report -Algorithm SHA256).Hash
    human_win_rate_claim = $false
    cases = $rows
    all_combats = @($data.cases | ForEach-Object { $_.combats }).Count
    class_combats = $combats.Count
    class_hero_turns = ($combats | Measure-Object turns -Sum).Sum
    class_hero_casts = ($hero.Values | Measure-Object -Sum).Sum
    basic_casts = $hero.class_basic_strike + $hero.class_basic_guard
    starter_casts = ($hero.GetEnumerator() | Where-Object { $_.Key -like 'class_s_*' -or $_.Key -like 'class_i_*' } | Measure-Object Value -Sum).Sum
    enemy_casts = ($enemy.Values | Measure-Object -Sum).Sum
    enemy_card_technique_casts = ($enemy.GetEnumerator() | Where-Object Key -Like 'class_*' | Measure-Object Value -Sum).Sum
    blocked_preparations = ($combats | Measure-Object blocked_preparations -Sum).Sum
    hero_casts_by_id = $hero
    enemy_casts_by_id = $enemy
}
$summary | ConvertTo-Json -Depth 20
