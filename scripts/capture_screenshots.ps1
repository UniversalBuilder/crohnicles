#!/usr/bin/env pwsh
# Script pour capturer automatiquement des screenshots de l'application
# Utilise integration_test avec un émulateur/simulateur

param(
    [string]$device = "android",  # priorité : android, puis ios, windows optionnel
    [string]$outputDir = "docs\screenshots"
)

Write-Host "🚀 Lancement de la capture de screenshots..." -ForegroundColor Green
Write-Host "📱 Device: $device" -ForegroundColor Cyan
Write-Host "📂 Output: $outputDir" -ForegroundColor Cyan

# Créer le dossier de sortie
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "✅ Dossier créé: $outputDir" -ForegroundColor Green
}

# Étape 1: Compiler l'app
Write-Host "`n🔨 Compilation de l'application..." -ForegroundColor Yellow
switch ($device) {
    "windows" {
        flutter build windows --debug
    }
    "android" {
        flutter build apk --debug
    }
    "ios" {
        flutter build ios --debug --simulator
    }
    default {
        Write-Host "❌ Device non supporté: $device" -ForegroundColor Red
        exit 1
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Échec de la compilation" -ForegroundColor Red
    exit 1
}

# Étape 2: Lancer les tests d'intégration avec screenshots
Write-Host "`n📸 Capture des screenshots..." -ForegroundColor Yellow

switch ($device) {
    "android" {
        Write-Host "📱 Préparation émulateur Android..." -ForegroundColor Yellow
        
        # Lister les émulateurs disponibles
        $emulators = flutter emulators 2>$null | Select-String -Pattern "•" | ForEach-Object { 
            if ($_ -match "• (.+?) •") { $matches[1].Trim() }
        }
        
        if ($emulators.Count -eq 0) {
            Write-Host "❌ Aucun émulateur Android trouvé" -ForegroundColor Red
            Write-Host "   Créez un émulateur dans Android Studio (AVD Manager)" -ForegroundColor Yellow
            Write-Host "   Recommandé: Pixel 6 API 34" -ForegroundColor Cyan
            exit 1
        }
        
        Write-Host "✅ Émulateurs disponibles:" -ForegroundColor Green
        $emulators | ForEach-Object { Write-Host "   - $_" -ForegroundColor Cyan }
        
        # Prendre le premier émulateur par défaut
        $defaultEmulator = $emulators[0]
        Write-Host "`n🚀 Lancement de l'émulateur: $defaultEmulator" -ForegroundColor Green
        flutter emulators --launch $defaultEmulator
        
        Write-Host "⏳ Attente du démarrage (15s)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 15
        
        Write-Host "📸 Capture en cours..." -ForegroundColor Green
        flutter test integration_test/screenshot_test.dart
    }
    "ios" {
        Write-Host "📱 Lancement simulateur iOS..." -ForegroundColor Yellow
        open -a Simulator 2>$null
        Start-Sleep -Seconds 5
        flutter test integration_test/screenshot_test.dart
    }
    "windows" {
        Write-Host "⚠️  Capture manuelle requise pour Windows" -ForegroundColor Yellow
        Write-Host "1. Lancez l'app: flutter run -d windows" -ForegroundColor Cyan
        Write-Host "2. Naviguez manuellement dans l'app" -ForegroundColor Cyan
        Write-Host "3. Capturez les screenshots avec Win+Shift+S" -ForegroundColor Cyan
    }
    default {
        Write-Host "❌ Device non supporté: $device" -ForegroundColor Red
        Write-Host "   Devices supportés: android, ios, windows" -ForegroundColor Yellow
        exit 1
    }
}

# Étape 3: Post-traitement (optionnel)
Write-Host "`n✨ Post-traitement..." -ForegroundColor Yellow

# Lister les screenshots capturés
$screenshots = Get-ChildItem -Path $outputDir -Filter "*.png" | Sort-Object Name

if ($screenshots.Count -eq 0) {
    Write-Host "⚠️  Aucun screenshot trouvé" -ForegroundColor Yellow
    Write-Host "`n📝 Instructions manuelles:" -ForegroundColor Cyan
    Write-Host "1. flutter run -d $device" -ForegroundColor White
    Write-Host "2. Naviguez dans l'app" -ForegroundColor White
    Write-Host "3. Capturez les screenshots:" -ForegroundColor White
    Write-Host "   - Timeline (page d'accueil)" -ForegroundColor White
    Write-Host "   - Compositeur de repas (bouton +)" -ForegroundColor White
    Write-Host "   - Insights (onglet graphiques)" -ForegroundColor White
    Write-Host "   - Calendrier (onglet calendrier)" -ForegroundColor White
    Write-Host "   - Settings & About" -ForegroundColor White
    Write-Host "4. Sauvegardez dans $outputDir" -ForegroundColor White
} else {
    Write-Host "✅ $($screenshots.Count) screenshots capturés:" -ForegroundColor Green
    foreach ($screenshot in $screenshots) {
        Write-Host "   📷 $($screenshot.Name)" -ForegroundColor Cyan
    }
}

Write-Host "`n✅ Script terminé!" -ForegroundColor Green
Write-Host "📂 Screenshots disponibles dans: $outputDir" -ForegroundColor Cyan
