# Sync Server & Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use compose:subagent (recommended) or compose:execute to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement sync server (separate repo) and sync plugin for Verstak2 platform.

**Architecture:** Sync server is a standalone Go HTTP server based on old Verstak server. Sync plugin is a dynamic plugin with settings UI registered via contributes.settingsPanels.

**Tech Stack:** Go (server), Svelte (plugin UI), SQLite (server DB), Wails (desktop integration)

---

## Phase 1: Sync Server

### Task 1: Initialize Sync Server Repository

**Covers:** [S1, S2]

**Files:**
- Create: `verstak-sync-server/go.mod`
- Create: `verstak-sync-server/cmd/server/main.go`
- Create: `verstak-sync-server/README.md`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p verstak-sync-server/cmd/server
mkdir -p verstak-sync-server/internal/server
```

- [ ] **Step 2: Initialize Go module**

```bash
cd verstak-sync-server
go mod init github.com/verstak/verstak-sync-server
```

- [ ] **Step 3: Create main.go entry point**

```go
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

func main() {
	port := flag.Int("port", 47732, "HTTP port")
	dataDir := flag.String("data", "./server-data", "Data directory (db, blobs, config)")
	adminUser := flag.String("admin-user", "", "Create admin user (first run)")
	adminPass := flag.String("admin-pass", "", "Admin password (first run)")
	flag.Parse()

	absData, err := filepath.Abs(*dataDir)
	if err != nil {
		log.Fatalf("data dir: %v", err)
	}

	if err := os.MkdirAll(absData, 0750); err != nil {
		log.Fatalf("create data dir: %v", err)
	}

	cfg, err := LoadConfig(absData)
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	if *adminUser != "" && *adminPass != "" {
		if err := cfg.SetAdmin(*adminUser, *adminPass); err != nil {
			log.Fatalf("set admin: %v", err)
		}
		fmt.Printf("Admin user %q created.\n", *adminUser)
	}

	dbPath := filepath.Join(absData, "server.db")
	srv, err := NewServer(dbPath, absData, cfg)
	if err != nil {
		log.Fatalf("server: %v", err)
	}
	defer srv.Close()

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("Verstak Sync Server starting on %s (data: %s)", addr, absData)
	if err := srv.ListenAndServe(addr); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
```

- [ ] **Step 4: Create README.md**

```markdown
# Verstak Sync Server

Standalone sync server for Verstak vaults.

## Quick Start

```bash
# First run with admin user
go run ./cmd/server --admin-user admin --admin-pass secret

# Subsequent runs
go run ./cmd/server
```

## API Endpoints

- `POST /api/v1/sync/push` — push operations
- `POST /api/v1/sync/pull` — pull operations
- `POST /api/v1/blobs/` — upload blob
- `GET /api/v1/blobs/:sha256` — download blob
- `POST /api/client/pair` — device pairing
- `GET /api/v1/health` — health check

## Configuration

Server config at `server-data/config.yml`:
```yaml
port: 47732
admin:
  - username: admin
    password_hash: "$2a$10$..."
```
```

- [ ] **Step 5: Commit**

```bash
cd verstak-sync-server
git init
git add .
git commit -m "feat: initialize sync server repository"
```

---

### Task 2: Implement Server Core

**Covers:** [S2]

**Files:**
- Create: `verstak-sync-server/internal/server/server.go`
- Create: `verstak-sync-server/internal/server/config.go`
- Create: `verstak-sync-server/internal/server/schema.go`

- [ ] **Step 1: Create server.go**

```go
package server

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type pairRateLimit struct {
	mu       sync.Mutex
	attempts map[string]int
}

func (p *pairRateLimit) allow(ip string) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.attempts == nil {
		p.attempts = make(map[string]int)
	}
	p.attempts[ip]++
	return p.attempts[ip] <= 5
}

func (p *pairRateLimit) reset(ip string) {
	p.mu.Lock()
	defer p.mu.Unlock()
	delete(p.attempts, ip)
}

type Server struct {
	db         *sql.DB
	cfg        *Config
	tokens     *tokenStore
	userTokens *userTokenStore
	blobsDir   string
	mux        *http.ServeMux
	pairLimit  *pairRateLimit
}

func (s *Server) auditLog(eventType, userID, deviceID, ip, msg string) {
	s.db.Exec("INSERT INTO server_audit_log (event_type, user_id, device_id, ip, message, created_at) VALUES (?, ?, ?, ?, ?, ?)",
		eventType, userID, deviceID, ip, msg, time.Now().UTC().Format(time.RFC3339))
}

func NewServer(dbPath, dataDir string, cfg *Config) (*Server, error) {
	db, err := sql.Open("sqlite3", fmt.Sprintf("file:%s?mode=rwc", dbPath))
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	db.SetMaxOpenConns(1)

	for _, stmt := range strings.Split(serverSchema, ";") {
		stmt = strings.TrimSpace(stmt)
		if stmt == "" {
			continue
		}
		if _, err := db.Exec(stmt); err != nil {
			db.Close()
			return nil, fmt.Errorf("schema: %w", err)
		}
	}

	db.Exec("ALTER TABLE server_users ADD COLUMN blocked INTEGER NOT NULL DEFAULT 0")
	db.Exec("ALTER TABLE server_users ADD COLUMN last_seen TEXT")
	db.Exec("ALTER TABLE server_devices ADD COLUMN token_hash TEXT")
	db.Exec("ALTER TABLE server_devices ADD COLUMN token_prefix TEXT")
	db.Exec("ALTER TABLE server_devices ADD COLUMN token_suffix TEXT")
	db.Exec("ALTER TABLE server_devices ADD COLUMN user_id TEXT")
	db.Exec("ALTER TABLE server_devices ADD COLUMN client_version TEXT")
	db.Exec("ALTER TABLE server_devices ADD COLUMN last_ip TEXT")
	db.Exec("ALTER TABLE server_devices ADD COLUMN revoked_at TEXT")
	db.Exec("ALTER TABLE server_ops ADD COLUMN server_sequence INTEGER")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_server_ops_sequence ON server_ops(server_sequence)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_server_ops_entity ON server_ops(entity_type, entity_id)")
	db.Exec(`CREATE TABLE IF NOT EXISTS server_tombstones (
		entity_type TEXT NOT NULL,
		entity_id TEXT NOT NULL,
		op_id TEXT NOT NULL,
		deleted_at TEXT NOT NULL,
		PRIMARY KEY (entity_type, entity_id)
	)`)
	db.Exec(`CREATE TABLE IF NOT EXISTS server_idempotency_keys (
		idempotency_key TEXT PRIMARY KEY,
		response_json TEXT NOT NULL,
		created_at TEXT NOT NULL
	)`)
	db.Exec(`ALTER TABLE server_ops ADD COLUMN idempotency_key TEXT`)
	db.Exec(`ALTER TABLE server_ops ADD COLUMN client_sequence INTEGER DEFAULT 0`)
	db.Exec(`ALTER TABLE server_ops ADD COLUMN last_seen_server_seq INTEGER DEFAULT 0`)

	blobsDir := filepath.Join(dataDir, "blobs")
	if err := os.MkdirAll(blobsDir, 0750); err != nil {
		db.Close()
		return nil, err
	}

	s := &Server{
		db:         db,
		cfg:        cfg,
		tokens:     newTokenStore(),
		userTokens: newUserTokenStore(),
		blobsDir:   blobsDir,
		pairLimit:  &pairRateLimit{},
	}
	s.mux = s.routes()
	return s, nil
}

func (s *Server) Close() error {
	return s.db.Close()
}

func (s *Server) ListenAndServe(addr string) error {
	return http.ListenAndServe(addr, s.mux)
}
```

- [ ] **Step 2: Create config.go**

```go
package server

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"golang.org/x/crypto/bcrypt"
	"gopkg.in/yaml.v3"
)

type AdminUser struct {
	Username     string `yaml:"username"`
	PasswordHash string `yaml:"password_hash"`
}

type Config struct {
	Port  int         `yaml:"port"`
	Admin []AdminUser `yaml:"admin"`
	mu    sync.Mutex
	path  string
}

func LoadConfig(dataDir string) (*Config, error) {
	path := filepath.Join(dataDir, "config.yml")
	cfg := &Config{
		Port:  47732,
		Admin: nil,
		path:  path,
	}
	data, err := os.ReadFile(path)
	if err == nil {
		if err := yaml.Unmarshal(data, cfg); err != nil {
			return nil, fmt.Errorf("parse config: %w", err)
		}
	}
	return cfg, nil
}

func (c *Config) Save() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.saveLocked()
}

func (c *Config) saveLocked() error {
	data, err := yaml.Marshal(c)
	if err != nil {
		return err
	}
	return os.WriteFile(c.path, data, 0640)
}

func (c *Config) SetAdmin(username, password string) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	user := AdminUser{Username: username, PasswordHash: string(hash)}
	for i, u := range c.Admin {
		if u.Username == username {
			c.Admin[i] = user
			return c.saveLocked()
		}
	}
	c.Admin = append(c.Admin, user)
	return c.saveLocked()
}

func (c *Config) CheckAdmin(username, password string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, u := range c.Admin {
		if u.Username == username {
			if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(password)) == nil {
				return true
			}
		}
	}
	return false
}
```

- [ ] **Step 3: Create schema.go**

```go
package server

const serverSchema = `
CREATE TABLE IF NOT EXISTS server_users (
	id TEXT PRIMARY KEY,
	username TEXT UNIQUE NOT NULL,
	email TEXT UNIQUE,
	password_hash TEXT NOT NULL,
	confirmed INTEGER NOT NULL DEFAULT 0,
	confirm_token TEXT,
	reset_token TEXT,
	reset_expires TEXT,
	created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS server_devices (
	id TEXT PRIMARY KEY,
	name TEXT NOT NULL,
	api_key TEXT,
	token_hash TEXT,
	token_prefix TEXT,
	token_suffix TEXT,
	user_id TEXT,
	client_version TEXT,
	last_ip TEXT,
	last_seen TEXT,
	revoked_at TEXT,
	created_at TEXT NOT NULL,
	FOREIGN KEY (user_id) REFERENCES server_users(id)
);

CREATE TABLE IF NOT EXISTS server_user_devices (
	user_id TEXT NOT NULL,
	device_id TEXT NOT NULL,
	PRIMARY KEY (user_id, device_id),
	FOREIGN KEY (user_id) REFERENCES server_users(id),
	FOREIGN KEY (device_id) REFERENCES server_devices(id)
);

CREATE TABLE IF NOT EXISTS server_ops (
	id TEXT PRIMARY KEY,
	op_id TEXT NOT NULL,
	device_id TEXT,
	entity_type TEXT NOT NULL,
	entity_id TEXT NOT NULL,
	op_type TEXT NOT NULL,
	payload_json TEXT,
	created_at TEXT NOT NULL,
	pushed_at TEXT,
	applied_at TEXT,
	server_sequence INTEGER,
	idempotency_key TEXT,
	client_sequence INTEGER DEFAULT 0,
	last_seen_server_seq INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS server_tombstones (
	entity_type TEXT NOT NULL,
	entity_id TEXT NOT NULL,
	op_id TEXT NOT NULL,
	deleted_at TEXT NOT NULL,
	PRIMARY KEY (entity_type, entity_id)
);

CREATE TABLE IF NOT EXISTS server_idempotency_keys (
	idempotency_key TEXT PRIMARY KEY,
	response_json TEXT NOT NULL,
	created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS server_audit_log (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	event_type TEXT NOT NULL,
	user_id TEXT,
	device_id TEXT,
	ip TEXT,
	message TEXT,
	created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_server_ops_sequence ON server_ops(server_sequence);
CREATE INDEX IF NOT EXISTS idx_server_ops_entity ON server_ops(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_server_devices_token ON server_devices(token_hash);
CREATE INDEX IF NOT EXISTS idx_server_devices_user ON server_devices(user_id);
`
```

- [ ] **Step 4: Add dependencies**

```bash
cd verstak-sync-server
go get github.com/mattn/go-sqlite3
go get golang.org/x/crypto/bcrypt
go get gopkg.in/yaml.v3
```

- [ ] **Step 5: Commit**

```bash
git add internal/server/
git commit -m "feat: add server core (server, config, schema)"
```

---

### Task 3: Implement Routes and Handlers

**Covers:** [S2]

**Files:**
- Create: `verstak-sync-server/internal/server/routes.go`
- Create: `verstak-sync-server/internal/server/handlers_api.go`
- Create: `verstak-sync-server/internal/server/handlers_auth.go`
- Create: `verstak-sync-server/internal/server/middleware.go`
- Create: `verstak-sync-server/internal/server/tokens.go`

- [ ] **Step 1: Create routes.go**

```go
package server

import "net/http"

func (s *Server) routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/health", s.handleHealth)
	mux.HandleFunc("/api/v1/device/register", s.handleDeviceRegister)
	mux.HandleFunc("/api/v1/sync/push", s.handleSyncPush)
	mux.HandleFunc("/api/v1/sync/pull", s.handleSyncPull)
	mux.HandleFunc("/api/v1/blobs/", s.handleBlobs)
	mux.HandleFunc("/api/client/pair", s.handleClientPair)
	mux.HandleFunc("/api/auth/test", s.handleAuthTest)
	mux.HandleFunc("/api/client/revoke-current", s.handleClientRevoke)
	mux.HandleFunc("/api/client/me", s.handleClientMe)
	mux.HandleFunc("/api/client/revoke-device", s.handleClientRevokeDevice)
	mux.HandleFunc("/", s.handleNotFound)
	return mux
}
```

- [ ] **Step 2: Create handlers_api.go**

Copy from `~/git/verstak/cmd/verstak-server/handlers_api.go` and update package name to `server`.

- [ ] **Step 3: Create handlers_auth.go**

Copy from `~/git/verstak/cmd/verstak-server/handlers_user.go` (auth endpoints only) and update package name.

- [ ] **Step 4: Create middleware.go**

```go
package server

import (
	"net/http"
	"strings"
)

func (s *Server) requireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tok := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if tok == "" {
			jsonErr(w, 401, "token required")
			return
		}
		next(w, r)
	}
}

func (s *Server) requireAdmin(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		username, password, ok := r.BasicAuth()
		if !ok || !s.cfg.CheckAdmin(username, password) {
			jsonErr(w, 401, "admin auth required")
			return
		}
		next(w, r)
	}
}
```

- [ ] **Step 5: Create tokens.go**

Copy from `~/git/verstak/cmd/verstak-server/tokens.go` and update package name.

- [ ] **Step 6: Create helpers.go**

```go
package server

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
)

func jsonOK(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func jsonErr(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func sha256Hex(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}
```

- [ ] **Step 7: Commit**

```bash
git add internal/server/
git commit -m "feat: add routes and API handlers"
```

---

### Task 4: Test Sync Server

**Covers:** [S2]

**Files:**
- Create: `verstak-sync-server/internal/server/server_test.go`

- [ ] **Step 1: Create server_test.go**

```go
package server

import (
	"testing"
	"os"
	"path/filepath"
)

func TestNewServer(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")
	cfg := &Config{Port: 0}

	srv, err := NewServer(dbPath, dir, cfg)
	if err != nil {
		t.Fatalf("NewServer failed: %v", err)
	}
	defer srv.Close()

	// Verify DB exists
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		t.Error("database file not created")
	}
}

func TestConfigSetAdmin(t *testing.T) {
	dir := t.TempDir()
	cfg := &Config{Port: 0, path: filepath.Join(dir, "config.yml")}

	if err := cfg.SetAdmin("admin", "password123"); err != nil {
		t.Fatalf("SetAdmin failed: %v", err)
	}

	if !cfg.CheckAdmin("admin", "password123") {
		t.Error("CheckAdmin should return true for correct password")
	}

	if cfg.CheckAdmin("admin", "wrong") {
		t.Error("CheckAdmin should return false for wrong password")
	}
}
```

- [ ] **Step 2: Run tests**

```bash
cd verstak-sync-server
go test ./internal/server/ -v
```

Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add internal/server/server_test.go
git commit -m "test: add server unit tests"
```

---

## Phase 2: Desktop Backend API

### Task 5: Add Sync Backend Methods

**Covers:** [S3, S4]

**Files:**
- Create: `verstak-desktop/internal/core/sync/client.go`
- Create: `verstak-desktop/internal/core/sync/service.go`
- Modify: `verstak-desktop/internal/api/app.go`

- [ ] **Step 1: Create sync/client.go**

```go
package sync

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

type Client struct {
	ServerURL   string
	APIKey      string
	DeviceToken string
	DeviceID    string
	VaultRoot   string
	HTTP        *http.Client
}

func NewClient(serverURL, apiKey, deviceID, vaultRoot string) *Client {
	return &Client{
		ServerURL: serverURL,
		APIKey:    apiKey,
		DeviceID:  deviceID,
		VaultRoot: vaultRoot,
		HTTP:      &http.Client{Timeout: 30 * time.Second},
	}
}

type DeviceInfo struct {
	DeviceID      string `json:"device_id"`
	UserID        string `json:"user_id"`
	Username      string `json:"username"`
	DeviceName    string `json:"device_name"`
	ClientVersion string `json:"client_version"`
	LastSeen      string `json:"last_seen"`
	RevokedAt     string `json:"revoked_at"`
	CreatedAt     string `json:"created_at"`
}

func (c *Client) PairDevice(serverURL, username, password, deviceName, clientVersion string) (deviceID, deviceToken string, err error) {
	body := map[string]string{
		"login":          username,
		"password":       password,
		"device_name":    deviceName,
		"client_version": clientVersion,
	}
	var resp struct {
		DeviceID    string `json:"device_id"`
		DeviceToken string `json:"device_token"`
	}
	savedURL := c.ServerURL
	c.ServerURL = serverURL
	err = c.post("/api/client/pair", body, &resp)
	c.ServerURL = savedURL
	if err != nil {
		return "", "", err
	}
	return resp.DeviceID, resp.DeviceToken, nil
}

func (c *Client) GetMe() (*DeviceInfo, error) {
	var resp DeviceInfo
	if err := c.get("/api/client/me", &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

func (c *Client) RevokeCurrent() error {
	var resp struct {
		Status string `json:"status"`
	}
	return c.post("/api/client/revoke-current", nil, &resp)
}

func (c *Client) TestAuth(serverURL, username, password string) error {
	body := map[string]string{"username": username, "password": password}
	savedURL := c.ServerURL
	savedKey := c.APIKey
	c.ServerURL = serverURL
	c.APIKey = ""
	err := c.post("/api/auth/test", body, nil)
	c.ServerURL = savedURL
	c.APIKey = savedKey
	return err
}

type PushOp struct {
	OpID              string `json:"op_id"`
	EntityType        string `json:"entity_type"`
	EntityID          string `json:"entity_id"`
	OpType            string `json:"op_type"`
	PayloadJSON       string `json:"payload_json"`
	ClientSequence    int    `json:"client_sequence"`
	LastSeenServerSeq int    `json:"last_seen_server_seq"`
	CreatedAt         string `json:"created_at"`
}

type PushResponse struct {
	Accepted  []string                 `json:"accepted"`
	Count     int                      `json:"count"`
	Conflicts []map[string]interface{} `json:"conflicts"`
}

func (c *Client) Push(ops []PushOp) (*PushResponse, error) {
	req := struct {
		DeviceID string   `json:"device_id"`
		Ops      []PushOp `json:"ops"`
	}{
		DeviceID: c.DeviceID,
		Ops:      ops,
	}
	var resp PushResponse
	if err := c.post("/api/v1/sync/push", req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

type PullResponse struct {
	ServerSequence int    `json:"server_sequence"`
	Ops            []Op   `json:"ops"`
}

type Op struct {
	OpID        string `json:"op_id"`
	EntityType  string `json:"entity_type"`
	EntityID    string `json:"entity_id"`
	OpType      string `json:"op_type"`
	PayloadJSON string `json:"payload_json"`
	CreatedAt   string `json:"created_at"`
}

func (c *Client) Pull(sinceSequence int) (*PullResponse, error) {
	req := struct {
		SinceSequence int `json:"since_sequence"`
	}{
		SinceSequence: sinceSequence,
	}
	var resp PullResponse
	if err := c.post("/api/v1/sync/pull", req, &resp); err != nil {
		return nil, err
	}
	return &resp, nil
}

func (c *Client) UploadBlob(localPath string) (sha256 string, err error) {
	var b bytes.Buffer
	w := multipart.NewWriter(&b)
	fw, err := w.CreateFormFile("file", filepath.Base(localPath))
	if err != nil {
		return "", err
	}
	f, err := os.Open(localPath)
	if err != nil {
		return "", err
	}
	defer f.Close()
	if _, err := io.Copy(fw, f); err != nil {
		return "", err
	}
	w.Close()

	req, err := http.NewRequest("POST", c.ServerURL+"/api/v1/blobs/", &b)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", w.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+c.bearerToken())

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var result struct {
		SHA256 string `json:"sha256"`
		Size   int    `json:"size"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	return result.SHA256, nil
}

func (c *Client) DownloadBlob(sha256, destPath string) error {
	req, err := http.NewRequest("GET", c.ServerURL+"/api/v1/blobs/"+sha256, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.bearerToken())

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("download blob: HTTP %d", resp.StatusCode)
	}

	out, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, resp.Body)
	return err
}

func (c *Client) bearerToken() string {
	if c.DeviceToken != "" {
		return c.DeviceToken
	}
	return c.APIKey
}

func (c *Client) post(path string, body, result interface{}) error {
	var b bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&b).Encode(body); err != nil {
			return err
		}
	}
	req, err := http.NewRequest("POST", c.ServerURL+path, &b)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.bearerToken())

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("http: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		data, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("server %d: %s", resp.StatusCode, string(data))
	}

	if result != nil {
		return json.NewDecoder(resp.Body).Decode(result)
	}
	return nil
}

func (c *Client) get(path string, result interface{}) error {
	req, err := http.NewRequest("GET", c.ServerURL+path, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.bearerToken())

	resp, err := c.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("http: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		data, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("server %d: %s", resp.StatusCode, string(data))
	}

	if result != nil {
		return json.NewDecoder(resp.Body).Decode(result)
	}
	return nil
}
```

- [ ] **Step 2: Create sync/service.go**

```go
package sync

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

type Service struct {
	db       *sql.DB
	deviceID string
}

func NewService(db *sql.DB, deviceID string) *Service {
	return &Service{db: db, deviceID: deviceID}
}

type SyncOp struct {
	ID                string  `json:"id"`
	OpID              string  `json:"op_id"`
	DeviceID          string  `json:"device_id"`
	EntityType        string  `json:"entity_type"`
	EntityID          string  `json:"entity_id"`
	OpType            string  `json:"op_type"`
	PayloadJSON       string  `json:"payload_json"`
	CreatedAt         string  `json:"created_at"`
	PushedAt          *string `json:"pushed_at,omitempty"`
	ClientSequence    int     `json:"client_sequence,omitempty"`
	LastSeenServerSeq int     `json:"last_seen_server_seq,omitempty"`
}

func (s *Service) RecordOp(entityType, entityID, opType string, payload interface{}) error {
	id := fmt.Sprintf("%d", time.Now().UnixNano())
	now := time.Now().UTC().Format(time.RFC3339)

	var payloadStr string
	if payload != nil {
		b, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		payloadStr = string(b)
	}

	_, err := s.db.Exec(
		`INSERT INTO sync_ops (id, op_id, device_id, entity_type, entity_id, op_type, payload_json, created_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		id, id, s.deviceID, entityType, entityID, opType, payloadStr, now,
	)
	return err
}

func (s *Service) GetUnpushedOps() ([]SyncOp, error) {
	rows, err := s.db.Query(
		`SELECT id, op_id, device_id, entity_type, entity_id, op_type, payload_json, created_at
		 FROM sync_ops WHERE pushed_at IS NULL ORDER BY created_at`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ops []SyncOp
	for rows.Next() {
		var o SyncOp
		if err := rows.Scan(&o.ID, &o.OpID, &o.DeviceID, &o.EntityType, &o.EntityID,
			&o.OpType, &o.PayloadJSON, &o.CreatedAt); err != nil {
			return nil, err
		}
		ops = append(ops, o)
	}
	return ops, rows.Err()
}

func (s *Service) MarkPushed(opIDs []string) error {
	now := time.Now().UTC().Format(time.RFC3339)
	for _, id := range opIDs {
		_, err := s.db.Exec("UPDATE sync_ops SET pushed_at=? WHERE op_id=?", now, id)
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) GetState() (serverURL, apiKey string, lastPullSeq int, lastSyncAt string, err error) {
	err = s.db.QueryRow(
		`SELECT server_url, api_key, last_pull_seq, COALESCE(last_sync_at,'') FROM sync_state WHERE device_id=?`,
		s.deviceID).Scan(&serverURL, &apiKey, &lastPullSeq, &lastSyncAt)
	if err == sql.ErrNoRows {
		return "", "", 0, "", nil
	}
	return
}

func (s *Service) SetState(serverURL, apiKey string) error {
	_, err := s.db.Exec(
		`INSERT INTO sync_state (device_id, server_url, api_key, last_pull_seq, last_sync_at)
		 VALUES (?, ?, ?, 0, '')
		 ON CONFLICT(device_id) DO UPDATE SET
		   server_url=excluded.server_url,
		   api_key=excluded.api_key`,
		s.deviceID, serverURL, apiKey,
	)
	return err
}

func (s *Service) SetLastPullSeq(seq int) error {
	_, err := s.db.Exec("UPDATE sync_state SET last_pull_seq=? WHERE device_id=?", seq, s.deviceID)
	return err
}

func (s *Service) SetLastSyncAt(t string) error {
	_, err := s.db.Exec("UPDATE sync_state SET last_sync_at=? WHERE device_id=?", t, s.deviceID)
	return err
}

func (s *Service) GetDeviceID() string {
	return s.deviceID
}
```

- [ ] **Step 3: Add sync methods to app.go**

Add these methods to `verstak-desktop/internal/api/app.go`:

```go
func (a *App) SyncStatus() (map[string]interface{}, error) {
	// Return current sync status
}

func (a *App) SyncConfigure(serverURL, username, password string) error {
	// Pair device with server
}

func (a *App) SyncDisconnect() error {
	// Disconnect and revoke device
}

func (a *App) SyncTestConnection(serverURL, username, password string) error {
	// Test server credentials
}

func (a *App) SyncSetInterval(minutes int) error {
	// Set auto-sync interval
}

func (a *App) SyncNow() (map[string]interface{}, error) {
	// Trigger immediate sync
}

func (a *App) ResetSyncKey() error {
	// Clear device token
}
```

- [ ] **Step 4: Commit**

```bash
git add internal/core/sync/ internal/api/app.go
git commit -m "feat: add sync backend methods"
```

---

## Phase 3: Sync Plugin

### Task 6: Create Plugin Structure

**Covers:** [S3]

**Files:**
- Create: `verstak-official-plugins/plugins/sync/plugin.json`
- Create: `verstak-official-plugins/plugins/sync/frontend/src/index.js`
- Create: `verstak-official-plugins/plugins/sync/frontend/src/SyncSettings.svelte`
- Create: `verstak-official-plugins/plugins/sync/frontend/src/SyncStatusBar.svelte`
- Create: `verstak-official-plugins/plugins/sync/frontend/package.json`

- [ ] **Step 1: Create plugin.json**

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
  "provides": [
    "verstak/sync/v1",
    "verstak/sync.status/v1"
  ],
  "requires": [
    "verstak/core/files/v1"
  ],
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
    "settingsPanels": [
      {
        "id": "verstak.sync.settings",
        "title": "Sync",
        "component": "SyncSettings"
      }
    ],
    "statusBarItems": [
      {
        "id": "verstak.sync.status",
        "label": "Sync",
        "position": "right"
      }
    ]
  }
}
```

- [ ] **Step 2: Create frontend package.json**

```json
{
  "name": "verstak-sync-plugin",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "build": "vite build",
    "dev": "vite build --watch"
  },
  "devDependencies": {
    "vite": "^5.0.0",
    "@sveltejs/vite-plugin-svelte": "^3.0.0",
    "svelte": "^4.0.0"
  }
}
```

- [ ] **Step 3: Create frontend/src/index.js**

```javascript
import SyncSettings from './SyncSettings.svelte';
import SyncStatusBar from './SyncStatusBar.svelte';

window.VerstakPluginRegister('verstak.sync', {
  components: {
    SyncSettings: {
      mount(container, props, api) {
        return new SyncSettings({
          target: container,
          props: { ...props, api }
        });
      },
      unmount(container) {
        // Svelte handles cleanup
      }
    },
    SyncStatusBar: {
      mount(container, props, api) {
        return new SyncStatusBar({
          target: container,
          props: { ...props, api }
        });
      },
      unmount(container) {
        // Svelte handles cleanup
      }
    }
  }
});
```

- [ ] **Step 4: Commit**

```bash
git add plugins/sync/
git commit -m "feat: create sync plugin structure"
```

---

### Task 7: Implement SyncSettings Component

**Covers:** [S3, S4]

**Files:**
- Create: `verstak-official-plugins/plugins/sync/frontend/src/SyncSettings.svelte`

- [ ] **Step 1: Create SyncSettings.svelte**

```svelte
<script>
  export let api = null;

  let settings = null;
  let loading = false;
  let errorMsg = '';
  let resultMsg = '';
  let resultKind = '';

  let serverUrl = '';
  let username = '';
  let password = '';
  let syncInterval = 0;
  let autoSync = false;
  let showDisconnectConfirm = false;
  let showResetKeyConfirm = false;
  let connectionOk = null;

  async function load() {
    try {
      settings = await api.settings.read();
      if (settings) {
        serverUrl = settings.serverUrl || '';
        syncInterval = settings.syncInterval || 0;
        autoSync = settings.autoSync || false;
      }
    } catch (e) {
      settings = null;
    }
  }

  load();

  async function testConnection() {
    loading = true;
    errorMsg = '';
    resultKind = '';
    connectionOk = null;
    try {
      await api.commands.execute('verstak.sync.testConnection', {
        serverUrl,
        username,
        password
      });
      connectionOk = true;
      resultMsg = 'connection ok';
    } catch (e) {
      connectionOk = false;
      resultMsg = 'connection failed: ' + String(e);
    }
    loading = false;
  }

  async function configureSync() {
    loading = true;
    errorMsg = '';
    resultKind = '';
    try {
      await api.commands.execute('verstak.sync.configure', {
        serverUrl,
        username,
        password
      });
      resultMsg = 'configured';
      username = '';
      password = '';
      await load();
    } catch (e) {
      errorMsg = String(e);
    }
    loading = false;
  }

  async function runSyncNow() {
    loading = true;
    errorMsg = '';
    resultKind = '';
    try {
      const r = await api.commands.execute('verstak.sync.syncNow');
      const summary = `Pushed: ${r?.pushed || 0}, Pulled: ${r?.pulled || 0}`;
      resultMsg = summary;
      await load();
    } catch (e) {
      errorMsg = String(e);
    }
    loading = false;
  }

  async function setInterval() {
    try {
      await api.settings.write('syncInterval', syncInterval);
      resultMsg = 'settings saved';
      resultKind = '';
    } catch (e) {
      errorMsg = String(e);
    }
  }

  async function setAutoSync() {
    try {
      await api.settings.write('autoSync', autoSync);
      resultMsg = 'settings saved';
      resultKind = '';
    } catch (e) {
      errorMsg = String(e);
    }
  }

  function confirmDisconnect() {
    showDisconnectConfirm = true;
  }

  async function doDisconnect() {
    showDisconnectConfirm = false;
    loading = true;
    resultKind = '';
    try {
      await api.commands.execute('verstak.sync.disconnect');
      resultMsg = 'disconnected';
      await load();
    } catch (e) {
      errorMsg = String(e);
    }
    loading = false;
  }

  function confirmResetKey() {
    showResetKeyConfirm = true;
  }

  async function doResetKey() {
    showResetKeyConfirm = false;
    loading = true;
    resultKind = '';
    try {
      await api.commands.execute('verstak.sync.resetKey');
      resultMsg = 'key reset';
      await load();
    } catch (e) {
      errorMsg = String(e);
    }
    loading = false;
  }

  function statusLabel(s) {
    if (!s) return 'Not configured';
    const labels = {
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'disabled': 'Not configured',
      'error': 'Error',
      'revoked': 'Revoked',
    };
    return labels[s] || s;
  }
</script>

<div class="settings-section">
  <h2>Sync</h2>
  <p class="section-desc">Synchronize your vault across devices via Verstak Sync Server.</p>

  {#if errorMsg}
    <div class="error-msg">{errorMsg}</div>
  {/if}
  {#if resultMsg && !errorMsg}
    <div class="result-msg" class:warning={resultKind === 'warning'}>{resultMsg}</div>
  {/if}

  {#if settings && settings.serverUrl}
    <div class="settings-card">
      <div class="sync-info">
        <div class="info-row">
          <span class="info-label">Status</span>
          <span class="info-value" class:status-ok={settings.lastStatus === 'connected'} class:status-err={settings.lastStatus === 'error' || settings.lastStatus === 'revoked'}>
            {statusLabel(settings.lastStatus)}
          </span>
        </div>
        {#if settings.serverUrl}
          <div class="info-row">
            <span class="info-label">Server</span>
            <span class="info-value mono">{settings.serverUrl}</span>
          </div>
        {/if}
        {#if settings.deviceName}
          <div class="info-row">
            <span class="info-label">Device</span>
            <span class="info-value">{settings.deviceName}</span>
          </div>
        {/if}
        {#if settings.deviceId}
          <div class="info-row">
            <span class="info-label">Device ID</span>
            <span class="info-value mono">{settings.deviceId}</span>
          </div>
        {/if}
        {#if settings.lastSyncAt}
          <div class="info-row">
            <span class="info-label">Last Sync</span>
            <span class="info-value">{settings.lastSyncAt}</span>
          </div>
        {/if}
        {#if settings.lastError}
          <div class="info-row">
            <span class="info-label">Last Error</span>
            <span class="info-value error">{settings.lastError}</span>
          </div>
        {/if}
      </div>
    </div>

    <div class="sync-actions">
      <button class="btn btn-primary" on:click={runSyncNow} disabled={loading}>
        Sync Now
      </button>
      <button class="btn" on:click={confirmDisconnect} disabled={loading}>
        Disconnect
      </button>
      <button class="btn" on:click={confirmResetKey} disabled={loading}>
        Reset Key
      </button>
    </div>

    <div class="sync-interval">
      <label>
        <span class="label-text">Sync Interval (minutes)</span>
        <div class="interval-row">
          <input type="number" bind:value={syncInterval} min="0" placeholder="0" />
          <button class="btn btn-sm" on:click={setInterval}>Save</button>
        </div>
      </label>
    </div>

    <div class="sync-autosync">
      <label>
        <input type="checkbox" bind:checked={autoSync} on:change={setAutoSync} />
        <span class="label-text">Auto-sync</span>
      </label>
    </div>
  {:else}
    <div class="settings-card">
      <div class="sync-setup">
        <div class="form-group">
          <label>
            <span class="label-text">Server URL</span>
            <input type="text" placeholder="https://example.com" bind:value={serverUrl} />
          </label>
        </div>
        <div class="form-group">
          <label>
            <span class="label-text">Username</span>
            <input type="text" bind:value={username} />
          </label>
        </div>
        <div class="form-group">
          <label>
            <span class="label-text">Password</span>
            <input type="password" bind:value={password} />
          </label>
        </div>
        <div class="sync-setup-actions">
          <button class="btn" on:click={testConnection} disabled={loading || !serverUrl}>
            Test Connection
          </button>
          <button class="btn btn-primary" on:click={configureSync}
                  disabled={loading || !serverUrl || !username || !password}>
            Connect
          </button>
        </div>
        {#if connectionOk !== null}
          <div class="connection-result" class:ok={connectionOk} class:fail={!connectionOk}>
            {connectionOk ? 'Test OK' : 'Connection failed'}
          </div>
        {/if}
      </div>
    </div>
  {/if}
</div>

{#if showDisconnectConfirm}
  <button class="modal-overlay" on:click={() => showDisconnectConfirm = false}>
    <div class="modal">
      <h3>Disconnect?</h3>
      <p class="modal-desc">This will revoke this device's access to the sync server.</p>
      <div class="modal-actions">
        <button class="btn btn-danger" on:click={doDisconnect}>Disconnect</button>
        <button class="btn" on:click={() => showDisconnectConfirm = false}>Cancel</button>
      </div>
    </div>
  </button>
{/if}

{#if showResetKeyConfirm}
  <button class="modal-overlay" on:click={() => showResetKeyConfirm = false}>
    <div class="modal">
      <h3>Reset Key?</h3>
      <p class="modal-desc">This will clear the device token. You'll need to reconnect.</p>
      <div class="modal-actions">
        <button class="btn btn-danger" on:click={doResetKey}>Reset</button>
        <button class="btn" on:click={() => showResetKeyConfirm = false}>Cancel</button>
      </div>
    </div>
  </button>
{/if}

<style>
  .settings-section {
    padding: 1.5rem;
    max-width: 600px;
  }
  .settings-section h2 {
    margin: 0 0 0.25rem 0;
    font-size: 1.2rem;
    color: #e0e0e0;
  }
  .section-desc {
    color: #888;
    font-size: 0.85rem;
    margin-bottom: 1.25rem;
    line-height: 1.4;
  }
  .settings-card {
    background: #1e1e30;
    border: 1px solid #2a2a3e;
    border-radius: 8px;
    padding: 1rem 1.25rem;
    margin-bottom: 1rem;
  }
  .info-row {
    display: flex;
    padding: 0.4rem 0;
    border-bottom: 1px solid #2a2a3e;
    font-size: 0.9rem;
  }
  .info-row:last-child { border-bottom: none; }
  .info-label {
    width: 180px;
    min-width: 180px;
    color: #888;
  }
  .info-value { color: #e0e0e0; word-break: break-all; }
  .info-value.mono { font-family: monospace; font-size: 0.85rem; }
  .info-value.error { color: #ff6b6b; }
  .status-ok { color: #34d399; font-weight: 600; }
  .status-err { color: #ff6b6b; }
  .sync-actions {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
    margin-bottom: 1rem;
  }
  .sync-interval {
    margin-bottom: 0.5rem;
  }
  .interval-row {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }
  .interval-row input {
    width: 100px;
  }
  .sync-autosync {
    margin-bottom: 0;
  }
  .sync-autosync label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
  }
  .sync-setup .form-group { margin-bottom: 1rem; }
  .sync-setup .form-group:last-of-type { margin-bottom: 0; }
  .sync-setup-actions {
    display: flex;
    gap: 0.5rem;
    margin-top: 1rem;
  }
  .connection-result {
    margin-top: 0.75rem;
    padding: 0.4rem 0.75rem;
    border-radius: 6px;
    font-size: 0.85rem;
  }
  .connection-result.ok {
    background: rgba(52, 211, 153, 0.1);
    border: 1px solid rgba(52, 211, 153, 0.3);
    color: #34d399;
  }
  .connection-result.fail {
    background: rgba(255, 107, 107, 0.1);
    border: 1px solid rgba(255, 107, 107, 0.3);
    color: #ff6b6b;
  }
  .error-msg {
    padding: 0.5rem 0.75rem;
    margin-bottom: 0.75rem;
    background: rgba(255, 107, 107, 0.1);
    border: 1px solid rgba(255, 107, 107, 0.3);
    border-radius: 6px;
    color: #ff6b6b;
    font-size: 0.85rem;
  }
  .result-msg {
    padding: 0.5rem 0.75rem;
    margin-bottom: 0.75rem;
    background: rgba(52, 211, 153, 0.1);
    border: 1px solid rgba(52, 211, 153, 0.3);
    border-radius: 6px;
    color: #34d399;
    font-size: 0.85rem;
  }
  .result-msg.warning {
    background: rgba(245, 158, 11, 0.1);
    border-color: rgba(245, 158, 11, 0.3);
    color: #f59e0b;
  }
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    border: none;
    padding: 0;
    cursor: pointer;
    width: 100%;
    color: inherit;
    font: inherit;
  }
  .modal {
    background: #1e1e2e;
    border: 1px solid #2a2a3e;
    border-radius: 10px;
    padding: 1.5rem;
    max-width: 420px;
    width: 90%;
    cursor: default;
  }
  .modal h3 { margin: 0 0 0.75rem 0; }
  .modal-desc { color: #888; font-size: 0.9rem; line-height: 1.5; margin-bottom: 1rem; }
  .modal-actions { display: flex; gap: 0.5rem; justify-content: flex-end; }
</style>
```

- [ ] **Step 2: Commit**

```bash
git add plugins/sync/frontend/src/SyncSettings.svelte
git commit -m "feat: implement SyncSettings component"
```

---

### Task 8: Implement SyncStatusBar Component

**Covers:** [S3, S4]

**Files:**
- Create: `verstak-official-plugins/plugins/sync/frontend/src/SyncStatusBar.svelte`

- [ ] **Step 1: Create SyncStatusBar.svelte**

```svelte
<script>
  import { onMount, onDestroy } from 'svelte';

  export let api = null;

  let status = 'disabled';
  let loading = false;
  let interval = null;

  async function loadStatus() {
    try {
      const settings = await api.settings.read();
      status = settings?.lastStatus || 'disabled';
    } catch (e) {
      status = 'error';
    }
  }

  onMount(() => {
    loadStatus();
    interval = setInterval(loadStatus, 30000);
  });

  onDestroy(() => {
    if (interval) clearInterval(interval);
  });

  function statusColor(s) {
    switch (s) {
      case 'connected': return '#34d399';
      case 'error': return '#ff6b6b';
      case 'revoked': return '#ff6b6b';
      default: return '#888';
    }
  }

  function statusText(s) {
    switch (s) {
      case 'connected': return 'Sync: Connected';
      case 'error': return 'Sync: Error';
      case 'revoked': return 'Sync: Revoked';
      default: return 'Sync: Off';
    }
  }
</script>

<button
  class="sync-status-bar"
  style="color: {statusColor(status)}"
  on:click={() => api.commands.execute('verstak.sync.openSettings')}
  title="Click to open sync settings"
>
  <span class="status-dot" style="background: {statusColor(status)}"></span>
  <span class="status-text">{statusText(status)}</span>
</button>

<style>
  .sync-status-bar {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.25rem 0.5rem;
    background: transparent;
    border: none;
    cursor: pointer;
    font-size: 0.75rem;
    font-family: inherit;
    color: inherit;
    transition: opacity 0.15s;
  }
  .sync-status-bar:hover {
    opacity: 0.8;
  }
  .status-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .status-text {
    white-space: nowrap;
  }
</style>
```

- [ ] **Step 2: Commit**

```bash
git add plugins/sync/frontend/src/SyncStatusBar.svelte
git commit -m "feat: implement SyncStatusBar component"
```

---

### Task 9: Build Plugin Frontend

**Covers:** [S3]

**Files:**
- Create: `verstak-official-plugins/plugins/sync/frontend/vite.config.js`

- [ ] **Step 1: Create vite.config.js**

```javascript
import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte()],
  build: {
    outDir: 'dist',
    lib: {
      entry: 'src/index.js',
      formats: ['iife'],
      name: 'VerstakSyncPlugin'
    },
    rollupOptions: {
      output: {
        entryFileNames: 'index.js',
        assetFileNames: '[name][extname]'
      }
    }
  }
});
```

- [ ] **Step 2: Install dependencies and build**

```bash
cd verstak-official-plugins/plugins/sync/frontend
npm install
npm run build
```

- [ ] **Step 3: Commit**

```bash
git add plugins/sync/frontend/
git commit -m "feat: build sync plugin frontend"
```

---

## Phase 4: Testing

### Task 10: Add E2E Tests

**Covers:** [S6]

**Files:**
- Create: `verstak-official-plugins/plugins/sync/e2e/sync-settings.spec.js`

- [ ] **Step 1: Create e2e test**

```javascript
import { test, expect } from '@playwright/test';

test.describe('Sync Plugin Settings', () => {
  test('shows setup form when not configured', async ({ page }) => {
    await page.goto('/');
    await page.click('[data-plugin="verstak.sync"]');
    await page.click('[data-action="settings"]');

    await expect(page.locator('.sync-setup')).toBeVisible();
    await expect(page.locator('input[placeholder="https://example.com"]')).toBeVisible();
  });

  test('shows status when configured', async ({ page }) => {
    // Mock configured state
    await page.goto('/');
    await page.evaluate(() => {
      localStorage.setItem('verstak-sync-settings', JSON.stringify({
        serverUrl: 'https://sync.example.com',
        lastStatus: 'connected',
        deviceName: 'test-device'
      }));
    });

    await page.click('[data-plugin="verstak.sync"]');
    await page.click('[data-action="settings"]');

    await expect(page.locator('.sync-info')).toBeVisible();
    await expect(page.locator('.status-ok')).toBeVisible();
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add plugins/sync/e2e/
git commit -m "test: add sync plugin E2E tests"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Initialize sync server repo | main.go, README.md |
| 2 | Server core | server.go, config.go, schema.go |
| 3 | Routes and handlers | routes.go, handlers_api.go, etc. |
| 4 | Server tests | server_test.go |
| 5 | Desktop backend API | sync/client.go, sync/service.go, app.go |
| 6 | Plugin structure | plugin.json, package.json, index.js |
| 7 | SyncSettings component | SyncSettings.svelte |
| 8 | SyncStatusBar component | SyncStatusBar.svelte |
| 9 | Build frontend | vite.config.js |
| 10 | E2E tests | sync-settings.spec.js |
