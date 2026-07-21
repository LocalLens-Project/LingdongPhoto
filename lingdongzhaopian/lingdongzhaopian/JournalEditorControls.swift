// SPDX-FileCopyrightText: 2026 LocalLens-Project
// SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI
import UIKit

struct JournalEditorControls: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int?
    @Binding var layout: JournalLayoutMode
    let onReplace: (Int) -> Void
    let onDelete: (Int) -> Void
    let onMove: (Int, Int) -> Void
    let onReset: (Int) -> Void

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                Label("单图构图", systemImage: "crop")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("拼图模板", selection: $layout) {
                    ForEach(JournalLayoutMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(.primary)
            }

            HStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            Image(uiImage: images[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(selectedIndex == index ? .white : .white.opacity(0.24), lineWidth: selectedIndex == index ? 2.5 : 1)
                                }
                                .shadow(color: .black.opacity(selectedIndex == index ? 0.22 : 0.08), radius: 5, y: 3)
                                .scaleEffect(selectedIndex == index ? 1 : 0.94)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedIndex = index
                                    UISelectionFeedbackGenerator().selectionChanged()
                                }
                                .draggable(String(index))
                                .dropDestination(for: String.self) { values, _ in
                                    guard let value = values.first,
                                          let source = Int(value),
                                          source != index else { return false }
                                    onMove(source, index)
                                    return true
                                }
                                .accessibilityLabel("第 \(index + 1) 张照片")
                                .accessibilityAddTraits(selectedIndex == index ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 3)
                }

                if let selectedIndex, images.indices.contains(selectedIndex) {
                    Menu {
                        Button {
                            onReplace(selectedIndex)
                        } label: {
                            Label("替换这张", systemImage: "arrow.triangle.2.circlepath")
                        }
                        Button {
                            onReset(selectedIndex)
                        } label: {
                            Label("恢复构图", systemImage: "arrow.counterclockwise")
                        }
                        if images.count > 1 {
                            Button(role: .destructive) {
                                onDelete(selectedIndex)
                            } label: {
                                Label("删除这张", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(LiquidPressButtonStyle())
                    .liquidGlass(in: Circle(), interactive: true, variant: .clear)
                }
            }

            Text("点击选择后在画布上拖动或双指缩放；长按缩略图可拖拽排序")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), variant: .clear)
    }
}
