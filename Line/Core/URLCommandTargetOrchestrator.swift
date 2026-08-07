//
//  URLCommandTargetOrchestrator.swift
//  Line
//
//  Target selection and execution lifecycle for one-shot URL automation commands.
//

import Foundation

@MainActor
final class URLCommandTargetOrchestrator<Target: AnyObject, Screen> {
    struct Dependencies {
        let candidates: @MainActor () -> [Target]
        let userDefinedTarget: @MainActor () -> Target?
        let isEligible: @MainActor (Target) -> Bool
        let screen: @MainActor (Target) -> Screen?
        let mainScreen: @MainActor () -> Screen?
        let activate: @MainActor (Target) -> ()
        let destinationScreen: @MainActor (WindowAction.ScreenSwitchAction, Screen) -> Screen?
        let preservingFrameAction: @MainActor (Target, Screen) -> WindowAction
        let apply: @MainActor (WindowAction, Target, Screen) async throws -> Bool
        let activationDelay: @MainActor () async throws -> ()
        let now: @MainActor () -> Date
    }

    enum Request {
        case action(WindowAction)
        case screenSwitch(WindowAction.ScreenSwitchAction)
    }

    enum Result: Equatable {
        case applied
        case noTarget
        case noScreen
        case noDestinationScreen
        case cancelled
        case failed
    }

    private let dependencies: Dependencies
    private var stickyTarget: Target?
    private var stickyTime: Date?
    private var nextRequestSequence: UInt = 0
    private var stickyRequestSequence: UInt = 0

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(_ request: Request) async -> Result {
        nextRequestSequence &+= 1
        let requestSequence = nextRequestSequence

        guard let target = URLTargetWindowPolicy.resolve(
            candidates: dependencies.candidates(),
            userDefined: dependencies.userDefinedTarget(),
            stickyWindow: stickyTarget,
            stickyTime: stickyTime,
            now: dependencies.now(),
            isEligible: dependencies.isEligible
        ) else {
            return .noTarget
        }

        let action: WindowAction
        let destination: Screen
        switch request {
        case let .action(requestedAction):
            guard let targetScreen = TargetScreenResolutionPolicy.choose(
                targetWindowScreen: dependencies.screen(target),
                mainScreen: dependencies.mainScreen()
            ) else {
                return .noScreen
            }
            dependencies.activate(target)
            do {
                try await dependencies.activationDelay()
            } catch is CancellationError {
                return .cancelled
            } catch {
                return .failed
            }
            action = requestedAction
            destination = targetScreen

        case let .screenSwitch(screenAction):
            guard let currentScreen = dependencies.screen(target) else {
                return .noScreen
            }
            guard let targetScreen = dependencies.destinationScreen(screenAction, currentScreen) else {
                return .noDestinationScreen
            }
            action = dependencies.preservingFrameAction(target, currentScreen)
            destination = targetScreen
        }

        do {
            guard try await dependencies.apply(action, target, destination) else {
                return .failed
            }
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed
        }

        if requestSequence >= stickyRequestSequence {
            stickyTarget = target
            stickyTime = dependencies.now()
            stickyRequestSequence = requestSequence
        }
        return .applied
    }
}
