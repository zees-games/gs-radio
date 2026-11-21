# gs-radio

A shared in-game radio station: the operator uploads MP3 and OGG tracks to the server, the server keeps one schedule (current track plus the instant it started), and every client downloads the files over HTTP and plays them seeked to where the station is. Read [docs/design.md](docs/design.md) first; it records why the clock is shared, why tracks are downloaded rather than streamed, and what is not built.

**The distributable is `addons/gs_radio/`.** `project.godot` and `examples/` exist to validate it alone. It requires gs-core (`ln -s ../../gs-core/addons/gs_core addons/gs_core`, gitignored); everything else is duck-typed.

| Path | What |
| --- | --- |
| `gs_radio_codec.gd` | `GSRadioCodec`: MP3/OGG by magic bytes, decode to a stream, length |
| `gs_radio_library.gd` | `GSRadioLibrary`: validation, caps, storage under `user://`, JSON index |
| `gs_radio_station.gd` | `GSRadioStation`: playlist, queue, shuffle/loop, schedule, skip, requests, ratings, state file |
| `gs_radio_api.gd` | `GSRadioApi`: JSON ops, admin flag `radio`, token or identity, listener ops |
| `gs_radio_http.gd` | `GSRadioHttp`: routes on gs-core's `GSHttpServer`, off by default, token from a file only |
| `gs_radio_client.gd` | `GSRadioClient`: downloads, cache, seek, drift, volume, tune in/out, input actions |
| `gs_radio_sink*.gd` | the playback seam: `GSRadioSink` shape, `GSRadioSinkNull` (tests), `GSRadioSinkGodot` |
| `gs_radio_commands.gd` | `GSRadioCommands`: `!radio`, `!song`, `!request`, `!rate` without a console dependency |
| `gs_radio_tags.gd` | `GSRadioTags`: title, artist, album and an ID3v2 cover from uploads |
| `gs_radio_workbench.gd` | `GSRadioWorkbench`: mounts the radio on a workbench's server and registers its page |
| `web/index.html` | the admin page: one file, no build |

- The HTTP server is gs-core's `GSHttpServer`; this addon only mounts routes. Uploads are a raw-body `PUT /api/tracks/<name>`. Do not write a second server or a multipart parser here.
- Admin identity is the api's `identity` and `permit` hooks. gs-core's `GSAdminIdentity` (API level 29) fits them: set `resolver`, `admin_uids` or `admin_groups`, `flags = ["radio"]` (empty by default), `channel = "radio"`, then `api.identity = gate.authenticate; api.permit = gate.permit`. gs-workbench's `GSWorkbenchIdentity` is a subclass of it. The radio code does not wrap it; the selftest exercises the wiring.
- Time on the wire is `position` (seconds into the track), not a timestamp: clients never need to agree with the server's wall clock.
- Nothing plays until `GSRadioClient.tune_in()` runs from a user gesture (`handle_input`, bound to the `radio_toggle` action). Never start it from `_ready`.
- Secrets (admin token, TLS key) are read from files only, never env or argv.
- The addon provides upload functionality only and ships no audio; the operator is responsible for the rights to what they broadcast. Keep that in the README.
- Validate: import, `--check-only` on every `.gd`, then `res://examples/radio_selftest.tscn` (`radio_selftest`), then `radio_cover_selftest` (album, cover, workbench page; extends the first) and `radio_net_selftest` (the host-side gs-net wrapper in `examples/host/`; needs gs-net and gs-profile linked: `ln -s ../../gs-net/addons/gs_net addons/gs_net`, gitignored, CI resolves them from `.gitignore`), all through `heavy`. One engine line, `Failed to decode mp3 file`, is expected on stderr: it is the check that a file with MP3 magic bytes but junk inside is refused. CI is the shared dot-ci `@v1`.
