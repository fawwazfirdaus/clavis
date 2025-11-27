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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by [Brick](https://brick.app) and [Bloom](https://bloom.app), but using camera‑based object recognition instead of NFC tags.

---

**Note**: Clavis is currently in development. Features and functionality may change before the first release.

