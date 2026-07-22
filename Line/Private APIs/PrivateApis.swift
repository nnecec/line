//
//  PrivateApis.swift
//  Line
//
//  Created by nnecec on 2025-11-27.
//
// Optional loaders for non-SkyLight private symbols that used to be hard-bound
// with `@_silgen_name`. Resolving via `dlsym(RTLD_DEFAULT, …)` keeps the app
// loadable when a symbol is missing; call sites must treat the optional as nil
// and degrade gracefully (see SkyLightSymbolLoader for the SkyLight set).

import ApplicationServices
import Darwin
import Scribe

/// Runtime-resolved private process/window symbols (ApplicationServices / HIServices).
@Loggable(style: .static)
enum PrivateSymbolLoader {
    /// Darwin `RTLD_DEFAULT` is not imported into Swift; macOS defines it as `((void *) -2)`.
    private static let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)

    private static func loadSymbol<T>(_ name: StaticString) -> T? {
        // Clear any prior error
        dlerror()

        guard let defaultHandle = rtldDefault,
              let sym = dlsym(defaultHandle, name.description)
        else {
            log.error("failed to load symbol \(name)")
            return nil
        }

        return unsafeBitCast(sym, to: T.self)
    }

    /// Carbon/HIServices process serial number lookup for a pid.
    typealias GetProcessForPIDFunc = @convention(c) (
        _ pid: pid_t,
        _ psn: UnsafeMutablePointer<ProcessSerialNumber>
    ) -> OSStatus
    static let GetProcessForPID: GetProcessForPIDFunc? = loadSymbol("GetProcessForPID")

    /// Maps an AXUIElement window to its CGWindowID (`_AXUIElementGetWindow`).
    typealias AXUIElementGetWindowFunc = @convention(c) (
        _ axUiElement: AXUIElement,
        _ wid: UnsafeMutablePointer<CGWindowID>
    ) -> AXError
    static let AXUIElementGetWindow: AXUIElementGetWindowFunc? = loadSymbol("_AXUIElementGetWindow")
}
