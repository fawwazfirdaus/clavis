# Clavis – Technical Specification (v1)

A Brick/Bloom‑style distraction blocker using camera‑based object recognition instead of NFC

## 1. Overview

Clavis is a native iOS app (Swift / SwiftUI) that helps users reduce digital distractions. Instead of using an NFC tag (like Brick or Bloom), the app uses any physical object chosen by the user as a "key." The app uses on‑device computer vision to verify that object and uses Focus Mode / Screen Time / Shortcuts to block or unlock apps.

### Core Concept

- User picks a visually distinctive object (e.g., a toy, book, patterned mug) as their **main key**.
- User scans this object from multiple angles to "enroll" it.
- User leaves that object at home.
- User can create multiple **modes** (e.g., Work Mode, Sleep Mode, Study Mode), each with its own configuration of apps to block.
- Each mode can optionally have its own **temporary key** (a different physical object) that allows unlocking certain apps for a limited time, one use per lock cycle.
- When a mode is locked, selected apps for that mode are blocked/hidden via Focus Mode.
- To unlock, user must physically return to the main key object and scan it again.

## 2. Goals & Non‑Goals

### Goals (v1)

- Enroll one physical object as the main key (shared across all modes).
- Create and manage multiple modes (e.g., Work, Sleep, Study) with distinct configurations.
- For each mode, optionally enroll a temporary key for limited app access.
- Recognize enrolled objects using on‑device computer vision.
- Allow the user to select apps/categories to block per mode.
- Lock/unlock distraction apps using Focus Mode / Screen Time.
- Allow temporary key to unlock specific apps for a limited time (one use per lock cycle).
- Switch between modes and lock/unlock each mode independently.
- Provide a smooth, guided onboarding flow.

### Non‑Goals (v1)

- Multiple main keys (e.g., Work key + Sleep key). Note: One main key shared across all modes, with mode-specific temporary keys supported.
- Cloud sync across devices (no iPad/Mac support yet).
- Strong anti‑tampering enforcement.
- Parental control or MDM-level lock enforcement.

## 3. User Stories

- **Enroll Main Key**: User selects a physical object and scans it from multiple angles as their main key (shared across all modes).
- **Create Mode**: User creates a new mode (e.g., Work, Sleep, Study) with a name and configuration.
- **Configure Mode**: User selects categories or specific apps to restrict when that mode is locked.
- **Enroll Temporary Key**: User optionally selects a different physical object and scans it as a temporary key for a specific mode.
- **Select Active Mode**: User can switch between modes and see which mode is currently active.
- **Lock Mode**: User can activate "Locked Mode" for the current mode, which blocks selected apps for that mode.
- **Unlock Mode**: User must scan their main key object to exit Locked Mode.
- **Temporary Unlock**: When a mode is locked, user can scan that mode's temporary key to unlock specific apps for a limited time (one use per lock cycle).
- **Edit Mode**: User can modify a mode's configuration (apps to block, temporary key settings).
- **Delete Mode**: User can remove a mode they no longer need.
- **Replace Key**: User can reset or replace their main key or any mode's temporary key if lost or unreliable.
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

- KeyManager (main key)
- ModeManager
- TemporaryKeyManager (per mode)
- LockStateManager
- AppsProfileManager (per mode)
- Onboarding state management

#### Integration Layer

- Focus Mode / Screen Time / Shortcuts integration
- Local persistence (Keychain + protected file storage)

## 5. Core Modules

### 5.1 KeyManager

Handles enrollment and verification of the user's main key physical object.

**Responsibilities:**

- Take multiple images from camera during enrollment.
- Extract feature vectors from each image using Vision/Core ML.
- Store feature vectors securely on device.
- During verification, compare new scan against stored vectors.
- Provide confidence scores and error types (e.g., blurry image, low light).
- Verify main key for full lock/unlock operations.

### 5.2 ModeManager

Manages multiple modes and their configurations.

**Responsibilities:**

- Create, edit, and delete modes.
- Store mode configurations (name, apps to block, temporary key settings).
- Track which mode is currently active/selected.
- Persist mode data locally.
- Provide operations: add mode, remove mode, update mode, switch active mode, list all modes.

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

Handles enrollment and verification of temporary key physical objects for each mode.

**Responsibilities:**

- Take multiple images from camera during temporary key enrollment (per mode).
- Extract feature vectors from each image using Vision/Core ML.
- Store feature vectors securely on device (associated with specific mode).
- During verification, compare new scan against stored vectors for the active mode.
- Track temporary unlock state (used/unused per lock cycle) per mode.
- Enforce one-time use per lock cycle per mode.
- Manage time-limited app access when temporary key is verified.
- Support multiple temporary keys (one per mode).

### 5.6 OnboardingManager

Tracks which onboarding steps have been completed.

**Steps:**

- Welcome screen
- Choose & enroll main key object
- Create first mode (default mode)
- Configure apps to block for first mode
- Optionally choose & enroll temporary key for first mode
- Configure Focus Mode
- Complete onboarding → enter main UI

## 6. Screen Flows

### 6.1 Onboarding Flow

**Welcome screen**

- Introduces the "physical key" concept with examples of good vs bad objects.

**Main Key Enrollment**

- User captures 5–8 photos of the main key object.
- Real‑time validation: lighting, blur, distinctiveness.

**Temporary Key Enrollment (Optional)**

- User can optionally enroll a temporary key object.
- Same enrollment process as main key (5–8 photos).
- User selects which apps can be unlocked with temporary key.

**Create First Mode**

- User creates their first mode (e.g., "Work Mode", "Default Mode").
- User selects categories or apps to block for this mode.
- Guided instructions to create a Focus Mode ("Keylock Mode").
- Add distracting apps to the Focus.

**Temporary Key Enrollment (Optional)**

- User can optionally enroll a temporary key for the first mode.
- Same enrollment process as main key (5–8 photos).
- User selects which apps can be unlocked with temporary key.

**Complete**

- User is taken to the main screen (Unlocked state, first mode active).

### 6.2 Mode Management Flow

- User can create new modes from settings or main screen.
- User names the mode and selects apps to block.
- User can optionally enroll a temporary key for the new mode.
- User can edit existing modes (change name, apps, temporary key).
- User can delete modes (with confirmation).
- User can switch between modes from the main screen.

### 6.3 Lock Flow

- User selects a mode (if multiple modes exist).
- User taps "Lock with my key."
- App scans the main key object to confirm presence.
- On success: Focus Mode turns ON → apps for that mode become blocked.
- Main screen updates to Locked state, showing which mode is locked.

### 6.4 Unlock Flow

- User taps "Scan to Unlock."
- Camera opens for main key scanning.
- On match: Focus Mode turns OFF → apps become available.
- Main screen updates to Unlocked state.
- Temporary key usage resets for the unlocked mode.

### 6.5 Temporary Unlock Flow

- While a mode is locked, user taps "Temporary Unlock."
- Camera opens for that mode's temporary key scanning.
- On match: Selected apps for that mode become temporarily available for a limited time.
- Temporary key is marked as used for the current lock cycle of that mode.
- After time expires or user manually ends temporary unlock, apps are blocked again.
- Temporary key cannot be used again until the next lock cycle (after full unlock with main key).
- Each mode's temporary key usage is tracked independently.

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
- Temporary unlock state (used/unused per cycle, per mode)
- Temporary unlock time remaining (per mode)
- Mode list and configurations

### Secure Storage

- Feature vectors (Main Key Template)
- Feature vectors (Temporary Key Templates, per mode if enrolled)
- Date enrolled (main key)
- Date enrolled (temporary keys, per mode if enrolled)
- Mode configurations (names, app lists, temporary key associations)
- Versioning info

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
- Per-mode temporary key management

### Milestone 5 – Internal Beta (TestFlight)

**Feedback focus:**

- Matching reliability
- Ease of Focus setup
- Overall concept delight
