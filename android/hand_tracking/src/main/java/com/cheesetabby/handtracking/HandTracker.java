package com.cheesetabby.handtracking;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Matrix;

import com.google.mediapipe.framework.image.BitmapImageBuilder;
import com.google.mediapipe.framework.image.MPImage;
import com.google.mediapipe.tasks.components.containers.Category;
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark;
import com.google.mediapipe.tasks.core.BaseOptions;
import com.google.mediapipe.tasks.vision.core.RunningMode;
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker;
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult;

import java.util.List;

/**
 * 카메라 프레임을 받아 손 랜드마크를 돌려주는 것만 한다.
 *
 * <p>어느 건반인지, 눌렀는지 같은 판정은 여기서 하지 않는다. 그 규칙은 Dart 한 곳에
 * 있어야 Android와 iOS가 갈라지지 않는다.
 *
 * <p>Kotlin이 아니라 Java로 둔 이유 — Flutter가 Built-in Kotlin으로 옮겨가면서
 * 모듈이 Kotlin Gradle Plugin을 직접 적용하면 앞으로 빌드가 깨진다. 이 코드는
 * Kotlin 문법이 필요 없을 만큼 단순하므로 의존을 없애는 쪽을 택했다.
 */
public final class HandTracker {

    public static final String MODEL_ASSET = "hand_landmarker.task";

    private final HandLandmarker landmarker;

    public HandTracker(Context context) {
        BaseOptions baseOptions = BaseOptions.builder()
                .setModelAssetPath(MODEL_ASSET)
                .build();

        HandLandmarker.HandLandmarkerOptions options =
                HandLandmarker.HandLandmarkerOptions.builder()
                        .setBaseOptions(baseOptions)
                        // VIDEO 모드는 동기 호출이면서 프레임 간 추적을 유지한다.
                        .setRunningMode(RunningMode.VIDEO)
                        .setNumHands(1)
                        .setMinHandDetectionConfidence(0.4f)
                        .setMinHandPresenceConfidence(0.4f)
                        .setMinTrackingConfidence(0.4f)
                        .build();

        this.landmarker = HandLandmarker.createFromOptions(context, options);
    }

    /** 좌표는 회전·반전이 적용된 뒤의 이미지 기준 정규화 좌표(0~1)다. */
    public static final class Result {
        /** 21개 랜드마크를 x,y 순으로 펼친 42개 값. */
        public final float[] landmarks;
        /** 손목(0)과 중지 밑동(9) 사이 거리. 거리·손 크기 보정에 쓴다. */
        public final float span;
        public final float confidence;

        Result(float[] landmarks, float span, float confidence) {
            this.landmarks = landmarks;
            this.span = span;
            this.confidence = confidence;
        }
    }

    /**
     * @param rotationDegrees 프레임을 세우려고 시계 방향으로 돌릴 각도 (0/90/180/270)
     * @param mirror          좌우 반전 여부. 전면 카메라를 거울처럼 쓰려면 true
     */
    public Result detect(
            byte[] nv21,
            int width,
            int height,
            int rotationDegrees,
            boolean mirror,
            long timestampMs) {

        Bitmap source = nv21ToBitmap(nv21, width, height);
        if (source == null) return null;

        Bitmap oriented = orient(source, rotationDegrees, mirror);
        MPImage image = new BitmapImageBuilder(oriented).build();

        HandLandmarkerResult result = landmarker.detectForVideo(image, timestampMs);
        if (oriented != source) source.recycle();

        List<List<NormalizedLandmark>> hands = result.landmarks();
        if (hands.isEmpty()) return null;
        List<NormalizedLandmark> hand = hands.get(0);
        if (hand.size() < 21) return null;

        float[] flat = new float[42];
        for (int i = 0; i < 21; i++) {
            flat[i * 2] = hand.get(i).x();
            flat[i * 2 + 1] = hand.get(i).y();
        }

        // 정규화 좌표는 가로세로 비율이 다르므로 픽셀 기준으로 환산해서 잰다.
        float w = oriented.getWidth();
        float h = oriented.getHeight();
        float dx = (hand.get(9).x() - hand.get(0).x()) * w;
        float dy = (hand.get(9).y() - hand.get(0).y()) * h;
        float spanPx = (float) Math.sqrt(dx * dx + dy * dy);
        float span = spanPx / Math.max(w, h);

        // 주의 — 이건 검출 신뢰도가 아니라 「왼손인지 오른손인지」에 대한 확신도다.
        // Java API에 프레임별 랜드마크 신뢰도가 없어서 대용으로 쓴다. 손이
        // 가려지거나 애매할 때 같이 떨어지므로 품질 지표로는 쓸 만하지만,
        // 진짜 게이트는 아래 생성자의 minHandDetection/Presence/Tracking 값이다.
        // iOS Vision은 관절별 실제 신뢰도를 주므로 그쪽에서 제대로 채운다.
        float confidence = 1f;
        List<List<Category>> handedness = result.handedness();
        if (!handedness.isEmpty() && !handedness.get(0).isEmpty()) {
            confidence = handedness.get(0).get(0).score();
        }

        return new Result(flat, span, confidence);
    }

    public void close() {
        landmarker.close();
    }

    private static Bitmap orient(Bitmap source, int rotationDegrees, boolean mirror) {
        if (rotationDegrees == 0 && !mirror) return source;
        Matrix matrix = new Matrix();
        if (mirror) matrix.postScale(-1f, 1f);
        if (rotationDegrees != 0) matrix.postRotate(rotationDegrees);
        return Bitmap.createBitmap(
                source, 0, 0, source.getWidth(), source.getHeight(), matrix, true);
    }

    /**
     * NV21 → ARGB_8888. JPEG를 거치지 않으려고 직접 변환한다.
     * 프레임마다 도는 경로라 할당을 최소로 유지한다.
     */
    private static Bitmap nv21ToBitmap(byte[] nv21, int width, int height) {
        int frameSize = width * height;
        if (nv21.length < frameSize * 3 / 2) return null;

        int[] argb = new int[frameSize];
        int yp = 0;
        for (int j = 0; j < height; j++) {
            int uvp = frameSize + (j >> 1) * width;
            int u = 0;
            int v = 0;
            for (int i = 0; i < width; i++) {
                int y = (nv21[yp] & 0xff) - 16;
                if (y < 0) y = 0;
                if ((i & 1) == 0) {
                    int offset = uvp + (i >> 1) * 2;
                    v = (nv21[offset] & 0xff) - 128;
                    u = (nv21[offset + 1] & 0xff) - 128;
                }
                int y1192 = 1192 * y;
                int r = y1192 + 1634 * v;
                int g = y1192 - 833 * v - 400 * u;
                int b = y1192 + 2066 * u;

                if (r < 0) r = 0; else if (r > 262143) r = 262143;
                if (g < 0) g = 0; else if (g > 262143) g = 262143;
                if (b < 0) b = 0; else if (b > 262143) b = 262143;

                argb[yp] = 0xff000000
                        | ((r << 6) & 0x00ff0000)
                        | ((g >> 2) & 0x0000ff00)
                        | ((b >> 10) & 0x000000ff);
                yp++;
            }
        }
        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        bitmap.setPixels(argb, 0, width, 0, 0, width, height);
        return bitmap;
    }
}
