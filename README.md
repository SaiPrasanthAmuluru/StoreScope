# StoreScope

See the data saved in Core Data **inside your running app** — no DB Browser, no hunting for the `.sqlite` file, no third-party library. Works on Simulator and real devices. Built for modular apps: register one container per module and browse them all.

> **Status:** pre-release. This package is in the design/requirements stage — no source code has been written yet. The install instructions, API and examples below describe the planned `0.1.0` surface, not something you can `swift build` today.

## Install

```swift
.package(url: "https://github.com/SaiPrasanthAmuluru/StoreScope.git", from: "0.1.0")
```

### What ships in Release

Xcode cannot link an SPM product for one build configuration only, so the package is always linked. The behaviour in a **Release** build is:

- The UIKit glue (shake hook, floating-button window, presentation) is compiled out with `#if DEBUG`, and every public `StoreScope` method is an empty stub. Nothing is registered or retained.
- The platform-neutral `…Core` and `…UI` targets still compile into the binary but are never called.

`DEBUG` is the standard flag of Xcode's Debug configuration. If your app has extra configurations (QA, Staging) that build with Release settings, the inspector is **off** there. To enable it in such a configuration, wrap your own calls: the package cannot see your app's custom compilation flags.

## Use

The API is three calls: `register` each container, `start` the triggers, and optionally `present` from code. All of them are no-ops in Release, so call sites need no `#if DEBUG`.

- Shake the device, or **Device ▸ Shake** in the Simulator.
- Or drag/tap the floating button. `start(triggers: [.shake])` turns the button off.
- `StoreScope.present()` opens it from code (e.g. a hidden debug menu item).

One container → opens straight to its entities. Several → a container picker first.

### Example 1: one data model (single container)

A typical app with one `.xcdatamodeld` and one `NSPersistentContainer`.

```swift
import CoreData
import StoreScope
import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The app's only Core Data stack.
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Shop")   // Shop.xcdatamodeld
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data store failed to load: \(error)") }
        }
        return container
    }()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register after the store has loaded, then start the triggers.
        StoreScope.register(persistentContainer, name: "Shop")
        StoreScope.start()
        return true
    }
}
```

SwiftUI app? Keep your `@main App` and attach the same delegate:

```swift
@main
struct ShopApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
```

### Example 2: multiple framework models (one container per module)

A modular app where each feature framework ships its own model and store, for example `CartKit`, `CatalogKit`, `OrdersKit` and `WishlistKit`.

Each module owns its stack and knows nothing about the inspector:

```swift
// CartKit/Sources/CartKit/CartStore.swift
import CoreData

public enum CartStore {

    /// CartKit's own stack. The model is loaded from this module's bundle,
    /// not the app bundle, which is why each module needs its own container.
    public static let container: NSPersistentContainer = {
        guard
            let modelURL = Bundle.module.url(forResource: "Cart", withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Cart.momd is missing from the CartKit bundle")
        }
        let container = NSPersistentContainer(name: "Cart", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error { fatalError("Cart store failed to load: \(error)") }
        }
        return container
    }()
}
```

The app (the only place that links `StoreScope`) registers every module's container once at launch:

```swift
// App target
import CartKit
import CatalogKit
import StoreScope
import OrdersKit
import UIKit
import WishlistKit

final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        StoreScope.register(CartStore.container,     name: "Cart")
        StoreScope.register(CatalogStore.container,  name: "Catalog")
        StoreScope.register(OrdersStore.container,   name: "Orders")
        StoreScope.register(WishlistStore.container, name: "Wishlist")
        StoreScope.start()
        return true
    }
}
```

The inspector then opens on a **Containers** list (Cart, Catalog, Orders, Wishlist); pick one to browse its entities.

Good to know for modular apps:

- Names are the identity: registering the same name again replaces the earlier entry, so re-registering after a logout that rebuilds a store is safe.
- Containers are held weakly. A module that tears its stack down simply shows an error row instead of crashing.
- Only the app target needs the dependency; feature modules stay free of debug tooling.
- A module that creates its container lazily (say, after login) can be registered at that point instead of at launch.

### Other options

```swift
StoreScope.start(triggers: [.floatingButton])   // no shake (app already uses it)
StoreScope.start(triggers: [.shake])            // no button (clean screenshots)
StoreScope.register(container, name: "Catalog", showsRelationships: false)
StoreScope.present()                            // open from your own debug menu
StoreScope.stop()                               // remove triggers and the button
```

## What you get

Containers → entities with live row counts → paged records (50 at a time) → full field list.
Search runs in SQLite across all string attributes (case/diacritic-insensitive). Tap a field to copy it, **Copy all** copies the record. NULL is shown distinctly from an empty string. Relationships show as `Entity pNN` / `N objects`.

## Notes and limits

- Row order: by default rows come back in the store's natural order, which Core Data does not guarantee. Pass `RecordQuery(sortKey:sortAscending:)` through a data source for a deterministic order (cost: a sort per page on unindexed columns). Paging uses the offset the source reports, so a changing store can still repeat or skip rows, but never loops.
- Relationship counts use object IDs only; related objects are never loaded.
- Dates show the stored UTC value, with local time as a caption in the detail view.
- Reads through its own background context: it never touches your `viewContext`. It shows **saved** data only (what is on disk), not unsaved changes in another context.
- Containers are held weakly; a released container shows an error instead of crashing.
- Rows are in the store's natural order. Writing to the store while paging can shift rows (duplicates are filtered out).
- Search covers string attributes only; numeric/date search is not supported yet.
- Read-only by design.
- Shake detection hooks `UIWindow.motionEnded` (the FLEX technique), DEBUG only. If your app already handles shake, use `start(triggers: [.floatingButton])`.
- The floating button lives in its own window above the app (`alert + 1`), so it appears in screenshots and screen recordings of debug builds.
- Register containers **after** their persistent stores have loaded.

## Layout (why three targets)

| Target | Platform | Role |
|---|---|---|
| `StoreScopeCore` | iOS + macOS | models, `InspectorDataSource`, `CoreDataSource`, registry |
| `StoreScopeUI` | iOS + macOS | SwiftUI screens that only know `InspectorDataSource` |
| `StoreScope` | iOS, DEBUG | triggers + presentation |

**macOS next step:** the Mac app adds an `SQLiteDataSource: InspectorDataSource` (raw SQLite3, reading Core Data's `Z…` tables and mapping them back to entity/attribute names) plus Simulator file discovery and file watching, then hosts `InspectorRootView` unchanged.

## Tests

`swift test` (macOS). Core tests use a real SQLite store in a temp directory (pagination termination, sorting, search, NULL vs empty, relationships, abstract/sub-entities, container lifetime, registry). UI tests drive `RecordListModel` with a fake source (debounce, cancellation, stale responses, offsets, duplicates, errors).

These are not written yet — see the status note at the top of this file.
