import SwiftUI
import Kingfisher

// Downsampling — декодируем картинку сразу в нужный размер.
// Без этого Kingfisher держит в памяти и декодирует JPEG в исходном (часто 1500×1500),
// а потом SwiftUI ресайзит при каждой отрисовке. На длинных списках это даёт фризы.
//
// Вызов: KFImage(url).downsampled(to: CGSize(width: 200, height: 200))
// Размер задаём в point'ах — внутри умножается на screen scale.

extension KFImage {
    func downsampled(to size: CGSize) -> KFImage {
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        return self
            .setProcessor(DownsamplingImageProcessor(size: pixelSize))
            .scaleFactor(scale)
            .cacheOriginalImage()
            // НЕ используем loadDiskFileSynchronously() — на длинных списках
            // он блокирует main thread на каждой картинке и убивает скролл.
            // Для иконок-логотипов, которые попадают в memoryCache после первого
            // показа, это значимая разница: память моментально + диск асинхронно.
    }
}
