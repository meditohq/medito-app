package meditofoundation.medito.wear

import android.app.Application

class WearApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // Start listening for the phone's context before the first frame.
        WatchRepository.init(this)
    }
}
