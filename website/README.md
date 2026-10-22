# Capstan website

The marketing site at [capstan.bytesnation.com](https://capstan.bytesnation.com/). It uses static HTML, CSS, JavaScript and SVG, with no build step or runtime dependencies. Fonts are hosted with the site. Their SIL Open Font License files are in `public/assets/`.

The install commands and product claims follow the repository's main README. Update both when the installation or workflow changes.

## Preview

Run from `website/`:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory public
```

Open [the local preview](http://127.0.0.1:4173/).

## Publish

Authenticate Wrangler with the Cloudflare account that owns `bytesnation.com`, then run from `website/`:

```sh
wrangler deploy --dry-run
wrangler deploy
```

`wrangler.jsonc` publishes only `public/` to the `capstan-website` Worker. Its custom domain configuration provisions DNS and TLS for `capstan.bytesnation.com`. The apex site uses a separate host.

After deployment, check the custom domain over HTTPS, the install and effort copy buttons, and a mobile viewport. Confirm that an unknown path returns HTTP 404. Deployments are manual. Pushing this directory to GitHub does not publish it.

To restore a previous deployment:

```sh
wrangler deployments list
wrangler rollback <version-id>
```

## Assets

The capstan workflow and mark are native SVG drawings based on the approved website concept. `social.png` is a browser capture of this page for link previews. Regenerate it after changing the hero design.
