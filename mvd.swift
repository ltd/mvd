// mvd: start/stop Mac Virtual Display on Apple Vision Pro from the command line.
//
// Uses the private SidecarCore framework (the same machinery behind iPad Sidecar),
// so it may break with a future macOS update.
//
// Build:  swiftc -O -o ~/bin/mvd ~/bin/mvd.swift
// Usage:  mvd [list|status|connect|disconnect|toggle]   (default: toggle)

import Foundation

typealias Completion = @convention(block) (NSError?) -> Void
typealias DeviceCall = @convention(c) (NSObject, Selector, NSObject, Completion) -> Void

func fail(_ msg: String) -> Never {
  FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
  exit(1)
}

guard dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore", RTLD_NOW) != nil,
      let cls = NSClassFromString("SidecarDisplayManager") as? NSObject.Type,
      let mgr = cls.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() as? NSObject
else { fail("SidecarCore is unavailable on this macOS version.") }

func devices(_ sel: String) -> [NSObject] {
  (mgr.perform(NSSelectorFromString(sel))?.takeUnretainedValue() as? [NSObject]) ?? []
}

func model(_ d: NSObject) -> String {
  d.responds(to: NSSelectorFromString("model")) ? (d.value(forKey: "model") as? String ?? "") : ""
}

func name(_ d: NSObject) -> String { d.value(forKey: "name") as? String ?? "?" }

func isVisionPro(_ d: NSObject) -> Bool { model(d).hasPrefix("RealityDevice") }

func call(_ selName: String, _ device: NSObject) {
  let sel = NSSelectorFromString(selName)
  guard mgr.responds(to: sel) else { fail("SidecarDisplayManager has no \(selName)") }
  let fn = unsafeBitCast(mgr.method(for: sel), to: DeviceCall.self)
  let done = DispatchSemaphore(value: 0)
  var error: NSError?
  // Bind the block to a variable first: an inline closure is treated as non-escaping,
  // and SidecarCore retains it, which trips Swift's escape check and crashes.
  let completion: Completion = { err in error = err; done.signal() }
  fn(mgr, sel, device, completion)
  // Completion is delivered on a background queue; wait up to 30s for it.
  if done.wait(timeout: .now() + 30) == .timedOut { fail("Timed out waiting for \(name(device)).") }
  if let error { fail("\(selName) failed: \(error.localizedDescription)") }
}

let all = devices("devices")
let connected = devices("connectedDevices")
let vision = all.first(where: isVisionPro)
let isConnected = connected.contains(where: isVisionPro)

switch CommandLine.arguments.dropFirst().first ?? "toggle" {
case "list":
  for d in all {
    let on = connected.contains(d) ? " (connected)" : ""
    print("\(name(d))  [\(model(d))]\(on)")
  }
case "status":
  print(vision == nil ? "not found" : (isConnected ? "connected" : "available"))
case "connect":
  guard let v = vision else { fail("Vision Pro not found. Is it on, unlocked, and on the same Apple Account?") }
  if !isConnected { call("connectToDevice:completion:", v) }
  print("connected")
case "disconnect":
  if isConnected, let v = connected.first(where: isVisionPro) { call("disconnectFromDevice:completion:", v) }
  print("disconnected")
case "toggle":
  guard let v = vision else { fail("Vision Pro not found. Is it on, unlocked, and on the same Apple Account?") }
  if isConnected {
    call("disconnectFromDevice:completion:", connected.first(where: isVisionPro) ?? v)
    print("disconnected")
  } else {
    call("connectToDevice:completion:", v)
    print("connected")
  }
default:
  fail("usage: mvd [list|status|connect|disconnect|toggle]")
}
