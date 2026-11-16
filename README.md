# Upright 

A macOS 14+ posture detection prototype using the Mac camera and optional compatible AirPods. Camera images are processed locally and are not saved. Sit with your face and shoulders visible, then calibrate while comfortably upright. The app reports a sustained change after ten seconds. Model being used is here (https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images).

## Run

Install Swift command-line tools, run `./build-app.sh`, then open `Upright.app`. Grant camera access and, when requested, motion access. The AirPods are optional btw. 

## Plan and current state

1. Capture camera frames and detect head and shoulder landmarks with Apple Vision. **Implemented.**
2. Calibrate a camera baseline and optional headphone attitude. **Implemented.**
3. Detect sustained deviations using both signals, allowing camera-only operation. **Prototype rules implemented.**
4. Collect consented, labeled real-world examples and evaluate false alerts and missed changes across users, lighting, poses, and camera positions. Tune thresholds or train a classifier from those results.
5. Add notifications, reconnection handling, robust calibration, and automated sensor integration tests before release. 

The current fixed thresholds are experimental, I haven't actually validated the posture measurements. A front-facing camera cannot reliably measure forward head translation or spine curvature, and head tilt alone does not identify a slouch. Looking down can trigger the motion rule. Recalibrate after changing position, camera angle, or headphones. Currently, the app is limited to a in-window, I don't have any features for a notification system planned soon until I can get the core model down and working.

If you want to let me know any issues lmk
