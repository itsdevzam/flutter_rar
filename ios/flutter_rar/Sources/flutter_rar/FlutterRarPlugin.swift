import Flutter
#if canImport(UnrarKit)
import UnrarKit
#endif

/// iOS extraction uses UnrarKit when CocoaPods is linked, and the official
/// UnRAR sources when Swift Package Manager builds this plugin.
/// UnRAR is not thread-safe, so every call stays on one queue.
public class FlutterRarPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "com.booknest.flutter_rar")

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.booknest.flutter_rar",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlutterRarPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async {
      let json: String
      #if canImport(UnrarKit)
      switch call.method {
      case "list":
        json = self.list(args)
      case "extract":
        json = self.extract(args)
      case "test":
        json = self.testArchive(args)
      default:
        json = self.fail("Unknown method")
      }
      #else
      json = self.nativeRun(call.method, args)
      #endif
      DispatchQueue.main.async {
        result(json)
      }
    }
  }

#if canImport(UnrarKit)
  private func list(_ args: [String: Any]) -> String {
    let path = args["rarFilePath"] as? String ?? ""
    let password = args["password"] as? String ?? ""
    let version = detectVersion(path)
    if version.isEmpty { return fail("Not a RAR archive") }
    do {
      let archive = try openArchive(path, password: password)
      let infos = try archive.listFileInfo()
      return success(
        message: "Listed \(infos.count) entries. (UnrarKit)",
        version: version,
        encrypted: encrypted(archive, infos),
        destination: "",
        entries: infos.map { entry($0, destination: "", version: version) }
      )
    } catch {
      return fail(message(for: error), version: version)
    }
  }

  private func extract(_ args: [String: Any]) -> String {
    let path = args["rarFilePath"] as? String ?? ""
    let destination = args["destinationPath"] as? String ?? ""
    let password = args["password"] as? String ?? ""
    let entryName = args["entryName"] as? String ?? ""
    let version = detectVersion(path)
    if version.isEmpty { return fail("Not a RAR archive") }
    if destination.isEmpty {
      return fail("Destination directory is required", version: version)
    }
    do {
      try FileManager.default.createDirectory(
        atPath: destination,
        withIntermediateDirectories: true
      )
      let archive = try openArchive(path, password: password)
      let infos = try archive.listFileInfo()
      if infos.contains(where: { !isSafe(normalized($0.filename)) }) {
        return fail("Archive contains an unsafe path", version: version)
      }
      let selected: [URKFileInfo]
      if entryName.isEmpty {
        try archive.extractFiles(to: destination, overwrite: true)
        selected = infos
      } else {
        guard let info = infos.first(where: { sameEntry($0.filename, entryName) }) else {
          return fail("Entry not found", version: version)
        }
        if !info.isDirectory {
          let data = try archive.extractData(fromFile: info.filename)
          let output = outputPath(destination, info.filename)
          try FileManager.default.createDirectory(
            atPath: (output as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
          )
          try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        }
        selected = [info]
      }
      let wrote = selected.filter { !$0.isDirectory }.count
      return success(
        message: "Extracted \(wrote) files. (UnrarKit)",
        version: version,
        encrypted: encrypted(archive, infos),
        destination: destination,
        entries: selected.map { entry($0, destination: destination, version: version) }
      )
    } catch {
      return fail(message(for: error), version: version)
    }
  }

  private func testArchive(_ args: [String: Any]) -> String {
    let path = args["rarFilePath"] as? String ?? ""
    let password = args["password"] as? String ?? ""
    let version = detectVersion(path)
    if version.isEmpty { return fail("Not a RAR archive") }
    do {
      let archive = try openArchive(path, password: password)
      guard archive.checkDataIntegrity() else {
        return fail("Archive data is corrupt", version: version)
      }
      let infos = try archive.listFileInfo()
      return success(
        message: "Archive is valid",
        version: version,
        encrypted: encrypted(archive, infos),
        destination: "",
        entries: infos.map { entry($0, destination: "", version: version) }
      )
    } catch {
      return fail(message(for: error), version: version)
    }
  }

  private func openArchive(_ path: String, password: String) throws -> URKArchive {
    if password.isEmpty {
      return try URKArchive(path: path)
    }
    return try URKArchive(path: path, password: password)
  }

  private func encrypted(_ archive: URKArchive, _ infos: [URKFileInfo]) -> Bool {
    archive.isPasswordProtected() || infos.contains { $0.isEncryptedWithPassword }
  }

  private func entry(
    _ info: URKFileInfo,
    destination: String,
    version: String
  ) -> [String: Any] {
    let name = normalized(info.filename)
    let extracted = destination.isEmpty ? "" : outputPath(destination, name)
    var item: [String: Any] = [
      "name": name,
      "extractedPath": extracted,
      "isDirectory": info.isDirectory,
      "uncompressedSize": info.uncompressedSize,
      "compressedSize": info.compressedSize,
      "isEncrypted": info.isEncryptedWithPassword,
      "compression": version == "RAR4" ? "rar4" : "rar5",
      "crc32": Int(info.crc),
      "skipped": false,
    ]
    if let timestamp = info.timestamp {
      item["modifiedAt"] = Int(timestamp.timeIntervalSince1970 * 1000)
    } else {
      item["modifiedAt"] = NSNull()
    }
    return item
  }

  private func outputPath(_ destination: String, _ name: String) -> String {
    (destination as NSString).appendingPathComponent(normalized(name))
  }

  private func normalized(_ name: String) -> String {
    name.replacingOccurrences(of: "\\", with: "/")
  }

  private func sameEntry(_ stored: String, _ requested: String) -> Bool {
    trimSlashes(normalized(stored)) == trimSlashes(normalized(requested))
  }

  private func trimSlashes(_ name: String) -> String {
    var value = name
    while value.hasSuffix("/") { value.removeLast() }
    while value.hasPrefix("./") { value.removeFirst(2) }
    return value
  }

  private func isSafe(_ name: String) -> Bool {
    if name.isEmpty || name.hasPrefix("/") || name.hasPrefix("\\") { return false }
    let scalars = Array(name)
    if scalars.count >= 2 && scalars[1] == ":" { return false }
    for part in name.split(separator: "/") where part == ".." {
      return false
    }
    return true
  }

  private func detectVersion(_ path: String) -> String {
    guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
    defer { try? handle.close() }
    let bytes = [UInt8](handle.readData(ofLength: 8))
    if bytes.count >= 7 && bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 &&
      bytes[3] == 0x21 && bytes[4] == 0x1A && bytes[5] == 0x07 {
      if bytes[6] == 0x00 { return "RAR4" }
      if bytes.count >= 8 && bytes[6] == 0x01 && bytes[7] == 0x00 { return "RAR5" }
    }
    return ""
  }

  private func message(for error: Error) -> String {
    let nsError = error as NSError
    switch nsError.code {
    case 22:
      return "Password required"
    case 24:
      return "Wrong password"
    case 12:
      return "Archive data is corrupt"
    case 13:
      return "Not a valid RAR archive"
    default:
      let text = nsError.localizedDescription
      if text.lowercased().contains("password") { return text }
      return text.isEmpty ? "RAR error" : text
    }
  }

  private func success(
    message: String,
    version: String,
    encrypted: Bool,
    destination: String,
    entries: [[String: Any]]
  ) -> String {
    encode([
      "success": true,
      "message": message,
      "rarVersion": version,
      "isEncrypted": encrypted,
      "destinationPath": destination,
      "entries": entries,
    ])
  }

#endif

#if !canImport(UnrarKit)
  private func nativeRun(_ method: String, _ args: [String: Any]) -> String {
    let path = args["rarFilePath"] as? String ?? ""
    let destination = args["destinationPath"] as? String ?? ""
    let password = args["password"] as? String ?? ""
    let entryName = args["entryName"] as? String ?? ""
    let mode: Int32
    switch method {
    case "list":
      mode = 0
    case "extract":
      mode = entryName.isEmpty ? 1 : 2
    case "test":
      mode = 3
    default:
      return fail("Unknown method")
    }
    let raw = path.withCString { pathPtr in
      destination.withCString { destPtr in
        password.withCString { passwordPtr in
          entryName.withCString { entryPtr in
            flutterRarRun(pathPtr, destPtr, passwordPtr, entryPtr, mode)
          }
        }
      }
    }
    guard let raw else { return fail("UnRAR failed") }
    let json = String(cString: raw)
    flutterRarFree(raw)
    return json
  }
#endif

  private func fail(_ message: String, version: String = "") -> String {
    encode([
      "success": false,
      "message": message,
      "rarVersion": version,
      "isEncrypted": false,
      "destinationPath": "",
      "entries": [],
    ])
  }

  private func encode(_ object: [String: Any]) -> String {
    guard JSONSerialization.isValidJSONObject(object),
      let data = try? JSONSerialization.data(withJSONObject: object),
      let text = String(data: data, encoding: .utf8)
    else {
      return "{\"success\":false,\"message\":\"Could not encode UnrarKit result\",\"rarVersion\":\"\",\"isEncrypted\":false,\"destinationPath\":\"\",\"entries\":[]}"
    }
    return text
  }
}

#if !canImport(UnrarKit)
@_silgen_name("flutter_rar_run")
private func flutterRarRun(
  _ path: UnsafePointer<CChar>?,
  _ dest: UnsafePointer<CChar>?,
  _ password: UnsafePointer<CChar>?,
  _ entry: UnsafePointer<CChar>?,
  _ mode: Int32
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("flutter_rar_free")
private func flutterRarFree(_ ptr: UnsafeMutablePointer<CChar>?)
#endif
