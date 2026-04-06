# Gitea Conference Customization Pack

Copy the contents of this folder into your Gitea **CustomPath** (a.k.a. `$GITEA_CUSTOM`, often `custom/`).

## What it does
- Overrides the landing page: `templates/home.tmpl`
- Adds conference CSS via the hook: `templates/custom/header.tmpl`
- Replaces logo + favicon via custom assets in: `public/assets/img/`

## Install
1. Locate your CustomPath (`gitea help` or Site Admin → Configuration).
2. Copy:
   - `templates/` -> `$GITEA_CUSTOM/templates/`
   - `public/`    -> `$GITEA_CUSTOM/public/`
3. Restart Gitea.
4. Hard refresh your browser for favicon changes.

## Customize text
Edit: `templates/home.tmpl`

## Customize colors/styles
Edit: `public/assets/css/conference.css`

## Replace logo/favicon
Replace:
- `public/assets/img/logo.svg`
- `public/assets/img/favicon.svg`
- `public/assets/img/favicon.png`
