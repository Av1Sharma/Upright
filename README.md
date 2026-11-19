# Upright

A macOS 14+ posture detection prototype using the Mac camera and optional compatible AirPods. Camera images are processed locally and are not saved. Sit with your face and shoulders visible, then calibrate while comfortably upright. The app reports a sustained change after four seconds. Model being used is here (https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images).

## Run

Install Swift command-line tools, run `./build-app.sh`, then open `Upright.app`. Upright starts in the macOS menu bar. Select its icon to see the camera, calibrate, open the detailed window, or quit; closing the window keeps monitoring active. Grant camera access and, when requested, motion access. The AirPods are optional btw.

## Plan and current state

1. Capture camera frames and detect head and shoulder landmarks with PoseNet, with Apple Vision as a fallback. **Implemented.**
2. Calibrate a camera baseline and optional headphone attitude. **Implemented.**
3. Detect sustained deviations using both signals, allowing camera-only operation. **Prototype rules implemented.**
4. Collect consented, labeled real-world examples and evaluate false alerts and missed changes across users, lighting, poses, and camera positions. Tune thresholds or train a classifier from those results.
5. Add notifications, reconnection handling, robust calibration, and automated sensor integration tests before release.

The current fixed thresholds are experimental, not validated posture measurements. A front-facing camera cannot reliably measure forward head translation or spine curvature, and head tilt alone does not identify a slouch. Looking down can trigger the motion rule. Recalibrate after changing position, camera angle, or headphones. The app displays an in-window status rather than sending notifications.

## Compare shoulder detectors

Run `./build-comparison.sh`, then `open "Shoulder Comparison.app"`. This requires Node.js and npm; the build installs the pinned PoseNet dependencies. The comparison app downloads PoseNet model files from Google at startup, so it needs internet access to load the model. Camera frames are analyzed on the Mac, stay in memory, and are not saved or sent to the model host.

Sit normally with relaxed arms and click **Compare current frame**. The panels show Apple Vision and PoseNet shoulder results on the same captured frame (Vision processes the camera buffer, PoseNet receives its JPEG representation). Pink marks the subject's left shoulder and blue the right. Compare point placement visually; confidence scores are not accuracy measurements and are not directly comparable between models. Repeat with different positions and lighting. Close the comparison app to stop its camera. This tool does not change Upright's posture detector.

## Posture measurements

Open **Tracking details** in the app to see the detector status and measurement values. Use the **Landmarks** switch above the camera preview to show or hide markers. During PoseNet tracking, yellow markers show the detected nose, eyes and shoulders over the live camera preview. The overlay follows the latest completed inference and may lag slightly behind your movement. Only points with sufficient model confidence are shown; verify that they land on the intended features.

The **head / shoulder height** is the nose-to-shoulder-midpoint vertical distance divided by shoulder width. **Eye / shoulder width** is eye spacing divided by shoulder width. Each change is relative to the most recent calibration from the same detection method. Eye spacing is unavailable when the eyes cannot be confidently detected; calibrate again when they are visible to set its baseline. Camera framing, head rotation and distance can affect these values, which are experimental posture-change signals, not measurements of spinal curvature. The new eye-spacing measurement does not change the existing posture classification.
