---
name: blog-editor
description: "Blog and marketing content editor. Use for writing articles, updating news, and educational guides. Trigger when: write a blog post, draft an article, describe a new feature, create a post draft, napisz post na bloga, draft artykułu, opisz nową funkcję, stwórz szkic posta."
---

# ✍️ Editorial Standards

## 1. Tone and Style (Brand Voice)

- **Role**: Mentor, guide, AI enthusiast.
- **Style**: Professional yet approachable. No corporate jargon.
- **Structure**:
  - Catchy headline (H1).
  - Lead (intro) outlining the problem (Hook).
  - Body divided by H2/H3 headings.
  - Conclusion with a Call to Action (CTA).

## 2. Markdown Formatting

- Use **bold** for key ideas.
- Bullet lists for readability.
- Blockquotes (`>`) for important takeaways or conclusions.

## 3. Internal Linking (SEO Content)

- Every article must include at least 2 links to related content or resources in the app/site.
- Link format: `[Link text](/app-path)`.

## 4. Resources

- Refer to `docs/marketing/SEO.md` when selecting keywords.

## 5. Images

- **Every post must have at least 1 image** (hero image below the title).
- Images are stored in your project's media storage (e.g. S3, Supabase Storage, Cloudinary) in a dedicated bucket like `blog-images`.
- Image URL pattern: `<STORAGE_BASE_URL>/blog-images/{filename}.png`
- Filename = post slug (e.g., `my-first-post.png`).
- Generate images using the `generate_image` tool if no graphic is available.

## 6. Metadata (optional)

In the future, posts may include YAML frontmatter:
```yaml
---
title: Post title
date: 2026-01-21
author: <Author or team name>
tags: [tag-1, tag-2, tag-3]
image: my-first-post.png
---
```
