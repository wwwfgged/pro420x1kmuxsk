# Збирання Muzik420

## Windows

### Потрібні інструменти

- Windows 10 або 11, x64.
- Flutter 3.41.9 stable (у ньому Dart 3.11.5; проєкт вимагає Dart `^3.11.0`).
- Visual Studio 2022 або Build Tools з компонентом **Desktop development with C++**, MSVC x64, CMake та Windows SDK.
- У Windows має бути ввімкнений **Developer Mode**: Flutter створює посилання для плагінів.

### Release-збірка

Відкрий PowerShell у корені репозиторію та виконай:

```powershell
flutter --version
flutter doctor -v
flutter pub get
flutter build windows --release
```

Готова програма буде в:

```text
build/windows/x64/runner/Release/
```

Для запуску залиш усю папку `Release` разом: окрім `muzik420_new.exe`, у ній є DLL та `data/` з ресурсами програми.

### Інсталятор Windows (необов'язково)

Проєкт містить сценарій Inno Setup `muzik420_setup.iss`. Для нього потрібні зібрана папка `Release` і Inno Setup 6. Сценарій наразі очікує проєкт у `C:\muzik420_new`; якщо репозиторій розташований інакше, перед компіляцією зміни `MySourceDir` та `OutputDir` на відповідні шляхи. Відкрий `.iss` у Inno Setup Compiler і натисни **F9**.

## Android

Потрібні Flutter SDK, Android Studio або Android SDK Command-line Tools, Android SDK та прийняті Android SDK ліцензії. У корені проєкту виконай:

```powershell
flutter doctor -v
flutter pub get
flutter build apk --release
```

APK буде в `build/app/outputs/flutter-apk/app-release.apk`.

## Apple та Linux

Для iOS і macOS потрібен macOS з Xcode; для Linux — Linux з Flutter desktop dependencies та CMake. Команди збірки:

```sh
flutter pub get
flutter build ios --release --no-codesign
flutter build macos --release
flutter build linux --release
```

Команду слід запускати на відповідній операційній системі. Зібрані файли Flutter кладе в підкаталоги `build/`.
