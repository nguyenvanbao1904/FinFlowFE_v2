# Chapter 11 — Conventions & Linting

## 11.1 SwiftLint Configuration

The project uses SwiftLint with **14 custom rules** that enforce architectural boundaries at compile time. The configuration lives in `.swiftlint.yml` at the project root.

### Scan Scope

```yaml
included:
  - FinFlowIos/FinFlow # App target code
  - Packages # All feature modules

excluded:
  - "**/.build" # SPM build artifacts
  - "**/checkouts" # Third-party source checkouts
  - "**/DerivedData" # Xcode build cache
  - "**/SourcePackages" # Resolved packages
  - "**/Tests" # Test targets excluded
```

### Disabled Built-in Rules

These default SwiftLint rules are disabled project-wide:

```yaml
disabled_rules:
  - trailing_whitespace
  - line_length
  - file_length
  - function_body_length
  - type_body_length
  - identifier_name
  - closure_parameter_position
```

## 11.2 Custom Rules — Full Reference

### 🔴 Error-Level Rules (Build-Breaking)

These rules have `severity: error` — violations **must** be fixed before merging.

#### 1. `no_print` — No Print Statements

```yaml
regex: "\\b(?:print|debugPrint|NSLog)\\s*\\("
```

**Banned:** `print()`, `debugPrint()`, `NSLog()`
**Use instead:** `Logger` from FinFlowCore (wraps `os.Logger` with category support)

```swift
// ❌ Banned
print("User logged in")

// ✅ Correct
Logger.info("User logged in", category: "Auth")
Logger.debug("Token refreshed", category: "Network")
```

#### 2. `no_combine_property_wrappers` — No Combine Wrappers

```yaml
regex: "@(?:Published|StateObject|ObservedObject)\\b"
```

**Banned:** `@Published`, `@StateObject`, `@ObservedObject`
**Use instead:** `@Observable` class with plain properties

```swift
// ❌ Banned
class MyViewModel: ObservableObject {
    @Published var items: [Item] = []
}

// ✅ Correct
@Observable
class MyViewModel {
    var items: [Item] = []
}
```

#### 3. `no_observable_object` — No ObservableObject Protocol

```yaml
regex: ":\\s*ObservableObject\\b"
```

**Banned:** Conforming to `ObservableObject`
**Use instead:** `@Observable` macro (Swift Observation framework)

#### 4. `no_navigation_link_destination` — No Direct NavigationLink Destinations

```yaml
regex: "NavigationLink\\s*\\(\\s*destination\\s*:"
```

**Banned:** `NavigationLink(destination:)` for feature screens
**Use instead:** `router.navigate(to: .someRoute)`

```swift
// ❌ Banned
NavigationLink(destination: ProfileView()) {
    Text("Profile")
}

// ✅ Correct — value-based navigation
Button("Profile") {
    router.navigate(to: .profile)
}
```

> NavigationLink with `value:` label for in-list navigation is acceptable.

#### 5. `no_hardcoded_padding` — No Magic Padding Numbers

```yaml
regex: "\\.padding\\s*\\(\\s*[0-9]+|\\.padding\\s*\\(\\s*\\.[a-zA-Z]+\\s*,\\s*[0-9]+"
```

**Banned:** `.padding(16)`, `.padding(.horizontal, 20)`
**Use instead:** `Spacing` tokens

```swift
// ❌ Banned
.padding(16)
.padding(.horizontal, 20)

// ✅ Correct
.padding(Spacing.sm)            // 16pt
.padding(.horizontal, Spacing.md) // 20pt
```

#### 6. `no_hardcoded_spacing` — No Magic Stack Spacing

```yaml
regex: "(?:VStack|HStack|ZStack|LazyVStack|LazyHStack)\\s*\\([^)]*spacing\\s*:\\s*[0-9]+(?:\\.[0-9]+)?"
```

**Banned:** `VStack(spacing: 8)`, `HStack(spacing: 16.0)`
**Use instead:** `Spacing` tokens

```swift
// ❌ Banned
VStack(spacing: 8) { ... }

// ✅ Correct
VStack(spacing: Spacing.xs) { ... }  // 8pt
```

#### 7. `no_url_session` — No Direct URLSession

```yaml
regex: "URLSession\\."
```

**Banned:** `URLSession.shared.data(...)` or any direct `URLSession` usage
**Use instead:** `APIClient` actor (handles auth, retry, timeout, token refresh)

#### 8. `domain_layer_isolation` — No UI Imports in Domain

```yaml
included: ".*Domain.*\\.swift"
regex: "import\\s+(?:SwiftUI|UIKit)\\b"
```

**Scope:** Only files in `Domain/` directories
**Banned:** `import SwiftUI`, `import UIKit`
**Why:** Domain layer is pure business logic — it must be platform-independent

#### 9. `no_business_logic_in_view` — No UseCase/Repository in Views

```yaml
included: ".*View\\.swift"
regex: "(?:UseCase|Repository)\\s*\\("
```

**Scope:** Only files ending in `View.swift`
**Banned:** Constructing `UseCase(...)` or `Repository(...)` in view files
**Why:** Views receive a ViewModel; the ViewModel owns use case references

#### 10. `no_cross_module_import` — No Cross-Package Imports

```yaml
included: ".*Packages/.*\\.swift"
regex: "import\\s+(?:Identity|Dashboard|Profile|Transaction)\\b"
```

**Scope:** All Swift files under `Packages/`
**Banned:** Importing sibling feature packages
**Why:** Feature modules must be buildable and testable independently

### 🟡 Warning-Level Rules (Should Fix)

These rules have `severity: warning` — they highlight code that violates guidelines but won't block the build.

#### 11. `no_hardcoded_colors` — Prefer AppColors

```yaml
regex: "\\.(?:foregroundColor|background|foregroundStyle|tint)\\s*\\(\\s*(?:Color\\(|\\.(?:blue|red|green|...))"
```

**Discouraged:** `.foregroundStyle(.blue)`, `.background(Color(.red))`
**Prefer:** `AppColors` tokens

```swift
// ⚠️ Warning
.foregroundStyle(.blue)

// ✅ Preferred
.foregroundStyle(AppColors.accent)
```

> Exception: Building base design system components or following specific HIG guidelines.

#### 12. `prefer_app_typography` — Prefer AppTypography

```yaml
regex: "\\.font\\s*\\(\\s*\\.(?:system|largeTitle|title|headline|body|...)"
```

**Discouraged:** `.font(.headline)`, `.font(.system(size: 14))`
**Prefer:** `AppTypography` tokens

```swift
// ⚠️ Warning
.font(.headline)

// ✅ Preferred
.font(AppTypography.headline)
```

#### 13. `no_direct_sheet_or_cover` — Delegate Sheets to Router

```yaml
included: ".*View\\.swift"
regex: "\\.(?:sheet|fullScreenCover)\\s*\\(\\s*(?:item|isPresented)"
```

**Discouraged:** Using `.sheet(isPresented:)` for full feature screens
**Prefer:** `router.presentSheet(.someRoute)`

> Exception: Small local confirmation dialogs that don't represent a feature screen.

#### 14. `liquid_glass_materials_guideline` — Use Materials Sparingly

```yaml
regex: "\\.(?:ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial|ultraThickMaterial)\\b"
```

**Allowed but flagged:** Material modifiers (Liquid Glass effects)
**Guidance:** Use sparingly, avoid on large scrolling content due to performance

## 11.3 Naming Conventions

### Files

| Type       | Pattern                         | Example                                                |
| ---------- | ------------------------------- | ------------------------------------------------------ |
| View       | `<Feature>View.swift`           | `LoginView.swift`, `HomeView.swift`                    |
| ViewModel  | `<Feature>ViewModel.swift`      | `LoginViewModel.swift`                                 |
| UseCase    | `<Action><Entity>UseCase.swift` | `LoginUseCase.swift`, `GetTransactionsUseCase.swift`   |
| Repository | `<Feature>Repository.swift`     | `AuthRepository.swift`                                 |
| Component  | `<Descriptive>Name.swift`       | `GlassTextField.swift`, `CategorySelectionSheet.swift` |
| Protocol   | `<Name>Protocol.swift`          | `SessionManagerProtocol.swift`                         |

### Types

| Type           | Convention                            | Example                                        |
| -------------- | ------------------------------------- | ---------------------------------------------- |
| ViewModels     | `@Observable @MainActor final class`  | `LoginViewModel`                               |
| UseCases       | `struct`, `Sendable`                  | `LoginUseCase`                                 |
| Repositories   | `actor` or `final class: Sendable`    | `TransactionRepository` (actor), `AuthRepository` (final class) |
| Actors         | `actor` for thread-safe mutable state | `APIClient`, `PINManager`, `BotChatGateway`    |
| Enums (tokens) | `enum` with `static let`              | `AppColors`, `Spacing`, `AppTypography`        |
| Protocols      | Suffix `Protocol`                     | `SessionManagerProtocol`, `TokenStoreProtocol` |

### Properties & Methods

| Convention                 | Example                                                     |
| -------------------------- | ----------------------------------------------------------- |
| ViewModel state properties | `isLoading`, `error`, `items`                               |
| ViewModel actions          | `func loadData() async`, `func handleLogin()`               |
| UseCase entry point        | `func execute(...)`                                         |
| Boolean prefixes           | `is`, `has`, `should`, `can`                                |
| Router actions             | `navigate(to:)`, `pop()`, `popToRoot()`, `presentSheet(_:)` |

## 11.4 Design System Token Usage

### Spacing Tokens (`Spacing` enum)

| Token                 | Value | Usage                               |
| --------------------- | ----- | ----------------------------------- |
| `Spacing.xs`          | 8pt   | Tight spacing, icon gaps            |
| `Spacing.sm`          | 16pt  | Standard padding, list item spacing |
| `Spacing.md`          | 20pt  | Section padding, form field gaps    |
| `Spacing.lg`          | 32pt  | Section separators, large gaps      |
| `Spacing.xl`          | 40pt  | Hero spacing, major section gaps    |
| `Spacing.iconSmall`   | 24pt  | Small icon frames                   |
| `Spacing.iconMedium`  | 32pt  | Medium icon frames                  |
| `Spacing.touchTarget` | 44pt  | iOS minimum touch target            |

> Alias: `AppSpacing` = `Spacing` (for lint rules)

### Corner Radius Tokens

| Token                 | Value |
| --------------------- | ----- |
| `CornerRadius.micro`  | 6pt   |
| `CornerRadius.small`  | 12pt  |
| `CornerRadius.medium` | 16pt  |
| `CornerRadius.large`  | 20pt  |
| `CornerRadius.pill`   | 100pt |

### Border Width Tokens

| Token                  | Value |
| ---------------------- | ----- |
| `BorderWidth.hairline` | 0.5pt |
| `BorderWidth.thin`     | 1pt   |
| `BorderWidth.medium`   | 2pt   |
| `BorderWidth.thick`    | 3pt   |

### Opacity Tokens

| Token                     | Value | Usage                          |
| ------------------------- | ----- | ------------------------------ |
| `OpacityLevel.ultraLight` | 0.1   | Ultra subtle backgrounds       |
| `OpacityLevel.light`      | 0.2   | Light overlays, dividers       |
| `OpacityLevel.low`        | 0.3   | Subtle shadows, disabled icons |
| `OpacityLevel.medium`     | 0.4   | Borders, moderate disabled     |
| `OpacityLevel.strong`     | 0.5   | Selected/active states         |
| `OpacityLevel.high`       | 0.8   | Prominent highlights           |

### Color Tokens (AppColors)

| Category          | Tokens                                                                                                                                                                                                                        |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Brand**         | `primary` (accent color)                                                                                                                                                                                                      |
| **Semantic**      | `success`, `error`, `accent`, `disabled`, `textInverted`                                                                                                                                                                      |
| **Social**        | `google`, `apple`, `expense` (alias: google), `destructive` (alias: google)                                                                                                                                                   |
| **UI Components** | `overlayBackground`, `inputBorderDefault`, `glassBorder`, `glassBorderFocused`, `errorBorder`, `buttonDisabled`, `settingsCardBackground`                                                                                     |
| **Backgrounds**   | `appBackground`, `cardBackground`                                                                                                                                                                                             |
| **Charts**        | `chartGridLine`, `chartRevenue`, `chartProfit`, `chartIncomeInterest`, `chartIncomeFee`, `chartIncomeOther`, `chartAsset*` (9 tokens), `chartCapital*` (7 tokens), `chartGrowthStrong`, `chartGrowthStable`, `chartInventory` |

### Typography Tokens (AppTypography)

| Category          | Tokens                                                        |
| ----------------- | ------------------------------------------------------------- |
| **Display**       | `displayXL`, `largeTitle`, `displayLarge`, `displayMedium`, `title`, `displaySmall`, `displayCaption`, `iconMedium` |
| **System Scaled** | `headline`, `subheadline`, `body`, `caption`, `caption2`, `buttonTitle` |
| **Specialty**     | `icon`, `pinDigit`, `profileStat`, `labelSmall` |

## 11.5 Logging

**Never use `print()`** — use `Logger` from FinFlowCore:

```swift
Logger.info("User authenticated", category: "Auth")
Logger.debug("Cache hit for key: \(key)", category: "Cache")
Logger.error("Failed to fetch: \(error)", category: "Network")
```

The `Logger` wrapper uses `os.Logger` under the hood, providing:

- Structured categories for filtering in Console.app
- Automatic redaction of sensitive data in release builds
- Zero overhead when logging is disabled

## 11.6 Concurrency Conventions

| Context                     | Annotation                 |
| --------------------------- | -------------------------- |
| ViewModel class             | `@MainActor`               |
| Router                      | `@MainActor`               |
| DependencyContainer         | `@MainActor`               |
| Network client              | `actor` (`APIClient`)      |
| Security manager            | `actor` (`PINManager`)     |
| Chat orchestrator           | `actor` (`BotChatGateway`) |
| UseCase struct              | `Sendable`                 |
| Enum types (routes, states) | `Sendable`                 |

**Rule of thumb:** If it holds mutable state → `actor` or `@MainActor`. If it's a value type passed across boundaries → `Sendable`.

## 11.7 Import Order Convention

```swift
// 1. Feature package (if in app target)
import Dashboard
import Identity
import Transaction

// 2. Core package
import FinFlowCore

// 3. Apple frameworks
import Foundation
import SwiftUI
import Observation
```

## 11.8 Comment & Documentation Style

- Use `///` for public API documentation
- Use `// MARK: -` to organize sections within files
- Vietnamese comments are acceptable for internal notes and TODOs
- `// swiftlint:disable:next <rule>` for justified suppressions (add comment explaining why)

## 11.9 Git Conventions

- Feature branches: `feature/<description>`
- Bugfix branches: `fix/<description>`
- Commit messages: concise English, imperative mood
- PR descriptions: summary + test plan

---

_Previous: [Chapter 10 — Testing](./10-testing.md)_
