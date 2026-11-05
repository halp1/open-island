import Foundation
import Testing
@testable import OpenIslandApp
import OpenIslandCore

@MainActor
struct DSHRootVisibilityTests {
    @Test(arguments: [false, true])
    func independentRootsInOneWorkspaceKeepSeparateRows(hasFocusRelay: Bool) {
        let now = Date.now
        let ids = [
            "session-01f1ca26-4f96-41b3-b06d-82300cc04fee",
            "session-1d19c9ee-286b-4c51-b931-6604c0def37a",
        ]
        let roots = ids.map { id in
            let hook = DSHHookPayload(
                hookEventName: .sessionStart, sessionID: id, cwd: "/tmp/dsh",
                webOrigin: hasFocusRelay ? "http://127.0.0.1:3080/" : nil,
                webFocusSocket: hasFocusRelay ? "/tmp/oi-dsh-focus-test/focus.sock" : nil
            )
            var session = AgentSession(
                id: id, title: "DSH", tool: .dsh, origin: .live,
                attachmentState: .attached, phase: .running, summary: "Working",
                updatedAt: now, jumpTarget: hook.defaultJumpTarget,
                piMetadata: hook.defaultPiMetadata
            )
            session.isHookManaged = true
            session.isProcessAlive = true
            session.lastHeartbeatAt = now
            return session
        }
        let model = AppModel()
        model.state = SessionState(sessions: roots)
        #expect(Set(model.surfacedSessions.map(\.id)) == Set(ids))
        #expect(model.recentSessions.isEmpty)
        #expect(model.liveSessionCount == 2)
        #expect(model.liveRunningCount == 2)

        model.state.apply(.sessionCompleted(SessionCompleted(
            sessionID: ids[0], summary: "Finished", timestamp: now.addingTimeInterval(1)
        )))
        #expect(Set(model.surfacedSessions.map(\.id)) == Set(ids))
        #expect(model.liveRunningCount == 1)
        #expect(model.state.session(id: ids[1])?.phase == .running)
    }

    @Test
    func cachedUnknownAndChildSessionsCannotBecomeRowsCardsOrSelection() async throws {
        let now = Date.now
        var root = AgentSession(id: "root", title: "DSH", tool: .dsh, origin: .live, attachmentState: .attached, phase: .running, summary: "Working", updatedAt: now, piMetadata: PiSessionMetadata(isSubagent: false, parentSessionID: "fork-parent"))
        root.isHookManaged = true
        root.isProcessAlive = true
        root.lastHeartbeatAt = now
        let child = AgentSession(id: "child", title: "DSH", tool: .dsh, origin: .live, phase: .waitingForAnswer, summary: "Hidden question", updatedAt: now, questionPrompt: QuestionPrompt(title: "Hidden", options: ["A"]), piMetadata: PiSessionMetadata(isSubagent: true, parentSessionID: "root"))
        let unknown = AgentSession(id: "old-unknown", title: "DSH", tool: .dsh, origin: .live, phase: .completed, summary: "Old registry entry", updatedAt: now)
        let model = AppModel()
        model.state = SessionState(sessions: [root, child, unknown])
        model.selectedSessionID = child.id
        model.islandSurface = .sessionList(actionableSessionID: child.id)
        #expect(model.allSessions.map(\.id) == [root.id])
        #expect(model.surfacedSessions.map(\.id) == [root.id])
        #expect(model.recentSessions.isEmpty)
        #expect(model.activeIslandCardSession == nil)
        #expect(model.focusedSession?.id == root.id)
        #expect(model.liveSessionCount == 1)
        #expect(model.liveAttentionCount == 0)
        #expect(model.state.liveAttentionCount == 0)
        let quiet = AppModel(isNotificationSessionAlreadyFrontmost: { _ in false })
        quiet.state = SessionState(sessions: [unknown])
        quiet.applyTrackedEvent(.questionAsked(QuestionAsked(sessionID: unknown.id, prompt: QuestionPrompt(title: "Unconfirmed", options: ["A"]), timestamp: now)))
        try await Task.sleep(for: .milliseconds(100))
        #expect(quiet.notchStatus == .closed)
        #expect(quiet.activeIslandCardSession == nil)
        #expect(quiet.allSessions.isEmpty)
        model.applyTrackedEvent(.piSessionMetadataUpdated(PiSessionMetadataUpdated(sessionID: child.id, piMetadata: PiSessionMetadata(isSubagent: true), timestamp: now)))
        #expect(model.state.session(id: child.id) == nil)
        #expect(model.selectedSessionID == root.id)
        var staleRoot = child
        staleRoot.piMetadata = PiSessionMetadata(isSubagent: false)
        model.acceptCoordinatorState(SessionState(sessions: [root, staleRoot, unknown]))
        #expect(model.state.session(id: child.id) == nil)
        model.state.apply(.sessionStarted(SessionStarted(sessionID: child.id, title: "DSH", tool: .dsh, summary: "Stale", timestamp: now, piMetadata: PiSessionMetadata(isSubagent: false))))
        #expect(model.state.session(id: child.id) == nil)
        let recovered = SessionStarted(sessionID: unknown.id, title: "DSH", tool: .dsh, summary: "Recovered", timestamp: now, piMetadata: PiSessionMetadata(isSubagent: false, parentSessionID: root.id))
        model.state.apply(.sessionHeartbeat(SessionHeartbeat(sessionID: unknown.id, timestamp: now, recoverySession: recovered)))
        #expect(Set(model.allSessions.map(\.id)) == [root.id, unknown.id])
        #expect(model.state.session(id: unknown.id)?.piMetadata?.isSubagent == false)
    }
}
