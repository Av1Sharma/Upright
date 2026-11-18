# Upright

A macOS 14+ posture detection prototype using the Mac camera and optional compatible AirPods. Camera images are processed locally and are not saved. Sit with your face and shoulders visible, then calibrate while comfortably upright. The app reports a sustained change after ten seconds.

## Run

Install Swift command-line tools, run `./build-app.sh`, then open `Upright.app`. Grant camera access and, when requested, motion access. Connect compatible head-tracking headphones before launch. AirPods are optional; the camera path works without them.

## Plan and current state

1. Capture camera frames and detect head and shoulder landmarks with Apple Vision. **Implemented.**
2. Calibrate a camera baseline and optional headphone attitude. **Implemented.**
3. Detect sustained deviations using both signals, allowing camera-only operation. **Prototype rules implemented.**
4. Collect consented, labeled real-world examples and evaluate false alerts and missed changes across users, lighting, poses, and camera positions. Tune thresholds or train a classifier from those results.
5. Add notifications, reconnection handling, robust calibration, and automated sensor integration tests before release.

The current fixed thresholds are experimental, not validated posture measurements. A front-facing camera cannot reliably measure forward head translation or spine curvature, and head tilt alone does not identify a slouch. Looking down can trigger the motion rule. Recalibrate after changing position, camera angle, or headphones. The app displays an in-window status rather than sending notifications.

## Compare shoulder detectors

Run `./build-comparison.sh`, then `open "Shoulder Comparison.app"`. This requires Node.js and npm; the build installs the pinned PoseNet dependencies. The comparison app downloads PoseNet model files from Google at startup, so it needs internet access to load the model. Camera frames are analyzed on the Mac, stay in memory, and are not saved or sent to the model host.

Sit normally with relaxed arms and click **Compare current frame**. The panels show Apple Vision and PoseNet shoulder results on the same captured frame (Vision processes the camera buffer, PoseNet receives its JPEG representation). Pink marks the subject's left shoulder and blue the right. Compare point placement visually; confidence scores are not accuracy measurements and are not directly comparable between models. Repeat with different positions and lighting. Close the comparison app to stop its camera. This tool does not change Upright's posture detector.
