import Foundation
import Testing
@testable import OpenIslandCore

struct ApprovalShortcutTargetTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func session(
        _ id: String, age: TimeInterval, phase: SessionPhase,
        permission: PermissionRequest? = nil, prompt: QuestionPrompt? = nil
    ) -> AgentSession {
        var session = AgentSession(
            id: id, title: id, tool: .claudeCode, phase: phase, summary: "",
            updatedAt: now.addingTimeInterval(-age), permissionRequest: permission, questionPrompt: prompt
        )
        session.isHookManaged = true
        return session
    }

    private func planPrompt(approve: String = "Approve") -> QuestionPrompt {
        DSHInteraction(
            requestID: UUID().uuidString, kind: .plan, status: .pending,
            questions: [DSHInteractionQuestion(
                id: "plan-review", question: "Approve?",
                options: [DSHInteractionOption(label: "Approve"), DSHInteractionOption(label: "Keep planning")],
                intent: DSHInteractionIntent(kind: "plan-review", approve: approve)
            )]
        ).questionPrompt!
    }

    @Test
    func picksNewestApprovalAndSkipsPlainQuestions() throws {
        let olderPermission = PermissionRequest(title: "Allow Bash", summary: "", affectedPath: "")
        let plan = planPrompt()
        let question = QuestionPrompt(title: "Which?", options: ["A", "B"])

        // The newest request is a plain question, so the plan review wins.
        var state = SessionState(sessions: [
            session("question", age: 1, phase: .waitingForAnswer, prompt: question),
            session("plan", age: 5, phase: .waitingForAnswer, prompt: plan),
            session("permission", age: 10, phase: .waitingForApproval, permission: olderPermission),
            session("running", age: 0, phase: .running),
        ])
        guard case let .approvalPrompt(sessionID, requestID, response) = state.mostRecentApprovalTarget else {
            Issue.record("expected plan review target")
            return
        }
        #expect(sessionID == "plan")
        #expect(requestID == plan.id)
        #expect(response.structuredAnswers == ["plan-review": StructuredQuestionAnswer(selectedOptions: ["Approve"])])

        // With the plan gone, the older permission is next.
        state = SessionState(sessions: [
            session("question", age: 1, phase: .waitingForAnswer, prompt: question),
            session("permission", age: 10, phase: .waitingForApproval, permission: olderPermission),
        ])
        #expect(state.mostRecentApprovalTarget == .permission(sessionID: "permission", requestID: olderPermission.id))

        // Terminal-only approvals, plain questions, and intents naming a missing option yield nothing.
        let terminalOnly = PermissionRequest(title: "t", summary: "", affectedPath: "", requiresTerminalApproval: true)
        state = SessionState(sessions: [
            session("question", age: 1, phase: .waitingForAnswer, prompt: question),
            session("terminal", age: 2, phase: .waitingForApproval, permission: terminalOnly),
            session("badPlan", age: 3, phase: .waitingForAnswer, prompt: planPrompt(approve: "Ship it")),
        ])
        #expect(state.mostRecentApprovalTarget == nil)
    }
}
