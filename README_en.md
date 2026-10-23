# Lingdong Photo

> This is the **4.0.0 Public Edition (Build 202649)**: local photo-creation code and standalone encryption transparency materials. The complete Letter feature and server implementation are excluded. Local-processing and account statements below describe this Public Edition's creation tools. See [publication scope](PUBLIC_EDITION.md) and [encryption protocol and checks](Transparency/README.md).

> **Language notice:** The Android version is currently not available in English. Its interface remains in Simplified Chinese for now.

Lingdong Photo is a local-first photo creation app for iOS and Android. The iOS app is built with SwiftUI, while the Android app uses Kotlin and Jetpack Compose. Both versions can extract perceptual colors, understand image content, read real capture metadata, and create photo cards, palettes, journals, bubble stamps, wallpapers, privacy masks, verifiable Photo Tickets, and multi-page Photo Albums. Color Relationship compares the shared, contrasting, and transitional colors of two photos. The iOS version also includes a plain-language Light Analysis for everyday users, turns photos into pencil, charcoal, or watercolor sketches, blends original photos into watercolor study sheets with Photo Painting, adds text or PNG artwork with Photo Signatures, converts a selected video segment into a Live Photo with a user-selected key photo, arranges photos into a complete Flowing-Light Fan, collects traditional colors by solar term in Solar-term Colors, and preserves thoughts beyond the frame in Photo Backs.

**Official app download (its feature scope differs from this Public Edition):** [Download Lingdong Photo](https://apps.apple.com/cn/app/%E7%81%B5%E5%8A%A8%E7%85%A7%E7%89%87/id6791514422)

The app is free to download, with no subscriptions or advertising. The iOS app offers optional “Support Us” content through a one-time purchase. Photo recognition, color analysis, and artwork rendering are performed on the device.

## Android version

The Android version is written in Kotlin and Jetpack Compose and supports Android 13 and later. Its UI and interactions are implemented specifically for Android. The photo-processing workflow does not depend on a project server, and the manifest does not request internet access.

### Creation modes and navigation

- Browse seven creation modes before importing a photo, plus separate entry points for Color Relationship, Photo Album, and Photo Ticket scanning.
- After loading a photo, switch modes from the panel at the top while keeping the current image and its on-device analysis.
- Available modes are Motion Card, Glass Palette, Instant Journal, Bubble Stamp, Spectrum Wallpaper, Privacy Mosaic, and Photo Ticket.

### Photo Ticket and verification

- Combine a photo, title, capture details, representative colors, and a ticket credential into a static PNG artwork.
- Choose Horizontal Classic, Vertical Travel, or Minimal Credential layouts. Horizontal tickets support landscape preview and editing.
- Use either a classic 1D code or a verification QR code, with separate controls for the text, capture time, location, device and lens, exposure details, and palette shared with viewers.
- Choose Standard or Time Capsule storytelling and add an optional message of up to 80 characters.
- Sign public QR data with a P-256 device key stored in Android Keystore.
- Scan and verify both Android- and iOS-generated Photo Tickets locally.
- QR codes never contain the original photo, album identifier, file path, or device serial number.

### Photo Album

- Five themes—Travel, Family, Children, Animals, and Custom—with 15 templates.
- A5 portrait, square, and A4 landscape book formats.
- Add regular photos or Lingdong artworks; edit cover and page text; add, duplicate, delete, and reorder pages.
- Preview the complete spread and export either a digital PDF or a print PDF with 3 mm bleed.

### Color Relationship

- Compare two photos using OKLab perceptual color and weighted palette matching.
- Explore Resonance, Compare, and Transition views.
- Automatically adapt the canvas to two landscape photos, two portrait photos, or a mixed pair without cropping away the full image.
- Display color affinity, lightness distance, and temperature distance with relationship-specific copy.
- Export a comparison image or a complete analysis at up to 2400 px wide, or original quality up to 8192 px on the longest edge.

### Color, analysis, and export

- Extract up to six representative colors using weighted K-Means in OKLab and show HEX values or literary color names with whole-image percentages.
- Classify image content locally with ML Kit and read camera, lens, aperture, shutter speed, ISO, focal length, time, and GPS metadata.
- Import through the system photo picker or another app’s share menu.
- Export JPEG, PNG, or HEIC at 1080P, 2K, or original quality up to 6000 px wide.
- Preserve all metadata, remove GPS only, or remove location, device, lens, and original capture time.
- Read, preview, and save Motion Photo creations. Privacy Mosaic always exports a treated static frame.

## Why this project exists

The project began as an experiment: how difficult is it to build a polished, small photo tool from scratch? The first iOS implementation studied publicly visible interaction patterns, but it did not use or reverse-engineer any third-party source code, assets, or private resources.

It has since grown far beyond an interface exercise. The project now includes perceptual OKLab color, weighted K-Means, color percentages, two-photo relationships, Apple Vision analysis, a category-based copy library, real EXIF metadata, Live Photo export, plain-language Light Analysis, video-to-Live Photo conversion, multi-photo journals, privacy masking, Photo Sketch, Photo Painting, Photo Signatures, verifiable Photo Tickets, device seals, in-app scanning, an App Clip, multi-page albums, Solar-term Colors, Photo Backs, a Photos action extension, App Shortcuts, and an export center. Android independently implements the same core workflow with platform-appropriate tools.

Some similar utilities charge a monthly subscription or a one-time fee. That is a valid choice for their developers; this project instead publishes its implementation so others can inspect, modify, and improve it.

## iOS features

### Creation modes and interface

- Browse twelve creation modes, plus independent Flowing-Light Fan, Photo Album, Color Relationship, Photo Ticket Reveal, Stamp Studio, Postcards, Scan and verify Photo Ticket, Video to Live Photo, Ticket Stubs, Stamp Collection, Solar-term Colors, and Photo Backs tools.
- Open independent tools without first entering the main editor. After importing a photo, switch creation modes or enter any tool from the same panel without selecting the image again.
- The mode picker uses translucent Liquid Glass and follows the system light or dark appearance.
- Every feature reorganizes its preview and controls for iPad portrait, landscape, larger displays, and resizable windows while retaining the compact iPhone experience.

### Palette Card and Lingdong Calendar

- Palette Card extracts dominant colors and extends the color strip below, left, or right without covering or cropping the photo.
- Lingdong Calendar includes Glass Calendar and Photo Calendar. Glass Calendar preserves the photo ratio and records its capture date and solar term; Photo Calendar places the photo beside a single-month calendar.
- Photo Calendar supports framing adjustments, hand-drawn date rings, Chinese or English month titles, and Hide Bottom Inscription. Supporters can also use Auto Color or a custom panel color.
- Glass Archive and Lingdong Calendar support landscape viewing on iPhone.

### Solar-term Colors

- Assign photos to the corresponding solar term from their original capture time, match representative colors to traditional colors, and gradually complete a solar-term year.
- Keep multiple photos for each term, choose an annual representative, and explore the complete sixteen-color set, phenology, poetry, and source references.
- Generate a partial or complete annual spectrum and export or restore a local collection backup. Date reading, color extraction, and traditional-color matching stay on the device.

### Photo Backs

- Write what the camera did not capture from the In the Frame, Outside the Frame, or For the Future perspective.
- Choose when to revisit a photo; it resurfaces when due, and a new Later entry can continue its story.
- Tap or swipe to flip between the front and back, with photos and writing kept in an on-device photo drawer.

### Flowing-Light Fan

- Arrange six photos across a complete open folding fan, with one photo presented independently on each panel.
- Single Photo Fan fills the complete fan with one image.
- Auto Color searches authorized photos on the device and combines six images from the same color family.
- Free Arrangement accepts up to six manually selected photos and lets you replace, pan, and zoom each panel for precise framing.
- Save the finished fan as a transparent 2400 × 1800 PNG.

### Stamps, postcards, and Stamp Collection

- Stamp Studio offers five perforation templates with photo, title, date, and font controls, and can collect the result or save it as PNG. Manual Framing supports direct dragging and pinch-to-zoom for precise composition.
- Stamps support Live Photo playback and can save the animated result to Photos.
- Postcard combines a photo, message, stamp, and postmark in four layouts.
- Stamp Collection stores geotagged stamps, reveals visited cities, and supports free rotation with a long press.

### Photo Ticket collections, developing, and archive

- Photo Ticket Collections organize tickets from trips, performances, or meaningful periods.
- Photo Ticket Developing recognizes an imported physical ticket on the device and recreates it as a verifiable Photo Ticket.
- Glass Archive preserves original device, capture-setting, and coordinate records in a Liquid Glass archive panel. The panel can move freely and pin one to six glass colors.
- Supporters can add custom archive text and choose a built-in font.
- Find Original on This Device scans a Photo Ticket and searches the local photo library for its original image.

### Personalization and supporter content

- Empty-screen Themes set a preferred primary color for every feature home screen before a photo is selected.
- Motion Card, Bubble Stamp, Instant Journal, Photo Signatures, and Glass Archive settings are available directly inside their respective tools.
- A one-time Support Us purchase unlocks poetic solar-term color names, collector Photo Ticket designs, all stamp and postcard templates, Glass Archive customization, fonts for Motion Card, Bubble Stamp, Instant Journal, and Photo Painting, Photo Calendar panels, Photo Signatures customization, exclusive app icons, and a supporter badge.
- Eligible early users of version 1.0.0 receive the same entitlement at no charge.
- When the entitlement is already active, the Support page explicitly says that no purchase is required and offers “Already Unlocked · Continue.” An account without an entitlement sees the localized price, and tapping the button starts the StoreKit purchase flow.

### Motion Card

- Generate a title from the image content and colors.
- Display real capture time or location data.
- Create a coordinated text area from the dominant color and its image coverage.
- Choose dark or light text with a target contrast ratio of at least 7:1.
- Use a solid-color or sampled gradient header.
- Change the displayed time with the system date picker or hide it.
- Motion Card Settings and Partial color selection remain available in Classic, Airy, and Immersive templates; drag and resize the sampling region or restore full-image sampling.
- All three templates support direct text editing, dragging, pinching, and type-size adjustments.
- Choose typography in Motion Card Settings. The system font is free, while supporters can use every built-in font.

### Glass Palette and Light Analysis

- Switch fluidly between Glass Palette and Light Analysis above the image.
- Glass Palette extracts six representative colors and shows their HEX values or one of 76 literary names, plus percentages that total 100%.
- Light Analysis explains shadows, midtones, highlights, contrast, exposure balance, and color-channel distribution in plain language.
- The analysis is fully offline and is phrased for ordinary users rather than professional photographers.
- Landscape and portrait photos are shown at their actual aspect ratio in Light Analysis, without cropping the image to fill the preview.
- Choose Single Row or Two Rows and preserve Liquid Glass or compatible frosted styling on export.

### Video to Live Photo

- Import a video with the system Photos picker and choose a continuous three-second segment from the complete timeline.
- The selection frame is proportional to the full video duration and can be dragged along the thumbnail strip; key-photo selection follows after the segment is confirmed.
- Choose the key photo frame by frame within the selected segment using an interaction inspired by the Live Photo editor in Apple Photos, then preview the result.
- Compatible source video and audio are passed through whenever possible to avoid unnecessary recompression, while the key photo is generated from the original video frame.
- Segment selection, frame extraction, Live Photo pairing, and saving are performed entirely on the device.

### Instant Journal

- Select one to five photos and automatically choose a collage arrangement.
- Use Auto Collage, Magazine Hero, or Vertical Filmstrip layouts.
- Select, replace, delete, reorder, reposition, and scale each photo independently.
- Generate copy and Emoji from on-device image analysis, regenerate alternatives, or edit them manually.
- Choose a copy font in Instant Journal Settings. The system font is free, while supporters can use every built-in font.

### Photo Signatures

- Switch between Bubble Stamp and Custom Signature.
- Combine the photo, copy, dominant color, and real capture parameters into a photographic stamp.
- Map internal camera product codes to readable names across major phone, camera, drone, and action-camera brands.
- Import local PNG camera marks for supported brands. Multicolor icons keep their colors; monochrome icons adapt to the artwork.
- Adjust image composition, typography, bubble scale, device information, and decorations.
- Choose a text font in Bubble Stamp Settings. The system font is free, while supporters can use every built-in font.
- Custom Signature adds a text signature, date and time, or a PNG signature to the full photo, with free positioning and scaling.
- The system font is free; supporters can unlock every signature font and custom PNG signatures.

### Spectrum Wallpaper

- Build a gradient spectrum from the dominant colors.
- Match the current device dimensions.
- Animate generation while respecting Reduce Motion.

### Privacy Mosaic

- Paint or erase mosaic regions manually.
- Use Apple Vision on the device to suggest faces, license plates, QR codes, and sensitive text.
- Enable or disable each detected region independently, undo edits, and change intensity and grain size.
- Export Live Photos as treated static images so untreated motion frames cannot expose private information.

Automatic detection is an aid and can miss or misclassify content. Always review identity documents, accounts, addresses, and other highly sensitive material before export.

### Photo Sketch

- Create pencil, charcoal, or watercolor interpretations entirely on the device.
- Adjust strength, stroke weight, original-color retention, and paper texture.
- Reset each style to its own defaults.

### Photo Painting

- Blend the original photo into layered watercolor washes, choose a brush direction, and adjust the framing.
- Customize the study-sheet title; supporters can also use the built-in stamp and postcard fonts.

### Photo Ticket

- Combine a photo, title, capture details, representative colors, and a ticket credential.
- Use Horizontal Classic, Vertical Travel, or Minimal Credential layouts and three width presets for the horizontal design.
- Sample a specific region for the ticket background and palette.
- Customize the main title or derive a city name from the photo location.
- Use a classic 1D code or a verification QR code and choose exactly which public fields to include.
- Choose Standard or Time Capsule storytelling and add an optional message.
- Sign public information with a P-256 key in the iPhone Secure Enclave; simulator signatures are explicitly marked as test data.
- Photo Tickets are exported as static PNG artworks. Live Photo ticket export is intentionally not provided.
- On supported iPhones, ticket generation uses the Dynamic Island as a visual output slot.

### Scanning and App Clip

- Scan a Photo Ticket verification QR code with the main app and parse it locally.
- The scanner does not take photos, save camera frames, or access the photo library.
- Show the ticket number, photo fingerprint, seal state, message, colors, copy, and capture fields selected by the creator.
- If the full app is not installed, the App Clip can display the same public information from the QR code without requesting Photos, Location, or Notifications access.

### Photo Album

- Five themes and 15 templates in A5 portrait, square, and A4 landscape formats.
- Add regular photos or Lingdong creations, replace and reposition images, edit text and fonts, and add, duplicate, delete, or reorder pages.
- Preview the complete book in landscape.
- Export a digital PDF or a print-ready PDF with 3 mm bleed. Empty slots remain blank, and low-resolution images are flagged before print export.

### Color Relationship

- Compare two photos with OKLab and weighted palette matching.
- Use Resonance for similar colors, Compare for the strongest difference, or Transition for a continuous bridge.
- Keep the reading direction consistent: colors on the left come from Photo 1 and colors on the right come from Photo 2.
- Display affinity, lightness distance, and temperature distance with stable, image-specific copy.
- Save either the photo-and-ribbon comparison or the complete analysis.

### Export Center

- Save to Photos, export to Files, or open the system share sheet.
- Choose JPEG, PNG, or HEIC and 1080P, 2K, or original quality up to 6000 px wide.
- Preserve metadata, remove location only, or remove GPS, device, lens, and original capture time.
- Preserve Live Photo motion when saving supported creations to Photos; Files, sharing, Privacy Mosaic, and Photo Ticket use static output.

### Photos action and App Shortcuts

- Open selected items from the Photos action list and continue in the main app with up to five photos and paired Live Photo video.
- Run Extract Photo Colors, Clean Photo Metadata, or Generate Spectrum Wallpaper without first opening the main interface.

## On-device intelligence and color extraction

iOS uses Apple Vision to recognize 34 broad content categories, including portraits, family, cats, dogs, birds, insects, gardens, forests, mountains, beaches, skies, sunsets, cities, architecture, streets, night scenes, food, coffee, travel, sport, and text screenshots. Classification uses `VNClassifyImageRequest`, `VNDetectFaceRectanglesRequest`, and `VNRecognizeTextRequest`; photos are not uploaded to the project author.

The palette pipeline works as follows:

1. Downsample and sample the complete image.
2. Convert RGB samples to OKLab.
3. Cluster representative colors with weighted K-Means.
4. Assign samples to the closest perceptual cluster.
5. Calculate whole-image coverage by pixel weight.
6. Correct rounding in the largest cluster so all percentages total 100%.

Literary names are selected from 76 references by nearest distance in OKLab.

## Liquid Glass and Live Photo

- iOS 26 uses native Liquid Glass APIs; iOS 17 and 18 use a compatible frosted material.
- iOS 27 and iPadOS 27 are supported at the system level, including resizable-window and layout changes.
- iPhone 18 Pro and iPhone 18 Pro Max include interface adjustments for their dimensions and Dynamic Island area.
- Buttons support press scaling, spring response, and haptics.
- Reduce Motion skips nonessential animation.
- The system Photos picker only provides items the user actively selects.
- On iOS 27 and later, importing begins after the system picker closes, with explicit recovery messages when reading fails or times out.
- EXIF, TIFF, and GPS fields are read from the original data when available.
- Paired Live Photo video can be imported, previewed, composited frame by frame, and written with a matching asset identifier. If audio encoding is incompatible, export automatically retries as a silent Live Photo and reports the saved result.
- After import, Live Photo motion frames are decoded and cached in the background before the user presses the Live control, so the first preview uses prepared playback content.
- Motion frames and key photos are normalized to standard dynamic range to avoid HDR brightness mismatches.
- Missing camera information stays empty; the app never invents a fixed model, aperture, or ISO value.

## Privacy

- No account, advertising, or third-party analytics SDK.
- No collection of user photos, creations, or device identifiers.
- Recognition, color calculation, and rendering stay on the device.
- Camera-brand PNG files imported by the user remain in local app storage.
- Verification QR codes contain only fields the creator chooses to make public.
- Device seals sign only public QR data; private keys remain in Secure Enclave or Android Keystore.
- Camera access is requested only when the user opens the Photo Ticket scanner.
- The app writes to Photos only after an explicit save action.
- iOS may use Apple’s system geocoding service when it needs to display a place name. Android does not include mapping and does not request internet access.

What can be completed on the device should stay on the device.

## Requirements

### iOS

- iOS 17.0 or later
- Xcode 26.0 or later for the iOS 26 Liquid Glass SDK
- Swift 5 language mode
- iPhone and iPad; the iPhone interface is portrait-first, while iPad supports a native sidebar, rotation, and resizable windows

### Android

- Android 13 or later (API 33+)
- Android Studio and Android SDK 36
- Android Gradle Plugin 8.13.2, Gradle 8.13, Kotlin 2.0.21
- JDK 17 or later; Java 11 bytecode target

## Build

### iOS

```bash
git clone https://github.com/LocalLens-Project/LingdongPhoto.git
cd LingdongPhoto
open lingdongzhaopian/lingdongzhaopian.xcodeproj
cp lingdongzhaopian/Config/Signing.local.example.xcconfig \
   lingdongzhaopian/Config/Signing.local.xcconfig
```

Fill in `DEVELOPMENT_TEAM`, the main app, extension, App Clip, parent app, and App Group identifiers in `Signing.local.xcconfig`. Create matching App IDs, share the App Group between the main app and Photos action extension, and configure the parent-app relationship for the App Clip. Then select an iOS 17+ simulator or device and run the project.

The public repository builds the non-commercial fallback declarations in `SupporterStore.swift` and `TraditionalColorLexiconData.swift` by default. Licensed commercial source files remain local and are ignored by Git. A licensed local checkout enables them by adding the following line to `Signing.local.xcconfig`:

```xcconfig
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) COMMERCIAL_BUILD
```

This excludes the public fallback declarations locally and compiles the StoreKit and complete color-data implementations without exposing them in the public repository. Except for Onboarding screenshots/GIFs and the two mode-entry selection screenshots, newly published product-image resources use commercial-license notice placeholders under their original asset names so that the public Asset Catalog remains buildable.

### Android

```bash
cd Android/lingdongzhaopian
./gradlew assembleDebug
```

The Debug APK is written to `app/build/outputs/apk/debug/app-debug.apk`. For a signed Release build, create a local `keystore.properties`, keep the key under the ignored `signing/` directory, and run `./gradlew assembleRelease`.

## Permissions

- The iOS Photos picker does not require full-library read permission for normal selection.
- Camera permission is used only for local QR scanning.
- Restoring paired Live Photo video from the Photos action may require limited or full Photos read access to match the selected original.
- Add-only Photos access is used when saving static artwork or Live Photos.
- The App Clip does not request Photos read/write, Camera, Location, or Notifications permission.
- Android uses the system picker and temporary share URIs, writes through MediaStore, and declares Camera and Vibration but no Internet, Location, or Microphone permission.

## Project structure

```text
.
├── README.md / README_en.md / README_zhhant.md
├── LICENSE / TRADEMARKS.md
├── Android/lingdongzhaopian/    # Kotlin + Jetpack Compose project
└── lingdongzhaopian/
    ├── Config/                  # Plists, entitlements, and signing templates
    ├── LingdongShareExtension/ # Photos action extension
    ├── LingdongTicketActivity/ # Main-app Live Activity
    ├── LingdongTicketClip/     # App Clip verification entry point
    ├── LingdongTicketClipActivity/
    ├── SharedActivity/         # Shared activity state and widgets
    ├── SharedTicket/           # Ticket payload, verification, and local-original lookup
    ├── lingdongzhaopian.xcodeproj/
    └── lingdongzhaopian/
        ├── Assets.xcassets/    # Public commercial-license notice placeholders
        ├── OnboardingScreens/  # Publishable onboarding screenshots and GIFs
        ├── Piaogence/          # Ticket collections, developing, and editions
        ├── Postal/             # Stamps, postcards, collections, Live Photos, and city resolution
        ├── PostalFonts/        # OFL fonts and complete license texts
        ├── Album*.swift
        ├── ApplicationIconFeature.swift
        ├── ColorRelationship*.swift
        ├── CreationSeasonEventView.swift
        ├── FanGalleryFeature.swift
        ├── IPadWorkspace.swift
        ├── LingdongFeatures.swift # Palette Card and Lingdong Calendar
        ├── ModeLauncherFeature.swift
        ├── PhotoBack*.swift
        ├── SignatureStampFeature.swift
        ├── SketchStudio.swift  # Photo Sketch and Photo Painting
        ├── SolarColor*.swift
        ├── SolarTermCalendar.swift
        ├── SupporterStore.swift             # Public fallback
        ├── TraditionalColorLexiconData.swift # Public fallback data
        └── lingdongzhaopianApp.swift
```

## License and trademarks

Source code is released under the [GNU Affero General Public License v3.0](./LICENSE), `AGPL-3.0-only`. Copying, modification, and redistribution must follow the license and provide the corresponding source. Modified software offered as a network service must also make its corresponding source available to those users.

The repository's open-source license applies only to source code that has been published. All images and commercial in-app-purchase content are excluded from the open-source release; contact us for commercial licensing.

The AGPL source license does not grant rights to the Lingdong Photo name, project branding, logo, App Icon, product-page artwork, or marketing screenshots. See [TRADEMARKS.md](./TRADEMARKS.md). Seek professional legal advice before commercial distribution, closed-source integration, or submitting a modified version to an app store.

## Contributing

Issues and pull requests are welcome, including new image categories and copy, improved Vision or ML Kit weighting, faster and more stable OKLab clustering, further iPad multiwindow and Android large-screen refinements, tests, and additional localizations. Before submitting code, build the relevant Debug and Release targets and do not include test photos containing personal location, EXIF, or identifiable people.

Lingdong Photo is initiated and maintained as an open-source LocalLens Project. LocalLens Project is a local-first software initiative of **Wenzhou Dulan Network Technology Co., Ltd.**, which currently provides full development, maintenance, and release support.
