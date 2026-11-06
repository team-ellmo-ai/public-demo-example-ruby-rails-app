# Changelog

## 0.1.0 (unreleased)

- First version: Rack middleware and Rails helpers that add eLLMo content (cached, refreshed in the background) and report page views from a background thread in gzipped batches (`source: "rails-sdk"`).
- Checks this client's switches (`GET analytics-v2.tryellmo.com/access/<client id>`, every 30 min per process, in the background): page views off discards them, content off serves and fetches none. One failed check is skipped; two in a row count as off.
- `config.debug` (or `ELLMO_DEBUG=1`): logs every call to eLLMo and its answer, prefixed `[ellmo-ai http]`; page-view uploads logged decoded and in full. `config.debug_body_limit` / `ELLMO_DEBUG_BODY` caps logged answers (2000 characters).
- Needs the `embedded-content_v2` function (the same one `ellmo-ai-react` 1.0 uses) to be deployed; until then pages render unchanged.
