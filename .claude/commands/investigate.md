# Investigate — Data Quality Issues

Systematic investigation of data quality problems. Argument: search term or problem description.

## Procedure

### 1. Check the data source FIRST

```bash
# Search the project for the term across known data locations
grep -r "TERM" src/data/ src/features/ content/

# Migrations / seed data (adapt to your stack)
grep -r "TERM" supabase/migrations/ prisma/ db/seeds/ 2>/dev/null
```

### 2. Verify the file structure

List the data directories your project uses (e.g. `src/data/`, `src/features/<feature>/data/`, content trees, fixtures).

### 3. Check the loader and transformations

Trace how the data is loaded and transformed before reaching the UI — bridges, adapters, normalizers, classifiers.

### 4. Only then check the code logic

If data exists but is not displayed:
1. Are inputs being classified / parsed correctly?
2. Is the search / ranking finding the record?
3. Is the response / view built correctly from the record?

## Report

Summarize: what was found, what is still unknown, next steps.
