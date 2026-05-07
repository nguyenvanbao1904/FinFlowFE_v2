# Widget Setup Guide — FinFlow Quick Add Widget

## Tổng quan

Widget cho phép user nhập giao dịch nhanh từ màn hình chính iOS bằng 3 cách:
1. **Voice** — Ghi âm giọng nói, tự động phân tích
2. **Text** — Nhập văn bản tự nhiên (AI parse)
3. **OCR** — Chụp/chọn ảnh hoá đơn

Widget hiển thị tổng chi tiêu hôm nay và 3 nút action.

---

## Files đã tạo

### Widget Extension (FinFlowWidget/)
```
FinFlowWidget/
├── FinFlowWidgetBundle.swift       ← Entry point
├── QuickAddWidget.swift            ← Widget UI + Timeline Provider
├── QuickAddIntents.swift           ← 3 AppIntents (Voice, Text, OCR)
└── QuickAddSharedState.swift       ← App Groups communication (widget-local copy)
```

### Main App Changes
```
FinFlowIos/FinFlow/Core/
├── QuickAddSharedState.swift       ← App Groups communication (app copy)
└── WidgetUpdateHelper.swift        ← Helper để reload widget

Packages/FinFlowCore/Sources/FinFlowCore/State/
└── WidgetInputMode.swift           ← Enum shared giữa app và widget

Modified files:
- FinFlowIosApp.swift               ← Handle widget activation + update summary
- AddTransactionView.swift          ← Auto-trigger input mode
- DependencyContainer+AppViews.swift ← Pass autoTriggerMode
- NavigationTypes.swift             ← AppRoute.addTransaction(autoTriggerMode:)
- TransactionListViewModel.swift    ← Fix .addTransaction() call
```

---

## Bước 1: Tạo Widget Extension Target trong Xcode

1. Mở `FinFlow.xcodeproj` trong Xcode
2. File → New → Target
3. Chọn **Widget Extension**
4. Cấu hình:
   - Product Name: `FinFlowWidget`
   - Bundle Identifier: `com.finflow.FinFlowIos.FinFlowWidget`
   - Include Configuration Intent: **NO** (không cần)
5. Click **Finish**
6. Xcode sẽ tạo folder `FinFlowWidget/` với template files — **XÓA** tất cả template files (Widget.swift, WidgetBundle.swift, etc.)

---

## Bước 2: Add Widget Files vào Target

1. Trong Xcode Project Navigator, kéo folder `FinFlowWidget/` (đã có 4 files) vào project
2. Đảm bảo **Target Membership** của 4 files widget là `FinFlowWidget` target:
   - FinFlowWidgetBundle.swift ✅ FinFlowWidget
   - QuickAddWidget.swift ✅ FinFlowWidget
   - QuickAddIntents.swift ✅ FinFlowWidget
   - QuickAddSharedState.swift ✅ FinFlowWidget

3. Add `QuickAddSharedState.swift` vào **CẢ 2 targets**:
   - File Inspector → Target Membership:
     - ✅ FinFlowIos (main app)
     - ✅ FinFlowWidget

4. Add `WidgetInputMode.swift` vào FinFlowCore package (đã tạo sẵn)

---

## Bước 3: Enable App Groups

Widget và Main App cần share data qua App Groups UserDefaults.

### 3.1. Main App Target (FinFlowIos)
1. Select `FinFlowIos` target → Signing & Capabilities
2. Click **+ Capability** → chọn **App Groups**
3. Click **+** để add group: `group.com.finflow.shared`

### 3.2. Widget Extension Target (FinFlowWidget)
1. Select `FinFlowWidget` target → Signing & Capabilities
2. Click **+ Capability** → chọn **App Groups**
3. Click **+** để add group: `group.com.finflow.shared` (cùng ID với main app)

---

## Bước 4: Configure Widget Target Settings

### 4.1. Deployment Target
- FinFlowWidget target → General → Deployment Info
- iOS Deployment Target: **17.0** (để dùng interactive widgets)

### 4.2. Info.plist (Widget)
Widget target tự động có `Info.plist`. Không cần thêm gì.

### 4.3. Bundle ID
- Main App: `com.finflow.FinFlowIos`
- Widget: `com.finflow.FinFlowIos.FinFlowWidget` (phải là child của main app)

---

## Bước 5: Build & Run

### 5.1. Build Widget Extension
```bash
# Trong Xcode, chọn scheme "FinFlowWidget" → Run
# Hoặc command line:
xcodebuild -scheme FinFlowWidget -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### 5.2. Test Widget
1. Run main app (`FinFlowIos` scheme)
2. Đăng nhập vào app
3. Về Home Screen → long press → Add Widget
4. Tìm "FinFlow" → chọn "Nhập Giao Dịch Nhanh"
5. Chọn size: Small (2×2) hoặc Medium (4×2)
6. Tap nút Voice/Text/OCR → app mở và tự động kích hoạt chế độ tương ứng

---

## Bước 6: Verify App Groups

Kiểm tra App Groups hoạt động:

```swift
// Trong Xcode Debug Console, chạy:
po UserDefaults(suiteName: "group.com.finflow.shared")?.dictionaryRepresentation()

// Sau khi tap widget button, sẽ thấy:
// ["widget.pendingInputMode": "voice"] hoặc "text" hoặc "ocr"
```

---

## Troubleshooting

### Widget không hiển thị trong Add Widget menu
- Kiểm tra Bundle ID: widget phải là child của main app (`com.finflow.FinFlowIos.FinFlowWidget`)
- Clean Build Folder (Cmd+Shift+K) và rebuild

### Widget tap không mở app
- Kiểm tra App Groups đã enable cho CẢ 2 targets
- Kiểm tra `appGroupID` trong `QuickAddSharedState.swift` khớp với Xcode settings

### App không nhận được input mode từ widget
- Debug: print trong `handleWidgetQuickAdd()` để xem `consumePendingInputMode()` trả về gì
- Kiểm tra `QuickAddSharedState.swift` có trong cả 2 targets

### Widget hiển thị "0 ₫" expense
- App chưa gọi `WidgetUpdateHelper.updateTodaySummary()` sau transaction
- Kiểm tra notification `.transactionDidSave` có fire không

### Compile errors "No such module 'FinFlowCore'"
- Đây là SourceKit diagnostic lỗi — bỏ qua nếu build thành công
- Widget target không import FinFlowCore (dùng local copy của `WidgetInputMode`)

---

## Widget Preview trong Xcode

Xcode 15+ hỗ trợ preview widget:

1. Mở `QuickAddWidget.swift`
2. Canvas sẽ hiển thị preview (nếu không thấy: Cmd+Option+Enter)
3. Preview có 2 size: Small và Medium

---

## Next Steps (Optional)

### 1. Custom Widget Refresh
Hiện tại widget refresh mỗi 30 phút. Để refresh ngay sau transaction:

```swift
// Trong AddTransactionViewModel.saveTransaction():
NotificationCenter.default.post(name: .transactionDidSave, object: nil)
// → FinFlowIosApp đã observe và gọi WidgetUpdateHelper.updateTodaySummary()
```

### 2. Lock Screen Widget (iOS 16+)
Thêm `.accessoryCircular` family vào `QuickAddWidget.supportedFamilies`:

```swift
.supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
```

### 3. Widget Deep Link Analytics
Track widget usage:

```swift
// Trong handleWidgetQuickAdd():
Analytics.log("widget_quick_add", parameters: ["mode": mode.rawValue])
```

---

## Summary

✅ Widget hiển thị chi tiêu hôm nay  
✅ 3 nút: Voice, Text, OCR  
✅ Tap → mở app → tự động kích hoạt chế độ tương ứng  
✅ App tự động update widget sau mỗi transaction  
✅ Dùng App Groups để share data  

**Lưu ý:** Widget Extension là separate target, không thể tạo bằng code — phải setup qua Xcode UI.
