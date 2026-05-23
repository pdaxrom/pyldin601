# Pyldin 601

Эмулятор болгарского 8-битного компьютера Pyldin-601 на базе MC6800.

Также добавлен экспериментальный режим нового FPGA-компьютера Pyldin-601 HD6303:

```sh
./pyldin -m hd6303
```

Запуск без `-m` остается старым Pyldin-601.

Основной desktop-проект находится в каталоге [`pyldin601/`](./pyldin601).

## Сборка desktop-версии

Сборка переведена на `CMake` + `vcpkg` в manifest mode.

### Что нужно

- `CMake` 3.24 или новее
- рабочий компилятор C/C++
- полный checkout `vcpkg`
- переменная окружения `VCPKG_ROOT`, указывающая на этот checkout

Важно: нужен именно каталог `vcpkg`, в котором есть файл `scripts/buildsystems/vcpkg.cmake`.

Пример:

```sh
export VCPKG_ROOT=/path/to/vcpkg
```

## Быстрый старт

```sh
cd pyldin601
cmake --preset release
cmake --build --preset release
```

После этого build-дерево будет создано в:

```text
pyldin601/out/build/release
```

## Что делает `vcpkg`

При первом `cmake --preset ...` автоматически подтягиваются зависимости из [`pyldin601/vcpkg.json`](./pyldin601/vcpkg.json):

- `sdl2`
- `sdl2-image`
- `zlib`

Локальная копия зависимостей для конкретного build-а попадает в:

```text
pyldin601/out/build/<preset>/vcpkg_installed
```

## Presets

Доступные configure presets описаны в [`pyldin601/CMakePresets.json`](./pyldin601/CMakePresets.json):

- `debug`
- `release`
- `macos-release`
- `linux-release`
- `windows-release`

Обычно достаточно `release`. Платформенные preset-ы оставлены как aliases для соответствующей host-системы.

## Сборка и упаковка

### Обычная сборка

```sh
cd pyldin601
cmake --preset release
cmake --build --preset release
```

### Staged bundle

Собирает приложение и раскладывает рядом все нужные ROM/Bios/Floppy/shader-файлы.

```sh
cd pyldin601
cmake --preset release
cmake --build --preset bundle-release
```

Результат:

- macOS: `pyldin601/out/build/release/bundle/Pyldin-601.app`
- Linux: `pyldin601/out/build/release/bundle/bin/pyldin` и `share/pyldin`
- Windows: `pyldin601/out/build/release/bundle/bin/pyldin.exe` и рядом runtime/data файлы

### Финальный пакет

```sh
cd pyldin601
cmake --preset release
cmake --build --preset package-release
```

Формат пакета зависит от платформы:

- macOS: `.dmg`
- Linux: `.tar.gz`
- Windows: `.zip`

Файлы пакетов создаются в:

```text
pyldin601/out/build/release
```

## Установка в произвольный каталог

Если нужен install tree без CPack:

```sh
cd pyldin601
cmake --preset release
cmake --build --preset release
cmake --install out/build/release --prefix /tmp/pyldin601-install
```

## Где лежат данные эмулятора

Во время install/bundle/package CMake автоматически добавляет:

- `Bios`
- `Floppy`
- `Rom`
- `Hd6303`
- `shaders`

Источники данных:

- [`native/Bios/`](./native/Bios)
- [`native/Floppy/`](./native/Floppy)
- [`native/RAMROMDiskPipnet/`](./native/RAMROMDiskPipnet)
- [`native-hd6303/Hd6303/`](./native-hd6303/Hd6303)
- [`pyldin601/shaders/`](./pyldin601/shaders)

## Платформенные замечания

### macOS

```sh
cd pyldin601
cmake --preset release
cmake --build --preset release
cmake --build --preset bundle-release
cmake --build --preset package-release
```

Будет собран `.app` bundle и `.dmg`.

### Linux

```sh
cd pyldin601
cmake --preset release
cmake --build --preset release
cmake --build --preset bundle-release
cmake --build --preset package-release
```

Будет собран install tree и `.tar.gz`.

### Windows

Запускать лучше из `Developer Command Prompt`, `PowerShell` с настроенным toolchain или из среды с MinGW/Visual Studio.

```sh
cd pyldin601
cmake --preset release
cmake --build --preset release
cmake --build --preset bundle-release
cmake --build --preset package-release
```

Будет собран `.zip`.

## Полезные опции CMake

Примеры:

```sh
cmake --preset release -DPYLDIN_ENABLE_ASAN=ON
cmake --preset release -DPYLDIN_ENABLE_OPENGL=ON
cmake --preset release -DPYLDIN_UNIBIOS_ONLY=ON
```

Основные опции:

- `PYLDIN_ENABLE_ASAN` — AddressSanitizer для локальной отладки
- `PYLDIN_ENABLE_OPENGL` — включить OpenGL renderer path
- `PYLDIN_UNIBIOS_ONLY` — устанавливать только UniBios ROM set
- `PYLDIN_BUNDLE_RUNTIME_DEPS` — копировать runtime-библиотеки в bundle/package

## Проверенная команда на macOS

```sh
export VCPKG_ROOT=/Users/sash/Work/vcpkg
cd /Users/sash/Work/P601/pyldin601/pyldin601
cmake --preset release
cmake --build --preset release --parallel
cmake --build --preset bundle-release
cmake --build --preset package-release
```
