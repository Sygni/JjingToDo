//
//  AddBookView.swift
//  JjingToDo
//

import SwiftUI
import CoreData

struct AddBookView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var vm: BookSearchViewModel
    @State private var showScanner = false
    @State private var navPath: [SearchBook] = []
    @State private var showManualSheet = false
    @State private var toast: String?

    init(context: NSManagedObjectContext) {
        _vm = StateObject(wrappedValue: BookSearchViewModel(context: context))
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 12) {
                HStack {
                    TextField("책 제목/저자/ISBN 검색", text: $vm.query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    if vm.isLoading { ProgressView() }
                    Button(action: { showScanner = true }) {
                        Image(systemName: "barcode.viewfinder").imageScale(.large)
                    }
                }
                .padding(.horizontal)

                if let err = vm.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                List(vm.results) { item in
                    NavigationLink {
                        ConfirmBookView(vm: vm, candidate: item)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: item.coverURL) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default: Color.gray.opacity(0.2)
                                }
                            }
                            .frame(width: 44, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.headline).lineLimit(2)
                                if !item.authors.isEmpty {
                                    Text(item.authors.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary)
                                }
                                HStack(spacing: 8) {
                                    if let p = item.pageCount { Text("\(p) pages") }
                                    if let lang = item.languageCode?.uppercased() {
                                        Text(lang).font(.caption)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(.thinMaterial)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }.foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showManualSheet = true } label: {
                            Label("수동 등록", systemImage: "plus.app")
                        }
                    }
                }
                .sheet(isPresented: $showManualSheet) {
                    AddBookManualView(vm: vm)
                }
            }
            .overlay(alignment: .bottom) {
                if let t = toast {
                    Text(t)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("책 검색")
            .navigationDestination(for: SearchBook.self) { b in
                ConfirmBookView(vm: vm, candidate: b)
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView { code in
                showScanner = false
                _Concurrency.Task { @MainActor in
                    if let isbn = normalizeISBN(from: code) {
                        if let merged = await vm.resolveByISBN(isbn) {
                            navPath.append(merged)
                        } else {
                            await vm.performSearch("isbn:\(isbn)")
                            if let first = vm.results.first {
                                navPath.append(first)
                            } else {
                                toast = "검색 결과가 없어요"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast = nil }
                            }
                        }
                    } else {
                        toast = "이 바코드는 책이 아니거나 인식이 불완전해요"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast = nil }
                    }
                }
            }
        }
    }
}
