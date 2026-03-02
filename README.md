# AHKv2-Lib

A collection of robust, modular components optimized specifically for AutoHotkey v2.

## Key Features

- **Native v2 Optimization**: Leverages modern AHK v2 features (Map, Array, and Objects) for improved performance and readability.
- **Modular & Standalone**: Designed with minimal internal dependencies. Most utilities can be integrated into your project by simply copying a single file.

## Architecture & Portability

The project is structured for high portability:

- **Decoupled Design**: Each module (e.g., Yaml) is organized to function independently, making it easy to pick and choose only what you need.
- **Lightweight Infrastructure**: Core utilities like assertions and logging are kept minimal to prevent "dependency bloat" when integrating into your scripts.
- **Self-Contained Licenses**: Each source file includes its own license header, simplifying compliance for individual file usage.

## Project Structure

```text
AHKv2-Lib/
├── documents/
├── source/
│   ├── lib/
│   └── tests/
└── tools/
```

| Directory | Description |
| :--- | :--- |
| **documents/** | Technical specifications and design notes (Synced with GitHub Wiki). |
| **source/lib/** | Library files (Folders for modules, flat files for utilities). |
| **source/tests/** | Unit tests corresponding to the library structure. |
| **tools/** | Helper scripts for development and maintenance. |

## Development

This project is developed with the assistance of AI (Google Gemini).

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.
