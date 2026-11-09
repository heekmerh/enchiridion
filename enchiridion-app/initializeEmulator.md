REM point to JDK 25 for this terminal only
set "JAVA_HOME=C:\Program Files\Java\jdk-25"
set "PATH=%JAVA_HOME%\bin;%PATH%"

sdkmanager --enable-native-access=ALL-UNNAMED "platform-tools"

sdkmanager "emulator"

sdkmanager --licenses

sdkmanager "system-images;android-33;google_apis;x86_64"

sdkmanager "platforms;android-33"

## Create Emulator
avdmanager list devices

avdmanager create avd -n flutter_emulator -k "system-images;android-33;google_apis;x86_64" --device "pixel"

## Start Emulator
emulator -avd flutter_emulator -netdelay none -netspeed full
### Performance flags
emulator -avd flutter_emulator -gpu host -accel auto

adb devices

emulator-5554    device

flutter doctor
flutter devices

emulator-5554 (mobile) • android

flutter run -d windows --dart-define=SUPABASE_URL=https://lvyoqnmqdquadkfixduq.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx2eW9xbm1xZHF1YWRrZml4ZHVxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyNjQwNjksImV4cCI6MjA5NDg0MDA2OX0.aAH-CB2zyk4hvjC1NPWTIEBSCJUWpH7CbHRQthYkakI

flutter build apk --release

/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill