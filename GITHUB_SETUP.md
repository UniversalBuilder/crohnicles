# 🚀 Pousser Crohnicles sur GitHub

## Étape 1: Créer le Repository GitHub

1. Connectez-vous sur [github.com](https://github.com)
2. Cliquez sur le bouton **"+" → "New repository"**
3. Configurez le repository :
   - **Repository name** : `crohnicles`
   - **Description** : `Application mobile de suivi santé pour Crohn/RCH avec IA prédictive`
   - **Visibility** : **Public** (pour lien documentation) ou **Private**
   - ⚠️ **NE PAS** cocher "Add README" (on a déjà le nôtre)
   - ⚠️ **NE PAS** cocher "Add .gitignore" (déjà présent)
   - **License** : None (on a déjà CC BY-NC-SA 4.0)
4. Cliquez sur **"Create repository"**

---

## Étape 2: Initialiser Git Localement

Ouvrez un terminal dans `d:\DEV\Crohnicles\crohnicles\` et exécutez :

```bash
# Initialiser Git
git init

# Configurer votre identité (si pas déjà fait)
git config user.name "Votre Nom"
git config user.email "votre.email@example.com"

# Ajouter tous les fichiers
git add .

# Premier commit
git commit -m "🎉 Initial commit - Crohnicles v1.0"
```

---

## Étape 3: Lier au Repository GitHub

Remplacez **`YOUR_USERNAME`** par votre nom d'utilisateur GitHub :

```bash
git remote add origin https://github.com/YOUR_USERNAME/crohnicles.git
git branch -M main
git push -u origin main
```

Si vous avez configuré SSH :
```bash
git remote add origin git@github.com:YOUR_USERNAME/crohnicles.git
git branch -M main
git push -u origin main
```

---

## Étape 4: Mettre à Jour les Liens dans l'App

Une fois le repository créé, remplacez les occurrences de `YOUR_USERNAME` dans :

### 1. README.md (lignes ~50-70)
```markdown
## 🤝 Contribuer
Les contributions sont les bienvenues ! Consultez [CONTRIBUTING.md](https://github.com/YOUR_USERNAME/crohnicles/blob/main/CONTRIBUTING.md).

## 📜 License
CC BY-NC-SA 4.0 - Voir [LICENSE](https://github.com/YOUR_USERNAME/crohnicles/blob/main/LICENSE)

## 🙏 Remerciements
Consultez [CONTRIBUTORS.md](https://github.com/YOUR_USERNAME/crohnicles/blob/main/CONTRIBUTORS.md)
```

### 2. lib/about_page.dart (lignes ~140-190)
```dart
// Section Contribuer
'GitHub': 'https://github.com/YOUR_USERNAME/crohnicles',

// Section Dons
'PayPal': 'https://paypal.me/YOUR_PAYPAL',
'Ko-fi': 'https://ko-fi.com/YOUR_KOFI',
'GitHub Sponsors': 'https://github.com/sponsors/YOUR_USERNAME',
```

### 3. CONTRIBUTORS.md (ligne ~30)
```markdown
## Comment Contribuer
Consultez [CONTRIBUTING.md](https://github.com/YOUR_USERNAME/crohnicles/blob/main/CONTRIBUTING.md)
```

### Commande pour remplacer automatiquement (PowerShell)
```powershell
$USERNAME = "votre_username_github"

# README.md
(Get-Content README.md) -replace 'YOUR_USERNAME', $USERNAME | Set-Content README.md

# about_page.dart
(Get-Content lib/about_page.dart) -replace 'YOUR_USERNAME', $USERNAME | Set-Content lib/about_page.dart
(Get-Content lib/about_page.dart) -replace 'YOUR_PAYPAL', "votre_username_paypal" | Set-Content lib/about_page.dart
(Get-Content lib/about_page.dart) -replace 'YOUR_KOFI', "votre_username_kofi" | Set-Content lib/about_page.dart

# CONTRIBUTORS.md
(Get-Content CONTRIBUTORS.md) -replace 'YOUR_USERNAME', $USERNAME | Set-Content CONTRIBUTORS.md

# Commit les changements
git add .
git commit -m "📝 Mise à jour des liens GitHub"
git push
```

---

## Étape 5: Configurer les Secrets GitHub (Optionnel)

Si vous ajoutez des workflows CI/CD plus tard :

1. Allez dans **Settings → Secrets and variables → Actions**
2. Ajoutez les secrets nécessaires (clés API, signing keys Android, etc.)

---

## 📦 Structure du Repository

Après push, votre repo contiendra :
```
crohnicles/
├── .github/           # (futur) Workflows CI/CD
├── android/           # Code Android
├── assets/            # ML models, images
├── ios/               # Code iOS
├── lib/               # Code Flutter/Dart
├── training/          # Scripts Python ML
├── test/              # Tests unitaires
├── CONTRIBUTORS.md
├── LICENSE
├── README.md
├── pubspec.yaml
└── ...
```

---

## ✅ Vérification

Après push, vérifiez que :
- [ ] Le repository est visible sur `https://github.com/YOUR_USERNAME/crohnicles`
- [ ] Les fichiers `README.md`, `LICENSE`, `CONTRIBUTORS.md` s'affichent correctement
- [ ] Les liens vers les documents fonctionnent
- [ ] Les screenshots (si ajoutés) sont visibles dans `assets/screenshots/`

---

## 🎯 Prochaines Étapes

1. **Badges CI/CD** : Ajouter GitHub Actions pour build Android/iOS automatique
2. **Releases** : Créer des releases tagged (v1.0.0, v1.1.0, etc.)
3. **Issues** : Activer les issues pour bug reports et feature requests
4. **Projects** : Utiliser GitHub Projects pour roadmap
5. **Discussions** : Activer les discussions pour communauté

---

## 🆘 Problèmes Courants

### "Authentication failed"
- Utilisez un **Personal Access Token** au lieu du mot de passe
- Allez dans **Settings → Developer settings → Personal access tokens**
- Créez un token avec scope `repo`

### "Permission denied (publickey)"
- Configurez votre clé SSH : https://docs.github.com/en/authentication/connecting-to-github-with-ssh

### "Large files detected"
Si des fichiers dépassent 50MB :
```bash
# Installer Git LFS
git lfs install

# Tracker les fichiers volumineux
git lfs track "*.apk"
git lfs track "*.aab"
git lfs track "*.tflite"

git add .gitattributes
git commit -m "🔧 Configure Git LFS"
git push
```

---

## 📚 Ressources

- [GitHub Docs](https://docs.github.com)
- [Git Basics](https://git-scm.com/book/fr/v2)
- [Flutter CI/CD](https://docs.flutter.dev/deployment/cd)
