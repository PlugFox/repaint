/// The frame rate of the scene.
extension type const RePaintFrameRate(int _value) implements int {
  /// The frame rate is unlimited.
  const RePaintFrameRate.unlimited() : _value = -1;

  /// The frame rate is limited to 120 frames per second.
  const RePaintFrameRate.fps120() : _value = 120;

  /// The frame rate is limited to 60 frames per second.
  const RePaintFrameRate.fps60() : _value = 60;

  /// The frame rate is limited to 30 frames per second.
  const RePaintFrameRate.fps30() : _value = 30;

  /// The frame rate is limited to 24 frames per second.
  const RePaintFrameRate.fps24() : _value = 24;

  /// The frame rate is limited to 15 frames per second.
  const RePaintFrameRate.fps15() : _value = 15;

  /// The frame rate is limited to 1 frames per second.
  const RePaintFrameRate.fps1() : _value = 1;

  /// The frame rate is limited to 0 frames per second.
  /// The scene is not updated with Ticker.
  const RePaintFrameRate.zero() : _value = 0;
}
