import * as tf from '@tensorflow/tfjs';
import * as posenet from '@tensorflow-models/posenet';

const status = document.getElementById('status');
const button = document.getElementById('capture');
let net;
const native = window.webkit.messageHandlers.comparison;
button.onclick = () => { button.disabled = true; status.textContent = 'Capturing a frame…'; native.postMessage('capture'); };
window.comparisonError = message => { status.textContent = message; button.disabled = !net; };
window.compareFrame = async payload => {
  try {
    const image = new Image();
    image.src = 'data:image/jpeg;base64,' + payload.image;
    await image.decode();
    const result = await net.estimateSinglePose(image, {flipHorizontal: false});
    const names = ['leftShoulder', 'rightShoulder'];
    const vision = names.map(name => payload.vision[name] || null);
    const pose = names.map(name => {
      const p = result.keypoints.find(k => k.part === name);
      return p ? {x: p.position.x / image.width, y: p.position.y / image.height, confidence: p.score} : null;
    });
    function render(id, points) {
      const canvas = document.getElementById(id); canvas.width = image.width; canvas.height = image.height;
      const context = canvas.getContext('2d'); context.drawImage(image, 0, 0);
      points.forEach((p, i) => {
        if (!p || p.confidence <= 0) return;
        context.beginPath(); context.arc(p.x * image.width, p.y * image.height, Math.max(8, image.width / 80), 0, Math.PI * 2);
        context.fillStyle = i === 0 ? '#ff315e' : '#00bbf0'; context.fill();
        context.lineWidth = 3; context.strokeStyle = 'white'; context.stroke();
      });
      document.getElementById(id + 'Result').textContent = points.map((p, i) => `${i === 0 ? 'Left' : 'Right'}: ${p ? (p.confidence * 100).toFixed(0) + '%' : 'not detected'}`).join(' · ') + ' (pink: left, blue: right)';
    }
    render('vision', vision); render('posenet', pose);
    status.textContent = 'Comparison complete. Look at both shoulder dots.';
  } catch (error) { status.textContent = 'Comparison failed: ' + error.message; }
  button.disabled = false;
};
(async () => {
  try { await tf.setBackend('webgl'); await tf.ready(); net = await posenet.load(); status.textContent = 'Ready'; button.disabled = false; }
  catch (e) { status.textContent = 'PoseNet could not load: ' + e.message + '. Check your internet connection and reopen the app.'; }
})();
