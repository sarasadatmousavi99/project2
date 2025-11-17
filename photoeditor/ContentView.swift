//
//  ContentView.swift
//  photoeditor
//
//  Created by sara sadat mousavi on 12/11/25.
//
// ContentView.swift
// photoeditor

import SwiftUI
import PhotosUI

// MARK: - Canvas Templates

enum CanvasTemplate: String, CaseIterable, Identifiable {
    case instagramPostSquare
    case instagramPostPortrait
    case instagramStory
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .instagramPostSquare:   return "Post 1:1"
        case .instagramPostPortrait: return "Post 4:5"
        case .instagramStory:        return "Story 9:16"
        }
    }
    
    /// Aspect ratio as width : height
    var aspectRatio: CGSize {
        switch self {
        case .instagramPostSquare:   return CGSize(width: 1, height: 1)
        case .instagramPostPortrait: return CGSize(width: 4, height: 5)
        case .instagramStory:        return CGSize(width: 9, height: 16)
        }
    }
}

// MARK: - Editing Tool

enum EditingTool {
    case none
    case size
    case background
}

// MARK: - Main View

struct ContentView: View {
    
    @State private var selectedTemplate: CanvasTemplate = .instagramStory
    @State private var selectedUIImage: UIImage?
    @State private var selectedPhotosPickerItem: PhotosPickerItem?
    
    @State private var backgroundColor: Color = Color(red: 1.0, green: 0.85, blue: 0.93)
    
    @State private var activeTool: EditingTool = .none
    @State private var showOriginal: Bool = false
    
    @State private var showSaveConfirmation = false
    @State private var showSaveResult = false
    @State private var saveErrorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: Background gradient (white -> light pink)
                LinearGradient(
                    colors: [
                        .white,
                        Color(red: 1.0, green: 0.85, blue: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 16) {
                    
                    // PREVIEW
                    previewSection
                    
                    // PHOTO PICKER BUTTON
                    PhotosPicker(selection: $selectedPhotosPickerItem, matching: .images) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.35))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "photo")
                                    .font(.headline)
                                    .foregroundColor(.pink)
                            }
                            
                            Text(selectedUIImage == nil ? "Select Photo for Preview" : "Change Photo")
                                .font(.headline)
                                .foregroundColor(.pink)
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.4))
                                .shadow(radius: 4, y: 2)
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                        .frame(height: 80) // space for sliding sheet
                }
                
                // BOTTOM SLIDING SHEET
                bottomSheet
            }
            .navigationTitle("photo editor")
            .navigationBarTitleDisplayMode(.inline)
            
            // TOOLBARS
            .toolbar {
                // Top: before / after
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedUIImage != nil {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showOriginal.toggle()
                            }
                        } label: {
                            Image(
                                systemName: showOriginal
                                ? "arrow.uturn.backward.circle.fill"
                                : "arrow.uturn.forward.circle.fill"
                            )
                            .imageScale(.large)
                        }
                        .accessibilityLabel(showOriginal ? "Show After" : "Show Before")
                    }
                }
                
                // Bottom: tools
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { toggleTool(.size) } label: {
                        toolbarButton(
                            icon: "aspectratio",
                            title: "Size",
                            isActive: activeTool == .size
                        )
                    }
                    
                    Button { toggleTool(.background) } label: {
                        toolbarButton(
                            icon: "paintpalette",
                            title: "Background",
                            isActive: activeTool == .background
                        )
                    }
                    
                    Button {
                        if selectedUIImage != nil {
                            // Close any open sheet (Size/Background) before saving
                            activeTool = .none
                            showSaveConfirmation = true
                        }
                    } label: {
                        toolbarButton(
                            icon: "square.and.arrow.down",
                            title: "Save",
                            isActive: false
                        )
                    }
                    .disabled(selectedUIImage == nil)
                }
            }
            
            // Save confirmation alert
            .alert("Save changes?", isPresented: $showSaveConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Save", role: .destructive) {
                    saveCanvasToPhotos()
                }
            } message: {
                Text("Do you want to save this edited image to your Photos?")
            }
            
            // Save result alert
            .alert("Saved!", isPresented: $showSaveResult) {
                Button("OK") {}
            } message: {
                if let msg = saveErrorMessage {
                    Text(msg)
                } else {
                    Text("Your edited photo has been saved.")
                }
            }
            
            // iOS 17 style onChange (two parameters)
            .onChange(of: selectedPhotosPickerItem) { oldItem, newItem in
                Task { await loadImage(from: newItem) }
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack {
            if let image = selectedUIImage {
                CanvasPreview(
                    image: image,
                    template: selectedTemplate,
                    backgroundColor: backgroundColor,
                    showOriginal: showOriginal
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 8)
                .padding(.horizontal)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.white.opacity(0.4))
                    
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundColor(.pink)
                        
                        Text("Choose a photo to see the preview.")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 240)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Bottom Sheet
    
    private var bottomSheet: some View {
        VStack {
            Spacer()
            
            if activeTool != .none {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                    
                    switch activeTool {
                    case .size:
                        Picker("", selection: $selectedTemplate) {
                            ForEach(CanvasTemplate.allCases) { template in
                                Text(template.displayName).tag(template)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        
                    case .background:
                        ColorPicker("", selection: $backgroundColor, supportsOpacity: false)
                            .labelsHidden()
                            .scaleEffect(1.3)
                            .padding(.bottom, 16)
                        
                    case .none:
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.8))
                )
                .shadow(radius: 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeTool)
            }
        }
    }
    
    // MARK: - Toolbar Button
    // Icon + text INSIDE one rounded rectangle (toolbox)

    private func toolbarButton(icon: String, title: String, isActive: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(isActive ? Color.pink.opacity(0.25) : Color.white.opacity(0.7))
            
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.pink)
                    .font(.headline)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(isActive ? .pink : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .frame(height: 56)          // toolbox height
        .frame(maxWidth: .infinity) // makes the three buttons share the width nicely
    }
    
    // MARK: - Tool Toggle
    
    private func toggleTool(_ tool: EditingTool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if activeTool == tool {
                activeTool = .none
            } else {
                activeTool = tool
            }
        }
    }
    
    // MARK: - Image Loading
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run {
                    self.selectedUIImage = img
                    self.showOriginal = false
                }
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
    
    // MARK: - Saving
    
    private func saveCanvasToPhotos() {
        guard let uiImage = selectedUIImage else { return }
        
        let rendererView = CanvasPreview(
            image: uiImage,
            template: selectedTemplate,
            backgroundColor: backgroundColor,
            showOriginal: false
        )
        
        let renderer = ImageRenderer(content: rendererView)
        
        if let finalImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
            saveErrorMessage = nil
            showSaveResult = true
        } else {
            saveErrorMessage = "Could not render final image."
            showSaveResult = true
        }
    }
}

// MARK: - Canvas Preview View

struct CanvasPreview: View {
    let image: UIImage
    let template: CanvasTemplate
    let backgroundColor: Color
    let showOriginal: Bool
    
    var body: some View {
        Group {
            if showOriginal {
                ZStack {
                    Color.black.opacity(0.85)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            } else {
                ZStack {
                    backgroundColor
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
        }
        .aspectRatio(
            template.aspectRatio.width / template.aspectRatio.height,
            contentMode: .fit
        )
    }
}

// MARK: - Preview Provider

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
