# Enchiridion

Enchiridion is a futuristic, offline-first reader application.

## Project Structure

- **enchiridion/**: The main Flutter application.
- **scripts/**: Data processing scripts (Python/Jupyter) and artifacts.

## Getting Started
### Create APK
- flutter build apk --release --split-per-abi
To run the Flutter application:

1. Navigate to the project directory:
   ```bash
   cd enchiridion
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## Documentation

- [Flutter Implementation Plan](FLUTTER_IMPLEMENTATION_PLAN.md)
- [Flutter Migration Guide](FLUTTER_MIGRATION_GUIDE.md)
- [Emulator Initialization](initializeEmulator.md)
