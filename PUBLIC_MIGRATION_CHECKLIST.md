# New Public Repository Migration Checklist

Target repository name:

`submarine-shipmate-hazardous-exposure`

## Recommended clean start

Do not copy the old `.git/` directory into the new public repository.

After copying this package into the new working directory:

```bash
git init
git branch -M main
git status
```

Review `.gitignore`, especially:

```text
*.zip
responses/*
private/
completed/
exports/
*.response.json
*_response.json
.env
.env.*
*.key
*.pem
```

Then stage deliberately:

```bash
git add README.md index.html .gitignore .nojekyll DISCLAIMER.md SECURITY.md
git add docs forms examples sources references responses
git status
git diff --cached
```

Before committing:

```bash
git ls-files '*.zip'
```

It should produce no output.

Then:

```bash
git commit -m "Initial public hazardous exposure research archive"
git remote add origin YOUR_NEW_REPOSITORY_URL
git push -u origin main
```

Enable GitHub Pages from `main` / `/(root)`.

Expected Pages pattern:

`https://NEW-ACCOUNT.github.io/submarine-shipmate-hazardous-exposure/`

Private form:

`https://NEW-ACCOUNT.github.io/submarine-shipmate-hazardous-exposure/forms/Submarine_Shipmate_Private_Reconstruction_Form.html`
