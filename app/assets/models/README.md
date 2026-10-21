# Face embedding model

`mobile_facenet.tflite` is Qualcomm AI Hub's float TFLite export of MobileFaceNet (release v0.64.0).

- Source: https://huggingface.co/qualcomm/MobileFaceNet
- Download: https://qaihub-public-assets.s3.us-west-2.amazonaws.com/qai-hub-models/models/mobile_facenet/releases/v0.64.0/mobile_facenet-tflite-float.zip
- License: Apache-2.0 (original implementation: https://github.com/foamliu/MobileFaceNet)

Inputs `img1` and `img2`: float32 `[1, 3, 112, 112]` (channels first, RGB, values 0–1).
Output `embeddings`: float32 `[2, 128]`, one embedding per input.
