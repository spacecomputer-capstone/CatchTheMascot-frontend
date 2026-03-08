# CatchTheMascot Documentation

## Overview

This repository contains the frontend for **Catch the Mascot**, a Flutter-based campus scavenger-hunt game. Players log in, allow location access, walk to mascot locations shown on a 3D campus map, prove they are physically present near a Raspberry Pi beacon, and then play a timing-based catch minigame to add mascots to their collection.

The repo is split into two main areas:

- `app/`: the actual Flutter application
- `ui-designs/`: static design references and screenshots

The current app logic lives almost entirely under `app/lib/`.

## What This Repo Does

At a high level, this frontend is responsible for:

- authenticating users
- loading and updating user and mascot data from Firestore
- rendering the campus map and mascot markers
- tracking player location and heading
- verifying physical presence through a Raspberry Pi / BLE challenge flow
- handling the catch minigame
- displaying collected mascots, coins, and profile data

## External Backend Dependencies

The frontend currently references two verification backends inside [`app/lib/utils/mascot_verification_helper.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/utils/mascot_verification_helper.dart):

- JWT verification backend:
  - Base URL: `https://jwt-verification-sk0m.onrender.com`
  - GitHub: [spacecomputer-capstone/jwt-verification](https://github.com/spacecomputer-capstone/jwt-verification)
- Legacy verification backend:
  - Base URL: `https://spacescrypt-api.onrender.com`
  - GitHub: [spacecomputer-capstone/SpaceScrypt](https://github.com/spacecomputer-capstone/SpaceScrypt)

The app also depends on:

- Firebase / Firestore for user, mascot, and catch data
- Mapbox for the 3D map experience
- BLE-capable devices and Raspberry Pi beacon hardware for proof-of-presence

## Current Runtime Flow

### 1. App startup

The app starts in [`app/lib/main.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/main.dart).

On launch it:

- initializes Firebase
- restores the previously logged-in user from local storage through `CurrentUser.restoreIfPossible()`
- preloads mascots from Firestore with `getMascots(...)`
- launches the `MaterialApp`

### 2. Authentication

Authentication is handled by:

- [`app/lib/screens/1_home_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/1_home_screen.dart)
- [`app/lib/screens/1_register_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/1_register_screen.dart)
- [`app/lib/apis/user_api.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/apis/user_api.dart)

Users can:

- register a new account
- log in with an existing account
- receive daily check-in coins when logging in after at least one day

Important implementation note:

- user records are stored in Firestore
- passwords are currently stored and compared directly; [`app/lib/models/user.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/models/user.dart) explicitly notes hashing as a TODO

### 3. Tutorial and permissions

After registration, the user is routed to the tutorial screen:

- [`app/lib/screens/tutorial_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/tutorial_screen.dart)

After login, the user is routed to the location permission screen:

- [`app/lib/screens/2_location_permission_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/2_location_permission_screen.dart)

This screen requests location access and then sends the user to the main map.

### 4. Map exploration

The core gameplay map is:

- [`app/lib/screens/3.1_mapbox_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/3.1_mapbox_screen.dart)

This screen is the heart of the repo. It:

- creates the Mapbox map
- tracks the player’s live GPS position
- updates camera movement and auto-follow behavior
- places the player 3D model on the map
- renders mascot markers and 3D models
- opens mascot detail screens when a mascot is tapped

Supporting map modules:

- [`app/lib/map/map_ids.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/map/map_ids.dart)
- [`app/lib/map/camera_controller.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/map/camera_controller.dart)
- [`app/lib/map/player_model_controller.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/map/player_model_controller.dart)
- [`app/lib/map/mascot_annotations.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/map/mascot_annotations.dart)
- [`app/lib/map/map_gestures.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/map/map_gestures.dart)

The map currently includes hardcoded mascot targets with campus coordinates, including Storke Tower and Henley Hall.

### 5. Mascot challenge and presence verification

When a user taps a mascot, the app opens:

- [`app/lib/screens/4_mascot_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/4_mascot_screen.dart)

This screen:

- loads mascot metadata
- charges coins to challenge the mascot
- runs proof-of-presence verification
- awards coins for first-time or changed-location visits
- launches the catch minigame if verification succeeds

The actual verification logic is concentrated in:

- [`app/lib/utils/mascot_verification_helper.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/utils/mascot_verification_helper.dart)

That helper implements a **dual-path verification strategy**:

1. JWT-first verification
2. legacy BLE verification fallback

#### JWT-first path

The newer path:

- resolves a Pi bridge URL from the JWT backend
- requests a challenge signed by the Pi
- signs the challenge locally with an app-side Ed25519 seed
- exchanges the signatures with the JWT backend
- stores the returned presence JWT and session ID in `SharedPreferences`

This is the currently preferred path in code.

#### Legacy fallback path

If JWT verification does not complete successfully within the configured time budget, the app falls back to the older flow:

- fetch nonce from the legacy backend
- scan for the BLE service UUID
- connect to the beacon
- read beacon ID
- write the nonce to the sign characteristic
- receive a 72-byte response containing timestamp + signature
- POST the result to the legacy backend for validation

This preserves compatibility with the older hardware/backend path.

Related experimental or earlier client implementations also exist:

- [`app/lib/presence/proof_of_presence.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/presence/proof_of_presence.dart)
- [`app/lib/presence/simple_presence_client.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/presence/simple_presence_client.dart)
- [`app/lib/services/bluetooth_service_mobile.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/services/bluetooth_service_mobile.dart)
- [`app/lib/services/bluetooth_service_web.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/services/bluetooth_service_web.dart)

These files document the protocol evolution, but the main active gameplay flow now goes through `MascotVerificationHelper`.

### 6. Catch minigame

After successful verification, the user enters:

- [`app/lib/screens/6_catch_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/6_catch_screen.dart)

This screen implements a timing bar minigame:

- a marker moves back and forth across the bar
- the user taps to catch
- success window size is derived from mascot rarity
- on success, the user’s caught mascot list is updated in Firestore

Catch results are pushed back to the mascot screen via navigation.

### 7. Inventory and profile

Collection and account views are handled by:

- [`app/lib/screens/8_inventory_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/8_inventory_screen.dart)
- [`app/lib/screens/10_profile_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/10_profile_screen.dart)

These screens show:

- current coin count
- number of explored places
- number of caught mascots
- card/grid view of the user’s mascot collection

## Data Model

### User model

Defined in [`app/lib/models/user.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/models/user.dart).

Key fields:

- `username`
- `password`
- `caughtMascots`
- `uncaughtMascots`
- `visitedPis`
- `coins`
- `lastPiVisited`
- `lastCheckInDate`

### Mascot model

Defined in [`app/lib/models/mascot.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/models/mascot.dart).

Key fields:

- `mascotName`
- `mascotId`
- `rarity`
- `piId`
- `respawnTime`
- `coins`

This file also contains `MascotStorageService`, which stores the highest seen mascot ID locally using `SharedPreferences`.

### Pi model

Defined in [`app/lib/models/pi.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/models/pi.dart).

Key fields:

- `piId`
- `location`
- `mascotIds`
- `latitude`
- `longitude`

## Data Access Layer

### Firestore usage

Most reads and writes are performed through Firestore’s REST API rather than the Flutter Firestore SDK:

- mascot operations: [`app/lib/apis/mascot_api.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/apis/mascot_api.dart)
- user operations: [`app/lib/apis/user_api.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/apis/user_api.dart)
- pi operations: [`app/lib/apis/pi_api.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/apis/pi_api.dart)

The repo consistently uses the Firestore database ID:

- `mascot-database`

Notable exception:

- [`app/lib/state/current_user.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/state/current_user.dart) restores a saved user through the Firestore SDK instead of REST
- [`app/lib/screens/6_catch_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/6_catch_screen.dart) updates `caughtMascots` through the SDK using `FieldValue.arrayUnion`

This means the app is using a **hybrid Firestore integration**: mostly REST, with a few SDK-based convenience calls.

### CurrentUser state

[`app/lib/state/current_user.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/state/current_user.dart) is the in-memory/session singleton for the authenticated user.

It:

- stores the currently loaded `User`
- persists the username locally
- restores the user on app startup
- clears session state on logout

## Game Constants and Rules

Shared reward and rarity helpers live in:

- [`app/lib/screens/helpers.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/helpers.dart)

Current values include:

- starting coins: `5`
- daily reward: `5`
- reward for visiting a different location: `2`
- reward for visiting a new location: `6`

Rarity is also converted into:

- display color
- display tier
- catch difficulty

## Assets

Important asset folders:

- mascot images: [`app/lib/assets/mascotimages`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/tree/main/app/lib/assets/mascotimages)
- mascot 3D models: [`app/lib/assets/3dmascots`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/tree/main/app/lib/assets/3dmascots)
- player assets: [`app/assets/player`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/tree/main/app/assets/player)
- icons: [`app/assets/icons`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/tree/main/app/assets/icons)
- UI mockups: [`ui-designs`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/tree/main/ui-designs)

Asset naming is important for mascot images because inventory and mascot screens derive paths using the mascot ID and mascot name.

## Repo Structure Summary

### Active folders

- `app/lib/screens`: user-facing screens and flow control
- `app/lib/apis`: Firestore access and backend helpers
- `app/lib/models`: core data models
- `app/lib/map`: Mapbox rendering and camera helpers
- `app/lib/utils`: routes and verification helper
- `app/lib/state`: persisted current user state
- `app/lib/widgets`: reusable UI components

### Support and platform folders

- `app/android`, `app/ios`, `app/macos`, `app/linux`, `app/windows`, `app/web`: Flutter platform targets

### Legacy, incomplete, or reference areas

These exist in the repo but are not central to the current primary path:

- older/readme-style API docs in `app/lib/apis/*_readme.md`
- `app/lib/apis/unused_api.dart`
- `app/lib/presence/*` experimental presence clients
- `app/lib/services/location_service.dart` and `app/lib/services/mascot_service.dart`, which are currently empty
- multiple tests that reference older screen names or earlier app structure

## Testing Situation

There is a sizable `app/test/` tree, but the current test suite is mixed:

- some widget and model tests exist
- some files are empty
- some tests reference legacy screen names such as `MapScreen`
- the checked-in tests do not cleanly map to the current active screen architecture

In practice, testing for this project has also been done manually by running the app on real target devices and validating that the major flows worked end-to-end, including login, navigation, map interaction, verification behavior, and collection/inventory updates.

This repo therefore has **partial and stale test coverage**, and the tests should not be treated as a fully current specification of the app.

A quick `flutter analyze` check in the current repo snapshot also reports errors from legacy/stale files, notably:

- `app/lib/apis/unused_api.dart`
- `app/test/screens/3_map_screen_test.dart`
- `app/test/widget_test.dart`

## Important Technical Notes

### 1. Firebase configuration

`main.dart` imports `firebase_options.dart`, which is typically generated by FlutterFire. In the current checked-in repo snapshot, that file is not present under `app/lib/`, so local setup depends on generating or otherwise supplying it.

### 2. Password handling

User passwords are currently stored plainly in the Firestore user document format used by this frontend. This is a major security limitation and should be addressed if the project continues beyond prototype scope.

### 3. Verification key material

`MascotVerificationHelper` includes a hardcoded Ed25519 seed for the JWT signing flow. That is acceptable only as prototype/demo infrastructure and should be replaced with a safer credential strategy in a production design.

### 4. Mixed data access strategy

The app uses both:

- Firestore REST calls
- direct Firestore SDK access

That works, but it increases maintenance complexity and should be kept in mind when debugging data consistency issues.

### 5. Hardcoded map and mascot values

Some mascot targets and map constants are hardcoded in the frontend. This is fine for a controlled campus demo, but it means some gameplay content is still embedded in client code rather than fully data-driven.

## Main Files to Read First

If someone new is onboarding to this repo, these are the most important files:

1. [`app/lib/main.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/main.dart)
2. [`app/lib/screens/3.1_mapbox_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/3.1_mapbox_screen.dart)
3. [`app/lib/screens/4_mascot_screen.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/screens/4_mascot_screen.dart)
4. [`app/lib/utils/mascot_verification_helper.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/utils/mascot_verification_helper.dart)
5. [`app/lib/apis/user_api.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/apis/user_api.dart)
6. [`app/lib/apis/mascot_api.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/apis/mascot_api.dart)
7. [`app/lib/state/current_user.dart`](https://github.com/spacecomputer-capstone/CatchTheMascot-frontend/blob/main/app/lib/state/current_user.dart)

## Short Summary

This repo is a Flutter frontend for a location-aware mascot-catching game. The major work in the codebase is the combination of:

- Firebase-backed user and mascot management
- Mapbox-based campus exploration
- BLE + Raspberry Pi proof-of-presence
- a newer JWT-based verification path layered on top of the older legacy verifier
- inventory/profile progression tied to coin and mascot collection systems

The most recent architectural direction is clearly toward **JWT-first presence verification with legacy fallback**, while still keeping the original gameplay loop and Firestore-backed app state intact.
