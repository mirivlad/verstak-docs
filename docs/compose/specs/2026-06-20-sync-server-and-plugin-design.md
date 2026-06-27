# Sync Server & Plugin Design

## [S1] Problem

Verstak2 needs synchronization between devices. The old Verstak (`~/git/verstak`) has a working sync server and client, but Verstak2 is a platform architecture with plugins. Sync must be implemented as:
1. A separate sync server repository
2. A sync plugin that provides settings UI via the plugin manager

## [S2] Sync Server

### Location
Separate repository: `verstak-sync-server`

### Source
Based on `~/git/verstak/cmd/verstak-server/` with minimal changes.

### Structure
```
verstak-sync-server/
  cmd/server/main.go
  internal/
    server/
      server.go
      routes.go
      handlers_api.go
      handlers_auth.go
      handlers_admin.go
      middleware.go
      config.go
      schema.go
      tokens.go
      smtp.go
  go.mod
  go.sum
  README.md
```

### API Endpoints
- `POST /api/v1/sync/push` — push operations
- `POST /api/v1/sync/pull` — pull operations
- `POST /api/v1/blobs/` — upload blob (multipart)
- `GET /api/v1/blobs/:sha256` — download blob
- `POST /api/client/pair` — device pairing with login/password
- `POST /api/auth/test` — test credentials
- `GET /api/client/me` — device info
- `POST /api/client/revoke-current` — revoke current device
- `POST /api/client/revoke-device` — revoke specific device (web)
- `GET /api/v1/health` — health check
- Admin endpoints: `/admin/dashboard`, `/admin/users`, `/admin/api/stats`

### Config
YAML file at `data/config.yml`:
```yaml
port: 47732
admin:
  - username: admin
    password_hash: "$2a$10$..."
```

### Database
SQLite at `data/server.db` with tables:
- `server_users` — user accounts
- `server_devices` — paired devices
- `server_ops` — sync operations
- `server_tombstones` — deleted entities
- `server_idempotency_keys` — idempotent push
- `server_user_devices` — user-device mapping
- `server_audit_log` — audit trail

## [S3] Sync Plugin

### Location
`verstak-official-plugins/plugins/sync/`

### Manifest
```json
{
  "schemaVersion": 1,
  "id": "verstak.sync",
  "name": "Sync",
  "version": "0.1.0",
  "apiVersion": "0.1.0",
  "description": "Vault synchronization across devices via Verstak Sync Server.",
  "source": "official",
  "icon": "sync",
  "provides": ["verstak/sync/v1", "verstak/sync.status/v1"],
  "requires": ["verstak/core/files/v1"],
  "permissions": [
    "files.read",
    "files.write",
    "network.remote",
    "settings.read",
    "settings.write",
    "ui.register"
  ],
  "frontend": {
    "entry": "frontend/dist/index.js"
  },
  "contributes": {
    "settingsPanels": [{
      "id": "verstak.sync.settings",
      "title": "Sync",
      "component": "SyncSettings"
    }],
    "statusBarItems": [{
      "id": "verstak.sync.status",
      "label": "Sync",
      "position": "right"
    }]
  }
}
```

### Capabilities Provided
- `verstak/sync/v1` — sync provider capability
- `verstak/sync.status/v1` — sync status provider

### Settings (Extended)
The plugin stores settings via `settings.read/write` API:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `serverUrl` | string | "" | Sync server URL |
| `username` | string | "" | User login |
| `password` | string | "" | User password (stored temporarily, not persisted) |
| `syncInterval` | number | 0 | Auto-sync interval in minutes (0 = disabled) |
| `autoSync` | boolean | false | Enable auto-sync |
| `deviceName` | string | hostname | Device identifier |
| `deviceId` | string | "" | Assigned device ID |
| `deviceToken` | string | "" | Device auth token |
| `lastStatus` | string | "disabled" | Connection status |
| `lastSyncAt` | string | "" | Last successful sync timestamp |
| `lastError` | string | "" | Last error message |

### Settings UI Component

`SyncSettings.svelte` — registered as settings panel via contributes.

**Two states:**

1. **Not configured** — setup form:
   - Server URL input
   - Username input
   - Password input
   - "Test Connection" button
   - "Connect" button

2. **Configured** — status view:
   - Status indicator (connected/disconnected/error/revoked)
   - Server URL display
   - Device Name display
   - Device ID display
   - Last Sync Time display
   - Last Error display (if any)
   - "Sync Now" button
   - "Disconnect" button
   - "Reset Key" button
   - Sync Interval input + Save button
   - Auto-sync toggle

### Backend Integration

The plugin uses VerstakPluginAPI to:
- Read/write settings via `settings.read/write`
- Call backend methods for sync operations

Backend methods needed in `verstak-desktop`:
- `SyncStatus()` — get current sync status
- `SyncConfigure(serverURL, username, password)` — pair device
- `SyncDisconnect()` — disconnect and revoke
- `SyncTestConnection(serverURL, username, password)` — test credentials
- `SyncSetInterval(minutes)` — set auto-sync interval
- `SyncNow()` — trigger immediate sync
- `ResetSyncKey()` — clear device token

### Status Bar Item

Shows sync status in the bottom-right status bar:
- Icon: sync icon
- Label: status text (Connected/Disconnected/Error)
- Click: opens plugin settings

## [S4] Data Flow

```
┌─────────────────────────────────────────────────────────┐
│                    Verstak Desktop                       │
│  ┌──────────────┐    ┌──────────────┐    ┌───────────┐ │
│  │ Plugin Manager│───▶│ Sync Plugin  │───▶│ Settings  │ │
│  │   (Settings)  │    │  (UI Panel)  │    │   API     │ │
│  └──────────────┘    └──────┬───────┘    └───────────┘ │
│                             │                            │
│  ┌──────────────────────────▼──────────────────────────┐│
│  │              VerstakPluginAPI                        ││
│  │  settings.read/write → files.read/write              ││
│  └──────────────────────────┬──────────────────────────┘│
│                             │                            │
│  ┌──────────────────────────▼──────────────────────────┐│
│  │           Core Platform (Go Backend)                 ││
│  │  SyncService: RecordOp, GetUnpushedOps, MarkPushed  ││
│  │  SyncClient: Push, Pull, UploadBlob, DownloadBlob   ││
│  └──────────────────────────┬──────────────────────────┘│
└─────────────────────────────┼───────────────────────────┘
                              │ HTTP
                              ▼
┌─────────────────────────────────────────────────────────┐
│                  Verstak Sync Server                     │
│  SQLite: users, devices, ops, tombstones                │
│  Blobs: SHA-256 content-addressed storage               │
│  API: push/pull, pair, auth, admin                      │
└─────────────────────────────────────────────────────────┘
```

## [S5] Implementation Order

1. **Sync Server** — copy and adapt from `~/git/verstak/cmd/verstak-server/`
2. **Backend API** — add sync methods to `verstak-desktop/internal/api/app.go`
3. **Sync Plugin** — create plugin structure with manifest and frontend
4. **Settings UI** — implement `SyncSettings.svelte` component
5. **Status Bar** — add sync status indicator
6. **Testing** — E2E tests for settings UI, integration tests for sync

## [S6] Testing Strategy

- **Unit tests**: Sync client (push/pull), settings read/write
- **E2E tests**: Settings UI (configure, disconnect, sync now)
- **Integration tests**: Full sync cycle (two devices, push/pull)
- **Manual verification**: Real sync server with two vault instances
