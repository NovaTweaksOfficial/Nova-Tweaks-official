import Cocoa
import WebKit
import Foundation

final class Bridge: NSObject, WKScriptMessageHandler {
    let webView: WKWebView
    let proc = Process()
    let inPipe = Pipe()
    let outPipe = Pipe()
    let errPipe = Pipe()
    let writeQueue = DispatchQueue(label: "nova.bridge.write")
    var pendingInit = true
    var buffer = Data()

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
    }

    func log(_ s: String) {
        let line = "[\(Date())] \(s)\n"
        let p = (NSHomeDirectory() as NSString).appendingPathComponent(".novatweaks/native-bridge.log")
        try? FileManager.default.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let d = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: p), let h = FileHandle(forWritingAtPath: p) { h.seekToEndOfFile(); h.write(d); try? h.close() }
            else { try? d.write(to: URL(fileURLWithPath: p)) }
        }
    }

    func start() throws {
        guard let res = Bundle.main.resourcePath else { throw NSError(domain:"nova", code:1, userInfo:[NSLocalizedDescriptionKey:"Missing Resources"]) }
        let script = (res as NSString).appendingPathComponent("Nova_Tweaks_WebGUI.ps1")
        guard FileManager.default.fileExists(atPath: script) else { throw NSError(domain:"nova", code:2, userInfo:[NSLocalizedDescriptionKey:"Missing Nova_Tweaks_WebGUI.ps1 in Resources"]) }

        var pwsh: String? = nil
        let bundled = (res as NSString).appendingPathComponent("pwsh/pwsh")
        if FileManager.default.isExecutableFile(atPath: bundled) { pwsh = bundled }
        if pwsh == nil {
            for c in ["/opt/homebrew/bin/pwsh","/usr/local/bin/pwsh","/usr/bin/pwsh"] { if FileManager.default.isExecutableFile(atPath: c) { pwsh = c; break } }
        }
        if pwsh == nil {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/env"); p.arguments = ["which","pwsh"]
            let o = Pipe(); p.standardOutput = o; try? p.run(); p.waitUntilExit()
            let s = String(data: o.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let s = s, !s.isEmpty, FileManager.default.isExecutableFile(atPath: s) { pwsh = s }
        }
        guard let pwshPath = pwsh else { throw NSError(domain:"nova", code:3, userInfo:[NSLocalizedDescriptionKey:"PowerShell 7 (pwsh) is required.\nInstall: brew install --cask powershell\nor https://github.com/PowerShell/PowerShell"]) }

        var env = ProcessInfo.processInfo.environment
        env["NOVA_STDIO_BRIDGE"] = "1"
        env["NOVA_SKIP_ADMIN"] = "1"
        env["NOVA_NOOPEN"] = "1"
        if env["NOVA_FIXED_GAME"] == nil { env["NOVA_FIXED_GAME"] = "Minecraft" }
        if env["NOVA_APP_VARIANT"] == nil { env["NOVA_APP_VARIANT"] = "NovaTweaksMinecraft" }

        proc.executableURL = URL(fileURLWithPath: pwshPath)
        proc.arguments = ["-NoProfile","-ExecutionPolicy","Bypass","-File", script]
        proc.environment = env
        proc.currentDirectoryURL = URL(fileURLWithPath: res)
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            if d.isEmpty { return }
            self?.onData(d)
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            if !d.isEmpty, let s = String(data: d, encoding: .utf8) { self?.log("STDERR: "+s) }
        }
        proc.terminationHandler = { [weak self] p in
            self?.log("backend exited \(p.terminationStatus)")
        }

        try proc.run()
        log("started pwsh=\(pwshPath) script=\(script)")
        send(["id":"__init","path":"__html","body":""])
    }

    func send(_ obj: [String: Any]) {
        guard let d = try? JSONSerialization.data(withJSONObject: obj), var s = String(data: d, encoding: .utf8) else { return }
        s += "\n"
        writeQueue.async { [weak self] in
            if let data = s.data(using: .utf8) { try? self?.inPipe.fileHandleForWriting.write(contentsOf: data) }
        }
    }

    func onData(_ d: Data) {
        buffer.append(d)
        while let r = buffer.firstRange(of: Data([0x0a])) {
            let line = buffer.subdata(in: buffer.startIndex..<r.lowerBound)
            buffer.removeSubrange(buffer.startIndex...r.lowerBound)
            guard !line.isEmpty else { continue }
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { log("bad json line"); continue }
            let id = obj["id"] as? String ?? (obj["id"].map { String(describing: $0) } ?? "")
            let body = obj["body"] as? String ?? "{}"
            if id == "__init" && pendingInit {
                pendingInit = false
                if let bobj = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any], let html = bobj["html"] as? String {
                    log("html loaded len=\(html.count)")
                    DispatchQueue.main.async { [weak self] in
                        self?.webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
                    }
                } else {
                    log("init missing html: \(body.prefix(200))")
                    DispatchQueue.main.async { [weak self] in
                        self?.webView.loadHTMLString("<html><body style='background:#050508;color:#ff6b7a;font-family:system-ui;padding:28px'>Nova Tweaks failed to load UI.<pre>\(body)</pre></body></html>", baseURL: nil)
                    }
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let bodyData = try? JSONSerialization.data(withJSONObject: ["id": id, "body": body], options: []),
                          let json = String(data: bodyData, encoding: .utf8) else { return }
                    self?.webView.evaluateJavaScript("window.__novaResolve && window.__novaResolve(\(json))", completionHandler: nil)
                }
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let path = dict["path"] as? String else { log("bad message"); return }
        let rawId = dict["id"]
        let id = (rawId as? String) ?? (rawId.map { String(describing: $0) } ?? "")
        let body = dict["body"] as? String ?? ""
        log("req \(id) \(path)")
        send(["id": id, "path": path, "body": body])
    }

    func stop() {
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        if proc.isRunning { proc.terminate() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var bridge: Bridge!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = WKWebViewConfiguration()
        let uc = WKUserContentController()
        let js = """
        (function(){
          var pending={}, seq=0;
          window.__novaResolve=function(msg){
            try{ if(typeof msg==='string') msg=JSON.parse(msg); }catch(e){ return; }
            var p=pending[String(msg.id)]; if(!p) return; delete pending[String(msg.id)];
            var body=msg.body||'{}';
            p.resolve(new Response(body,{status:200,headers:{'Content-Type':'application/json'}}));
          };
          var nativeFetch=window.fetch;
          window.fetch=function(input,init){
            var url=typeof input==='string'?input:((input&&input.url)||'');
            if(url && url.charAt(0)==='/' && !(url.indexOf('//')===0)){
              return new Promise(function(resolve,reject){
                var id=String(++seq); pending[id]={resolve:resolve,reject:reject};
                var body=(init&&init.body)?init.body:'';
                try{
                  if(!(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.nova)) throw new Error('nova bridge unavailable');
                  window.webkit.messageHandlers.nova.postMessage({id:id,path:url,body:String(body)});
                }catch(e){ delete pending[id]; resolve(new Response(JSON.stringify({success:false,message:String(e)}),{status:200,headers:{'Content-Type':'application/json'}})); }
                setTimeout(function(){ if(pending[id]){ delete pending[id]; resolve(new Response(JSON.stringify({success:false,message:'Native app timed out waiting for response.'}),{status:200,headers:{'Content-Type':'application/json'}})); } }, 30000);
              });
            }
            return nativeFetch.apply(this,arguments);
          };
          window.__novaNative=1;
        })();
        """
        uc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = uc

        let webView = WKWebView(frame: .zero, configuration: config)
        bridge = Bridge(webView: webView)
        uc.add(bridge, name: "nova")

        webView.setValue(false, forKey: "drawsBackground")
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Nova Tweaks"
        window.center()
        window.contentView = webView
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        webView.loadHTMLString("<html><body style='margin:0;background:#050508;color:#8888a0;font-family:system-ui;display:flex;align-items:center;justify-content:center;height:100vh'>Loading Nova Tweaks…</body></html>", baseURL: nil)

        do { try bridge.start() }
        catch {
            let msg = (error as NSError).localizedDescription
            webView.loadHTMLString("<html><body style='background:#050508;color:#ff6b7a;font-family:system-ui;padding:28px'><h2>Nova Tweaks</h2><pre style='white-space:pre-wrap'>\(msg)</pre></body></html>", baseURL: nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        bridge?.stop()
        NSApp.terminate(nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
