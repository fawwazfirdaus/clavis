# Clavis – Technical Specification (v1)

A Brick/Bloom‑style distraction blocker using camera‑based object recognition instead of NFC

## 1. Overview

Clavis is a native iOS app (Swift / SwiftUI) that helps users reduce digital distractions. Instead of using an NFC tag (like Brick or Bloom), the app uses any physical object chosen by the user as a "key." The app uses on‑device computer vision to verify that object and uses Focus Mode / Screen Time / Shortcuts to block or unlock apps.

### Core Concept

- User can create multiple **modes** (e.g., Work Mode, Sleep Mode, Study Mode), each with its own configuration of apps to block.
- For each mode, user picks a visually distinctive object (e.g., a toy, book, patterned mug) as that mode's **main key**.
- User scans each main key object from multiple angles to "enroll" it.
- User leaves main key objects at home.
- Each mode can optionally have multiple **temporary keys** (different physical objects) that allow unlocking certain apps for a limited time, one use per lock cycle per key.
- The same physical key object can be reused across different modes (e.g., a key can be the main key for Work Mode and a temporary key for Sleep Mode).
- When a mode is locked, selected apps for that mode are blocked/hidden via Focus Mode.
- To unlock, user must physically return to that mode's main key object and scan it again.

## 2. Goals & Non‑Goals

### Goals (v1)

- Create and manage multiple modes (e.g., Work, Sleep, Study) with distinct configurations.
- For each mode, enroll one physical object as that mode's main key.
- For each mode, optionally enroll multiple temporary keys for limited app access.
- Allow the same physical key object to be reused across different modes (as main key for one mode, temporary key for another, etc.).
- Recognize enrolled objects using on‑device computer vision.
- Allow the user to select apps/categories to block per mode.
- Lock/unlock distraction apps using Focus Mode / Screen Time.
- Allow temporary keys to unlock specific apps for a limited time (one use per lock cycle per key).
- Switch between modes and lock/unlock each mode independently.
- Provide a smooth, guided onboarding flow.

### Non‑Goals (v1)

- Cloud sync across devices (no iPad/Mac support yet).
- Strong anti‑tampering enforcement.
- Parental control or MDM-level lock enforcement.

## 3. User Stories

- **Create Mode**: User creates a new mode (e.g., Work, Sleep, Study) with a name and configuration.
- **Enroll Main Key**: User selects a physical object and scans it from multiple angles as the main key for a specific mode.
- **Configure Mode**: User selects categories or specific apps to restrict when that mode is locked.
- **Enroll Temporary Key**: User optionally selects a physical object and scans it as a temporary key for a specific mode. User can enroll multiple temporary keys per mode.
- **Reuse Key**: User can assign an already-enrolled key to another mode (as main key or temporary key).
- **Select Active Mode**: User can switch between modes and see which mode is currently active.
- **Lock Mode**: User can activate "Locked Mode" for the current mode, which blocks selected apps for that mode.
- **Unlock Mode**: User must scan that mode's main key object to exit Locked Mode.
- **Temporary Unlock**: When a mode is locked, user can scan any of that mode's temporary keys to unlock specific apps for a limited time (one use per lock cycle per key).
- **Edit Mode**: User can modify a mode's configuration (apps to block, main key, temporary keys).
- **Delete Mode**: User can remove a mode they no longer need.
- **Replace Key**: User can reset or replace a mode's main key or any temporary key if lost or unreliable.
- **Scan Failure Recovery**: User is guided through lighting/angle adjustments if verification fails.

## 4. Architecture

Clavis uses the **MV (Model-View)** architecture pattern, following the principle that **"View is the ViewModel"** in SwiftUI.

### MV Pattern Components

**M = Model (Aggregate Root Model)**

A small number of aggregate root models, each representing a bounded context (e.g., `KeyManager`, `ModeManager`, `TemporaryKeyManager`, `LockStateManager`, `AppsProfileManager`). These models:

- Fetch and persist data (usually via services / integration layer)
- Own collections of entities and domain objects
- Provide operations: add, remove, filter, sort, search, etc.
- Can communicate with other aggregate models when needed
- Do NOT contain UI-specific logic

**V = View (SwiftUI View, which is also the ViewModel)**

SwiftUI views are treated as both view and view-model:

- Bind directly to `@StateObject` / `@EnvironmentObject` aggregate models
- Format data for display and handle simple UI state (selected item, sheet toggles, text field bindings)
- Do NOT contain networking or domain logic

### Philosophy

SwiftUI already has MVVM baked in through its reactive data binding system, so there's no need for a redundant ViewModel layer. Instead of creating one ViewModel per screen (e.g., `HomeViewModel`, `OrderListViewModel`), we use:

- A few aggregate models based on domain (bounded context), not screen count
- Views that bind directly to those models and act as their own view-models

This approach keeps the architecture simple, testable (unit tests against models, E2E for flows), and scalable (split models by bounded context when they grow).

### Layers

#### UI Layer (SwiftUI)

- Onboarding
- Main key enrollment flow
- Mode creation and management
- Temporary key enrollment flow (per mode, optional)
- Mode selection/switching
- Main status screen (Locked/Unlocked, current mode)
- Scan UI for lock/unlock
- Temporary unlock UI
- Settings (Reset keys, manage modes, change app profiles)

#### Domain Layer

- KeyManager (manages all keys, reusable across modes)
- ModeManager
- TemporaryKeyManager (tracks temporary key usage per mode)
- LockStateManager
- AppsProfileManager (per mode)
- Onboarding state management

#### Integration Layer

- Focus Mode / Screen Time / Shortcuts integration
- Local persistence (Keychain + protected file storage)

## 5. Core Modules

### 5.1 KeyManager

Manages all physical key objects that can be used across modes. Keys can be assigned as main keys or temporary keys for different modes, and the same key can be reused across multiple modes.

**Responsibilities:**

- Manage a collection of all enrolled keys (each key has a unique ID).
- Take multiple images from camera during key enrollment.
- Extract feature vectors from each image using Vision/Core ML.
- Store feature vectors securely on device (Keychain).
- During verification, compare new scan against stored vectors for a specific key.
- Provide confidence scores and error types (e.g., blurry image, low light).
- Support key reuse: the same key can be assigned as main key for one mode and temporary key for another mode.
- Allow keys to be updated, renamed, or removed.

### 5.2 ModeManager

Manages multiple modes and their configurations.

**Responsibilities:**

- Create, edit, and delete modes.
- Store mode configurations (name, main key ID, temporary key IDs, apps to block).
- Each mode must have exactly one main key (required).
- Each mode can have zero or more temporary keys (optional array).
- Track which mode is currently active/selected.
- Persist mode data locally.
- Provide operations: add mode, remove mode, update mode, switch active mode, list all modes.
- Manage key assignments: set main key for a mode, add/remove temporary keys for a mode.

### 5.3 LockStateManager

Maintains the lock state for the currently active mode.

**Responsibilities:**

- Set current lock state for active mode.
- Trigger Focus Mode ON when locking (using active mode's app configuration).
- Trigger Focus Mode OFF when unlocking.
- Publish lock state changes to SwiftUI.
- Track which mode is currently locked.

### 5.4 AppsProfileManager

Manages which apps/categories are blocked for each mode during Locked Mode.

**Responsibilities:**

- Store user's chosen categories (e.g., Social, Video, Games) per mode.
- Guide user through configuring Focus Mode restrictions per mode.
- Persist chosen profile for each mode.
- Retrieve app profile for the currently active mode.

### 5.5 TemporaryKeyManager

Tracks temporary key usage state for each mode. Note: Key enrollment is handled by KeyManager; this manager only tracks which temporary keys have been used per lock cycle.

**Responsibilities:**

- Track temporary key usage state per (modeId, keyId) pair.
- Enforce one-time use per lock cycle per temporary key per mode.
- Reset temporary key usage when a mode is unlocked (allowing keys to be used again in the next lock cycle).
- Persist temporary key usage state locally (UserDefaults).
- Support multiple temporary keys per mode (each tracked independently).

### 5.6 OnboardingManager

Tracks which onboarding steps have been completed.

**Steps:**

- Welcome screen
- Create first mode (default mode)
- Choose & enroll main key object for first mode
- Configure apps to block for first mode
- Optionally choose & enroll temporary key(s) for first mode
- Configure Focus Mode
- Complete onboarding → enter main UI

## 6. Screen Flows

### 6.1 Onboarding Flow

**Welcome screen**

- Introduces the "physical key" concept with examples of good vs bad objects.

**Create First Mode**

- User creates their first mode (e.g., "Work Mode", "Default Mode").
- User selects categories or apps to block for this mode.

**Main Key Enrollment for First Mode**

- User captures 5–8 photos of the main key object for this mode.
- Real‑time validation: lighting, blur, distinctiveness.
- Key is enrolled and assigned as the main key for the first mode.

**Temporary Key Enrollment (Optional)**

- User can optionally enroll one or more temporary key objects for the first mode.
- Same enrollment process as main key (5–8 photos).
- User can reuse an already-enrolled key or enroll a new one.
- User selects which apps can be unlocked with temporary key(s).

**Configure Focus Mode**

- Guided instructions to create a Focus Mode ("Keylock Mode").
- Add distracting apps to the Focus.

**Complete**

- User is taken to the main screen (Unlocked state, first mode active).

### 6.2 Mode Management Flow

- User can create new modes from settings or main screen.
- User names the mode and selects apps to block.
- User must enroll a main key for the new mode (required).
- User can optionally enroll one or more temporary keys for the new mode.
- User can reuse existing keys (assign an already-enrolled key as main key or temporary key for the new mode).
- User can edit existing modes (change name, apps, main key, temporary keys).
- User can delete modes (with confirmation).
- User can switch between modes from the main screen.

### 6.3 Lock Flow

- User selects a mode (if multiple modes exist).
- User taps "Lock with my key."
- App scans that mode's main key object to confirm presence.
- On success: Focus Mode turns ON → apps for that mode become blocked.
- Main screen updates to Locked state, showing which mode is locked.
- All temporary keys for that mode are reset to unused state.

### 6.4 Unlock Flow

- User taps "Scan to Unlock."
- Camera opens for scanning the locked mode's main key.
- On match: Focus Mode turns OFF → apps become available.
- Main screen updates to Unlocked state.
- All temporary key usage resets for the unlocked mode (allowing them to be used again in the next lock cycle).

### 6.5 Temporary Unlock Flow

- While a mode is locked, user taps "Temporary Unlock."
- Camera opens for scanning any of that mode's temporary keys.
- App tries to match the scan against all temporary keys for that mode (skipping already-used keys).
- On match: Selected apps for that mode become temporarily available for a limited time.
- The matched temporary key is marked as used for the current lock cycle of that mode.
- After time expires or user manually ends temporary unlock, apps are blocked again.
- That specific temporary key cannot be used again until the next lock cycle (after full unlock with main key).
- Other temporary keys for the same mode can still be used (if not yet used in this lock cycle).
- Each temporary key's usage is tracked independently per mode.

## 7. Computer Vision Design

### Requirements

- On‑device inference
- Offline operation
- Fast classification (<1 second)
- Focus on feature matching, not classification

### Enrollment

- Take 5–8 snapshots
- Extract a feature vector from each image
- Store vectors in a "key template" locally and securely

### Verification

- Extract feature vector from current camera frame
- Compare against stored template
- If best similarity score exceeds threshold → match
- Otherwise → no match

### Heuristics

- Brightness check
- Blur detection
- Distance/framing guidance
- Warnings for uniform or low‑texture objects

## 8. System Integration

### Focus Mode (recommended for v1)

- User creates a Focus Mode named "Keylock Mode" (or mode-specific Focus Modes).
- They assign distracting apps to be blocked per mode.
- Your app triggers Focus Mode ON/OFF using:
  - Shortcuts integration
  - Focus activation APIs (if available on that iOS version)
- Lock → Focus ON (with apps from active mode's configuration)
- Unlock → Focus OFF
- When switching modes while locked, update Focus Mode to reflect new mode's app configuration.

**Later versions:**

- Could integrate with Screen Time API / MDM for stronger enforcement.

## 9. Data Persistence

### UserDefaults / AppStorage

- Onboarding state
- Lock state (per mode)
- Currently active mode
- App profile selection (per mode)
- Temporary unlock state (used/unused per cycle, per (modeId, keyId) pair)
- Temporary unlock time remaining (per mode)
- Mode list and configurations (including key ID references)

### Secure Storage

- Feature vectors (Key Templates - all keys stored independently)
- Key metadata (ID, name, enrollment date)
- Mode configurations (names, main key ID, temporary key IDs, app lists)
- Versioning info

Note: Keys are stored independently and referenced by ID in modes. The same key can be referenced by multiple modes.

### Privacy Guarantee

- All data stays on device
- No photos or embeddings uploaded
- Easy reset: "Delete my key" clears all stored data
- Mode configurations stored locally and securely

## 10. Risks & Mitigations

### Risk 1: Unreliable Object Recognition

**Mitigation:**

- Strong guidance on object distinctiveness
- Multi‑angle enrollment
- Blur & brightness detection
- Adjustable thresholds

### Risk 2: User Bypass (not a hardcore blocker)

**Mitigation:**

- Clear messaging that this is a behavioral tool
- Optional: trusted partner sets Screen Time passcode (v2)

### Risk 3: Focus Mode Setup Confusion

**Mitigation:**

- Detailed step‑by‑step instructions with screenshots
- Validation checks during onboarding

## 11. Development Milestones

### Milestone 1 – CV Prototype

- Local prototype for enrollment & matching
- Verify similarity scores logged to console

### Milestone 2 – Lock State + UI Skeleton

- Basic SwiftUI screens
- Lock / unlock state machine working
- Mode management UI (create, edit, delete, switch modes)

### Milestone 3 – Focus Mode Integration

- Trigger Focus ON/OFF via Shortcut or API
- App blocking flow functional

### Milestone 4 – Onboarding & UX Polish

- Good/bad object guide
- Better scan flow
- Error handling
- Mode switching UX
- Per-mode key management (main key + multiple temporary keys)
- Key reuse UI (assign existing keys to modes)

### Milestone 5 – Internal Beta (TestFlight)

**Feedback focus:**

- Matching reliability
- Ease of Focus setup
- Overall concept delight
