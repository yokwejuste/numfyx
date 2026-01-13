# NumFyx

![numfyx UI](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/pm6yollm9ffngomw4ile.png)

A simple, offline Flutter app that converts all phone numbers in your device contacts to international E.164 format.

## Features

-   **Offline Operation**: All processing happens locally on your device
-   **E.164 Formatting**: Converts phone numbers to international standard format (+237XXXXXXXXX)
-   **Smart Processing**: 
    -   Leaves numbers already starting with + unchanged
    -   Uses Cameroon (CM) as default region for conversion
    -   Safely skips invalid numbers
-   **Clean UI**: Simple black and white interface
-   **Progress Tracking**: Real-time progress indicator during processing
-   **Detailed Statistics**: Shows scanned, updated, skipped, and failed numbers
-   **Safe**: Does not modify non-phone contact data

## Requirements

-   Flutter (stable channel)
-   Dart with null safety
-   Android 6.0+ or iOS 10.0+

## Dependencies

-   `flutter_contacts`: ^1.1.9+2
-   `libphonenumber_plugin`: ^0.3.3
-   `permission_handler`: ^12.0.1

## Installation

1.  Clone the repository
2.  Run `flutter pub get` to install dependencies
3.  Build and run on your device:
    ```bash
    flutter run
    ```

## Permissions

The app requires contacts permission to:

-   Read contacts from your device
-   Write formatted phone numbers back to contacts

### Android

Permissions are declared in `android/app/src/main/AndroidManifest.xml`:

-   `READ_CONTACTS`
-   `WRITE_CONTACTS`

### iOS

Permission description is in `ios/Runner/Info.plist`:

-   `NSContactsUsageDescription`

## Usage

1.  Launch the app
2.  Grant contacts permission when prompted
3.  Tap "Start Formatting" to begin processing
4.  Wait for completion
5.  Review statistics showing what was updated

## How It Works

1.  **Permission Check**: Requests contacts access on first launch
2.  **Contact Loading**: Fetches all contacts with phone numbers
3.  **Number Processing**: For each phone number:
    -   If it starts with +, skip it
    -   Otherwise, attempt to format to E.164 using Cameroon (CM) region
    -   Validate the formatted result
    -   Update contact if formatting succeeded
4.  **Statistics**: Track and display processing results

## Privacy

-   No data is sent to any server
-   No analytics or tracking
-   No internet connection required
-   All processing is done locally on your device

## Design Principles

-   Clean, production-ready code
-   Simple StatefulWidget state management (no external state libraries)
-   Comprehensive error handling
-   User-friendly progress feedback
-   Black and white UI only

## License

This project is a demonstration Flutter app.

## Notes

-   Numbers already in E.164 format (starting with +) are left unchanged
-   Invalid numbers that cannot be formatted are safely skipped
-   Contact data other than phone numbers remains untouched
-   Default region is set to Cameroon (CM) but can be modified in code

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

-   [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
-   [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
