package com.google.flutter.plugins.audiofileplayer;

import android.app.Activity;
import android.app.Application;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.AudioManager;
import android.os.Bundle;
import android.support.v4.media.MediaBrowserCompat;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;
import android.view.KeyEvent;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.media.session.MediaButtonReceiver;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * Flutter audio file player plugin.
 *
 * <p>Receives messages which a) create, trigger, and destroy instances of {@link
 * ManagedMediaPlayer}, or b) communicate with the OS to control and respond to background audio
 * interaction.
 */
public class AudiofileplayerPlugin
        implements MethodCallHandler,
        AudiofileplayerService.ServiceListener,
        FlutterPlugin,
        ActivityAware {
    // Used when defining an Intent from a custom media button.
    public static final String CUSTOM_MEDIA_BUTTON_EXTRA_KEY = "customMediaButton";
    private static final String TAG = AudiofileplayerPlugin.class.getSimpleName();
    // Method channel constants, matching those in the Dart and iOS plugin code.
    private static final String CHANNEL = "audiofileplayer";
    private static final String LOAD_METHOD = "load";
    private static final String FLUTTER_PATH = "flutterPath";
    private static final String ABSOLUTE_PATH = "absolutePath";
    private static final String AUDIO_BYTES = "audioBytes";
    private static final String REMOTE_URL = "remoteUrl";
    private static final String AUDIO_ID = "audioId";
    private static final String LOOPING = "looping";
    private static final String PLAY_IN_BACKGROUND = "playInBackground";
    private static final String RELEASE_METHOD = "release";
    private static final String PLAY_METHOD = "play";
    private static final String PLAY_FROM_START = "playFromStart";
    private static final String ENDPOINT_SECONDS = "endpointSeconds";
    private static final String SEEK_METHOD = "seek";
    private static final String SET_VOLUME_METHOD = "setVolume";
    private static final String VOLUME = "volume";
    private static final String PAUSE_METHOD = "pause";
    private static final String ON_COMPLETE_CALLBACK = "onComplete";
    private static final String ON_DURATION_CALLBACK = "onDuration";
    private static final String DURATION_SECONDS = "duration_seconds";
    private static final String ON_POSITION_CALLBACK = "onPosition";
    private static final String POSITION_SECONDS = "position_seconds";
    private static final String STOP_BACKGROUND_DISPLAY_METHOD = "stopBackgroundDisplay";
    private static final String ERROR_CODE = "AudioPluginError";
    // Constants for updating playback state from Dart.
    private static final String SET_PLAYBACK_STATE_METHOD = "setPlaybackState";
    private static final String PLAYBACK_IS_PLAYING = "playbackIsPlaying";
    private static final String PLAYBACK_POSITION_SECONDS = "playbackPositionSeconds";
    // Constants for setting audio metadata from Dart.
    private static final String SET_METADATA_METHOD = "setMetadata";
    private static final String METADATA_ID = "metadataId";
    private static final String METADATA_TITLE = "metadataTitle";
    private static final String METADATA_ALBUM = "metadataAlbum";
    private static final String METADATA_ARTIST = "metadataArtist";
    private static final String METADATA_GENRE = "metadataGenre";
    private static final String METADATA_DURATION_SECONDS = "metadataDurationSeconds";
    private static final String METADATA_ART_BYTES = "metadataArtBytes";
    // Constants for setting supported actions from Dart, and sending media events to Dart.
    private static final String SET_SUPPORTED_MEDIA_ACTIONS_METHOD = "setSupportedMediaActions";
    private static final String MEDIA_ACTIONS = "mediaActions";
    private static final String SET_ANDROID_MEDIA_BUTTONS_METHOD = "setAndroidMediaButtons";
    private static final String MEDIA_BUTTONS = "mediaButtons";
    private static final String MEDIA_COMPACT_INDICES = "mediaCompactIndices";
    private static final String ON_MEDIA_EVENT_CALLBACK = "onMediaEvent";
    private static final String MEDIA_EVENT_TYPE = "mediaEventType";
    private static final String MEDIA_STOP = "stop";
    private static final String MEDIA_PAUSE = "pause";
    private static final String MEDIA_PLAY = "play";
    private static final String MEDIA_PLAY_PAUSE = "playPause";
    private static final String MEDIA_NEXT = "next";
    private static final String MEDIA_PREVIOUS = "previous";
    private static final String MEDIA_SEEK_FORWARD = "seekForward";
    private static final String MEDIA_SEEK_BACKWARD = "seekBackward";
    private static final String MEDIA_SEEK_TO = "seekTo";
    private static final String MEDIA_SEEK_TO_POSITION_SECONDS = "seekToPositionSeconds";
    private static final String MEDIA_CUSTOM = "custom";
    private static final String MEDIA_CUSTOM_TITLE = "customTitle";
    private static final String MEDIA_CUSTOM_EVENT_ID = "customEventId";
    private static final String MEDIA_CUSTOM_DRAWABLE_RESOURCE = "customDrawableResource";
    private final MediaControllerCompat.Callback controllerCallback =
            new MediaControllerCompat.Callback() {
                @Override
                public void onMetadataChanged(MediaMetadataCompat metadata) {
                    Log.i(TAG, "MediaControllerCompat.Callback.onMetadataChanged");
                }

                @Override
                public void onPlaybackStateChanged(PlaybackStateCompat state) {
                    Log.i(TAG, "MediaControllerCompat.Callback.onPlaybackStateChanged");
                }
            };
    private Registrar registrar;
    // Activity used by v2 embedding.
    private Activity activity;
    private Map<String, ManagedMediaPlayer> mediaPlayers;
    private MethodChannel methodChannel;
    private Context context;
    private MediaBrowserCompat mediaBrowser;
    private MediaControllerCompat mediaController;
    private final MediaBrowserCompat.ConnectionCallback connectionCallback =
            new MediaBrowserCompat.ConnectionCallback() {
                @Override
                public void onConnected() {
                    Log.i(TAG, "ConnectionCallback.onConnected");
                    try {
                        Activity activity = activity();
                        MediaSessionCompat.Token token = mediaBrowser.getSessionToken();
                        mediaController = new MediaControllerCompat(activity, token);
                        MediaControllerCompat.setMediaController(activity, mediaController);
                        mediaController.registerCallback(controllerCallback);
                        AudiofileplayerService.instance.setPendingIntentActivity(activity);
                        AudiofileplayerService.instance.setListener(AudiofileplayerPlugin.this);
                    } catch (Exception e) {
                        Log.e(TAG, "ConnectionCallback.onConnected Failure", e);
                    }
                }

                @Override
                public void onConnectionSuspended() {
                    Log.i(TAG, "ConnectionCallback.onConnectionSuspended");
                }

                @Override
                public void onConnectionFailed() {
                    Log.i(TAG, "ConnectionCallback.onConnectionFailed");
                }
            };

    public static void registerWith(Registrar registrar) {
        AudiofileplayerPlugin instance = new AudiofileplayerPlugin();
        instance.registrar = registrar;
        instance.initInstance(registrar.messenger(), registrar.context());
        instance.registerLifecycleCallbacks(instance.activity());
    }

    /**
     * Converts a Map of metadata entries (from Dart) into a {@link MediaMetadataCompat}.
     */
    static MediaMetadataCompat mapToMetadata(Map<String, ?> map) {
        MediaMetadataCompat.Builder builder = new MediaMetadataCompat.Builder();
        if (map.containsKey(METADATA_ID)) {
            builder.putString(MediaMetadataCompat.METADATA_KEY_MEDIA_ID, (String) map.get(METADATA_ID));
        }
        if (map.containsKey(METADATA_TITLE)) {
            builder.putString(MediaMetadataCompat.METADATA_KEY_TITLE, (String) map.get(METADATA_TITLE));
        }
        if (map.containsKey(METADATA_ALBUM)) {
            builder.putString(MediaMetadataCompat.METADATA_KEY_ALBUM, (String) map.get(METADATA_ALBUM));
        }
        if (map.containsKey(METADATA_ARTIST)) {
            builder.putString(MediaMetadataCompat.METADATA_KEY_ARTIST, (String) map.get(METADATA_ARTIST));
        }
        if (map.containsKey(METADATA_GENRE)) {
            builder.putString(MediaMetadataCompat.METADATA_KEY_GENRE, (String) map.get(METADATA_GENRE));
        }
        if (map.containsKey(METADATA_DURATION_SECONDS)) {
            // Convert to Long milliseconds.
            Double durationSecondsDouble = (Double) map.get(METADATA_DURATION_SECONDS);
            Long durationMsLong = (long) Math.floor(durationSecondsDouble * 1000);
            builder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMsLong);
        }
        if (map.containsKey(METADATA_ART_BYTES)) {
            byte[] artBytes = (byte[]) map.get(METADATA_ART_BYTES);
            Bitmap bitmap = BitmapFactory.decodeByteArray(artBytes, 0, artBytes.length);
            builder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap);
            builder.putBitmap(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON, bitmap);
        }
        return builder.build();
    }

    /**
     * Converts a {@link KeyEvent} code (from the Android system) into a MediaEvent type string (to
     * send to Dart).
     */
    private static String eventCodeToMediaEventString(int eventCode) {
        switch (eventCode) {
            case KeyEvent.KEYCODE_MEDIA_PLAY:
                return MEDIA_PLAY;
            case KeyEvent.KEYCODE_MEDIA_PAUSE:
                return MEDIA_PAUSE;
            // Intentional fall-through, treating HEADSETHOOK as play/pause.
            case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
            case KeyEvent.KEYCODE_HEADSETHOOK:
                return MEDIA_PLAY_PAUSE;
            case KeyEvent.KEYCODE_MEDIA_STOP:
                return MEDIA_STOP;
            case KeyEvent.KEYCODE_MEDIA_NEXT:
                return MEDIA_NEXT;
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
                return MEDIA_PREVIOUS;
            case KeyEvent.KEYCODE_MEDIA_FAST_FORWARD:
                return MEDIA_SEEK_FORWARD;
            case KeyEvent.KEYCODE_MEDIA_REWIND:
                return MEDIA_SEEK_BACKWARD;
            default:
                Log.e(TAG, "Unsupported eventCode:" + eventCode);
                return null;
        }
    }

    /**
     * Converts a list of Strings, representing supported media actions, to a long bitmask of
     * PlaybackStateCompat actions.
     */
    private static long mediaActionStringsToPlaybackStateActions(List<String> mediaActionStrings) {
        long result = 0;
        if (mediaActionStrings.contains(MEDIA_PLAY)) result |= PlaybackStateCompat.ACTION_PLAY;
        if (mediaActionStrings.contains(MEDIA_PAUSE)) result |= PlaybackStateCompat.ACTION_PAUSE;
        if (mediaActionStrings.contains(MEDIA_PLAY_PAUSE))
            result |= PlaybackStateCompat.ACTION_PLAY_PAUSE;
        if (mediaActionStrings.contains(MEDIA_STOP)) result |= PlaybackStateCompat.ACTION_STOP;
        if (mediaActionStrings.contains(MEDIA_NEXT))
            result |= PlaybackStateCompat.ACTION_SKIP_TO_NEXT;
        if (mediaActionStrings.contains(MEDIA_PREVIOUS))
            result |= PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS;
        if (mediaActionStrings.contains(MEDIA_SEEK_FORWARD))
            result |= PlaybackStateCompat.ACTION_FAST_FORWARD;
        if (mediaActionStrings.contains(MEDIA_SEEK_BACKWARD))
            result |= PlaybackStateCompat.ACTION_REWIND;
        if (mediaActionStrings.contains(MEDIA_SEEK_TO))
            result |= PlaybackStateCompat.ACTION_SEEK_TO;
        return result;
    }

    private void registerLifecycleCallbacks(Activity activity) {
        LifecycleCallbacks callbacks = new LifecycleCallbacks(this, activity.hashCode());
        activity.getApplication().registerActivityLifecycleCallbacks(callbacks);
    }

    private void initInstance(BinaryMessenger messenger, Context context) {
        this.context = context;
        methodChannel = new MethodChannel(messenger, CHANNEL);
        methodChannel.setMethodCallHandler(this);
        mediaPlayers = new HashMap<>();
        Context activeContext = activeContext();
        mediaBrowser =
                new MediaBrowserCompat(
                        activeContext,
                        new ComponentName(activeContext, AudiofileplayerService.class),
                        connectionCallback,
                        null);
    }

    private Activity activity() {
        return activity != null ? activity : registrar.activity();
    }

    private Context activeContext() {
        // for v2 activity context
        if (activity != null) {
            return activity;
        }
        // if it's v1, use registrar
        return registrar != null ? registrar.activeContext() : context;
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        initInstance(binding.getBinaryMessenger(), binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        methodChannel.setMethodCallHandler(null);
        methodChannel = null;
        mediaBrowser = null;
        mediaPlayers.clear();
        mediaPlayers = null;
        context = null;
    }

    private void attachToActivity(ActivityPluginBinding activityPluginBinding) {
        this.activity = activityPluginBinding.getActivity();
        registerLifecycleCallbacks(activity());
    }

    private void detachToActivity() {
        this.activity = null;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        attachToActivity(activityPluginBinding);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detachToActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
        attachToActivity(activityPluginBinding);
    }

    @Override
    public void onDetachedFromActivity() {
        detachToActivity();
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        Log.i(TAG, "onMethodCall: method = " + call.method);
        if (call.method.equals(LOAD_METHOD)) {
            onLoad(call, result);
            return;
        } else if (call.method.equals(SET_PLAYBACK_STATE_METHOD)) {
            Boolean isPlayingBoolean = call.argument(PLAYBACK_IS_PLAYING);
            Double positionSecondsDouble = call.argument(PLAYBACK_POSITION_SECONDS);
            long positionMs =
                    positionSecondsDouble == null
                            ? PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN
                            : (long) Math.floor(positionSecondsDouble * 1000);
            AudiofileplayerService.instance.setPlaybackStateState(
                    isPlayingBoolean ? PlaybackStateCompat.STATE_PLAYING : PlaybackStateCompat.STATE_PAUSED,
                    positionMs,
                    1.0f);
            result.success(null);
            return;
        } else if (call.method.equals(SET_METADATA_METHOD)) {
            MediaMetadataCompat metadata = mapToMetadata((Map<String, ?>) call.arguments);
            AudiofileplayerService.instance.setMetadata(metadata);
            result.success(null);
            return;
        } else if (call.method.equals(SET_SUPPORTED_MEDIA_ACTIONS_METHOD)) {
            List<String> mediaActionStrings = call.argument(MEDIA_ACTIONS);
            long playbackStateActions = mediaActionStringsToPlaybackStateActions(mediaActionStrings);
            AudiofileplayerService.instance.setPlaybackStateActions(playbackStateActions);
            result.success((null));
            return;
        } else if (call.method.equals(SET_ANDROID_MEDIA_BUTTONS_METHOD)) {
            List<?> mediaButtonTypesOrCustoms = call.argument(MEDIA_BUTTONS);
            List<NotificationCompat.Action> actions = new ArrayList<>();
            for (Object mediaButtonTypeOrCustom : mediaButtonTypesOrCustoms) {
                if (mediaButtonTypeOrCustom instanceof String) {
                    actions.add(mediaButtonTypeToAction((String) mediaButtonTypeOrCustom));
                } else if (mediaButtonTypeOrCustom instanceof Map) {
                    actions.add(customMediaButtonMapToAction((Map) mediaButtonTypeOrCustom));
                }
            }
            List<Integer> compactIndicesList = call.argument(MEDIA_COMPACT_INDICES);
            AudiofileplayerService.instance.setActions(actions, compactIndicesList);
            result.success(null);
            return;
        } else if (call.method.equals(STOP_BACKGROUND_DISPLAY_METHOD)) {
            AudiofileplayerService.instance.stop();
            result.success(null);
            return;
        }

        // All subsequent calls need a valid player.
        ManagedMediaPlayer player = getAndVerifyPlayer(call, result);

        if (call.method.equals(PLAY_METHOD)) {
            Boolean playFromStartBoolean = call.argument(PLAY_FROM_START);
            boolean playFromStart = playFromStartBoolean.booleanValue();
            Double endpointSecondsDouble = call.argument(ENDPOINT_SECONDS);
            int endpointMs =
                    endpointSecondsDouble == null
                            ? ManagedMediaPlayer.PLAY_TO_END
                            : (int) Math.floor(endpointSecondsDouble * 1000);
            player.play(playFromStart, endpointMs);

            // Calls the MediaSessionCompat.Callback.onPlay() in the AudiofileplayerService
            // Note that without this, the service doesn't start, but the audio still continues to
            // play in the background; it appears that using MediaBrowserService keeps this context
            // active.
            if (player.playInBackground) {
                mediaController.getTransportControls().play();
            }
            result.success(null);
        } else if (call.method.equals(RELEASE_METHOD)) {
            player.release();
            mediaPlayers.remove(player.getAudioId());
            result.success(null);
        } else if (call.method.equals(SEEK_METHOD)) {
            Double positionSecondsDouble = call.argument(POSITION_SECONDS);
            double positionSeconds = positionSecondsDouble.doubleValue();
            player.setOnSeekCompleteListener(
                    () -> {
                        result.success(null);
                        // Remove listener to avoid additional calls to result.
                        player.setOnSeekCompleteListener(null);
                    });
            player.seek(positionSeconds);
        } else if (call.method.equals(SET_VOLUME_METHOD)) {
            Double volumeDouble = call.argument(VOLUME);
            double volume = volumeDouble.doubleValue();
            player.setVolume(volume);
            result.success(null);
        } else if (call.method.equals(PAUSE_METHOD)) {
            player.pause();
            result.success(null);
        } else {
            result.notImplemented();
        }
    }

    private void onLoad(MethodCall call, Result result) {
        String audioId = call.argument(AUDIO_ID);
        if (audioId == null) {
            result.error(ERROR_CODE, "Received load() call without an audioId", null);
            return;
        }
        if (mediaPlayers.get(audioId) != null) {
            result.error(ERROR_CODE, "Tried to load an already-loaded player: " + audioId, null);
            return;
        }

        Boolean loopingBoolean = call.argument(LOOPING);
        boolean looping = false;
        if (loopingBoolean != null) {
            looping = loopingBoolean.booleanValue();
        }

        Boolean playInBackgroundBoolean = call.argument(PLAY_IN_BACKGROUND);
        boolean playInBackground = false;
        if (playInBackgroundBoolean != null) {
            playInBackground = playInBackgroundBoolean.booleanValue();
        }

        try {
            if (call.argument(FLUTTER_PATH) != null) {
                String flutterPath = call.argument(FLUTTER_PATH).toString();
                AssetManager assetManager = context.getAssets();
                String key = FlutterLoader.getInstance().getLookupKeyForAsset(flutterPath);
                AssetFileDescriptor fd = assetManager.openFd(key);
                ManagedMediaPlayer newPlayer =
                        new LocalManagedMediaPlayer(audioId, fd, this, looping, playInBackground);
                fd.close();
                mediaPlayers.put(audioId, newPlayer);
                handleDurationForPlayer(newPlayer, audioId);
                result.success(null);
            } else if (call.argument(ABSOLUTE_PATH) != null) {
                String absolutePath = call.argument(ABSOLUTE_PATH);
                ManagedMediaPlayer newPlayer =
                        new LocalManagedMediaPlayer(audioId, absolutePath, this, looping, playInBackground);
                mediaPlayers.put(audioId, newPlayer);
                handleDurationForPlayer(newPlayer, audioId);
                result.success(null);
            } else if (call.argument(AUDIO_BYTES) != null) {
                byte[] audioBytes = call.argument(AUDIO_BYTES);
                ManagedMediaPlayer newPlayer =
                        new LocalManagedMediaPlayer(
                                audioId, audioBytes, this, looping, playInBackground, context);
                mediaPlayers.put(audioId, newPlayer);
                handleDurationForPlayer(newPlayer, audioId);
                result.success(null);
            } else if (call.argument(REMOTE_URL) != null) {
                String remoteUrl = call.argument(REMOTE_URL);
                // Note that this will throw an exception on invalid URL or lack of network connectivity.
                RemoteManagedMediaPlayer newPlayer =
                        new RemoteManagedMediaPlayer(audioId, remoteUrl, this, looping, playInBackground);
                newPlayer.setOnRemoteLoadListener(
                        (success) -> {
                            if (success) {
                                handleDurationForPlayer(newPlayer, audioId);
                                result.success(null);
                            } else {
                                mediaPlayers.remove(audioId);
                                result.error(ERROR_CODE, "Remote URL loading failed for URL: " + remoteUrl, null);
                            }
                        });
                // Add player to data structure immediately; will be removed if async loading fails.
                mediaPlayers.put(audioId, newPlayer);
            } else {
                result.error(
                        ERROR_CODE,
                        "Could not create ManagedMediaPlayer with no flutterPath, audioBytes, nor remoteUrl.",
                        null);
                return;
            }
        } catch (Exception e) {
            result.error(ERROR_CODE, "Could not create ManagedMediaPlayer:" + e.getMessage(), null);
        }
    }

    private ManagedMediaPlayer getAndVerifyPlayer(MethodCall call, Result result) {
        String audioId = call.argument(AUDIO_ID);
        if (audioId == null) {
            result.error(
                    ERROR_CODE, String.format("Received %s call without an audioId", call.method), null);
            return null;
        }
        ManagedMediaPlayer player = mediaPlayers.get(audioId);
        if (player == null) {
            result.error(
                    ERROR_CODE,
                    String.format("Called %s on an unloaded player: %s", call.method, audioId),
                    null);
        }
        return player;
    }

    /**
     * Called by {@link ManagedMediaPlayer} when (non-looping) file has finished playback.
     */
    public void handleCompletion(String audioId) {
        this.methodChannel.invokeMethod(
                ON_COMPLETE_CALLBACK, Collections.singletonMap(AUDIO_ID, audioId));
    }

    // Called on successful load.
    public void handleDurationForPlayer(ManagedMediaPlayer player, String audioId) {
        Map<String, Object> arguments = new HashMap<String, Object>();
        arguments.put(AUDIO_ID, audioId);
        // Note that player will report a negative value if duration is unavailable (for example,
        // streaming certain types of remote audio).
        double durationSeconds = player.getDurationSeconds();
        arguments.put(DURATION_SECONDS, Double.valueOf(durationSeconds));
        this.methodChannel.invokeMethod(ON_DURATION_CALLBACK, arguments);
    }

    // ServiceListener overrides.

    /**
     * Called repeatedly by {@link ManagedMediaPlayer} during playback.
     */
    public void handlePosition(String audioId, double positionSeconds) {
        Map<String, Object> arguments = new HashMap<String, Object>();
        arguments.put(AUDIO_ID, audioId);
        arguments.put(POSITION_SECONDS, Double.valueOf(positionSeconds));
        this.methodChannel.invokeMethod(ON_POSITION_CALLBACK, arguments);
    }

    /**
     * Stop and release all {@link ManagedMediaPlayer}s.
     *
     * <p>Called on the parent Activity's onDestroy(); note that this assumes that the Dart audio lib
     * is disposed and that there will be no further messages over the method channel.
     */
    private void onDestroy() {
        for (ManagedMediaPlayer player : mediaPlayers.values()) {
            player.release();
        }
        mediaPlayers.clear();
    }

    @Override
    public void onMediaButtonClick(int keyCode) {
        Log.i(TAG, "onMediaButtonClick()");
        Map<String, Object> arguments = new HashMap<>();
        arguments.put(MEDIA_EVENT_TYPE, eventCodeToMediaEventString(keyCode));
        methodChannel.invokeMethod(ON_MEDIA_EVENT_CALLBACK, arguments);
    }

    // static conversion utility methods.

    @Override
    public void onCustomMediaButtonClick(String eventId) {
        Log.i(TAG, "onCustomMediaButtonClick()");
        Map<String, Object> arguments = new HashMap<>();
        arguments.put(MEDIA_EVENT_TYPE, MEDIA_CUSTOM);
        arguments.put(MEDIA_CUSTOM_EVENT_ID, eventId);
        methodChannel.invokeMethod(ON_MEDIA_EVENT_CALLBACK, arguments);
    }

    @Override
    public void onSeekTo(long positionMs) {
        Log.i(TAG, "onSeekTo()");
        double positionSeconds = positionMs / 1000.0;
        Map<String, Object> arguments = new HashMap<>();
        arguments.put(MEDIA_EVENT_TYPE, MEDIA_SEEK_TO);
        arguments.put(MEDIA_SEEK_TO_POSITION_SECONDS, positionSeconds);
        methodChannel.invokeMethod(ON_MEDIA_EVENT_CALLBACK, arguments);
    }

    /**
     * Converts a media button type string (from Dart) into a {@link NotificationCompat.Action}.
     *
     * <p>Uses built-in image resources for each type.
     */
    private NotificationCompat.Action mediaButtonTypeToAction(String mediaButtonType) {
        switch (mediaButtonType) {
            case MEDIA_PAUSE:
                return new NotificationCompat.Action(
                        R.drawable.ic_pause_black_36dp,
                        context.getString(R.string.pause),
                        MediaButtonReceiver.buildMediaButtonPendingIntent(
                                context, PlaybackStateCompat.ACTION_PAUSE));
            case MEDIA_PLAY:
                return new NotificationCompat.Action(
                        R.drawable.ic_play_arrow_black_36dp,
                        context.getString(R.string.play),
                        MediaButtonReceiver.buildMediaButtonPendingIntent(
                                context, PlaybackStateCompat.ACTION_PLAY));
            case MEDIA_STOP:
                return new NotificationCompat.Action(
                        R.drawable.ic_stop_black_36dp,
                        context.getString(R.string.stop),
                        MediaButtonReceiver.buildMediaButtonPendingIntent(
                                context, PlaybackStateCompat.ACTION_STOP));
            case MEDIA_NEXT:
                return new NotificationCompat.Action(
                        R.drawable.ic_skip_next_black_36dp,
                        context.getString(R.string.skipForward),
                        MediaButtonReceiver.buildMediaButtonPendingIntent(
                                context, PlaybackStateCompat.ACTION_SKIP_TO_NEXT));
            case MEDIA_PREVIOUS:
                return new NotificationCompat.Action(
                        R.drawable.ic_skip_previous_black_36dp,
                        context.getString(R.string.skipBackward),
                        MediaButtonReceiver.buildMediaButtonPendingIntent(
                                context, PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS));
            case MEDIA_SEEK_FORWARD:
                return new NotificationCompat.Action(
                        R.drawable.ic_fast_forward_black_36dp,
                        context.getString(R.string.seekForward),
                        MediaButtonReceiver.buildMediaButtonPendingIntent(
                                context, PlaybackStateCompat.ACTION_FAST_FORWARD));
            case MEDIA_SEEK_BACKWARD:
                return new NotificationCompat.Action(
                        R.drawable.ic_fast_rewind_black_36dp,
                        context.getString(R.string.seekBackward),
                        MediaButtonReceiver.buildMediaButtonPendingIntent(
                                context, PlaybackStateCompat.ACTION_REWIND));
            default:
                Log.e(TAG, "unsupported mediaButtonType:" + mediaButtonType);
                return null; //ERROR
        }
    }

    /**
     * Converts a custom media button map (from Dart) into a {@link NotificationCompat.Action}.
     */
    private NotificationCompat.Action customMediaButtonMapToAction(Map customMediaButton) {
        String resourceName = (String) customMediaButton.get(MEDIA_CUSTOM_DRAWABLE_RESOURCE);
        String title = (String) customMediaButton.get(MEDIA_CUSTOM_TITLE);
        String eventId = (String) customMediaButton.get(MEDIA_CUSTOM_EVENT_ID);
        int resourceId =
                context.getResources().getIdentifier(resourceName, "drawable", context.getPackageName());
        ComponentName component =
                new ComponentName(context.getPackageName(), AudiofileplayerService.class.getName());
        Intent intent = new Intent(Intent.ACTION_MEDIA_BUTTON);
        intent.setComponent(component);
        intent.putExtra(CUSTOM_MEDIA_BUTTON_EXTRA_KEY, eventId);
        PendingIntent pendingIntent =
                PendingIntent.getService(context, 0, intent, PendingIntent.FLAG_CANCEL_CURRENT);

        return new NotificationCompat.Action(resourceId, title, pendingIntent);
    }

    private static class LifecycleCallbacks implements Application.ActivityLifecycleCallbacks {
        private final WeakReference<AudiofileplayerPlugin> audioPluginRef;
        private final int activityHashCode;

        LifecycleCallbacks(AudiofileplayerPlugin audioPlugin, int activityHashCode) {
            audioPluginRef = new WeakReference<>(audioPlugin);
            this.activityHashCode = activityHashCode;
        }

        @Override
        public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
            // Never called, since Activity is already created before plugin.
            Log.i(TAG, "LifecycleCallbacks.onActivityCreated");
        }

        @Override
        public void onActivityStarted(Activity activity) {
            Log.i(TAG, "LifecycleCallbacks.onActivityStarted");
            if (activity.hashCode() != activityHashCode) {
                return;
            }
            // https://developer.android.com/guide/topics/media-apps/audio-app/building-a-mediabrowser-client
            AudiofileplayerPlugin audioPlugin = audioPluginRef.get();
            if (audioPlugin != null) {
                audioPlugin.mediaBrowser.connect();
            }
        }

        @Override
        public void onActivityResumed(Activity activity) {
            Log.i(TAG, "LifecycleCallbacks.onActivityResumed");
            if (activity.hashCode() != activityHashCode) {
                return;
            }
            // https://developer.android.com/guide/topics/media-apps/audio-app/building-a-mediabrowser-client
            AudiofileplayerPlugin audioPlugin = audioPluginRef.get();
            if (audioPlugin != null) {
                activity.setVolumeControlStream(AudioManager.STREAM_MUSIC);
            }
        }

        @Override
        public void onActivityPaused(Activity activity) {
        }

        @Override
        public void onActivityStopped(Activity activity) {
            Log.i(TAG, "LifecycleCallbacks.onActivityStopped");
            if (activity.hashCode() != activityHashCode) {
                return;
            }
            // https://developer.android.com/guide/topics/media-apps/audio-app/building-a-mediabrowser-client
            AudiofileplayerPlugin audioPlugin = audioPluginRef.get();
            if (audioPlugin != null) {
                if (MediaControllerCompat.getMediaController(activity) != null) {
                    MediaControllerCompat.getMediaController(activity)
                            .unregisterCallback(audioPlugin.controllerCallback);
                }
                audioPlugin.mediaBrowser.disconnect();
            }
        }

        @Override
        public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
        }

        @Override
        public void onActivityDestroyed(Activity activity) {
            if (activity.hashCode() != activityHashCode) {
                return;
            }
            activity.getApplication().unregisterActivityLifecycleCallbacks(this);

            AudiofileplayerPlugin audioPlugin = audioPluginRef.get();
            if (audioPlugin != null) {
                audioPlugin.onDestroy();
            }
        }
    }
}
