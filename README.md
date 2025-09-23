# Rankle

An iOS app to create and manage ranked lists via quick 1v1 matchups.

## Requirements
- Xcode 15+
- iOS 16+
- XcodeGen (install via Homebrew: `brew install xcodegen`)

## Project Structure
```
Rankle/
  project.yml                # XcodeGen spec
  Rankle/
    Supporting/Info.plist
    Sources/
      App/                   # App entry and root view
      Models/                # Data models
      Services/              # Persistence services
      ViewModels/            # Observable view models
      Views/                 # SwiftUI screens
    Tests/
      RankingTests.swift
```

## Generate Xcode Project
```bash
cd /Users/ishaan28/Desktop/rankle
xcodegen generate
open Rankle.xcodeproj
```

## Run
- Select the "Rankle" scheme
- Choose an iOS 16+ simulator
- Build & Run (Cmd+R)

## Features (MVP)
- Create lists with initial items
- Pairwise ranking via binary insertion comparisons
- Add items to an existing list
- Local JSON persistence

## Next Steps
- Better matchup scheduling and progress indicators
- Import/export and sharing
- Cloud sync
