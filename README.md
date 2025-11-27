# Clavis

A Brick/Bloom‑style distraction blocker using camera‑based object recognition instead of NFC.

## Overview

Clavis is a native iOS app that helps you reduce digital distractions by using any physical object as a "key" to lock and unlock your distracting apps. Instead of relying on NFC tags, Clavis uses on‑device computer vision to recognize your chosen object, making it more flexible and accessible.

### How It Works

1. **Choose Your Key**: Pick any visually distinctive object (e.g., a toy, book, patterned mug)
2. **Enroll It**: Scan the object from multiple angles to create a secure template
3. **Leave It Behind**: Keep your key object at home or in a safe place
4. **Lock Apps**: Activate lock mode to block distracting apps via Focus Mode
5. **Unlock**: Return to your key object and scan it to unlock your apps

## Features

- 🎯 **Physical Key Concept**: Use any object you own as your key
- 📷 **On‑Device Computer Vision**: Fast, private object recognition using Vision/Core ML
- 🔒 **Focus Mode Integration**: Seamlessly blocks apps using iOS Focus Mode
- 🎨 **Guided Onboarding**: Smooth setup flow with helpful guidance
- 🔐 **Privacy First**: All processing happens on‑device; no data leaves your phone
- ⚡ **Fast Recognition**: Object verification in under 1 second

## Requirements

- iOS 15.0 or later
- Device with camera support
- Xcode 14.0+ (for development)

## Installation

### For Users

Clavis is currently in development. Once released, it will be available on the App Store.

### For Developers

1. Clone the repository:
```bash
git clone https://github.com/yourusername/clavis.git
cd clavis
```

2. Open the project in Xcode:
```bash
open clavis.xcodeproj
```

3. Build and run the project (⌘R)

## Usage

### First Time Setup

1. Launch Clavis and complete the onboarding flow
2. Choose a distinctive physical object as your key
3. Follow the guided enrollment process (capture 5–8 photos from different angles)
4. Configure which apps or categories to block
5. Set up a Focus Mode named "Keylock Mode" with your distracting apps

### Locking Apps

1. Tap "Lock with my key"
2. Scan your enrolled object to confirm presence
3. Focus Mode activates → distracting apps are blocked

### Unlocking Apps

1. Tap "Scan to Unlock"
2. Point camera at your enrolled object
3. On successful match → Focus Mode deactivates → apps become available

### Replacing Your Key

If you need to replace your key object:
1. Go to Settings
2. Select "Reset Key"
3. Follow the enrollment process again

## Architecture

Clavis uses the **MV (Model-View)** architecture pattern, following the principle that **"View is the ViewModel"** in SwiftUI.

For detailed architecture information, see [docs/SPEC.md](docs/SPEC.md).

## Development Status

Clavis is currently in active development. Current milestones:

- [x] Project setup
- [ ] Milestone 1: CV Prototype
- [ ] Milestone 2: Lock State + UI Skeleton
- [ ] Milestone 3: Focus Mode Integration
- [ ] Milestone 4: Onboarding & UX Polish
- [ ] Milestone 5: Internal Beta (TestFlight)

See [docs/SPEC.md](docs/SPEC.md) for the complete technical specification and development roadmap.

## Privacy

Clavis is designed with privacy as a core principle:

- ✅ All computer vision processing happens on‑device
- ✅ No photos or feature vectors are uploaded
- ✅ All data stored locally using Keychain and secure file storage
- ✅ Easy reset: "Delete my key" clears all stored data
- ✅ No tracking, analytics, or external data collection

## Limitations (v1)

- Single key object only (no multiple keys)
- iOS only (no iPad/Mac support yet)
- Behavioral tool (not a hardcore blocker)
- Requires manual Focus Mode setup

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Add your license here]

## Acknowledgments

Inspired by [Brick](https://brick.app) and [Bloom](https://bloom.app), but using camera‑based object recognition instead of NFC tags.

---

**Note**: Clavis is currently in development. Features and functionality may change before the first release.

