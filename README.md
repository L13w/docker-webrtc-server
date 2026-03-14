# Docker WebRTC Server

A self-hosted, single-container live stream server. Accepts **RTMP** and **WebRTC (WHIP)** input, publishes as **WebRTC (WHEP)** and **HLS**. Zero configuration beyond your public IP.

Built on [SRS](https://ossrs.io/) v5 with an English UI, cloud auto-detection, and production-ready defaults.

## Requirements

- **Docker** (or Docker Compose)
- **Ports** 1935, 8080, 1985 (TCP) and 8000 (UDP+TCP) open on your firewall (for remote access)
- ~**160MB** disk for the Docker image
- ~**20MB RAM** at idle; scales with concurrent viewers

Runs on any platform Docker supports: Linux, macOS, Windows, ARM, x86_64.

## What It Does

```
                         ┌──────────────────────┐
  OBS / FFmpeg / Browser │  Docker WebRTC Server│ ──▶ WebRTC ── Browser
    (RTMP or WHIP)       └──────────────────────┘ ──▶ HLS    ── Browser / VLC
```

**Ingest (publish a stream):**
- **RTMP** on port `1935` — use OBS, FFmpeg, or any RTMP encoder
- **WebRTC via WHIP** on port `1985` — publish from a browser or OBS 30.2+

**Playback (watch a stream):**
- **WebRTC via WHEP** on port `1985` — low latency in any modern browser
- **HLS** on port `8080` — broad compatibility, ~4-6s latency

**Both directions work simultaneously.** An RTMP stream from OBS is instantly available over WebRTC, and a WebRTC stream published via WHIP is available over RTMP/HLS.

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 1935 | TCP | RTMP ingest |
| 8080 | TCP | HLS playback, built-in web player |
| 1985 | TCP | HTTP API, WHIP ingest, WHEP playback |
| 8000 | UDP+TCP | WebRTC media (ICE/SRTP) |

## Quick Start

### Local (laptop/desktop)

For testing on your own machine, no public IP needed:

```bash
docker run -d --name srs \
  -p 1935:1935 \
  -p 8080:8080 \
  -p 1985:1985 \
  -p 8000:8000/udp \
  -p 8000:8000/tcp \
  llewroberts/docker-webrtc-server
```

Or with Compose:

```bash
git clone https://github.com/L13w/docker-webrtc-server.git
cd docker-webrtc-server
docker compose up -d
```

Then open `http://localhost:8080` and publish to `rtmp://localhost/live/stream1`.

### Remote server

To allow viewers outside your network, set `CANDIDATE_IP` to your server's public IP:

```bash
docker run -d --name srs \
  -p 1935:1935 \
  -p 8080:8080 \
  -p 1985:1985 \
  -p 8000:8000/udp \
  -p 8000:8000/tcp \
  -e CANDIDATE_IP=YOUR_SERVER_IP \
  llewroberts/docker-webrtc-server
```

Or with Compose:

```bash
git clone https://github.com/L13w/docker-webrtc-server.git
cd docker-webrtc-server
export CANDIDATE_IP=YOUR_SERVER_IP
docker compose up -d
```

### Verify it's running

```bash
curl http://localhost:1985/api/v1/versions
```

### Open the built-in player

Visit `http://YOUR_IP:8080` in a browser to access the console and test players.

## Cloud VM Auto-Detection

On Azure, AWS, or GCP, you can skip setting `CANDIDATE_IP` and use auto-detection instead:

```bash
AUTO_DETECT_IP=true docker compose up -d
```

The entrypoint will query the cloud metadata service to find your public IP automatically.

## Using with OBS

### Stream via RTMP (recommended)

1. Open OBS **Settings > Stream**
2. Set:
   - **Service**: Custom
   - **Server**: `rtmp://YOUR_SERVER_IP/live`
   - **Stream Key**: `stream1` (or any name you choose)
3. Click **Start Streaming**

Your stream is now available at:
- **WebRTC**: `http://YOUR_SERVER_IP:1985/rtc/v1/whep/?app=live&stream=stream1`
- **HLS**: `http://YOUR_SERVER_IP:8080/live/stream1.m3u8`
- **Built-in player**: `http://YOUR_SERVER_IP:8080/players/rtc_player.html?stream=stream1`

### Stream via WHIP (OBS 30.2+)

OBS 30.2 and later support WHIP output natively:

1. Open OBS **Settings > Stream**
2. Set:
   - **Service**: WHIP
   - **Server**: `http://YOUR_SERVER_IP:1985/rtc/v1/whip/?app=live&stream=stream1`
   - **Bearer Token**: (leave empty)
3. Click **Start Streaming**

WHIP streaming gives you lower publish latency compared to RTMP but requires OBS 30.2+.

## Using with FFmpeg

```bash
# Stream a video file via RTMP
ffmpeg -re -i video.mp4 -c copy -f flv rtmp://YOUR_SERVER_IP/live/stream1

# Stream a test pattern
ffmpeg -re -f lavfi -i testsrc=size=1280x720:rate=30 \
  -f lavfi -i sine=frequency=440:sample_rate=44100 \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -c:a aac -b:a 128k \
  -f flv rtmp://YOUR_SERVER_IP/live/stream1
```

## Watching Streams

### WebRTC (lowest latency)

Use the WHEP endpoint with any WHEP-compatible player:

```
http://YOUR_SERVER_IP:1985/rtc/v1/whep/?app=live&stream=stream1
```

Or use the built-in player:

```
http://YOUR_SERVER_IP:8080/players/rtc_player.html?stream=stream1
```

### HLS (broadest compatibility)

```
http://YOUR_SERVER_IP:8080/live/stream1.m3u8
```

Works with VLC, Safari, or any HLS player (hls.js, Video.js, etc.).

## API

The server provides an HTTP API on port 1985:

| Endpoint | Description |
|----------|-------------|
| `GET /api/v1/versions` | Server version |
| `GET /api/v1/summaries` | Server summary and health |
| `GET /api/v1/streams` | Active streams |
| `GET /api/v1/clients` | Connected clients |
| `POST /rtc/v1/whip/?app=live&stream=NAME` | WHIP publish endpoint |
| `POST /rtc/v1/whep/?app=live&stream=NAME` | WHEP playback endpoint |

Full API docs: [SRS HTTP API](https://ossrs.io/lts/en-us/docs/v5/doc/http-api)

## Configuration

The server config is at [srs.conf](srs.conf). Key settings:

- **`rtmp_to_rtc on`** — RTMP streams are automatically available as WebRTC
- **`rtc_to_rtmp on`** — WebRTC streams are automatically available as RTMP/HLS
- **`gop_cache off`** — Disabled for lower WebRTC latency (no buffered GOP on connect)
- **HLS**: 2-second fragments, 10-second window

To customize, edit `srs.conf` and rebuild:

```bash
docker compose build && docker compose up -d
```

## Firewall

Ensure these ports are open on your server:

```bash
# Example for ufw
sudo ufw allow 1935/tcp   # RTMP
sudo ufw allow 8080/tcp   # HLS
sudo ufw allow 1985/tcp   # API / WHIP / WHEP
sudo ufw allow 8000/udp   # WebRTC media (UDP)
sudo ufw allow 8000/tcp   # WebRTC media (TCP fallback)
```

On cloud providers, update your security group / NSG to allow these ports.

## Architecture

This runs [SRS](https://github.com/ossrs/srs) v5, a widely-used open-source media server written in C++. SRS handles all protocol translation internally — there are no additional services, proxies, or dependencies. One container does everything.

## License

SRS is licensed under [MIT](https://github.com/ossrs/srs/blob/develop/LICENSE). This Docker configuration is also MIT licensed.
