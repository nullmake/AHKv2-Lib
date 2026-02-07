# AHKv2-Lib

A collection of high-quality, strictly compliant, and well-tested libraries for AutoHotkey v2.

## Goals

- **Strict Compliance**: Adherence to official specifications (e.g., YAML 1.2.2).
- **Test-Driven Development**: 100% public member test coverage to ensure reliability.
- **Modern AHK v2 Syntax**: Built from the ground up using native v2 features (Map, Array, Objects).
- **Clean Architecture**: Clear separation of concerns following Core/Infrastructure layers.

## Architecture

The project is designed for high portability and modularity:

- **Feature-Based Structure**: Each library (e.g., Yaml) is organized in its own directory, making it easy to copy specific features into your project.
- **Minimal Dependencies**: Infrastructure components like logging and assertions are kept lightweight to ensure individual modules remain easy to integrate.
- **Portability**: Each source file includes its own license header, supporting the practice of picking up specific files as needed.

## Project Structure

```text
AHKv2-Lib/
├── documents/
├── source/
│   ├── lib/
│   │   └── infrastructure/
│   └── tests/
└── tools/
```

| Directory | Description |
| :--- | :--- |
| **documents/** | Technical specifications and design notes (Synced with GitHub Wiki). |
| **source/lib/infrastructure/** | Shared utility components (e.g., Logger, Assert). |
| **source/tests/** | Comprehensive unit tests following the library structure. |
| **tools/** | Helper scripts for development, build, and maintenance. |

## Planned Modules

1. **Yaml**: A robust YAML 1.2.2 parser and dumper.
2. **Infrastructure**: Reusable components like Logger, Assert, and ServiceLocator.

## Development

This project is developed in collaboration between human and AI, with a focus on engineering excellence and high-quality software development.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.
