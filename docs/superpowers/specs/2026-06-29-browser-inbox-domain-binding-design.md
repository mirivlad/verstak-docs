# Browser Inbox Domain Binding Design

## Purpose

Browser captures often arrive while the user is not focused on the workspace
that should receive them. Domain binding routes unscoped browser captures into a
workspace queue by matching the capture domain to a plugin-owned binding table.

This keeps Browser Inbox behavior in the official plugin. Desktop core still
only publishes browser capture events and may annotate the current workspace
when it knows one.

## Scope

This slice implements domain-to-workspace routing inside `verstak.browser-inbox`:

- store bindings in the Browser Inbox plugin settings namespace;
- match capture domains case-insensitively;
- route only captures that do not already include `workspaceRootPath`;
- preserve the global aggregate view;
- keep the binding model independent from Notes, Files, Activity, and Journal.

It does not implement conversion into notes/links/files/activity, browser UI for
editing bindings, or a desktop core domain binding API.

## Settings Contract

The plugin reads `domainBindings` from its settings object:

```json
{
  "domainBindings": {
    "example.com": "Project",
    "client.example.com": "ClientA"
  }
}
```

Keys are hostnames. Values are top-level `workspaceRootPath` strings.

Normalization rules:

- trim whitespace around keys and values;
- lowercase domains for matching;
- strip one or more leading dots from binding keys;
- ignore empty domains and empty workspace roots.

## Routing Rules

For each incoming `browser.capture.page`, `browser.capture.selection`, or
`browser.capture.link` event:

1. If payload already has `workspaceRootPath`, keep it unchanged.
2. Otherwise, derive a domain from `payload.domain` or `payload.url`.
3. If an exact normalized domain binding exists, set `workspaceRootPath` and
   `workspaceName` to the bound workspace root before storage.
4. If no binding exists, keep current behavior and store the capture in the
   receiving view scope.

Subdomain fallback is intentionally out of scope for this first slice. A
binding for `example.com` does not match `docs.example.com` until a later design
adds explicit wildcard or suffix semantics.

## Testing

`scripts/smoke-browser-inbox-plugin.js` must prove:

- an unscoped capture with `domain: "client.example.com"` and a
  `domainBindings` entry for that domain is stored under
  `captures:workspace:ClientA`;
- the routed capture appears in the ClientA workspace view;
- the global view still aggregates the routed capture;
- an event that already includes `workspaceRootPath: "Project"` is not
  overwritten by a domain binding for another workspace.
