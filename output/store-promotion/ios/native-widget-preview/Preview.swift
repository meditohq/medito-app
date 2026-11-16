import SwiftUI
import WidgetKit
@main struct PreviewApp: App {
 var body: some Scene { WindowGroup { PreviewScreen().preferredColorScheme(.dark) } }
}
struct PreviewScreen: View {
 let now=Date()
 var body: some View {
  ZStack {
   Color(red:0.278,green:0.188,blue:0.431).ignoresSafeArea()
   VStack(spacing:26) {
    HStack(spacing:20) {
     VStack(spacing:10) {
      StreakWidgetView(entry:StreakEntry(date:now,data:.placeholder))
       .frame(width:178,height:178).clipShape(RoundedRectangle(cornerRadius:24))
      Text("Streak").font(.system(size:14,weight:.medium))
     }
     VStack(spacing:10) {
      ConsistencyWidgetView(entry:ConsistencyEntry(date:now,data:.placeholder))
       .frame(width:178,height:178).clipShape(RoundedRectangle(cornerRadius:24))
      Text("Consistency").font(.system(size:14,weight:.medium))
     }
    }
    VStack(spacing:10) {
     UpNextWidgetEntryView(entry:UpNextEntry(date:now,title:"Observing distractions",subtitle:"4 min",packTitle:"Learning to sit",trackId:"learning-to-sit-02",completed:1,total:10,themePreference:"dark"))
      .frame(width:376,height:178).clipShape(RoundedRectangle(cornerRadius:24))
     Text("Continue").font(.system(size:14,weight:.medium))
    }
   }.foregroundStyle(.white)
  }.statusBarHidden()
 }
}
