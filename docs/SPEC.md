# Clavis – Technical Specification (v1)

A Brick/Bloom‑style distraction blocker using camera‑based object recognition instead of NFC

## 1. Overview

Clavis is a native iOS app (Swift / SwiftUI) that helps users reduce digital distractions. Instead of using an NFC tag (like Brick or Bloom), the app uses any physical object chosen by the user as a "key." The app uses on‑device computer vision to verify that object and uses Focus Mode / Screen Time / Shortcuts to block or unlock apps.

### Core Concept

- User picks a visually distinctive object (e.g., a toy, book, patterned mug).
- User scans this object from multiple angles to "enroll" it.
- User leaves that object at home.
- When lock mode is active, selected apps are blocked/hidden via Focus Mode.
- To unlock, user must physically return to the object and scan it again.

## 2. Goals & Non‑Goals

### Goals (v1)

- Enroll one physical object as a key.
- Recognize that object using on‑device computer vision.
- Allow the user to select apps/categories to block.
- Lock/unlock distraction apps using Focus Mode / Screen Time.
- Provide a smooth, guided onboarding flow.

### Non‑Goals (v1)

- Multiple keys (e.g., Work key + Sleep key).
- Cloud sync across devices (no iPad/Mac support yet).
- Strong anti‑tampering enforcement.
- Parental control or MDM-level lock enforcement.

## 3. User Stories

- **Enroll Object**: User selects a physical object and scans it from multiple angles.
- **Select Apps to Block**: User chooses categories or specific apps to restrict when locked.
- **Lock Mode**: User can activate "Locked Mode," which blocks selected apps.
- **Unlock Mode**: User must scan their enrolled object to exit Locked Mode.
- **Replace Key**: User can reset or replace their key if lost or unreliable.
- **Scan Failure Recovery**: User is guided through lighting/angle adjustments if verification fails.

## 4. Architecture

Clavis uses the **MV (Model-View)** architecture pattern, following the principle that **"View is the ViewModel"** in SwiftUI.

### MV Pattern Components

**M = Model (Aggregate Root Model)**

A small number of aggregate root models, each representing a bounded context (e.g., `KeyManager`, `LockStateManager`, `AppsProfileManager`). These models:

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
- Key enrollment flow
- Main status screen (Locked/Unlocked)
- Scan UI for lock/unlock
- Settings (Reset key, change app profile)

#### Domain Layer

- KeyManager
- LockStateManager
- AppsProfileManager
- Onboarding state management

#### Integration Layer

- Focus Mode / Screen Time / Shortcuts integration
- Local persistence (Keychain + protected file storage)

## 5. Core Modules

### 5.1 KeyManager

Handles enrollment and verification of the user's physical object.

**Responsibilities:**

- Take multiple images from camera during enrollment.
- Extract feature vectors from each image using Vision/Core ML.
- Store feature vectors securely on device.
- During verification, compare new scan against stored vectors.
- Provide confidence scores and error types (e.g., blurry image, low light).

### 5.2 LockStateManager

Maintains the global app state as either Locked or Unlocked.

**Responsibilities:**

- Set current lock state.
- Trigger Focus Mode ON when locking.
- Trigger Focus Mode OFF when unlocking.
- Publish lock state changes to SwiftUI.

### 5.3 AppsProfileManager

Manages which apps/categories are blocked during Locked Mode.

**Responsibilities:**

- Store user's chosen categories (e.g., Social, Video, Games).
- Guide user through configuring Focus Mode restrictions.
- Persist chosen profile.

### 5.4 OnboardingManager

Tracks which onboarding steps have been completed.

**Steps:**

- Welcome screen
- Choose & enroll key object
- Configure Focus Mode
- Complete onboarding → enter main UI

## 6. Screen Flows

### 6.1 Onboarding Flow

**Welcome screen**

- Introduces the "physical key" concept with examples of good vs bad objects.

**Key Enrollment**

- User captures 5–8 photos of the object.
- Real‑time validation: lighting, blur, distinctiveness.

**Configure Blocking**

- User selects categories or apps.
- Guided instructions to create a Focus Mode ("Keylock Mode").
- Add distracting apps to the Focus.

**Complete**

- User is taken to the main screen (Unlocked state).

### 6.2 Lock Flow

- User taps "Lock with my key."
- App scans the object to confirm presence.
- On success: Focus Mode turns ON → apps become blocked.
- Main screen updates to Locked state.

### 6.3 Unlock Flow

- User taps "Scan to Unlock."
- Camera opens for object scanning.
- On match: Focus Mode turns OFF → apps become available.
- Main screen updates to Unlocked state.

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

- User creates a Focus Mode named "Keylock Mode".
- They assign distracting apps to be blocked.
- Your app triggers Focus Mode ON/OFF using:
  - Shortcuts integration
  - Focus activation APIs (if available on that iOS version)
- Lock → Focus ON
- Unlock → Focus OFF

**Later versions:**

- Could integrate with Screen Time API / MDM for stronger enforcement.

## 9. Data Persistence

### UserDefaults / AppStorage

- Onboarding state
- Lock state
- App profile selection

### Secure Storage

- Feature vectors (Key Template)
- Date enrolled
- Versioning info

### Privacy Guarantee

- All data stays on device
- No photos or embeddings uploaded
- Easy reset: "Delete my key" clears all stored data

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

### Milestone 3 – Focus Mode Integration

- Trigger Focus ON/OFF via Shortcut or API
- App blocking flow functional

### Milestone 4 – Onboarding & UX Polish

- Good/bad object guide
- Better scan flow
- Error handling

### Milestone 5 – Internal Beta (TestFlight)

**Feedback focus:**

- Matching reliability
- Ease of Focus setup
- Overall concept delight
