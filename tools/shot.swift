import ScreenSaver
import AppKit

// Harness testowy: ładuje .saver i zapisuje jedną klatkę do PNG.
// Użycie: shot <bundle> <out.png> [mode theme imagePath]
let args = CommandLine.arguments
guard args.count >= 3, let bundle = Bundle(path: args[1]), bundle.load(),
      let cls = bundle.principalClass as? ScreenSaverView.Type else {
    print("load failed"); exit(1)
}
let d = ScreenSaverDefaults(forModuleWithName: "com.bluerootstudio.MatrixRain")!
if args.count >= 5 {
    d.set(Double(args[3])!, forKey: "mode")
    d.set(Double(args[4])!, forKey: "theme")
    d.synchronize()
}
guard let v = cls.init(frame: NSRect(x: 0, y: 0, width: 1440, height: 900), isPreview: false) else { print("init failed"); exit(1) }
if args.count >= 6 {
    v.perform(NSSelectorFromString("importImagePaths:"), with: [args[5]] as NSArray)
}
v.perform(NSSelectorFromString("snapshot:"), with: args[2] as NSString)
if args.count >= 5 {  // sprzątanie: przywróć domyślne
    d.set(0.0, forKey: "mode"); d.set(0.0, forKey: "theme")
    d.set([Data](), forKey: "images"); d.synchronize()
}
print("saved")
