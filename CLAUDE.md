# AutoSpotter Overview

AutoSpotter is always-listening, voice-activated AI Assistant provides the fastest possible response to spoken user queries.
These queries are expedited by allowing the user to type out a free-flowing context within which the assistant will answer questions.
The architecture aims to maximize use of open source tooling to avoid excessive GPT token requirements.

## Key Features

### Voice Controlled Response Curation

The Assistant tries to be as terse as possible. When possible, the Assistant responds with a single word.
In order to reduce token usage, a local speech-to-text script continuously captures words spoken into the device microphone.
When the trigger word "Jarvis" is detected, the local script begins analyzing the speech to detect the user's query. It also immediatly takes a screenshot of the user's active window.
It is this query and this screenshot that are used as the starting-prompt for the rest of the workflow.

### Research Agent

For complex queries, the Agent is capable of going to the web for more information. This is especially important for queries that require up-to-date information.

### Visual Analysis

If a user's query seem's to refer to something in the screenshot, the two are processed by the appropriate ai tools.

### Custom Context

The user can locally configure additional context for their Assistant, in markdown.

### Open-Source-First

By default, the application is configured to rely entirely on local, open source tools/models. Paid options will be added later.

# Design and Architecture

AutoSpotter is comprised of several components.

## Desktop Service

Located at `pkg/desktop/`

### Description

A Background Service that takes action based on speech detected in the microphone, and a System Tray App that allows for basic control of the Background Service.

### Key Technologies

- Python
- `faster-whisper`
- `silero-vad`
- `sounddevice`
- `python-windows-service`
- `pystray`
- `PyInstaller` (cross-platform bundling)

### Architecture

The Desktop Service uses a cross-platform architecture with platform-specific service implementations:

```
pkg/desktop/
├── service/
│   ├── windows_service.py    # Windows Service (python-windows-service)
│   ├── macos_daemon.py       # macOS LaunchAgent/Daemon (launchd)
│   └── linux_daemon.py      # Linux Service (systemd)
├── tray/
│   └── tray_app.py          # Cross-platform system tray (pystray)
├── core/
│   ├── audio_processor.py    # Audio capture and speech recognition
│   ├── trigger_detector.py   # "Jarvis" wake word detection
│   └── screenshot_capture.py # Screen capture functionality
└── shared/
    ├── config.py            # Configuration management
    └── utils.py             # Common utilities
```

### Cross-Platform Deployment

Each platform requires separate builds using PyInstaller:
- **Windows**: Executable (.exe) with Windows Service registration
- **macOS**: Application bundle (.app) with launchd integration
- **Linux**: Executable with systemd service files

This service runs on the local machine and can make calls to outside services as needed.

## Web Portal

Located at `pkg/aws/web`

### Descriptions

This site, hosted in AWS, provides information about the product, and a way to download the appropriate client.
Authenticated users can adjust payment options, toggle premium services, and configuring their assistant.

### Key Technologies

- vite
- TypeScript
- React
- React Router

## Build And Deploy

Located at `pkg/aws/SAM`

### Description

This indicates configuration for building the Desktop Service, deploying the web portal, and ensuring the desktop executable can be downloaded from that portal.

### Key Technologies

# Project Directory Structure

This is a monorepo.

pkg/
├── desktop/                  # Desktop service
│   ├── service/              # Platform-specific service implementations
│   ├── tray/                 # System tray application
│   ├── core/                 # Core audio and speech processing
│   └── shared/               # Desktop service utilities
├── aws/
│   ├── web/                  # Web portal (planned)
│   └── SAM/                  # AWS SAM configuration (planned)
└── shared/                   # Cross-component shared utilities (planned)
