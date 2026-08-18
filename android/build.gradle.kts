allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// OneDrive/Windows often locks mergeDebugAssets, which makes cleanMerge*Assets
// fail even though assemble can still overwrite the files.
subprojects {
    tasks.configureEach {
        if (name.startsWith("cleanMerge") && name.contains("Assets")) {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
