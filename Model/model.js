import * as tf from '@tensorflow/tfjs';
import * as posenet from '@tensorflow-models/posenet';
const bridge = window.webkit.messageHandlers.pose;
let model;
window.analyzeFrame = async (base64, id) => {
  try {
    const image = new Image();
    image.src = 'data:image/jpeg;base64,' + base64;
    await image.decode();
    const result = await model.estimateSinglePose(image, {flipHorizontal: false});
    const names = ['nose', 'leftEye', 'rightEye', 'leftShoulder', 'rightShoulder'];
    const points = {};
    for (const name of names) {
      const p = result.keypoints.find(item => item.part === name);
      if (p) points[name] = {x: p.position.x, y: p.position.y, confidence: p.score};
    }
    bridge.postMessage({type: 'result', id, points});
  } catch (error) { bridge.postMessage({type: 'error', id, message: String(error)}); }
};
(async () => {
  try {
    await tf.setBackend('webgl'); await tf.ready();
    model = await posenet.load();
    bridge.postMessage({type: 'ready'});
  } catch (error) { bridge.postMessage({type: 'unavailable', message: String(error)}); }
})();
