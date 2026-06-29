# Browser Inbox Conversion Activity Design

## Purpose

Browser Inbox now publishes `browser.capture.converted` when a capture becomes
a Markdown note. Activity should record that conversion through the same public
event subscription model it already uses for file, note, workspace, and browser
capture events.

## Scope

This slice wires one public event into `verstak.activity`:

- subscribe to `browser.capture.converted`;
- declare the event in the Activity plugin `activityProviders` contribution;
- store and render conversion activity in the existing workspace/global streams;
- include conversion events in worklog reconstruction.

It does not add a direct Browser Inbox to Activity API, special conversion UI,
or new desktop core behavior.

## Event Shape

Browser Inbox emits:

```js
{
  captureId: "capture-id",
  conversionType: "note",
  notePath: "Project/Notes/Example.md",
  workspaceRootPath: "Project",
  title: "Example",
  url: "https://example.com",
  sourcePluginId: "verstak.browser-inbox"
}
```

Activity stores the event using its normal event normalization. The title should
come from `payload.title`; summary should naturally include the best available
payload text such as `notePath` through the existing summary logic.

## Testing

`scripts/smoke-activity-plugin.js` must prove:

- `browser.capture.converted` is subscribed by the Activity frontend;
- the Activity manifest advertises the event in `activityProviders`;
- a workspace-scoped conversion event is stored under that workspace key;
- the rendered Activity view includes the conversion title and event type;
- worklog suggestions include the conversion event id.
