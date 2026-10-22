/**
 * Browser-side face detection and camera bridge for BakeOut.
 *
 * MediaPipe's FaceLandmarker runs entirely in the browser, so the selfie check
 * never sends an image anywhere. Faces come back as the same flat shape the
 * native iOS and Android detectors report.
 */
(function () {
  'use strict';

  // The 16 landmarks that ring each eye in MediaPipe's 468-point face mesh.
  var LEFT_EYE = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398];
  var RIGHT_EYE = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246];

  // The six landmarks that measure the eye opening: two corners and two pairs of
  // eyelid points. Their distance ratio drops sharply when the eye closes.
  var LEFT_EYE_LID = [33, 160, 158, 133, 153, 144];
  var RIGHT_EYE_LID = [362, 385, 387, 263, 373, 380];

  var state = {
    imageLandmarker: null,
    videoLandmarker: null,
    video: null,
    stream: null,
    onFrame: null,
    running: false,
    lastVideoTime: -1,
    lastDetect: 0,
    loading: null,
  };

  function loadScript(src) {
    return new Promise(function (resolve, reject) {
      if (document.querySelector('script[data-bakeout="' + src + '"]')) {
        resolve();
        return;
      }
      var tag = document.createElement('script');
      tag.src = src;
      tag.async = true;
      tag.dataset.bakeout = src;
      tag.onload = function () { resolve(); };
      tag.onerror = function () { reject(new Error('Failed to load ' + src)); };
      document.head.appendChild(tag);
    });
  }

  /** MediaPipe keeps its API on `window.Vision` in some builds and on `window` in others. */
  function mediaPipe() {
    if (window.Vision && window.Vision.FaceLandmarker) return window.Vision;
    if (window.FaceLandmarker) return window;
    throw new Error('MediaPipe did not load');
  }

  function createLandmarker(fileset, runningMode) {
    var options = {
      baseOptions: { modelAssetPath: 'mediapipe/face_landmarker.task', delegate: 'GPU' },
      runningMode: runningMode,
      numFaces: 3,
      outputFaceBlendshapes: false,
      outputFacialTransformationMatrixes: true,
    };
    return mediaPipe().FaceLandmarker.createFromOptions(fileset, options).catch(function () {
      // Some browsers and machines have no usable GPU delegate.
      options.baseOptions.delegate = 'CPU';
      return mediaPipe().FaceLandmarker.createFromOptions(fileset, options);
    });
  }

  /** Loads MediaPipe and the face landmark model. Safe to call more than once. */
  function init() {
    if (state.imageLandmarker) return Promise.resolve();
    if (state.loading) return state.loading;
    state.loading = loadScript('mediapipe/vision_bundle.js')
      .then(function () {
        return mediaPipe().FilesetResolver.forVisionTasks('mediapipe/wasm');
      })
      .then(function (fileset) {
        return Promise.all([
          createLandmarker(fileset, 'IMAGE'),
          createLandmarker(fileset, 'VIDEO'),
        ]);
      })
      .then(function (made) {
        state.imageLandmarker = made[0];
        state.videoLandmarker = made[1];
      })
      .catch(function (error) {
        // Forget the failed attempt so a later try can start clean.
        state.loading = null;
        throw error;
      });
    return state.loading;
  }

  function bytesToBase64(bytes) {
    var binary = '';
    var chunk = 0x8000;
    for (var i = 0; i < bytes.length; i += chunk) {
      binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
    }
    return btoa(binary);
  }

  function base64ToBytes(b64) {
    var binary = atob(b64);
    var out = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
    return out;
  }

  function sniffMime(bytes) {
    if (bytes[0] === 0x89 && bytes[1] === 0x50) return 'image/png';
    if (bytes[0] === 0x52 && bytes[1] === 0x49) return 'image/webp';
    return 'image/jpeg';
  }

  function loadImage(src) {
    return new Promise(function (resolve, reject) {
      var img = new Image();
      img.onload = function () { resolve(img); };
      img.onerror = function () { reject(new Error('Could not decode the image')); };
      img.src = src;
    });
  }

  /** Eye centre and open-height ratio, in pixels of the image being read. */
  function eyeStats(points, indices, width, height) {
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    var sumX = 0, sumY = 0, count = 0;
    for (var i = 0; i < indices.length; i++) {
      var p = points[indices[i]];
      if (!p) continue;
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
      sumX += p.x;
      sumY += p.y;
      count++;
    }
    if (count === 0) return { ratio: 0, cx: 0, cy: 0 };
    var eyeWidth = (maxX - minX) * width;
    var eyeHeight = (maxY - minY) * height;
    return {
      ratio: eyeWidth > 0 ? eyeHeight / eyeWidth : 0,
      cx: (sumX / count) * width,
      cy: (sumY / count) * height,
    };
  }

  /**
   * Eye aspect ratio: the eye's opening height over its width, measured between
   * the eyelid landmarks. A wide-open eye is around 0.25, a closed one near 0.05.
   */
  function eyeOpening(points, indices, width, height) {
    var at = function (i) {
      var p = points[i];
      return p ? { x: p.x * width, y: p.y * height } : null;
    };
    var p1 = at(indices[0]), p2 = at(indices[1]), p3 = at(indices[2]);
    var p4 = at(indices[3]), p5 = at(indices[4]), p6 = at(indices[5]);
    if (!p1 || !p2 || !p3 || !p4 || !p5 || !p6) return 0;
    var distance = function (a, b) {
      return Math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
    };
    var width = distance(p1, p4);
    if (width <= 0) return 0;
    return (distance(p2, p6) + distance(p3, p5)) / (2 * width);
  }

  /** Head yaw in degrees, taken from the transformation matrix MediaPipe returns. */
  function yawFrom(matrix) {
    if (!matrix || !matrix.data || matrix.data.length < 16) return 0;
    // MediaPipe hands the matrix over column-major: d[0..2] is the first column,
    // so d[2] is the lower-left term a yaw rotation puts its sine into.
    var d = matrix.data;
    var yaw = Math.atan2(-d[2], Math.sqrt(d[0] * d[0] + d[1] * d[1]));
    return yaw * 180 / Math.PI;
  }

  function facesFrom(result, width, height) {
    var out = [];
    var all = (result && result.faceLandmarks) || [];
    var matrices = (result && result.facialTransformationMatrixes) || [];
    for (var i = 0; i < all.length; i++) {
      var points = all[i];
      if (!points || !points.length) continue;
      var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      for (var j = 0; j < points.length; j++) {
        var p = points[j];
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      var left = eyeStats(points, LEFT_EYE, width, height);
      var right = eyeStats(points, RIGHT_EYE, width, height);
      out.push({
        x: minX * width,
        y: minY * height,
        width: (maxX - minX) * width,
        height: (maxY - minY) * height,
        yaw: yawFrom(matrices[i]),
        leftEyeEar: eyeOpening(points, LEFT_EYE_LID, width, height),
        rightEyeEar: eyeOpening(points, RIGHT_EYE_LID, width, height),
        leftEyeX: left.cx,
        leftEyeY: left.cy,
        rightEyeX: right.cx,
        rightEyeY: right.cy,
      });
    }
    return out;
  }

  /** Detects faces in an encoded image given as base64. Returns a JSON list. */
  function detectImageBytes(base64) {
    return init().then(function () {
      var bytes = base64ToBytes(base64);
      var src = 'data:' + sniffMime(bytes) + ';base64,' + base64;
      return loadImage(src).then(function (img) {
        var width = img.naturalWidth || img.width;
        var height = img.naturalHeight || img.height;
        var result = state.imageLandmarker.detect(img);
        return JSON.stringify(facesFrom(result, width, height));
      });
    });
  }

  /** Opens the front camera and streams detected faces to the callback. */
  function startCamera(video, onFrame) {
    // Leaving and re-entering the check would otherwise leave the old camera running.
    stopCamera();
    return init().then(function () {
      state.video = video;
      state.onFrame = onFrame;
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('This browser has no camera access');
      }
      return navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
        audio: false,
      });
    }).then(function (stream) {
      state.stream = stream;
      var video = state.video;
      video.srcObject = stream;
      video.setAttribute('playsinline', '');
      video.muted = true;
      return video.play().then(function () {
        state.running = true;
        state.lastVideoTime = -1;
        state.lastDetect = 0;
        requestAnimationFrame(loop);
      }, function (error) {
        // Don't leave the camera light on when playback is refused.
        stopCamera();
        throw error;
      });
    });
  }

  function loop() {
    if (!state.running) return;
    requestAnimationFrame(loop);
    var video = state.video;
    if (!video || video.readyState < 2 || !state.videoLandmarker) return;
    if (video.currentTime === state.lastVideoTime) return;
    // Reading every frame pegs the main thread on machines without a GPU delegate.
    var now = performance.now();
    if (now - state.lastDetect < 40) return;
    state.lastDetect = now;
    state.lastVideoTime = video.currentTime;
    var result;
    try {
      result = state.videoLandmarker.detectForVideo(video, now);
    } catch (e) {
      return;
    }
    if (!state.onFrame) return;
    try {
      state.onFrame(JSON.stringify(facesFrom(result, video.videoWidth, video.videoHeight)));
    } catch (e) {
      // A frame that cannot be read is simply skipped.
    }
  }

  function stopCamera() {
    state.running = false;
    state.onFrame = null;
    if (state.stream) {
      state.stream.getTracks().forEach(function (track) { track.stop(); });
      state.stream = null;
    }
    if (state.video) {
      state.video.srcObject = null;
      state.video = null;
    }
  }

  /** One still frame from the running camera, as base64 JPEG. */
  function captureStill() {
    var video = state.video;
    if (!video || !video.videoWidth) {
      return Promise.reject(new Error('The camera is not running'));
    }
    var canvas = document.createElement('canvas');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);
    return new Promise(function (resolve, reject) {
      canvas.toBlob(function (blob) {
        if (!blob) {
          reject(new Error('Could not read the camera frame'));
          return;
        }
        blob.arrayBuffer().then(function (buffer) {
          resolve(bytesToBase64(new Uint8Array(buffer)));
        }, reject);
      }, 'image/jpeg', 0.92);
    });
  }

  window.bakeoutVision = {
    init: init,
    detectImageBytes: detectImageBytes,
    startCamera: startCamera,
    stopCamera: stopCamera,
    captureStill: captureStill,
  };
})();
