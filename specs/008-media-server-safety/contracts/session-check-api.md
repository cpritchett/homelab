# Contract: Session Check API

## Purpose

Defines how the deployment agent checks for active sessions on critical services before deploying.

## Plex Session Check

**Request**:
```
GET https://plex.in.hypyr.space/status/sessions?X-Plex-Token={token}
Accept: application/json
```

**Response** (active sessions exist):
```json
{
  "MediaContainer": {
    "size": 2,
    "Metadata": [
      {
        "title": "Movie Title",
        "Player": { "state": "playing" },
        "User": { "title": "username" }
      },
      {
        "title": "TV Show S01E05",
        "Player": { "state": "paused" },
        "User": { "title": "other_user" }
      }
    ]
  }
}
```

**Response** (no active sessions):
```json
{
  "MediaContainer": {
    "size": 0
  }
}
```

**Active session criteria**: `Player.state` is `"playing"` or `"paused"`.

## Jellyfin Session Check

**Request**:
```
GET https://jellyfin.in.hypyr.space/Sessions?ApiKey={key}
```

**Response** (array — filter for active):
```json
[
  {
    "UserName": "username",
    "NowPlayingItem": {
      "Name": "Movie Title",
      "Type": "Movie"
    },
    "PlayState": {
      "IsPaused": false
    }
  },
  {
    "UserName": "idle_user"
  }
]
```

**Active session criteria**: `NowPlayingItem` is present (non-null). Covers both playing (`IsPaused: false`) and paused (`IsPaused: true`).

## Error Handling

| Scenario              | Agent Behavior                                          |
| --------------------- | ------------------------------------------------------- |
| HTTP 200, 0 sessions  | Proceed with deploy                                     |
| HTTP 200, >0 sessions | Block deploy, report count and details to operator      |
| HTTP 401/403          | Warn operator: API token may be invalid; treat as active |
| Connection timeout    | Treat as "may be active"; ask operator before proceeding |
| HTTP 5xx              | Treat as "may be active"; ask operator before proceeding |
