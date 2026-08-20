// Kotlin Gradle Plugin을 적용하지 않는다.
// Flutter가 Built-in Kotlin으로 옮겨가면서, 모듈이 KGP를 직접 적용하면
// 앞으로 빌드가 깨진다. 이 모듈은 Java만 쓰므로 애초에 KGP가 필요 없다.
plugins {
    id("com.android.library")
}

android {
    namespace = "com.cheesetabby.handtracking"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // .task 모델은 압축되면 MediaPipe가 열지 못한다.
    androidResources {
        noCompress += "task"
    }
}

dependencies {
    // 버전 고정. 자동 업그레이드하지 않는다 — 손 추적 동작이 바뀌면
    // 판정 파라미터를 다시 맞춰야 한다.
    implementation("com.google.mediapipe:tasks-vision:1.0.0")
}

tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:deprecation")
}
