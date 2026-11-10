import Foundation
import CoreGraphics
import ImageIO
@main struct Check {
 static func main() throws {
  let colors: [[UInt8]] = [[220,20,30],[20,220,30],[20,30,220],[150,80,30],[30,150,80],[80,30,150],[90,90,90],[250,250,250],[10,10,10]]
  var pixels: [UInt8] = []
  for y in 0..<160 { for x in 0..<160 {
   let index = min(y / 53,2) * 3 + min(x / 53,2)
   pixels += colors[index] + [255]
  }}
  let data = Data(pixels)
  let provider = CGDataProvider(data: data as CFData)!
  let image = CGImage(width:160,height:160,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:640,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
  let encoded = NSMutableData()
  let dest = CGImageDestinationCreateWithData(encoded,"public.png" as CFString,1,nil)!
  CGImageDestinationAddImage(dest,image,nil); precondition(CGImageDestinationFinalize(dest))
  let palette = DesktopAndroidFlowPalette.decode(encoded as Data)!
  precondition(palette.values.count == 30)
  for i in 0..<9 {
   let rgb = colors[i].map { Float($0) / 255 }
   let low = rgb.min()!, high = rgb.max()!, l = (low+high)/2
   let sat = high == low ? 0 : (high-low)/(1-abs(2*l-1))
   for c in 0..<3 {
    let expected = sat < 0.08 ? rgb[c] : (min(max(l+(rgb[c]-l)*min(sat*1.2,1)/sat,0),1)*255).rounded()/255
    precondition(abs(palette.values[i*3+c]-expected)<0.005,"Grid/color mismatch at \(i), \(c)")
   }
  }
  print("PASS: 160x160 row-major nine-cell sampling, saturation and neutral-color preservation")
 }
}
