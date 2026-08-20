allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Gradle intermediates off OneDrive. Syncing build\... causes
// AccessDeniedException on mergeDebugNativeLibs / mergeDebugAssets.
val androidBuildRoot =
    java.io.File(
        System.getenv("LOCALAPPDATA") ?: System.getProperty("user.home"),
        "osp-parking-android-build",
    )
rootProject.layout.buildDirectory.set(androidBuildRoot)

subprojects {
    project.layout.buildDirectory.set(java.io.File(androidBuildRoot, project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

// OneDrive/Windows often locks merge output folders during clean.
subprojects {
    tasks.configureEach {
        if (name.startsWith("cleanMerge") &&
            (name.contains("Assets") || name.contains("NativeLibs"))
        ) {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
