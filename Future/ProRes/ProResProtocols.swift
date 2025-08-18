import Foundation
import CoreImage

// MARK: - ProRes Processing Protocol
/// Протокол для обработки ProRes файлов
public protocol ProResProcessing {
    /// Варианты ProRes
    associatedtype ProResVariant: CaseIterable, RawRepresentable where ProResVariant.RawValue == String
    
    /// Декодирует ProRes файл и возвращает массив кадров
    func decodeProRes(from url: URL) async throws -> [CIImage]
    
    /// Кодирует массив кадров в ProRes формат
    func encodeProRes(_ images: [CIImage], to url: URL, variant: ProResVariant) async throws
    
    /// Конвертирует ProRes файл в другой вариант
    func convertProRes(from sourceURL: URL, to destinationURL: URL, targetVariant: ProResVariant) async throws
    
    /// Проверяет поддержку варианта ProRes
    func isVariantSupported(_ variant: ProResVariant) -> Bool
    
    /// Возвращает информацию о состоянии процессора
    func getProResInfo() -> String
}

// MARK: - ProRes Variant Enum
/// Варианты ProRes для использования в Domain слое
public enum ProResVariant: String, CaseIterable {
    case proRes4444 = "ProRes 4444"
    case proRes422HQ = "ProRes 422 HQ"
    case proRes422 = "ProRes 422"
    case proRes422LT = "ProRes 422 LT"
    case proRes422Proxy = "ProRes 422 Proxy"
    
    public var description: String {
        switch self {
        case .proRes4444: return "Highest quality, 4:4:4 chroma, 12-bit, alpha channel"
        case .proRes422HQ: return "High quality, 4:2:2 chroma, 10-bit, broadcast standard"
        case .proRes422: return "Standard quality, 4:2:2 chroma, 10-bit, balanced"
        case .proRes422LT: return "Lightweight, 4:2:2 chroma, 10-bit, efficient"
        case .proRes422Proxy: return "Proxy quality, 4:2:2 chroma, 10-bit, fast editing"
        }
    }
}
