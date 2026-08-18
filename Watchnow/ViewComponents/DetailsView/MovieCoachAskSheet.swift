//
//  MovieCoachAskSheet.swift
//  Watchnow
//
//  The optional half of Movie Coach. Deliberately *not* a chat screen:
//  a short list of tap-to-ask questions tailored to the title, and one
//  answer at a time. The user never has to type to get value.
//

import SwiftUI

struct MovieCoachAskSheet: View {

    let context: MovieCoachContext

    @Environment(\.dismiss) private var dismiss

    @State private var asked: String?
    @State private var answer: String?
    @State private var isGenerating = false
    @State private var didFail = false

    private var questions: [String] { MovieCoachService.suggestedQuestions(for: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(context.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    if let asked {
                        answerCard(for: asked)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(asked == nil ? "What do you want to know?" : "Ask something else")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(questions.filter { $0 != asked }, id: \.self) { question in
                            Button { ask(question) } label: {
                                HStack(spacing: 10) {
                                    Text(question)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isGenerating)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.background))
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .modifier(SoftScrollEdgeEffectStyleModifier())
    }

    // MARK: - Answer

    @ViewBuilder
    private func answerCard(for question: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.accentColor)

            if isGenerating {
                Text("Thinking that through for you right now.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .redacted(reason: .placeholder)
            } else if didFail {
                HStack(spacing: 10) {
                    Text("Couldn't answer that one.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Retry") { ask(question) }
                        .font(.system(size: 13, weight: .semibold))
                        .buttonStyle(.plain)
                }
            } else if let answer {
                Text(answer)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        }
    }

    private func ask(_ question: String) {
        asked = question
        answer = nil
        didFail = false
        isGenerating = true

        Task {
            defer { isGenerating = false }
            do {
                answer = try await MovieCoachService.answer(question: question, context: context)
            } catch {
                didFail = true
            }
        }
    }
}
