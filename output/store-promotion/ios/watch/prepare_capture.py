from pathlib import Path
import shutil,json
repo=Path(__file__).resolve().parents[4];src=repo/'ios';tmp=Path('/private/tmp/medito-watch-store-capture/project');tmp.mkdir(exist_ok=True)
shutil.copytree(src/'Runner.xcodeproj',tmp/'Runner.xcodeproj',dirs_exist_ok=True)
shutil.copytree(src/'MeditoWatch',tmp/'MeditoWatch',dirs_exist_ok=True)
for name in ['Runner','Flutter','Pods','MeditoWidget']:
 p=tmp/name
 if not p.exists():p.symlink_to(src/name,target_is_directory=True)
art=tmp/'MeditoWatch/Assets.xcassets/CaptureCourse.imageset';art.mkdir(exist_ok=True)
shutil.copy(repo/'assets/images/the_medito_course.png',art/'course.png')
(art/'Contents.json').write_text(json.dumps({'images':[{'filename':'course.png','idiom':'universal'}],'info':{'author':'xcode','version':1}}))
track={'id':'capture-learning-to-sit','title':'Learning to sit','subtitle':'4 min','audioUrl':'https://example.invalid/unused.mp3','fileId':'capture-learning-to-sit-4min','durationMs':240000,'guide':'Will'}
context={'v':2,'accountId':'store-example','sentAt':0,'streak':7,'consistency':67,'showStreak':False,'upNext':{**track,'packTitle':'The Medito course','coverUrl':'medito-capture://course','completed':2,'total':10},'daily':{**track,'id':'capture-daily','title':'Your Daily'},'favorites':[{**track,'packTitle':'The Medito course'},{**track,'id':'capture-learning','title':'Learning to sit','packTitle':'Learning to sit'}]}
(tmp.parent/'example-context.json').write_text(json.dumps(context,indent=2))
fixture=json.dumps(context)
seed='''        // Screenshot-only host: actual views and example account data.
        if ProcessInfo.processInfo.arguments.contains("-storeCapture") {
            let context = try! JSONSerialization.jsonObject(with: Data(#"FIXTURE"#.utf8)) as! [String: Any]
            UserDefaults.standard.set(context, forKey: "watch_progress_context_v2")
            let url = "medito-capture://course"
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in url.utf8 { hash ^= UInt64(byte); hash = hash &* 0x100000001b3 }
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("covers")
            try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try! UIImage(named: "CaptureCourse")!.jpegData(compressionQuality: 0.95)!.write(to: directory.appendingPathComponent(String(hash, radix: 16) + ".jpg"))
        }
'''.replace('FIXTURE',fixture)
p=tmp/'MeditoWatch/MeditoWatchApp.swift';s=p.read_text().replace('import SwiftUI','import SwiftUI\nimport UIKit').replace('    init() {','    init() {\n'+seed);p.write_text(s)
p=tmp/'MeditoWatch/ContentView.swift';s=p.read_text().replace('@State private var path: [Route] = []','@State private var path: [Route] = ProcessInfo.processInfo.arguments.contains("-captureFavorites") ? [.favorites] : []');p.write_text(s)
print('Native capture project prepared; production views unchanged')
