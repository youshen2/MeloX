"""Compile production trajectories and compare GPU field against Android math."""
from pathlib import Path
import json, math, subprocess, tempfile, unittest
ROOT = Path(__file__).resolve().parents[2]
# Keep inspectable artifacts outside the checkout; no recursive deletion.
ARTIFACTS = Path(tempfile.gettempdir()) / "melox-tests.noindex"
ARTIFACTS.mkdir(parents=True, exist_ok=True)
BG = ROOT / 'MeloXDesktop/Features/Player/Background'
class AndroidFlowParity(unittest.TestCase):
 def test_palette(self):
  scratch = Path(tempfile.mkdtemp(prefix='android-palette-', dir=ARTIFACTS))
  subprocess.run(['swiftc','-parse-as-library',str(BG/'DesktopAndroidFlowPalette.swift'),str(ROOT/'MeloXDesktop/Core/Artwork/ArtworkDataLoader.swift'),str(ROOT/'Tools/Tests/AndroidFlowPaletteChecks.swift'),'-o',str(scratch/'check')],check=True)
  subprocess.run([str(scratch/'check')],check=True)
 def test_motion_clock_and_gpu(self):
  scratch = Path(tempfile.mkdtemp(prefix='android-parity-', dir=ARTIFACTS))
  shader = (BG/'DesktopBlurredArtworkFlow.metal').read_text().replace('[[ stitchable ]]', 'inline') + '''
kernel void check(device float4 *out [[buffer(0)]], device const float *values [[buffer(1)]], uint i [[thread_position_in_grid]]) {
 float2 p(float(i % 7) / 6 * 800, float(i / 7) / 4 * 600);
 out[i] = float4(desktopBlurredArtworkFlow(p, half4(1), float2(800,600), 2.3, values, 48, 1, .45));
}
'''
  (scratch/'test.metal').write_text(shader)
  harness = r'''
import Foundation
import Metal
@main struct Check {
 static func main() throws {
  precondition(AppSettings.playerBackgroundMotionRange(for: .blurredArtwork).lowerBound == 0)
  precondition(AppSettings.playerBackgroundMotionRange(for: .blurredArtwork).upperBound == 1.4)
  precondition(AppSettings.playerBackgroundMotionRange(for: .flowingLight).lowerBound == 0.4)
  precondition(AppSettings.playerBackgroundMotionRange(for: .appleMusicBackdrop).lowerBound == 0.4)
  let motion = DesktopBlurredArtworkMotion()
  precondition(abs(motion.speed(for: 1) - 1.92) < 0.00001)
  precondition(abs(motion.speed(for: 1.4) - 3.84) < 0.00001)
  precondition(motion.speed(for: 0) == 0)
  for t in stride(from: 0.0, through: 30, by: 0.3) {
   let a = motion.centers(at: t), b = motion.centers(at: t + 8 * .pi)
   precondition(zip(a,b).allSatisfy { abs($0-$1) < 0.00001 })
  }
  var clock = DesktopBlurredArtworkClock()
  let date = Date(timeIntervalSince1970: 100)
  clock.setRate(2, at: date)
  clock.setRate(0, at: date.addingTimeInterval(3))
  precondition(clock.elapsed(at: date.addingTimeInterval(30)) == 6)
  clock.setRate(4, at: date.addingTimeInterval(30))
  precondition(clock.elapsed(at: date.addingTimeInterval(32)) == 14)
  guard let device = MTLCreateSystemDefaultDevice() else {
   print("SKIP_NO_METAL")
   return
  }
  let lib = try device.makeLibrary(source: String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8), options: nil)
  let pipe = try device.makeComputePipelineState(function: lib.makeFunction(name: "check")!)
  var values = (0..<30).map { Float(($0 * 37 + 11) % 255) / 255 } + motion.centers(at: 2.3)
  let input = device.makeBuffer(bytes: &values, length: values.count * 4)!
  let output = device.makeBuffer(length: 35 * 16)!
  let command = device.makeCommandQueue()!.makeCommandBuffer()!
  let encoder = command.makeComputeCommandEncoder()!
  encoder.setComputePipelineState(pipe)
  encoder.setBuffer(output, offset: 0, index: 0)
  encoder.setBuffer(input, offset: 0, index: 1)
  encoder.dispatchThreads(MTLSize(width: 35,height: 1,depth: 1), threadsPerThreadgroup: MTLSize(width: 1,height: 1,depth: 1))
  encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
  if let error = command.error { throw error }
  let pointer = output.contents().bindMemory(to: Float.self, capacity: 140)
  print(String(data: try JSONSerialization.data(withJSONObject: Array(UnsafeBufferPointer(start: pointer,count: 140))), encoding: .utf8)!)
 }
}
'''
  settings = (ROOT/'MeloXDesktop/Core/Settings/Application/AppSettings.swift').read_text()
  start = settings.index('    static func playerBackgroundMotionRange(')
  opening = settings.index('{', start)
  depth, end = 1, opening + 1
  while depth:
   depth += (settings[end] == '{') - (settings[end] == '}')
   end += 1
  policy = 'enum PlayerBackgroundStyle { case blurredArtwork, flowingLight, appleMusicBackdrop }\nstruct AppSettings {\n static let playerBackgroundMotionIntensityRange = 0.4...1.4\n' + settings[start:end] + '\n}\n'
  (scratch/'main.swift').write_text(policy + harness)
  subprocess.run(['swiftc','-parse-as-library',str(BG/'DesktopBlurredArtworkMotion.swift'),str(scratch/'main.swift'),'-o',str(scratch/'check')],check=True)
  output = subprocess.check_output([str(scratch/'check'),str(scratch/'test.metal')],text=True).strip()
  if output == 'SKIP_NO_METAL': self.skipTest('Metal device is unavailable on this Mac')
  actual=json.loads(output)
  colors=[((i*37+11)%255)/255 for i in range(30)]
  fx=[.5,.25,.75,.5,.25,.75,.5,.25,.75];fy=[.25,.75,.5,.75,.5,.25,.5,.25,.75]
  worst=0
  for k in range(35):
   u=(k%7)/6;v=(k//7)/4;t=2.3
   su=u+.15*(math.sin(v*3.1+t)*math.cos(u*2.3-t*.75)+.5*math.sin((u+v)*4.9-t*1.25))
   sv=v+.15*(math.cos(u*2.9-t)*math.sin(v*2.6+t*.5)+.5*math.cos((u-v)*5.4+t))
   su+=.15*.28*math.sin(sv*6.7-t*1.5)
   sv+=.15*.28*math.cos(su*7.1+t*1.5)
   total=.16;rgb=[colors[27+c]*total for c in range(3)]
   for i in range(9):
    dx=(su-(.5+.3*math.sin(t*fx[i]+i*1.7)))*(48/110)/.45
    dy=(sv-(.5+.3*math.cos(t*fy[i]+i*.9)))/.45
    weight=(1/(1+(dx*dx+dy*dy)*4.5))**2
    total+=weight
    for c in range(3):rgb[c]+=colors[i*3+c]*weight
   for c in range(3):worst=max(worst,abs(rgb[c]/total-actual[k*4+c]))
  self.assertLess(worst, 1/255)
  print(f'GPU vs Android reference: 35 samples, max channel error {worst:.6f}; clock and 8π trajectories passed')
if __name__=='__main__':unittest.main()
