import Foundation

/// What the global "approve" shortcut acts on. Only requests that carry an
/// explicit approve affordance qualify: tool permissions and privilege
/// escalation (permission requests) and plan reviews (question prompts whose
/// every item names an approve option). Plain questions never qualify.
public enum ApprovalShortcutTarget: Equatable, Sendable {
    case permission(sessionID: String, requestID: UUID)
    case approvalPrompt(sessionID: String, requestID: UUID, response: QuestionPromptResponse)
}

extension QuestionPrompt {
    /// The answer that approves this prompt, or nil when it is an ordinary question.
    public var approvalResponse: QuestionPromptResponse? {
        guard !questions.isEmpty else { return nil }
        var structured: [String: StructuredQuestionAnswer] = [:]
        var previews: [String: String] = [:]
        for item in questions {
            guard let label = item.approveOption,
                  item.options.contains(where: { $0.label == label && !$0.allowsFreeform }),
                  structured[item.responseKey] == nil else { return nil }
            structured[item.responseKey] = StructuredQuestionAnswer(selectedOptions: [label])
            previews[item.responseKey] = label
        }
        return QuestionPromptResponse(
            rawAnswer: questions.count == 1 ? questions[0].approveOption : nil,
            answers: previews,
            structuredAnswers: structured
        )
    }
}

extension SessionState {
    /// The most recently updated pending approval among sessions shown in the island.
    public var mostRecentApprovalTarget: ApprovalShortcutTarget? {
        for session in sessions where session.isVisibleInIsland {
            switch session.phase {
            case .waitingForApproval:
                if let request = session.permissionRequest, !request.requiresTerminalApproval {
                    return .permission(sessionID: session.id, requestID: request.id)
                }
            case .waitingForAnswer:
                if let prompt = session.questionPrompt, let response = prompt.approvalResponse {
                    return .approvalPrompt(sessionID: session.id, requestID: prompt.id, response: response)
                }
            case .running, .completed:
                break
            }
        }
        return nil
    }
}
