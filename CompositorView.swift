import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct CompositorView: View {
    @State private var inputImage: NSImage?
    @State private var processedImage: NSImage?
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 1.0
    @State private var saturation: Double = 1.0
    
    var body: some View {
        HSplitView {
            // Левая панель с контролами
            VStack(alignment: .leading, spacing: 20) {
                Text("Image Controls")
                    .font(.headline)
                
                Button("Load Image") {
                    loadImage()
                }
                .buttonStyle(.borderedProminent)
                
                if inputImage != nil {
                    Group {
                        VStack(alignment: .leading) {
                            Text("Brightness: \(brightness, specifier: "%.2f")")
                            Slider(value: $brightness, in: -1...1)
                                .onChange(of: brightness) { _ in
                                    processImage()
                                }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Contrast: \(contrast, specifier: "%.2f")")
                            Slider(value: $contrast, in: 0...2)
                                .onChange(of: contrast) { _ in
                                    processImage()
                                }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Saturation: \(saturation, specifier: "%.2f")")
                            Slider(value: $saturation, in: 0...2)
                                .onChange(of: saturation) { _ in
                                    processImage()
                                }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(width: 250)
            
            // Правая панель с изображением
            VStack {
                if let image = processedImage ?? inputImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text("No image loaded")
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(minWidth: 400, minHeight: 300)
        }
        .navigationTitle("Compositor App")
    }
    
    private func loadImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            if let url = panel.url,
               let image = NSImage(contentsOf: url) {
                inputImage = image
                processImage()
            }
        }
    }
    
    private func processImage() {
        guard let inputImage = inputImage else { return }
        
        // Конвертируем NSImage в CIImage
        guard let ciImage = CIImage(data: inputImage.tiffRepresentation!) else { return }
        
        // Применяем фильтры
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.brightness = Float(brightness)
        filter.contrast = Float(contrast)
        filter.saturation = Float(saturation)
        
        // Получаем результат
        guard let outputImage = filter.outputImage else { return }
        
        // Конвертируем обратно в NSImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        processedImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}