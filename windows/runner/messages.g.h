// Autogenerated from Pigeon (v17.1.3), do not edit directly.
// See also: https://pub.dev/packages/pigeon

#ifndef PIGEON_MESSAGES_G_H_
#define PIGEON_MESSAGES_G_H_
#include <flutter/basic_message_channel.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/standard_message_codec.h>

#include <map>
#include <optional>
#include <string>



// Generated class from Pigeon.

class FlutterError {
 public:
  explicit FlutterError(const std::string& code)
    : code_(code) {}
  explicit FlutterError(const std::string& code, const std::string& message)
    : code_(code), message_(message) {}
  explicit FlutterError(const std::string& code, const std::string& message, const flutter::EncodableValue& details)
    : code_(code), message_(message), details_(details) {}

  const std::string& code() const { return code_; }
  const std::string& message() const { return message_; }
  const flutter::EncodableValue& details() const { return details_; }

 private:
  std::string code_;
  std::string message_;
  flutter::EncodableValue details_;
};

template<class T> class ErrorOr {
 public:
  ErrorOr(const T& rhs) : v_(rhs) {}
  ErrorOr(const T&& rhs) : v_(std::move(rhs)) {}
  ErrorOr(const FlutterError& rhs) : v_(rhs) {}
  ErrorOr(const FlutterError&& rhs) : v_(std::move(rhs)) {}

  bool has_error() const { return std::holds_alternative<FlutterError>(v_); }
  const T& value() const { return std::get<T>(v_); };
  const FlutterError& error() const { return std::get<FlutterError>(v_); };

 private:
  friend class MeditoAudioServiceApi;
  friend class MeditoAudioServiceCallbackApi;
  ErrorOr() = default;
  T TakeValue() && { return std::get<T>(std::move(v_)); }

  std::variant<T, FlutterError> v_;
};


// Generated class from Pigeon that represents data sent in messages.
class AudioData {
 public:
  // Constructs an object setting all fields.
  explicit AudioData(
    const std::string& url,
    const Track& track);

  const std::string& url() const;
  void set_url(std::string_view value_arg);

  const Track& track() const;
  void set_track(const Track& value_arg);


 private:
  static AudioData FromEncodableList(const flutter::EncodableList& list);
  flutter::EncodableList ToEncodableList() const;
  friend class MeditoAudioServiceApi;
  friend class MeditoAudioServiceApiCodecSerializer;
  friend class MeditoAudioServiceCallbackApi;
  friend class MeditoAudioServiceCallbackApiCodecSerializer;
  std::string url_;
  Track track_;

};


// Generated class from Pigeon that represents data sent in messages.
class PlaybackState {
 public:
  // Constructs an object setting all non-nullable fields.
  explicit PlaybackState(
    bool is_playing,
    bool is_buffering,
    bool is_seeking,
    bool is_completed,
    int64_t position,
    int64_t duration,
    const Speed& speed,
    int64_t volume,
    const Track& track);

  // Constructs an object setting all fields.
  explicit PlaybackState(
    bool is_playing,
    bool is_buffering,
    bool is_seeking,
    bool is_completed,
    int64_t position,
    int64_t duration,
    const Speed& speed,
    int64_t volume,
    const Track& track,
    const BackgroundSound* background_sound);

  bool is_playing() const;
  void set_is_playing(bool value_arg);

  bool is_buffering() const;
  void set_is_buffering(bool value_arg);

  bool is_seeking() const;
  void set_is_seeking(bool value_arg);

  bool is_completed() const;
  void set_is_completed(bool value_arg);

  int64_t position() const;
  void set_position(int64_t value_arg);

  int64_t duration() const;
  void set_duration(int64_t value_arg);

  const Speed& speed() const;
  void set_speed(const Speed& value_arg);

  int64_t volume() const;
  void set_volume(int64_t value_arg);

  const Track& track() const;
  void set_track(const Track& value_arg);

  const BackgroundSound* background_sound() const;
  void set_background_sound(const BackgroundSound* value_arg);
  void set_background_sound(const BackgroundSound& value_arg);


 private:
  static PlaybackState FromEncodableList(const flutter::EncodableList& list);
  flutter::EncodableList ToEncodableList() const;
  friend class MeditoAudioServiceApi;
  friend class MeditoAudioServiceApiCodecSerializer;
  friend class MeditoAudioServiceCallbackApi;
  friend class MeditoAudioServiceCallbackApiCodecSerializer;
  bool is_playing_;
  bool is_buffering_;
  bool is_seeking_;
  bool is_completed_;
  int64_t position_;
  int64_t duration_;
  Speed speed_;
  int64_t volume_;
  Track track_;
  std::optional<BackgroundSound> background_sound_;

};


// Generated class from Pigeon that represents data sent in messages.
class BackgroundSound {
 public:
  // Constructs an object setting all non-nullable fields.
  explicit BackgroundSound(const std::string& title);

  // Constructs an object setting all fields.
  explicit BackgroundSound(
    const std::string* uri,
    const std::string& title);

  const std::string* uri() const;
  void set_uri(const std::string_view* value_arg);
  void set_uri(std::string_view value_arg);

  const std::string& title() const;
  void set_title(std::string_view value_arg);


 private:
  static BackgroundSound FromEncodableList(const flutter::EncodableList& list);
  flutter::EncodableList ToEncodableList() const;
  friend class PlaybackState;
  friend class MeditoAudioServiceApi;
  friend class MeditoAudioServiceApiCodecSerializer;
  friend class MeditoAudioServiceCallbackApi;
  friend class MeditoAudioServiceCallbackApiCodecSerializer;
  std::optional<std::string> uri_;
  std::string title_;

};


// Generated class from Pigeon that represents data sent in messages.
class Speed {
 public:
  // Constructs an object setting all fields.
  explicit Speed(double speed);

  double speed() const;
  void set_speed(double value_arg);


 private:
  static Speed FromEncodableList(const flutter::EncodableList& list);
  flutter::EncodableList ToEncodableList() const;
  friend class PlaybackState;
  friend class MeditoAudioServiceApi;
  friend class MeditoAudioServiceApiCodecSerializer;
  friend class MeditoAudioServiceCallbackApi;
  friend class MeditoAudioServiceCallbackApiCodecSerializer;
  double speed_;

};


// Generated class from Pigeon that represents data sent in messages.
class Track {
 public:
  // Constructs an object setting all non-nullable fields.
  explicit Track(
    const std::string& title,
    const std::string& description,
    const std::string& image_url);

  // Constructs an object setting all fields.
  explicit Track(
    const std::string& title,
    const std::string& description,
    const std::string& image_url,
    const std::string* artist,
    const std::string* artist_url);

  const std::string& title() const;
  void set_title(std::string_view value_arg);

  const std::string& description() const;
  void set_description(std::string_view value_arg);

  const std::string& image_url() const;
  void set_image_url(std::string_view value_arg);

  const std::string* artist() const;
  void set_artist(const std::string_view* value_arg);
  void set_artist(std::string_view value_arg);

  const std::string* artist_url() const;
  void set_artist_url(const std::string_view* value_arg);
  void set_artist_url(std::string_view value_arg);


 private:
  static Track FromEncodableList(const flutter::EncodableList& list);
  flutter::EncodableList ToEncodableList() const;
  friend class AudioData;
  friend class PlaybackState;
  friend class MeditoAudioServiceApi;
  friend class MeditoAudioServiceApiCodecSerializer;
  friend class MeditoAudioServiceCallbackApi;
  friend class MeditoAudioServiceCallbackApiCodecSerializer;
  std::string title_;
  std::string description_;
  std::string image_url_;
  std::optional<std::string> artist_;
  std::optional<std::string> artist_url_;

};

class MeditoAudioServiceApiCodecSerializer : public flutter::StandardCodecSerializer {
 public:
  MeditoAudioServiceApiCodecSerializer();
  inline static MeditoAudioServiceApiCodecSerializer& GetInstance() {
    static MeditoAudioServiceApiCodecSerializer sInstance;
    return sInstance;
  }

  void WriteValue(
    const flutter::EncodableValue& value,
    flutter::ByteStreamWriter* stream) const override;

 protected:
  flutter::EncodableValue ReadValueOfType(
    uint8_t type,
    flutter::ByteStreamReader* stream) const override;

};

// Generated interface from Pigeon that represents a handler of messages from Flutter.
class MeditoAudioServiceApi {
 public:
  MeditoAudioServiceApi(const MeditoAudioServiceApi&) = delete;
  MeditoAudioServiceApi& operator=(const MeditoAudioServiceApi&) = delete;
  virtual ~MeditoAudioServiceApi() {}
  virtual ErrorOr<bool> PlayAudio(const AudioData& audio_data) = 0;
  virtual std::optional<FlutterError> PlayPauseAudio() = 0;
  virtual std::optional<FlutterError> StopAudio() = 0;
  virtual std::optional<FlutterError> SetSpeed(double speed) = 0;
  virtual std::optional<FlutterError> SeekToPosition(int64_t position) = 0;
  virtual std::optional<FlutterError> Skip10SecondsForward() = 0;
  virtual std::optional<FlutterError> Skip10SecondsBackward() = 0;
  virtual std::optional<FlutterError> SetBackgroundSound(const std::string* uri) = 0;
  virtual std::optional<FlutterError> SetBackgroundSoundVolume(double volume) = 0;
  virtual std::optional<FlutterError> StopBackgroundSound() = 0;
  virtual std::optional<FlutterError> PlayBackgroundSound() = 0;

  // The codec used by MeditoAudioServiceApi.
  static const flutter::StandardMessageCodec& GetCodec();
  // Sets up an instance of `MeditoAudioServiceApi` to handle messages through the `binary_messenger`.
  static void SetUp(
    flutter::BinaryMessenger* binary_messenger,
    MeditoAudioServiceApi* api);
  static flutter::EncodableValue WrapError(std::string_view error_message);
  static flutter::EncodableValue WrapError(const FlutterError& error);

 protected:
  MeditoAudioServiceApi() = default;

};
class MeditoAudioServiceCallbackApiCodecSerializer : public flutter::StandardCodecSerializer {
 public:
  MeditoAudioServiceCallbackApiCodecSerializer();
  inline static MeditoAudioServiceCallbackApiCodecSerializer& GetInstance() {
    static MeditoAudioServiceCallbackApiCodecSerializer sInstance;
    return sInstance;
  }

  void WriteValue(
    const flutter::EncodableValue& value,
    flutter::ByteStreamWriter* stream) const override;

 protected:
  flutter::EncodableValue ReadValueOfType(
    uint8_t type,
    flutter::ByteStreamReader* stream) const override;

};

// Generated class from Pigeon that represents Flutter messages that can be called from C++.
class MeditoAudioServiceCallbackApi {
 public:
  MeditoAudioServiceCallbackApi(flutter::BinaryMessenger* binary_messenger);
  static const flutter::StandardMessageCodec& GetCodec();
  void UpdatePlaybackState(
    const PlaybackState& state,
    std::function<void(void)>&& on_success,
    std::function<void(const FlutterError&)>&& on_error);

 private:
  flutter::BinaryMessenger* binary_messenger_;
};

#endif  // PIGEON_MESSAGES_G_H_
