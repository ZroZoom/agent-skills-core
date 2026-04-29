# Deploy Production

Prepare and deploy the application to production.

## 1. Verification (Pre-deployment)

```bash
npm run quality      # lint + typecheck
npx vitest run       # unit tests
npm run build        # production build
```

All MUST pass without errors.

## 2. Versioning

1. Check the current version: `node -p "require('./package.json').version"`
2. Update `package.json` (bump version)
3. Update `CHANGELOG.md`

## 3. Commit and tag

```bash
git add package.json CHANGELOG.md
git commit -m "chore: bump version to X.Y.Z"
git tag vX.Y.Z
```

## 4. Push (triggers CI/CD on Netlify)

```bash
git push && git push --tags
```

## 5. Production verification

After the deploy completes, check https://<DOMAIN_PRIMARY>:
- [ ] Page loads correctly
- [ ] Login works
- [ ] Dashboard is accessible
- [ ] Critical pages render correctly with all assets
