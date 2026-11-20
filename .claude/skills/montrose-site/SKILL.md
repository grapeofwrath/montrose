---
name: "montrose-site"
description: "Work on the Montrose Millwork website: Go/Echo/Templ/Tailwind/Alpine code, Palladio-plate theme, carousels, gallery, and NixOS deployment. Use for any change to this site."
---

# Montrose Millwork site

Finish-carpentry business site. Go module `montRose`, Echo v5, Templ, Tailwind v4 (browser CDN), AlpineJS (CDN). Server listens on `$PORT`, default :5050.

## Rules for answers and code
- KISS. Prefer the simplest logical solution; offer multiple options only when it genuinely helps.
- Comments only when the code can't explain itself to a competent reader. Never comment what the code does.
- The files on disk are the source of truth; the user may have edited them since you last read them, so re-read before editing.
- Ask no questions for small edits; just make them.

## Layout
- `main.go`: Echo setup, static middleware (root `public`), routes `/` and `/gallery`, `render` helper, `loadReviews` (read per request, errors logged, page renders without reviews).
- `views/` (package `views`): `layout.templ`, `components.templ`, `home.templ`, `gallery.templ`, `reviews.templ`.
- `public/assets/`: `reviews.json`, logos, `ash-bg-02.webp`, `plates/` (Palladio engravings), `favicon/`. `public/images/`: gallery photos (.jpg/.jpeg/.png/.webp, listed alphabetically by `galleryHandler`).
- `scripts/process-images.sh` (convert gallery photos to web-sized .webp) and `scripts/optimize-plates.sh` (shrink plates); both back up originals outside `public/`. `scripts/` is gitignored.
- `flake.nix`: dev shell (go from overlay `goVersion`, templ, air, gotools, golangci-lint), `packages.default`, `nixosModules.default`.

## Workflow
- Edit `.templ`, then run `templ generate`. The generated `*_templ.go` files must be committed (the Nix build does not run templ and must not be gitignored).
- Dev loop: `air` (builds with `CGO_ENABLED=0`, serves on :5051). Static files are served from `public/` relative to the working directory.
- Flakes only see git-tracked files: `git add` new photos, `reviews.json`, and generated files before `nix build`.
- Before committing, check: `gofmt -l .`, `templ fmt -fail views`, `golangci-lint run ./...`, `go build .`.
- Branches: the server deploys `main`. Work in progress goes on `dev` (pushed to origin); merge into `main` only when it should go live.
- Claude Code sandbox: `nix`/`direnv` aren't available, so go, templ and golangci-lint aren't on PATH. Use the dev-shell binaries from `/nix/store` (e.g. `ls -d /nix/store/*-go-1.27*/bin`) and set `GOCACHE` to the scratchpad. `git push` has no GitHub credentials here; the user pushes from their own terminal.

## Theme
- Tailwind `@theme` tokens in `Layout`: `main #60a5fa`, `accent #CA9C68` (warm tan, close to the ash banner), `vellum #e8e0cc`. Base: `bg-zinc-900 text-gray-100`.
- Palladio plate aesthetic (Four Books of Architecture, Ware 1738, public domain via c82.net, credited in footer): vellum or zinc-800 mats, thin accent inner rules, serif small-caps captions (`font-serif text-[0.7rem] uppercase tracking-[0.3em]`), diamond (&#9670;) ornament dividers, `PlateBg` engravings (inverted, ~0.07 opacity) on dark sections.
- `[x-cloak]` is hidden globally in `Layout`.

## Components (components.templ unless noted)
- `Button(label, href, dark, attrs)`: the single button/link style; pass `templ.Attributes` for Alpine hooks. `Modal(label, panelClass)` uses it as trigger. `ContactPanel`: wood banner on top, dark serif body with accent border.
- `SVG`, `SocialLink`, `PlateBg` (parent needs `relative isolate overflow-hidden`, content `relative`), `Profile(image, name, plate, flip)` with children text, `mirror(flip)`.
- `carouselData(n, extra)` builds the shared Alpine state string: `i`, `n`, `go`, `pos`, `start`/`end` (touch swipe: at least 40px and 1.5x more horizontal than vertical), `wheel` (trackpad accumulation over 50, locked until 150ms of silence). `extra` entries must end with a comma.
- layout.templ: `Layout(title)`, `Header(href, label)` (banner + `Navbar`), `Navbar` (fixed, bottom on mobile and top from `sm`, shown via IntersectionObserver once `#header` is scrolled past, static translate classes avoid a flash before Alpine loads), `NavButtons(href, label)` (page link + Contact modal), `Footer(plate)` (extra bottom padding on mobile so the bottom navbar doesn't cover it).
- Header uses the full planer logo `/assets/Montrose_logo.PNG` with `mix-blend-multiply` on the ash banner; Navbar uses the text logo `/assets/Montrose_logo_text_transparent.png` as a CSS mask over `bg-vellum`.
- Layout head also carries favicon links and Plausible analytics.
- reviews.templ: `Review{Comment, Author}` carousel (grid-stacked slides positioned by `pos(idx)`, diamond pagination, swipe/trackpad/arrow keys). Data from `public/assets/reviews.json`; the current entries are placeholders to be replaced with real reviews.
- gallery.templ: `Gallery(images)` defaults to a carousel with a Grid/Carousel toggle, arrow buttons (`ArrowButton`, chevron polygon, zinc-900 with accent hover, translucent vellum bg), swipe/trackpad/keyboard, middle-click opens the raw image, clicking a grid figure calls `show(k)`. The frame animates `aspect-ratio` via `fit(img)` so arrows glide when photos differ in shape.

## Deployment
- `nixosModules.default` exposes `services.montrose.enable`: systemd service (`DynamicUser`, `WorkingDirectory` = package `share/montrose` so `public/` is found). Reverse proxy and firewall live in the server's NixOS config, not this flake.
- Binary name comes from the Go module (`montRose`); change `ExecStart` if `go.mod` differs.
- When Go deps change, set `vendorHash` to `lib.fakeHash`, run `nix build`, and paste the printed `got:` hash.
- `public/` is baked into the Nix store, so photo or review changes need commit, rebuild, and switch.
- Deploy: `nix flake update montrose` then `nixos-rebuild switch --flake .#server --target-host root@server --build-host root@server`. Logs: `journalctl -u montrose -f`.
- Piwigo (photo hosting on port 5052 via podman + sops-nix) is a separate module, `piwigo.nix`, not part of this flake.

## Common fixes already made (don't reintroduce)
- Extension switch in `main.go` needs the dot (`".png"`); use `max-h-[90dvh]` bracket syntax; page title must use the `title` argument; image alt must not be the filename; avoid duplicating contact markup (use `NavButtons`).
- Use `divide-x` on the button group instead of per-button borders to avoid double borders.