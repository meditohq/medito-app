from pathlib import Path
import subprocess,plistlib,shutil
root=Path('/Users/mike/Projects/Medito/medito_new')
tmp=Path('/private/tmp/medito-native-widget-preview');app=tmp/'WidgetPreview.app';app.mkdir(exist_ok=True)
for name in ['WidgetShared.swift','StatCalculators.swift','StreakWidget.swift','ConsistencyWidget.swift','UpNextWidget.swift']:
 s=(root/'ios/MeditoWidget'/name).read_text()
 s=s.replace('@Environment(\\.widgetFamily) var family', 'var family: WidgetFamily = '+('.systemMedium' if name=='UpNextWidget.swift' else '.systemSmall'))
 if name=='WidgetShared.swift':
  s=s.replace('if #available(iOSApplicationExtension 17.0, *) {','if #available(iOSApplicationExtension 99.0, *) {')
  start=s.index('        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()')
  end=s.index('        for weight in',start)
  s=s[:start]+'        let dir = Bundle.main.bundleURL\n'+s[end:]
 s=s.replace('iOSApplicationExtension', 'iOS')
 (tmp/name).write_text(s)
for font in (root/'assets/fonts/google-sans').glob('*.ttf'):shutil.copy(font,app/font.name)
plistlib.dump({'CFBundleIdentifier':'org.medito.storewidgetpreview','CFBundleName':'Widget Preview','CFBundleExecutable':'WidgetPreview','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0','LSRequiresIPhoneOS':True,'MinimumOSVersion':'15.0','UIDeviceFamily':[1,2],'UILaunchScreen':{}},(app/'Info.plist').open('wb'))
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
sources=[str(p) for p in tmp.glob('*.swift')]
subprocess.run(['xcrun','swiftc','-sdk',sdk,'-target','arm64-apple-ios17.0-simulator','-parse-as-library',*sources,'-o',str(app/'WidgetPreview')],check=True)
subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(app)],check=True)
